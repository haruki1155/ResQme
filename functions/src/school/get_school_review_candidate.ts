import {HttpsError,onCall} from 'firebase-functions/v2/https';
import {onboardingDatabase,resqmeRuntimeOptions} from '../onboarding/authorization';
import {assertReviewCandidateEligible,requireSchoolReviewer} from './approval_contract';
import {keys,object} from '../medical/medical_contract';

export function validateReviewCandidateRequest(value:unknown):string {
 const input=object(value);keys(input,['studentUid']);
 if(typeof input.studentUid!=='string'||!/^[-A-Za-z0-9]{8,128}$/.test(input.studentUid)) throw new HttpsError('invalid-argument','Invalid review request.');
 return input.studentUid;
}

export const getSchoolReviewCandidate=onCall(resqmeRuntimeOptions,async request=>{
 const reviewerUid=request.auth?.uid,db=onboardingDatabase(reviewerUid),studentUid=validateReviewCandidateRequest(request.data);
 const reviewer=await db.doc(`schoolReviewers/${reviewerUid}`).get();
 const reviewerData=reviewer.data();
 requireSchoolReviewer(reviewerData);
 const student=await db.doc(`studentProfiles/${studentUid}`).get();
 return assertReviewCandidateEligible({reviewer:reviewerData,student:student.data(),reviewerUid:reviewerUid!,studentUid});
});
