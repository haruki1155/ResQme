import assert from 'node:assert/strict';
import test from 'node:test';
import {initializeApp,deleteApp} from 'firebase/app';
import {connectAuthEmulator,getAuth,signInWithEmailAndPassword} from 'firebase/auth';
import {connectFunctionsEmulator,getFunctions,httpsCallable} from 'firebase/functions';
import {initializeApp as initializeAdmin,deleteApp as deleteAdmin} from 'firebase-admin/app';
import {getAuth as adminAuth} from 'firebase-admin/auth';
import {getFirestore} from 'firebase-admin/firestore';
import {emulatorConfig,projectId} from './emulator_config';
const endpoints=emulatorConfig(process.env);
const admin=initializeAdmin({projectId},'onboarding-integration');
const store=getFirestore(admin);
function client(name:string){const app=initializeApp({projectId,apiKey:'test'},name);const auth=getAuth(app);connectAuthEmulator(auth,`http://${endpoints.auth.host}:${endpoints.auth.port}`,{disableWarnings:true});const fn=getFunctions(app,'us-central1');connectFunctionsEmulator(fn,endpoints.functions.host,endpoints.functions.port);return {app,auth,call:(name:string,data:unknown)=>httpsCallable(fn,name,{timeout:10000})(data)};}
const adult=client('qa-adult'),minor=client('qa-minor'),outsider=client('qa-outsider'),anonymous=client('qa-anonymous');
const fixtures=[{client:adult,uid:'qa-medical-adult',age:18},{client:minor,uid:'qa-medical-minor',age:17},{client:outsider,uid:'qa-medical-outsider',age:18}];
const created:string[]=[];
test.before(async()=>{
  for(const fixture of fixtures){
    const email=`${fixture.uid}@example.test`;
    await adminAuth(admin).createUser({uid:fixture.uid,email,password:'Synthetic-Local-123'});created.push(fixture.uid);
    if(fixture.client!==outsider) await store.doc(`qaTesters/${fixture.uid}`).set({enabled:true,syntheticOnly:true});
    await signInWithEmailAndPassword(fixture.client.auth,email,'Synthetic-Local-123');
    await fixture.client.call('createStudentRegistration',{fullName:'Synthetic Tester',ageYears:fixture.age,noticeVersion:'tier1-registration-v1',acknowledgmentAccepted:true});
  }
});
test.after(async()=>{
  for(const uid of created){
    for(const path of [`studentProfiles/${uid}`,`studentMedicalRecords/${uid}`,`studentQrCredentials/${uid}`]) {
      const ref=store.doc(path);for(const collection of await ref.listCollections()){for(const doc of (await collection.get()).docs) await doc.ref.delete();}await ref.delete();
    }
    await adminAuth(admin).deleteUser(uid);
    await store.doc(`qaTesters/${uid}`).delete();
  }
  for(const value of [adult,minor,outsider,anonymous]) await deleteApp(value.app);
  await deleteAdmin(admin);
});
const base={conditions:{state:'unknown'},allergies:{state:'none_known'},acknowledgment:{version:'synthetic-medical-v1',syntheticDataConfirmed:true},expectedRevision:0,requestId:'medical-request-0001'};
test('medical denies anonymous, non-QA and missing minor acknowledgment', {timeout:20000},async()=>{
  await assert.rejects(()=>anonymous.call('saveMySyntheticMedicalRecord',base),{code:'functions/unauthenticated'});
  await assert.rejects(()=>outsider.call('saveMySyntheticMedicalRecord',base),{code:'functions/permission-denied'});
  await assert.rejects(()=>minor.call('saveMySyntheticMedicalRecord',base),{code:'functions/invalid-argument'});
  assert.equal((await store.doc('studentMedicalRecords/qa-medical-outsider').get()).exists,false);
  assert.equal((await store.doc('studentMedicalRecords/qa-medical-minor').get()).exists,false);
});
test('medical save/replay/stale contact/clear preserve private data and pending status', {timeout:30000},async()=>{
  const first=await adult.call('saveMySyntheticMedicalRecord',base);
  assert.deepEqual((await adult.call('saveMySyntheticMedicalRecord',base)).data,first.data);
  await assert.rejects(()=>adult.call('saveMySyntheticMedicalRecord',{...base,conditions:{state:'none_known'}}),{code:'functions/already-exists'});
  const updates=await Promise.allSettled(['revision-a','revision-b'].map(requestId=>adult.call('saveMySyntheticMedicalRecord',{...base,expectedRevision:1,requestId})));
  assert.equal(updates.filter(value=>value.status==='fulfilled').length,1);
  assert.equal((updates.find(value=>value.status==='rejected') as PromiseRejectedResult).reason.code,'functions/failed-precondition');
  const record=store.doc('studentMedicalRecords/qa-medical-adult');
  const expectedContact={fullName:null,relationship:null,phoneNumber:null};
  const emergencyContact={fullName:'Fictional Contact',relationship:'Parent',phoneNumber:'09123456789'};
  await adult.call('saveMySyntheticMedicalRecord',{...base,expectedRevision:2,requestId:'contact-update-0001',expectedContact,emergencyContact});
  await assert.rejects(()=>adult.call('saveMySyntheticMedicalRecord',{...base,expectedRevision:3,requestId:'contact-stale-0001',expectedContact,emergencyContact}),{code:'functions/failed-precondition'});
  assert.equal((await record.get()).get('revision'),3);
  const cleared=await adult.call('clearMySyntheticMedicalRecord',{expectedRevision:3,requestId:'clear-request-0001'});
  assert.deepEqual((await adult.call('clearMySyntheticMedicalRecord',{expectedRevision:3,requestId:'clear-request-0001'})).data,cleared.data);
  const result=(await record.get()).data()!;
  assert.equal(result.medicalStatus,'not_started');assert.equal(result.conditions,undefined);assert.equal(result.allergies,undefined);
  const profile=(await store.doc('studentProfiles/qa-medical-adult').get()).data()!;
  assert.equal(profile.status,'pending_review');assert.equal(profile.conditions,undefined);assert.deepEqual(profile.emergencyContacts.primary,emergencyContact);
});
test('minor test save never verifies guardian authorization or enrollment', {timeout:15000},async()=>{
  await minor.call('saveMySyntheticMedicalRecord',{...base,acknowledgment:{...base.acknowledgment,minorNoticeAcknowledged:true}});
  const record=(await store.doc('studentMedicalRecords/qa-medical-minor').get()).data()!;
  assert.equal(record.guardianAuthorizationStatus,'not_verified');assert.equal(record.syntheticOnly,true);assert.equal(record.medicalStatus,'completed_synthetic');
  assert.equal((await store.doc('studentProfiles/qa-medical-minor').get()).get('status'),'pending_review');
});
test('QR denies forged requests and non-pending/missing registration', {timeout:20000},async()=>{
  await assert.rejects(()=>anonymous.call('ensureMyTier1Qr',{}),{code:'functions/unauthenticated'});
  await assert.rejects(()=>adult.call('ensureMyTier1Qr',{uid:'other'}),{code:'functions/invalid-argument'});
  const ref=store.doc('studentProfiles/qa-medical-outsider');const before=(await ref.get()).data()!;
  try{
    for(const status of ['approved','rejected','deactivated','unknown']){await ref.update({status});await assert.rejects(()=>outsider.call('ensureMyTier1Qr',{}),{code:'functions/failed-precondition'});}
    await ref.delete();await assert.rejects(()=>outsider.call('ensureMyTier1Qr',{}),{code:'functions/failed-precondition'});
  }finally{await ref.set(before);}
});
test('QR activation remains denied until production medical completion and trusted school approval', {timeout:20000},async()=>{
  for(const person of [adult,minor,outsider]) await assert.rejects(()=>person.call('ensureMyTier1Qr',{}),{code:'functions/failed-precondition'});
  for(const uid of ['qa-medical-adult','qa-medical-minor','qa-medical-outsider']) {
    assert.equal((await store.doc(`studentQrCredentials/${uid}`).get()).exists,false);
    assert.equal((await store.doc(`studentProfiles/${uid}`).get()).get('schoolAssignmentStatus'),'unassigned');
  }
});
