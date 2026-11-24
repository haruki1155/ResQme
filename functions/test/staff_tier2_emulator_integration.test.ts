import assert from 'node:assert/strict';
import {createHash, generateKeyPairSync, randomBytes, sign} from 'node:crypto';
import {createServer, type Server} from 'node:http';
import test from 'node:test';
import {deleteApp, initializeApp} from 'firebase/app';
import {connectAuthEmulator, getAuth, signInWithEmailAndPassword} from 'firebase/auth';
import {connectFirestoreEmulator, doc, getDoc, getFirestore as clientFirestore} from 'firebase/firestore';
import {connectFunctionsEmulator, getFunctions, httpsCallable} from 'firebase/functions';
import {deleteApp as deleteAdmin, initializeApp as initializeAdmin} from 'firebase-admin/app';
import {getAuth as adminAuth} from 'firebase-admin/auth';
import {getFirestore} from 'firebase-admin/firestore';
import {staffTier2Operation, staffTier2SignedMessage} from '../src/staff/staff_tier2_contract';
import {emulatorConfig, projectId} from './emulator_config';

/**
 * Isolated Phase 1.7 Emulator Integration Suite (24-export package, demo-resqme only).
 * Requires loopback-only Auth, Firestore, and Functions emulators with an approved isolated profile.
 * Never runs against hosted projects or real student records.
 */
const endpoints = emulatorConfig(process.env);
const adminApp = initializeAdmin({projectId}, 'phase1-staff-tier2-integration');
const store = getFirestore(adminApp);

const actors = {
  student: {uid: 'qa-p1-student', email: 'p1-student@example.test'},
  staffSame: {uid: 'qa-p1-staff-same', email: 'p1-staff-same@example.test'},
  staffOther: {uid: 'qa-p1-staff-other', email: 'p1-staff-other@example.test'},
};
const password = 'Synthetic-Local-123';
const deviceId = 'staff_emu_device_0123456789';
const schoolId = 'synthetic-pilot';
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
    fs,
    call: (fn: string, data: unknown) => httpsCallable(fns, fn, {timeout: 10000})(data),
  };
}

const clients = {
  student: makeClient('p1-student-client'),
  staffSame: makeClient('p1-staff-same-client'),
  staffOther: makeClient('p1-staff-other-client'),
};
const qrPayloads: string[] = [];
let statusServer: Server | null = null;
const statusPort = Number(process.env.RESQME_ATTESTATION_STATUS_PORT || 18199);

async function deleteOwnedTree(ref: FirebaseFirestore.DocumentReference) {
  for (const sub of await ref.listCollections()) {
    for (const d of (await sub.get()).docs) await deleteOwnedTree(d.ref);
  }
  await ref.delete();
}

function signStaffChallenge(c: {challengeId: string; nonce: string; purpose: string}) {
  const msg = staffTier2SignedMessage({
    staffUid: actors.staffSame.uid,
    deviceId,
    operation: staffTier2Operation,
    purpose: c.purpose,
    challengeId: c.challengeId,
    nonce: c.nonce,
  });
  return sign('sha256', Buffer.from(msg, 'utf8'), privateKey).toString('base64url');
}

test.before(async () => {
  statusServer = createServer((_req, res) => {
    res.writeHead(200, {'Content-Type': 'application/json'});
    res.end(JSON.stringify({entries: {}}));
  });
  await new Promise<void>((resolve, reject) => {
    statusServer!.once('error', reject);
    statusServer!.listen(statusPort, '127.0.0.1', () => resolve());
  });
  for (const a of Object.values(actors)) {
    await adminAuth(adminApp).createUser({...a, password});
  }
  await signInWithEmailAndPassword(clients.student.auth, actors.student.email, password);
  await signInWithEmailAndPassword(clients.staffSame.auth, actors.staffSame.email, password);
  await signInWithEmailAndPassword(clients.staffOther.auth, actors.staffOther.email, password);

  const payload = `resqme:v1:${randomBytes(32).toString('base64url')}`;
  qrPayloads.push(payload);
  const qrHash = createHash('sha256').update(payload, 'utf8').digest('hex');

  await store.doc(`studentProfiles/${actors.student.uid}`).set({
    schemaVersion: 1,
    status: 'pending_review',
    fullName: 'Fictional Adult Student',
    ageYearsAtRegistration: 20,
    schoolAssignmentStatus: 'assigned',
    schoolId,
    schoolApprovalStatus: 'approved',
    medicalStatus: 'complete',
    medicalRevision: 1,
  });
  await store.doc(`studentMedicalRecords/${actors.student.uid}`).set({
    schemaVersion: 1,
    medicalStatus: 'complete',
    selfReported: true,
    syntheticOnly: false,
    revision: 1,
    conditions: {state: 'listed', details: 'Fictional asthma'},
    allergies: {state: 'none_known', details: null},
    primaryContact: {fullName: 'Fictional Guardian', relationship: 'Parent', phoneNumber: '09170000001'},
  });
  await store.doc(`studentQrCredentials/${actors.student.uid}`).set({
    payload,
    verificationStatus: 'active',
  });
  await store.doc(`studentQrLookups/${qrHash}`).set({
    uid: actors.student.uid,
    status: 'active',
  });
  await store.doc(`staffAccounts/${actors.staffSame.uid}`).set({
    role: 'authorized',
    active: true,
    schoolId,
  });
  await store.doc(`staffAccounts/${actors.staffOther.uid}`).set({
    role: 'authorized',
    active: true,
    schoolId: 'other-school',
  });
  await store.doc(`staffTier2Devices/${actors.staffSame.uid}`).set({
    staffUid: actors.staffSame.uid,
    schoolId,
    deviceId,
    publicKey: publicKeyB64,
    attestationSerials: ['a1b2c3d4', 'deadbeef'],
    status: 'active',
    keyVersion: 1,
  });
});

test.after(async () => {
  for (const a of Object.values(actors)) {
    await deleteOwnedTree(store.doc(`studentProfiles/${a.uid}`));
    await deleteOwnedTree(store.doc(`studentMedicalRecords/${a.uid}`));
    await store.doc(`studentQrCredentials/${a.uid}`).delete();
    await store.doc(`staffAccounts/${a.uid}`).delete();
    await store.doc(`staffTier2Devices/${a.uid}`).delete();
    try {
      await adminAuth(adminApp).deleteUser(a.uid);
    } catch (err) {
      if ((err as {code?: string}).code !== 'auth/user-not-found') throw err;
    }
  }
  for (const p of qrPayloads) {
    await store.doc(`studentQrLookups/${createHash('sha256').update(p, 'utf8').digest('hex')}`).delete();
  }
  for (const col of ['staffTier2Challenges', 'tier2AccessAudits']) {
    const snap = await store.collection(col).get();
    for (const d of snap.docs) await d.ref.delete();
  }
  for (const c of Object.values(clients)) await deleteApp(c.app);
  await deleteAdmin(adminApp);
  if (statusServer) {
    await new Promise<void>((resolve) => statusServer!.close(() => resolve()));
    statusServer = null;
  }
});

test('direct Firestore medical reads are denied for both student owner and staff', async () => {
  await assert.rejects(() => getDoc(doc(clients.student.fs, 'studentMedicalRecords', actors.student.uid)));
  await assert.rejects(() => getDoc(doc(clients.staffSame.fs, 'studentMedicalRecords', actors.student.uid)));
});

test('cross-school staff is denied Tier 2 challenge issuance', async () => {
  await assert.rejects(
    () => clients.staffOther.call('issueStaffTier2Challenge', {
      payload: qrPayloads[0],
      deviceId,
      purpose: 'emergency_response',
    }),
    {code: 'functions/permission-denied'},
  );
});

test('concurrent consumption of a single Tier 2 challenge allows exactly one read and one allowed audit', async () => {
  const issued = (await clients.staffSame.call('issueStaffTier2Challenge', {
    payload: qrPayloads[0],
    deviceId,
    purpose: 'emergency_response',
  })).data as {challengeId: string; nonce: string; purpose: string};

  const signature = signStaffChallenge(issued);
  const settled = await Promise.allSettled([
    clients.staffSame.call('readStudentTier2', {challengeId: issued.challengeId, deviceId, signature}),
    clients.staffSame.call('readStudentTier2', {challengeId: issued.challengeId, deviceId, signature}),
  ]);
  assert.equal(settled.filter((r) => r.status === 'fulfilled').length, 1);
  assert.equal(settled.filter((r) => r.status === 'rejected').length, 1);

  const audits = await store.collection('tier2AccessAudits').where('outcome', '==', 'allowed').get();
  assert.equal(audits.size, 1);
  const audit = audits.docs[0].data();
  assert.equal(audit.actorUid, actors.staffSame.uid);
  assert.equal(audit.targetUid, actors.student.uid);
  assert.equal('conditions' in audit, false);
});

test('QR replacement during an outstanding challenge denies read', async () => {
  const issued = (await clients.staffSame.call('issueStaffTier2Challenge', {
    payload: qrPayloads[0],
    deviceId,
    purpose: 'clinic_triage',
  })).data as {challengeId: string; nonce: string; purpose: string};

  const oldHash = createHash('sha256').update(qrPayloads[0], 'utf8').digest('hex');
  await store.doc(`studentQrLookups/${oldHash}`).update({status: 'revoked'});
  const signature = signStaffChallenge(issued);
  await assert.rejects(
    () => clients.staffSame.call('readStudentTier2', {challengeId: issued.challengeId, deviceId, signature}),
    {code: 'functions/permission-denied'},
  );
  await store.doc(`studentQrLookups/${oldHash}`).update({status: 'active'});
});

test('staff suspension and device revocation deny outstanding challenges immediately', async () => {
  const issued = (await clients.staffSame.call('issueStaffTier2Challenge', {
    payload: qrPayloads[0],
    deviceId,
    purpose: 'incident_assistance',
  })).data as {challengeId: string; nonce: string; purpose: string};

  await store.doc(`staffAccounts/${actors.staffSame.uid}`).update({active: false});
  const signature = signStaffChallenge(issued);
  await assert.rejects(
    () => clients.staffSame.call('readStudentTier2', {challengeId: issued.challengeId, deviceId, signature}),
    {code: 'functions/permission-denied'},
  );

  await store.doc(`staffAccounts/${actors.staffSame.uid}`).update({active: true});
  await store.doc(`staffTier2Devices/${actors.staffSame.uid}`).update({status: 'revoked'});
  await assert.rejects(
    () => clients.staffSame.call('readStudentTier2', {challengeId: issued.challengeId, deviceId, signature}),
    {code: 'functions/permission-denied'},
  );
});
