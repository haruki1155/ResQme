import assert from 'node:assert/strict';
import test from 'node:test';
import {evaluateStudentEligibility} from '../src/qr/qr_eligibility';
import {hashQrPayload} from '../src/qr/resolve_tier1_qr';
import {
  claimMyRosterVerification,
  createStudentRegistration,
  registrationDeps,
} from '../src/registration/create_student_registration';
import {noticeVersion, validateRegistration} from '../src/registration/registration_contract';
import {
  evaluateRosterClaim,
  matchingRosterSchool,
  normalizeRosterName,
  rosterCodeDigest,
  rosterLookupId,
} from '../src/school/roster_contract';
import {staffManagementDeps} from '../src/staff/staff_account_management';
import {verifySchoolStudentAccount} from '../src/staff/staff_student_management';

const TEST_HMAC_KEY = '0123456789abcdef0123456789abcdef0123456789abcdef';

test('registration with an enrollment code stays retryable when roster verification is unavailable', async (t) => {
  const previousKey = process.env.RESQME_SCHOOL_ROSTER_HMAC_KEY;
  delete process.env.RESQME_SCHOOL_ROSTER_HMAC_KEY;
  t.after(() => {
    if (previousKey !== undefined) process.env.RESQME_SCHOOL_ROSTER_HMAC_KEY = previousKey;
  });
  const store = makeMockDb();
  t.mock.method(registrationDeps, 'db', () => store.db as never);
  const request = {
    auth: {uid: 'student-retry', token: {}},
    data: {
      fullName: 'Mara Cruz Reyes',
      birthDate: '2005-03-10',
      lrn: '109900112233',
      enrollmentCode: 'ENROLL-TEST-CODE-0001',
      noticeVersion,
      acknowledgmentAccepted: true,
    },
  };
  await assert.rejects(createStudentRegistration.run(request as never), {
    code: 'failed-precondition',
  });
  assert.equal(store.rows.size, 0);

  await createStudentRegistration.run({
    ...request,
    data: {...request.data, enrollmentCode: null},
  } as never);
  assert.equal(store.rows.get('studentProfiles/student-retry')?.schoolApprovalStatus, 'pending');
});

function makeMockDb() {
  const rows = new Map<string, Record<string, unknown>>();

  const docRef = (path: string) => ({
    path,
    id: path.split('/').pop()!,
    async get() {
      const data = rows.get(path);
      return {
        id: path.split('/').pop()!,
        exists: data !== undefined,
        data: () => data,
        get: (f: string) => data?.[f],
      };
    },
    collection(sub: string) {
      return {
        doc(id: string) {
          return docRef(`${path}/${sub}/${id}`);
        },
      };
    },
  });

  const db = {
    doc: docRef,
    async runTransaction<T>(fn: (tx: unknown) => Promise<T>): Promise<T> {
      const ops: Array<() => void> = [];
      const tx = {
        async get(ref: {path: string}) {
          if (ops.length > 0) throw new Error('Firestore transactions require reads before writes.');
          const data = rows.get(ref.path);
          return {
            exists: data !== undefined,
            data: () => data,
            get: (f: string) => data?.[f],
          };
        },
        create(ref: {path: string}, data: Record<string, unknown>) {
          if (rows.has(ref.path)) throw new Error(`Already exists: ${ref.path}`);
          ops.push(() => rows.set(ref.path, {...data}));
        },
        update(ref: {path: string}, patch: Record<string, unknown>) {
          ops.push(() => {
            const cur = rows.get(ref.path);
            if (!cur) throw new Error(`Missing doc: ${ref.path}`);
            rows.set(ref.path, {...cur, ...patch});
          });
        },
        set(ref: {path: string}, data: Record<string, unknown>, opts?: {merge?: boolean}) {
          ops.push(() => {
            const cur = opts?.merge ? (rows.get(ref.path) ?? {}) : {};
            rows.set(ref.path, {...cur, ...data});
          });
        },
      };
      const res = await fn(tx);
      for (const op of ops) op();
      return res;
    },
  };

  return {rows, db};
}

test('validateRegistration validates exact YYYY-MM-DD birthDate, derives age, and rejects invalid dates', () => {
  const valid = validateRegistration({
    fullName: 'Juan Santos Dela Cruz',
    birthDate: '2007-04-15',
    lrn: '009987654321',
    noticeVersion,
    acknowledgmentAccepted: true,
  } as never);
  assert.equal(valid.birthDate, '2007-04-15');
  assert.ok(valid.ageYears >= 18);

  for (const badBirthDate of [
    '2010-02-29', // non-leap-year Feb 29
    '2099-01-01', // future date
    '04/15/2007', // non-ISO format
    '2007-4-5', // unpadded
    12345,
  ]) {
    assert.throws(() =>
      validateRegistration({
        fullName: 'Juan Santos Dela Cruz',
        ageYears: 18,
        birthDate: badBirthDate,
        lrn: '009987654321',
        noticeVersion,
        acknowledgmentAccepted: true,
      } as never),
    );
  }
});

test('evaluateRosterClaim and matchingRosterSchool enforce exact birthDate and reject fuzzy/partial names', () => {
  const lrn = '009987654321';
  const code = 'ENROLL-CODE-TEST-00001';
  const rosterId = rosterLookupId(lrn, TEST_HMAC_KEY);
  const roster = {
    schoolId: 'school-alpha',
    lastName: 'Dela Cruz',
    firstName: 'Juan',
    middleName: 'Santos',
    normalizedName: normalizeRosterName('Juan Santos Dela Cruz'),
    birthDate: '2010-05-10',
    enrollmentCodeDigest: rosterCodeDigest(code, TEST_HMAC_KEY),
    claimedByUid: null,
  };
  const codeClaim = {rosterId, claimedByUid: null};

  // Exact match (both First Middle Last and SF1 "Last, First Middle" format) succeeds
  for (const exactForm of ['Juan Santos Dela Cruz', '  Dela Cruz,  Juan   Santos ']) {
    assert.equal(
      evaluateRosterClaim({
        roster,
        codeClaim,
        rosterId,
        lrn,
        fullName: exactForm,
        birthDate: '2010-05-10',
        enrollmentCode: code,
        uid: 'stu-1',
        key: TEST_HMAC_KEY,
      }),
      'auto_approve',
    );
    assert.equal(matchingRosterSchool(roster, exactForm, '2010-05-10'), 'school-alpha');
  }

  // Fuzzy / partial / missing middle name MUST NOT match!
  for (const fuzzyName of [
    'Juan Dela Cruz',
    'Juan S. Dela Cruz',
    'Juan Santoz Dela Cruz',
    'Juan Santos Dela',
  ]) {
    assert.equal(
      evaluateRosterClaim({
        roster,
        codeClaim,
        rosterId,
        lrn,
        fullName: fuzzyName,
        birthDate: '2010-05-10',
        enrollmentCode: code,
        uid: 'stu-1',
        key: TEST_HMAC_KEY,
      }),
      'manual_review',
    );
    assert.equal(matchingRosterSchool(roster, fuzzyName, '2010-05-10'), null);
  }

  // Missing or wrong birthDate against SF1 roster row with birthDate MUST NOT match!
  for (const wrongBirth of [null, undefined, '2010-05-11', '2009-05-10']) {
    assert.equal(
      evaluateRosterClaim({
        roster,
        codeClaim,
        rosterId,
        lrn,
        fullName: 'Juan Santos Dela Cruz',
        birthDate: wrongBirth,
        enrollmentCode: code,
        uid: 'stu-1',
        key: TEST_HMAC_KEY,
      }),
      'manual_review',
    );
    assert.equal(matchingRosterSchool(roster, 'Juan Santos Dela Cruz', wrongBirth), null);
  }

  // Roster match WITHOUT enrollmentCode (identity ownership distinction!) stays manual_review
  assert.equal(
    evaluateRosterClaim({
      roster,
      codeClaim: undefined,
      rosterId,
      lrn,
      fullName: 'Juan Santos Dela Cruz',
      birthDate: '2010-05-10',
      enrollmentCode: null,
      uid: 'stu-1',
      key: TEST_HMAC_KEY,
    }),
    'manual_review',
  );
});

test('createStudentRegistration automatically activates verified roster student, enforces minor guardian gate, and blocks duplicate LRN across manual admin review', async (t) => {
  const prevKey = process.env.RESQME_SCHOOL_ROSTER_HMAC_KEY;
  process.env.RESQME_SCHOOL_ROSTER_HMAC_KEY = TEST_HMAC_KEY;
  t.after(() => {
    if (prevKey === undefined) delete process.env.RESQME_SCHOOL_ROSTER_HMAC_KEY;
    else process.env.RESQME_SCHOOL_ROSTER_HMAC_KEY = prevKey;
  });

  const s = makeMockDb();
  t.mock.method(registrationDeps, 'db', () => s.db as never);
  t.mock.method(staffManagementDeps, 'db', () => s.db as never);

  s.rows.set('staffAccounts/master-1', {
    role: 'admin',
    isMasterAdmin: true,
    active: true,
    status: 'active',
    schoolId: 'school-alpha',
    mustChangePassword: false,
    requiresEmailVerification: true,
  });

  const lrn = '009987654321';
  const code = 'ENROLL-MINOR-CODE-0001';
  const rId = rosterLookupId(lrn, TEST_HMAC_KEY);
  const cDigest = rosterCodeDigest(code, TEST_HMAC_KEY);

  s.rows.set(`schoolRosterClaims/${rId}`, {
    schoolId: 'school-alpha',
    lrn,
    lastName: 'Dela Cruz',
    firstName: 'Juan',
    middleName: 'Santos',
    fullName: 'Juan Santos Dela Cruz',
    normalizedName: 'juan santos dela cruz',
    gradeLevel: 'Grade 10',
    sex: 'Male',
    birthDate: '2011-05-10',
    enrollmentCodeDigest: cDigest,
    claimedByUid: null,
  });
  s.rows.set(`schoolRosterCodes/${cDigest}`, {
    rosterId: rId,
    schoolId: 'school-alpha',
    claimedByUid: null,
  });

  // 1. Minor registers with matching LRN + "Last, First Middle" + exact birthDate + valid code
  const res = await createStudentRegistration.run({
    auth: {uid: 'stu-minor-1', token: {}},
    data: {
      fullName: 'Dela Cruz, Juan Santos',
      birthDate: '2011-05-10',
      ageYears: 15,
      lrn,
      enrollmentCode: code,
      noticeVersion,
      acknowledgmentAccepted: true,
    },
  } as never);

  assert.equal(res.status, 'pending_guardian');
  const profile = s.rows.get('studentProfiles/stu-minor-1')!;
  assert.equal(profile.schoolApprovalStatus, 'approved');
  assert.equal(profile.schoolVerificationMethod, 'roster');
  assert.equal(profile.schoolVerificationOutcome, 'verified');
  assert.equal(profile.schoolId, 'school-alpha');
  assert.equal(profile.gradeLevel, 'Grade 10');
  assert.equal(profile.birthDate, '2011-05-10');
  assert.equal(profile.gender, 'Male');
  assert.ok((profile.ageYearsAtRegistration as number) < 18);

  // Minor still CANNOT bypass guardian authorization even when schoolApprovalStatus == 'approved'!
  assert.equal(
    evaluateStudentEligibility({
      uid: 'stu-minor-1',
      profile,
      medical: {
        schemaVersion: 1,
        medicalStatus: 'complete',
        selfReported: true,
        revision: 1,
      },
      guardianAuthorization: undefined,
    }),
    false,
  );

  // 2a. Mismatched biographical guess for a claimed LRN stays 'manual_review' (anti-enumeration) and leaks zero roster fields!
  const enumProbeRes = await createStudentRegistration.run({
    auth: {uid: 'stu-enum-probe', token: {}},
    data: {
      fullName: 'Another Name',
      birthDate: '2007-01-01',
      ageYears: 19,
      lrn,
      noticeVersion,
      acknowledgmentAccepted: true,
    },
  } as never);
  assert.equal(JSON.stringify(enumProbeRes).includes('school-alpha'), false);
  const enumProbeProfile = s.rows.get('studentProfiles/stu-enum-probe')!;
  assert.equal(enumProbeProfile.schoolVerificationOutcome, 'manual_review');
  assert.equal(enumProbeProfile.schoolId, null);
  assert.equal('gradeLevel' in enumProbeProfile, false);

  // 2b. Second registrant with matching biographical identity trying to re-claim the same LRN gets conflict & zero unapproved roster attributes!
  const dupRes = await createStudentRegistration.run({
    auth: {uid: 'stu-impersonator', token: {}},
    data: {
      fullName: 'Juan Santos Dela Cruz',
      birthDate: '2011-05-10',
      ageYears: 15,
      lrn,
      noticeVersion,
      acknowledgmentAccepted: true,
    },
  } as never);
  // Response must not leak roster school, grade, or owner identity
  assert.equal(JSON.stringify(dupRes).includes('school-alpha'), false);
  assert.equal(JSON.stringify(dupRes).includes('Grade 10'), false);

  const dupProfile = s.rows.get('studentProfiles/stu-impersonator')!;
  assert.equal(dupProfile.schoolApprovalStatus, 'pending');
  assert.equal(dupProfile.schoolVerificationOutcome, 'conflict');
  assert.equal('gradeLevel' in dupProfile, false);
  assert.equal(dupProfile.gender, null);

  // Even if someone forces schoolId onto dupProfile, verifySchoolStudentAccount rejects LRN lock!
  s.rows.set('studentProfiles/stu-impersonator-2', {
    schemaVersion: 1,
    fullName: 'Impersonator Two',
    ageYearsAtRegistration: 19,
    lrn,
    status: 'pending_review',
    schoolAssignmentStatus: 'assigned',
    schoolId: 'school-alpha',
    schoolApprovalStatus: 'pending',
    schoolVerificationOutcome: 'manual_review',
    medicalStatus: 'not_started',
    medicalRevision: 0,
  });
  await assert.rejects(
    () =>
      verifySchoolStudentAccount.run({
        auth: {
          uid: 'master-1',
          token: {email_verified: true, auth_time: Math.floor(Date.now() / 1000)},
        },
        data: {studentUid: 'stu-impersonator-2', requestId: 'req-imp-check-01'},
      } as never),
    /already claimed/i,
  );

  // 3. Manual verification against an unclaimed minor roster row forces pending_guardian even if forged ageYears >= 18
  const lrnMinorManual = '009987654399';
  const rIdMinorManual = rosterLookupId(lrnMinorManual, TEST_HMAC_KEY);
  s.rows.set(`schoolRosterClaims/${rIdMinorManual}`, {
    schoolId: 'school-alpha',
    lrn: lrnMinorManual,
    normalizedName: 'rosa santos',
    gradeLevel: 'Grade 9',
    birthDate: '2012-03-15',
    enrollmentCodeDigest: null,
    claimedByUid: null,
  });
  s.rows.set('studentProfiles/stu-forged-age', {
    schemaVersion: 1,
    fullName: 'Rosa Santos',
    ageYearsAtRegistration: 20, // forged adult age prior to manual review
    lrn: lrnMinorManual,
    status: 'pending_review',
    schoolAssignmentStatus: 'assigned',
    schoolId: 'school-alpha',
    schoolApprovalStatus: 'pending',
    schoolVerificationOutcome: 'manual_review',
    medicalStatus: 'complete',
    medicalRevision: 1,
  });
  await verifySchoolStudentAccount.run({
    auth: {
      uid: 'master-1',
      token: {email_verified: true, auth_time: Math.floor(Date.now() / 1000)},
    },
    data: {studentUid: 'stu-forged-age', requestId: 'req-manual-minor-01'},
  } as never);
  const manuallyVerifiedMinor = s.rows.get('studentProfiles/stu-forged-age')!;
  assert.equal(manuallyVerifiedMinor.status, 'pending_guardian');
  assert.ok((manuallyVerifiedMinor.ageYearsAtRegistration as number) < 18);
  assert.equal(manuallyVerifiedMinor.birthDate, '2012-03-15');
  assert.equal(manuallyVerifiedMinor.gradeLevel, 'Grade 9');
});

test('claimMyRosterVerification allows a pending student to fix a birthDate typo and auto-verify with their enrollment code', async (t) => {
  const prevKey = process.env.RESQME_SCHOOL_ROSTER_HMAC_KEY;
  process.env.RESQME_SCHOOL_ROSTER_HMAC_KEY = TEST_HMAC_KEY;
  t.after(() => {
    if (prevKey === undefined) delete process.env.RESQME_SCHOOL_ROSTER_HMAC_KEY;
    else process.env.RESQME_SCHOOL_ROSTER_HMAC_KEY = prevKey;
  });

  const s = makeMockDb();
  t.mock.method(registrationDeps, 'db', () => s.db as never);

  const lrn = '109900112233';
  const code = 'ENROLL-RECOVERY-CODE1';
  const rId = rosterLookupId(lrn, TEST_HMAC_KEY);
  const cDigest = rosterCodeDigest(code, TEST_HMAC_KEY);

  s.rows.set(`schoolRosterClaims/${rId}`, {
    schoolId: 'school-alpha',
    lrn,
    lastName: 'Reyes',
    firstName: 'Mara',
    middleName: 'Cruz',
    fullName: 'Mara Cruz Reyes',
    normalizedName: 'mara cruz reyes',
    gradeLevel: 'Grade 10',
    sex: 'Female',
    birthDate: '2005-03-10',
    enrollmentCodeDigest: cDigest,
    claimedByUid: null,
  });
  s.rows.set(`schoolRosterCodes/${cDigest}`, {
    rosterId: rId,
    schoolId: 'school-alpha',
    claimedByUid: null,
  });

  // Step 1: Student accidentally submits wrong birthDate year (2010-03-10) -> falls back to unassigned manual_review
  await createStudentRegistration.run({
    auth: {uid: 'stu-recovery-1', token: {}},
    data: {
      fullName: 'Mara Cruz Reyes',
      birthDate: '2010-03-10',
      ageYears: 16,
      lrn,
      enrollmentCode: code,
      noticeVersion,
      acknowledgmentAccepted: true,
    },
  } as never);
  assert.equal(s.rows.get('studentProfiles/stu-recovery-1')!.schoolApprovalStatus, 'pending');
  assert.equal(s.rows.get('studentProfiles/stu-recovery-1')!.schoolAssignmentStatus, 'unassigned');

  // Step 2: Mismatched claim attempt fails cleanly without mutating or leaking
  await assert.rejects(
    () =>
      claimMyRosterVerification.run({
        auth: {uid: 'stu-recovery-1', token: {}},
        data: {
          fullName: 'Mara Cruz Reyes',
          birthDate: '2010-03-10',
          lrn,
          enrollmentCode: code,
        },
      } as never),
    /did not match/i,
  );
  assert.equal(s.rows.get('studentProfiles/stu-recovery-1')!.schoolApprovalStatus, 'pending');

  // Opening My QR before retrying enrollment creates a pending credential and lookup.
  const payload = 'resqme:v1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
  s.rows.set('studentQrCredentials/stu-recovery-1', {
    payload,
    verificationStatus: 'pending',
  });
  const lookupPath = `studentQrLookups/${hashQrPayload(payload)}`;
  s.rows.set(lookupPath, {uid: 'stu-recovery-1', status: 'pending'});
  Object.assign(s.rows.get('studentProfiles/stu-recovery-1')!, {
    medicalStatus: 'complete',
    medicalRevision: 1,
  });
  s.rows.set('studentMedicalRecords/stu-recovery-1', {
    schemaVersion: 1,
    medicalStatus: 'complete',
    selfReported: true,
    revision: 1,
    conditions: {state: 'none_known', details: null},
    allergies: {state: 'none_known', details: null},
    primaryContact: {fullName: 'Test Guardian', relationship: 'Parent', phoneNumber: '09171234567'},
  });

  // Step 3: Corrected birthDate 2005-03-10 claims roster, sets approved, and updates age/status
  const verified = (await claimMyRosterVerification.run({
    auth: {uid: 'stu-recovery-1', token: {}},
    data: {
      fullName: 'Mara Cruz Reyes',
      birthDate: '2005-03-10',
      lrn,
      enrollmentCode: code,
    },
  } as never)) as {verified: boolean; schoolApprovalStatus: string};

  assert.equal(verified.verified, true);
  assert.equal(verified.schoolApprovalStatus, 'approved');
  const updated = s.rows.get('studentProfiles/stu-recovery-1')!;
  assert.equal(updated.schoolApprovalStatus, 'approved');
  assert.equal(updated.schoolAssignmentStatus, 'assigned');
  assert.equal(updated.schoolId, 'school-alpha');
  assert.equal(updated.schoolVerificationMethod, 'roster');
  assert.equal(updated.schoolVerificationOutcome, 'verified');
  assert.equal(updated.birthDate, '2005-03-10');
  assert.equal(updated.status, 'pending_review');
  assert.ok((updated.ageYearsAtRegistration as number) >= 18);
  assert.equal(s.rows.get(`schoolRosterClaims/${rId}`)!.claimedByUid, 'stu-recovery-1');
  assert.equal(s.rows.get('studentQrCredentials/stu-recovery-1')!.verificationStatus, 'active');
  assert.equal(s.rows.get(lookupPath)!.status, 'active');

  // Step 4: Second account trying to claim the consumed code fails cleanly
  s.rows.set('studentProfiles/stu-other-claim', {
    schemaVersion: 1,
    fullName: 'Mara Cruz Reyes',
    ageYearsAtRegistration: 21,
    status: 'pending_review',
    schoolApprovalStatus: 'pending',
    medicalStatus: 'not_started',
    medicalRevision: 0,
  });
  await assert.rejects(
    () =>
      claimMyRosterVerification.run({
        auth: {uid: 'stu-other-claim', token: {}},
        data: {
          fullName: 'Mara Cruz Reyes',
          birthDate: '2005-03-10',
          lrn,
          enrollmentCode: code,
        },
      } as never),
    /did not match/i,
  );
});
