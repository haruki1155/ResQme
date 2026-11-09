import {createHash} from 'node:crypto';
import {FieldValue} from 'firebase-admin/firestore';
import {HttpsError,onCall} from 'firebase-functions/v2/https';
import {onboardingDatabase,requirePending,resqmeRuntimeOptions} from '../onboarding/authorization';
import {assertApprovalEligible,validateSchoolApprovalRequest} from './approval_contract';

export const approveStudentQr=onCall(resqmeRuntimeOptions,async request=>{
  const reviewerUid=request.auth?.uid;
  const db=onboardingDatabase(reviewerUid);
  const input=validateSchoolApprovalRequest(request.data);
  if(input.studentUid===reviewerUid) throw new HttpsError('permission-denied','Approval unavailable.');
  const reviewer=db.doc(`schoolReviewers/${reviewerUid}`);
  const profile=db.doc(`studentProfiles/${input.studentUid}`);
  const medical=db.doc(`studentMedicalRecords/${input.studentUid}`);
  const audit=profile.collection('schoolApprovals').doc(input.requestId);
  const digest=createHash('sha256').update(JSON.stringify({studentUid:input.studentUid})).digest('hex');
  return db.runTransaction(async tx=>{
    const [reviewerSnapshot,profileSnapshot,medicalSnapshot,replay]=await Promise.all([
      tx.get(reviewer),tx.get(profile),tx.get(medical),tx.get(audit),
    ]);
    if(!profileSnapshot.exists) throw new HttpsError('not-found','Approval unavailable.');
    const student=requirePending(profileSnapshot.data());
    const schoolId=assertApprovalEligible({
      reviewer:reviewerSnapshot.data(),student,
      medical:medicalSnapshot.data(),
    });
    if(replay.exists){
      if(replay.get('digest')!==digest) throw new HttpsError('already-exists','Request ID already used.');
      return {schoolApprovalStatus:'approved'};
    }
    if(student.schoolApprovalStatus==='approved') throw new HttpsError('already-exists','School approval is already recorded.');
    tx.update(profile,{
      schoolApprovalStatus:'approved',schoolApprovedAt:FieldValue.serverTimestamp(),
      schoolApprovedBy:reviewerUid,updatedAt:FieldValue.serverTimestamp(),
    });
    tx.create(audit,{digest,schoolId,reviewerUid,decision:'approved',recordedAt:FieldValue.serverTimestamp()});
    return {schoolApprovalStatus:'approved'};
  });
});
