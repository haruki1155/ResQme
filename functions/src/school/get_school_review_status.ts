import {createHash} from 'node:crypto';
import {HttpsError,onCall} from 'firebase-functions/v2/https';
import {onboardingDatabase,resqmeRuntimeOptions} from '../onboarding/authorization';
import {requireSchoolReviewer} from './approval_contract';
import {validateReviewCandidateRequest} from './get_school_review_candidate';
import {evaluateQrEligibility} from '../qr/qr_eligibility';
import {isQrPayload} from '../qr/ensure_my_tier1_qr';

/** Coherent read-only snapshot; no student identity, medical or guardian fields leave this callable. */
export const getSchoolReviewStatus=onCall(resqmeRuntimeOptions,async request=>{
 const reviewerUid=request.auth?.uid,db=onboardingDatabase(reviewerUid);
 const uid=validateReviewCandidateRequest(request.data);
 if(uid===reviewerUid) throw new HttpsError('permission-denied','Review unavailable.');
 return db.runTransaction(async tx=>{
  const reviewer=await tx.get(db.doc(`schoolReviewers/${reviewerUid}`));
  const schoolId=requireSchoolReviewer(reviewer.data());
  const profile=await tx.get(db.doc(`studentProfiles/${uid}`));
  const data=profile.data();
  if(!data||data.schemaVersion!==1||data.schoolAssignmentStatus!=='assigned'||data.schoolId!==schoolId||
    !['pending_review','pending_guardian'].includes(data.status)||!['pending','approved','rejected','revoked'].includes(data.schoolApprovalStatus)) {
   throw new HttpsError('not-found','Review unavailable.');
  }
  const credential=await tx.get(db.doc(`studentQrCredentials/${uid}`));
  let qrActive=false;
  const payload=credential.get('payload');
  if(credential.get('verificationStatus')==='active'&&isQrPayload(payload)) {
   const [lookup,medical,guardian]=await Promise.all([
    tx.get(db.doc(`studentQrLookups/${createHash('sha256').update(payload).digest('hex')}`)),
    tx.get(db.doc(`studentMedicalRecords/${uid}`)),tx.get(db.doc(`studentGuardianAuthorizations/${uid}`)),
   ]);
   qrActive=lookup.exists&&lookup.get('status')==='active'&&evaluateQrEligibility({uid,profile:data,
    credential:credential.data(),lookup:lookup.data(),medical:medical.data(),guardianAuthorization:guardian.data()});
  }
  return {schoolStatus:data.schoolApprovalStatus,qrActive};
 });
});
