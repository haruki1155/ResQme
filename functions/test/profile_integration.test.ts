import assert from 'node:assert/strict';
import test from 'node:test';
import {initializeApp, deleteApp} from 'firebase/app';
import {
  connectAuthEmulator,
  createUserWithEmailAndPassword,
  deleteUser,
  getAuth,
  signOut,
} from 'firebase/auth';
import {connectFunctionsEmulator, getFunctions, httpsCallable} from 'firebase/functions';
import {initializeApp as initializeAdmin, deleteApp as deleteAdmin} from 'firebase-admin/app';
import {getAuth as adminAuth} from 'firebase-admin/auth';
import {getFirestore} from 'firebase-admin/firestore';
import {emulatorConfig, projectId} from './emulator_config';

const endpoints = emulatorConfig(process.env);
const admin = initializeAdmin({projectId}, 'profile-integration');
const store = getFirestore(admin);
const app = initializeApp({projectId, apiKey: 'test'}, 'profile-integration');
const auth = getAuth(app);
connectAuthEmulator(
  auth,
  `http://${endpoints.auth.host}:${endpoints.auth.port}`,
  {disableWarnings: true},
);
const functions = getFunctions(app, 'us-central1');
connectFunctionsEmulator(
  functions,
  endpoints.functions.host,
  endpoints.functions.port,
);
const call = (name: string, data: unknown) =>
  httpsCallable(functions, name, {timeout: 10000})(data);
const foreignUid = 'synthetic-foreign-profile';

let uid: string | undefined;
test.after(async () => {
  const foreignProfile = store.doc(`studentProfiles/${foreignUid}`);
  for (const collection of await foreignProfile.listCollections()) {
    for (const document of (await collection.get()).docs) {
      await document.ref.delete();
    }
  }
  await foreignProfile.delete();
  if (uid) {
    const profile = store.doc(`studentProfiles/${uid}`);
    for (const collection of await profile.listCollections()) {
      for (const document of (await collection.get()).docs) {
        await document.ref.delete();
      }
    }
    await profile.delete();
    await store.doc(`studentMedicalRecords/${uid}`).delete();
    await store.doc(`studentQrCredentials/${uid}`).delete();
    try {
      await adminAuth(admin).deleteUser(uid);
    } catch (error) {
      if ((error as {code?: string}).code !== 'auth/user-not-found') throw error;
    }
  }
  await deleteApp(app);
  await deleteAdmin(admin);
});

test('profile callable authenticates, derives ownership, and filters profile data', {timeout: 30000}, async () => {
  await assert.rejects(() => call('getMyStudentProfile', {}), {
    code: 'functions/unauthenticated',
  });

  const credential = await createUserWithEmailAndPassword(
    auth,
    'profile-owner@example.test',
    'Synthetic-Local-123',
  );
  uid = credential.user.uid;
  const registration = await call('createStudentRegistration', {
    fullName: 'Synthetic Student',
    ageYears: 17,
    noticeVersion: 'tier1-registration-v1',
    acknowledgmentAccepted: true,
    gender: 'Female',
    personalPhone: '0912 345 6789',
    guardianName: 'Synthetic Guardian',
    guardianRelationship: 'Parent',
    guardianPhone: '+63 912 345 6789',
    secondaryName: 'Synthetic Contact',
    secondaryPhone: '0912-345-6789',
  });
  assert.deepEqual(registration.data, {
    status: 'pending_review',
    profilePath: `studentProfiles/${uid}`,
  });

  const profile = store.doc(`studentProfiles/${uid}`);
  await profile.update({
    schoolId: 'must-not-return',
    medicalRecord: {conditions: 'must-not-return'},
    internalMetadata: {privateFlag: true},
    'emergencyContacts.primary.privateFlag': true,
    'emergencyContacts.secondary.privateFlag': true,
  });
  await store.doc(`studentMedicalRecords/${uid}`).set({
    conditions: 'must-not-return',
  });

  const result = await call('getMyStudentProfile', {});
  assert.deepEqual(result.data, {
    schemaVersion: 1,
    fullName: 'Synthetic Student',
    ageYearsAtRegistration: 17,
    status: 'pending_review',
    gender: 'Female',
    personalContactNumber: '09123456789',
    emergencyContacts: {
      primary: {
        fullName: 'Synthetic Guardian',
        relationship: 'Parent',
        phoneNumber: '+639123456789',
      },
      secondary: {
        fullName: 'Synthetic Contact',
        phoneNumber: '09123456789',
      },
    },
  });

  await store.doc(`studentProfiles/${foreignUid}`).set({
    schemaVersion: 1,
    fullName: 'Foreign Synthetic Student',
    ageYearsAtRegistration: 18,
    status: 'pending_review',
    lrn: null,
  });
  await assert.rejects(
    () => call('getMyStudentProfile', {uid: foreignUid}),
    {code: 'functions/invalid-argument'},
  );

  const firstQr = await call('ensureMyTier1Qr', {});
  const repeatedQr = await call('ensureMyTier1Qr', {});
  assert.deepEqual(repeatedQr.data, firstQr.data);
  assert.deepEqual(
    Object.keys(firstQr.data as Record<string, unknown>).sort(),
    ['issuedAt', 'payload', 'verificationStatus'],
  );
  assert.match(
    (firstQr.data as {payload: string}).payload,
    /^resqme:v1:[A-Za-z0-9_-]{43}$/,
  );
  await store.doc(`studentQrCredentials/${uid}`).update({
    privateFlag: true,
  });
  assert.deepEqual((await call('getMyStudentProfile', {})).data, result.data);

  await profile.delete();
  await assert.rejects(() => call('getMyStudentProfile', {}), {
    code: 'functions/not-found',
  });

  await profile.set({
    schemaVersion: 1,
    fullName: 'Synthetic Student',
    ageYearsAtRegistration: '17',
    status: 'pending_review',
    lrn: null,
  });
  await assert.rejects(() => call('getMyStudentProfile', {}), {
    code: 'functions/failed-precondition',
  });

  await signOut(auth);
});
