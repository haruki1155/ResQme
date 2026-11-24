import assert from 'node:assert/strict';
import test from 'node:test';
import type {CallableRequest} from 'firebase-functions/v2/https';
import {assertStaffAccount, requireStaff} from '../src/staff/staff_authorization';
import {getStaffAccess} from '../src/staff/get_staff_access';

const authorization = require('../src/onboarding/authorization') as typeof import('../src/onboarding/authorization');

function mockDb(entries: Array<[string, Record<string, unknown>]>) {
  const rows = new Map(entries);
  const get = async (path: string) => {
    const data = rows.get(path);
    return {
      exists: data !== undefined,
      data: () => (data ? structuredClone(data) : undefined),
      get: (field: string) => (data ? data[field] : undefined),
    };
  };
  return {
    doc: (path: string) => ({path, get: () => get(path)}),
  };
}

function req(uid: string | undefined, data: unknown = {}) {
  return {
    auth: uid ? {uid, token: {auth_time: Math.floor(Date.now() / 1000)}} : undefined,
    data,
  } as unknown as CallableRequest;
}

test('assertStaffAccount accepts active admin and authorized within allowed roles', () => {
  assert.deepEqual(
    assertStaffAccount({role: 'admin', active: true, schoolId: 'pilot-school-1'}),
    {
      role: 'admin',
      schoolId: 'pilot-school-1',
      active: true,
      isMasterAdmin: false,
      mustChangePassword: false,
      requiresEmailVerification: false,
      emailVerified: false,
      fullName: null,
      position: null,
      loginId: null,
    },
  );
  assert.deepEqual(
    assertStaffAccount({role: 'authorized', active: true, schoolId: 'pilot-school-1'}, ['admin', 'authorized']),
    {
      role: 'authorized',
      schoolId: 'pilot-school-1',
      active: true,
      isMasterAdmin: false,
      mustChangePassword: false,
      requiresEmailVerification: false,
      emailVerified: false,
      fullName: null,
      position: null,
      loginId: null,
    },
  );
});

test('assertStaffAccount denies inactive, student, wrong-role, and malformed schoolId', () => {
  assert.throws(() => assertStaffAccount(undefined), {code: 'permission-denied'});
  assert.throws(() => assertStaffAccount({role: 'admin', active: false, schoolId: 'pilot-school-1'}), {code: 'permission-denied'});
  assert.throws(() => assertStaffAccount({role: 'student', active: true, schoolId: 'pilot-school-1'}), {code: 'permission-denied'});
  assert.throws(() => assertStaffAccount({role: 'authorized', active: true, schoolId: 'pilot-school-1'}, ['admin']), {code: 'permission-denied'});
  assert.throws(() => assertStaffAccount({role: 'admin', active: true, schoolId: 'INVALID SCHOOL!'}), {code: 'permission-denied'});
});

test('requireStaff does not auto-map legacy schoolReviewers without explicit staffAccounts record', async () => {
  const db = mockDb([
    ['schoolReviewers/legacy-reviewer', {active: true, schoolId: 'pilot-school-1'}],
  ]);
  await assert.rejects(() => requireStaff(db as never, 'legacy-reviewer'), {code: 'permission-denied'});
});

test('getStaffAccess denies unauthenticated, students, inactive staff, and forged client fields', async (t) => {
  const db = mockDb([
    ['studentProfiles/student-1', {schemaVersion: 1, fullName: 'Fictional Student'}],
    ['staffAccounts/inactive-1', {role: 'authorized', active: false, schoolId: 'pilot-school-1'}],
    ['staffAccounts/admin-1', {role: 'admin', active: true, schoolId: 'pilot-school-1'}],
    ['staffAccounts/auth-1', {role: 'authorized', active: true, schoolId: 'pilot-school-1'}],
  ]);
  t.mock.method(authorization, 'onboardingDatabase', () => db as never);

  await assert.rejects(() => getStaffAccess.run(req(undefined, {})), {code: 'unauthenticated'});
  await assert.rejects(() => getStaffAccess.run(req('student-1', {})), {code: 'permission-denied'});
  await assert.rejects(() => getStaffAccess.run(req('inactive-1', {})), {code: 'permission-denied'});
  await assert.rejects(() => getStaffAccess.run(req('admin-1', {role: 'admin', schoolId: 'other'})), {code: 'invalid-argument'});

  assert.deepEqual(await getStaffAccess.run(req('admin-1', {})), {
    role: 'admin',
    schoolId: 'pilot-school-1',
    active: true,
    isMasterAdmin: false,
    mustChangePassword: false,
    requiresEmailVerification: false,
    emailVerified: false,
    fullName: null,
    position: null,
    loginId: null,
  });
  assert.deepEqual(await getStaffAccess.run(req('auth-1', {})), {
    role: 'authorized',
    schoolId: 'pilot-school-1',
    active: true,
    isMasterAdmin: false,
    mustChangePassword: false,
    requiresEmailVerification: false,
    emailVerified: false,
    fullName: null,
    position: null,
    loginId: null,
  });
});
