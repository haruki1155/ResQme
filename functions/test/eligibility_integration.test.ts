import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import test from 'node:test';
import {initializeApp,deleteApp} from 'firebase/app';
import {connectAuthEmulator,getAuth,signInWithEmailAndPassword} from 'firebase/auth';
import {connectFunctionsEmulator,getFunctions,httpsCallable} from 'firebase/functions';
import {initializeApp as initializeAdmin,deleteApp as deleteAdmin} from 'firebase-admin/app';
import {getAuth as adminAuth} from 'firebase-admin/auth';
import {getFirestore} from 'firebase-admin/firestore';
import {emulatorConfig,projectId} from './emulator_config';

const endpoints=emulatorConfig(process.env);
const admin=initializeAdmin({projectId},'eligibility-integration');
const store=getFirestore(admin);
const people=[
  {uid:'qa-eligibility-student',email:'eligibility-student@example.test'},
  {uid:'qa-eligibility-reviewer',email:'eligibility-reviewer@example.test'},
];
const apps=people.map(({email},index)=>{
  const app=initializeApp({projectId,apiKey:'test'},`eligibility-${index}`);
  const auth=getAuth(app);
  connectAuthEmulator(auth,`http://${endpoints.auth.host}:${endpoints.auth.port}`,{disableWarnings:true});
  const functions=getFunctions(app,'us-central1');
  connectFunctionsEmulator(functions,endpoints.functions.host,endpoints.functions.port);
  return {app,auth,call:(name:string,data:unknown)=>httpsCallable(functions,name,{timeout:10000})(data)};
});
const [student,reviewer]=apps;
const qrPayloads:string[]=[];
const legacyPayload=`resqme:v1:${Buffer.alloc(32,5).toString('base64url')}`;

async function deleteOwnedTree(ref:FirebaseFirestore.DocumentReference) {
  for(const collection of await ref.listCollections()) for(const child of (await collection.get()).docs) await deleteOwnedTree(child.ref);
  await ref.delete();
}

test.before(async()=>{
  for(const person of people) await adminAuth(admin).createUser({...person,password:'Synthetic-Local-123'});
  for(let index=0;index<apps.length;index++) await signInWithEmailAndPassword(apps[index].auth,people[index].email,'Synthetic-Local-123');
  await student.call('createStudentRegistration',{fullName:'Fictional Student',ageYears:16,noticeVersion:'tier1-registration-v1',acknowledgmentAccepted:true});
  await store.doc(`studentProfiles/${people[0].uid}`).update({schoolId:'synthetic-pilot',schoolAssignmentStatus:'assigned'});
  await store.doc(`studentQrCredentials/${people[0].uid}`).set({payload:legacyPayload,verificationStatus:'unverified'});
  qrPayloads.push(legacyPayload);
  await store.doc(`schoolReviewers/${people[1].uid}`).set({active:true,schoolId:'synthetic-pilot'});
});
test.after(async()=>{
  for(const person of people){
    const profile=store.doc(`studentProfiles/${person.uid}`);
    await deleteOwnedTree(profile);
    const record=store.doc(`studentMedicalRecords/${person.uid}`);
    await deleteOwnedTree(record);
    const credential=store.doc(`studentQrCredentials/${person.uid}`),credentialData=(await credential.get()).data();
    if(typeof credentialData?.payload==='string') qrPayloads.push(credentialData.payload);
    for(const payload of qrPayloads) await store.doc(`studentQrLookups/${createHash('sha256').update(payload).digest('hex')}`).delete();
    await credential.delete();
    await store.doc(`schoolReviewers/${person.uid}`).delete();
    try{await adminAuth(admin).deleteUser(person.uid);}catch(error){if((error as {code?:string}).code!=='auth/user-not-found')throw error;}
  }
  for(const value of apps) await deleteApp(value.app);
  await deleteAdmin(admin);
});

test('school approval is server-scoped and requires a complete owner medical record',{timeout:30000},async()=>{
  await assert.rejects(()=>reviewer.call('approveStudentQr',{studentUid:people[0].uid,requestId:'approval-0001'}),{code:'functions/failed-precondition'});
  await assert.rejects(()=>student.call('ensureMyTier1Qr',{}),{code:'functions/failed-precondition'});
  await assert.rejects(()=>student.call('completeMyMedicalRecord',{}),{code:'functions/invalid-argument'});
  const medical={
    conditions:{state:'unknown'},allergies:{state:'none_known'},selfReportConfirmed:true,
    primaryContact:{fullName:'Fictional Contact',relationship:'Parent',phoneNumber:'09123456789'},
    expectedRevision:0,requestId:'medical-complete-0001',
  };
  const saved=await student.call('completeMyMedicalRecord',medical);
  assert.deepEqual(saved.data,{medicalStatus:'complete',revision:1});
  assert.deepEqual((await student.call('completeMyMedicalRecord',medical)).data,saved.data);
  await assert.rejects(()=>student.call('approveStudentQr',{studentUid:people[0].uid,requestId:'approval-self-0001'}),{code:'functions/permission-denied'});
  const reviewerRef=store.doc(`schoolReviewers/${people[1].uid}`);
  await reviewerRef.update({schoolId:'another-school'});
  await assert.rejects(()=>reviewer.call('approveStudentQr',{studentUid:people[0].uid,requestId:'approval-wrong-0001'}),{code:'functions/permission-denied'});
  await reviewerRef.update({schoolId:'synthetic-pilot'});
  const approved=await reviewer.call('approveStudentQr',{studentUid:people[0].uid,requestId:'approval-0001'});
  assert.deepEqual(approved.data,{schoolApprovalStatus:'approved'});
  assert.equal((await store.doc(`studentProfiles/${people[0].uid}`).get()).get('schoolApprovalStatus'),'approved');
  assert.equal((await store.doc(`studentProfiles/${people[0].uid}/schoolApprovals/approval-0001`).get()).get('reviewerUid'),people[1].uid);
  await assert.rejects(()=>student.call('ensureMyTier1Qr',{}),{code:'functions/failed-precondition'});
  const issued=(await student.call('replaceMyTier1Qr',{})).data as {payload:string;verificationStatus:string};
  qrPayloads.push(issued.payload);
  assert.equal(issued.verificationStatus,'active');
  assert.deepEqual((await reviewer.call('resolveTier1Qr',{payload:issued.payload})).data,{active:true});
  assert.deepEqual((await reviewer.call('resolveTier1Qr',{payload:'malformed'})).data,{active:false});
  const replacement=(await student.call('replaceMyTier1Qr',{})).data as {payload:string;verificationStatus:string};
  qrPayloads.push(replacement.payload);
  assert.notEqual(replacement.payload,issued.payload);
  assert.deepEqual((await reviewer.call('resolveTier1Qr',{payload:issued.payload})).data,{active:false});
  assert.deepEqual((await reviewer.call('resolveTier1Qr',{payload:replacement.payload})).data,{active:true});
  const revoked=await reviewer.call('revokeStudentQr',{studentUid:people[0].uid,requestId:'revoke-0001'});
  assert.deepEqual(revoked.data,{schoolApprovalStatus:'revoked'});
  assert.deepEqual((await reviewer.call('revokeStudentQr',{studentUid:people[0].uid,requestId:'revoke-0001'})).data,revoked.data);
  assert.deepEqual((await reviewer.call('resolveTier1Qr',{payload:replacement.payload})).data,{active:false});
  assert.equal((await store.doc(`studentQrLookups/${createHash('sha256').update(replacement.payload).digest('hex')}`).get()).get('status'),'revoked');
  assert.equal((await store.doc(`studentQrCredentials/${people[0].uid}`).get()).get('verificationStatus'),'revoked');
  await assert.rejects(()=>student.call('completeMyMedicalRecord',{...medical,expectedRevision:1,requestId:'medical-update-0001'}),{code:'functions/failed-precondition'});
  const profile=(await student.call('getMyStudentProfile',{})).data as Record<string,unknown>;
  assert.equal(profile.schoolApprovalStatus,'revoked');
  assert.equal(profile.medicalStatus,'complete');
  assert.equal(profile.conditions,undefined);
  assert.equal(profile.medicalRevision,1);
});
