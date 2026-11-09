import {createHash} from 'node:crypto';
import {getApps,initializeApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import {HttpsError,onCall} from 'firebase-functions/v2/https';
import {isQrPayload} from './ensure_my_tier1_qr';
import {resqmeRuntimeOptions} from '../onboarding/authorization';
import {keys,object} from '../medical/medical_contract';

export function validateResolveQrRequest(value:unknown):string {
  const input=object(value);
  keys(input,['payload']);
  if(!isQrPayload(input.payload)) throw new HttpsError('invalid-argument','Invalid QR.');
  return input.payload;
}
export function isCanonicalQrPayload(value:unknown):boolean{return isQrPayload(value);}
export function hashQrPayload(payload:string):string{return createHash('sha256').update(payload,'utf8').digest('hex');}

const rateBuckets=new Map<string,{startedAt:number;count:number}>();
export function allowTier1Resolution(ip:unknown,now=Date.now()):boolean {
  if(typeof ip!=='string'||ip.length<3||ip.length>128) return false;
  for(const [key,bucket] of rateBuckets) if(now-bucket.startedAt>=60_000) rateBuckets.delete(key);
  if(rateBuckets.size>1000) rateBuckets.clear();
  const bucket=rateBuckets.get(ip);
  if(!bucket||now-bucket.startedAt>=60_000){rateBuckets.set(ip,{startedAt:now,count:1});return true;}
  if(bucket.count>=30) return false;
  bucket.count++;
  return true;
}

export const resolveTier1Qr=onCall({...resqmeRuntimeOptions,maxInstances:4},async request=>{
  if(!allowTier1Resolution(request.rawRequest.ip)) return {active:false};
  let payload:string;
  try{payload=validateResolveQrRequest(request.data);}catch{return {active:false};}
  const project=process.env.GCLOUD_PROJECT||process.env.GOOGLE_CLOUD_PROJECT;
  if(!['demo-resqme','resqme-943ee'].includes(project??'')) return {active:false};
  if(!getApps().some(app=>app.name==='[DEFAULT]')) initializeApp();
  const db=getFirestore();
  const lookup=await db.doc(`studentQrLookups/${hashQrPayload(payload)}`).get();
  if(!lookup.exists||lookup.get('status')!=='active'||typeof lookup.get('uid')!=='string') return {active:false};
  const uid=lookup.get('uid') as string;
  const [profile,credential,medical]=await Promise.all([
    db.doc(`studentProfiles/${uid}`).get(),
    db.doc(`studentQrCredentials/${uid}`).get(),
    db.doc(`studentMedicalRecords/${uid}`).get(),
  ]);
  const eligible=profile.exists&&profile.get('schemaVersion')===1&&profile.get('schoolApprovalStatus')==='approved'&&profile.get('medicalStatus')==='complete'&&
    medical.exists&&medical.get('medicalStatus')==='complete'&&medical.get('selfReported')===true&&
    credential.exists&&credential.get('verificationStatus')==='active'&&credential.get('payload')===payload;
  return {active:eligible};
});
