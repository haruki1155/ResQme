import assert from 'node:assert/strict';
import {createHash, generateKeyPairSync, randomBytes, sign} from 'node:crypto';
import test from 'node:test';
import {Timestamp} from 'firebase-admin/firestore';
import type {CallableRequest} from 'firebase-functions/v2/https';
import {issueStaffTier2Challenge} from '../src/staff/issue_staff_tier2_challenge';
import {readStudentTier2} from '../src/staff/read_student_tier2';
import {
  resetAttestationStatusCacheForTest,
  setAttestationStatusFetcherForTest,
} from '../src/staff/staff_attestation';
import {staffTier2Operation, staffTier2SignedMessage} from '../src/staff/staff_tier2_contract';

test.beforeEach(() => {
  resetAttestationStatusCacheForTest();
  setAttestationStatusFetcherForTest(async () => ({entries: {}}));
});
test.afterEach(() => {
  setAttestationStatusFetcherForTest(null);
  resetAttestationStatusCacheForTest();
});

const authorization = require('../src/onboarding/authorization') as typeof import('../src/onboarding/authorization');

function makePayload(): {payload: string; qrHash: string} {
  const payload = `resqme:v1:${randomBytes(32).toString('base64url')}`;
  const qrHash = createHash('sha256').update(payload, 'utf8').digest('hex');
  return {payload, qrHash};
}

function makeFixture(opts?: {role?: 'admin' | 'authorized'; studentAge?: number; guardianVerified?: boolean; failAudit?: boolean; enrollmentProofVersion?: number | null}) {
  const {payload, qrHash} = makePayload();
  const {publicKey, privateKey} = generateKeyPairSync('ec', {namedCurve: 'prime256v1'});
  const staffUid = 'staff-uid-1';
  const studentUid = 'student-uid-1';
  const deviceId = 'staff_device_0123456789abc';
  const schoolId = 'pilot-school-1';
  const deviceDoc: Record<string, unknown> = {
    staffUid,
    schoolId,
    deviceId,
    publicKey: publicKey.export({type: 'spki', format: 'der'}).toString('base64url'),
    attestationSerials: ['a1b2c3d4', 'deadbeef'],
    status: 'active',
    keyVersion: 1,
  };
  if (opts?.enrollmentProofVersion !== null) {
    deviceDoc.enrollmentProofVersion = opts?.enrollmentProofVersion ?? 2;
  }
  const rows = new Map<string, Record<string, unknown>>([
    [`staffAccounts/${staffUid}`, {role: opts?.role ?? 'authorized', active: true, schoolId}],
    [`staffTier2Devices/${staffUid}`, deviceDoc],
    [`studentQrLookups/${qrHash}`, {uid: studentUid, status: 'active'}],
    [`studentQrCredentials/${studentUid}`, {payload, verificationStatus: 'active'}],
    [`studentProfiles/${studentUid}`, {
      schemaVersion: 1,
      status: 'pending_review',
      fullName: 'Fictional Adult Student',
      ageYearsAtRegistration: opts?.studentAge ?? 20,
      schoolAssignmentStatus: 'assigned',
      schoolId,
      schoolApprovalStatus: 'approved',
      medicalStatus: 'complete',
      medicalRevision: 1,
      lrn: '123456789012',
    }],
    [`studentMedicalRecords/${studentUid}`, {
      schemaVersion: 1,
      medicalStatus: 'complete',
      selfReported: true,
      syntheticOnly: false,
      revision: 1,
      conditions: {state: 'listed', details: 'Fictional asthma'},
      allergies: {state: 'none_known', details: null},
      primaryContact: {fullName: 'Fictional Guardian', relationship: 'Parent', phoneNumber: '09170000001'},
      lrn: 'never-returned',
    }],
  ]);
  if (opts?.guardianVerified) {
    rows.set(`studentGuardianAuthorizations/${studentUid}`, {
      status: 'verified',
      studentUid,
      guardianUid: 'guardian-uid-1',
      method: 'independent_guardian_verification',
      verifiedAt: new Date(),
    });
  }

  let failAudit = opts?.failAudit ?? false;
  let txLock = Promise.resolve();
  const read = async (path: string) => {
    const data = rows.get(path);
    return {
      exists: data !== undefined,
      data: () => (data ? {...data} : undefined),
      get: (field: string) => (data ? data[field] : undefined),
    };
  };
  const db = {
    doc: (path: string) => ({
      path,
      get: () => read(path),
      set: async (data: Record<string, unknown>) => {
        rows.set(path, {...data});
      },
      create: async (data: Record<string, unknown>) => {
        if (failAudit && path.startsWith('tier2AccessAudits/')) throw new Error('audit-write-failed');
        rows.set(path, {...data});
      },
    }),
    async runTransaction<T>(action: (tx: unknown) => Promise<T>): Promise<T> {
      const prev = txLock;
      let release!: () => void;
      txLock = new Promise<void>((r) => {
        release = r;
      });
      await prev;
      try {
        const pending: Array<() => void> = [];
        const tx = {
          get: (ref: {path: string}) => read(ref.path),
          create: (ref: {path: string}, data: Record<string, unknown>) => {
            if (failAudit && ref.path.startsWith('tier2AccessAudits/')) {
              throw new Error('audit-write-failed');
            }
            pending.push(() => rows.set(ref.path, {...data}));
          },
          update: (ref: {path: string}, patch: Record<string, unknown>) => {
            pending.push(() => rows.set(ref.path, {...rows.get(ref.path), ...patch}));
          },
        };
        const result = await action(tx);
        for (const fn of pending) fn();
        return result;
      } finally {
        release();
      }
    },
  };

  function signChallenge(c: {challengeId: string; nonce: string; purpose?: string; devId?: string; uid?: string}) {
    const msg = staffTier2SignedMessage({
      staffUid: c.uid ?? staffUid,
      deviceId: c.devId ?? deviceId,
      operation: staffTier2Operation,
      purpose: c.purpose ?? 'emergency_response',
      challengeId: c.challengeId,
      nonce: c.nonce,
    });
    return sign('sha256', Buffer.from(msg, 'utf8'), privateKey).toString('base64url');
  }

  return {
    payload,
    qrHash,
    staffUid,
    studentUid,
    deviceId,
    schoolId,
    rows,
    db,
    signChallenge,
    setFailAudit: (v: boolean) => {
      failAudit = v;
    },
    privateKey,
  };
}

function req(uid: string | undefined, data: unknown) {
  return {
    auth: uid ? {uid, token: {auth_time: Math.floor(Date.now() / 1000)}} : undefined,
    data,
  } as unknown as CallableRequest;
}

test('same-school Admin and Authorized staff succeed with QR-bound proof and write audit atomically', async (t) => {
  for (const role of ['admin', 'authorized'] as const) {
    const f = makeFixture({role});
    t.mock.method(authorization, 'onboardingDatabase', () => f.db as never);

    const issued = await issueStaffTier2Challenge.run(req(f.staffUid, {
      payload: f.payload,
      deviceId: f.deviceId,
      purpose: 'emergency_response',
    })) as {challengeId: string; nonce: string; operation: string; purpose: string};
    // Opaque challenge only: zero student details before biometric proof
    assert.equal('fullName' in issued, false);
    assert.equal('conditions' in issued, false);
    assert.equal('targetUid' in issued, false);
    f.rows.get(`staffTier2Challenges/${issued.challengeId}`)!.expiresAt = Timestamp.fromMillis(Date.now() + 60_000);

    const signature = f.signChallenge({challengeId: issued.challengeId, nonce: issued.nonce});
    const record = await readStudentTier2.run(req(f.staffUid, {
      challengeId: issued.challengeId,
      deviceId: f.deviceId,
      signature,
    })) as Record<string, unknown>;

    assert.deepEqual(Object.keys(record).sort(), ['allergies', 'conditions', 'primaryContact']);
    assert.equal('lrn' in record, false);

    // Audit record written without medical data, signature, or raw QR
    const audits = [...f.rows.entries()].filter(([k]) => k.startsWith('tier2AccessAudits/'));
    assert.equal(audits.length, 1);
    const audit = audits[0][1];
    assert.equal(audit.actorUid, f.staffUid);
    assert.equal(audit.actorRole, role);
    assert.equal(audit.targetUid, f.studentUid);
    assert.equal(audit.outcome, 'allowed');
    assert.equal('conditions' in audit, false);
    assert.equal('payload' in audit, false);
    assert.equal('signature' in audit, false);

    // Replay of same challenge must be denied
    await assert.rejects(() => readStudentTier2.run(req(f.staffUid, {
      challengeId: issued.challengeId,
      deviceId: f.deviceId,
      signature,
    })), {code: 'permission-denied'});
  }
});

test('denies wrong school, student caller, disabled staff, pending/revoked QR, minor without guardian, and audit failure', async (t) => {
  // Wrong school
  const wrongSchool = makeFixture();
  wrongSchool.rows.get(`staffAccounts/${wrongSchool.staffUid}`)!.schoolId = 'other-school';
  t.mock.method(authorization, 'onboardingDatabase', () => wrongSchool.db as never);
  await assert.rejects(() => issueStaffTier2Challenge.run(req(wrongSchool.staffUid, {
    payload: wrongSchool.payload,
    deviceId: wrongSchool.deviceId,
    purpose: 'emergency_response',
  })), {code: 'permission-denied'});

  // Minor without guardian
  const minor = makeFixture({studentAge: 16, guardianVerified: false});
  t.mock.method(authorization, 'onboardingDatabase', () => minor.db as never);
  await assert.rejects(() => issueStaffTier2Challenge.run(req(minor.staffUid, {
    payload: minor.payload,
    deviceId: minor.deviceId,
    purpose: 'clinic_triage',
  })), {code: 'permission-denied'});

  // QR revoked AFTER challenge issuance must deny read
  const revokedAfter = makeFixture();
  t.mock.method(authorization, 'onboardingDatabase', () => revokedAfter.db as never);
  const c1 = await issueStaffTier2Challenge.run(req(revokedAfter.staffUid, {
    payload: revokedAfter.payload,
    deviceId: revokedAfter.deviceId,
    purpose: 'emergency_response',
  })) as {challengeId: string; nonce: string};
  revokedAfter.rows.get(`staffTier2Challenges/${c1.challengeId}`)!.expiresAt = Timestamp.fromMillis(Date.now() + 60_000);
  revokedAfter.rows.get(`studentQrLookups/${revokedAfter.qrHash}`)!.status = 'revoked';
  await assert.rejects(() => readStudentTier2.run(req(revokedAfter.staffUid, {
    challengeId: c1.challengeId,
    deviceId: revokedAfter.deviceId,
    signature: revokedAfter.signChallenge(c1),
  })), {code: 'permission-denied'});

  // Staff suspended AFTER challenge issuance must deny read
  const suspendedAfter = makeFixture();
  t.mock.method(authorization, 'onboardingDatabase', () => suspendedAfter.db as never);
  const c2 = await issueStaffTier2Challenge.run(req(suspendedAfter.staffUid, {
    payload: suspendedAfter.payload,
    deviceId: suspendedAfter.deviceId,
    purpose: 'emergency_response',
  })) as {challengeId: string; nonce: string};
  suspendedAfter.rows.get(`staffTier2Challenges/${c2.challengeId}`)!.expiresAt = Timestamp.fromMillis(Date.now() + 60_000);
  suspendedAfter.rows.get(`staffAccounts/${suspendedAfter.staffUid}`)!.active = false;
  await assert.rejects(() => readStudentTier2.run(req(suspendedAfter.staffUid, {
    challengeId: c2.challengeId,
    deviceId: suspendedAfter.deviceId,
    signature: suspendedAfter.signChallenge(c2),
  })), {code: 'permission-denied'});

  // Audit write failure prevents medical release
  const auditFail = makeFixture({failAudit: true});
  t.mock.method(authorization, 'onboardingDatabase', () => auditFail.db as never);
  const c3 = await issueStaffTier2Challenge.run(req(auditFail.staffUid, {
    payload: auditFail.payload,
    deviceId: auditFail.deviceId,
    purpose: 'emergency_response',
  })) as {challengeId: string; nonce: string};
  auditFail.rows.get(`staffTier2Challenges/${c3.challengeId}`)!.expiresAt = Timestamp.fromMillis(Date.now() + 60_000);
  await assert.rejects(() => readStudentTier2.run(req(auditFail.staffUid, {
    challengeId: c3.challengeId,
    deviceId: auditFail.deviceId,
    signature: auditFail.signChallenge(c3),
  })));
});

test('concurrent duplicate consumption allows at most one read', async (t) => {
  const f = makeFixture();
  t.mock.method(authorization, 'onboardingDatabase', () => f.db as never);
  const issued = await issueStaffTier2Challenge.run(req(f.staffUid, {
    payload: f.payload,
    deviceId: f.deviceId,
    purpose: 'emergency_response',
  })) as {challengeId: string; nonce: string};
  f.rows.get(`staffTier2Challenges/${issued.challengeId}`)!.expiresAt = Timestamp.fromMillis(Date.now() + 60_000);
  const signature = f.signChallenge(issued);
  const results = await Promise.allSettled([
    readStudentTier2.run(req(f.staffUid, {challengeId: issued.challengeId, deviceId: f.deviceId, signature})),
    readStudentTier2.run(req(f.staffUid, {challengeId: issued.challengeId, deviceId: f.deviceId, signature})),
  ]);
  assert.equal(results.filter((r) => r.status === 'fulfilled').length, 1);
  assert.equal(results.filter((r) => r.status === 'rejected').length, 1);
});

test('previously enrolled device is denied immediately when its attestation certificate becomes revoked', async (t) => {
  const f = makeFixture();
  t.mock.method(authorization, 'onboardingDatabase', () => f.db as never);
  const issued = await issueStaffTier2Challenge.run(req(f.staffUid, {
    payload: f.payload,
    deviceId: f.deviceId,
    purpose: 'emergency_response',
  })) as {challengeId: string; nonce: string};
  f.rows.get(`staffTier2Challenges/${issued.challengeId}`)!.expiresAt = Timestamp.fromMillis(Date.now() + 60_000);

  // Attestation certificate serial becomes revoked after enrollment and challenge issuance
  resetAttestationStatusCacheForTest();
  setAttestationStatusFetcherForTest(async () => ({
    entries: {a1b2c3d4: {status: 'REVOKED', reason: 'KEY_COMPROMISE'}},
  }));

  await assert.rejects(() => readStudentTier2.run(req(f.staffUid, {
    challengeId: issued.challengeId,
    deviceId: f.deviceId,
    signature: f.signChallenge(issued),
  })), {code: 'permission-denied'});

  await assert.rejects(() => issueStaffTier2Challenge.run(req(f.staffUid, {
    payload: f.payload,
    deviceId: f.deviceId,
    purpose: 'emergency_response',
  })), {code: 'permission-denied'});
});

test('older unproven device enrollments require biometric re-enrollment and enrollment signatures cannot authorize Tier 2 reads', async (t) => {
  // 1. Legacy device without enrollmentProofVersion is rejected with failed-precondition
  const legacy = makeFixture({enrollmentProofVersion: null});
  t.mock.method(authorization, 'onboardingDatabase', () => legacy.db as never);
  await assert.rejects(
    () =>
      issueStaffTier2Challenge.run(
        req(legacy.staffUid, {
          payload: legacy.payload,
          deviceId: legacy.deviceId,
          purpose: 'emergency_response',
        }),
      ),
    {code: 'failed-precondition'},
  );

  // 2. If a device downgrades/lacks proof version at readStudentTier2 time, deny with failed-precondition
  const f = makeFixture({enrollmentProofVersion: 2});
  t.mock.method(authorization, 'onboardingDatabase', () => f.db as never);
  const issued = (await issueStaffTier2Challenge.run(
    req(f.staffUid, {
      payload: f.payload,
      deviceId: f.deviceId,
      purpose: 'emergency_response',
    }),
  )) as {challengeId: string; nonce: string};
  f.rows.get(`staffTier2Challenges/${issued.challengeId}`)!.expiresAt = Timestamp.fromMillis(Date.now() + 60_000);

  delete f.rows.get(`staffTier2Devices/${f.staffUid}`)!.enrollmentProofVersion;
  await assert.rejects(
    () =>
      readStudentTier2.run(
        req(f.staffUid, {
          challengeId: issued.challengeId,
          deviceId: f.deviceId,
          signature: f.signChallenge(issued),
        }),
      ),
    {code: 'failed-precondition'},
  );

  // 3. Restore proof version; enrollment-domain signature cannot satisfy readStudentTier2
  f.rows.get(`staffTier2Devices/${f.staffUid}`)!.enrollmentProofVersion = 2;
  const enrollDomainMsg = `resqme:staff-enroll:v2\n${f.staffUid}\n${f.deviceId}\n${issued.challengeId}\n${issued.nonce}`;
  const enrollSig = sign('sha256', Buffer.from(enrollDomainMsg, 'utf8'), f.privateKey).toString('base64url');
  await assert.rejects(
    () =>
      readStudentTier2.run(
        req(f.staffUid, {
          challengeId: issued.challengeId,
          deviceId: f.deviceId,
          signature: enrollSig,
        }),
      ),
    {code: 'permission-denied'},
  );
});
