import {randomBytes} from 'node:crypto';
import {FieldValue, Timestamp} from 'firebase-admin/firestore';
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {
  isStudentAccountDisabled,
  onboardingDatabase,
  resqmeRuntimeOptions,
} from '../onboarding/authorization';
import {evaluateStudentEligibility} from '../qr/qr_eligibility';
import {hashQrPayload} from '../qr/resolve_tier1_qr';
import {hashTrustedDeviceTransferCode} from './enroll_tier2_device';
import {keys, object} from './medical_contract';
import {
  STUDENT_ENROLLMENT_PROOF_VERSION,
  requireRecentAuth,
  requireTier2Eligible,
  tier2ApproveTransferOperation,
  tier2PresentQrOperation,
  tier2SignedMessage,
  validateProof,
  verifyTier2Signature,
} from './tier2_challenge';

export const TIER2_PRESENTATION_PREFIX = 'resqme:tier2:v1:';
const TIER2_PRESENTATION_PATTERN = /^resqme:tier2:v1:[A-Za-z0-9_-]{43}$/;
export const TIER2_PRESENTATION_TTL_SECONDS = 90;
const TRANSFER_CODE_TTL_MS = 10 * 60_000;

export function isTier2PresentationPayload(value: unknown): value is string {
  return typeof value === 'string' && TIER2_PRESENTATION_PATTERN.test(value);
}

function toTimestampMillis(value: unknown): number {
  if (value instanceof Timestamp) return value.toMillis();
  if (value instanceof Date) return value.getTime();
  return 0;
}

export const getMyTrustedDeviceStatus = onCall(resqmeRuntimeOptions, async (request) => {
  const uid = request.auth?.uid;
  const db = onboardingDatabase(uid);
  const data = object(request.data ?? {});
  keys(data, ['deviceId']);
  const candidateDeviceId = data.deviceId;
  if (
    candidateDeviceId !== undefined &&
    candidateDeviceId !== null &&
    (typeof candidateDeviceId !== 'string' || !/^[A-Za-z0-9_-]{20,80}$/.test(candidateDeviceId))
  ) {
    throw new HttpsError('invalid-argument', 'Invalid device identifier.');
  }

  return db.runTransaction(async (tx) => {
    const [profileSnap, deviceSnap] = await Promise.all([
      tx.get(db.doc(`studentProfiles/${uid}`)),
      tx.get(db.doc(`tier2Devices/${uid}`)),
    ]);
    const profile = profileSnap.data();
    if (!profileSnap.exists || !profile || profile.schemaVersion !== 1) {
      throw new HttpsError('failed-precondition', 'Complete student registration first.');
    }
    if (isStudentAccountDisabled(profile)) {
      throw new HttpsError('permission-denied', 'Student account is disabled.');
    }

    const active =
      deviceSnap.exists &&
      deviceSnap.get('status') === 'active' &&
      deviceSnap.get('enrollmentProofVersion') === STUDENT_ENROLLMENT_PROOF_VERSION &&
      typeof deviceSnap.get('deviceId') === 'string' &&
      (deviceSnap.get('deviceId') as string).length >= 20;

    const isCurrentDeviceTrusted =
      active &&
      typeof candidateDeviceId === 'string' &&
      deviceSnap.get('deviceId') === candidateDeviceId;

    const rawVersion = deviceSnap.get('keyVersion');
    return {
      hasActiveTrustedDevice: active,
      isCurrentDeviceTrusted,
      keyVersion: active && Number.isSafeInteger(rawVersion) ? Number(rawVersion) : null,
    };
  });
});

export const issueTrustedDeviceTransferCode = onCall(resqmeRuntimeOptions, async (request) => {
  const uid = request.auth?.uid;
  const db = onboardingDatabase(uid);
  requireRecentAuth(request.auth?.token.auth_time, undefined, 120);
  const input = validateProof(request.data);

  const profileRef = db.doc(`studentProfiles/${uid}`);
  const medicalRef = db.doc(`studentMedicalRecords/${uid}`);
  const guardianRef = db.doc(`studentGuardianAuthorizations/${uid}`);
  const deviceRef = db.doc(`tier2Devices/${uid}`);
  const challengeRef = db.doc(`tier2Challenges/${input.challengeId}`);

  const transferCode = `TDX-${randomBytes(18).toString('base64url').toUpperCase()}`;
  const grantHash = hashTrustedDeviceTransferCode(transferCode);
  const expiresAtMs = Date.now() + TRANSFER_CODE_TTL_MS;

  await db.runTransaction(async (tx) => {
    const [p, m, g, d, c] = await Promise.all([
      tx.get(profileRef),
      tx.get(medicalRef),
      tx.get(guardianRef),
      tx.get(deviceRef),
      tx.get(challengeRef),
    ]);
    requireTier2Eligible(p.data(), m.data(), {
      uid: uid!,
      guardianAuthorization: g.data(),
    });
    const challengeData = c.data();
    if (
      !d.exists ||
      d.get('deviceId') !== input.deviceId ||
      d.get('status') !== 'active' ||
      !challengeData ||
      challengeData.uid !== uid ||
      challengeData.deviceId !== input.deviceId ||
      challengeData.operation !== tier2ApproveTransferOperation ||
      challengeData.consumedAt != null ||
      toTimestampMillis(challengeData.expiresAt) <= Date.now()
    ) {
      throw new HttpsError('permission-denied', 'Trusted-device transfer approval is unavailable.');
    }
    if (d.get('enrollmentProofVersion') !== STUDENT_ENROLLMENT_PROOF_VERSION) {
      throw new HttpsError('failed-precondition', 'Biometric security setup is required.');
    }
    const message = tier2SignedMessage({
      uid: uid!,
      deviceId: input.deviceId,
      operation: tier2ApproveTransferOperation,
      challengeId: input.challengeId,
      nonce: challengeData.nonce as string,
    });
    if (!verifyTier2Signature(d.get('publicKey') as string, message, input.signature)) {
      throw new HttpsError('permission-denied', 'Trusted-device transfer signature failed.');
    }

    tx.update(challengeRef, {consumedAt: FieldValue.serverTimestamp()});
    tx.create(db.doc(`studentDeviceTransferGrants/${grantHash}`), {
      uid,
      fromDeviceId: input.deviceId,
      fromKeyVersion: Number(d.get('keyVersion') || 1),
      expiresAt: new Date(expiresAtMs),
      consumedAt: null,
      createdAt: FieldValue.serverTimestamp(),
    });
    const pData = p.data();
    if (
      pData?.schoolAssignmentStatus === 'assigned' &&
      typeof pData.schoolId === 'string' &&
      pData.schoolId.length >= 2
    ) {
      tx.create(db.doc(`staffManagementAudits/${randomBytes(16).toString('hex')}`), {
        actorUid: uid,
        actorRole: 'student',
        schoolId: pData.schoolId,
        action: 'approve_student_device_transfer',
        targetUid: uid,
        outcome: 'allowed',
        createdAt: FieldValue.serverTimestamp(),
      });
    }
  });

  return {
    transferCode,
    expiresAt: expiresAtMs,
  };
});

export const issueMyTier2PresentationToken = onCall(resqmeRuntimeOptions, async (request) => {
  const uid = request.auth?.uid;
  const db = onboardingDatabase(uid);
  const input = validateProof(request.data);

  const profileRef = db.doc(`studentProfiles/${uid}`);
  const medicalRef = db.doc(`studentMedicalRecords/${uid}`);
  const guardianRef = db.doc(`studentGuardianAuthorizations/${uid}`);
  const deviceRef = db.doc(`tier2Devices/${uid}`);
  const challengeRef = db.doc(`tier2Challenges/${input.challengeId}`);

  const payload = `${TIER2_PRESENTATION_PREFIX}${randomBytes(32).toString('base64url')}`;
  const tokenHash = hashQrPayload(payload);
  const expiresAtMs = Date.now() + TIER2_PRESENTATION_TTL_SECONDS * 1000;

  await db.runTransaction(async (tx) => {
    const [p, m, g, d, c, nextTokenSnap] = await Promise.all([
      tx.get(profileRef),
      tx.get(medicalRef),
      tx.get(guardianRef),
      tx.get(deviceRef),
      tx.get(challengeRef),
      tx.get(db.doc(`studentTier2PresentationTokens/${tokenHash}`)),
    ]);
    if (nextTokenSnap.exists) {
      throw new HttpsError('aborted', 'Retry Tier 2 QR unlock.');
    }
    const pData = p.data();
    const mData = m.data();
    if (
      !evaluateStudentEligibility({
        uid: uid!,
        profile: pData,
        medical: mData,
        guardianAuthorization: g.data(),
      })
    ) {
      throw new HttpsError('permission-denied', 'Tier 2 presentation is unavailable.');
    }
    const challengeData = c.data();
    if (
      !d.exists ||
      d.get('deviceId') !== input.deviceId ||
      d.get('status') !== 'active' ||
      !challengeData ||
      challengeData.uid !== uid ||
      challengeData.deviceId !== input.deviceId ||
      challengeData.operation !== tier2PresentQrOperation ||
      challengeData.consumedAt != null ||
      toTimestampMillis(challengeData.expiresAt) <= Date.now()
    ) {
      throw new HttpsError('permission-denied', 'Tier 2 presentation is unavailable.');
    }
    if (d.get('enrollmentProofVersion') !== STUDENT_ENROLLMENT_PROOF_VERSION) {
      throw new HttpsError('failed-precondition', 'Biometric security setup is required.');
    }
    const message = tier2SignedMessage({
      uid: uid!,
      deviceId: input.deviceId,
      operation: tier2PresentQrOperation,
      challengeId: input.challengeId,
      nonce: challengeData.nonce as string,
    });
    if (!verifyTier2Signature(d.get('publicKey') as string, message, input.signature)) {
      throw new HttpsError('permission-denied', 'Tier 2 biometric proof failed.');
    }

    const priorHash = d.get('activePresentationTokenHash');
    if (typeof priorHash === 'string' && priorHash.length === 64 && priorHash !== tokenHash) {
      tx.set(
        db.doc(`studentTier2PresentationTokens/${priorHash}`),
        {status: 'revoked', revokedAt: FieldValue.serverTimestamp()},
        {merge: true},
      );
    }

    const keyVersion = Number(d.get('keyVersion') || 1);
    tx.update(challengeRef, {consumedAt: FieldValue.serverTimestamp()});
    tx.update(deviceRef, {
      activePresentationTokenHash: tokenHash,
      lastPresentedAt: FieldValue.serverTimestamp(),
    });
    tx.create(db.doc(`studentTier2PresentationTokens/${tokenHash}`), {
      uid,
      deviceId: input.deviceId,
      keyVersion,
      medicalRevision: Number(mData?.revision ?? 0),
      status: 'active',
      expiresAt: new Date(expiresAtMs),
      consumedAt: null,
      createdAt: FieldValue.serverTimestamp(),
    });
  });

  return {
    payload,
    expiresAt: expiresAtMs,
    ttlSeconds: TIER2_PRESENTATION_TTL_SECONDS,
  };
});
