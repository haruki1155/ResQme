import assert from 'node:assert/strict';
import test from 'node:test';
import * as onboardingAuth from '../src/onboarding/authorization';
import {getStaffAccess} from '../src/staff/get_staff_access';
import {
  staffManagementDeps,
  syncMasterAdminEmail,
  type StaffAdminAuthPort,
} from '../src/staff/staff_account_management';
import {listSchoolActivityLogs} from '../src/staff/staff_activity_logs';
import {
  listSchoolRoster,
  listSchoolStudents,
  setStudentAccountStatus,
} from '../src/staff/staff_student_management';

function makeStore() {
  const rows = new Map<string, Record<string, unknown>>();
  const users = new Map<
    string,
    {email: string; password: string; disabled: boolean; revokedTokens: number; displayName: string}
  >();

  const docRef = (path: string) => ({
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
    async update(patch: Record<string, unknown>) {
      const cur = rows.get(path);
      if (!cur) throw new Error(`Missing doc ${path}`);
      rows.set(path, {...cur, ...patch});
    },
    collection(sub: string) {
      return {
        doc(id: string) {
          return docRef(`${path}/${sub}/${id}`);
        },
      };
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
    async runTransaction<T>(fn: (tx: unknown) => Promise<T>): Promise<T> {
      const ops: Array<() => void> = [];
      const tx = {
        async get(ref: {path: string}) {
          const data = rows.get(ref.path);
          return {
            exists: data !== undefined,
            data: () => data,
            get: (field: string) => data?.[field],
          };
        },
        create(ref: {path: string}, data: Record<string, unknown>) {
          if (rows.has(ref.path)) throw new Error(`Already exists: ${ref.path}`);
          ops.push(() => rows.set(ref.path, {...data}));
        },
        update(ref: {path: string}, patch: Record<string, unknown>) {
          ops.push(() => {
            const cur = rows.get(ref.path);
            if (!cur) throw new Error(`Missing doc ${ref.path}`);
            rows.set(ref.path, {...cur, ...patch});
          });
        },
        set(ref: {path: string}, data: Record<string, unknown>, opts?: {merge?: boolean}) {
          ops.push(() => {
            const cur = opts?.merge ? (rows.get(ref.path) ?? {}) : {};
            rows.set(ref.path, {...cur, ...data});
          });
        },
      };
      const res = await fn(tx);
      for (const op of ops) op();
      return res;
    },
  };

  const auth: StaffAdminAuthPort = {
    async createUser(input) {
      const uid = `u-${users.size + 1}`;
      users.set(uid, {
        email: input.email,
        password: input.password,
        disabled: false,
        revokedTokens: 0,
        displayName: input.displayName,
      });
      return {uid};
    },
    async updateUser(uid, input) {
      const u = users.get(uid) ?? {
        email: `${uid}@student.test`,
        password: '',
        disabled: false,
        revokedTokens: 0,
        displayName: '',
      };
      if (input.disabled !== undefined) u.disabled = input.disabled;
      users.set(uid, u);
    },
    async revokeRefreshTokens(uid) {
      const u = users.get(uid);
      if (u) u.revokedTokens += 1;
    },
    async deleteUser(uid) {
      users.delete(uid);
    },
  };

  return {rows, users, db, auth};
}

function req(uid: string, data: unknown) {
  return {
    auth: {
      uid,
      token: {
        auth_time: Math.floor(Date.now() / 1000),
        email_verified: true,
        email: `${uid}@school.edu.ph`,
      },
    },
    data,
  } as never;
}

test('getStaffAccess and syncMasterAdminEmail tolerate null or undefined request.data', async (t) => {
  const s = makeStore();
  s.rows.set('staffAccounts/master-1', {
    role: 'admin',
    isMasterAdmin: true,
    active: true,
    status: 'active',
    schoolId: 'school-a',
    mustChangePassword: false,
    requiresEmailVerification: true,
    fullName: 'Principal Maria',
  });

  t.mock.method(onboardingAuth, 'onboardingDatabase', () => s.db as never);
  t.mock.method(staffManagementDeps, 'db', () => s.db as never);

  const accessFromNull = await getStaffAccess.run(req('master-1', null));
  assert.equal(accessFromNull.schoolId, 'school-a');
  assert.equal(accessFromNull.isMasterAdmin, true);

  const syncedFromNull = await syncMasterAdminEmail.run(req('master-1', null));
  assert.equal(syncedFromNull.emailVerified, true);
});

test('listSchoolStudents keyset cursor survives concurrent status mutation of the boundary student', async (t) => {
  const s = makeStore();
  s.rows.set('staffAccounts/master-1', {
    role: 'admin',
    isMasterAdmin: true,
    active: true,
    status: 'active',
    schoolId: 'school-a',
    mustChangePassword: false,
    requiresEmailVerification: true,
  });

  for (const [uid, fullName, lrn] of [
    ['stu-a', 'Alonzo, Maria', '000000000001'],
    ['stu-b', 'Bautista, Jose', '000000000002'],
    ['stu-c', 'Cruz, Sofia', '000000000003'],
  ] as const) {
    s.rows.set(`studentProfiles/${uid}`, {
      schemaVersion: 1,
      fullName,
      ageYearsAtRegistration: 18,
      lrn,
      status: 'pending_review',
      schoolAssignmentStatus: 'assigned',
      schoolId: 'school-a',
      schoolApprovalStatus: 'approved',
      schoolVerificationOutcome: 'verified',
      medicalStatus: 'complete',
      medicalRevision: 1,
    });
  }

  t.mock.method(staffManagementDeps, 'db', () => s.db as never);
  t.mock.method(staffManagementDeps, 'auth', () => s.auth);

  const page1 = await listSchoolStudents.run(
    req('master-1', {statusFilter: 'verified', limit: 2}),
  );
  assert.deepEqual(
    page1.students.map((st) => st.uid),
    ['stu-a', 'stu-b'],
  );
  assert.ok(page1.nextCursor);

  // Boundary student stu-b becomes disabled before page 2 is requested!
  await setStudentAccountStatus.run(
    req('master-1', {studentUid: 'stu-b', action: 'disable'}),
  );

  // Page 2 must NOT throw 'Invalid pagination cursor.' and must return stu-c!
  const page2 = await listSchoolStudents.run(
    req('master-1', {statusFilter: 'verified', limit: 2, cursor: page1.nextCursor}),
  );
  assert.deepEqual(
    page2.students.map((st) => st.uid),
    ['stu-c'],
  );
  assert.equal(page2.nextCursor, null);
});

test('listSchoolRoster keyset cursor survives boundary grade/entry update between pages', async (t) => {
  const s = makeStore();
  s.rows.set('staffAccounts/master-1', {
    role: 'admin',
    isMasterAdmin: true,
    active: true,
    status: 'active',
    schoolId: 'school-a',
    mustChangePassword: false,
    requiresEmailVerification: true,
  });

  s.rows.set('schoolRosterClaims/r-1', {
    schoolId: 'school-a',
    displayName: 'Aquino, Lea',
    lrn: '000000000011',
    gradeLevel: 'Grade 10',
  });
  s.rows.set('schoolRosterClaims/r-2', {
    schoolId: 'school-a',
    displayName: 'Dizon, Paolo',
    lrn: '000000000012',
    gradeLevel: 'Grade 10',
  });
  s.rows.set('schoolRosterClaims/r-3', {
    schoolId: 'school-a',
    displayName: 'Gomez, Nina',
    lrn: '000000000013',
    gradeLevel: 'Grade 10',
  });

  t.mock.method(staffManagementDeps, 'db', () => s.db as never);
  t.mock.method(staffManagementDeps, 'auth', () => s.auth);

  const page1 = await listSchoolRoster.run(
    req('master-1', {gradeFilter: 'Grade 10', limit: 2}),
  );
  assert.deepEqual(
    page1.entries.map((e) => e.rosterId),
    ['r-1', 'r-2'],
  );
  assert.ok(page1.nextCursor);

  // r-2 moves to Grade 11 before page 2 is fetched
  s.rows.set('schoolRosterClaims/r-2', {
    schoolId: 'school-a',
    displayName: 'Dizon, Paolo',
    lrn: '000000000012',
    gradeLevel: 'Grade 11',
  });

  const page2 = await listSchoolRoster.run(
    req('master-1', {gradeFilter: 'Grade 10', limit: 2, cursor: page1.nextCursor}),
  );
  assert.deepEqual(
    page2.entries.map((e) => e.rosterId),
    ['r-3'],
  );
  assert.equal(page2.nextCursor, null);
});

test('listSchoolActivityLogs cursor deterministically tie-breaks across collections and survives boundary removal', async (t) => {
  const s = makeStore();
  s.rows.set('staffAccounts/master-1', {
    role: 'admin',
    isMasterAdmin: true,
    active: true,
    status: 'active',
    schoolId: 'school-a',
    mustChangePassword: false,
    requiresEmailVerification: true,
  });

  const sameInstant = new Date('2026-11-25T10:00:00.000Z');
  // Same ID 'same-id' and same timestamp in BOTH audit collections!
  s.rows.set('staffManagementAudits/same-id', {
    schoolId: 'school-a',
    actorUid: 'master-1',
    actorRole: 'admin',
    action: 'verify_student_account',
    targetUid: 'stu-1',
    outcome: 'allowed',
    recordedAt: sameInstant,
  });
  s.rows.set('tier2AccessAudits/same-id', {
    schoolId: 'school-a',
    actorUid: 'auth-1',
    actorRole: 'authorized',
    targetUid: 'stu-1',
    purpose: 'emergency_response',
    outcome: 'allowed',
    recordedAt: sameInstant,
  });
  s.rows.set('staffManagementAudits/older-id', {
    schoolId: 'school-a',
    actorUid: 'master-1',
    actorRole: 'admin',
    action: 'create_authorized_account',
    targetUid: 'auth-1',
    outcome: 'allowed',
    recordedAt: new Date('2026-11-25T09:00:00.000Z'),
  });

  t.mock.method(staffManagementDeps, 'db', () => s.db as never);
  t.mock.method(staffManagementDeps, 'auth', () => s.auth);

  const page1 = await listSchoolActivityLogs.run(req('master-1', {limit: 1}));
  assert.equal(page1.entries.length, 1);
  assert.ok(page1.nextCursor);

  const page2 = await listSchoolActivityLogs.run(
    req('master-1', {limit: 1, cursor: page1.nextCursor}),
  );
  assert.equal(page2.entries.length, 1);
  // Must NOT skip the second record that shared the exact same timestamp and doc id across collections!
  assert.notEqual(
    `${page2.entries[0].sourceCollection}:${page2.entries[0].id}`,
    `${page1.entries[0].sourceCollection}:${page1.entries[0].id}`,
  );
  assert.ok(page2.nextCursor);

  const page3 = await listSchoolActivityLogs.run(
    req('master-1', {limit: 1, cursor: page2.nextCursor}),
  );
  assert.equal(page3.entries[0].id, 'older-id');
});
