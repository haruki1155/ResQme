import assert from 'node:assert/strict';
import test from 'node:test';
import {
  generateSecurePassword,
  provisionMasterAdmin,
  type MasterAdminAuthAdapter,
  type MasterAdminFirestoreAdapter,
} from '../src/staff/master_admin_provisioning';

function makeHarness(options: {failFirestoreWrite?: boolean; existingLock?: boolean} = {}) {
  const users = new Map<string, {uid: string; email: string; password: string; emailVerified: boolean; disabled: boolean}>();
  const docs = new Map<string, Record<string, unknown>>();
  if (options.existingLock) {
    docs.set('masterAdminLocks/school-alpha', {uid: 'existing-master', schoolId: 'school-alpha'});
  }
  const deletedUids: string[] = [];
  let uidCounter = 0;

  const auth: MasterAdminAuthAdapter = {
    async createUser(input) {
      for (const u of users.values()) {
        if (u.email === input.email) {
          throw new Error('auth/email-already-exists');
        }
      }
      const uid = `master-uid-${++uidCounter}`;
      users.set(uid, {
        uid,
        email: input.email,
        password: input.password,
        emailVerified: input.emailVerified,
        disabled: false,
      });
      return {uid};
    },
    async deleteUser(uid) {
      deletedUids.push(uid);
      users.delete(uid);
    },
  };

  const db: MasterAdminFirestoreAdapter = {
    async runTransaction(fn) {
      const staged = new Map<string, Record<string, unknown>>();
      const tx = {
        async get(path: string) {
          const data = docs.get(path);
          return {exists: data !== undefined, data: () => data};
        },
        create(path: string, data: Record<string, unknown>) {
          if (docs.has(path) || staged.has(path)) {
            throw new Error(`Document already exists: ${path}`);
          }
          staged.set(path, data);
        },
      };
      const result = await fn(tx);
      if (options.failFirestoreWrite) {
        throw new Error('simulated-firestore-failure');
      }
      for (const [k, v] of staged.entries()) {
        docs.set(k, v);
      }
      return result;
    },
  };

  return {auth, db, users, docs, deletedUids};
}

test('generateSecurePassword produces high-entropy passwords meeting complexity requirements', () => {
  const pw1 = generateSecurePassword();
  const pw2 = generateSecurePassword();
  assert.notEqual(pw1, pw2);
  assert.ok(pw1.length >= 20);
  assert.match(pw1, /[A-Z]/);
  assert.match(pw1, /[a-z]/);
  assert.match(pw1, /[0-9]/);
  assert.match(pw1, /[!@#$%^&*_-]/);
});

test('provisionMasterAdmin creates unverified Master Admin with server-owned flags and lock', async () => {
  const h = makeHarness();
  const res = await provisionMasterAdmin({
    auth: h.auth,
    db: h.db,
    email: '  Master.Owner@School.EDU.PH ',
    schoolId: 'school-alpha',
  });

  assert.equal(res.email, 'master.owner@school.edu.ph');
  assert.equal(res.schoolId, 'school-alpha');
  assert.ok(res.initialPassword.length >= 20);

  const authUser = h.users.get(res.uid);
  assert.ok(authUser);
  assert.equal(authUser.emailVerified, false);

  const staffDoc = h.docs.get(`staffAccounts/${res.uid}`);
  assert.ok(staffDoc);
  assert.equal(staffDoc.role, 'admin');
  assert.equal(staffDoc.isMasterAdmin, true);
  assert.equal(staffDoc.active, true);
  assert.equal(staffDoc.status, 'active');
  assert.equal(staffDoc.schoolId, 'school-alpha');
  assert.equal(staffDoc.mustChangePassword, true);
  assert.equal(staffDoc.requiresEmailVerification, true);
  assert.equal('password' in staffDoc, false);
  assert.equal('initialPassword' in staffDoc, false);

  const lockDoc = h.docs.get('masterAdminLocks/school-alpha');
  assert.ok(lockDoc);
  assert.equal(lockDoc.uid, res.uid);
});

test('provisionMasterAdmin prevents duplicate Master Admin creation and rolls back Auth user', async () => {
  const h = makeHarness({existingLock: true});
  await assert.rejects(
    () =>
      provisionMasterAdmin({
        auth: h.auth,
        db: h.db,
        email: 'second@school.edu.ph',
        schoolId: 'school-alpha',
      }),
    /already exists/i,
  );
  assert.equal(h.users.size, 0);
  assert.equal(h.deletedUids.length, 1);
});

test('provisionMasterAdmin cleans up Auth user on partial Firestore failure', async () => {
  const h = makeHarness({failFirestoreWrite: true});
  await assert.rejects(
    () =>
      provisionMasterAdmin({
        auth: h.auth,
        db: h.db,
        email: 'owner@school.edu.ph',
        schoolId: 'school-alpha',
      }),
    /simulated-firestore-failure/,
  );
  assert.equal(h.users.size, 0);
  assert.equal(h.deletedUids.length, 1);
  assert.equal(h.docs.size, 0);
});

test('provisionMasterAdmin rejects invalid email or untrusted schoolId before touching Auth', async () => {
  const h = makeHarness();
  await assert.rejects(
    () =>
      provisionMasterAdmin({
        auth: h.auth,
        db: h.db,
        email: 'not-an-email',
        schoolId: 'school-alpha',
      }),
    /invalid email/i,
  );
  await assert.rejects(
    () =>
      provisionMasterAdmin({
        auth: h.auth,
        db: h.db,
        email: 'owner@school.edu.ph',
        schoolId: 'BAD SCHOOL!',
      }),
    /invalid school/i,
  );
  assert.equal(h.users.size, 0);
});
