import {randomBytes} from 'node:crypto';
import {FieldValue} from 'firebase-admin/firestore';
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {keys, object} from '../medical/medical_contract';
import {requireRecentAuth} from '../medical/tier2_challenge';
import {onboardingDatabase, resqmeRuntimeOptions} from '../onboarding/authorization';
import {requireStaff} from './staff_authorization';

export const issueStaffEnrollmentChallenge = onCall(resqmeRuntimeOptions, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in is required.');
  requireRecentAuth(request.auth?.token.auth_time, undefined, 120);
  keys(object(request.data), []);

  const db = onboardingDatabase(uid);
  const challengeId = randomBytes(24).toString('hex');
  const nonce = randomBytes(32).toString('base64url');
  const expiresAtMs = Date.now() + 60_000;

  await db.runTransaction(async (tx) => {
    const staff = await requireStaff(db, uid, undefined, tx, {
      emailVerified: request.auth?.token.email_verified === true,
    });
    tx.create(db.doc(`staffEnrollmentChallenges/${challengeId}`), {
      staffUid: uid,
      schoolId: staff.schoolId,
      nonce,
      expiresAt: new Date(expiresAtMs),
      consumedAt: null,
      createdAt: FieldValue.serverTimestamp(),
    });
  });

  return {challengeId, nonce, expiresAt: expiresAtMs};
});
