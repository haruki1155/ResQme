import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import test from 'node:test';
import {initializeApp,deleteApp,getApps} from 'firebase-admin/app';
import {getAuth as adminAuth} from 'firebase-admin/auth';
import {getFirestore} from 'firebase-admin/firestore';
import {initializeApp as initializeClient,deleteApp as deleteClient} from 'firebase/app';
import {connectAuthEmulator,getAuth,signInWithEmailAndPassword,signOut} from 'firebase/auth';
import {connectFunctionsEmulator,getFunctions,httpsCallable} from 'firebase/functions';
import {emulatorConfig,projectId} from './emulator_config';
import {syntheticSchoolRoster} from './fixtures/synthetic_school_roster';
import {rosterCodeDigest,rosterLookupId} from '../src/school/roster_contract';
import {seedLocalSchoolRoster} from '../tools/seed_local_school_roster';

const endpoints=emulatorConfig(process.env);
const key=process.env.RESQME_SCHOOL_ROSTER_HMAC_KEY??'';
const admin=initializeApp({projectId},'school-roster-fixtures-integration');
const db=getFirestore(admin);
const adminUsers=getAuthForAdmin();

function getAuthForAdmin(){return adminAuth(admin);}

const students=syntheticSchoolRoster.map((row,index)=>({
  row,
  uid:`qa-school-fixture-${index+1}`,
  email:`school-fixture-${index+1}@example.test`,
}));
const reviewer={uid:'qa-school-fixture-reviewer',email:'school-reviewer-fixture@example.test'};
const clients=[...students,reviewer].map((person,index)=>{
  const app=initializeClient({projectId,apiKey:'test'},`school-fixture-client-${index}`);
  const auth=getAuth(app);
  connectAuthEmulator(auth,`http://${endpoints.auth.host}:${endpoints.auth.port}`,{disableWarnings:true});
  const functions=getFunctions(app,'us-central1');
  connectFunctionsEmulator(functions,endpoints.functions.host,endpoints.functions.port);
  return {app,auth,email:person.email,call:(name:string,data:unknown)=>httpsCallable(functions,name,{timeout:20000})(data)};
});
const reviewerClient=clients[students.length];
const profileRefs=students.map(({uid})=>db.doc(`studentProfiles/${uid}`));
const medicalRefs=students.map(({uid})=>db.doc(`studentMedicalRecords/${uid}`));
const credentialRefs=students.map(({uid})=>db.doc(`studentQrCredentials/${uid}`));
const reviewerRef=db.doc(`schoolReviewers/${reviewer.uid}`);
const rosterRefs=syntheticSchoolRoster.map(row=>db.doc(`schoolRosterClaims/${rosterLookupId(row.lrn,key)}`));
const codeRefs=syntheticSchoolRoster.flatMap(row=>row.enrollmentCode?[db.doc(`schoolRosterCodes/${rosterCodeDigest(row.enrollmentCode,key)}`)]:[]);
const createdUsers:string[]=[];
const qrPayloads=new Set<string>();
let seeded=false;
let createdDefaultAdminApp=false;

async function assertUserAbsent(uid:string,email:string){
  try{await adminUsers.getUser(uid);throw new Error('Synthetic Auth fixture collision.');}
  catch(error){if((error as {code?:string}).code!=='auth/user-not-found')throw error;}
  try{await adminUsers.getUserByEmail(email);throw new Error('Synthetic Auth fixture collision.');}
  catch(error){if((error as {code?:string}).code!=='auth/user-not-found')throw error;}
}

async function deleteTree(ref:FirebaseFirestore.DocumentReference){
  for(const childCollection of await ref.listCollections()){
    for(const child of (await childCollection.get()).docs) await deleteTree(child.ref);
  }
  await ref.delete();
}

async function completeMedical(client:typeof clients[number],requestId:string){
  return client.call('completeMyMedicalRecord',{
    conditions:{state:'unknown'},allergies:{state:'none_known'},selfReportConfirmed:true,
    primaryContact:{fullName:'Fictional Emergency Contact',relationship:'Parent',phoneNumber:'09123456789'},
    expectedRevision:0,requestId,
  });
}

test.before(async()=>{
  if(Buffer.byteLength(key,'utf8')<32) throw new Error('Integration requires an injected local-only HMAC key.');
  if(getApps().some(app=>app.name==='[DEFAULT]')) throw new Error('Unexpected default Admin app; refusing fixture setup.');
  for(const person of [...students,reviewer]) await assertUserAbsent(person.uid,person.email);
  const existingProfiles=await Promise.all([...profileRefs,...medicalRefs,...credentialRefs,reviewerRef,...rosterRefs,...codeRefs].map(ref=>ref.get()));
  if(existingProfiles.some(snapshot=>snapshot.exists)) throw new Error('Synthetic Firestore fixture collision; refusing setup.');

  for(const person of [...students,reviewer]){
    await adminUsers.createUser({uid:person.uid,email:person.email,password:'Synthetic-Local-123'});
    createdUsers.push(person.uid);
  }
  for(const client of clients) await signInWithEmailAndPassword(client.auth,client.email,'Synthetic-Local-123');
  createdDefaultAdminApp=true;
  await seedLocalSchoolRoster(process.env);
  seeded=true;
  if(!getApps().some(app=>app.name==='[DEFAULT]'&&app.options.projectId==='demo-resqme')) throw new Error('Local roster seeder did not initialize the demo project.');
  await reviewerRef.create({active:true,schoolId:'synthetic-school'});
});

test.after(async()=>{
  for(const payload of qrPayloads){
    const hash=createHash('sha256').update(payload).digest('hex');
    await db.doc(`studentQrLookups/${hash}`).delete();
  }
  for(const uid of students.map(person=>person.uid)){
    for(const ref of [db.doc(`studentProfiles/${uid}`),db.doc(`studentMedicalRecords/${uid}`),db.doc(`studentQrCredentials/${uid}`)]){
      if((await ref.get()).exists) await deleteTree(ref);
    }
  }
  if((await reviewerRef.get()).exists) await reviewerRef.delete();
  for(const uid of createdUsers){
    try{await adminUsers.deleteUser(uid);}catch(error){if((error as {code?:string}).code!=='auth/user-not-found')throw error;}
  }
  if(seeded){
    for(let index=0;index<rosterRefs.length;index++){
      const snapshot=await rosterRefs[index].get();
      if(snapshot.exists){
        if(snapshot.get('syntheticFixture')!==true||snapshot.get('fixtureCase')!==syntheticSchoolRoster[index].caseId) throw new Error('Roster fixture ownership mismatch; preserving record.');
        await rosterRefs[index].delete();
      }
    }
    const codeRows=syntheticSchoolRoster.filter(row=>row.enrollmentCode);
    for(let index=0;index<codeRefs.length;index++){
      const snapshot=await codeRefs[index].get();
      if(snapshot.exists){
        if(snapshot.get('syntheticFixture')!==true||snapshot.get('rosterId')!==rosterLookupId(codeRows[index].lrn,key)) throw new Error('Code fixture ownership mismatch; preserving record.');
        await codeRefs[index].delete();
      }
    }
  }
  for(const client of clients) await deleteClient(client.app);
  if(createdDefaultAdminApp){
    const app=getApps().find(value=>value.name==='[DEFAULT]'&&value.options.projectId==='demo-resqme');
    if(app) await deleteApp(app);
  }
  await deleteApp(admin);
});

test('five synthetic roster scenarios preserve school, medical, QR and privacy boundaries',{timeout:90000},async()=>{
  const registrationResults=await Promise.all(students.map(({row},index)=>{
    const ageYears=row.caseId==='auto-3'?17:18;
    const data={fullName:row.fullName,ageYears,lrn:row.lrn,enrollmentCode:row.enrollmentCode,
      ...(ageYears<18?{guardianName:'Fictional Guardian',guardianRelationship:'Parent',guardianPhone:'09123456789'}:{}),
      noticeVersion:'tier1-registration-v1',acknowledgmentAccepted:true};
    return clients[index].call('createStudentRegistration',data);
  }));
  assert.equal(registrationResults.length,5);

  const profiles=await Promise.all(profileRefs.map(ref=>ref.get()));
  for(let index=0;index<3;index++){
    const row=syntheticSchoolRoster[index],profile=profiles[index];
    assert.equal(profile.get('schoolApprovalStatus'),'approved');
    assert.equal(profile.get('schoolAssignmentStatus'),'assigned');
    assert.equal(profile.get('schoolVerificationMethod'),'roster');
    assert.equal(profile.get('schoolVerificationOutcome'),'verified');
    assert.equal(profile.get('schoolId'),'synthetic-school');
    assert.equal(profile.get('lrn'),row.lrn);
    assert.equal(profile.get('medicalStatus'),'not_started');
    assert.equal((await rosterRefs[index].get()).get('claimedByUid'),students[index].uid);
    assert.equal((await codeRefs[index].get()).get('claimedByUid'),students[index].uid);
  }

  const manualProfile=profiles[3];
  assert.equal(manualProfile.get('schoolApprovalStatus'),'pending');
  assert.equal(manualProfile.get('schoolAssignmentStatus'),'assigned');
  assert.equal(manualProfile.get('schoolVerificationOutcome'),'manual_review');
  const conflictProfile=profiles[4];
  assert.equal(conflictProfile.get('schoolApprovalStatus'),'pending');
  assert.equal(conflictProfile.get('schoolVerificationOutcome'),'manual_review');
  assert.equal((await rosterRefs[4].get()).get('claimedByUid'),'synthetic-already-claimed-uid');
  assert.equal((await codeRefs[3].get()).get('claimedByUid'),'synthetic-already-claimed-uid');

  const qrResults=await Promise.all(students.map((_,index)=>clients[index].call('ensureMyTier1Qr',{})));
  for(let index=0;index<qrResults.length;index++){
    const qr=qrResults[index].data as {payload:string;verificationStatus:string};
    qrPayloads.add(qr.payload);
    assert.equal(qr.verificationStatus,'pending');
    assert.deepEqual((await clients[index].call('resolveTier1Qr',{payload:qr.payload})).data,{active:false});
    const profile=(await clients[index].call('getMyStudentProfile',{})).data as Record<string,unknown>;
    assert.equal(profile.lrn,undefined);
    // These are owner-only compatibility fields, never public resolver fields.
    assert.deepEqual(Object.keys(profile).sort(),[
      'schemaVersion','fullName','ageYearsAtRegistration','status','schoolApprovalStatus',
      'schoolAssignmentStatus','schoolVerificationOutcome','medicalStatus','medicalRevision',
      'gender','personalContactNumber','emergencyContacts',
    ].sort());
    assert.equal(profile.personalContactNumber,null);
    const minor=students[index].row.caseId==='auto-3';
    assert.deepEqual(profile.emergencyContacts,{
      primary:minor?{fullName:'Fictional Guardian',relationship:'Parent',phoneNumber:'09123456789'}:{fullName:null,relationship:null,phoneNumber:null},
      secondary:{fullName:null,phoneNumber:null},
    });
  }

  const studentOneProfile=(await profileRefs[0].get()).data();
  await clients[0].call('createStudentRegistration',{
    fullName:syntheticSchoolRoster[0].fullName,ageYears:18,lrn:syntheticSchoolRoster[0].lrn,
    enrollmentCode:syntheticSchoolRoster[0].enrollmentCode,noticeVersion:'tier1-registration-v1',acknowledgmentAccepted:true,
  });
  assert.deepEqual((await profileRefs[0].get()).data(),studentOneProfile);
  const originalQr=qrResults[0].data as {payload:string};
  const repeatedQr=(await clients[0].call('ensureMyTier1Qr',{})).data as {payload:string;verificationStatus:string};
  qrPayloads.add(repeatedQr.payload);
  assert.equal(repeatedQr.payload,originalQr.payload);
  await signOut(clients[0].auth);
  await signInWithEmailAndPassword(clients[0].auth,clients[0].email,'Synthetic-Local-123');
  assert.equal(((await clients[0].call('getMyStudentProfile',{})).data as Record<string,unknown>).schoolApprovalStatus,'approved');

  await assert.rejects(()=>clients[1].call('getSchoolReviewCandidate',{studentUid:students[3].uid}),{code:'functions/permission-denied'});
  await reviewerRef.update({schoolId:'different-synthetic-school'});
  await assert.rejects(()=>reviewerClient.call('getSchoolReviewCandidate',{studentUid:students[3].uid}),(error:unknown)=>{
    const denial=error as {code?:unknown;message?:unknown;details?:unknown;data?:unknown};
    assert.equal(denial.code,'functions/not-found');
    assert.equal(denial.message,'Candidate unavailable. [404]');
    assert.equal(denial.details,undefined);
    assert.equal(Object.prototype.hasOwnProperty.call(denial,'data'),false);
    return true;
  });
  await reviewerRef.update({schoolId:'synthetic-school'});
  const candidate=(await reviewerClient.call('getSchoolReviewCandidate',{studentUid:students[3].uid})).data;
  assert.deepEqual(candidate,{studentUid:students[3].uid,fullName:syntheticSchoolRoster[3].fullName,schoolApprovalStatus:'pending',schoolVerificationOutcome:'manual_review'});
  await reviewerClient.call('approveStudentQr',{studentUid:students[3].uid,requestId:'fixture-approval-0001'});
  assert.equal((await db.doc(`studentProfiles/${students[3].uid}/schoolApprovals/fixture-approval-0001`).get()).exists,true);
  const approvedManualQr=(await clients[3].call('ensureMyTier1Qr',{})).data as {payload:string;verificationStatus:string};
  qrPayloads.add(approvedManualQr.payload);
  assert.equal(approvedManualQr.verificationStatus,'pending');

  await completeMedical(clients[0],'fixture-medical-adult-0001');
  const adultQr=(await clients[0].call('ensureMyTier1Qr',{})).data as {payload:string;verificationStatus:string};
  qrPayloads.add(adultQr.payload);
  assert.equal(adultQr.verificationStatus,'active');
  assert.deepEqual((await reviewerClient.call('resolveTier1Qr',{payload:adultQr.payload})).data,{active:true});

  await completeMedical(clients[2],'fixture-medical-minor-0001');
  const minorQr=(await clients[2].call('ensureMyTier1Qr',{})).data as {payload:string;verificationStatus:string};
  qrPayloads.add(minorQr.payload);
  assert.equal(minorQr.verificationStatus,'pending');
  assert.deepEqual((await reviewerClient.call('resolveTier1Qr',{payload:minorQr.payload})).data,{active:false});
  assert.equal((await db.doc(`studentGuardianAuthorizations/${students[2].uid}`).get()).exists,false);
});
