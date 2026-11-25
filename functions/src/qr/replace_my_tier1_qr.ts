import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {keys, object} from '../medical/medical_contract';
import {onboardingDatabase, requirePending, resqmeRuntimeOptions} from '../onboarding/authorization';
import {rotateStudentTier1QrInTx} from './qr_rotation';

export function validateReplaceQrRequest(value: unknown) {
  keys(object(value), []);
}

export const replaceMyTier1Qr = onCall(resqmeRuntimeOptions, async (request) => {
  const uid = request.auth?.uid;
  const db = onboardingDatabase(uid);
  validateReplaceQrRequest(request.data);

  const profile = db.doc(`studentProfiles/${uid}`);
  const medical = db.doc(`studentMedicalRecords/${uid}`);
  const guardian = db.doc(`studentGuardianAuthorizations/${uid}`);
  const credential = db.doc(`studentQrCredentials/${uid}`);

  let verificationStatus: 'pending' | 'active' = 'pending';
  let issuedPayload = '';
  let credentialVersion = 1;

  await db.runTransaction(async (tx) => {
    const [owner, medicalSnapshot, guardianSnapshot, existing] = await Promise.all([
      tx.get(profile),
      tx.get(medical),
      tx.get(guardian),
      tx.get(credential),
    ]);
    const ownerData = requirePending(owner.data());
    if (
      ownerData.schoolApprovalStatus === 'revoked' ||
      (existing.exists && existing.get('verificationStatus') === 'revoked')
    ) {
      throw new HttpsError('failed-precondition', 'Credential unavailable.');
    }

    const rotated = await rotateStudentTier1QrInTx({
      db,
      tx,
      uid: uid!,
      profile: ownerData,
      medical: medicalSnapshot.data(),
      guardianAuthorization: guardianSnapshot.data(),
      existingCredential: existing,
    });
    issuedPayload = rotated.payload;
    verificationStatus = rotated.verificationStatus;
    credentialVersion = rotated.credentialVersion;
  });

  const saved = await credential.get();
  const issuedAt = saved.get('issuedAt');
  return {
    payload: issuedPayload,
    verificationStatus,
    credentialVersion,
    issuedAt:
      issuedAt && typeof issuedAt.toDate === 'function'
        ? issuedAt.toDate().toISOString()
        : new Date().toISOString(),
  };
});
