import {randomBytes} from 'node:crypto';
import {FieldValue} from 'firebase-admin/firestore';
import {onCall} from 'firebase-functions/v2/https';
import {onboardingDatabase,resqmeRuntimeOptions} from '../onboarding/authorization';
import {keys,object} from './medical_contract';
import {requireRecentAuth,requireTier2Eligible} from './tier2_challenge';

export const issueStudentEnrollmentChallenge=onCall(resqmeRuntimeOptions,async request=>{
  const uid=request.auth?.uid,db=onboardingDatabase(uid);
  requireRecentAuth(request.auth?.token.auth_time,undefined,120);
  keys(object(request.data),[]);
  const challengeId=randomBytes(24).toString('hex');
  const nonce=randomBytes(32).toString('base64url');
  const expiresAtMs=Date.now()+60_000;
  await db.runTransaction(async tx=>{
    const [profile,medical,guardian]=await Promise.all([
      tx.get(db.doc(`studentProfiles/${uid}`)),
      tx.get(db.doc(`studentMedicalRecords/${uid}`)),
      tx.get(db.doc(`studentGuardianAuthorizations/${uid}`)),
    ]);
    requireTier2Eligible(profile.data(),medical.data(),{uid:uid!,guardianAuthorization:guardian.data()});
    tx.create(db.doc(`tier2EnrollmentChallenges/${challengeId}`),{
      uid,
      nonce,
      expiresAt:new Date(expiresAtMs),
      consumedAt:null,
      createdAt:FieldValue.serverTimestamp(),
    });
  });
  return {challengeId,nonce,expiresAt:expiresAtMs};
});
