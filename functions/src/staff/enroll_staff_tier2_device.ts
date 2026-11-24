import {randomBytes} from 'node:crypto';
import {FieldValue, Timestamp} from 'firebase-admin/firestore';
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {keys, object} from '../medical/medical_contract';
import {requireRecentAuth, verifyTier2Signature} from '../medical/tier2_challenge';
import {onboardingDatabase, resqmeRuntimeOptions} from '../onboarding/authorization';
import {verifyAndroidKeyAttestation} from './staff_attestation';
import {requireStaff} from './staff_authorization';
import {
  STAFF_ENROLLMENT_PROOF_VERSION,
  staffEnrollmentSignedMessage,
} from './staff_tier2_contract';

function validateStaffEnrollmentRequest(value: unknown) {
  const data = object(value);
  keys(data, ['challengeId', 'deviceId', 'publicKey', 'attestationChain', 'signature']);
  if (
    typeof data.challengeId !== 'string' ||
    !/^[A-Fa-f0-9]{32,64}$/.test(data.challengeId) ||
    typeof data.deviceId !== 'string' ||
    !/^[A-Za-z0-9_-]{20,80}$/.test(data.deviceId) ||
    typeof data.publicKey !== 'string' ||
    data.publicKey.length > 1024 ||
    !Array.isArray(data.attestationChain) ||
    typeof data.signature !== 'string' ||
    !/^[A-Za-z0-9_-]{80,160}$/.test(data.signature)
  ) {
    throw new HttpsError('invalid-argument', 'Invalid staff device enrollment.');
  }
  return {
    challengeId: data.challengeId,
    deviceId: data.deviceId,
    publicKey: data.publicKey,
    attestationChain: data.attestationChain,
    signature: data.signature,
  };
}

export const enrollStaffTier2Device = onCall(resqmeRuntimeOptions, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in is required.');
  requireRecentAuth(request.auth?.token.auth_time, undefined, 120);
  const input = validateStaffEnrollmentRequest(request.data);
  const db = onboardingDatabase(uid);

  const challengeRef = db.doc(`staffEnrollmentChallenges/${input.challengeId}`);
  const deviceRef = db.doc(`staffTier2Devices/${uid}`);
  const auditRef = db.doc(`staffManagementAudits/${randomBytes(16).toString('hex')}`);

  const keyVersion = await db.runTransaction(async (tx) => {
    const staff = await requireStaff(db, uid, undefined, tx, {
      emailVerified: request.auth?.token.email_verified === true,
    });
    const [challengeSnap, oldDevice] = await Promise.all([
      tx.get(challengeRef),
      tx.get(deviceRef),
    ]);
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
      challenge.staffUid !== uid ||
      challenge.schoolId !== staff.schoolId ||
      challenge.consumedAt != null ||
      typeof challenge.nonce !== 'string' ||
      expiresMs <= Date.now()
    ) {
      throw new HttpsError('permission-denied', 'Enrollment challenge is invalid or expired.');
    }

    const attestation = await verifyAndroidKeyAttestation({
      publicKey: input.publicKey,
      attestationChain: input.attestationChain,
      expectedChallenge: Buffer.from(challenge.nonce, 'base64url'),
    });

    const expectedMessage = staffEnrollmentSignedMessage({
      staffUid: uid,
      deviceId: input.deviceId,
      challengeId: input.challengeId,
      nonce: challenge.nonce,
    });
    if (!verifyTier2Signature(input.publicKey, expectedMessage, input.signature)) {
      throw new HttpsError(
        'permission-denied',
        'Device biometric proof could not be verified.',
      );
    }

    const nextVersion = Number(oldDevice.get('keyVersion') || 0) + 1;
    tx.update(challengeRef, {consumedAt: FieldValue.serverTimestamp()});
    tx.set(deviceRef, {
      staffUid: uid,
      schoolId: staff.schoolId,
      deviceId: input.deviceId,
      publicKey: input.publicKey,
      attestationLevel: attestation.securityLevel,
      attestationSerials: attestation.certificateSerials,
      attestationVerifiedAt: FieldValue.serverTimestamp(),
      enrollmentProofVersion: STAFF_ENROLLMENT_PROOF_VERSION,
      status: 'active',
      keyVersion: nextVersion,
      enrolledAt: FieldValue.serverTimestamp(),
    });
    tx.create(auditRef, {
      actorUid: uid,
      actorRole: staff.role,
      schoolId: staff.schoolId,
      action: 'enroll_staff_biometric_device',
      targetUid: uid,
      outcome: 'allowed',
      enrollmentProofVersion: STAFF_ENROLLMENT_PROOF_VERSION,
      createdAt: FieldValue.serverTimestamp(),
    });
    return nextVersion;
  });

  return {
    deviceId: input.deviceId,
    status: 'active' as const,
    keyVersion,
    enrollmentProofVersion: STAFF_ENROLLMENT_PROOF_VERSION,
  };
});
