import {FieldValue} from 'firebase-admin/firestore';
import {HttpsError,onCall} from 'firebase-functions/v2/https';
import {onboardingDatabase,resqmeRuntimeOptions} from '../onboarding/authorization';
import {requireRecentAuth} from './tier2_challenge';
import {keys,object} from './medical_contract';

export const revokeMyTier2Device=onCall(resqmeRuntimeOptions,async request=>{
  const uid=request.auth?.uid,db=onboardingDatabase(uid);
  requireRecentAuth(request.auth?.token.auth_time,Math.floor(Date.now()/1000),120);
  keys(object(request.data),[]);
  const device=db.doc(`tier2Devices/${uid}`);
  await db.runTransaction(async tx=>{
    const current=await tx.get(device);
    if(current.exists&&current.get('status')==='active') tx.update(device,{status:'revoked',revokedAt:FieldValue.serverTimestamp()});
  });
  return {status:'revoked'};
});
