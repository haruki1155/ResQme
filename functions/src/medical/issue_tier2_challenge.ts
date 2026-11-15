import {randomBytes} from 'node:crypto';
import {FieldValue} from 'firebase-admin/firestore';
import {HttpsError,onCall} from 'firebase-functions/v2/https';
import {onboardingDatabase,resqmeRuntimeOptions} from '../onboarding/authorization';
import {requireRecentAuth,requireTier2Eligible,validateChallengeRequest} from './tier2_challenge';

export const issueTier2Challenge=onCall(resqmeRuntimeOptions,async request=>{
  const uid=request.auth?.uid,db=onboardingDatabase(uid);
  requireRecentAuth(request.auth?.token.auth_time);
  const input=validateChallengeRequest(request.data);
  const profile=db.doc(`studentProfiles/${uid}`),medical=db.doc(`studentMedicalRecords/${uid}`),guardian=db.doc(`studentGuardianAuthorizations/${uid}`),device=db.doc(`tier2Devices/${uid}`);
  const challengeId=randomBytes(24).toString('hex'),nonce=randomBytes(32).toString('base64url');
  await db.runTransaction(async tx=>{
    const [p,m,g,d]=await Promise.all([tx.get(profile),tx.get(medical),tx.get(guardian),tx.get(device)]);
    requireTier2Eligible(p.data(),m.data(),{uid:uid!,guardianAuthorization:g.data()});
    if(!d.exists||d.get('deviceId')!==input.deviceId||d.get('status')!=='active') throw new HttpsError('permission-denied','Tier 2 access is unavailable.');
    tx.create(db.doc(`tier2Challenges/${challengeId}`),{uid,deviceId:input.deviceId,operation:input.operation,nonce,expiresAt:new Date(Date.now()+60_000),consumedAt:null,createdAt:FieldValue.serverTimestamp()});
  });
  return {challengeId,nonce,deviceId:input.deviceId,operation:input.operation};
});
