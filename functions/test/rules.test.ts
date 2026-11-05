import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {resolve} from 'node:path';
import test from 'node:test';
import {
  assertFails,
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from '@firebase/rules-unit-testing';
import {doc, getDoc, setDoc, updateDoc, deleteDoc} from 'firebase/firestore';

let testEnvironment: RulesTestEnvironment;

test.before(async () => {
  const endpoint = process.env.FIRESTORE_EMULATOR_HOST;
  assert.ok(endpoint, 'FIRESTORE_EMULATOR_HOST must be set by the emulator');

  const [host, port] = endpoint.split(':');
  testEnvironment = await initializeTestEnvironment({
    projectId: 'demo-resqme',
    firestore: {
      host,
      port: Number(port),
      rules: await readFile(resolve(process.cwd(), '../firestore.rules'), 'utf8'),
    },
  });
});

test.after(async () => {
  await testEnvironment.cleanup();
});

test('A0 Firestore rules deny an unauthenticated read', async () => {
  const database = testEnvironment.unauthenticatedContext().firestore();

  await assertFails(getDoc(doc(database, 'students', 'synthetic-student')));
});

test('only the profile owner can read a submitted registration', async () => {
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'studentProfiles', 'owner'), {
      status: 'pending_review', lrn: null,
    });
  });
  const owner = testEnvironment.authenticatedContext('owner').firestore();
  await getDoc(doc(owner, 'studentProfiles', 'owner'));
  const other = testEnvironment.authenticatedContext('other').firestore();
  await assertFails(getDoc(doc(other, 'studentProfiles', 'owner')));
  await assertFails(setDoc(doc(other, 'studentProfiles', 'other'), {status: 'approved'}));
  await assertFails(getDoc(doc(testEnvironment.unauthenticatedContext().firestore(), 'studentProfiles', 'owner')));
  await assertFails(setDoc(doc(owner, 'studentProfiles', 'owner'), {status: 'approved'}));
  await assertFails(setDoc(doc(owner, 'studentProfiles', 'owner', 'acknowledgments', 'tier1-registration-v1'), {affirmativeAction: true}));
  await assertFails(getDoc(doc(owner, 'medicalRecords', 'owner')));
  await assertFails(setDoc(doc(owner, 'qrCredentials', 'owner'), {active: true}));
});
test('synthetic medical records and acknowledgments are owner-read-only',async()=>{
  const tester=testEnvironment.authenticatedContext('medical-owner').firestore();
  await assertFails(setDoc(doc(tester,'qaTesters','medical-owner'),{enabled:true,syntheticOnly:true}));
  await assertFails(getDoc(doc(tester,'qaTesters','medical-owner')));
  await testEnvironment.withSecurityRulesDisabled(async context=>{
    await setDoc(doc(context.firestore(),'studentMedicalRecords','medical-owner'),{syntheticOnly:true});
    await setDoc(doc(context.firestore(),'studentMedicalRecords','medical-owner','acknowledgments','request-0001'),{version:'synthetic-medical-v1'});
  });
  for(const suffix of [[],['acknowledgments','request-0001']]){
    const path=['studentMedicalRecords','medical-owner',...suffix];
    const owner=testEnvironment.authenticatedContext('medical-owner').firestore();
    await getDoc(doc(owner,path.join('/')));
    for(const context of [testEnvironment.unauthenticatedContext(),testEnvironment.authenticatedContext('other')]) await assertFails(getDoc(doc(context.firestore(),path.join('/'))));
    await assertFails(setDoc(doc(owner,path.join('/')),{guardianVerified:true}));
    await assertFails(updateDoc(doc(owner,path.join('/')),{guardianVerified:true}));
    await assertFails(deleteDoc(doc(owner,path.join('/'))));
  }
});
test('QR references are private and no client may create/update/delete them',async()=>{
  await testEnvironment.withSecurityRulesDisabled(async context=>{await setDoc(doc(context.firestore(),'studentQrCredentials','qr-owner'),{payload:'resqme:v1:synthetic',verificationStatus:'unverified'});});
  const owner=testEnvironment.authenticatedContext('qr-owner').firestore();
  const ref=doc(owner,'studentQrCredentials','qr-owner');await getDoc(ref);
  await assertFails(setDoc(ref,{payload:'forged'}));await assertFails(updateDoc(ref,{verificationStatus:'approved'}));await assertFails(deleteDoc(ref));
  for(const context of [testEnvironment.unauthenticatedContext(),testEnvironment.authenticatedContext('other')]) await assertFails(getDoc(doc(context.firestore(),'studentQrCredentials','qr-owner')));
});
