import {createHash,randomBytes} from 'node:crypto';
import {FieldValue} from 'firebase-admin/firestore';
import {HttpsError,onCall} from 'firebase-functions/v2/https';
import {onboardingDatabase,requirePending,resqmeRuntimeOptions} from '../onboarding/authorization';
import {keys,object} from '../medical/medical_contract';
import {evaluateQrEligibility} from './qr_eligibility';
export function validateQrRequest(value:unknown) {if(value!=null) keys(object(value),[]);}
export const ensureMyTier1Qr=onCall(resqmeRuntimeOptions, async request=>{
  const db=onboardingDatabase(request.auth?.uid);
  validateQrRequest(request.data);
  const uid=request.auth!.uid;
  const profile=db.doc(`studentProfiles/${uid}`),medical=db.doc(`studentMedicalRecords/${uid}`),guardian=db.doc(`studentGuardianAuthorizations/${uid}`),credential=db.doc(`studentQrCredentials/${uid}`);
  let verificationStatus:'pending'|'active'='pending';
  await db.runTransaction(async tx=>{
    const [owner,medicalSnapshot,guardianSnapshot,existing]=await Promise.all([tx.get(profile),tx.get(medical),tx.get(guardian),tx.get(credential)]);
    const ownerData=requirePending(owner.data());
    if(ownerData.schoolApprovalStatus==='revoked') throw new HttpsError('failed-precondition','Credential unavailable.');
    if(existing.exists){
      const payload=existing.get('payload');
      const oldStatus=existing.get('verificationStatus');
      if(!isQrPayload(payload)||!['pending','active'].includes(oldStatus as string)) throw new HttpsError('failed-precondition','Credential unavailable.');
      const lookup=db.doc(`studentQrLookups/${hashQr(payload)}`);
      const index=await tx.get(lookup);
      if(!index.exists||index.get('uid')!==uid||index.get('status')!==oldStatus) throw new HttpsError('failed-precondition','Credential unavailable.');
      const eligible=evaluateQrEligibility({uid,profile:ownerData,medical:medicalSnapshot.data(),guardianAuthorization:guardianSnapshot.data(),credential:existing.data(),lookup:index.data()});
      if(oldStatus==='active'&&!eligible){
        throw new HttpsError('failed-precondition','Credential unavailable.');
      }
      if(oldStatus==='pending'&&eligible){
        tx.update(credential,{verificationStatus:'active',activatedAt:FieldValue.serverTimestamp()});
        tx.update(lookup,{status:'active',activatedAt:FieldValue.serverTimestamp()});
        verificationStatus='active';
        return;
      }
      if(oldStatus==='revoked') throw new HttpsError('failed-precondition','Credential unavailable.');
      verificationStatus=oldStatus as 'pending'|'active';
      return;
    }
    const payload=`resqme:v1:${randomBytes(32).toString('base64url')}`;
    const lookup=db.doc(`studentQrLookups/${hashQr(payload)}`);
    if((await tx.get(lookup)).exists) throw new HttpsError('internal','Credential unavailable.');
    const status=evaluateQrEligibility({uid,profile:ownerData,medical:medicalSnapshot.data(),guardianAuthorization:guardianSnapshot.data(),credential:{payload,verificationStatus:'pending'}})?'active':'pending';
    tx.create(credential,{payload,verificationStatus:status,issuedAt:FieldValue.serverTimestamp(),...(status==='active'?{activatedAt:FieldValue.serverTimestamp()}:{})});
    tx.create(lookup,{uid,status,createdAt:FieldValue.serverTimestamp(),...(status==='active'?{activatedAt:FieldValue.serverTimestamp()}:{})});
    verificationStatus=status;
  });
  const result=await credential.get();
  return {payload:result.get('payload'),verificationStatus,issuedAt:result.get('issuedAt').toDate().toISOString()};
});

export function isQrPayload(value:unknown):value is string {
  if(typeof value!=='string'||!/^resqme:v1:[A-Za-z0-9_-]{43}$/.test(value)) return false;
  const reference=value.slice('resqme:v1:'.length);
  try{return Buffer.from(reference,'base64url').length===32&&Buffer.from(reference,'base64url').toString('base64url')===reference;}catch{return false;}
}
export function hashQr(payload:string){return createHash('sha256').update(payload,'utf8').digest('hex');}
