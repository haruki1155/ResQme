import assert from 'node:assert/strict';
import {generateKeyPairSync, sign} from 'node:crypto';
import test from 'node:test';
import {resolveTier1Qr, hashQrPayload} from '../src/qr/resolve_tier1_qr';
import {replaceMyTier1Qr} from '../src/qr/replace_my_tier1_qr';
import {staffManagementDeps, type StaffAdminAuthPort} from '../src/staff/staff_account_management';
import {setAttestationStatusFetcherForTest} from '../src/staff/staff_attestation';
import {getSchoolStudentDetails} from '../src/staff/staff_student_management';
import {
  adminQrReplaceSignedMessage,
  issueAdminQrReplaceChallenge,
  replaceSchoolStudentQr,
} from '../src/staff/staff_qr_replacement';
import {readStudentTier2} from '../src/staff/read_student_tier2';
import {STAFF_ENROLLMENT_PROOF_VERSION, staffTier2SignedMessage} from '../src/staff/staff_tier2_contract';

const INITIAL_QR = 'resqme:v1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
const INITIAL_HASH = hashQrPayload(INITIAL_QR);

function makeStore() {
  const rows = new Map<string, Record<string, unknown>>();
  let failAuditWrite = false;

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
      if (failAuditWrite && path.startsWith('staffManagementAudits/')) {
        throw new Error('Simulated audit failure');
      }
      rows.set(path, {...data});
    },
    async create(data: Record<string, unknown>) {
      if (failAuditWrite && path.startsWith('staffManagementAudits/')) {
        throw new Error('Simulated audit failure');
      }
      if (rows.has(path)) throw new Error(`Already exists: ${path}`);
      rows.set(path, {...data});
    },
    async update(patch: Record<string, unknown>) {
      const cur = rows.get(path);
      if (!cur) throw new Error(`Missing doc ${path}`);
      rows.set(path, {...cur, ...patch});
    },
    collection(sub: string) {
      return {
        doc: (id: string) => docRef(`${path}/${sub}/${id}`),
      };
    },
  });

  const db = {
    doc: docRef,
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

  return {
    rows,
    db,
    setFailAuditWrite(v: boolean) {
      failAuditWrite = v;
    },
  };
}

function makeKeypair() {
  const {publicKey, privateKey} = generateKeyPairSync('ec', {namedCurve: 'prime256v1'});
  const spki = publicKey.export({type: 'spki', format: 'der'}) as Buffer;
  return {
    publicKeySpkiBase64: spki.toString('base64'),
    signMessage: (msg: string) => sign('sha256', Buffer.from(msg, 'utf8'), privateKey).toString('base64url'),
  };
}

function authReq(
  uid: string | undefined,
  data: unknown,
  opts?: {emailVerified?: boolean; authTime?: number},
) {
  return {
    auth: uid
      ? {
          uid,
          token: {
            email_verified: opts?.emailVerified ?? true,
            auth_time: opts?.authTime ?? Math.floor(Date.now() / 1000),
          },
        }
      : undefined,
    data,
    rawRequest: {},
  } as never;
}

function seedFixture(rows: Map<string, Record<string, unknown>>) {
  const adminKey = makeKeypair();
  rows.set('staffAccounts/admin-1', {
    schoolId: '000000123',
    role: 'admin',
    isMasterAdmin: true,
    active: true,
    status: 'active',
    mustChangePassword: false,
    requiresEmailVerification: true,
    fullName: 'Master Admin',
  });
  rows.set('staffTier2Devices/admin-1', {
    deviceId: 'device_admin_1234567890',
    status: 'active',
    enrollmentProofVersion: STAFF_ENROLLMENT_PROOF_VERSION,
    keyVersion: 1,
    publicKey: adminKey.publicKeySpkiBase64,
    attestationSerials: ['01', '02'],
  });
  rows.set('staffAccounts/auth-1', {
    schoolId: '000000123',
    role: 'authorized',
    isMasterAdmin: false,
    active: true,
    status: 'active',
    mustChangePassword: false,
    fullName: 'Nurse One',
  });
  rows.set('staffAccounts/admin-other', {
    schoolId: '999999999',
    role: 'admin',
    isMasterAdmin: true,
    active: true,
    status: 'active',
    mustChangePassword: false,
    requiresEmailVerification: true,
    fullName: 'Other Admin',
  });
  rows.set('studentProfiles/student-1', {
    schemaVersion: 1,
    status: 'pending_guardian',
    schoolAssignmentStatus: 'assigned',
    schoolId: '000000123',
    schoolApprovalStatus: 'approved',
    schoolVerificationOutcome: 'roster_matched',
    medicalStatus: 'complete',
    medicalRevision: 2,
    fullName: 'Juan Dela Cruz',
    lrn: '123456789012',
    gradeLevel: 'Grade 10',
    ageYearsAtRegistration: 16,
    emergencyContacts: {
      primary: {fullName: 'Maria Dela Cruz', relationship: 'Mother', phoneNumber: '+639171234567'},
    },
  });
  rows.set('studentMedicalRecords/student-1', {
    schemaVersion: 1,
    selfReported: true,
    syntheticOnly: false,
    medicalStatus: 'complete',
    revision: 2,
    primaryContact: {fullName: 'Maria Dela Cruz', relationship: 'Mother', phoneNumber: '+639171234567'},
    conditions: {state: 'none_known', details: null},
    allergies: {state: 'listed', details: 'Peanuts'},
  });
  rows.set('studentGuardianAuthorizations/student-1', {
    status: 'verified',
    studentUid: 'student-1',
    guardianUid: 'guardian-1',
    verifiedAt: new Date(),
    method: 'independent_guardian_verification',
  });
  rows.set('studentQrCredentials/student-1', {
    payload: INITIAL_QR,
    verificationStatus: 'active',
    credentialVersion: 1,
  });
  rows.set(`studentQrLookups/${INITIAL_HASH}`, {
    uid: 'student-1',
    status: 'active',
  });
  return {adminKey};
}

function withDeps(
  store: ReturnType<typeof makeStore>,
  fn: () => Promise<void>,
) {
  const prevDb = staffManagementDeps.db;
  const prevAuth = staffManagementDeps.auth;
  staffManagementDeps.db = (() => store.db as never) as never;
  staffManagementDeps.auth = (() => ({}) as StaffAdminAuthPort) as never;
  setAttestationStatusFetcherForTest(async () => ({entries: {}}));
  return fn().finally(() => {
    staffManagementDeps.db = prevDb;
    staffManagementDeps.auth = prevAuth;
    setAttestationStatusFetcherForTest(null);
  });
}

test('Master Admin replaces lost QR with biometric step-up, revokes old QR, preserves student data, and writes audit', async () => {
  const store = makeStore();
  const {adminKey} = seedFixture(store.rows);

  await withDeps(store, async () => {
    const chRes = (await issueAdminQrReplaceChallenge.run(
      authReq('admin-1', {
        studentUid: 'student-1',
        reason: 'lost',
        deviceId: 'device_admin_1234567890',
      }),
    )) as {challengeId: string; nonce: string; issuedAtSec: number};

    const sig = adminKey.signMessage(
      adminQrReplaceSignedMessage({
        adminUid: 'admin-1',
        deviceId: 'device_admin_1234567890',
        studentUid: 'student-1',
        reason: 'lost',
        challengeId: chRes.challengeId,
        nonce: chRes.nonce,
      }),
    );

    const res = (await replaceSchoolStudentQr.run(
      authReq('admin-1', {
        studentUid: 'student-1',
        reason: 'lost',
        requestId: 'req_lost_qr_0001',
        challengeId: chRes.challengeId,
        method: 'biometric',
        deviceId: 'device_admin_1234567890',
        signature: sig,
      }),
    )) as Record<string, unknown>;

    assert.equal(res.studentUid, 'student-1');
    assert.equal(res.verificationStatus, 'active');
    assert.equal(res.credentialVersion, 2);
    assert.equal(res.reason, 'lost');
    assert.equal(res.payload, undefined);

    const oldLookup = store.rows.get(`studentQrLookups/${INITIAL_HASH}`);
    assert.equal(oldLookup?.status, 'revoked');

    const newCred = store.rows.get('studentQrCredentials/student-1');
    assert.ok(typeof newCred?.payload === 'string' && newCred.payload !== INITIAL_QR);
    assert.equal(newCred?.credentialVersion, 2);
    assert.equal(newCred?.verificationStatus, 'active');

    const newLookup = store.rows.get(`studentQrLookups/${hashQrPayload(newCred!.payload as string)}`);
    assert.equal(newLookup?.status, 'active');
    assert.equal(newLookup?.uid, 'student-1');

    // Profile, medical, guardian preserved
    const profile = store.rows.get('studentProfiles/student-1');
    assert.equal(profile?.schoolApprovalStatus, 'approved');
    assert.equal(profile?.medicalStatus, 'complete');
    assert.equal(store.rows.get('studentGuardianAuthorizations/student-1')?.status, 'verified');

    // Audit recorded without raw QR or LRN
    const audit = store.rows.get('staffManagementAudits/req_lost_qr_0001');
    assert.equal(audit?.action, 'replace_student_qr');
    assert.equal(audit?.reason, 'lost');
    assert.equal(audit?.credentialVersion, 2);
    assert.equal(JSON.stringify(audit).includes(INITIAL_QR), false);
    assert.equal(JSON.stringify(audit).includes(newCred!.payload as string), false);
    assert.equal(JSON.stringify(audit).includes('123456789012'), false);
  });
});

test('Master Admin replaces damaged QR with fresh password reauth and rejects stale auth_time', async () => {
  const store = makeStore();
  seedFixture(store.rows);

  await withDeps(store, async () => {
    const chRes = (await issueAdminQrReplaceChallenge.run(
      authReq('admin-1', {studentUid: 'student-1', reason: 'damaged'}),
    )) as {challengeId: string; nonce: string; issuedAtSec: number};

    await assert.rejects(
      () =>
        replaceSchoolStudentQr.run(
          authReq(
            'admin-1',
            {
              studentUid: 'student-1',
              reason: 'damaged',
              requestId: 'req_pwd_stale_01',
              challengeId: chRes.challengeId,
              method: 'password',
            },
            {authTime: chRes.issuedAtSec - 30},
          ),
        ),
      (err: {code?: string}) => err.code === 'permission-denied',
    );

    const ok = (await replaceSchoolStudentQr.run(
      authReq(
        'admin-1',
        {
          studentUid: 'student-1',
          reason: 'damaged',
          requestId: 'req_pwd_fresh_01',
          challengeId: chRes.challengeId,
          method: 'password',
        },
        {authTime: chRes.issuedAtSec + 1},
      ),
    )) as Record<string, unknown>;
    assert.equal(ok.credentialVersion, 2);
    assert.equal(ok.reason, 'damaged');

    // Replay of consumed challenge fails
    await assert.rejects(
      () =>
        replaceSchoolStudentQr.run(
          authReq(
            'admin-1',
            {
              studentUid: 'student-1',
              reason: 'damaged',
              requestId: 'req_pwd_replay_02',
              challengeId: chRes.challengeId,
              method: 'password',
            },
            {authTime: chRes.issuedAtSec + 2},
          ),
        ),
      (err: {code?: string}) => err.code === 'failed-precondition',
    );
  });
});

test('Denies non-Master Admin, cross-school Master Admin, disabled student, and ineligible student', async () => {
  const store = makeStore();
  seedFixture(store.rows);

  await withDeps(store, async () => {
    await assert.rejects(
      () => issueAdminQrReplaceChallenge.run(authReq('auth-1', {studentUid: 'student-1', reason: 'lost'})),
      (err: {code?: string}) => err.code === 'permission-denied',
    );
    await assert.rejects(
      () => issueAdminQrReplaceChallenge.run(authReq('admin-other', {studentUid: 'student-1', reason: 'lost'})),
      (err: {code?: string}) => err.code === 'permission-denied',
    );
    await assert.rejects(
      () => issueAdminQrReplaceChallenge.run(authReq('student-1', {studentUid: 'student-1', reason: 'lost'})),
      (err: {code?: string}) => err.code === 'permission-denied',
    );

    store.rows.set('studentProfiles/student-1', {
      ...store.rows.get('studentProfiles/student-1'),
      accountStatus: 'disabled',
    });
    await assert.rejects(
      () => issueAdminQrReplaceChallenge.run(authReq('admin-1', {studentUid: 'student-1', reason: 'compromised'})),
      /failed-precondition|disabled/i,
    );
  });
});

test('Idempotent requestId replay returns recorded result and audit failure aborts rotation', async () => {
  const store = makeStore();
  const {adminKey} = seedFixture(store.rows);

  await withDeps(store, async () => {
    const ch1 = (await issueAdminQrReplaceChallenge.run(
      authReq('admin-1', {studentUid: 'student-1', reason: 'compromised', deviceId: 'device_admin_1234567890'}),
    )) as {challengeId: string; nonce: string};

    store.setFailAuditWrite(true);
    await assert.rejects(() =>
      replaceSchoolStudentQr.run(
        authReq('admin-1', {
          studentUid: 'student-1',
          reason: 'compromised',
          requestId: 'req_audit_fail_01',
          challengeId: ch1.challengeId,
          method: 'biometric',
          deviceId: 'device_admin_1234567890',
          signature: adminKey.signMessage(
            adminQrReplaceSignedMessage({
              adminUid: 'admin-1',
              deviceId: 'device_admin_1234567890',
              studentUid: 'student-1',
              reason: 'compromised',
              challengeId: ch1.challengeId,
              nonce: ch1.nonce,
            }),
          ),
        }),
      ),
    );
    // Rotation aborted: old QR still active
    assert.equal(store.rows.get(`studentQrLookups/${INITIAL_HASH}`)?.status, 'active');
    assert.equal(store.rows.get('studentQrCredentials/student-1')?.payload, INITIAL_QR);

    store.setFailAuditWrite(false);
    const ch2 = (await issueAdminQrReplaceChallenge.run(
      authReq('admin-1', {studentUid: 'student-1', reason: 'compromised', deviceId: 'device_admin_1234567890'}),
    )) as {challengeId: string; nonce: string};
    const sig2 = adminKey.signMessage(
      adminQrReplaceSignedMessage({
        adminUid: 'admin-1',
        deviceId: 'device_admin_1234567890',
        studentUid: 'student-1',
        reason: 'compromised',
        challengeId: ch2.challengeId,
        nonce: ch2.nonce,
      }),
    );

    const first = (await replaceSchoolStudentQr.run(
      authReq('admin-1', {
        studentUid: 'student-1',
        reason: 'compromised',
        requestId: 'req_idem_0001',
        challengeId: ch2.challengeId,
        method: 'biometric',
        deviceId: 'device_admin_1234567890',
        signature: sig2,
      }),
    )) as Record<string, unknown>;
    const replay = (await replaceSchoolStudentQr.run(
      authReq('admin-1', {
        studentUid: 'student-1',
        reason: 'compromised',
        requestId: 'req_idem_0001',
        challengeId: ch2.challengeId,
        method: 'biometric',
        deviceId: 'device_admin_1234567890',
        signature: sig2,
      }),
    )) as Record<string, unknown>;
    assert.deepEqual(replay.credentialVersion, first.credentialVersion);
    assert.equal(store.rows.get('studentQrCredentials/student-1')?.credentialVersion, 2);
  });
});

test('Old QR fails resolveTier1Qr and outstanding staffTier2Challenges tied to old QR are denied in readStudentTier2', async () => {
  const store = makeStore();
  const {adminKey} = seedFixture(store.rows);
  const oldChallengeId = 'a'.repeat(32);
  store.rows.set(`staffTier2Challenges/${oldChallengeId}`, {
    staffUid: 'admin-1',
    deviceId: 'device_admin_1234567890',
    targetUid: 'student-1',
    qrHash: INITIAL_HASH,
    operation: 'staff_read_medical',
    purpose: 'emergency_response',
    medicalRevision: 2,
    nonce: 'nonce_old_tier2',
    issuedAtSec: Math.floor(Date.now() / 1000),
    expiresAt: new Date(Date.now() + 120_000),
    consumed: false,
  });

  await withDeps(store, async () => {
    const chRes = (await issueAdminQrReplaceChallenge.run(
      authReq('admin-1', {studentUid: 'student-1', reason: 'lost'}),
    )) as {challengeId: string; issuedAtSec: number};

    await replaceSchoolStudentQr.run(
      authReq(
        'admin-1',
        {
          studentUid: 'student-1',
          reason: 'lost',
          requestId: 'req_invalidate_old_01',
          challengeId: chRes.challengeId,
          method: 'password',
        },
        {authTime: chRes.issuedAtSec + 1},
      ),
    );

    // Outstanding Tier 2 challenge bound to old QR is now rejected
    const tier2Sig = adminKey.signMessage(
      staffTier2SignedMessage({
        staffUid: 'admin-1',
        deviceId: 'device_admin_1234567890',
        operation: 'staff_read_medical',
        purpose: 'emergency_response',
        challengeId: oldChallengeId,
        nonce: 'nonce_old_tier2',
      }),
    );
    await assert.rejects(() =>
      readStudentTier2.run(
        authReq('admin-1', {
          challengeId: oldChallengeId,
          deviceId: 'device_admin_1234567890',
          signature: tier2Sig,
        }),
      ),
    );
    assert.equal(typeof resolveTier1Qr, 'function');
    assert.equal(typeof replaceMyTier1Qr, 'function');
    assert.equal(typeof getSchoolStudentDetails, 'function');
  });
});
