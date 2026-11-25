import assert from 'node:assert/strict';
import test from 'node:test';
import {Timestamp} from 'firebase-admin/firestore';
import type {CallableRequest} from 'firebase-functions/v2/https';
import {
  ensureMyStudentLoginQr,
  isStudentLoginQrPayload,
  maskLoginEmail,
  replaceMyStudentLoginQr,
  resolveStudentLoginQr,
  revokeMyStudentLoginQr,
  studentLoginQrDeps,
} from '../src/registration/student_login_qr';

function createFakeEnv() {
  const rows = new Map<string, Record<string, unknown>>();
  const users = new Map<string, {email?: string; disabled?: boolean}>();

  const readSnap = async (path: string) => {
    const data = rows.get(path);
    return {
      exists: data !== undefined,
      id: path.split('/').pop() ?? '',
      data: () => (data ? {...data} : undefined),
      get: (field: string) => (data ? data[field] : undefined),
    };
  };

  const db = {
    doc: (path: string) => ({
      path,
      get: () => readSnap(path),
    }),
    async runTransaction<T>(fn: (tx: any) => Promise<T>): Promise<T> {
      const pending: Array<() => void> = [];
      const tx = {
        get: (ref: {path: string}) => readSnap(ref.path),
        create: (ref: {path: string}, data: Record<string, unknown>) => {
          pending.push(() => {
            if (rows.has(ref.path)) throw new Error(`already-exists: ${ref.path}`);
            rows.set(ref.path, {...data});
          });
        },
        set: (ref: {path: string}, data: Record<string, unknown>, opts?: {merge?: boolean}) => {
          pending.push(() => {
            const prev = opts?.merge ? rows.get(ref.path) ?? {} : {};
            rows.set(ref.path, {...prev, ...data});
          });
        },
        update: (ref: {path: string}, patch: Record<string, unknown>) => {
          pending.push(() => {
            const prev = rows.get(ref.path);
            if (!prev) throw new Error(`not-found: ${ref.path}`);
            rows.set(ref.path, {...prev, ...patch});
          });
        },
      };
      const out = await fn(tx);
      for (const apply of pending) apply();
      return out;
    },
  };

  const auth = {
    async getUser(uid: string) {
      const u = users.get(uid);
      if (!u) {
        const err = new Error('user-not-found') as Error & {code: string};
        err.code = 'auth/user-not-found';
        throw err;
      }
      return {uid, email: u.email, disabled: u.disabled ?? false};
    },
  };

  rows.set('studentProfiles/student-1', {
    schemaVersion: 1,
    fullName: 'Maria Clara Reyes',
    ageYearsAtRegistration: 19,
    status: 'pending_review',
    schoolApprovalStatus: 'approved',
    schoolAssignmentStatus: 'assigned',
    schoolId: 'pilot-school-1',
    lrn: '001122334455',
    medicalStatus: 'complete',
    medicalRevision: 1,
  });
  users.set('student-1', {email: 'maria.reyes@example.test', disabled: false});

  return {rows, users, db, auth};
}

function makeReq(
  uid: string | undefined,
  data: unknown = {},
  ip = '203.0.113.10',
): CallableRequest {
  return {
    auth: uid ? {uid, token: {auth_time: Math.floor(Date.now() / 1000)}} : undefined,
    data,
    rawRequest: {ip},
  } as unknown as CallableRequest;
}

test('Phase 3: ensureMyStudentLoginQr issues opaque revocable token with zero secrets and resolves account hint only', async (t) => {
  const env = createFakeEnv();
  t.mock.method(studentLoginQrDeps, 'db', () => env.db as never);
  t.mock.method(studentLoginQrDeps, 'auth', () => env.auth as never);

  const first = (await ensureMyStudentLoginQr.run(makeReq('student-1'))) as {
    payload: string;
    credentialVersion: number;
    status: string;
  };
  assert.equal(isStudentLoginQrPayload(first.payload), true);
  assert.match(first.payload, /^resqme:login:v1:[A-Za-z0-9_-]{43}$/);
  assert.equal(first.credentialVersion, 1);
  assert.equal(first.status, 'active');
  assert.equal(first.payload.includes('001122334455'), false);
  assert.equal(first.payload.includes('maria'), false);

  const second = (await ensureMyStudentLoginQr.run(makeReq('student-1'))) as {
    payload: string;
    credentialVersion: number;
  };
  assert.equal(second.payload, first.payload);
  assert.equal(second.credentialVersion, 1);

  const resolved = (await resolveStudentLoginQr.run(
    makeReq(undefined, {payload: first.payload}),
  )) as Record<string, unknown>;
  assert.deepEqual(Object.keys(resolved).sort(), ['email', 'maskedEmail']);
  assert.equal(resolved.email, 'maria.reyes@example.test');
  assert.equal(resolved.maskedEmail, maskLoginEmail('maria.reyes@example.test'));
  assert.equal('customToken' in resolved, false);
  assert.equal('idToken' in resolved, false);
  assert.equal('lrn' in resolved, false);
});

test('Phase 3: replace and revoke immediately invalidate old Login QR; emergency QRs and disabled accounts are rejected safely', async (t) => {
  const env = createFakeEnv();
  t.mock.method(studentLoginQrDeps, 'db', () => env.db as never);
  t.mock.method(studentLoginQrDeps, 'auth', () => env.auth as never);

  const issued = (await ensureMyStudentLoginQr.run(makeReq('student-1'))) as {
    payload: string;
  };
  const rotated = (await replaceMyStudentLoginQr.run(makeReq('student-1'))) as {
    payload: string;
    credentialVersion: number;
  };
  assert.notEqual(rotated.payload, issued.payload);
  assert.equal(rotated.credentialVersion, 2);

  // Old QR rejected with same generic permission-denied as unknown token
  let oldErrMsg = '';
  await assert.rejects(
    async () => {
      await resolveStudentLoginQr.run(makeReq(undefined, {payload: issued.payload}));
    },
    (err: any) => {
      oldErrMsg = err.message;
      return err.code === 'permission-denied';
    },
  );

  let unknownErrMsg = '';
  const fakeUnknown = `resqme:login:v1:${'A'.repeat(43)}`;
  await assert.rejects(
    async () => {
      await resolveStudentLoginQr.run(makeReq(undefined, {payload: fakeUnknown}));
    },
    (err: any) => {
      unknownErrMsg = err.message;
      return err.code === 'permission-denied';
    },
  );
  assert.equal(oldErrMsg, unknownErrMsg);

  // Emergency Tier 1 QR scanned in Login QR flow gives clear guidance
  const tier1Payload = `resqme:v1:${'B'.repeat(43)}`;
  await assert.rejects(
    () => resolveStudentLoginQr.run(makeReq(undefined, {payload: tier1Payload})),
    (err: any) => err.code === 'invalid-argument' && /emergency/i.test(err.message),
  );

  // Disabled student account rejected identically to unknown/revoked QR (anti-enumeration)
  env.rows.get('studentProfiles/student-1')!.accountDisabled = true;
  env.rows.get('studentProfiles/student-1')!.accountStatus = 'disabled';
  await assert.rejects(
    () => resolveStudentLoginQr.run(makeReq(undefined, {payload: rotated.payload})),
    (err: any) => err.code === 'permission-denied' && err.message === unknownErrMsg,
  );

  // Re-enable then explicit revoke
  env.rows.get('studentProfiles/student-1')!.accountDisabled = false;
  env.rows.get('studentProfiles/student-1')!.accountStatus = 'active';
  await revokeMyStudentLoginQr.run(makeReq('student-1'));
  await assert.rejects(
    () => resolveStudentLoginQr.run(makeReq(undefined, {payload: rotated.payload})),
    {code: 'permission-denied'},
  );
});

test('Phase 3: resolveStudentLoginQr enforces transactional rate limiting against repeated malicious attempts', async (t) => {
  const env = createFakeEnv();
  t.mock.method(studentLoginQrDeps, 'db', () => env.db as never);
  t.mock.method(studentLoginQrDeps, 'auth', () => env.auth as never);

  const probePayload = `resqme:login:v1:${'Z'.repeat(43)}`;
  for (let i = 0; i < 10; i++) {
    await assert.rejects(
      () => resolveStudentLoginQr.run(makeReq(undefined, {payload: probePayload}, '198.51.100.77')),
      {code: 'permission-denied'},
    );
    // Keep rate-limit window active in fake Firestore
    for (const [k, v] of env.rows.entries()) {
      if (k.startsWith('studentLoginQrRateLimits/') && !(v.windowStartedAt instanceof Timestamp)) {
        v.windowStartedAt = Timestamp.fromMillis(Date.now());
      }
    }
  }
  await assert.rejects(
    () => resolveStudentLoginQr.run(makeReq(undefined, {payload: probePayload}, '198.51.100.77')),
    {code: 'resource-exhausted'},
  );
});
