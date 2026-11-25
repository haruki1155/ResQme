import assert from 'node:assert/strict';
import {createHash, generateKeyPairSync, sign} from 'node:crypto';
import {createServer, type Server} from 'node:http';
import test from 'node:test';
import {deleteApp, initializeApp} from 'firebase/app';
import {
  EmailAuthProvider,
  connectAuthEmulator,
  getAuth,
  reauthenticateWithCredential,
  signInWithEmailAndPassword,
  signOut,
} from 'firebase/auth';
import {connectFirestoreEmulator, getFirestore as clientFirestore} from 'firebase/firestore';
import {connectFunctionsEmulator, getFunctions, httpsCallable} from 'firebase/functions';
import {deleteApp as deleteAdmin, initializeApp as initializeAdmin} from 'firebase-admin/app';
import {getAuth as adminAuth} from 'firebase-admin/auth';
import {FieldValue, getFirestore, Timestamp} from 'firebase-admin/firestore';
import {staffTier2Operation, staffTier2SignedMessage} from '../src/staff/staff_tier2_contract';
import {emulatorConfig, projectId} from './emulator_config';

const endpoints = emulatorConfig(process.env);
const adminApp = initializeAdmin({projectId}, 'phase24-qr-replacement-integration');
const store = getFirestore(adminApp);

const masterEmail = 'p24-master@example.test';
const masterUid = 'qa-p24-master';
const studentEmail = 'p24-student@example.test';
const studentUid = 'qa-p24-student';
const password = 'Master-Initial!2026';
const schoolId = 'qa-p24-school';
const deviceId = 'staff_p24_device_0123456789';
const {publicKey, privateKey} = generateKeyPairSync('ec', {namedCurve: 'prime256v1'});
const publicKeyB64 = publicKey.export({type: 'spki', format: 'der'}).toString('base64');

const initialQr = 'resqme:v1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
const initialQrHash = createHash('sha256').update(initialQr, 'utf8').digest('hex');

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

const masterClient = makeClient('p24-master-client');
const studentClient = makeClient('p24-student-client');
let statusServer: Server | null = null;
const statusPort = Number(process.env.RESQME_ATTESTATION_STATUS_PORT || 18299);

test.before(async () => {
  statusServer = createServer((_req, res) => {
    res.writeHead(200, {'Content-Type': 'application/json'});
    res.end(JSON.stringify({entries: {}}));
  });
  await new Promise<void>((resolve, reject) => {
    statusServer!.once('error', reject);
    statusServer!.listen(statusPort, '127.0.0.1', () => resolve());
  });

  await adminAuth(adminApp).createUser({
    uid: masterUid,
    email: masterEmail,
    password,
    emailVerified: true,
  });
  await adminAuth(adminApp).createUser({
    uid: studentUid,
    email: studentEmail,
    password,
    emailVerified: true,
  });

  await store.doc(`staffAccounts/${masterUid}`).set({
    schoolId,
    role: 'admin',
    active: true,
    isMasterAdmin: true,
    mustChangePassword: false,
    requiresEmailVerification: true,
    fullName: 'Phase 2.4 Master Admin',
    createdAt: FieldValue.serverTimestamp(),
  });
  await store.doc(`staffTier2Devices/${masterUid}`).set({
    deviceId,
    status: 'active',
    enrollmentProofVersion: 2,
    keyVersion: 1,
    publicKey: publicKeyB64,
    attestationSerials: ['01', '02'],
    enrolledAt: FieldValue.serverTimestamp(),
  });

  await store.doc(`studentProfiles/${studentUid}`).set({
    schemaVersion: 1,
    status: 'pending_guardian',
    schoolAssignmentStatus: 'assigned',
    schoolId,
    schoolApprovalStatus: 'approved',
    schoolVerificationOutcome: 'roster_matched',
    medicalStatus: 'complete',
    medicalRevision: 1,
    fullName: 'Fictional Student QA',
    lrn: '123456789012',
    gradeLevel: 'Grade 10',
    ageYearsAtRegistration: 16,
    emergencyContacts: {
      primary: {
        fullName: 'Parent Contact QA',
        relationship: 'Mother',
        phoneNumber: '+639171234567',
      },
    },
  });
  await store.doc(`studentMedicalRecords/${studentUid}`).set({
    schemaVersion: 1,
    selfReported: true,
    syntheticOnly: false,
    medicalStatus: 'complete',
    revision: 1,
    primaryContact: {
      fullName: 'Parent Contact QA',
      relationship: 'Mother',
      phoneNumber: '+639171234567',
    },
    conditions: {state: 'none_known', details: null},
    allergies: {state: 'listed', details: 'Peanuts'},
  });
  await store.doc(`studentGuardianAuthorizations/${studentUid}`).set({
    status: 'verified',
    studentUid,
    guardianUid: 'qa-p24-guardian',
    verifiedAt: new Date(),
    method: 'independent_guardian_verification',
  });
  await store.doc(`studentQrCredentials/${studentUid}`).set({
    payload: initialQr,
    verificationStatus: 'active',
    credentialVersion: 1,
    issuedAt: FieldValue.serverTimestamp(),
    activatedAt: FieldValue.serverTimestamp(),
  });
  await store.doc(`studentQrLookups/${initialQrHash}`).set({
    uid: studentUid,
    status: 'active',
    credentialVersion: 1,
    createdAt: FieldValue.serverTimestamp(),
    activatedAt: FieldValue.serverTimestamp(),
  });
});

test.after(async () => {
  await Promise.allSettled([
    signOut(masterClient.auth),
    signOut(studentClient.auth),
    deleteApp(masterClient.app),
    deleteApp(studentClient.app),
    deleteAdmin(adminApp),
  ]);
  if (statusServer) {
    await new Promise<void>((resolve) => statusServer!.close(() => resolve()));
  }
});

test('Phase 2.4 QR replacement lifecycle in Firebase emulators', async () => {
  await signInWithEmailAndPassword(masterClient.auth, masterEmail, password);
  await signInWithEmailAndPassword(studentClient.auth, studentEmail, password);

  // 1. Create an outstanding Tier 2 challenge tied to the original QR before rotation
  const oldTier2Ch = (await masterClient.call('issueStaffTier2Challenge', {
    payload: initialQr,
    deviceId,
    purpose: 'emergency_response',
  })).data as {challengeId: string; nonce: string};

  // 2. Master Admin replaces QR via biometric step-up
  const replaceCh = (await masterClient.call('issueAdminQrReplaceChallenge', {
    studentUid,
    reason: 'compromised',
    deviceId,
  })).data as {challengeId: string; nonce: string};

  const replaceMsg = `resqme:staff-qr-replace:v1\n${masterUid}\n${deviceId}\nadmin_replace_student_qr\n${studentUid}\ncompromised\n${replaceCh.challengeId}\n${replaceCh.nonce}`;
  const replaceSig = sign('sha256', Buffer.from(replaceMsg, 'utf8'), privateKey).toString('base64url');

  const reqId1 = 'emu_qr_rep_0001';
  const replaceRes = (await masterClient.call('replaceSchoolStudentQr', {
    studentUid,
    reason: 'compromised',
    requestId: reqId1,
    challengeId: replaceCh.challengeId,
    method: 'biometric',
    deviceId,
    signature: replaceSig,
  })).data as {credentialVersion: number; verificationStatus: string; reason: string};

  assert.equal(replaceRes.credentialVersion, 2);
  assert.equal(replaceRes.verificationStatus, 'active');
  assert.equal(replaceRes.reason, 'compromised');

  // 3. Old QR fails resolveTier1Qr and outstanding old Tier 2 challenge fails readStudentTier2
  const oldResolved = (await masterClient.call('resolveTier1Qr', {payload: initialQr})).data as {
    active: boolean;
  };
  assert.equal(oldResolved.active, false);

  const oldTier2Sig = sign(
    'sha256',
    Buffer.from(
      staffTier2SignedMessage({
        staffUid: masterUid,
        deviceId,
        operation: staffTier2Operation,
        purpose: 'emergency_response',
        challengeId: oldTier2Ch.challengeId,
        nonce: oldTier2Ch.nonce,
      }),
      'utf8',
    ),
    privateKey,
  ).toString('base64url');

  await assert.rejects(() =>
    masterClient.call('readStudentTier2', {
      challengeId: oldTier2Ch.challengeId,
      deviceId,
      signature: oldTier2Sig,
    }),
  );

  // 4. Student retrieves replacement QR via ensureMyTier1Qr and it works for Tier 1 & Biometric Tier 2
  const studentQr = (await studentClient.call('ensureMyTier1Qr', {})).data as {
    payload: string;
    verificationStatus: string;
  };
  assert.notEqual(studentQr.payload, initialQr);
  assert.equal(studentQr.verificationStatus, 'active');

  const newHash = createHash('sha256').update(studentQr.payload, 'utf8').digest('hex');
  const [oldLookupSnap, newLookupSnap] = await Promise.all([
    store.doc(`studentQrLookups/${initialQrHash}`).get(),
    store.doc(`studentQrLookups/${newHash}`).get(),
  ]);
  assert.equal(oldLookupSnap.get('status'), 'revoked');
  assert.equal(newLookupSnap.get('status'), 'active');
  assert.equal(newLookupSnap.get('uid'), studentUid);

  const newTier2Ch = (await masterClient.call('issueStaffTier2Challenge', {
    payload: studentQr.payload,
    deviceId,
    purpose: 'emergency_response',
  })).data as {challengeId: string; nonce: string};

  const newTier2Sig = sign(
    'sha256',
    Buffer.from(
      staffTier2SignedMessage({
        staffUid: masterUid,
        deviceId,
        operation: staffTier2Operation,
        purpose: 'emergency_response',
        challengeId: newTier2Ch.challengeId,
        nonce: newTier2Ch.nonce,
      }),
      'utf8',
    ),
    privateKey,
  ).toString('base64url');

  const tier2Data = (await masterClient.call('readStudentTier2', {
    challengeId: newTier2Ch.challengeId,
    deviceId,
    signature: newTier2Sig,
  })).data as {allergies?: {details?: string}};
  assert.equal(tier2Data.allergies?.details, 'Peanuts');

  // 5. Master Admin also rotates via password reauth -> v3, and check getSchoolStudentDetails + audit
  const pwdCh = (await masterClient.call('issueAdminQrReplaceChallenge', {
    studentUid,
    reason: 'lost',
    deviceId: null,
  })).data as {challengeId: string; issuedAtSec: number};

  // Ensure auth_time >= issuedAtSec on reauthenticate
  await new Promise((r) => setTimeout(r, 1100));
  await reauthenticateWithCredential(
    masterClient.auth.currentUser!,
    EmailAuthProvider.credential(masterEmail, password),
  );
  await masterClient.auth.currentUser!.getIdToken(true);

  const pwdRes = (await masterClient.call('replaceSchoolStudentQr', {
    studentUid,
    reason: 'lost',
    requestId: 'emu_qr_rep_0002',
    challengeId: pwdCh.challengeId,
    method: 'password',
    deviceId: null,
    signature: null,
  })).data as {credentialVersion: number; reason: string};
  assert.equal(pwdRes.credentialVersion, 3);

  const details = (await masterClient.call('getSchoolStudentDetails', {studentUid})).data as {
    credentialVersion: number;
    maskedLrn: string;
    schoolApprovalStatus: string;
    medicalCompletionStatus: string;
    guardianAuthorizationStatus: string;
  };
  assert.equal(details.credentialVersion, 3);
  assert.equal(details.maskedLrn, '1234••••9012');
  assert.equal(details.schoolApprovalStatus, 'approved');
  assert.equal(details.medicalCompletionStatus, 'complete');
  assert.equal(details.guardianAuthorizationStatus, 'verified');

  const audit1 = await store.doc(`staffManagementAudits/${reqId1}`).get();
  assert.equal(audit1.exists, true);
  assert.equal(audit1.get('action'), 'replace_student_qr');
  assert.equal(audit1.get('credentialVersion'), 2);
  assert.equal(JSON.stringify(audit1.data()).includes(initialQr), false);
  assert.equal(JSON.stringify(audit1.data()).includes(studentQr.payload), false);
  assert.equal(JSON.stringify(audit1.data()).includes('123456789012'), false);
  assert.ok(audit1.get('recordedAt') instanceof Timestamp);
});
