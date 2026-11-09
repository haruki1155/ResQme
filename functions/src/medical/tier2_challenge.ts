import {createPublicKey,verify} from 'node:crypto';
import {HttpsError} from 'firebase-functions/v2/https';
import {keys,object} from './medical_contract';

export const tier2Operation='read_medical' as const;
export function requireRecentAuth(authTime:unknown,nowSeconds=Math.floor(Date.now()/1000),maxAge=300) {
  if(!Number.isSafeInteger(authTime)||(authTime as number)>nowSeconds+5||nowSeconds-(authTime as number)>maxAge) {
    throw new HttpsError('failed-precondition','Please reauthenticate to access Tier 2.');
  }
}
export function validateDeviceEnrollment(value:unknown) {
  const data=object(value);keys(data,['deviceId','publicKey']);
  if(typeof data.deviceId!=='string'||!/^[A-Za-z0-9_-]{20,80}$/.test(data.deviceId)||typeof data.publicKey!=='string'||data.publicKey.length>1024) throw new HttpsError('invalid-argument','Invalid device enrollment.');
  try {
    const der=Buffer.from(data.publicKey,'base64url');
    const key=createPublicKey({key:der,format:'der',type:'spki'});
    if(key.asymmetricKeyType!=='ec'||key.asymmetricKeyDetails?.namedCurve!=='prime256v1') throw new Error('key');
  } catch {throw new HttpsError('invalid-argument','Invalid device enrollment.');}
  return {deviceId:data.deviceId,publicKey:data.publicKey};
}
export function validateChallengeRequest(value:unknown) {
  const data=object(value);keys(data,['deviceId','operation']);
  if(typeof data.deviceId!=='string'||!/^[A-Za-z0-9_-]{20,80}$/.test(data.deviceId)||data.operation!==tier2Operation) throw new HttpsError('invalid-argument','Invalid Tier 2 request.');
  return {deviceId:data.deviceId,operation:tier2Operation};
}
export function validateProof(value:unknown) {
  const data=object(value);keys(data,['challengeId','deviceId','signature']);
  if(typeof data.challengeId!=='string'||!/^[A-Fa-f0-9]{32,64}$/.test(data.challengeId)||typeof data.deviceId!=='string'||!/^[A-Za-z0-9_-]{20,80}$/.test(data.deviceId)||typeof data.signature!=='string'||!/^[A-Za-z0-9_-]{80,160}$/.test(data.signature)) throw new HttpsError('invalid-argument','Invalid Tier 2 proof.');
  return {challengeId:data.challengeId,deviceId:data.deviceId,signature:data.signature};
}
export function tier2SignedMessage(input:{uid:string;deviceId:string;operation:string;challengeId:string;nonce:string}) {
  return `${input.uid}\n${input.deviceId}\n${input.operation}\n${input.challengeId}\n${input.nonce}`;
}
export function verifyTier2Signature(publicKey:string,message:string,signature:string):boolean {
  try {
    const key=createPublicKey({key:Buffer.from(publicKey,'base64url'),format:'der',type:'spki'});
    return verify('sha256',Buffer.from(message,'utf8'),key,Buffer.from(signature,'base64url'));
  } catch {return false;}
}
export function requireTier2Eligible(profile:FirebaseFirestore.DocumentData|undefined,medical:FirebaseFirestore.DocumentData|undefined) {
  if(!profile||profile.schemaVersion!==1||profile.schoolApprovalStatus!=='approved'||profile.medicalStatus!=='complete'||
      !medical||medical.medicalStatus!=='complete'||medical.selfReported!==true||medical.syntheticOnly===true) {
    throw new HttpsError('permission-denied','Tier 2 access is unavailable.');
  }
}
export function sanitizeTier2Record(medical:FirebaseFirestore.DocumentData|undefined) {
  const invalid=()=>new HttpsError('failed-precondition','Tier 2 information is unavailable.');
  if(!medical) throw invalid();
  const answer=(value:unknown)=>{
    if(!value||typeof value!=='object'||Array.isArray(value)) throw invalid();
    const data=value as Record<string,unknown>;
    if(Object.keys(data).some(key=>!['state','details'].includes(key))||!['unknown','none_known','listed'].includes(data.state as string)) throw invalid();
    const details=data.details;
    if(details!==null&&typeof details!=='string') throw invalid();
    if(data.state==='listed'&&(!details||!details.trim())) throw invalid();
    if(data.state!=='listed'&&details!==null) throw invalid();
    return {state:data.state,details};
  };
  const raw=medical.primaryContact;
  if(!raw||typeof raw!=='object'||Array.isArray(raw)) throw invalid();
  const contact=raw as Record<string,unknown>;
  for(const field of ['fullName','relationship','phoneNumber']) if(typeof contact[field]!=='string'||!(contact[field] as string).trim()) throw invalid();
  if(Object.keys(contact).some(key=>!['fullName','relationship','phoneNumber'].includes(key))) throw invalid();
  return {
    conditions:answer(medical.conditions),
    allergies:answer(medical.allergies),
    primaryContact:{fullName:contact.fullName,relationship:contact.relationship,phoneNumber:contact.phoneNumber},
  };
}
