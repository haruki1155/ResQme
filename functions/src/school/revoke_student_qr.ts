import {createHash} from 'node:crypto';
import {FieldValue} from 'firebase-admin/firestore';
import {HttpsError,onCall} from 'firebase-functions/v2/https';
import {onboardingDatabase,resqmeRuntimeOptions} from '../onboarding/authorization';
import {validateSchoolApprovalRequest,assertRevocationEligible,requireSchoolReviewer} from './approval_contract';
import {isQrPayload} from '../qr/ensure_my_tier1_qr';

export const revokeStudentQr=onCall(resqmeRuntimeOptions,async request=>{
  const reviewerUid=request.auth?.uid,db=onboardingDatabase(reviewerUid),input=validateSchoolApprovalRequest(request.data);
  if(input.studentUid===reviewerUid) throw new HttpsError('permission-denied','School revocation is unavailable.');
  const reviewer=db.doc(`schoolReviewers/${reviewerUid}`),profile=db.doc(`studentProfiles/${input.studentUid}`),credential=db.doc(`studentQrCredentials/${input.studentUid}`),audit=profile.collection('schoolApprovals').doc(input.requestId);
  const digest=createHash('sha256').update(JSON.stringify({studentUid:input.studentUid,decision:'revoked'})).digest('hex');
  await db.runTransaction(async tx=>{
    const [r,p,c,replay]=await Promise.all([tx.get(reviewer),tx.get(profile),tx.get(credential),tx.get(audit)]);
    if(replay.exists){
      const schoolId=requireSchoolReviewer(r.data()),student=p.data();
      if(replay.get('digest')!==digest) throw new HttpsError('already-exists','Request ID already used.');
      if(!student||student.schoolAssignmentStatus!=='assigned'||student.schoolId!==schoolId||student.schoolApprovalStatus!=='revoked'||student.schoolRevokedBy!==reviewerUid||replay.get('reviewerUid')!==reviewerUid) throw new HttpsError('permission-denied','School revocation is unavailable.');
      return;
    }
    const schoolId=assertRevocationEligible({reviewer:r.data(),student:p.data()});
    if(c.exists&&c.get('verificationStatus')==='active') {
      const payload=c.get('payload');
      if(!isQrPayload(payload)) throw new HttpsError('failed-precondition','Credential unavailable.');
      const lookup=db.doc(`studentQrLookups/${createHash('sha256').update(payload).digest('hex')}`),snapshot=await tx.get(lookup);
      if(!snapshot.exists||snapshot.get('uid')!==input.studentUid||snapshot.get('status')!=='active') throw new HttpsError('failed-precondition','Credential unavailable.');
      tx.update(lookup,{status:'revoked',revokedAt:FieldValue.serverTimestamp()});
    }
    tx.update(profile,{schoolApprovalStatus:'revoked',schoolRevokedAt:FieldValue.serverTimestamp(),schoolRevokedBy:reviewerUid,updatedAt:FieldValue.serverTimestamp()});
    if(c.exists) tx.update(credential,{verificationStatus:'revoked',revokedAt:FieldValue.serverTimestamp()});
    tx.create(audit,{digest,schoolId,reviewerUid,decision:'revoked',recordedAt:FieldValue.serverTimestamp()});
  });
  return {schoolApprovalStatus:'revoked'};
});
