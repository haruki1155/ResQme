import assert from 'node:assert/strict';
import test from 'node:test';
import {assertApprovalEligible,assertRevocationEligible,requireSchoolReviewer,validateSchoolApprovalRequest} from '../src/school/approval_contract';

const reviewer={active:true,schoolId:'synthetic-pilot'};
const student={schemaVersion:1,status:'pending_review',schoolAssignmentStatus:'assigned',schoolId:'synthetic-pilot',schoolApprovalStatus:'pending'};
const medical={medicalStatus:'complete',selfReported:true,syntheticOnly:false};

test('school approval accepts only a server-managed reviewer and same-school complete record',()=>{
  assert.equal(requireSchoolReviewer(reviewer),'synthetic-pilot');
  assert.equal(assertApprovalEligible({reviewer,student,medical}),'synthetic-pilot');
});

test('school approval rejects inactive or missing reviewers and other-school students',()=>{
  for(const value of [undefined,{active:false,schoolId:'synthetic-pilot'}]) {
    assert.throws(()=>requireSchoolReviewer(value));
  }
  assert.throws(()=>assertApprovalEligible({reviewer,student:{...student,schoolId:'other-school'},medical}));
  assert.throws(()=>assertApprovalEligible({reviewer:{active:true,schoolId:'other-school'},student,medical}));
  assert.throws(()=>assertApprovalEligible({reviewer,student:{...student,schoolAssignmentStatus:'unassigned'},medical}));
});

test('school approval rejects incomplete or synthetic medical records',()=>{
  for(const value of [undefined,{...medical,medicalStatus:'not_started'},{...medical,syntheticOnly:true},{...medical,selfReported:false}]) {
    assert.throws(()=>assertApprovalEligible({reviewer,student,medical:value}));
  }
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
