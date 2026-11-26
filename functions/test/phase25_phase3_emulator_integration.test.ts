import assert from 'node:assert/strict';
import test from 'node:test';
import * as XLSX from 'xlsx';
import {deleteApp, initializeApp} from 'firebase/app';
import {connectAuthEmulator, getAuth, signInWithEmailAndPassword, signOut} from 'firebase/auth';
import {connectFirestoreEmulator, getFirestore as clientFirestore} from 'firebase/firestore';
import {connectFunctionsEmulator, getFunctions, httpsCallable} from 'firebase/functions';
import {deleteApp as deleteAdmin, initializeApp as initializeAdmin} from 'firebase-admin/app';
import {getAuth as adminAuth} from 'firebase-admin/auth';
import {FieldValue, getFirestore} from 'firebase-admin/firestore';
import {noticeVersion} from '../src/registration/registration_contract';
import {emulatorConfig, projectId} from './emulator_config';

const endpoints = emulatorConfig(process.env);
const adminApp = initializeAdmin({projectId}, 'phase25-phase3-integration');
const store = getFirestore(adminApp);

const masterEmail = 'p3-master@example.test';
const masterUid = 'qa-p3-master';
const authStaffEmail = 'p3-auth@example.test';
const authStaffUid = 'qa-p3-auth';
const minorEmail = 'p3-minor@example.test';
const minorUid = 'qa-p3-minor';
const duplicateEmail = 'p3-dup@example.test';
const duplicateUid = 'qa-p3-dup';
const password = 'Master-Initial!2026';
const schoolId = 'qa-p3-school';

function makeClient(name: string) {
  const app = initializeApp({projectId, apiKey: 'test'}, name);
  const auth = getAuth(app);
  connectAuthEmulator(auth, `http://${endpoints.auth.host}:${endpoints.auth.port}`, {
    disableWarnings: true,
  });
  const fs = clientFirestore(app);
  connectFirestoreEmulator(fs, endpoints.firestore.host, endpoints.firestore.port);
  const fns = getFunctions(app, 'us-central1');
  connectFunctionsEmulator(fns, endpoints.functions.host, endpoints.functions.port);
  return {
    app,
    auth,
    call: (fn: string, data: unknown = {}) => httpsCallable(fns, fn, {timeout: 15000})(data),
  };
}

const masterClient = makeClient('p3-master-client');
const authStaffClient = makeClient('p3-auth-client');
const minorClient = makeClient('p3-minor-client');
const dupClient = makeClient('p3-dup-client');

function buildSf1XlsxBase64(): string {
  const aoa: Array<Array<unknown>> = [
    ['School Form 1 (SF 1) School Register'],
    ['(Fictional Emulator Fixture)'],
    [],
    ['', '', '', 'School ID', schoolId],
    [],
    ['', '', 'School Name', 'QA Pilot High', '', '', '', '', '', '', '', '', 'School Year', '2026-2027', '', '', '', '', 'Grade Level', 'Grade 10'],
    [],
    ['', 'LRN', 'NAME (Last Name, First Name, Middle Name)', '', '', '', 'Sex (M/F)', 'BIRTH DATE (mm/dd/ yyyy)', 'AGE', '', '', '', '', '', '', '', '', '', '', 'PARENTS', '', '', '', 'GUARDIAN (If not Parent)', '', 'Contact Number of Parent or Guardian'],
    ['', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', "Father's Name", '', "Mother's Maiden Name", '', 'Name', 'Relation-ship', ''],
    ['', '009987654321', 'Dela Cruz, Juan Santos', '', '', '', 'M', '05/10/2010', '', '', '', '', '', '', '', '', '', '', '', 'Dela Cruz, Pedro', '', 'Santos, Maria', '', 'Maria Dela Cruz', 'Mother', '09171234567'],
    ['', '009123456789', 'Reyes, Mara Cruz', '', '', '', 'F', '03/10/2005', '', '', '', '', '', '', '', '', '', '', '', 'Reyes, Jose', '', 'Cruz, Elena', '', '', '', '09179876543'],
    ['', '009987654321', 'Dela Cruz, Juan Santos', '', '', '', 'M', '05/10/2010', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', ''],
    ['', '001122334455', 'Invalid, Date', '', '', '', 'F', '02/30/2010', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', ''],
    ['List and Code of Indicators under REMARKS', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 'Prepared by:'],
  ];
  const ws = XLSX.utils.aoa_to_sheet(aoa);
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, ws, 'School Form 1 (SF1)');
  return (XLSX.write(wb, {type: 'buffer', bookType: 'xlsx'}) as Buffer).toString('base64');
}

test.before(async () => {
  for (const u of [
    {uid: masterUid, email: masterEmail},
    {uid: authStaffUid, email: authStaffEmail},
    {uid: minorUid, email: minorEmail},
    {uid: duplicateUid, email: duplicateEmail},
  ]) {
    await adminAuth(adminApp).createUser({
      uid: u.uid,
      email: u.email,
      password,
      emailVerified: true,
    });
  }

  await store.doc(`staffAccounts/${masterUid}`).set({
    schoolId,
    role: 'admin',
    active: true,
    isMasterAdmin: true,
    mustChangePassword: false,
    requiresEmailVerification: true,
    fullName: 'Phase 3 Master Admin',
    createdAt: FieldValue.serverTimestamp(),
  });
  await store.doc(`staffAccounts/${authStaffUid}`).set({
    schoolId,
    role: 'authorized',
    active: true,
    isMasterAdmin: false,
    mustChangePassword: false,
    fullName: 'Phase 3 Nurse',
    createdAt: FieldValue.serverTimestamp(),
  });
});

test.after(async () => {
  await Promise.allSettled([
    signOut(masterClient.auth),
    signOut(authStaffClient.auth),
    signOut(minorClient.auth),
    signOut(dupClient.auth),
    deleteApp(masterClient.app),
    deleteApp(authStaffClient.app),
    deleteApp(minorClient.app),
    deleteApp(dupClient.app),
    deleteAdmin(adminApp),
  ]);
});

test('SF1 import, authoritative minor birthDate/grade inheritance, LRN lock, and Activity Logs in emulators', async () => {
  await signInWithEmailAndPassword(masterClient.auth, masterEmail, password);
  await signInWithEmailAndPassword(authStaffClient.auth, authStaffEmail, password);
  await signInWithEmailAndPassword(minorClient.auth, minorEmail, password);
  await signInWithEmailAndPassword(dupClient.auth, duplicateEmail, password);

  const fileBase64 = buildSf1XlsxBase64();

  // Authorized staff denied from roster preview and activity logs
  await assert.rejects(() =>
    authStaffClient.call('previewSchoolRosterImport', {
      fileName: 'sf1.xlsx',
      fileBase64,
      confirmedGradeLevel: 'Grade 10',
    }),
  );
  await assert.rejects(() => authStaffClient.call('listSchoolActivityLogs', {}));

  // Master Admin previews SF1
  const preview = (await masterClient.call('previewSchoolRosterImport', {
    fileName: 'sf1.xlsx',
    fileBase64,
    confirmedGradeLevel: null,
  })).data as {
    previewId: string;
    fileSha256: string;
    confirmedGradeLevel: string;
    summary: {newCount: number; duplicateCount: number; invalidCount: number};
  };
  assert.equal(preview.confirmedGradeLevel, 'Grade 10');
  assert.equal(preview.summary.newCount, 2);
  assert.equal(preview.summary.duplicateCount, 1);
  assert.equal(preview.summary.invalidCount, 1);

  // Master Admin commits SF1 and retries idempotently
  const commit = (await masterClient.call('commitSchoolRosterImport', {
    previewId: preview.previewId,
    requestId: 'emu_sf1_imp_001',
    expectedFileSha256: preview.fileSha256,
    privacyNoticeAcknowledged: true,
  })).data as {
    committedCount: number;
    newCount: number;
    generatedCredentials: Array<{fullName: string; maskedLrn: string; enrollmentCode: string}>;
  };
  assert.equal(commit.committedCount, 2);
  assert.equal(commit.generatedCredentials.length, 2);

  const replay = (await masterClient.call('commitSchoolRosterImport', {
    previewId: preview.previewId,
    requestId: 'emu_sf1_imp_001',
    expectedFileSha256: preview.fileSha256,
    privacyNoticeAcknowledged: true,
  })).data as {committedCount: number; generatedCredentials: unknown[]};
  assert.equal(replay.committedCount, 2);
  assert.equal(replay.generatedCredentials.length, 0);

  const minorCred = commit.generatedCredentials.find((c) => c.maskedLrn === '0099••••4321');
  assert.ok(minorCred);

  // Minor student registers claiming ageYears: 19 (attempting to bypass guardian auth!)
  const regRes = (await minorClient.call('createStudentRegistration', {
    fullName: 'Juan Santos Dela Cruz',
    birthDate: '2010-05-10',
    ageYears: 19,
    noticeVersion,
    acknowledgmentAccepted: true,
    lrn: '009987654321',
    enrollmentCode: minorCred!.enrollmentCode,
  })).data as {status: string};

  // Authoritative roster birthDate (2010-05-10) forces minor status 'pending_guardian'!
  assert.equal(regRes.status, 'pending_guardian');

  const minorProfile = await store.doc(`studentProfiles/${minorUid}`).get();
  assert.equal(minorProfile.get('schoolApprovalStatus'), 'approved');
  assert.equal(minorProfile.get('schoolVerificationOutcome'), 'verified');
  assert.equal(minorProfile.get('gradeLevel'), 'Grade 10');
  assert.equal(minorProfile.get('birthDate'), '2010-05-10');
  assert.ok(Number(minorProfile.get('ageYearsAtRegistration')) < 18);

  // LRN lock was written for automatic verification
  const lockSnap = await store.doc(`studentLrnLocks/${schoolId}_009987654321`).get();
  assert.equal(lockSnap.exists, true);
  assert.equal(lockSnap.get('studentUid'), minorUid);

  // Second student attempting to reuse the same LRN/code stays pending and
  // receives uniform 'manual_review' (preventing LRN claim enumeration).
  await dupClient.call('createStudentRegistration', {
    fullName: 'Juan Santos Dela Cruz',
    ageYears: 16,
    noticeVersion,
    acknowledgmentAccepted: true,
    lrn: '009987654321',
    enrollmentCode: minorCred!.enrollmentCode,
  });
  const dupProfile = await store.doc(`studentProfiles/${duplicateUid}`).get();
  assert.equal(dupProfile.get('schoolApprovalStatus'), 'pending');
  assert.equal(dupProfile.get('schoolVerificationOutcome'), 'manual_review');

  // Activity Logs shows commit_roster_import with zero secret leakage
  const logs = (await masterClient.call('listSchoolActivityLogs', {
    category: 'management',
    outcome: 'allowed',
  })).data as {entries: Array<{action: string}>; totalMatched: number};
  assert.ok(logs.entries.some((e) => e.action === 'commit_roster_import'));
  assert.equal(JSON.stringify(logs).includes(minorCred!.enrollmentCode), false);
  assert.equal(JSON.stringify(logs).includes('009987654321'), false);
});
