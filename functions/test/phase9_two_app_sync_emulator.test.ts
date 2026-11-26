import assert from 'node:assert/strict';
import {createHash, generateKeyPairSync, randomBytes, sign} from 'node:crypto';
import {createServer, type Server} from 'node:http';
import test from 'node:test';
import * as XLSX from 'xlsx';
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
import {FieldValue, getFirestore} from 'firebase-admin/firestore';
import {
  studentEnrollmentSignedMessage,
  tier2ApproveTransferOperation,
  tier2PresentQrOperation,
  tier2SignedMessage,
} from '../src/medical/tier2_challenge';
import {noticeVersion} from '../src/registration/registration_contract';
import {staffTier2Operation, staffTier2SignedMessage} from '../src/staff/staff_tier2_contract';
import {emulatorConfig, projectId} from './emulator_config';

/**
 * Phase 9 End-to-End Two-App Synchronization Suite (demo-resqme loopback emulators only).
 * Verifies live state synchronization across Admin Portal and Student App workflows
 * using strictly fictional student, roster, and medical data.
 */
const endpoints = emulatorConfig(process.env);
const adminApp = initializeAdmin({projectId}, 'phase9-two-app-sync');
const store = getFirestore(adminApp);

const schoolId = 'qa-p9-school';
const password = 'Synthetic-Phase9!2026';

const actors = {
  master: {uid: 'qa-p9-master', email: 'p9-master@example.test'},
  nurse: {uid: 'qa-p9-nurse', email: 'p9-nurse@example.test'},
  adultStudent: {uid: 'qa-p9-adult', email: 'p9-adult@example.test'},
  minorStudent: {uid: 'qa-p9-minor', email: 'p9-minor@example.test'},
  manualStudent: {uid: 'qa-p9-manual', email: 'p9-manual@example.test'},
};

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

const masterClient = makeClient('p9-master-client');
const nurseClient = makeClient('p9-nurse-client');
const adultClient = makeClient('p9-adult-client');
const minorClient = makeClient('p9-minor-client');
const manualClient = makeClient('p9-manual-client');
const anonClient = makeClient('p9-anon-client');

const staffDeviceId = 'staff_p9_device_0123456789abcdef';
const staffKeys = generateKeyPairSync('ec', {namedCurve: 'prime256v1'});
const staffPubB64 = staffKeys.publicKey.export({type: 'spki', format: 'der'}).toString('base64url');

const phoneADeviceId = 'student_phoneA_0123456789abcdef';
const phoneAKeys = generateKeyPairSync('ec', {namedCurve: 'prime256v1'});
const phoneAPubB64 = phoneAKeys.publicKey.export({type: 'spki', format: 'der'}).toString('base64url');

const phoneBDeviceId = 'student_phoneB_fedcba9876543210';
const phoneBKeys = generateKeyPairSync('ec', {namedCurve: 'prime256v1'});
const phoneBPubB64 = phoneBKeys.publicKey.export({type: 'spki', format: 'der'}).toString('base64url');

const phoneCDeviceId = 'student_phoneC_1122334455667788';
const phoneCKeys = generateKeyPairSync('ec', {namedCurve: 'prime256v1'});
const phoneCPubB64 = phoneCKeys.publicKey.export({type: 'spki', format: 'der'}).toString('base64url');

let statusServer: Server | null = null;
const statusPort = Number(process.env.RESQME_ATTESTATION_STATUS_PORT || 18199);

function buildSf1Fixture(): {base64: string; sha256: string} {
  const aoa: Array<Array<unknown>> = [
    ['School Form 1 (SF 1) School Register'],
    ['(Fictional Phase 9 Emulator Fixture)'],
    [],
    ['', '', '', 'School ID', schoolId],
    [],
    ['', '', 'School Name', 'Fictional Sync High', '', '', '', '', '', '', '', '', 'School Year', '2026-2027', '', '', '', '', 'Grade Level', 'Grade 12'],
    [],
    ['', 'LRN', 'NAME (Last Name, First Name, Middle Name)', '', '', '', 'Sex (M/F)', 'BIRTH DATE (mm/dd/ yyyy)', 'AGE', '', '', '', '', '', '', '', '', '', '', 'PARENTS', '', '', '', 'GUARDIAN (If not Parent)', '', 'Contact Number of Parent or Guardian'],
    ['', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', "Father's Name", '', "Mother's Maiden Name", '', 'Name', 'Relation-ship', ''],
    ['', '009888111222', 'Reyes, Mara Cruz', '', '', '', 'F', '03/10/2005', '', '', '', '', '', '', '', '', '', '', '', 'Reyes, Jose', '', 'Cruz, Elena', '', '', '', '09179876543'],
    ['', '009888333444', 'Dela Cruz, Juan Santos', '', '', '', 'M', '05/10/2010', '', '', '', '', '', '', '', '', '', '', '', 'Dela Cruz, Pedro', '', 'Santos, Maria', '', 'Maria Dela Cruz', 'Mother', '09171234567'],
    ['List and Code of Indicators under REMARKS', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 'Prepared by:'],
  ];
  const ws = XLSX.utils.aoa_to_sheet(aoa);
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, ws, 'School Form 1 (SF1)');
  const buf = XLSX.write(wb, {type: 'buffer', bookType: 'xlsx'}) as Buffer;
  return {
    base64: buf.toString('base64'),
    sha256: createHash('sha256').update(buf).digest('hex'),
  };
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
    await adminAuth(adminApp).createUser({
      uid: a.uid,
      email: a.email,
      password,
      emailVerified: true,
    });
  }

  await store.doc(`staffAccounts/${actors.master.uid}`).set({
    schoolId,
    role: 'admin',
    active: true,
    isMasterAdmin: true,
    mustChangePassword: false,
    requiresEmailVerification: true,
    fullName: 'Principal Maria Santos',
    createdAt: FieldValue.serverTimestamp(),
  });
  await store.doc(`staffAccounts/${actors.nurse.uid}`).set({
    schoolId,
    role: 'authorized',
    active: true,
    isMasterAdmin: false,
    mustChangePassword: false,
    fullName: 'Nurse Roberto Gomez',
    createdAt: FieldValue.serverTimestamp(),
  });
  await store.doc(`staffTier2Devices/${actors.nurse.uid}`).set({
    staffUid: actors.nurse.uid,
    schoolId,
    deviceId: staffDeviceId,
    publicKey: staffPubB64,
    attestationSerials: ['aa11bb22', 'cc33dd44'],
    enrollmentProofVersion: 2,
    status: 'active',
    keyVersion: 1,
  });
});

test.after(async () => {
  await Promise.allSettled([
    signOut(masterClient.auth),
    signOut(nurseClient.auth),
    signOut(adultClient.auth),
    signOut(minorClient.auth),
    signOut(manualClient.auth),
    signOut(anonClient.auth),
    deleteApp(masterClient.app),
    deleteApp(nurseClient.app),
    deleteApp(adultClient.app),
    deleteApp(minorClient.app),
    deleteApp(manualClient.app),
    deleteApp(anonClient.app),
    deleteAdmin(adminApp),
  ]);
  if (statusServer) {
    await new Promise<void>((resolve) => statusServer!.close(() => resolve()));
    statusServer = null;
  }
});

test('Phase 9: End-to-end two-app synchronization across SF1 import, auto/manual registration, Login QR, personal-device Tier 2, QR replacement, disable/enable, and Manila Activity Logs', async () => {
  await signInWithEmailAndPassword(masterClient.auth, actors.master.email, password);
  await signInWithEmailAndPassword(nurseClient.auth, actors.nurse.email, password);
  await signInWithEmailAndPassword(adultClient.auth, actors.adultStudent.email, password);
  await signInWithEmailAndPassword(minorClient.auth, actors.minorStudent.email, password);
  await signInWithEmailAndPassword(manualClient.auth, actors.manualStudent.email, password);

  // 1. SF1 Import -> Roster + Enrollment Credentials -> Dashboard Counts
  const sf1 = buildSf1Fixture();
  const preview = (await masterClient.call('previewSchoolRosterImport', {
    fileName: 'phase9_sf1.xlsx',
    fileBase64: sf1.base64,
    confirmedGradeLevel: null,
  })).data as {
    previewId: string;
    fileSha256: string;
    summary: {newCount: number};
  };
  assert.equal(preview.summary.newCount, 2);
  assert.equal(preview.fileSha256, sf1.sha256);

  const commit = (await masterClient.call('commitSchoolRosterImport', {
    previewId: preview.previewId,
    requestId: 'p9_sf1_commit_001',
    expectedFileSha256: sf1.sha256,
    privacyNoticeAcknowledged: true,
  })).data as {
    committedCount: number;
    generatedCredentials: Array<{fullName: string; maskedLrn: string; enrollmentCode: string}>;
  };
  assert.equal(commit.committedCount, 2);
  const adultRosterCred = commit.generatedCredentials.find((c) => c.maskedLrn === '0098••••1222');
  const minorRosterCred = commit.generatedCredentials.find((c) => c.maskedLrn === '0098••••3444');
  assert.ok(adultRosterCred);
  assert.ok(minorRosterCred);

  const statsAfterImport = (await masterClient.call('getPortalDashboardStats', {})).data as {
    importedRosterCount: number;
    registeredStudentsCount: number;
    verifiedStudentsCount: number;
  };
  assert.equal(statsAfterImport.importedRosterCount, 2);
  assert.equal(statsAfterImport.registeredStudentsCount, 0);

  // 2. Matching Student Registration -> Auto-Verified (Adult active-ready, Minor pending_guardian)
  const adultReg = (await adultClient.call('createStudentRegistration', {
    fullName: 'Mara Cruz Reyes',
    birthDate: '2005-03-10',
    ageYears: 21,
    noticeVersion,
    acknowledgmentAccepted: true,
    lrn: '009888111222',
    enrollmentCode: adultRosterCred!.enrollmentCode,
  })).data as {status: string};
  assert.equal(adultReg.status, 'pending_review');

  const minorReg = (await minorClient.call('createStudentRegistration', {
    fullName: 'Juan Santos Dela Cruz',
    birthDate: '2010-05-10',
    ageYears: 19, // Attempted adult claim overridden by authoritative roster birthDate!
    noticeVersion,
    acknowledgmentAccepted: true,
    lrn: '009888333444',
    enrollmentCode: minorRosterCred!.enrollmentCode,
  })).data as {status: string};
  assert.equal(minorReg.status, 'pending_guardian');

  // Portal Roster immediately reflects Verified state on both claimed roster entries
  const rosterPage = (await masterClient.call('listSchoolRoster', {
    registrationFilter: 'verified',
  })).data as {entries: Array<{displayName: string; registrationState: string}>; totalMatched: number};
  assert.equal(rosterPage.totalMatched, 2);

  // 3. Unmatched Student Registration -> Pending Manual Review in Active Students
  await manualClient.call('createStudentRegistration', {
    fullName: 'Carlos Mendoza Ramos',
    birthDate: '2004-11-20',
    ageYears: 21,
    noticeVersion,
    acknowledgmentAccepted: true,
    lrn: '009555666777',
  });
  // Assign school pending approval (as school-routed manual review candidate)
  await store.doc(`studentProfiles/${actors.manualStudent.uid}`).set(
    {
      schoolAssignmentStatus: 'assigned',
      schoolId,
      schoolApprovalStatus: 'pending',
      schoolVerificationOutcome: 'manual_review',
      gradeLevel: 'Grade 12',
    },
    {merge: true},
  );

  const pendingPage = (await masterClient.call('listSchoolStudents', {
    statusFilter: 'registered',
  })).data as {students: Array<{uid: string; fullName: string}>; totalMatched: number};
  assert.equal(pendingPage.totalMatched, 1);
  assert.equal(pendingPage.students[0].uid, actors.manualStudent.uid);

  // 4. Manual Master Admin Verification -> Transitions to Verified + Locks LRN
  const manualVerify = (await masterClient.call('verifySchoolStudentAccount', {
    studentUid: actors.manualStudent.uid,
    requestId: 'p9_manual_verify_001',
  })).data as {schoolApprovalStatus: string; verificationMethod: string};
  assert.equal(manualVerify.schoolApprovalStatus, 'approved');
  assert.equal(manualVerify.verificationMethod, 'manual_admin');

  const verifiedPage = (await masterClient.call('listSchoolStudents', {
    statusFilter: 'verified',
  })).data as {totalMatched: number};
  assert.equal(verifiedPage.totalMatched, 3);

  // 5. Student Medical Completion & Update -> Syncs with Tier 1 QR & Revision
  const med1 = (await adultClient.call('completeMyMedicalRecord', {
    expectedRevision: 0,
    requestId: 'p9_med_req_001',
    selfReportConfirmed: true,
    conditions: {state: 'listed', details: 'Fictional mild asthma'},
    allergies: {state: 'listed', details: 'Fictional penicillin allergy'},
    primaryContact: {
      fullName: 'Elena Cruz Reyes',
      relationship: 'Mother',
      phoneNumber: '09179876543',
    },
  })).data as {revision: number; medicalStatus: string};
  assert.equal(med1.revision, 1);

  const qr1 = (await adultClient.call('ensureMyTier1Qr', {})).data as {
    payload: string;
    verificationStatus: string;
  };
  assert.equal(qr1.verificationStatus, 'active');
  assert.equal(((await anonClient.call('resolveTier1Qr', {payload: qr1.payload})).data as {active: boolean}).active, true);

  // Update medical record -> revision increments to 2
  const med2 = (await adultClient.call('completeMyMedicalRecord', {
    expectedRevision: 1,
    requestId: 'p9_med_req_002',
    selfReportConfirmed: true,
    conditions: {state: 'listed', details: 'Fictional mild asthma (inhaler carried)'},
    allergies: {state: 'listed', details: 'Fictional penicillin allergy'},
    primaryContact: {
      fullName: 'Elena Cruz Reyes',
      relationship: 'Mother',
      phoneNumber: '09179876543',
    },
  })).data as {revision: number};
  assert.equal(med2.revision, 2);

  // 6. Student Login QR -> Account Identification + Password Gate + Rotation
  const loginQr1 = (await adultClient.call('ensureMyStudentLoginQr', {})).data as {
    payload: string;
    status: string;
  };
  assert.equal(loginQr1.status, 'active');
  assert.ok(loginQr1.payload.startsWith('resqme:login:v1:'));

  // Scanning emergency QR in Login QR resolver is rejected
  await assert.rejects(() => anonClient.call('resolveStudentLoginQr', {payload: qr1.payload}));

  const resolvedLogin = (await anonClient.call('resolveStudentLoginQr', {
    payload: loginQr1.payload,
  })).data as {email: string; maskedEmail: string};
  assert.equal(resolvedLogin.email, actors.adultStudent.email);
  assert.ok(resolvedLogin.maskedEmail.includes('•'));
  // Complete password authentication using resolved email
  await signInWithEmailAndPassword(anonClient.auth, resolvedLogin.email, password);
  await signOut(anonClient.auth);

  const loginQr2 = (await adultClient.call('replaceMyStudentLoginQr', {})).data as {payload: string};
  assert.notEqual(loginQr2.payload, loginQr1.payload);
  await assert.rejects(() => anonClient.call('resolveStudentLoginQr', {payload: loginQr1.payload}));

  // 7. Personal-Device Biometric Enrollment, Overwrite Block, Transfer, Tier 2 Token & Staff Scan
  const enrollChalA = (await adultClient.call('issueStudentEnrollmentChallenge', {})).data as {
    challengeId: string;
    nonce: string;
  };
  const enrollSigA = sign(
    'sha256',
    Buffer.from(
      studentEnrollmentSignedMessage({
        uid: actors.adultStudent.uid,
        deviceId: phoneADeviceId,
        challengeId: enrollChalA.challengeId,
        nonce: enrollChalA.nonce,
      }),
      'utf8',
    ),
    phoneAKeys.privateKey,
  ).toString('base64url');

  await adultClient.call('enrollTier2Device', {
    challengeId: enrollChalA.challengeId,
    deviceId: phoneADeviceId,
    publicKey: phoneAPubB64,
    signature: enrollSigA,
  });

  // Phone B reports untrusted status and is blocked from password-only overwrite
  const phoneBStatus = (await adultClient.call('getMyTrustedDeviceStatus', {
    deviceId: phoneBDeviceId,
  })).data as {hasActiveTrustedDevice: boolean; isCurrentDeviceTrusted: boolean};
  assert.equal(phoneBStatus.hasActiveTrustedDevice, true);
  assert.equal(phoneBStatus.isCurrentDeviceTrusted, false);

  const enrollChalBBlocked = (await adultClient.call('issueStudentEnrollmentChallenge', {})).data as {
    challengeId: string;
    nonce: string;
  };
  const enrollSigBBlocked = sign(
    'sha256',
    Buffer.from(
      studentEnrollmentSignedMessage({
        uid: actors.adultStudent.uid,
        deviceId: phoneBDeviceId,
        challengeId: enrollChalBBlocked.challengeId,
        nonce: enrollChalBBlocked.nonce,
      }),
      'utf8',
    ),
    phoneBKeys.privateKey,
  ).toString('base64url');
  await assert.rejects(() =>
    adultClient.call('enrollTier2Device', {
      challengeId: enrollChalBBlocked.challengeId,
      deviceId: phoneBDeviceId,
      publicKey: phoneBPubB64,
      signature: enrollSigBBlocked,
    }),
  );

  // Phone A approves device transfer via hardware-biometric challenge
  const xferChal = (await adultClient.call('issueTier2Challenge', {
    deviceId: phoneADeviceId,
    operation: tier2ApproveTransferOperation,
  })).data as {challengeId: string; nonce: string};
  const xferSig = sign(
    'sha256',
    Buffer.from(
      tier2SignedMessage({
        uid: actors.adultStudent.uid,
        deviceId: phoneADeviceId,
        operation: tier2ApproveTransferOperation,
        challengeId: xferChal.challengeId,
        nonce: xferChal.nonce,
      }),
      'utf8',
    ),
    phoneAKeys.privateKey,
  ).toString('base64url');
  const xferGrant = (await adultClient.call('issueTrustedDeviceTransferCode', {
    challengeId: xferChal.challengeId,
    deviceId: phoneADeviceId,
    signature: xferSig,
  })).data as {transferCode: string};
  assert.ok(xferGrant.transferCode.startsWith('TDX-'));

  // Phone B enrolls legitimately with transferCode
  const enrollChalB = (await adultClient.call('issueStudentEnrollmentChallenge', {})).data as {
    challengeId: string;
    nonce: string;
  };
  const enrollSigB = sign(
    'sha256',
    Buffer.from(
      studentEnrollmentSignedMessage({
        uid: actors.adultStudent.uid,
        deviceId: phoneBDeviceId,
        challengeId: enrollChalB.challengeId,
        nonce: enrollChalB.nonce,
      }),
      'utf8',
    ),
    phoneBKeys.privateKey,
  ).toString('base64url');
  await adultClient.call('enrollTier2Device', {
    challengeId: enrollChalB.challengeId,
    deviceId: phoneBDeviceId,
    publicKey: phoneBPubB64,
    signature: enrollSigB,
    transferCode: xferGrant.transferCode,
  });

  // Phone B mints 90-second single-use Protected Tier 2 QR token
  const presChal = (await adultClient.call('issueTier2Challenge', {
    deviceId: phoneBDeviceId,
    operation: tier2PresentQrOperation,
  })).data as {challengeId: string; nonce: string};
  const presSig = sign(
    'sha256',
    Buffer.from(
      tier2SignedMessage({
        uid: actors.adultStudent.uid,
        deviceId: phoneBDeviceId,
        operation: tier2PresentQrOperation,
        challengeId: presChal.challengeId,
        nonce: presChal.nonce,
      }),
      'utf8',
    ),
    phoneBKeys.privateKey,
  ).toString('base64url');
  const tier2Token = (await adultClient.call('issueMyTier2PresentationToken', {
    challengeId: presChal.challengeId,
    deviceId: phoneBDeviceId,
    signature: presSig,
  })).data as {payload: string};
  assert.ok(tier2Token.payload.startsWith('resqme:tier2:v1:'));

  // Authorized Nurse scans single-use Tier 2 presentation QR with staff biometrics
  const staffChal1 = (await nurseClient.call('issueStaffTier2Challenge', {
    payload: tier2Token.payload,
    deviceId: staffDeviceId,
    purpose: 'clinic_triage',
  })).data as {challengeId: string; nonce: string};
  const staffSig1 = sign(
    'sha256',
    Buffer.from(
      staffTier2SignedMessage({
        staffUid: actors.nurse.uid,
        deviceId: staffDeviceId,
        operation: staffTier2Operation,
        purpose: 'clinic_triage',
        challengeId: staffChal1.challengeId,
        nonce: staffChal1.nonce,
      }),
      'utf8',
    ),
    staffKeys.privateKey,
  ).toString('base64url');
  const tier2Read = (await nurseClient.call('readStudentTier2', {
    challengeId: staffChal1.challengeId,
    deviceId: staffDeviceId,
    signature: staffSig1,
  })).data as {conditions: {details: string}};
  assert.equal(tier2Read.conditions.details, 'Fictional mild asthma (inhaler carried)');

  // Single-use presentation token is immediately consumed and cannot be scanned again
  await assert.rejects(() =>
    nurseClient.call('issueStaffTier2Challenge', {
      payload: tier2Token.payload,
      deviceId: staffDeviceId,
      purpose: 'clinic_triage',
    }),
  );

  // 8. Lost QR Replacement -> Old Permanent QR Immediately Rejected, New QR Active
  const replaceChal = (await masterClient.call('issueAdminQrReplaceChallenge', {
    studentUid: actors.adultStudent.uid,
    reason: 'lost',
    deviceId: null,
  })).data as {challengeId: string};
  await new Promise((r) => setTimeout(r, 1100));
  await reauthenticateWithCredential(
    masterClient.auth.currentUser!,
    EmailAuthProvider.credential(actors.master.email, password),
  );
  await masterClient.auth.currentUser!.getIdToken(true);
  const replaced = (await masterClient.call('replaceSchoolStudentQr', {
    studentUid: actors.adultStudent.uid,
    reason: 'lost',
    requestId: 'p9_qr_replace_001',
    challengeId: replaceChal.challengeId,
    method: 'password',
    deviceId: null,
    signature: null,
  })).data as {credentialVersion: number; verificationStatus: string};
  assert.equal(replaced.verificationStatus, 'active');
  assert.equal(replaced.credentialVersion, 2);

  assert.equal(((await anonClient.call('resolveTier1Qr', {payload: qr1.payload})).data as {active: boolean}).active, false);
  const qr2 = (await adultClient.call('ensureMyTier1Qr', {})).data as {payload: string};
  assert.notEqual(qr2.payload, qr1.payload);
  assert.equal(((await anonClient.call('resolveTier1Qr', {payload: qr2.payload})).data as {active: boolean}).active, true);

  // 9. Student Disable / Enable & Trusted-Device School Recovery
  await masterClient.call('setStudentAccountStatus', {
    studentUid: actors.adultStudent.uid,
    action: 'disable',
  });
  // Disabled student's emergency QR & Login QR & Auth are disabled/revoked
  assert.equal(((await anonClient.call('resolveTier1Qr', {payload: qr2.payload})).data as {active: boolean}).active, false);
  await assert.rejects(() => anonClient.call('resolveStudentLoginQr', {payload: loginQr2.payload}));
  const disabledAuthUser = await adminAuth(adminApp).getUser(actors.adultStudent.uid);
  assert.equal(disabledAuthUser.disabled, true);

  // Re-enable student -> Auth enabled, previously revoked Login QR stays revoked, active Tier 1 QR works again
  await masterClient.call('setStudentAccountStatus', {
    studentUid: actors.adultStudent.uid,
    action: 'enable',
  });
  await signInWithEmailAndPassword(adultClient.auth, actors.adultStudent.email, password);
  await assert.rejects(() => anonClient.call('resolveStudentLoginQr', {payload: loginQr2.payload}));
  assert.equal(((await anonClient.call('resolveTier1Qr', {payload: qr2.payload})).data as {active: boolean}).active, true);

  // Re-enroll Phone B, then verify Master Admin resetStudentTrustedDevice allows Phone C without transferCode
  const reEnrollChalB = (await adultClient.call('issueStudentEnrollmentChallenge', {})).data as {
    challengeId: string;
    nonce: string;
  };
  const reEnrollSigB = sign(
    'sha256',
    Buffer.from(
      studentEnrollmentSignedMessage({
        uid: actors.adultStudent.uid,
        deviceId: phoneBDeviceId,
        challengeId: reEnrollChalB.challengeId,
        nonce: reEnrollChalB.nonce,
      }),
      'utf8',
    ),
    phoneBKeys.privateKey,
  ).toString('base64url');
  await adultClient.call('enrollTier2Device', {
    challengeId: reEnrollChalB.challengeId,
    deviceId: phoneBDeviceId,
    publicKey: phoneBPubB64,
    signature: reEnrollSigB,
  });

  await masterClient.call('resetStudentTrustedDevice', {
    studentUid: actors.adultStudent.uid,
    reason: 'lost_personal_phone',
  });

  const enrollChalC = (await adultClient.call('issueStudentEnrollmentChallenge', {})).data as {
    challengeId: string;
    nonce: string;
  };
  const enrollSigC = sign(
    'sha256',
    Buffer.from(
      studentEnrollmentSignedMessage({
        uid: actors.adultStudent.uid,
        deviceId: phoneCDeviceId,
        challengeId: enrollChalC.challengeId,
        nonce: enrollChalC.nonce,
      }),
      'utf8',
    ),
    phoneCKeys.privateKey,
  ).toString('base64url');
  await adultClient.call('enrollTier2Device', {
    challengeId: enrollChalC.challengeId,
    deviceId: phoneCDeviceId,
    publicKey: phoneCPubB64,
    signature: enrollSigC,
  });

  // 10. Activity Logs -> Chronological Asia/Manila Date Grouping, Actor Display Names, & Zero Secret/Medical Leakage
  const todayManila = new Date(Date.now() + 8 * 3600_000).toISOString().slice(0, 10);
  const allLogs = (await masterClient.call('listSchoolActivityLogs', {
    category: 'all',
    outcome: 'all',
    startDate: todayManila,
    endDate: todayManila,
    limit: 50,
  })).data as {
    entries: Array<{
      action: string;
      actorDisplayName: string | null;
      manilaDate: string;
      manilaTimeLabel: string;
    }>;
    totalMatched: number;
  };

  const recordedActions = new Set(allLogs.entries.map((e) => e.action));
  assert.ok(recordedActions.has('commit_roster_import'));
  assert.ok(recordedActions.has('verify_student_account'));
  assert.ok(recordedActions.has('replace_student_qr'));
  assert.ok(recordedActions.has('disable_student_account'));
  assert.ok(recordedActions.has('enable_student_account'));
  assert.ok(recordedActions.has('reset_student_trusted_device'));
  assert.ok(recordedActions.has('tier2_emergency_read'));

  assert.ok(allLogs.entries.some((e) => e.actorDisplayName === 'Principal Maria Santos'));
  assert.ok(allLogs.entries.some((e) => e.actorDisplayName === 'Nurse Roberto Gomez'));
  assert.ok(allLogs.entries.every((e) => e.manilaDate === todayManila));
  assert.ok(allLogs.entries.every((e) => e.manilaTimeLabel.includes('PHT')));

  const serializedLogs = JSON.stringify(allLogs);
  assert.equal(serializedLogs.includes('009888111222'), false);
  assert.equal(serializedLogs.includes('009888333444'), false);
  assert.equal(serializedLogs.includes(adultRosterCred!.enrollmentCode), false);
  assert.equal(serializedLogs.includes('asthma'), false);
  assert.equal(serializedLogs.includes('penicillin'), false);
  assert.equal(serializedLogs.includes(qr2.payload), false);
});
