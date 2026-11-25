import {createHash, randomBytes} from 'node:crypto';
import {FieldValue, Timestamp} from 'firebase-admin/firestore';
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {keys, object} from '../medical/medical_contract';
import {requireRecentAuth, verifyTier2Signature} from '../medical/tier2_challenge';
import {isStudentAccountDisabled, resqmeRuntimeOptions} from '../onboarding/authorization';
import {evaluateStudentEligibility} from '../qr/qr_eligibility';
import {rotateStudentTier1QrInTx, type QrReplacementReason} from '../qr/qr_rotation';
import {requireMasterAdmin, staffManagementDeps} from './staff_account_management';
import {assertAttestationSerialsNotRevoked} from './staff_attestation';
import {enforceTransactionalRateLimit} from './staff_student_management';
import {STAFF_ENROLLMENT_PROOF_VERSION} from './staff_tier2_contract';

const UID_PATTERN = /^[A-Za-z0-9_-]{2,128}$/;
const DEVICE_ID_PATTERN = /^[A-Za-z0-9_-]{16,128}$/;
const CHALLENGE_ID_PATTERN = /^[a-f0-9]{32,64}$/;
const REQUEST_ID_PATTERN = /^[A-Za-z0-9_-]{8,128}$/;
const QR_REPLACE_OPERATION = 'admin_replace_student_qr';
const MAX_QR_REPLACE_CHALLENGES_PER_WINDOW = 10;

const VALID_REASONS: readonly QrReplacementReason[] = ['lost', 'damaged', 'compromised'];

function validateReason(value: unknown): QrReplacementReason {
  if (typeof value !== 'string' || !VALID_REASONS.includes(value as QrReplacementReason)) {
    throw new HttpsError('invalid-argument', 'Valid QR replacement reason is required.');
  }
  return value as QrReplacementReason;
}

function validateStudentUid(value: unknown): string {
  if (typeof value !== 'string' || !UID_PATTERN.test(value)) {
    throw new HttpsError('invalid-argument', 'Invalid student UID.');
  }
  return value;
}

export function adminQrReplaceSignedMessage(input: {
  adminUid: string;
  deviceId: string;
  studentUid: string;
  reason: QrReplacementReason;
  challengeId: string;
  nonce: string;
}): string {
  return `resqme:staff-qr-replace:v1\n${input.adminUid}\n${input.deviceId}\n${QR_REPLACE_OPERATION}\n${input.studentUid}\n${input.reason}\n${input.challengeId}\n${input.nonce}`;
}

async function loadEligibleStudentForReplacement(
  txOrDb: {
    get?: (ref: FirebaseFirestore.DocumentReference) => Promise<FirebaseFirestore.DocumentSnapshot>;
  },
  db: FirebaseFirestore.Firestore,
  studentUid: string,
  adminSchoolId: string,
) {
  const profileRef = db.doc(`studentProfiles/${studentUid}`);
  const medicalRef = db.doc(`studentMedicalRecords/${studentUid}`);
  const guardianRef = db.doc(`studentGuardianAuthorizations/${studentUid}`);
  const credRef = db.doc(`studentQrCredentials/${studentUid}`);

  const getter = txOrDb.get
    ? (ref: FirebaseFirestore.DocumentReference) => txOrDb.get!(ref)
    : (ref: FirebaseFirestore.DocumentReference) => ref.get();

  const [profileSnap, medicalSnap, guardianSnap, credSnap] = await Promise.all([
    getter(profileRef),
    getter(medicalRef),
    getter(guardianRef),
    getter(credRef),
  ]);

  const profile = profileSnap.data();
  if (
    !profileSnap.exists ||
    !profile ||
    profile.schemaVersion !== 1 ||
    profile.schoolAssignmentStatus !== 'assigned' ||
    profile.schoolId !== adminSchoolId
  ) {
    throw new HttpsError('permission-denied', 'Student account is unavailable.');
  }
  if (isStudentAccountDisabled(profile)) {
    throw new HttpsError(
      'failed-precondition',
      'Disabled student accounts cannot receive replacement QR credentials.',
    );
  }
  if (profile.schoolApprovalStatus === 'revoked') {
    throw new HttpsError(
      'failed-precondition',
      'Revoked student accounts cannot receive replacement QR credentials.',
    );
  }
  if (
    !evaluateStudentEligibility({
      uid: studentUid,
      profile,
      medical: medicalSnap.data(),
      guardianAuthorization: guardianSnap.data(),
    })
  ) {
    throw new HttpsError(
      'failed-precondition',
      'Student must have approved school verification, complete medical record, and required guardian authorization before replacing their QR code.',
    );
  }

  return {profile, medicalSnap, guardianSnap, credSnap};
}

export const issueAdminQrReplaceChallenge = onCall(resqmeRuntimeOptions, async (request) => {
  const adminUid = request.auth?.uid;
  if (!adminUid) throw new HttpsError('unauthenticated', 'Sign in is required.');
  const data = object(request.data);
  keys(data, ['studentUid', 'reason', 'deviceId']);
  const studentUid = validateStudentUid(data.studentUid);
  const reason = validateReason(data.reason);

  let deviceId: string | null = null;
  if (data.deviceId != null) {
    if (typeof data.deviceId !== 'string' || !DEVICE_ID_PATTERN.test(data.deviceId)) {
      throw new HttpsError('invalid-argument', 'Invalid staff device identifier.');
    }
    deviceId = data.deviceId;
  }

  const db = staffManagementDeps.db(adminUid);
  const admin = await requireMasterAdmin(
    db,
    adminUid,
    request.auth?.token.email_verified === true,
  );

  await enforceTransactionalRateLimit(
    db,
    `staffQrReplaceRateLimits/${adminUid}`,
    MAX_QR_REPLACE_CHALLENGES_PER_WINDOW,
    'Too many QR replacement verification requests. Wait before trying again.',
  );

  await loadEligibleStudentForReplacement({}, db, studentUid, admin.schoolId);

  if (deviceId) {
    const devSnap = await db.doc(`staffTier2Devices/${adminUid}`).get();
    if (
      !devSnap.exists ||
      devSnap.get('status') !== 'active' ||
      devSnap.get('deviceId') !== deviceId ||
      typeof devSnap.get('publicKey') !== 'string' ||
      devSnap.get('enrollmentProofVersion') !== STAFF_ENROLLMENT_PROOF_VERSION
    ) {
      throw new HttpsError('failed-precondition', 'Biometric staff device is not active.');
    }
  }

  const challengeId = randomBytes(16).toString('hex');
  const nonce = randomBytes(24).toString('base64url');
  const nowMs = Date.now();
  const issuedAtSec = Math.floor(nowMs / 1000);
  const expiresAt = Timestamp.fromMillis(nowMs + 120_000);

  await db.doc(`staffQrReplaceChallenges/${challengeId}`).create({
    adminUid,
    schoolId: admin.schoolId,
    targetUid: studentUid,
    reason,
    operation: QR_REPLACE_OPERATION,
    deviceId,
    nonce,
    issuedAtSec,
    expiresAt,
    consumed: false,
    createdAt: FieldValue.serverTimestamp(),
  });

  return {challengeId, nonce, issuedAtSec};
});

export const replaceSchoolStudentQr = onCall(resqmeRuntimeOptions, async (request) => {
  const adminUid = request.auth?.uid;
  if (!adminUid) throw new HttpsError('unauthenticated', 'Sign in is required.');
  const data = object(request.data);
  keys(data, ['studentUid', 'reason', 'requestId', 'challengeId', 'method', 'deviceId', 'signature']);

  const studentUid = validateStudentUid(data.studentUid);
  const reason = validateReason(data.reason);
  if (typeof data.requestId !== 'string' || !REQUEST_ID_PATTERN.test(data.requestId)) {
    throw new HttpsError('invalid-argument', 'Invalid QR replacement request ID.');
  }
  const requestId = data.requestId;

  if (typeof data.challengeId !== 'string' || !CHALLENGE_ID_PATTERN.test(data.challengeId)) {
    throw new HttpsError('invalid-argument', 'Invalid QR replacement challenge.');
  }
  const challengeId = data.challengeId;

  if (data.method !== 'biometric' && data.method !== 'password') {
    throw new HttpsError('invalid-argument', 'Invalid verification method.');
  }
  const method = data.method;

  const db = staffManagementDeps.db(adminUid);
  const admin = await requireMasterAdmin(
    db,
    adminUid,
    request.auth?.token.email_verified === true,
  );

  const digest = createHash('sha256')
    .update(JSON.stringify({action: 'replace_student_qr', adminUid, studentUid, reason}))
    .digest('hex');

  const auditRef = db.doc(`staffManagementAudits/${requestId}`);
  const challengeRef = db.doc(`staffQrReplaceChallenges/${challengeId}`);

  // Pre-verify device attestation revocation outside tx if biometric.
  let deviceId: string | null = null;
  let signature: string | null = null;
  if (method === 'biometric') {
    if (typeof data.deviceId !== 'string' || !DEVICE_ID_PATTERN.test(data.deviceId)) {
      throw new HttpsError('invalid-argument', 'Invalid staff device identifier.');
    }
    if (typeof data.signature !== 'string' || !/^[A-Za-z0-9_-]{80,160}$/.test(data.signature)) {
      throw new HttpsError('invalid-argument', 'Invalid biometric signature.');
    }
    deviceId = data.deviceId;
    signature = data.signature;
  }

  let responsePayload: {
    studentUid: string;
    verificationStatus: 'pending' | 'active';
    credentialVersion: number;
    reason: QrReplacementReason;
    issuedAt: string;
  } | null = null;

  await db.runTransaction(async (tx) => {
    const replaySnap = await tx.get(auditRef);
    if (replaySnap.exists) {
      if (replaySnap.get('digest') !== digest) {
        throw new HttpsError('already-exists', 'Request ID already used for another operation.');
      }
      const recordedIssuedAt = replaySnap.get('recordedAt');
      responsePayload = {
        studentUid,
        verificationStatus:
          (replaySnap.get('verificationStatus') as 'pending' | 'active') ?? 'active',
        credentialVersion: Number(replaySnap.get('credentialVersion') ?? 1),
        reason,
        issuedAt:
          recordedIssuedAt && typeof recordedIssuedAt.toDate === 'function'
            ? recordedIssuedAt.toDate().toISOString()
            : new Date().toISOString(),
      };
      return;
    }

    const challengeSnap = await tx.get(challengeRef);
    const challenge = challengeSnap.data();
    const expiresAt = challenge?.expiresAt;
    const expiresMs =
      expiresAt instanceof Timestamp
        ? expiresAt.toMillis()
        : expiresAt instanceof Date
          ? expiresAt.getTime()
          : 0;

    if (
      !challengeSnap.exists ||
      !challenge ||
      challenge.consumed === true ||
      challenge.adminUid !== adminUid ||
      challenge.schoolId !== admin.schoolId ||
      challenge.targetUid !== studentUid ||
      challenge.reason !== reason ||
      challenge.operation !== QR_REPLACE_OPERATION ||
      expiresMs <= Date.now()
    ) {
      throw new HttpsError(
        'failed-precondition',
        'QR replacement verification challenge expired or invalid.',
      );
    }

    if (method === 'biometric') {
      if (challenge.deviceId !== deviceId) {
        throw new HttpsError('permission-denied', 'Biometric device mismatch.');
      }
      const devSnap = await tx.get(db.doc(`staffTier2Devices/${adminUid}`));
      const publicKey = devSnap.get('publicKey');
      if (
        !devSnap.exists ||
        devSnap.get('status') !== 'active' ||
        devSnap.get('deviceId') !== deviceId ||
        devSnap.get('enrollmentProofVersion') !== STAFF_ENROLLMENT_PROOF_VERSION ||
        typeof publicKey !== 'string'
      ) {
        throw new HttpsError('permission-denied', 'Biometric staff device is unavailable.');
      }
      await assertAttestationSerialsNotRevoked(devSnap.get('attestationSerials'));
      const signedMsg = adminQrReplaceSignedMessage({
        adminUid,
        deviceId: deviceId!,
        studentUid,
        reason,
        challengeId,
        nonce: String(challenge.nonce),
      });
      if (!verifyTier2Signature(publicKey, signedMsg, signature!)) {
        throw new HttpsError('permission-denied', 'Biometric verification failed.');
      }
    } else {
      const authTime = request.auth?.token.auth_time;
      requireRecentAuth(authTime);
      const issuedAtSec = Number(challenge.issuedAtSec);
      if (
        typeof authTime !== 'number' ||
        !Number.isFinite(issuedAtSec) ||
        authTime < issuedAtSec
      ) {
        throw new HttpsError(
          'permission-denied',
          'Fresh password confirmation is required for this QR replacement.',
        );
      }
    }

    const {profile, medicalSnap, guardianSnap, credSnap} =
      await loadEligibleStudentForReplacement(tx, db, studentUid, admin.schoolId);

    const rotated = await rotateStudentTier1QrInTx({
      db,
      tx,
      uid: studentUid,
      profile,
      medical: medicalSnap.data(),
      guardianAuthorization: guardianSnap.data(),
      existingCredential: credSnap,
      replacedByUid: adminUid,
      replacementReason: reason,
    });

    tx.update(challengeRef, {
      consumed: true,
      consumedAt: FieldValue.serverTimestamp(),
      method,
    });

    tx.create(auditRef, {
      action: 'replace_student_qr',
      schoolId: admin.schoolId,
      actorUid: adminUid,
      targetUid: studentUid,
      reason,
      method,
      ...(deviceId ? {deviceId} : {}),
      previousCredentialVersion: rotated.previousCredentialVersion,
      credentialVersion: rotated.credentialVersion,
      verificationStatus: rotated.verificationStatus,
      digest,
      recordedAt: FieldValue.serverTimestamp(),
    });

    responsePayload = {
      studentUid,
      verificationStatus: rotated.verificationStatus,
      credentialVersion: rotated.credentialVersion,
      reason,
      issuedAt: new Date().toISOString(),
    };
  });

  return responsePayload!;
});
