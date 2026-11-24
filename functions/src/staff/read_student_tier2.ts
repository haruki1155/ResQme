import {randomBytes} from 'node:crypto';
import {FieldValue, Timestamp} from 'firebase-admin/firestore';
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {sanitizeTier2Record, verifyTier2Signature} from '../medical/tier2_challenge';
import {onboardingDatabase, resqmeRuntimeOptions} from '../onboarding/authorization';
import {evaluateQrEligibility} from '../qr/qr_eligibility';
import {hashQrPayload} from '../qr/resolve_tier1_qr';
import {assertAttestationSerialsNotRevoked} from './staff_attestation';
import {requireStaff} from './staff_authorization';
import {
  STAFF_ENROLLMENT_PROOF_VERSION,
  staffTier2Operation,
  staffTier2SignedMessage,
  validateStaffProofRequest,
} from './staff_tier2_contract';

export const readStudentTier2 = onCall(resqmeRuntimeOptions, async (request) => {
  const staffUid = request.auth?.uid;
  if (!staffUid) throw new HttpsError('unauthenticated', 'Sign in is required.');
  const input = validateStaffProofRequest(request.data);
  const db = onboardingDatabase(staffUid);

  const challengeRef = db.doc(`staffTier2Challenges/${input.challengeId}`);
  const deviceRef = db.doc(`staffTier2Devices/${staffUid}`);
  const auditRef = db.doc(`tier2AccessAudits/${randomBytes(16).toString('hex')}`);

  let denialContext: {
    schoolId?: string;
    targetUid?: string;
    purpose?: string;
    reason: string;
  } = {reason: 'denied'};

  try {
    return await db.runTransaction(async (tx) => {
      const staff = await requireStaff(db, staffUid, ['admin', 'authorized'], tx, {
        emailVerified: request.auth?.token.email_verified === true,
      });
      denialContext.schoolId = staff.schoolId;

      const [deviceSnap, challengeSnap] = await Promise.all([
        tx.get(deviceRef),
        tx.get(challengeRef),
      ]);
      const challenge = challengeSnap.data();
      if (challenge) {
        if (typeof challenge.targetUid === 'string') denialContext.targetUid = challenge.targetUid;
        if (typeof challenge.purpose === 'string') denialContext.purpose = challenge.purpose;
      }

      const expiresAt = challenge?.expiresAt;
      const expiresMs =
        expiresAt instanceof Timestamp
          ? expiresAt.toMillis()
          : expiresAt instanceof Date
            ? expiresAt.getTime()
            : 0;

      if (
        !deviceSnap.exists ||
        deviceSnap.get('status') !== 'active' ||
        deviceSnap.get('deviceId') !== input.deviceId ||
        typeof deviceSnap.get('publicKey') !== 'string' ||
        !challengeSnap.exists ||
        !challenge ||
        challenge.staffUid !== staffUid ||
        challenge.schoolId !== staff.schoolId ||
        challenge.deviceId !== input.deviceId ||
        challenge.keyVersion !== deviceSnap.get('keyVersion') ||
        challenge.operation !== staffTier2Operation ||
        challenge.consumedAt != null ||
        typeof challenge.nonce !== 'string' ||
        typeof challenge.targetUid !== 'string' ||
        typeof challenge.qrHash !== 'string' ||
        typeof challenge.purpose !== 'string' ||
        expiresMs <= Date.now()
      ) {
        denialContext.reason = 'invalid_challenge_or_device';
        throw new HttpsError('permission-denied', 'Emergency Tier 2 access is unavailable.');
      }
      if (deviceSnap.get('enrollmentProofVersion') !== STAFF_ENROLLMENT_PROOF_VERSION) {
        denialContext.reason = 'device_reenrollment_required';
        throw new HttpsError(
          'failed-precondition',
          'Biometric device re-enrollment is required.',
        );
      }
      try {
        await assertAttestationSerialsNotRevoked(deviceSnap.get('attestationSerials'));
      } catch (err) {
        denialContext.reason = 'attestation_revoked_or_unavailable';
        throw err;
      }

      const message = staffTier2SignedMessage({
        staffUid,
        deviceId: input.deviceId,
        operation: staffTier2Operation,
        purpose: challenge.purpose,
        challengeId: input.challengeId,
        nonce: challenge.nonce,
      });
      if (!verifyTier2Signature(deviceSnap.get('publicKey') as string, message, input.signature)) {
        denialContext.reason = 'invalid_signature';
        throw new HttpsError('permission-denied', 'Emergency Tier 2 access is unavailable.');
      }

      const targetUid = challenge.targetUid;
      const qrHash = challenge.qrHash;
      const [profileSnap, credentialSnap, lookupSnap, medicalSnap, guardianSnap] = await Promise.all([
        tx.get(db.doc(`studentProfiles/${targetUid}`)),
        tx.get(db.doc(`studentQrCredentials/${targetUid}`)),
        tx.get(db.doc(`studentQrLookups/${qrHash}`)),
        tx.get(db.doc(`studentMedicalRecords/${targetUid}`)),
        tx.get(db.doc(`studentGuardianAuthorizations/${targetUid}`)),
      ]);
      const profile = profileSnap.data();
      const credential = credentialSnap.data();
      const medical = medicalSnap.data();
      const livePayload = typeof credential?.payload === 'string' ? credential.payload : '';

      if (
        !profileSnap.exists ||
        !credentialSnap.exists ||
        !lookupSnap.exists ||
        !medicalSnap.exists ||
        profile?.schoolId !== staff.schoolId ||
        lookupSnap.get('status') !== 'active' ||
        lookupSnap.get('uid') !== targetUid ||
        !livePayload ||
        hashQrPayload(livePayload) !== qrHash ||
        medical?.revision !== challenge.medicalRevision ||
        !evaluateQrEligibility({
          uid: targetUid,
          profile,
          medical,
          guardianAuthorization: guardianSnap.data(),
          credential,
          lookup: lookupSnap.data(),
        })
      ) {
        denialContext.reason = 'target_ineligible_or_qr_changed';
        throw new HttpsError('permission-denied', 'Emergency Tier 2 access is unavailable.');
      }

      const sanitized = sanitizeTier2Record(medical);

      // Consume challenge and write immutable audit atomically; audit write failure aborts release.
      tx.update(challengeRef, {consumedAt: FieldValue.serverTimestamp()});
      tx.create(auditRef, {
        actorUid: staffUid,
        actorRole: staff.role,
        schoolId: staff.schoolId,
        targetUid,
        deviceId: input.deviceId,
        purpose: challenge.purpose,
        outcome: 'allowed',
        recordedAt: FieldValue.serverTimestamp(),
      });

      return sanitized;
    });
  } catch (error) {
    if (error instanceof HttpsError && error.code === 'permission-denied') {
      try {
        await db.doc(`tier2AccessAudits/${randomBytes(16).toString('hex')}`).create({
          actorUid: staffUid,
          schoolId: denialContext.schoolId ?? null,
          targetUid: denialContext.targetUid ?? null,
          deviceId: input.deviceId,
          purpose: denialContext.purpose ?? null,
          outcome: 'denied',
          reasonCode: denialContext.reason,
          recordedAt: FieldValue.serverTimestamp(),
        });
      } catch {
        // Denial audit failure must never mask the security denial itself.
      }
    }
    throw error;
  }
});
