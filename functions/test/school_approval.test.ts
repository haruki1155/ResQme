import assert from 'node:assert/strict';
import test from 'node:test';
import {assertApprovalEligible,assertReviewCandidateEligible,assertRevocationEligible,requireSchoolReviewer,validateSchoolApprovalRequest} from '../src/school/approval_contract';
import {validateReviewCandidateRequest} from '../src/school/get_school_review_candidate';

const reviewer={active:true,schoolId:'synthetic-pilot'};
const student={schemaVersion:1,status:'pending_review',schoolAssignmentStatus:'assigned',schoolId:'synthetic-pilot',schoolApprovalStatus:'pending'};
test('school approval accepts a server-managed reviewer and same-school assigned student independently of medical completion',()=>{
  assert.equal(requireSchoolReviewer(reviewer),'synthetic-pilot');
  assert.equal(assertApprovalEligible({reviewer,student}),'synthetic-pilot');
});

test('school approval rejects inactive or missing reviewers and other-school students',()=>{
  for(const value of [undefined,{active:false,schoolId:'synthetic-pilot'}]) {
    assert.throws(()=>requireSchoolReviewer(value));
  }
  assert.throws(()=>assertApprovalEligible({reviewer,student:{...student,schoolId:'other-school'}}));
  assert.throws(()=>assertApprovalEligible({reviewer:{active:true,schoolId:'other-school'},student}));
  assert.throws(()=>assertApprovalEligible({reviewer,student:{...student,schoolAssignmentStatus:'unassigned'}}));
});
test('school revocation requires the active same-school reviewer and approved enrollment',()=>{
  assert.equal(assertRevocationEligible({reviewer,student:{...student,schoolApprovalStatus:'approved'}}),'synthetic-pilot');
  for(const profile of [{...student,schoolId:'other-school',schoolApprovalStatus:'approved'},{...student,schoolApprovalStatus:'pending'},{...student,schoolAssignmentStatus:'unassigned',schoolApprovalStatus:'approved'}]) {
    assert.throws(()=>assertRevocationEligible({reviewer,student:profile}));
  }
});

test('approval request rejects forged reviewer, school, status, and malformed uid fields',()=>{
  assert.deepEqual(validateSchoolApprovalRequest({studentUid:'synthetic1234',requestId:'request-0001'}),
    {studentUid:'synthetic1234',requestId:'request-0001'});
  for(const value of [
    {studentUid:'short',requestId:'request-0001'},
    {studentUid:'synthetic1234',requestId:'short'},
    {studentUid:'synthetic1234',requestId:'request-0001',schoolId:'forged'},
    {studentUid:'synthetic1234',requestId:'request-0001',reviewerUid:'forged'},
  ]) assert.throws(()=>validateSchoolApprovalRequest(value));
});

test('same-school reviewer sees only assigned pending candidate projection',()=>{
 assert.deepEqual(assertReviewCandidateEligible({reviewer,student:{...student,fullName:'Synthetic Student',schoolVerificationOutcome:'manual_review'},reviewerUid:'reviewer-uid-1',studentUid:'student-uid-1'}),{studentUid:'student-uid-1',fullName:'Synthetic Student',schoolApprovalStatus:'pending',schoolVerificationOutcome:'manual_review'});
 for(const input of [
  {reviewer,student,reviewerUid:'same-uid',studentUid:'same-uid'},
  {reviewer,student:{...student,schoolId:'other-school'},reviewerUid:'reviewer-uid-1',studentUid:'student-uid-1'},
  {reviewer,student:{...student,schoolAssignmentStatus:'unassigned'},reviewerUid:'reviewer-uid-1',studentUid:'student-uid-1'},
 ]) assert.throws(()=>assertReviewCandidateEligible(input));
});

test('candidate lookup accepts only an exact student UID and no authority fields',()=>{
 assert.equal(validateReviewCandidateRequest({studentUid:'student-uid-1'}),'student-uid-1');
 for(const value of [null,{}, {studentUid:'short'}, {studentUid:'student-uid-1',schoolId:'forged'}, {studentUid:'student-uid-1',lrn:'000000000001'}]) assert.throws(()=>validateReviewCandidateRequest(value));
});
