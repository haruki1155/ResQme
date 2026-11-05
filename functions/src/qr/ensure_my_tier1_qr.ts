import {randomBytes} from 'node:crypto';
import {FieldValue} from 'firebase-admin/firestore';
import {HttpsError,onCall} from 'firebase-functions/v2/https';
import {onboardingDatabase,requirePending} from '../onboarding/authorization';
import {keys,object} from '../medical/medical_contract';
export function validateQrRequest(value:unknown) {if(value!=null) keys(object(value),[]);}
export const ensureMyTier1Qr=onCall(async request=>{
  const db=onboardingDatabase(request.auth?.uid);
  validateQrRequest(request.data);
  const profile=db.doc(`studentProfiles/${request.auth!.uid}`),credential=db.doc(`studentQrCredentials/${request.auth!.uid}`);
  await db.runTransaction(async tx=>{
    const [owner,existing]=await Promise.all([tx.get(profile),tx.get(credential)]);
    requirePending(owner.data());
    if(existing.exists){
      if(existing.get('verificationStatus')!=='unverified'||!/^resqme:v1:[A-Za-z0-9_-]{43}$/.test(existing.get('payload'))) throw new HttpsError('failed-precondition','Credential unavailable.');
      return;
    }
    tx.create(credential,{payload:`resqme:v1:${randomBytes(32).toString('base64url')}`,verificationStatus:'unverified',issuedAt:FieldValue.serverTimestamp()});
  });
  const result=await credential.get();
  return {payload:result.get('payload'),verificationStatus:'unverified',issuedAt:result.get('issuedAt').toDate().toISOString()};
});
