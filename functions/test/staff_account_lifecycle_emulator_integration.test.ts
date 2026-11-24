import assert from 'node:assert/strict';
import {createHash, generateKeyPairSync, randomBytes, sign} from 'node:crypto';
import {createServer, type Server} from 'node:http';
import test from 'node:test';
import {deleteApp, initializeApp} from 'firebase/app';
import {connectAuthEmulator, getAuth, signInWithEmailAndPassword, signOut} from 'firebase/auth';
import {connectFirestoreEmulator, getFirestore as clientFirestore} from 'firebase/firestore';
import {connectFunctionsEmulator, getFunctions, httpsCallable} from 'firebase/functions';
import {deleteApp as deleteAdmin, initializeApp as initializeAdmin} from 'firebase-admin/app';
import {getAuth as adminAuth} from 'firebase-admin/auth';
import {getFirestore} from 'firebase-admin/firestore';
import {staffTier2Operation, staffTier2SignedMessage} from '../src/staff/staff_tier2_contract';
import {emulatorConfig, projectId} from './emulator_config';

const endpoints = emulatorConfig(process.env);
const adminApp = initializeAdmin({projectId}, 'phase21-lifecycle-integration');
const store = getFirestore(adminApp);

const masterEmail = 'p21-master@example.test';
const masterUid = 'qa-p21-master';
const studentUid = 'qa-p21-student';
const password = 'Master-Initial!2026';
const schoolId = 'qa-p21-school';
const deviceId = 'staff_p21_device_0123456789';
const {publicKey, privateKey} = generateKeyPairSync('ec', {namedCurve: 'prime256v1'});
const publicKeyB64 = publicKey.export({type: 'spki', format: 'der'}).toString('base64url');

function makeClient(name: string) {
  const app = initializeApp({projectId, apiKey: 'test'}, name);
  const auth = getAuth(app);
  connectAuthEmulator(auth, `http://${endpoints.auth.host}:${endpoints.auth.port}`, {disableWarnings: true});
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

const masterClient = makeClient('p21-master-client');
const staffClient = makeClient('p21-staff-client');
let statusServer: Server | null = null;
const statusPort = Number(process.env.RESQME_ATTESTATION_STATUS_PORT || 18199);
let qrPayload = '';
let qrHash = '';
let createdStaffUid = '';
let createdLoginId = '';

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
  await store.doc(`staffAccounts/${masterUid}`).set({
    role: 'admin',
    isMasterAdmin: true,
    active: true,
    status: 'active',
    schoolId,
    mustChangePassword: false,
    requiresEmailVerification: true,
    loginEmail: masterEmail,
  });

  qrPayload = `resqme:v1:${randomBytes(32).toString('base64url')}`;
  qrHash = createHash('sha256').update(qrPayload, 'utf8').digest('hex');
  await store.doc(`studentProfiles/${studentUid}`).set({
    schemaVersion: 1,
    status: 'pending_review',
    fullName: 'Fictional P21 Student',
    ageYearsAtRegistration: 20,
    schoolAssignmentStatus: 'assigned',
    schoolId,
    schoolApprovalStatus: 'approved',
    medicalStatus: 'complete',
    medicalRevision: 1,
  });
  await store.doc(`studentMedicalRecords/${studentUid}`).set({
    schemaVersion: 1,
    medicalStatus: 'complete',
    selfReported: true,
    syntheticOnly: false,
    revision: 1,
    conditions: {state: 'listed', details: 'Fictional asthma'},
    allergies: {state: 'none_known', details: null},
    primaryContact: {fullName: 'Fictional Guardian', relationship: 'Parent', phoneNumber: '09170000001'},
  });
  await store.doc(`studentQrCredentials/${studentUid}`).set({payload: qrPayload, verificationStatus: 'active'});
  await store.doc(`studentQrLookups/${qrHash}`).set({uid: studentUid, status: 'active'});

  await signInWithEmailAndPassword(masterClient.auth, masterEmail, password);
});

test.after(async () => {
  await Promise.all([deleteApp(masterClient.app), deleteApp(staffClient.app)]);
  const toDelete = [
    `staffAccounts/${masterUid}`,
    `studentProfiles/${studentUid}`,
    `studentMedicalRecords/${studentUid}`,
    `studentQrCredentials/${studentUid}`,
    `studentQrLookups/${qrHash}`,
  ];
  if (createdStaffUid) {
    toDelete.push(`staffAccounts/${createdStaffUid}`, `staffTier2Devices/${createdStaffUid}`);
  }
  if (createdLoginId) {
    toDelete.push(`staffLoginIds/${createdLoginId.toLowerCase()}`);
  }
  for (const p of toDelete) {
    await store.doc(p).delete().catch(() => undefined);
  }
  for (const col of ['staffTier2Challenges', 'staffEnrollmentChallenges', 'staffManagementAudits', 'tier2AccessAudits']) {
    for (const d of (await store.collection(col).get()).docs) {
      await d.ref.delete().catch(() => undefined);
    }
  }
  for (const u of [masterUid, createdStaffUid].filter(Boolean)) {
    await adminAuth(adminApp).deleteUser(u).catch(() => undefined);
  }
  await deleteAdmin(adminApp);
  if (statusServer) {
    await new Promise<void>((resolve) => statusServer!.close(() => resolve()));
  }
});

test('Phase 2.1 lifecycle: create Authorized, enforce first-login password setup, suspend/reactivate without restoring challenges, and reset password', async () => {
  // 1. Master Admin creates Authorized account
  const created = (
    await masterClient.call('createAuthorizedAccount', {
      fullName: 'Nurse Elena',
      position: 'School Nurse',
    })
  ).data as {uid: string; loginId: string; temporaryPassword: string};
  createdStaffUid = created.uid;
  createdLoginId = created.loginId;
  assert.match(created.loginId, /^AUTH-[A-Z0-9]{8}$/);
  assert.ok(created.temporaryPassword.length >= 16);

  // 2. Authorized user signs in with generated internal email; mustChangePassword blocks Tier 2 enrollment
  const internalEmail = `${created.loginId.toLowerCase()}@staff.resqme.internal`;
  await signInWithEmailAndPassword(staffClient.auth, internalEmail, created.temporaryPassword);
  const access1 = (await staffClient.call('getStaffAccess')).data as {mustChangePassword: boolean; requiresEmailVerification: boolean};
  assert.equal(access1.mustChangePassword, true);
  assert.equal(access1.requiresEmailVerification, false);
  await assert.rejects(() => staffClient.call('issueStaffEnrollmentChallenge', {}));

  // 3. Authorized user completes mandatory password change without email verification
  const newPassword = 'Elena-Personal!2026';
  await staffClient.call('changeMyStaffPassword', {newPassword});
  await signOut(staffClient.auth);
  await signInWithEmailAndPassword(staffClient.auth, internalEmail, newPassword);
  const access2 = (await staffClient.call('getStaffAccess')).data as {mustChangePassword: boolean};
  assert.equal(access2.mustChangePassword, false);

  // 4. Provision device doc and issue a live Tier 2 challenge
  await store.doc(`staffTier2Devices/${createdStaffUid}`).set({
    staffUid: createdStaffUid,
    schoolId,
    deviceId,
    publicKey: publicKeyB64,
    attestationLevel: 'trusted_environment',
    attestationSerials: ['aa11', 'bb22'],
    status: 'active',
    keyVersion: 1,
  });
  const ch = (
    await staffClient.call('issueStaffTier2Challenge', {
      payload: qrPayload,
      deviceId,
      purpose: 'emergency_response',
    })
  ).data as {challengeId: string; nonce: string; purpose: string};
  const msg = staffTier2SignedMessage({
    staffUid: createdStaffUid,
    deviceId,
    operation: staffTier2Operation,
    purpose: ch.purpose,
    challengeId: ch.challengeId,
    nonce: ch.nonce,
  });
  const sig = sign('sha256', Buffer.from(msg, 'utf8'), privateKey).toString('base64url');

  // 5. Master Admin suspends Authorized account -> challenge invalidated & device revoked
  await masterClient.call('setAuthorizedAccountStatus', {
    targetUid: createdStaffUid,
    action: 'suspend',
  });
  await assert.rejects(() =>
    staffClient.call('readStudentTier2', {
      challengeId: ch.challengeId,
      deviceId,
      signature: sig,
    }),
  );

  // 6. Reactivating account does NOT restore previously invalidated challenge or revoked device
  await masterClient.call('setAuthorizedAccountStatus', {
    targetUid: createdStaffUid,
    action: 'reactivate',
  });
  await assert.rejects(() =>
    staffClient.call('readStudentTier2', {
      challengeId: ch.challengeId,
      deviceId,
      signature: sig,
    }),
  );

  // 7. Resetting temporary password forces mustChangePassword back to true and revokes tokens
  const reset = (
    await masterClient.call('resetAuthorizedPassword', {targetUid: createdStaffUid})
  ).data as {temporaryPassword: string};
  assert.ok(reset.temporaryPassword.length >= 16);
  const staffSnap = await store.doc(`staffAccounts/${createdStaffUid}`).get();
  assert.equal(staffSnap.get('mustChangePassword'), true);

  // 8. List returns the school's Authorized account
  const listed = (await masterClient.call('listAuthorizedAccounts', {search: 'elena'})).data as {
    accounts: Array<{uid: string; mustChangePassword: boolean}>;
  };
  assert.equal(listed.accounts.length, 1);
  assert.equal(listed.accounts[0].uid, createdStaffUid);
  assert.equal(listed.accounts[0].mustChangePassword, true);
});
