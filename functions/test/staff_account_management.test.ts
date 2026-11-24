import assert from 'node:assert/strict';
import test from 'node:test';
import {
  changeMyStaffPassword,
  createAuthorizedAccount,
  listAuthorizedAccounts,
  resetAuthorizedPassword,
  revokeAuthorizedDevice,
  setAuthorizedAccountStatus,
  staffManagementDeps,
  syncMasterAdminEmail,
  updateAuthorizedAccount,
  type StaffAdminAuthPort,
} from '../src/staff/staff_account_management';
import {assertStaffAccount} from '../src/staff/staff_authorization';

function makeStore(options: {failNextTx?: boolean} = {}) {
  const rows = new Map<string, Record<string, unknown>>();
  const users = new Map<string, {email: string; password: string; disabled: boolean; revokedTokens: number; displayName: string}>();
  const deletedUids: string[] = [];
  let seq = 0;
  let failTx = options.failNextTx === true;

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
          return {docs};
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
      const result = await fn(tx);
      if (failTx) {
        failTx = false;
        throw new Error('simulated-tx-failure');
      }
      for (const op of ops) op();
      return result;
    },
  };

  const auth: StaffAdminAuthPort = {
    async createUser(input) {
      const uid = `auth-uid-${++seq}`;
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
      const u = users.get(uid) ?? {email: `${uid}@example.test`, password: '', disabled: false, revokedTokens: 0, displayName: ''};
      if (input.password !== undefined) u.password = input.password;
      if (input.disabled !== undefined) u.disabled = input.disabled;
      if (input.displayName !== undefined) u.displayName = input.displayName;
      users.set(uid, u);
    },
    async revokeRefreshTokens(uid) {
      const u = users.get(uid);
      if (u) u.revokedTokens += 1;
    },
    async deleteUser(uid) {
      deletedUids.push(uid);
      users.delete(uid);
    },
  };

  return {db, auth, rows, users, deletedUids};
}

function req(uid: string, data: unknown = {}, opts: {emailVerified?: boolean; email?: string; authTime?: number} = {}) {
  return {
    auth: {
      uid,
      token: {
        auth_time: opts.authTime ?? Math.floor(Date.now() / 1000),
        email_verified: opts.emailVerified ?? true,
        email: opts.email ?? `${uid}@school.edu.ph`,
      },
    },
    data,
  } as never;
}

test('unverified Master Admin and first-login Authorized users are blocked from privileged operations', () => {
  assert.throws(
    () =>
      assertStaffAccount(
        {role: 'admin', schoolId: 'school-a', active: true, isMasterAdmin: true, requiresEmailVerification: true, mustChangePassword: false},
        ['admin'],
        {emailVerified: false},
      ),
    /Email verification is required/,
  );
  assert.throws(
    () =>
      assertStaffAccount(
        {role: 'authorized', schoolId: 'school-a', active: true, mustChangePassword: true, requiresEmailVerification: false},
        ['admin', 'authorized'],
        {emailVerified: false},
      ),
    /Password setup is required/,
  );
  assert.throws(
    () =>
      assertStaffAccount(
        {role: 'authorized', schoolId: 'school-a', active: true, status: 'suspended'},
        ['admin', 'authorized'],
      ),
    /Staff access is unavailable/,
  );
});

test('Master Admin creates Authorized account without email verification and never stores password in Firestore', async (t) => {
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
  t.mock.method(staffManagementDeps, 'db', () => s.db as never);
  t.mock.method(staffManagementDeps, 'auth', () => s.auth);

  // Unverified Master Admin is denied
  await assert.rejects(
    () => createAuthorizedAccount.run(req('master-1', {fullName: 'Nurse Ana', position: 'School Nurse'}, {emailVerified: false})),
    /Email verification is required/,
  );

  // Verified Master Admin succeeds
  const created = await createAuthorizedAccount.run(
    req('master-1', {fullName: 'Nurse Ana', position: 'School Nurse'}, {emailVerified: true}),
  );
  assert.match(created.loginId, /^AUTH-[A-Z0-9]{8}$/);
  assert.ok(created.temporaryPassword.length >= 16);
  assert.equal(created.role, 'authorized');
  assert.equal(created.schoolId, 'school-a');

  const doc = s.rows.get(`staffAccounts/${created.uid}`)!;
  assert.equal(doc.role, 'authorized');
  assert.equal(doc.isMasterAdmin, false);
  assert.equal(doc.mustChangePassword, true);
  assert.equal(doc.requiresEmailVerification, false);
  assert.equal('temporaryPassword' in doc, false);
  assert.equal('password' in doc, false);

  // Audit created without password
  const audits = [...s.rows.entries()].filter(([k]) => k.startsWith('staffManagementAudits/'));
  assert.equal(audits.length, 1);
  assert.equal(audits[0][1].action, 'create_authorized_account');
  assert.equal('temporaryPassword' in audits[0][1], false);
});

test('partial failure during Authorized creation deletes orphaned Auth user', async (t) => {
  const s = makeStore({failNextTx: true});
  s.rows.set('staffAccounts/master-1', {
    role: 'admin',
    isMasterAdmin: true,
    active: true,
    status: 'active',
    schoolId: 'school-a',
    mustChangePassword: false,
    requiresEmailVerification: true,
  });
  t.mock.method(staffManagementDeps, 'db', () => s.db as never);
  t.mock.method(staffManagementDeps, 'auth', () => s.auth);

  await assert.rejects(
    () => createAuthorizedAccount.run(req('master-1', {fullName: 'Guard Ben', position: 'Security Officer'})),
    /Unable to finalize/,
  );
  assert.equal(s.users.size, 0);
  assert.equal(s.deletedUids.length, 1);
});

test('Authorized users and students cannot manage accounts; cross-school and Master Admin self-suspension are denied', async (t) => {
  const s = makeStore();
  s.rows.set('staffAccounts/master-a', {
    role: 'admin',
    isMasterAdmin: true,
    active: true,
    status: 'active',
    schoolId: 'school-a',
    mustChangePassword: false,
    requiresEmailVerification: true,
  });
  s.rows.set('staffAccounts/auth-a', {
    role: 'authorized',
    isMasterAdmin: false,
    active: true,
    status: 'active',
    schoolId: 'school-a',
    mustChangePassword: false,
    requiresEmailVerification: false,
    fullName: 'Staff A',
    position: 'Nurse',
    loginId: 'AUTH-AAAA1111',
  });
  s.rows.set('staffAccounts/auth-b', {
    role: 'authorized',
    isMasterAdmin: false,
    active: true,
    status: 'active',
    schoolId: 'school-b',
    mustChangePassword: false,
    requiresEmailVerification: false,
    fullName: 'Staff B',
    position: 'Nurse',
    loginId: 'AUTH-BBBB2222',
  });
  t.mock.method(staffManagementDeps, 'db', () => s.db as never);
  t.mock.method(staffManagementDeps, 'auth', () => s.auth);

  // Authorized caller cannot create or suspend
  await assert.rejects(() => createAuthorizedAccount.run(req('auth-a', {fullName: 'X Y', position: 'Guard'})));
  await assert.rejects(() => setAuthorizedAccountStatus.run(req('auth-a', {targetUid: 'auth-a', action: 'suspend'})));
  // Student caller (no staffAccounts doc) cannot list
  await assert.rejects(() => listAuthorizedAccounts.run(req('student-1', {})));
  // Master Admin cannot suspend or revoke itself
  await assert.rejects(() => setAuthorizedAccountStatus.run(req('master-a', {targetUid: 'master-a', action: 'suspend'})));
  await assert.rejects(() => setAuthorizedAccountStatus.run(req('master-a', {targetUid: 'master-a', action: 'revoke'})));
  // Master Admin cannot modify cross-school Authorized account
  await assert.rejects(() => updateAuthorizedAccount.run(req('master-a', {targetUid: 'auth-b', fullName: 'Hacked', position: 'Boss'})));
  await assert.rejects(() => setAuthorizedAccountStatus.run(req('master-a', {targetUid: 'auth-b', action: 'suspend'})));

  // List returns only same-school Authorized accounts
  const listed = await listAuthorizedAccounts.run(req('master-a', {search: 'staff'}));
  assert.equal(listed.accounts.length, 1);
  assert.equal(listed.accounts[0].uid, 'auth-a');
});

test('suspend, reset password, revoke device, and permanent revoke invalidate devices, tokens, and challenges', async (t) => {
  const s = makeStore();
  s.rows.set('staffAccounts/master-a', {
    role: 'admin',
    isMasterAdmin: true,
    active: true,
    status: 'active',
    schoolId: 'school-a',
    mustChangePassword: false,
    requiresEmailVerification: true,
  });
  s.rows.set('staffAccounts/auth-a', {
    role: 'authorized',
    isMasterAdmin: false,
    active: true,
    status: 'active',
    schoolId: 'school-a',
    mustChangePassword: false,
    requiresEmailVerification: false,
    fullName: 'Staff A',
    position: 'Nurse',
    loginId: 'AUTH-AAAA1111',
  });
  s.rows.set('staffTier2Devices/auth-a', {status: 'active', keyVersion: 1});
  s.rows.set('staffTier2Challenges/ch-1', {staffUid: 'auth-a', consumedAt: null});
  s.users.set('auth-a', {email: 'auth-aaaa1111@staff.resqme.internal', password: 'OldPassword!123', disabled: false, revokedTokens: 0, displayName: 'Staff A'});

  t.mock.method(staffManagementDeps, 'db', () => s.db as never);
  t.mock.method(staffManagementDeps, 'auth', () => s.auth);

  // Reset password forces mustChangePassword, revokes tokens, invalidates challenges
  const reset = await resetAuthorizedPassword.run(req('master-a', {targetUid: 'auth-a'}));
  assert.ok(reset.temporaryPassword.length >= 16);
  assert.equal(s.rows.get('staffAccounts/auth-a')!.mustChangePassword, true);
  assert.equal(s.users.get('auth-a')!.revokedTokens, 1);
  assert.ok(s.rows.get('staffTier2Challenges/ch-1')!.consumedAt != null);

  // Authorized user completes first-login password setup
  await changeMyStaffPassword.run(req('auth-a', {newPassword: 'NewStrongPass!2026'}));
  assert.equal(s.rows.get('staffAccounts/auth-a')!.mustChangePassword, false);

  // Revoke device increments keyVersion
  await revokeAuthorizedDevice.run(req('master-a', {targetUid: 'auth-a'}));
  assert.equal(s.rows.get('staffTier2Devices/auth-a')!.status, 'revoked');
  assert.equal(s.rows.get('staffTier2Devices/auth-a')!.keyVersion, 2);

  // Suspend disables user and revokes tokens; reactivate re-enables
  await setAuthorizedAccountStatus.run(req('master-a', {targetUid: 'auth-a', action: 'suspend'}));
  assert.equal(s.rows.get('staffAccounts/auth-a')!.active, false);
  assert.equal(s.users.get('auth-a')!.disabled, true);
  assert.equal(s.users.get('auth-a')!.revokedTokens, 2);

  await setAuthorizedAccountStatus.run(req('master-a', {targetUid: 'auth-a', action: 'reactivate'}));
  assert.equal(s.rows.get('staffAccounts/auth-a')!.active, true);
  assert.equal(s.users.get('auth-a')!.disabled, false);

  // Permanent revoke cannot be reactivated
  await setAuthorizedAccountStatus.run(req('master-a', {targetUid: 'auth-a', action: 'revoke'}));
  assert.equal(s.rows.get('staffAccounts/auth-a')!.status, 'revoked');
  await assert.rejects(
    () => setAuthorizedAccountStatus.run(req('master-a', {targetUid: 'auth-a', action: 'reactivate'})),
    /Permanently revoked/,
  );

  // Master Admin verified email sync succeeds only when verified
  await assert.rejects(
    () => syncMasterAdminEmail.run(req('master-a', {}, {emailVerified: false})),
    /Email verification is required/,
  );
  const synced = await syncMasterAdminEmail.run(req('master-a', {}, {emailVerified: true, email: 'NewOwner@School.EDU.PH'}));
  assert.equal(synced.email, 'newowner@school.edu.ph');
});
