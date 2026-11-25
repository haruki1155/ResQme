import assert from 'node:assert/strict';
import test from 'node:test';
import {staffManagementDeps, type StaffAdminAuthPort} from '../src/staff/staff_account_management';
import {listSchoolActivityLogs} from '../src/staff/staff_activity_logs';

function makeStore() {
  const rows = new Map<string, Record<string, unknown>>();
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
  };
  return {rows, db};
}

function authReq(uid: string | undefined, data: unknown, emailVerified = true) {
  return {
    auth: uid ? {uid, token: {email_verified: emailVerified}} : undefined,
    data,
    rawRequest: {},
  } as never;
}

function seedAudits(rows: Map<string, Record<string, unknown>>) {
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

  rows.set('staffManagementAudits/a1', {
    schoolId: '000000123',
    actorUid: 'admin-1',
    actorRole: 'admin',
    action: 'replace_student_qr',
    targetUid: 'stu-1',
    reason: 'lost',
    method: 'biometric',
    credentialVersion: 2,
    outcome: 'allowed',
    // Sensitive fields that MUST be redacted if ever present
    lrn: '123456789012',
    payload: 'resqme:v1:SECRET',
    recordedAt: new Date('2026-11-25T10:00:00Z'),
  });
  rows.set('staffManagementAudits/a2', {
    schoolId: '000000123',
    actorUid: 'admin-1',
    actorRole: 'admin',
    action: 'reveal_student_lrn',
    targetType: 'student',
    targetId: 'stu-1',
    method: 'password',
    outcome: 'allowed',
    recordedAt: new Date('2026-11-24T09:00:00Z'),
  });
  rows.set('tier2AccessAudits/t1', {
    schoolId: '000000123',
    actorUid: 'auth-1',
    actorRole: 'authorized',
    targetUid: 'stu-1',
    purpose: 'emergency_response',
    outcome: 'denied',
    reasonCode: 'target_ineligible_or_qr_changed',
    allergies: {state: 'listed', details: 'Peanuts'},
    recordedAt: new Date('2026-11-25T11:00:00Z'),
  });
  rows.set('staffManagementAudits/other-school', {
    schoolId: '999999999',
    actorUid: 'admin-other',
    actorRole: 'admin',
    action: 'create_authorized_account',
    targetUid: 'auth-other',
    outcome: 'allowed',
    recordedAt: new Date('2026-11-25T12:00:00Z'),
  });
}

function withDeps(store: ReturnType<typeof makeStore>, fn: () => Promise<void>) {
  const prevDb = staffManagementDeps.db;
  const prevAuth = staffManagementDeps.auth;
  staffManagementDeps.db = (() => store.db as never) as never;
  staffManagementDeps.auth = (() => ({}) as StaffAdminAuthPort) as never;
  return fn().finally(() => {
    staffManagementDeps.db = prevDb;
    staffManagementDeps.auth = prevAuth;
  });
}

test('Master Admin lists school-scoped newest-first logs with strict redaction', async () => {
  const store = makeStore();
  seedAudits(store.rows);

  await withDeps(store, async () => {
    const res = (await listSchoolActivityLogs.run(authReq('admin-1', {}))) as {
      entries: Array<Record<string, unknown>>;
      nextCursor: string | null;
      totalMatched: number;
    };
    assert.equal(res.totalMatched, 3);
    assert.deepEqual(
      res.entries.map((e) => e.id),
      ['t1', 'a1', 'a2'],
    );
    const json = JSON.stringify(res);
    assert.equal(json.includes('123456789012'), false);
    assert.equal(json.includes('resqme:v1:SECRET'), false);
    assert.equal(json.includes('Peanuts'), false);
    assert.equal(json.includes('other-school'), false);
  });
});

test('Supports category, outcome, date-range, actor filtering and cursor pagination', async () => {
  const store = makeStore();
  seedAudits(store.rows);

  await withDeps(store, async () => {
    const tier2 = (await listSchoolActivityLogs.run(
      authReq('admin-1', {category: 'tier2', outcome: 'denied'}),
    )) as {entries: Array<{id: string}>};
    assert.deepEqual(tier2.entries.map((e) => e.id), ['t1']);

    const paged1 = (await listSchoolActivityLogs.run(
      authReq('admin-1', {limit: 2}),
    )) as {entries: Array<{id: string}>; nextCursor: string | null};
    assert.deepEqual(paged1.entries.map((e) => e.id), ['t1', 'a1']);
    assert.ok(paged1.nextCursor);

    const paged2 = (await listSchoolActivityLogs.run(
      authReq('admin-1', {limit: 2, cursor: paged1.nextCursor}),
    )) as {entries: Array<{id: string}>; nextCursor: string | null};
    assert.deepEqual(paged2.entries.map((e) => e.id), ['a2']);
    assert.equal(paged2.nextCursor, null);

    const dateFiltered = (await listSchoolActivityLogs.run(
      authReq('admin-1', {startDate: '2026-11-25', endDate: '2026-11-25', actorUid: 'admin-1'}),
    )) as {entries: Array<{id: string}>};
    assert.deepEqual(dateFiltered.entries.map((e) => e.id), ['a1']);
  });
});

test('Denies authorized personnel, students, and unauthenticated callers', async () => {
  const store = makeStore();
  seedAudits(store.rows);

  await withDeps(store, async () => {
    await assert.rejects(
      () => listSchoolActivityLogs.run(authReq(undefined, {})),
      (err: {code?: string}) => err.code === 'unauthenticated',
    );
    await assert.rejects(
      () => listSchoolActivityLogs.run(authReq('auth-1', {})),
      (err: {code?: string}) => err.code === 'permission-denied',
    );
    await assert.rejects(
      () => listSchoolActivityLogs.run(authReq('student-1', {})),
      (err: {code?: string}) => err.code === 'permission-denied',
    );
  });
});
