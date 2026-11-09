import {randomBytes,createHash} from 'node:crypto';
import {FieldValue} from 'firebase-admin/firestore';
import {HttpsError,onCall} from 'firebase-functions/v2/https';
import {onboardingDatabase,requireQrEligible,resqmeRuntimeOptions} from '../onboarding/authorization';
import {keys,object} from '../medical/medical_contract';
import {isQrPayload} from './ensure_my_tier1_qr';

function hash(payload:string){return createHash('sha256').update(payload,'utf8').digest('hex');}
export function validateReplaceQrRequest(value:unknown){keys(object(value),[]);}
export const replaceMyTier1Qr=onCall(resqmeRuntimeOptions,async request=>{
  const uid=request.auth?.uid,db=onboardingDatabase(uid);
  validateReplaceQrRequest(request.data);
  const profile=db.doc(`studentProfiles/${uid}`),credential=db.doc(`studentQrCredentials/${uid}`);
  let issuedPayload='';
  await db.runTransaction(async tx=>{
    const [owner,existing]=await Promise.all([tx.get(profile),tx.get(credential)]);
    requireQrEligible(owner.data());
    let oldLookup:FirebaseFirestore.DocumentReference|undefined;
    if(existing.exists&&existing.get('verificationStatus')==='active') {
      const oldPayload=existing.get('payload');
      if(!isQrPayload(oldPayload)) throw new HttpsError('failed-precondition','Credential unavailable.');
      oldLookup=db.doc(`studentQrLookups/${hash(oldPayload)}`);
      const lookup=await tx.get(oldLookup);
      if(!lookup.exists||lookup.get('uid')!==uid||lookup.get('status')!=='active') throw new HttpsError('failed-precondition','Credential unavailable.');
    }
    issuedPayload=`resqme:v1:${randomBytes(32).toString('base64url')}`;
    const nextLookup=db.doc(`studentQrLookups/${hash(issuedPayload)}`);
    const lookupCollision=await tx.get(nextLookup);
    if(lookupCollision.exists) throw new HttpsError('internal','Credential unavailable.');
    if(oldLookup) tx.update(oldLookup,{status:'revoked',revokedAt:FieldValue.serverTimestamp()});
    if(existing.exists) tx.update(credential,{payload:issuedPayload,verificationStatus:'active',issuedAt:FieldValue.serverTimestamp(),activatedAt:FieldValue.serverTimestamp()});
    else tx.create(credential,{payload:issuedPayload,verificationStatus:'active',issuedAt:FieldValue.serverTimestamp(),activatedAt:FieldValue.serverTimestamp()});
    tx.create(nextLookup,{uid,status:'active',createdAt:FieldValue.serverTimestamp()});
  });
  const snapshot=await credential.get();
  return {payload:issuedPayload,verificationStatus:'active',issuedAt:snapshot.get('issuedAt').toDate().toISOString()};
});
