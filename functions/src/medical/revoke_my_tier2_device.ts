import {FieldValue} from 'firebase-admin/firestore';
import {onCall} from 'firebase-functions/v2/https';
import {isStudentAccountDisabled,onboardingDatabase,resqmeRuntimeOptions} from '../onboarding/authorization';
import {HttpsError} from 'firebase-functions/v2/https';
import {requireRecentAuth} from './tier2_challenge';
import {keys,object} from './medical_contract';

export const revokeMyTier2Device=onCall(resqmeRuntimeOptions,async request=>{
  const uid=request.auth?.uid,db=onboardingDatabase(uid);
  requireRecentAuth(request.auth?.token.auth_time,Math.floor(Date.now()/1000),120);
  keys(object(request.data),[]);
  const profile=db.doc(`studentProfiles/${uid}`);
  const device=db.doc(`tier2Devices/${uid}`);
  await db.runTransaction(async tx=>{
    const [profileSnap,current]=await Promise.all([tx.get(profile),tx.get(device)]);
    if(isStudentAccountDisabled(profileSnap.data())) throw new HttpsError('permission-denied','Student account is disabled.');
    if(current.exists&&current.get('status')==='active') tx.update(device,{status:'revoked',revokedAt:FieldValue.serverTimestamp()});
  });
  return {status:'revoked'};
});
