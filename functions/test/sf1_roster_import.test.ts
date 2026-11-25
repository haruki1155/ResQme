import assert from 'node:assert/strict';
import test from 'node:test';
import * as XLSX from 'xlsx';
import {evaluateRosterClaim, rosterCodeDigest, rosterLookupId} from '../src/school/roster_contract';
import {parseSf1Workbook} from '../src/school/sf1_parser';
import {
  commitSchoolRosterImport,
  listSchoolRosterImports,
  previewSchoolRosterImport,
} from '../src/school/sf1_roster_import';
import {staffManagementDeps, type StaffAdminAuthPort} from '../src/staff/staff_account_management';

const TEST_ROSTER_KEY = '0123456789abcdef0123456789abcdef';

function buildSyntheticSf1Buffer(
  bookType: 'xls' | 'xlsx',
  rows: Array<Array<unknown>>,
  gradeLevel = 'Grade 10',
): Buffer {
  const aoa: Array<Array<unknown>> = [
    ['School Form 1 (SF 1) School Register'],
    ['(Fictional QA Fixture)'],
    [],
    ['', '', '', 'School ID', '000000123'],
    [],
    ['', '', 'School Name', 'QA Pilot High', '', '', '', '', '', '', '', '', 'School Year', '2026-2027', '', '', '', '', 'Grade Level', gradeLevel],
    [],
    ['', 'LRN', 'NAME (Last Name, First Name, Middle Name)', '', '', '', 'Sex (M/F)', 'BIRTH DATE (mm/dd/ yyyy)', 'AGE', '', '', '', '', '', '', '', '', '', '', 'PARENTS', '', '', '', 'GUARDIAN (If not Parent)', '', 'Contact Number of Parent or Guardian'],
    ['', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', "Father's Name", '', "Mother's Maiden Name", '', 'Name', 'Relation-ship', ''],
    ...rows,
    ['List and Code of Indicators under REMARKS', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 'Prepared by:'],
  ];
  const ws = XLSX.utils.aoa_to_sheet(aoa);
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, ws, 'School Form 1 (SF1)');
  return XLSX.write(wb, {type: 'buffer', bookType}) as Buffer;
}

function makeStore() {
  const rows = new Map<string, Record<string, unknown>>();

  interface MockDocRef {
    path: string;
    id: string;
    get: () => Promise<{
      id: string;
      exists: boolean;
      data: () => Record<string, unknown> | undefined;
      get: (f: string) => unknown;
    }>;
    set: (data: Record<string, unknown>) => Promise<void>;
    create: (data: Record<string, unknown>) => Promise<void>;
    update: (patch: Record<string, unknown>) => Promise<void>;
    collection: (sub: string) => {doc: (id: string) => MockDocRef};
  }

  const docRef = (path: string): MockDocRef => ({
    path,
    id: path.split('/').pop()!,
    async get() {
      const data = rows.get(path);
      return {
        id: path.split('/').pop()!,
        exists: data !== undefined,
        data: () => data,
        get: (field: string) => data?.[field],
      };
    },
    async set(data: Record<string, unknown>) {
      rows.set(path, {...data});
    },
    async create(data: Record<string, unknown>) {
      if (rows.has(path)) throw new Error(`Already exists: ${path}`);
      rows.set(path, {...data});
    },
    async update(patch: Record<string, unknown>) {
      const cur = rows.get(path);
      if (!cur) throw new Error(`Missing doc ${path}`);
      rows.set(path, {...cur, ...patch});
    },
    collection(sub: string) {
      return {doc: (id: string) => docRef(`${path}/${sub}/${id}`)};
    },
  });

  const db = {
    doc: docRef,
    collection(col: string) {
      const filters: Array<[string, unknown]> = [];
      const query = {
        where(field: string, _op: string, value: unknown) {
          filters.push([field, value]);
          return query;
        },
        async get() {
          const docs = [...rows.entries()]
            .filter(([p]) => p.startsWith(`${col}/`) && p.split('/').length === 2)
            .filter(([, data]) => filters.every(([f, v]) => data[f] === v))
            .map(([p, data]) => ({
              id: p.split('/').pop()!,
              ref: docRef(p),
              data: () => data,
              get: (field: string) => data[field],
            }));
          return {docs, empty: docs.length === 0, size: docs.length};
        },
      };
      return query;
    },
    async runTransaction<T>(fn: (tx: {
      get: (ref: MockDocRef) => ReturnType<MockDocRef['get']>;
      set: (ref: MockDocRef, data: Record<string, unknown>) => void;
      create: (ref: MockDocRef, data: Record<string, unknown>) => void;
      update: (ref: MockDocRef, patch: Record<string, unknown>) => void;
    }) => Promise<T>): Promise<T> {
      const snapshot = new Map<string, Record<string, unknown>>();
      for (const [k, v] of rows) snapshot.set(k, {...v});
      const ops: Array<() => Promise<void>> = [];
      const tx = {
        get: (ref: MockDocRef) => ref.get(),
        set: (ref: MockDocRef, data: Record<string, unknown>) => {
          ops.push(() => ref.set(data));
        },
        create: (ref: MockDocRef, data: Record<string, unknown>) => {
          ops.push(() => ref.create(data));
        },
        update: (ref: MockDocRef, patch: Record<string, unknown>) => {
          ops.push(() => ref.update(patch));
        },
      };
      try {
        const result = await fn(tx);
        for (const op of ops) await op();
        return result;
      } catch (err) {
        rows.clear();
        for (const [k, v] of snapshot) rows.set(k, v);
        throw err;
      }
    },
  };
  return {rows, db};
}

function authReq(uid: string | undefined, data: unknown) {
  return {
    auth: uid ? {uid, token: {email_verified: true}} : undefined,
    data,
    rawRequest: {},
  } as never;
}

function seedAdmin(rows: Map<string, Record<string, unknown>>) {
  rows.set('staffAccounts/admin-1', {
    schoolId: '000000123',
    role: 'admin',
    isMasterAdmin: true,
    active: true,
    mustChangePassword: false,
    requiresEmailVerification: true,
    fullName: 'Master Admin',
  });
  rows.set('staffAccounts/auth-1', {
    schoolId: '000000123',
    role: 'authorized',
    isMasterAdmin: false,
    active: true,
    mustChangePassword: false,
    fullName: 'Nurse One',
  });
}

function withDeps(store: ReturnType<typeof makeStore>, fn: () => Promise<void>) {
  const prevDb = staffManagementDeps.db;
  const prevAuth = staffManagementDeps.auth;
  const prevKey = process.env.RESQME_SCHOOL_ROSTER_HMAC_KEY;
  staffManagementDeps.db = (() => store.db as never) as never;
  staffManagementDeps.auth = (() => ({}) as StaffAdminAuthPort) as never;
  process.env.RESQME_SCHOOL_ROSTER_HMAC_KEY = TEST_ROSTER_KEY;
  return fn().finally(() => {
    staffManagementDeps.db = prevDb;
    staffManagementDeps.auth = prevAuth;
    if (prevKey === undefined) delete process.env.RESQME_SCHOOL_ROSTER_HMAC_KEY;
    else process.env.RESQME_SCHOOL_ROSTER_HMAC_KEY = prevKey;
  });
}

test('Parses both .xls and .xlsx SF1 workbooks, preserving leading-zero LRNs and rejecting invalid dates', () => {
  const sampleRows = [
    ['', '009876543210', 'Dela Cruz, Juan Santos', '', '', '', 'M', '05/10/2010', '', '', '', '', '', '', '', '', '', '', '', 'Dela Cruz, Pedro', '', 'Santos, Maria', '', 'Maria Dela Cruz', 'Mother', '09171234567'],
    ['', '001122334455', 'Reyes, Ana', '', '', '', 'F', '02/30/2010', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', ''],
  ];

  for (const ext of ['xls', 'xlsx'] as const) {
    const buf = buildSyntheticSf1Buffer(ext, sampleRows, 'Grade 10');
    const parsed = parseSf1Workbook({buffer: buf});
    assert.equal(parsed.effectiveGradeLevel, 'Grade 10');
    assert.equal(parsed.rows.length, 2);
    assert.equal(parsed.rows[0].lrn, '009876543210');
    assert.equal(parsed.rows[0].birthDate, '2010-05-10');
    assert.equal(parsed.rows[0].sex, 'Male');
    assert.equal(parsed.rows[0].validationError, null);
    assert.ok(parsed.rows[1].validationError?.includes('birth date'));
  }

  assert.throws(() => parseSf1Workbook({buffer: Buffer.from('not-an-excel-file')}));
});

test('Preview masks LRNs, detects duplicates/conflicts, commits idempotently, and integrates with registration', async () => {
  const store = makeStore();
  seedAdmin(store.rows);

  const sampleRows = [
    ['', '009876543210', 'Dela Cruz, Juan Santos', '', '', '', 'M', '05/10/2010', '', '', '', '', '', '', '', '', '', '', '', 'Dela Cruz, Pedro', '', 'Santos, Maria', '', '', '', '09171234567'],
    ['', '009876543210', 'Dela Cruz, Juan Santos', '', '', '', 'M', '05/10/2010', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', ''],
  ];
  const xlsxBuf = buildSyntheticSf1Buffer('xlsx', sampleRows, 'Grade 10');

  await withDeps(store, async () => {
    await assert.rejects(
      () =>
        previewSchoolRosterImport.run(
          authReq('auth-1', {
            fileName: 'sf1.xlsx',
            fileBase64: xlsxBuf.toString('base64'),
            confirmedGradeLevel: 'Grade 10',
          }),
        ),
      (err: {code?: string}) => err.code === 'permission-denied',
    );

    const preview = (await previewSchoolRosterImport.run(
      authReq('admin-1', {
        fileName: 'sf1.xlsx',
        fileBase64: xlsxBuf.toString('base64'),
        confirmedGradeLevel: 'Grade 10',
      }),
    )) as {
      previewId: string;
      summary: {newCount: number; duplicateCount: number};
      rows: Array<{maskedLrn: string; status: string}>;
    };

    assert.equal(preview.summary.newCount, 1);
    assert.equal(preview.summary.duplicateCount, 1);
    assert.equal(preview.rows[0].maskedLrn, '0098••••3210');
    assert.equal(JSON.stringify(preview).includes('009876543210'), false);

    const commit1 = (await commitSchoolRosterImport.run(
      authReq('admin-1', {previewId: preview.previewId, requestId: 'imp_req_0001'}),
    )) as {
      committedCount: number;
      newCount: number;
      generatedCredentials: Array<{enrollmentCode: string; fullName: string}>;
    };
    assert.equal(commit1.committedCount, 1);
    assert.equal(commit1.newCount, 1);
    assert.equal(commit1.generatedCredentials.length, 1);

    // Idempotent retry
    const commitReplay = (await commitSchoolRosterImport.run(
      authReq('admin-1', {previewId: preview.previewId, requestId: 'imp_req_0001'}),
    )) as {committedCount: number; generatedCredentials: unknown[]};
    assert.equal(commitReplay.committedCount, 1);
    assert.equal(commitReplay.generatedCredentials.length, 0);

    // Verify automatic registration claim evaluation matches imported record
    const rId = rosterLookupId('009876543210', TEST_ROSTER_KEY);
    const rosterDoc = store.rows.get(`schoolRosterClaims/${rId}`)!;
    assert.equal(rosterDoc.gradeLevel, 'Grade 10');

    const enrollmentCode = commit1.generatedCredentials[0].enrollmentCode;
    const codeDigest = rosterCodeDigest(enrollmentCode, TEST_ROSTER_KEY);
    const codeDoc = store.rows.get(`schoolRosterCodes/${codeDigest}`) as {
      rosterId?: string;
      claimedByUid?: string | null;
    };

    const claimOutcome = evaluateRosterClaim({
      roster: rosterDoc as never,
      codeClaim: codeDoc,
      rosterId: rId,
      lrn: '009876543210',
      fullName: 'Juan Santos Dela Cruz',
      birthDate: '2010-05-10',
      enrollmentCode,
      uid: 'stu-new-1',
      key: TEST_ROSTER_KEY,
    });
    assert.equal(claimOutcome, 'auto_approve');

    const missingBirthOutcome = evaluateRosterClaim({
      roster: rosterDoc as never,
      codeClaim: codeDoc,
      rosterId: rId,
      lrn: '009876543210',
      fullName: 'Juan Santos Dela Cruz',
      birthDate: null,
      enrollmentCode,
      uid: 'stu-new-1',
      key: TEST_ROSTER_KEY,
    });
    assert.equal(missingBirthOutcome, 'manual_review');

    // Duplicate claim by a second student rejected/conflict once claimed
    const dupClaim = evaluateRosterClaim({
      roster: {...rosterDoc, claimedByUid: 'stu-new-1'} as never,
      codeClaim: {...codeDoc, claimedByUid: 'stu-new-1'},
      rosterId: rId,
      lrn: '009876543210',
      fullName: 'Juan Santos Dela Cruz',
      enrollmentCode,
      uid: 'stu-other-2',
      key: TEST_ROSTER_KEY,
    });
    assert.equal(dupClaim, 'conflict');

    const history = (await listSchoolRosterImports.run(authReq('admin-1', {}))) as {
      imports: Array<{importId: string; committedCount: number}>;
    };
    assert.equal(history.imports.length, 1);
    assert.equal(history.imports[0].importId, 'imp_req_0001');
  });
});
