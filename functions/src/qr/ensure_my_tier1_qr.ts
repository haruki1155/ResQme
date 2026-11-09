import {createHash,randomBytes} from 'node:crypto';
import {FieldValue} from 'firebase-admin/firestore';
import {HttpsError,onCall} from 'firebase-functions/v2/https';
import {onboardingDatabase,requireQrEligible,resqmeRuntimeOptions} from '../onboarding/authorization';
import {keys,object} from '../medical/medical_contract';
export function validateQrRequest(value:unknown) {if(value!=null) keys(object(value),[]);}
export const ensureMyTier1Qr=onCall(resqmeRuntimeOptions, async request=>{
  const db=onboardingDatabase(request.auth?.uid);
  validateQrRequest(request.data);
  const uid=request.auth!.uid;
  const profile=db.doc(`studentProfiles/${uid}`),credential=db.doc(`studentQrCredentials/${uid}`);
  await db.runTransaction(async tx=>{
    const [owner,existing]=await Promise.all([tx.get(profile),tx.get(credential)]);
    requireQrEligible(owner.data());
    if(existing.exists){
      const payload=existing.get('payload');
      if(!isQrPayload(payload)||existing.get('verificationStatus')!=='active') throw new HttpsError('failed-precondition','Credential unavailable.');
      const lookup=db.doc(`studentQrLookups/${hashQr(payload)}`);
      const index=await tx.get(lookup);
      if(!index.exists||index.get('uid')!==uid||index.get('status')!=='active') throw new HttpsError('failed-precondition','Credential unavailable.');
      return;
    }
    const payload=`resqme:v1:${randomBytes(32).toString('base64url')}`;
    tx.create(credential,{payload,verificationStatus:'active',issuedAt:FieldValue.serverTimestamp(),activatedAt:FieldValue.serverTimestamp()});
    tx.create(db.doc(`studentQrLookups/${hashQr(payload)}`),{uid,status:'active',createdAt:FieldValue.serverTimestamp()});
  });
  const result=await credential.get();
  return {payload:result.get('payload'),verificationStatus:'active',issuedAt:result.get('issuedAt').toDate().toISOString()};
});

export function isQrPayload(value:unknown):value is string {
  if(typeof value!=='string'||!/^resqme:v1:[A-Za-z0-9_-]{43}$/.test(value)) return false;
  const reference=value.slice('resqme:v1:'.length);
  try{return Buffer.from(reference,'base64url').length===32&&Buffer.from(reference,'base64url').toString('base64url')===reference;}catch{return false;}
}
export function hashQr(payload:string){return createHash('sha256').update(payload,'utf8').digest('hex');}
