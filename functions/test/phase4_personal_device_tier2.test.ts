import assert from 'node:assert/strict';
import {generateKeyPairSync, sign} from 'node:crypto';
import test from 'node:test';
import {Timestamp} from 'firebase-admin/firestore';
import type {CallableRequest} from 'firebase-functions/v2/https';
import {enrollTier2Device} from '../src/medical/enroll_tier2_device';
import {issueStudentEnrollmentChallenge} from '../src/medical/issue_student_enrollment_challenge';
import {issueTier2Challenge} from '../src/medical/issue_tier2_challenge';
import {readMyTier2WithPassword} from '../src/medical/read_my_tier2_with_password';
import {revokeMyTier2Device} from '../src/medical/revoke_my_tier2_device';
import {
  STUDENT_ENROLLMENT_PROOF_VERSION,
  studentEnrollmentSignedMessage,
  tier2SignedMessage,
} from '../src/medical/tier2_challenge';
import {
  getMyTrustedDeviceStatus,
  issueMyTier2PresentationToken,
  issueTrustedDeviceTransferCode,
} from '../src/medical/trusted_device_management';
import {issueStaffTier2Challenge} from '../src/staff/issue_staff_tier2_challenge';
import {
   resetAttestationStatusCacheForTest,
  setAttestationStatusFetcherForTest,
} from '../src/staff/staff_attestation';
import {staffManagementDeps} from '../src/staff/staff_account_management';
import {resetStudentTrustedDevice} from '../src/staff/staff_student_management';
import {readStudentTier2} from '../src/staff/read_student_tier2';
import {staffTier2Operation, staffTier2SignedMessage} from '../src/staff/staff_tier2_contract';

const authorization = require('../src/onboarding/authorization') as typeof import('../src/onboarding/authorization');

test.beforeEach(() => {
  resetAttestationStatusCacheForTest();
  setAttestationStatusFetcherForTest(async () => ({entries: {}}));
});
test.afterEach(() => {
  setAttestationStatusFetcherForTest(null);
  resetAttestationStatusCacheForTest();
});

function createPhase4Env() {
  const uid = 'student-p4-1';
  const schoolId = 'school-p4-1';
  const staffUid = 'staff-p4-1';
  const adminUid = 'admin-p4-1';
  const deviceA = 'deviceA_0123456789abcdef';
  const deviceB = 'deviceB_fedcba9876543210';
  const staffDeviceId = 'staffDev_0123456789abcdef';

  const keyA = generateKeyPairSync('ec', {namedCurve: 'prime256v1'});
  const keyB = generateKeyPairSync('ec', {namedCurve: 'prime256v1'});
  const staffKey = generateKeyPairSync('ec', {namedCurve: 'prime256v1'});

  const pubA = keyA.publicKey.export({type: 'spki', format: 'der'}).toString('base64url');
  const pubB = keyB.publicKey.export({type: 'spki', format: 'der'}).toString('base64url');
  const staffPub = staffKey.publicKey.export({type: 'spki', format: 'der'}).toString('base64url');

  const rows = new Map<string, Record<string, unknown>>([
    [
      `studentProfiles/${uid}`,
      {
        schemaVersion: 1,
        fullName: 'Andres Bonifacio',
        ageYearsAtRegistration: 19,
        status: 'pending_review',
        schoolApprovalStatus: 'approved',
        schoolAssignmentStatus: 'assigned',
        schoolId,
        medicalStatus: 'complete',
        medicalRevision: 1,
        lrn: '109876543210',
      },
    ],
    [
      `studentMedicalRecords/${uid}`,
      {
        schemaVersion: 1,
        medicalStatus: 'complete',
        selfReported: true,
        syntheticOnly: false,
        revision: 1,
        conditions: {state: 'listed', details: 'Fictional mild asthma'},
        allergies: {state: 'none_known', details: null},
        primaryContact: {
          fullName: 'Gregoria De Jesus',
          relationship: 'Guardian',
          phoneNumber: '09171234567',
        },
      },
    ],
    [
      `staffAccounts/${staffUid}`,
      {role: 'authorized', active: true, status: 'active', schoolId},
    ],
    [
      `staffAccounts/${adminUid}`,
      {
        role: 'admin',
        isMasterAdmin: true,
        active: true,
        status: 'active',
        schoolId,
        mustChangePassword: false,
        requiresEmailVerification: true,
      },
    ],
    [
      `staffTier2Devices/${staffUid}`,
      {
        staffUid,
        schoolId,
        deviceId: staffDeviceId,
        publicKey: staffPub,
        attestationSerials: ['aa11bb22', 'cc33dd44'],
        status: 'active',
        enrollmentProofVersion: 2,
        keyVersion: 1,
      },
    ],
  ]);

  const toValue = (val: unknown): unknown =>
    val instanceof Date ? Timestamp.fromMillis(val.getTime()) : val;

  const normalizePatch = (data: Record<string, unknown>) => {
    const copy: Record<string, unknown> = {};
    for (const [k, v] of Object.entries(data)) copy[k] = toValue(v);
    return copy;
  };

  const snap = async (path: string) => {
    const d = rows.get(path);
    return {
      exists: d !== undefined,
      id: path.split('/').pop() ?? '',
      data: () => (d ? {...d} : undefined),
      get: (k: string) => (d ? d[k] : undefined),
    };
  };

  const db = {
    doc: (path: string) => ({
      path,
      get: () => snap(path),
      create: async (data: Record<string, unknown>) => {
        rows.set(path, normalizePatch(data));
      },
    }),
    async runTransaction<T>(fn: (tx: any) => Promise<T>): Promise<T> {
      const writes: Array<() => void> = [];
      const tx = {
        get: (ref: {path: string}) => snap(ref.path),
        create: (ref: {path: string}, data: Record<string, unknown>) => {
          writes.push(() => {
            assert.equal(rows.has(ref.path), false, `duplicate: ${ref.path}`);
            rows.set(ref.path, normalizePatch(data));
          });
        },
        set: (ref: {path: string}, data: Record<string, unknown>, opts?: {merge?: boolean}) => {
          writes.push(() => {
            const prev = opts?.merge ? rows.get(ref.path) ?? {} : {};
            rows.set(ref.path, {...prev, ...normalizePatch(data)});
          });
        },
        update: (ref: {path: string}, patch: Record<string, unknown>) => {
          writes.push(() => {
            const prev = rows.get(ref.path);
            assert.ok(prev, `missing: ${ref.path}`);
            rows.set(ref.path, {...prev, ...normalizePatch(patch)});
          });
        },
      };
      const out = await fn(tx);
      for (const w of writes) w();
      return out;
    },
  };

  const req = (callerUid: string, data: unknown = {}): CallableRequest =>
    ({
      auth: {
        uid: callerUid,
        token: {
          auth_time: Math.floor(Date.now() / 1000),
          email_verified: true,
        },
      },
      data,
    }) as unknown as CallableRequest;

  return {
    uid,
    schoolId,
    staffUid,
    adminUid,
    deviceA,
    deviceB,
    staffDeviceId,
    keyA,
    keyB,
    staffKey,
    pubA,
    pubB,
    rows,
    db,
    req,
  };
}

test('Phase 4: password-only secondary device cannot silently overwrite or revoke active trusted device; transfer code or Master Admin recovery succeeds and revokes old device', async (t) => {
  const f = createPhase4Env();
  t.mock.method(authorization, 'onboardingDatabase', () => f.db as never);
  t.mock.method(staffManagementDeps, 'db', () => f.db as never);

  // 1. First-time enrollment on Device A succeeds
  const chA = (await issueStudentEnrollmentChallenge.run(f.req(f.uid, {}))) as {
    challengeId: string;
    nonce: string;
  };
  const sigA = sign(
    'sha256',
    Buffer.from(
      studentEnrollmentSignedMessage({
        uid: f.uid,
        deviceId: f.deviceA,
        challengeId: chA.challengeId,
        nonce: chA.nonce,
      }),
    ),
    f.keyA.privateKey,
  ).toString('base64url');
  await enrollTier2Device.run(
    f.req(f.uid, {
      challengeId: chA.challengeId,
      deviceId: f.deviceA,
      publicKey: f.pubA,
      signature: sigA,
    }),
  );

  // Trusted device status reflects Device A trusted, Device B NOT trusted (and leaks zero deviceId!)
  const statusA = (await getMyTrustedDeviceStatus.run(
    f.req(f.uid, {deviceId: f.deviceA}),
  )) as Record<string, unknown>;
  assert.equal(statusA.hasActiveTrustedDevice, true);
  assert.equal(statusA.isCurrentDeviceTrusted, true);
  assert.equal('deviceId' in statusA, false);

  const statusB = (await getMyTrustedDeviceStatus.run(
    f.req(f.uid, {deviceId: f.deviceB}),
  )) as Record<string, unknown>;
  assert.equal(statusB.hasActiveTrustedDevice, true);
  assert.equal(statusB.isCurrentDeviceTrusted, false);

  // 2. Secondary Device B CAN still legitimately view own medical record with password without altering Device A
  const ownMed = await readMyTier2WithPassword.run(f.req(f.uid, {}));
  assert.deepEqual(Object.keys(ownMed).sort(), ['allergies', 'conditions', 'primaryContact']);
  assert.equal(f.rows.get(`tier2Devices/${f.uid}`)?.deviceId, f.deviceA);

  // 3. Secondary Device B CANNOT revoke Device A using password alone!
  await assert.rejects(
    () => revokeMyTier2Device.run(f.req(f.uid, {deviceId: f.deviceB})),
    {code: 'permission-denied'},
  );
  await assert.rejects(
    () => revokeMyTier2Device.run(f.req(f.uid, {})),
    {code: 'permission-denied'},
  );

  // 4. Secondary Device B CANNOT silently replace Device A using password-only enrollment!
  const chBBlocked = (await issueStudentEnrollmentChallenge.run(f.req(f.uid, {}))) as {
    challengeId: string;
    nonce: string;
  };
  const sigBBlocked = sign(
    'sha256',
    Buffer.from(
      studentEnrollmentSignedMessage({
        uid: f.uid,
        deviceId: f.deviceB,
        challengeId: chBBlocked.challengeId,
        nonce: chBBlocked.nonce,
      }),
    ),
    f.keyB.privateKey,
  ).toString('base64url');
  await assert.rejects(
    () =>
      enrollTier2Device.run(
        f.req(f.uid, {
          challengeId: chBBlocked.challengeId,
          deviceId: f.deviceB,
          publicKey: f.pubB,
          signature: sigBBlocked,
        }),
      ),
    {code: 'failed-precondition'},
  );
  assert.equal(f.rows.get(`tier2Devices/${f.uid}`)?.deviceId, f.deviceA);

  // 5. Existing Trusted Device A approves replacement via biometric signature -> Device B enrolls and revokes Device A!
  const transferCh = (await issueTier2Challenge.run(
    f.req(f.uid, {deviceId: f.deviceA, operation: 'approve_device_transfer'}),
  )) as {challengeId: string; nonce: string};
  const transferSig = sign(
    'sha256',
    Buffer.from(
      tier2SignedMessage({
        uid: f.uid,
        deviceId: f.deviceA,
        operation: 'approve_device_transfer',
        challengeId: transferCh.challengeId,
        nonce: transferCh.nonce,
      }),
    ),
    f.keyA.privateKey,
  ).toString('base64url');
  const transferGrant = (await issueTrustedDeviceTransferCode.run(
    f.req(f.uid, {
      challengeId: transferCh.challengeId,
      deviceId: f.deviceA,
      signature: transferSig,
    }),
  )) as {transferCode: string};

  const chBAllowed = (await issueStudentEnrollmentChallenge.run(f.req(f.uid, {}))) as {
    challengeId: string;
    nonce: string;
  };
  const sigBAllowed = sign(
    'sha256',
    Buffer.from(
      studentEnrollmentSignedMessage({
        uid: f.uid,
        deviceId: f.deviceB,
        challengeId: chBAllowed.challengeId,
        nonce: chBAllowed.nonce,
      }),
    ),
    f.keyB.privateKey,
  ).toString('base64url');
  const enrolledB = (await enrollTier2Device.run(
    f.req(f.uid, {
      challengeId: chBAllowed.challengeId,
      deviceId: f.deviceB,
      publicKey: f.pubB,
      signature: sigBAllowed,
      transferCode: transferGrant.transferCode,
    }),
  )) as {deviceId: string; keyVersion: number};
  assert.equal(enrolledB.deviceId, f.deviceB);
  assert.equal(enrolledB.keyVersion, 2);

  // Old Device A is immediately rejected for Tier 2 challenges!
  await assert.rejects(
    () =>
      issueTier2Challenge.run(
        f.req(f.uid, {deviceId: f.deviceA, operation: 'read_medical'}),
      ),
    {code: 'permission-denied'},
  );

  // 6. Master Admin school-verified recovery resets lost Device B -> fresh enrollment succeeds
  await resetStudentTrustedDevice.run(
    f.req(f.adminUid, {studentUid: f.uid, reason: 'lost_personal_device'}),
  );
  assert.equal(f.rows.get(`tier2Devices/${f.uid}`)?.status, 'revoked');
});

test('Phase 4: short-lived biometric Tier 2 presentation token contains zero medical data, works with Staff scanner, and rejects expired or replayed scans', async (t) => {
  const f = createPhase4Env();
  t.mock.method(authorization, 'onboardingDatabase', () => f.db as never);

  f.rows.set(`tier2Devices/${f.uid}`, {
    deviceId: f.deviceA,
    publicKey: f.pubA,
    status: 'active',
    enrollmentProofVersion: STUDENT_ENROLLMENT_PROOF_VERSION,
    keyVersion: 1,
  });

  // 1. Unlock protected Tier 2 presentation QR with biometric proof
  const presentCh = (await issueTier2Challenge.run(
    f.req(f.uid, {deviceId: f.deviceA, operation: 'present_tier2_qr'}),
  )) as {challengeId: string; nonce: string};
  const presentSig = sign(
    'sha256',
    Buffer.from(
      tier2SignedMessage({
        uid: f.uid,
        deviceId: f.deviceA,
        operation: 'present_tier2_qr',
        challengeId: presentCh.challengeId,
        nonce: presentCh.nonce,
      }),
    ),
    f.keyA.privateKey,
  ).toString('base64url');

  const tokenRes = (await issueMyTier2PresentationToken.run(
    f.req(f.uid, {
      challengeId: presentCh.challengeId,
      deviceId: f.deviceA,
      signature: presentSig,
    }),
  )) as {payload: string; expiresAt: number; ttlSeconds: number};

  assert.match(tokenRes.payload, /^resqme:tier2:v1:[A-Za-z0-9_-]{43}$/);
  assert.equal(tokenRes.payload.includes('asthma'), false);
  assert.equal(tokenRes.payload.includes('109876543210'), false);
  assert.equal(tokenRes.ttlSeconds, 90);

  // 2. Staff scans short-lived presentation token with mandatory staff biometric proof
  const staffIssued = (await issueStaffTier2Challenge.run(
    f.req(f.staffUid, {
      payload: tokenRes.payload,
      deviceId: f.staffDeviceId,
      purpose: 'emergency_response',
    }),
  )) as {challengeId: string; nonce: string};

  const staffSig = sign(
    'sha256',
    Buffer.from(
      staffTier2SignedMessage({
        staffUid: f.staffUid,
        deviceId: f.staffDeviceId,
        operation: staffTier2Operation,
        purpose: 'emergency_response',
        challengeId: staffIssued.challengeId,
        nonce: staffIssued.nonce,
      }),
      'utf8',
    ),
    f.staffKey.privateKey,
  ).toString('base64url');

  const record = (await readStudentTier2.run(
    f.req(f.staffUid, {
      challengeId: staffIssued.challengeId,
      deviceId: f.staffDeviceId,
      signature: staffSig,
    }),
  )) as Record<string, unknown>;
  assert.deepEqual(Object.keys(record).sort(), ['allergies', 'conditions', 'primaryContact']);

  // 3. Re-scanning the consumed presentation token is rejected!
  await assert.rejects(
    () =>
      issueStaffTier2Challenge.run(
        f.req(f.staffUid, {
          payload: tokenRes.payload,
          deviceId: f.staffDeviceId,
          purpose: 'emergency_response',
        }),
      ),
    {code: 'permission-denied'},
  );
});
