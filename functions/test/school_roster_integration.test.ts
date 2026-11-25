import assert from 'node:assert/strict';
import test from 'node:test';
import {initializeApp,deleteApp} from 'firebase/app';
import {connectAuthEmulator,getAuth,signInWithEmailAndPassword} from 'firebase/auth';
import {connectFunctionsEmulator,getFunctions,httpsCallable} from 'firebase/functions';
import {initializeApp as initializeAdmin,deleteApp as deleteAdmin} from 'firebase-admin/app';
import {getAuth as adminAuth} from 'firebase-admin/auth';
import {getFirestore} from 'firebase-admin/firestore';
import {emulatorConfig,projectId} from './emulator_config';
import {normalizeRosterName,rosterCodeDigest,rosterLookupId} from '../src/school/roster_contract';

const endpoints=emulatorConfig(process.env);
const key=process.env.RESQME_SCHOOL_ROSTER_HMAC_KEY??'';
const admin=initializeAdmin({projectId},'school-roster-integration');
const store=getFirestore(admin);
const people=[
 {uid:'qa-school-claim-one',email:'school-claim-one@example.test'},
 {uid:'qa-school-claim-two',email:'school-claim-two@example.test'},
];
const apps=people.map(({email},index)=>{
 const app=initializeApp({projectId,apiKey:'test'},`school-roster-${index}`),auth=getAuth(app);
 connectAuthEmulator(auth,`http://${endpoints.auth.host}:${endpoints.auth.port}`,{disableWarnings:true});
 const functions=getFunctions(app,'us-central1');connectFunctionsEmulator(functions,endpoints.functions.host,endpoints.functions.port);
 return {app,auth,email,call:(name:string,data:unknown)=>httpsCallable(functions,name,{timeout:15000})(data)};
});
const lrn='900000000040',fullName='Synthetic Roster Race Student',enrollmentCode='LOCAL-ONLY-RACE-CODE-0001';
const rosterId=rosterLookupId(lrn,key),codeDigest=rosterCodeDigest(enrollmentCode,key);
const rosterRef=store.doc(`schoolRosterClaims/${rosterId}`),codeRef=store.doc(`schoolRosterCodes/${codeDigest}`);
const registration={fullName,ageYears:18,lrn,enrollmentCode,noticeVersion:'tier1-registration-v1',acknowledgmentAccepted:true};
const createdUsers:string[]=[];
let rosterCreated=false,codeCreated=false;

async function removeProfile(uid:string){
 const profile=store.doc(`studentProfiles/${uid}`);
 for(const collection of await profile.listCollections()) for(const item of (await collection.get()).docs) await item.ref.delete();
 await profile.delete();
}

test.before(async()=>{
 if(Buffer.byteLength(key,'utf8')<32) return;
 for(const person of people){await adminAuth(admin).createUser({...person,password:'Synthetic-Local-123'});createdUsers.push(person.uid);}
 for(const client of apps) await signInWithEmailAndPassword(client.auth,client.email,'Synthetic-Local-123');
 await rosterRef.create({schemaVersion:1,syntheticFixture:true,schoolId:'synthetic-school',normalizedName:normalizeRosterName(fullName),enrollmentCodeDigest:codeDigest,claimedByUid:null});
 rosterCreated=true;
 await codeRef.create({schemaVersion:1,syntheticFixture:true,rosterId,claimedByUid:null});
 codeCreated=true;
});

test.after(async()=>{
 for(const uid of createdUsers){
  await removeProfile(uid);
  try{await adminAuth(admin).deleteUser(uid);}catch(error){if((error as {code?:string}).code!=='auth/user-not-found') throw error;}
 }
 if(rosterCreated) await rosterRef.delete();
 if(codeCreated) await codeRef.delete();
 for(const client of apps) await deleteApp(client.app);
 await deleteAdmin(admin);
});

test('two Auth UIDs cannot consume one roster identity or enrollment code', {skip:Buffer.byteLength(key,'utf8')<32,timeout:30000},async()=>{
 const results=await Promise.all(apps.map(client=>client.call('createStudentRegistration',registration)));
 const profiles=await Promise.all(people.map(person=>store.doc(`studentProfiles/${person.uid}`).get()));
 const approved=profiles.filter(profile=>profile.get('schoolApprovalStatus')==='approved');
 const pending=profiles.filter(profile=>profile.get('schoolApprovalStatus')==='pending');
 assert.equal(approved.length,1);assert.equal(pending.length,1);
 assert.equal(approved[0].get('schoolVerificationMethod'),'roster');
 assert.equal(approved[0].get('lrn'),lrn);
 assert.equal(pending[0].get('schoolVerificationOutcome'),'conflict');
 const claim=(await rosterRef.get()).data();assert.equal(typeof claim?.claimedByUid,'string');
 assert.equal((await codeRef.get()).get('claimedByUid'),claim?.claimedByUid);
 assert.equal(results.length,2);
 const winnerIndex=people.findIndex(person=>person.uid===claim?.claimedByUid);
 await apps[winnerIndex].call('createStudentRegistration',registration);
 assert.equal((await rosterRef.get()).get('claimedByUid'),people[winnerIndex].uid);
 assert.equal((await store.doc(`studentProfiles/${people[winnerIndex].uid}/acknowledgments/tier1-registration-v1`).get()).exists,true);
});
