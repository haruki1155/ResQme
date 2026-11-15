import {HttpsError} from 'firebase-functions/v2/https';
import {keys,object} from '../medical/medical_contract';

export function validateSchoolApprovalRequest(value:unknown) {
  const data=object(value);keys(data,['studentUid','requestId']);
  if(typeof data.studentUid!=='string'||!/^[-A-Za-z0-9]{8,128}$/.test(data.studentUid)) throw new HttpsError('invalid-argument','Invalid approval request.');
  if(typeof data.requestId!=='string'||!/^[A-Za-z0-9_-]{8,80}$/.test(data.requestId)) throw new HttpsError('invalid-argument','Invalid approval request.');
  return {studentUid:data.studentUid,requestId:data.requestId};
}

export function requireSchoolReviewer(value:Record<string,unknown>|undefined) {
  if(!value||value.active!==true||typeof value.schoolId!=='string'||!/^[a-z0-9][a-z0-9_-]{1,63}$/.test(value.schoolId)) {
    throw new HttpsError('permission-denied','School approval is unavailable.');
  }
  return value.schoolId;
}

export function assertApprovalEligible(input:{
  reviewer:Record<string,unknown>|undefined;
  student:Record<string,unknown>|undefined;
}) {
  const schoolId=requireSchoolReviewer(input.reviewer);
  if(!input.student) throw new HttpsError('not-found','Approval unavailable.');
  if(input.student.schemaVersion!==1||!['pending_review','pending_guardian'].includes(input.student.status as string)||input.student.schoolAssignmentStatus!=='assigned'||input.student.schoolId!==schoolId||input.student.schoolApprovalStatus==='revoked') {
    throw new HttpsError('permission-denied','Approval unavailable.');
  }
  return schoolId;
}

export function assertReviewCandidateEligible(input:{reviewer:Record<string,unknown>|undefined;student:Record<string,unknown>|undefined;reviewerUid:string;studentUid:string}) {
  const schoolId=requireSchoolReviewer(input.reviewer),student=input.student;
  if(input.reviewerUid===input.studentUid||!student||student.schemaVersion!==1||
    student.schoolAssignmentStatus!=='assigned'||student.schoolId!==schoolId||
    student.schoolApprovalStatus!=='pending'||typeof student.fullName!=='string'||student.fullName.trim().length<2) {
    throw new HttpsError('not-found','Candidate unavailable.');
  }
  return {
    studentUid:input.studentUid,
    fullName:student.fullName,
    schoolApprovalStatus:'pending' as const,
    schoolVerificationOutcome:['verified','manual_review','conflict'].includes(student.schoolVerificationOutcome as string)?student.schoolVerificationOutcome as string:'manual_review',
  };
}

export function assertRevocationEligible(input:{
  reviewer:Record<string,unknown>|undefined;
  student:Record<string,unknown>|undefined;
}) {
  const schoolId=requireSchoolReviewer(input.reviewer),student=input.student;
  if(!student||student.schemaVersion!==1||student.schoolAssignmentStatus!=='assigned'||student.schoolId!==schoolId||student.schoolApprovalStatus!=='approved') {
    throw new HttpsError('permission-denied','School revocation is unavailable.');
  }
  return schoolId;
}
