import {HttpsError} from 'firebase-functions/v2/https';
export function object(value:unknown):Record<string,unknown> {
  if (!value || typeof value!=='object' || Array.isArray(value)) throw new HttpsError('invalid-argument','Invalid request.');
  return value as Record<string,unknown>;
}
export function keys(data:Record<string,unknown>, allowed:string[]) {
  if(Object.keys(data).some(key=>!allowed.includes(key))) throw new HttpsError('invalid-argument','Unexpected request fields.');
}
export function revisionRequest(value:unknown) {
  const data=object(value);
  if(!Number.isSafeInteger(data.expectedRevision) || (data.expectedRevision as number)<0 || typeof data.requestId!=='string' || !/^[A-Za-z0-9_-]{8,80}$/.test(data.requestId)) throw new HttpsError('invalid-argument','Invalid revision or request ID.');
  return {expectedRevision:data.expectedRevision as number,requestId:data.requestId};
}
function answer(value:unknown) {
  const data=object(value); keys(data,['state','details']);
  if(!['unknown','none_known','listed'].includes(data.state as string)) throw new HttpsError('invalid-argument','Choose an explicit medical status.');
  if(data.details!=null && typeof data.details!=='string') throw new HttpsError('invalid-argument','Invalid details.');
  const details=typeof data.details==='string'?data.details.trim():'';
  if(details.length>2000 || (data.state==='listed' ? !details : !!details)) throw new HttpsError('invalid-argument','Details must match the selected status.');
  return {state:data.state as 'unknown'|'none_known'|'listed',details:details||null};
}
export function contact(value:unknown) {
  const data=object(value); keys(data,['fullName','relationship','phoneNumber']);
  const text=(value:unknown,max:number)=>{if(value==null || value==='') return null; if(typeof value!=='string'||value.trim().length>max) throw new HttpsError('invalid-argument','Invalid contact.');return value.trim()||null;};
  const fullName=text(data.fullName,120),relationship=text(data.relationship,40),phoneNumber=text(data.phoneNumber,32)?.replace(/[ -]/g,'')??null;
  if((fullName&&fullName.length<2)||(phoneNumber&&!/^(09\d{9}|\+639\d{9})$/.test(phoneNumber))) throw new HttpsError('invalid-argument','Invalid contact.');
  return {fullName,relationship,phoneNumber};
}
export function validateMedicalSave(value:unknown) {
  const data=object(value);keys(data,['conditions','allergies','emergencyContact','expectedContact','acknowledgment','expectedRevision','requestId']);
  const acknowledgment=object(data.acknowledgment);keys(acknowledgment,['version','syntheticDataConfirmed','minorNoticeAcknowledged']);
  if(acknowledgment.version!=='synthetic-medical-v1'||acknowledgment.syntheticDataConfirmed!==true || (acknowledgment.minorNoticeAcknowledged!==undefined&&typeof acknowledgment.minorNoticeAcknowledged!=='boolean')) throw new HttpsError('invalid-argument','Confirm the synthetic-data acknowledgment.');
  if((data.emergencyContact===undefined)!==(data.expectedContact===undefined)) throw new HttpsError('invalid-argument','Contact updates require their original values.');
  return {...revisionRequest(data),conditions:answer(data.conditions),allergies:answer(data.allergies),acknowledgment:{version:'synthetic-medical-v1',syntheticDataConfirmed:true,minorNoticeAcknowledged:acknowledgment.minorNoticeAcknowledged===true},
    emergencyContact:data.emergencyContact===undefined?null:contact(data.emergencyContact),expectedContact:data.expectedContact===undefined?null:contact(data.expectedContact)};
}

/** Production completion contract. Synthetic QA records use validateMedicalSave separately. */
export function validateMedicalCompletion(value:unknown) {
  const data=object(value);
  keys(data,['conditions','allergies','primaryContact','selfReportConfirmed','expectedRevision','requestId']);
  if(data.selfReportConfirmed!==true) throw new HttpsError('invalid-argument','Confirm the medical information is self-reported.');
  const conditions=answer(data.conditions),allergies=answer(data.allergies),primaryContact=contact(data.primaryContact);
  if(!primaryContact.fullName||!primaryContact.relationship||!primaryContact.phoneNumber) throw new HttpsError('invalid-argument','Complete the primary emergency contact.');
  return {...revisionRequest(data),conditions,allergies,primaryContact,selfReportConfirmed:true};
}
