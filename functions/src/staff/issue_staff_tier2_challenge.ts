import {randomBytes} from 'node:crypto';
import {FieldValue} from 'firebase-admin/firestore';
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {onboardingDatabase, resqmeRuntimeOptions} from '../onboarding/authorization';
import {evaluateQrEligibility} from '../qr/qr_eligibility';
import {hashQrPayload} from '../qr/resolve_tier1_qr';
import {assertAttestationSerialsNotRevoked} from './staff_attestation';
import {requireStaff} from './staff_authorization';
import {
  allowStaffTier2Challenge,
  staffTier2Operation,
  validateStaffChallengeRequest,
} from './staff_tier2_contract';

export const issueStaffTier2Challenge = onCall(resqmeRuntimeOptions, async (request) => {
  const staffUid = request.auth?.uid;
  if (!staffUid) throw new HttpsError('unauthenticated', 'Sign in is required.');
  const input = validateStaffChallengeRequest(request.data);
  if (!allowStaffTier2Challenge(staffUid)) {
    throw new HttpsError('resource-exhausted', 'Too many Tier 2 requests.');
  }

  const db = onboardingDatabase(staffUid);
  const qrHash = hashQrPayload(input.payload);
  const challengeId = randomBytes(24).toString('hex');
  const nonce = randomBytes(32).toString('base64url');
  const expiresAtMs = Date.now() + 60_000;

  await db.runTransaction(async (tx) => {
    const staff = await requireStaff(db, staffUid, ['admin', 'authorized'], tx, {
      emailVerified: request.auth?.token.email_verified === true,
    });
    const [deviceSnap, lookupSnap] = await Promise.all([
      tx.get(db.doc(`staffTier2Devices/${staffUid}`)),
      tx.get(db.doc(`studentQrLookups/${qrHash}`)),
    ]);
    if (
      !deviceSnap.exists ||
      deviceSnap.get('status') !== 'active' ||
      deviceSnap.get('deviceId') !== input.deviceId ||
      typeof deviceSnap.get('publicKey') !== 'string' ||
      !Number.isSafeInteger(deviceSnap.get('keyVersion'))
    ) {
      throw new HttpsError('permission-denied', 'Emergency Tier 2 access is unavailable.');
    }
    await assertAttestationSerialsNotRevoked(deviceSnap.get('attestationSerials'));
    const targetUid = lookupSnap.get('uid');
    if (
      !lookupSnap.exists ||
      lookupSnap.get('status') !== 'active' ||
      typeof targetUid !== 'string' ||
      !targetUid
    ) {
      throw new HttpsError('permission-denied', 'Emergency Tier 2 access is unavailable.');
    }
    const [profileSnap, credentialSnap, medicalSnap, guardianSnap] = await Promise.all([
      tx.get(db.doc(`studentProfiles/${targetUid}`)),
      tx.get(db.doc(`studentQrCredentials/${targetUid}`)),
      tx.get(db.doc(`studentMedicalRecords/${targetUid}`)),
      tx.get(db.doc(`studentGuardianAuthorizations/${targetUid}`)),
    ]);
    const profile = profileSnap.data();
    const credential = credentialSnap.data();
    const medical = medicalSnap.data();
    if (
      !profileSnap.exists ||
      !credentialSnap.exists ||
      !medicalSnap.exists ||
      profile?.schoolId !== staff.schoolId ||
      credential?.payload !== input.payload ||
      !evaluateQrEligibility({
        uid: targetUid,
        profile,
        medical,
        guardianAuthorization: guardianSnap.data(),
        credential,
        lookup: lookupSnap.data(),
      })
    ) {
      throw new HttpsError('permission-denied', 'Emergency Tier 2 access is unavailable.');
    }

    tx.create(db.doc(`staffTier2Challenges/${challengeId}`), {
      staffUid,
      actorRole: staff.role,
      schoolId: staff.schoolId,
      deviceId: input.deviceId,
      keyVersion: Number(deviceSnap.get('keyVersion')),
      targetUid,
      qrHash,
      medicalRevision: Number(medical?.revision),
      operation: staffTier2Operation,
      purpose: input.purpose,
      nonce,
      expiresAt: new Date(expiresAtMs),
      consumedAt: null,
      createdAt: FieldValue.serverTimestamp(),
    });
  });

  // Opaque challenge only: zero student identity or medical fields before biometric proof.
  return {
    challengeId,
    nonce,
    deviceId: input.deviceId,
    operation: staffTier2Operation,
    purpose: input.purpose,
    expiresAt: expiresAtMs,
  };
});
