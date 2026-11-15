import assert from 'node:assert/strict';
import test from 'node:test';
import {evaluateQrEligibility} from '../src/qr/qr_eligibility';

const payload=`resqme:v1:${Buffer.alloc(32,7).toString('base64url')}`;
const uid='synthetic-student-uid';
const base={uid,profile:{schemaVersion:1,status:'pending_review',schoolAssignmentStatus:'assigned',schoolId:'synthetic-school',schoolApprovalStatus:'approved',ageYearsAtRegistration:18,medicalStatus:'complete',medicalRevision:1},medical:{schemaVersion:1,medicalStatus:'complete',selfReported:true,syntheticOnly:false,revision:1,conditions:{state:'unknown'},allergies:{state:'none_known'},primaryContact:{fullName:'Synthetic Contact',relationship:'Parent',phoneNumber:'09123456789'}},guardianAuthorization:undefined,credential:{payload,verificationStatus:'pending'}};
test('adult activates only with assigned school, approval, completed authoritative medical record and intact credential',()=>{
 assert.equal(evaluateQrEligibility(base),true);
 for(const changes of [
  {profile:{...base.profile,schoolApprovalStatus:'pending'}},
  {profile:{...base.profile,schoolAssignmentStatus:'unassigned'}},
  {profile:{...base.profile,medicalStatus:'not_started'}},
  {medical:{...base.medical,syntheticOnly:true}},
  {medical:{...base.medical,revision:2}},
  {credential:{...base.credential,verificationStatus:'revoked'}},
  {credential:{...base.credential,payload:'private'}},
  {lookup:{uid:'other',status:'pending'}},
 ]) assert.equal(evaluateQrEligibility({...base,...changes}),false);
});
test('minor remains ineligible without independent guardian verification',()=>{
 const minor={...base,profile:{...base.profile,ageYearsAtRegistration:17}};
 assert.equal(evaluateQrEligibility(minor),false);
 assert.equal(evaluateQrEligibility({...minor,guardianAuthorization:{status:'verified',studentUid:uid,guardianUid:'guardian-uid',verifiedAt:'2026-11-10T00:00:00Z',method:'independent_guardian_verification'}}),true);
});
