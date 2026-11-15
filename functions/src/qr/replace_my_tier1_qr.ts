import {randomBytes,createHash} from 'node:crypto';
import {FieldValue} from 'firebase-admin/firestore';
import {HttpsError,onCall} from 'firebase-functions/v2/https';
import {onboardingDatabase,requirePending,resqmeRuntimeOptions} from '../onboarding/authorization';
import {keys,object} from '../medical/medical_contract';
import {isQrPayload} from './ensure_my_tier1_qr';
import {evaluateQrEligibility} from './qr_eligibility';

function hash(payload:string){return createHash('sha256').update(payload,'utf8').digest('hex');}
export function validateReplaceQrRequest(value:unknown){keys(object(value),[]);}
export const replaceMyTier1Qr=onCall(resqmeRuntimeOptions,async request=>{
  const uid=request.auth?.uid,db=onboardingDatabase(uid);
  validateReplaceQrRequest(request.data);
  const profile=db.doc(`studentProfiles/${uid}`),medical=db.doc(`studentMedicalRecords/${uid}`),guardian=db.doc(`studentGuardianAuthorizations/${uid}`),credential=db.doc(`studentQrCredentials/${uid}`);
  let issuedPayload='';
  await db.runTransaction(async tx=>{
    const [owner,medicalSnapshot,guardianSnapshot,existing]=await Promise.all([tx.get(profile),tx.get(medical),tx.get(guardian),tx.get(credential)]);
    const ownerData=requirePending(owner.data());
    if(ownerData.schoolApprovalStatus==='revoked') throw new HttpsError('failed-precondition','Credential unavailable.');
    let oldLookup:FirebaseFirestore.DocumentReference|undefined;
    if(existing.exists) {
      const oldStatus=existing.get('verificationStatus');
      if(oldStatus==='revoked'||!['active','pending'].includes(oldStatus as string)) throw new HttpsError('failed-precondition','Credential unavailable.');
      const oldPayload=existing.get('payload');
      if(!isQrPayload(oldPayload)) throw new HttpsError('failed-precondition','Credential unavailable.');
      oldLookup=db.doc(`studentQrLookups/${hash(oldPayload)}`);
      const lookup=await tx.get(oldLookup);
      if(!lookup.exists||lookup.get('uid')!==uid||lookup.get('status')!==oldStatus) throw new HttpsError('failed-precondition','Credential unavailable.');
      if(oldStatus==='active'&&!evaluateQrEligibility({uid:uid!,profile:ownerData,medical:medicalSnapshot.data(),guardianAuthorization:guardianSnapshot.data(),credential:existing.data(),lookup:lookup.data()})) throw new HttpsError('failed-precondition','Credential unavailable.');
    }
    issuedPayload=`resqme:v1:${randomBytes(32).toString('base64url')}`;
    const nextLookup=db.doc(`studentQrLookups/${hash(issuedPayload)}`);
    const lookupCollision=await tx.get(nextLookup);
    if(lookupCollision.exists) throw new HttpsError('internal','Credential unavailable.');
    const verificationStatus=evaluateQrEligibility({uid:uid!,profile:ownerData,medical:medicalSnapshot.data(),guardianAuthorization:guardianSnapshot.data(),credential:{payload:issuedPayload,verificationStatus:'pending'}})?'active':'pending';
    if(oldLookup) tx.update(oldLookup,{status:'revoked',revokedAt:FieldValue.serverTimestamp()});
    const activation=verificationStatus==='active'?{activatedAt:FieldValue.serverTimestamp()}:{};
    if(existing.exists) tx.update(credential,{payload:issuedPayload,verificationStatus,issuedAt:FieldValue.serverTimestamp(),...activation});
    else tx.create(credential,{payload:issuedPayload,verificationStatus,issuedAt:FieldValue.serverTimestamp(),...activation});
    tx.create(nextLookup,{uid,status:verificationStatus,createdAt:FieldValue.serverTimestamp(),...activation});
  });
  const snapshot=await credential.get();
  return {payload:issuedPayload,verificationStatus:snapshot.get('verificationStatus'),issuedAt:snapshot.get('issuedAt').toDate().toISOString()};
});
