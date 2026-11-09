import {FieldValue,Timestamp} from 'firebase-admin/firestore';
import {HttpsError,onCall} from 'firebase-functions/v2/https';
import {onboardingDatabase,resqmeRuntimeOptions} from '../onboarding/authorization';
import {requireRecentAuth,requireTier2Eligible,sanitizeTier2Record,tier2Operation,tier2SignedMessage,validateProof,verifyTier2Signature} from './tier2_challenge';

export const readMyTier2Record=onCall(resqmeRuntimeOptions,async request=>{
  const uid=request.auth!.uid,db=onboardingDatabase(uid);
  requireRecentAuth(request.auth?.token.auth_time);
  const input=validateProof(request.data);
  const profile=db.doc(`studentProfiles/${uid}`),medical=db.doc(`studentMedicalRecords/${uid}`),device=db.doc(`tier2Devices/${uid}`),challenge=db.doc(`tier2Challenges/${input.challengeId}`);
  return db.runTransaction(async tx=>{
    const [p,m,d,c]=await Promise.all([tx.get(profile),tx.get(medical),tx.get(device),tx.get(challenge)]);
    requireTier2Eligible(p.data(),m.data());
    const challengeData=c.data();
    if(!d.exists||d.get('deviceId')!==input.deviceId||d.get('status')!=='active'||!challengeData||challengeData.uid!==uid||challengeData.deviceId!==input.deviceId||challengeData.operation!==tier2Operation||challengeData.consumedAt!=null||!(challengeData.expiresAt instanceof Timestamp)||challengeData.expiresAt.toMillis()<=Date.now()) throw new HttpsError('permission-denied','Tier 2 access is unavailable.');
    const message=tier2SignedMessage({uid,deviceId:input.deviceId,operation:tier2Operation,challengeId:input.challengeId,nonce:challengeData.nonce as string});
    if(!verifyTier2Signature(d.get('publicKey') as string,message,input.signature)) throw new HttpsError('permission-denied','Tier 2 access is unavailable.');
    tx.update(challenge,{consumedAt:FieldValue.serverTimestamp()});
    return sanitizeTier2Record(m.data());
  });
});
