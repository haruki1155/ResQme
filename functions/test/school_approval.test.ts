import assert from 'node:assert/strict';
import test from 'node:test';
import {assertApprovalEligible,assertReviewCandidateEligible,assertRevocationEligible,requireSchoolReviewer,validateSchoolApprovalRequest} from '../src/school/approval_contract';
import {validateReviewCandidateRequest} from '../src/school/get_school_review_candidate';
import {getSchoolReviewCandidate} from '../src/school/get_school_review_candidate';
import {approveStudentQr} from '../src/school/approve_student_qr';
import type {CallableRequest} from 'firebase-functions/v2/https';
const authorization=require('../src/onboarding/authorization') as typeof import('../src/onboarding/authorization');

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

for(const scenario of ['missing-reviewer','inactive-reviewer','other-school','self-approval']) {
 test(`approval handler denies ${scenario} without writes`,async t=>{
  const owner='reviewer-uid-1',target=scenario==='self-approval'?owner:'student-uid-1';
  let writes=0;
  const reviewerRecord=scenario==='missing-reviewer'?undefined:{active:scenario!=='inactive-reviewer',schoolId:scenario==='other-school'?'other-school':'synthetic-pilot'};
  const db={
   doc:(path:string)=>({path,collection:(name:string)=>({doc:(id:string)=>({path:`${path}/${name}/${id}`})})}),
   runTransaction:async(action:(tx:unknown)=>Promise<unknown>)=>action({
    get:async(ref:{path:string})=>{
     const value=ref.path.startsWith('schoolReviewers/')?reviewerRecord:ref.path===`studentProfiles/${target}`?{...student,ageYearsAtRegistration:25}:undefined;
     return {exists:!!value,data:()=>value};
    },
    update:()=>{writes++;},create:()=>{writes++;},
   }),
  };
  t.mock.method(authorization,'onboardingDatabase',()=>db as never);
  await assert.rejects(()=>approveStudentQr.run({auth:{uid:owner},data:{studentUid:target,requestId:'request-0001'}} as CallableRequest),{code:'permission-denied'});
  assert.equal(writes,0);
 });
}

test('unprovisioned reviewer cannot read the student profile through lookup',async t=>{
 const reads:string[]=[];
 const db={doc:(path:string)=>({get:async()=>{reads.push(path);return {data:()=>undefined};}})};
 t.mock.method(authorization,'onboardingDatabase',()=>db as never);
 await assert.rejects(()=>getSchoolReviewCandidate.run({auth:{uid:'reviewer-uid-1'},data:{studentUid:'student-uid-1'}} as CallableRequest),{code:'permission-denied'});
 assert.deepEqual(reads,['schoolReviewers/reviewer-uid-1']);
});

test('anonymous callers cannot use reviewer lookup or approval',async()=>{
 for(const callable of [getSchoolReviewCandidate,approveStudentQr]) {
  await assert.rejects(()=>callable.run({data:{studentUid:'student-uid-1',requestId:'request-0001'}} as CallableRequest),{code:'unauthenticated'});
 }
});

test('reviewer QR lookup rejects anonymous, inactive, wrong-school, revoked and unrelated credentials',async()=>{
  const {assertReviewerQrEligible}=await import('../src/school/reviewer_qr_contract.js');
  const payload=`resqme:v1:${Buffer.alloc(32,9).toString('base64url')}`;
  const base={reviewer:{active:true,schoolId:'synthetic-pilot'},reviewerUid:'reviewer-one',studentUid:'student-one',
    student:{schemaVersion:1,schoolAssignmentStatus:'assigned',schoolId:'synthetic-pilot',schoolApprovalStatus:'pending',status:'pending_review',fullName:'Fictional Student'},
    credential:{payload,verificationStatus:'pending'},lookup:{uid:'student-one',status:'pending'}};
  assert.deepEqual(assertReviewerQrEligible(base),{studentUid:'student-one',fullName:'Fictional Student',schoolApprovalStatus:'pending',schoolVerificationOutcome:'manual_review'});
  for(const input of [
    {...base,reviewer:undefined}, {...base,reviewer:{...base.reviewer,active:false}},
    {...base,reviewer:{...base.reviewer,schoolId:'other-school'}}, {...base,reviewerUid:'student-one'},
    {...base,credential:{...base.credential,verificationStatus:'revoked'}},
    {...base,lookup:{...base.lookup,status:'revoked'}}, {...base,student:{...base.student,schoolApprovalStatus:'approved'}},
  ]) assert.throws(()=>assertReviewerQrEligible(input));
});

// Serial commit model exercises the callable's re-read/replay decisions. Firestore
// itself supplies conflict retries; this is not an emulator concurrency proof.
test('competing reviewers yield one transition; replay is bound to its original reviewer', async t => {
 const target='student-transaction';
 let profile:Record<string,unknown>={...student,ageYearsAtRegistration:25};
 const audits=new Map<string,Record<string,unknown>>(); let transitions=0; let queue=Promise.resolve();
 const db={doc:(path:string)=>({path,collection:(name:string)=>({doc:(id:string)=>({path:`${path}/${name}/${id}`})})}),
 runTransaction:(action:(tx:unknown)=>Promise<unknown>)=>{
  const operation=queue.then(()=>action({get:async(ref:{path:string})=>{
   const value=ref.path.startsWith('schoolReviewers/')?reviewer:ref.path===`studentProfiles/${target}`?profile:audits.get(ref.path);
   return {exists:!!value,data:()=>value,get:(key:string)=>(value as Record<string,unknown> | undefined)?.[key]};
  },update:(_ref:unknown,value:Record<string,unknown>)=>{profile={...profile,...value};transitions++;},
  create:(ref:{path:string},value:Record<string,unknown>)=>{assert.equal(audits.has(ref.path),false);audits.set(ref.path,value);}}));
  queue=operation.then(()=>undefined,()=>undefined); return operation;
 }};
 t.mock.method(authorization,'onboardingDatabase',()=>db as never);
 const call=(uid:string,requestId:string)=>approveStudentQr.run({auth:{uid},data:{studentUid:target,requestId}} as CallableRequest);
 const outcomes=await Promise.allSettled([call('reviewer-one','request-one'),call('reviewer-two','request-two')]);
 assert.equal(outcomes.filter(x=>x.status==='fulfilled').length,1);
 assert.equal(transitions,1); assert.equal(audits.size,1);
 await call('reviewer-one','request-one'); assert.equal(transitions,1);
 await assert.rejects(()=>call('reviewer-two','request-one'));
 await assert.rejects(()=>call('reviewer-one','request-new'));
 for(const status of ['revoked','rejected','invalid']) {
  profile={...profile,schoolApprovalStatus:status};
  await assert.rejects(()=>call('reviewer-one','request-one'));
  await assert.rejects(()=>call('reviewer-one','request-new'));
 }
 assert.equal(transitions,1); assert.equal(audits.size,1);
});


test('status refresh authorizes reviewer and reports school approval independently of pending QR', async t=>{
 const {getSchoolReviewStatus}=await import('../src/school/get_school_review_status.js');
 let reviewerData:Record<string,unknown>|undefined=reviewer;
 const reads:string[]=[];
 const db={doc:(path:string)=>({path}),runTransaction:async(fn:(tx:unknown)=>Promise<unknown>)=>fn({get:async(ref:{path:string})=>{
  reads.push(ref.path);
  const value=ref.path.startsWith('schoolReviewers/')?reviewerData:ref.path.startsWith('studentProfiles/')?{...student,schoolApprovalStatus:'approved'}:{verificationStatus:'pending'};
  return {exists:!!value,data:()=>value,get:(key:string)=>(value as Record<string,unknown>|undefined)?.[key]};
 }})};
 t.mock.method(authorization,'onboardingDatabase',()=>db as never);
 const request={auth:{uid:'reviewer-one'},data:{studentUid:'student-one'}} as CallableRequest;
 assert.deepEqual(await getSchoolReviewStatus.run(request),{schoolStatus:'approved',qrActive:false});
 for(const invalid of [undefined,{active:false,schoolId:'synthetic-pilot'},{active:true,schoolId:'other-school'}]) {
  reviewerData=invalid;
  await assert.rejects(()=>getSchoolReviewStatus.run(request));
 }
 assert.equal(reads.some(path=>path.startsWith('studentMedicalRecords/')),false);
 await assert.rejects(()=>getSchoolReviewStatus.run({...request,auth:{uid:'student-one'}} as CallableRequest));
});
