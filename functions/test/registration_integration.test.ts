import assert from 'node:assert/strict'; import test from 'node:test'; import {initializeApp,deleteApp} from 'firebase/app'; import {getAuth,connectAuthEmulator,signInAnonymously} from 'firebase/auth'; import {getFunctions,connectFunctionsEmulator,httpsCallable} from 'firebase/functions'; import {getFirestore,connectFirestoreEmulator,doc,getDoc,collection,getDocs} from 'firebase/firestore';
import {emulatorConfig, projectId} from './emulator_config';
import {initializeApp as initializeAdmin, deleteApp as deleteAdmin} from 'firebase-admin/app';
import {getFirestore as adminFirestore} from 'firebase-admin/firestore';
console.log('[1] Test runner started');
const endpoints = emulatorConfig(process.env);
const admin = initializeAdmin({projectId}, 'registration-integration');
const store = adminFirestore(admin);
const app = initializeApp({projectId, apiKey: 'test'});
const auth = getAuth(app);
connectAuthEmulator(auth, `http://${endpoints.auth.host}:${endpoints.auth.port}`, {disableWarnings: true});
const db = getFirestore(app);
connectFirestoreEmulator(db, endpoints.firestore.host, endpoints.firestore.port);
const fn = getFunctions(app, 'us-central1');
connectFunctionsEmulator(fn, endpoints.functions.host, endpoints.functions.port);
const call = httpsCallable(fn, 'createStudentRegistration', {timeout: 8000});
const data = {fullName: 'Synthetic Student', ageYears: 17, noticeVersion: 'tier1-registration-v1', acknowledgmentAccepted: true};
console.log('[2] Firebase test clients initialized');
test.after(async () => {await deleteApp(app); await deleteAdmin(admin); console.log('[7] Test cleanup completed');});
test('unauthenticated callable rejects', {timeout: 10000}, async () => {
  console.log('[3] Test case started');
  assert.equal(auth.currentUser, null);
  console.log('[4] Sending callable request');
  const before = await store.collection('studentProfiles').get();
  await assert.rejects(() => call(data), {code: 'functions/unauthenticated'});
  assert.equal((await store.collection('studentProfiles').get()).size, before.size);
  console.log('[5] Callable response received');
  console.log('[6] Assertions completed');
});

for (const altered of [false, true]) {
  test(altered ? 'altered repeat rejects without changing records' : 'identical repeat preserves one profile and acknowledgment', {timeout: 15000}, async () => {
    const user = (await signInAnonymously(auth)).user;
    const profile = store.doc(`studentProfiles/${user.uid}`);
    try {
      await call(data);
      const original = (await profile.get()).data();
      const acknowledgments = await profile.collection('acknowledgments').get();
      assert.equal(acknowledgments.size, 1);
      assert.equal(original?.status, 'pending_guardian');
      assert.equal(original?.lrn, null);
      if (altered) await assert.rejects(() => call({...data, fullName: 'Altered Synthetic', ageYears: 18}), {code: 'functions/already-exists'});
      else await call(data);
      assert.deepEqual((await profile.get()).data(), original);
      assert.deepEqual((await profile.collection('acknowledgments').get()).docs.map(d => d.data()), acknowledgments.docs.map(d => d.data()));
      assert.equal((await profile.listCollections()).length, 1);
    } finally {
      for (const ack of (await profile.collection('acknowledgments').get()).docs) await ack.ref.delete();
      await profile.delete();
      await user.delete();
    }
  });
}
