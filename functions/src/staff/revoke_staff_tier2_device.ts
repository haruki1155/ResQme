import {FieldValue} from 'firebase-admin/firestore';
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {keys, object} from '../medical/medical_contract';
import {requireRecentAuth} from '../medical/tier2_challenge';
import {onboardingDatabase, resqmeRuntimeOptions} from '../onboarding/authorization';

export const revokeStaffTier2Device = onCall(resqmeRuntimeOptions, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in is required.');
  requireRecentAuth(request.auth?.token.auth_time, undefined, 120);
  keys(object(request.data), []);

  const db = onboardingDatabase(uid);
  const deviceRef = db.doc(`staffTier2Devices/${uid}`);
  await db.runTransaction(async (tx) => {
    const existing = await tx.get(deviceRef);
    tx.set(
      deviceRef,
      {
        status: 'revoked',
        keyVersion: Number(existing.get('keyVersion') || 0) + 1,
        revokedAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
  });

  return {status: 'revoked' as const};
});
