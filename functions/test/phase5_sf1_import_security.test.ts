import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import test from 'node:test';
import * as XLSX from 'xlsx';
import {parseSf1Workbook} from '../src/school/sf1_parser';
import {
  commitSchoolRosterImport,
  previewSchoolRosterImport,
} from '../src/school/sf1_roster_import';
import {staffManagementDeps} from '../src/staff/staff_account_management';

const TEST_ROSTER_KEY = '0123456789abcdef0123456789abcdef0123456789abcdef';

function buildFictionalSf1Buffer(bookType: 'xlsx' | 'xls'): Buffer {
  const aoa = [
    ['School Form 1 (SF 1) School Register'],
    ['School Name', 'Fictional Pilot High School', '', 'School ID', '300001'],
    ['School Year', '2026-2027', '', 'Grade Level', 'Grade 10', 'Section', 'Rizal'],
    [],
    ['LRN', 'NAME (Last Name, First Name, Middle Name)', 'Sex (M/F)', 'BIRTH DATE (mm/dd/yyyy)'],
    ['009876543210', 'Dela Cruz, Juan, Santos', 'M', '05/10/2010'],
    ['001122334455', 'Reyes, Maria, Clara', 'F', '08/22/2009'],
  ];
  const ws = XLSX.utils.aoa_to_sheet(aoa);
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, ws, 'SF1');
  return XLSX.write(wb, {type: 'buffer', bookType}) as Buffer;
}

test('Phase 5: parseSf1Workbook accepts valid .xlsx and .xls magic bytes and rejects disguised HTML/CSV/macro payloads', () => {
  for (const format of ['xlsx', 'xls'] as const) {
    const buf = buildFictionalSf1Buffer(format);
    const parsed = parseSf1Workbook({buffer: buf, fileName: `sf1_test.${format}`});
    assert.equal(parsed.effectiveGradeLevel, 'Grade 10');
    assert.equal(parsed.rows.length, 2);
    assert.equal(parsed.rows[0].lrn, '009876543210');
    assert.equal(parsed.rows[0].birthDate, '2010-05-10');
  }

  // Disguised HTML renamed to .xls must be rejected before parser execution
  const htmlDisguised = Buffer.from('<html><table><tr><td>LRN</td></tr></table></html>', 'utf8');
  assert.throws(
    () => parseSf1Workbook({buffer: htmlDisguised, fileName: 'fake.xls'}),
    (err: any) => err.code === 'invalid-argument' && /genuine \.xls or \.xlsx/i.test(err.message),
  );

  // Disguised CSV renamed to .xlsx must be rejected
  const csvDisguised = Buffer.from('LRN,NAME,BIRTH DATE\n009876543210,"Dela Cruz, Juan",05/10/2010\n', 'utf8');
  assert.throws(
    () => parseSf1Workbook({buffer: csvDisguised, fileName: 'fake.xlsx'}),
    (err: any) => err.code === 'invalid-argument',
  );

  // Macro-containing ZIP signature (`vbaProject.bin`) must be rejected
  const macroZip = Buffer.concat([
    Buffer.from([0x50, 0x4b, 0x03, 0x04]),
    Buffer.from('xl/vbaProject.bin', 'utf8'),
  ]);
  assert.throws(
    () => parseSf1Workbook({buffer: macroZip, fileName: 'macro.xlsx'}),
    (err: any) => err.code === 'invalid-argument' && /macro/i.test(err.message),
  );
});

test('Phase 5: preview-to-commit binds fileSha256, enforces privacyNoticeAcknowledged, scrubs preview PII after commit, and cleans expired previews', async (t) => {
  const prevKey = process.env.RESQME_SCHOOL_ROSTER_HMAC_KEY;
  process.env.RESQME_SCHOOL_ROSTER_HMAC_KEY = TEST_ROSTER_KEY;
  t.after(() => {
    if (prevKey === undefined) delete process.env.RESQME_SCHOOL_ROSTER_HMAC_KEY;
    else process.env.RESQME_SCHOOL_ROSTER_HMAC_KEY = prevKey;
  });

  const rows = new Map<string, Record<string, unknown>>([
    [
      'staffAccounts/admin-sf1',
      {
        role: 'admin',
        isMasterAdmin: true,
        active: true,
        status: 'active',
        schoolId: 'school-sf1',
        mustChangePassword: false,
        requiresEmailVerification: true,
      },
    ],
    // Pre-existing expired preview that must be purged opportunistically
    [
      'schoolRosterImportPreviews/expired00000000000000000000000001',
      {
        schoolId: 'school-sf1',
        actorUid: 'admin-sf1',
        consumed: false,
        expiresAt: new Date(Date.now() - 60_000),
        rows: [{fullName: 'Stale Temp Student'}],
      },
    ],
  ]);

  const docRef = (path: string) => ({
    path,
    id: path.split('/').pop()!,
    async get() {
      const d = rows.get(path);
      return {
        id: path.split('/').pop()!,
        exists: d !== undefined,
        data: () => (d ? {...d} : undefined),
        get: (k: string) => d?.[k],
      };
    },
    async create(data: Record<string, unknown>) {
      rows.set(path, {...data});
    },
    async delete() {
      rows.delete(path);
    },
  });

  const db = {
    doc: docRef,
    collection(col: string) {
      const filters: Array<[string, unknown]> = [];
      const q = {
        where(f: string, op: string, v: unknown) {
          assert.equal(op, '==');
          filters.push([f, v]);
          return q;
        },
        async get() {
          const docs = [...rows.entries()]
            .filter(([p]) => p.startsWith(`${col}/`) && p.split('/').length === 2)
            .filter(([, d]) => filters.every(([f, v]) => d[f] === v))
            .map(([p, d]) => ({
              id: p.split('/').pop()!,
              ref: docRef(p),
              data: () => ({...d}),
              get: (k: string) => d[k],
            }));
          return {docs};
        },
      };
      return q;
    },
    async runTransaction<T>(fn: (tx: any) => Promise<T>): Promise<T> {
      const writes: Array<() => void> = [];
      const tx = {
        get: (ref: {path: string}) => docRef(ref.path).get(),
        create: (ref: {path: string}, d: Record<string, unknown>) =>
          writes.push(() => rows.set(ref.path, {...d})),
        set: (ref: {path: string}, d: Record<string, unknown>, opts?: {merge?: boolean}) =>
          writes.push(() =>
            rows.set(ref.path, {...(opts?.merge ? rows.get(ref.path) ?? {} : {}), ...d}),
          ),
        update: (ref: {path: string}, patch: Record<string, unknown>) =>
          writes.push(() => rows.set(ref.path, {...(rows.get(ref.path) ?? {}), ...patch})),
      };
      const out = await fn(tx);
      for (const w of writes) w();
      return out;
    },
  };

  t.mock.method(staffManagementDeps, 'db', () => db as never);

  const xlsxBuf = buildFictionalSf1Buffer('xlsx');
  const expectedSha = createHash('sha256').update(xlsxBuf).digest('hex');

  const preview = (await previewSchoolRosterImport.run({
    auth: {uid: 'admin-sf1', token: {email_verified: true}},
    data: {
      fileName: 'fictional_sf1.xlsx',
      fileBase64: xlsxBuf.toString('base64'),
    },
  } as never)) as {
    previewId: string;
    fileSha256: string;
    rows: Array<{maskedLrn: string | null}>;
  };

  assert.equal(preview.fileSha256, expectedSha);
  assert.equal(
    rows.has('schoolRosterImportPreviews/expired00000000000000000000000001'),
    false,
  );
  assert.equal(JSON.stringify(preview).includes('009876543210'), false);

  // Mismatched expectedFileSha256 must be rejected
  await assert.rejects(
    () =>
      commitSchoolRosterImport.run({
        auth: {uid: 'admin-sf1', token: {email_verified: true}},
        data: {
          previewId: preview.previewId,
          requestId: 'sf1_req_bad_sha_01',
          expectedFileSha256: '0'.repeat(64),
          privacyNoticeAcknowledged: true,
        },
      } as never),
    {code: 'failed-precondition'},
  );

  // Unacknowledged privacy notice must be rejected
  await assert.rejects(
    () =>
      commitSchoolRosterImport.run({
        auth: {uid: 'admin-sf1', token: {email_verified: true}},
        data: {
          previewId: preview.previewId,
          requestId: 'sf1_req_no_ack_01',
          expectedFileSha256: expectedSha,
          privacyNoticeAcknowledged: false,
        },
      } as never),
    {code: 'failed-precondition'},
  );

  // Valid bound commit succeeds and scrubs temporary PII rows from preview doc
  const committed = (await commitSchoolRosterImport.run({
    auth: {uid: 'admin-sf1', token: {email_verified: true}},
    data: {
      previewId: preview.previewId,
      requestId: 'sf1_req_ok_0001',
      expectedFileSha256: expectedSha,
      privacyNoticeAcknowledged: true,
    },
  } as never)) as {committedCount: number; status: string};
  assert.equal(committed.status, 'completed');
  assert.equal(committed.committedCount, 2);

  const consumedPreview = rows.get(`schoolRosterImportPreviews/${preview.previewId}`)!;
  assert.equal(consumedPreview.consumed, true);
  assert.deepEqual(consumedPreview.rows, []);
});
