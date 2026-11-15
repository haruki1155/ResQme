import {validateMedicalCompletion} from '../medical/medical_contract';
type Data=Record<string,unknown>|undefined;
function canonicalPayload(value:unknown):value is string {
 if(typeof value!=='string'||!/^resqme:v1:[A-Za-z0-9_-]{43}$/.test(value)) return false;
 const encoded=value.slice('resqme:v1:'.length);
 try{return Buffer.from(encoded,'base64url').length===32&&Buffer.from(encoded,'base64url').toString('base64url')===encoded;}catch{return false;}
}

export function evaluateQrEligibility(input:{
 uid:string;
 profile:Data;
 medical:Data;
 guardianAuthorization:Data;
 credential:Data;
 lookup?:Data;
}):boolean {
 const {uid,profile,medical,guardianAuthorization,credential,lookup}=input;
 if(!profile||profile.schemaVersion!==1||!['pending_review','pending_guardian'].includes(profile.status as string)||
   profile.schoolAssignmentStatus!=='assigned'||typeof profile.schoolId!=='string'||!/^[a-z0-9][a-z0-9_-]{1,63}$/.test(profile.schoolId)||
   profile.schoolApprovalStatus!=='approved'||!Number.isInteger(profile.ageYearsAtRegistration)||
   Number(profile.ageYearsAtRegistration)<0||Number(profile.ageYearsAtRegistration)>130||
   profile.medicalStatus!=='complete'||!Number.isSafeInteger(profile.medicalRevision)||Number(profile.medicalRevision)<1||
   !medical||medical.schemaVersion!==1||medical.medicalStatus!=='complete'||medical.selfReported!==true||medical.syntheticOnly===true||
   medical.revision!==profile.medicalRevision||!credential||!['pending','active'].includes(credential.verificationStatus as string)||
   !canonicalPayload(credential.payload)) return false;
 try{validateMedicalCompletion({conditions:medical.conditions,allergies:medical.allergies,primaryContact:medical.primaryContact,selfReportConfirmed:true,expectedRevision:medical.revision,requestId:'eligibility-check'});}catch{return false;}
 const verifiedAt=guardianAuthorization?.verifiedAt;
 const hasVerifiedAt=verifiedAt instanceof Date||(verifiedAt!==null&&typeof verifiedAt==='object'&&typeof (verifiedAt as {toDate?:unknown}).toDate==='function')||(typeof verifiedAt==='string'&&Number.isFinite(Date.parse(verifiedAt)));
 if(Number(profile.ageYearsAtRegistration)<18&&(!guardianAuthorization||guardianAuthorization.status!=='verified'||
   guardianAuthorization.studentUid!==uid||typeof guardianAuthorization.guardianUid!=='string'||guardianAuthorization.guardianUid===uid||
   !hasVerifiedAt||guardianAuthorization.method!=='independent_guardian_verification')) return false;
 if(lookup&& (lookup.uid!==uid||lookup.status!==credential.verificationStatus)) return false;
 return true;
}
