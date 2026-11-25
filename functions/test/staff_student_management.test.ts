import assert from 'node:assert/strict';
import test from 'node:test';
import {requirePending, requireQrEligible} from '../src/onboarding/authorization';
import {sanitizeStudentProfile} from '../src/profile/get_my_student_profile';
import {evaluateQrEligibility, evaluateStudentEligibility} from '../src/qr/qr_eligibility';
import {hashQrPayload} from '../src/qr/resolve_tier1_qr';
import {rosterLookupId} from '../src/school/roster_contract';
import {staffManagementDeps, type StaffAdminAuthPort} from '../src/staff/staff_account_management';
import {
  getPortalDashboardStats,
  getSchoolStudentDetails,
  listSchoolRoster,
  listSchoolStudents,
  setStudentAccountStatus,
  verifySchoolStudentAccount,
} from '../src/staff/staff_student_management';

const TEST_QR = 'resqme:v1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';

function makeStore() {
  const rows = new Map<string, Record<string, unknown>>();
  const users = new Map<
    string,
    {email: string; password: string; disabled: boolean; revokedTokens: number; displayName: string}
  >();

  interface MockDocRef {
    path: string;
    id: string;
    get: () => Promise<{
      id: string;
      exists: boolean;
      data: () => Record<string, unknown> | undefined;
      get: (f: string) => unknown;
    }>;
    update: (patch: Record<string, unknown>) => Promise<void>;
    collection: (sub: string) => {doc: (id: string) => MockDocRef};
  }

  const docRef = (path: string): MockDocRef => ({
    path,
    id: path.split('/').pop()!,
    async get() {
      const data = rows.get(path);
      return {
        id: path.split('/').pop()!,
        exists: data !== undefined,
        data: () => data,
        get: (field: string) => data?.[field],
      };
    },
    async update(patch: Record<string, unknown>) {
      const cur = rows.get(path);
      if (!cur) throw new Error(`Missing doc ${path}`);
      rows.set(path, {...cur, ...patch});
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
    collection(col: string) {
      const filters: Array<[string, unknown]> = [];
      const query = {
        where(field: string, _op: string, value: unknown) {
          filters.push([field, value]);
          return query;
        },
        async get() {
          const docs = [...rows.entries()]
            .filter(([p]) => p.startsWith(`${col}/`) && p.split('/').length === 2)
            .filter(([, data]) => filters.every(([f, v]) => data[f] === v))
            .map(([p, data]) => ({
              id: p.split('/').pop()!,
              ref: docRef(p),
              data: () => data,
              get: (field: string) => data[field],
            }));
          return {docs};
        },
      };
      return query;
    },
    async runTransaction<T>(fn: (tx: unknown) => Promise<T>): Promise<T> {
      const ops: Array<() => void> = [];
      const tx = {
        async get(ref: {path: string}) {
          const data = rows.get(ref.path);
          return {
            exists: data !== undefined,
            data: () => data,
            get: (field: string) => data?.[field],
          };
        },
        create(ref: {path: string}, data: Record<string, unknown>) {
          if (rows.has(ref.path)) throw new Error(`Already exists: ${ref.path}`);
          ops.push(() => rows.set(ref.path, {...data}));
        },
        update(ref: {path: string}, patch: Record<string, unknown>) {
          ops.push(() => {
            const cur = rows.get(ref.path);
            if (!cur) throw new Error(`Missing doc ${ref.path}`);
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
      const result = await fn(tx);
      for (const op of ops) op();
      return result;
    },
  };

  const auth: StaffAdminAuthPort = {
    async createUser(input) {
      const uid = `u-${users.size + 1}`;
      users.set(uid, {
        email: input.email,
        password: input.password,
        disabled: false,
        revokedTokens: 0,
        displayName: input.displayName,
      });
      return {uid};
    },
    async updateUser(uid, input) {
      const u = users.get(uid) ?? {
        email: `${uid}@student.test`,
        password: '',
        disabled: false,
        revokedTokens: 0,
        displayName: '',
      };
      if (input.password !== undefined) u.password = input.password;
      if (input.disabled !== undefined) u.disabled = input.disabled;
      if (input.displayName !== undefined) u.displayName = input.displayName;
      users.set(uid, u);
    },
    async revokeRefreshTokens(uid) {
      const u = users.get(uid);
      if (u) u.revokedTokens += 1;
    },
    async deleteUser(uid) {
      users.delete(uid);
    },
  };

  return {db, auth, rows, users};
}

function req(
  uid: string,
  data: unknown = {},
  opts: {emailVerified?: boolean; email?: string; authTime?: number} = {},
) {
  return {
    auth: {
      uid,
      token: {
        auth_time: opts.authTime ?? Math.floor(Date.now() / 1000),
        email_verified: opts.emailVerified ?? true,
        email: opts.email ?? `${uid}@school.edu.ph`,
      },
    },
    data,
  } as never;
}

function seedMasterAdmin(rows: Map<string, Record<string, unknown>>, uid = 'master-a', schoolId = 'school-a') {
  rows.set(`staffAccounts/${uid}`, {
    role: 'admin',
    isMasterAdmin: true,
    active: true,
    status: 'active',
    schoolId,
    mustChangePassword: false,
    requiresEmailVerification: true,
  });
}

test('disabled student profile is rejected across onboarding, profile, QR, and Tier 2 chokepoints', () => {
  const baseProfile = {
    schemaVersion: 1,
    fullName: 'Juan Dela Cruz',
    ageYearsAtRegistration: 19,
    status: 'pending_review',
    schoolAssignmentStatus: 'assigned',
    schoolId: 'school-a',
    schoolApprovalStatus: 'approved',
    schoolVerificationOutcome: 'verified',
    medicalStatus: 'complete',
    medicalRevision: 1,
    lrn: '000123456789',
  };
  const completeMedical = {
    schemaVersion: 1,
    medicalStatus: 'complete',
    selfReported: true,
    revision: 1,
    conditions: {state: 'none_known', details: null},
    allergies: {state: 'none_known', details: null},
    primaryContact: {fullName: 'Maria Dela Cruz', relationship: 'Mother', phoneNumber: '09171234567'},
  };

  assert.equal(
    evaluateStudentEligibility({
      uid: 'stu-1',
      profile: baseProfile,
      medical: completeMedical,
      guardianAuthorization: undefined,
    }),
    true,
  );

  for (const disabledPatch of [{accountDisabled: true}, {accountStatus: 'disabled'}]) {
    const disabledProfile = {...baseProfile, ...disabledPatch};
    assert.throws(() => requirePending(disabledProfile));
    assert.throws(() => requireQrEligible(disabledProfile));
    assert.throws(() => sanitizeStudentProfile(disabledProfile));
    assert.equal(
      evaluateStudentEligibility({
        uid: 'stu-1',
        profile: disabledProfile,
        medical: completeMedical,
        guardianAuthorization: undefined,
      }),
      false,
    );
    assert.equal(
      evaluateQrEligibility({
        uid: 'stu-1',
        profile: disabledProfile,
        medical: completeMedical,
        guardianAuthorization: undefined,
        credential: {payload: TEST_QR, verificationStatus: 'active'},
        lookup: {uid: 'stu-1', status: 'active'},
      }),
      false,
    );
  }
});

test('dashboard stats, Active Students filters, LRN leading zeros, pagination, and zero medical leakage', async (t) => {
  const s = makeStore();
  seedMasterAdmin(s.rows, 'master-a', 'school-a');
  s.rows.set('staffAccounts/auth-1', {
    role: 'authorized',
    isMasterAdmin: false,
    active: true,
    status: 'active',
    schoolId: 'school-a',
    mustChangePassword: false,
    requiresEmailVerification: false,
    fullName: 'Clara Nurse',
    position: 'Nurse',
    loginId: 'AUTH-1111AAAA',
  });
  s.rows.set('staffAccounts/auth-other', {
    role: 'authorized',
    isMasterAdmin: false,
    active: true,
    status: 'active',
    schoolId: 'school-b',
  });

  // Roster entries for school-a (2) and school-b (1)
  s.rows.set('schoolRosterClaims/r1', {
    schoolId: 'school-a',
    normalizedName: 'ana santos',
    displayName: 'Santos, Ana',
    lrn: '009876543210',
    gradeLevel: 'Grade 10',
    claimedByUid: 'stu-verified',
  });
  s.rows.set('schoolRosterClaims/r2', {
    schoolId: 'school-a',
    normalizedName: 'unregistered learner',
    displayName: 'Learner, Unregistered',
    lrn: '001122334455',
    claimedByUid: null,
  });
  s.rows.set('schoolRosterClaims/r-other', {
    schoolId: 'school-b',
    normalizedName: 'other school',
    lrn: '111111111111',
  });

  // Students in school-a: 1 verified, 1 registered (unverified, no grade), 1 disabled (with revoked QR)
  s.rows.set('studentProfiles/stu-verified', {
    schemaVersion: 1,
    fullName: 'Ana Santos',
    ageYearsAtRegistration: 16,
    birthDate: '2010-04-12',
    gradeLevel: 'Grade 10',
    gender: 'Female',
    lrn: '009876543210',
    status: 'pending_guardian',
    schoolAssignmentStatus: 'assigned',
    schoolId: 'school-a',
    schoolApprovalStatus: 'approved',
    schoolVerificationMethod: 'roster',
    schoolVerificationOutcome: 'verified',
    medicalStatus: 'complete',
    medicalRevision: 1,
  });
  s.rows.set('studentMedicalRecords/stu-verified', {
    schemaVersion: 1,
    medicalStatus: 'complete',
    selfReported: true,
    revision: 1,
    conditions: {state: 'listed', details: 'SECRET ASTHMA DETAILS'},
    allergies: {state: 'listed', details: 'SECRET PEANUT ALLERGY'},
  });
  s.rows.set('studentGuardianAuthorizations/stu-verified', {
    studentUid: 'stu-verified',
    guardianUid: 'guard-1',
    status: 'verified',
    method: 'independent_guardian_verification',
    verifiedAt: new Date('2026-01-10T00:00:00Z'),
  });
  s.rows.set('studentQrCredentials/stu-verified', {
    payload: TEST_QR,
    verificationStatus: 'active',
  });

  s.rows.set('studentProfiles/stu-registered', {
    schemaVersion: 1,
    fullName: 'Benito Reyes',
    ageYearsAtRegistration: 18,
    lrn: '000000123456',
    status: 'pending_review',
    schoolAssignmentStatus: 'assigned',
    schoolId: 'school-a',
    schoolApprovalStatus: 'pending',
    schoolVerificationMethod: null,
    schoolVerificationOutcome: 'manual_review',
    medicalStatus: 'not_started',
    medicalRevision: 0,
  });

  s.rows.set('studentProfiles/stu-disabled', {
    schemaVersion: 1,
    fullName: 'Carlo Mendoza',
    ageYearsAtRegistration: 19,
    gradeLevel: 'Grade 12',
    lrn: '005555555555',
    status: 'pending_review',
    schoolAssignmentStatus: 'assigned',
    schoolId: 'school-a',
    schoolApprovalStatus: 'revoked',
    schoolVerificationOutcome: 'verified',
    accountDisabled: true,
    accountStatus: 'disabled',
    medicalStatus: 'complete',
    medicalRevision: 1,
  });

  // Cross-school student must never appear
  s.rows.set('studentProfiles/stu-other-school', {
    schemaVersion: 1,
    fullName: 'Zoe Other',
    ageYearsAtRegistration: 18,
    lrn: '999999999999',
    status: 'pending_review',
    schoolAssignmentStatus: 'assigned',
    schoolId: 'school-b',
    schoolApprovalStatus: 'approved',
  });

  t.mock.method(staffManagementDeps, 'db', () => s.db as never);
  t.mock.method(staffManagementDeps, 'auth', () => s.auth);

  const stats = await getPortalDashboardStats.run(req('master-a', {}));
  assert.equal(stats.schoolId, 'school-a');
  assert.equal(stats.rosterAvailable, true);
  assert.equal(stats.importedRosterCount, 2);
  assert.equal(stats.registeredStudentsCount, 3);
  assert.equal(stats.verifiedStudentsCount, 1);
  assert.equal(stats.disabledStudentsCount, 1);
  assert.equal(stats.authorizedPersonnelCount, 1);

  // Active Students list: alphabetical, leading zeros preserved, Unassigned Grade fallback, visible categories only
  const page1 = await listSchoolStudents.run(req('master-a', {limit: 2}));
  assert.equal(page1.students.length, 2);
  assert.equal(page1.students[0].fullName, 'Ana Santos');
  assert.equal(page1.students[0].accountCategory, 'verified');
  assert.equal(page1.students[0].lrn, '009876543210');
  assert.equal(page1.students[1].fullName, 'Benito Reyes');
  assert.equal(page1.students[1].accountCategory, 'registered');
  assert.equal(page1.students[1].gradeLevel, 'Unassigned Grade');
  assert.equal(page1.students[1].lrn, '000000123456');
  assert.ok(page1.nextCursor);

  const page2 = await listSchoolStudents.run(req('master-a', {limit: 2, cursor: page1.nextCursor}));
  assert.equal(page2.students.length, 1);
  assert.equal(page2.students[0].fullName, 'Carlo Mendoza');
  assert.equal(page2.students[0].accountCategory, 'disabled');
  assert.equal(page2.nextCursor, null);

  // Exact LRN search preserves leading zeros
  const byLrn = await listSchoolStudents.run(req('master-a', {search: '000000123456'}));
  assert.equal(byLrn.students.length, 1);
  assert.equal(byLrn.students[0].uid, 'stu-registered');

  // Filter by Unassigned Grade
  const unassigned = await listSchoolStudents.run(req('master-a', {gradeFilter: 'Unassigned Grade'}));
  assert.equal(unassigned.students.length, 1);
  assert.equal(unassigned.students[0].uid, 'stu-registered');

  // Reject invalid visible categories ('pending' or 'revoked')
  await assert.rejects(() => listSchoolStudents.run(req('master-a', {statusFilter: 'pending'})));
  await assert.rejects(() => listSchoolStudents.run(req('master-a', {statusFilter: 'revoked'})));

  // Student Details never exposes medical contents or QR payload
  const details = await getSchoolStudentDetails.run(req('master-a', {studentUid: 'stu-verified'}));
  const serialized = JSON.stringify(details);
  assert.equal(serialized.includes('SECRET ASTHMA DETAILS'), false);
  assert.equal(serialized.includes('SECRET PEANUT ALLERGY'), false);
  assert.equal(serialized.includes(TEST_QR), false);
  assert.equal(details.lrn, '009876543210');
  assert.equal(details.gradeLevel, 'Grade 10');
  assert.equal(details.sex, 'Female');
  assert.equal(details.birthDate, '2010-04-12');
  assert.equal(details.accountCategory, 'verified');
  assert.equal(details.verificationMethod, 'roster');
  assert.equal(details.medicalCompletionStatus, 'complete');
  assert.equal(details.guardianAuthorizationStatus, 'verified');
  assert.equal(details.qrStatus, 'active');

  // Cross-school details denied
  await assert.rejects(
    () => getSchoolStudentDetails.run(req('master-a', {studentUid: 'stu-other-school'})),
    /permission-denied|Student account is unavailable/,
  );
});

test('manual verification enforces Master Admin role, LRN uniqueness, conflict block, and QR eligibility', async (t) => {
  const s = makeStore();
  seedMasterAdmin(s.rows, 'master-a', 'school-a');
  s.rows.set('staffAccounts/auth-a', {
    role: 'authorized',
    isMasterAdmin: false,
    active: true,
    status: 'active',
    schoolId: 'school-a',
    mustChangePassword: false,
    requiresEmailVerification: false,
  });

  // Eligible Registered student whose medical record is NOT complete yet -> QR must stay pending!
  s.rows.set('studentProfiles/stu-incomplete', {
    schemaVersion: 1,
    fullName: 'Diana Lim',
    ageYearsAtRegistration: 19,
    lrn: '004444444444',
    status: 'pending_review',
    schoolAssignmentStatus: 'assigned',
    schoolId: 'school-a',
    schoolApprovalStatus: 'pending',
    schoolVerificationMethod: null,
    schoolVerificationOutcome: 'manual_review',
    medicalStatus: 'not_started',
    medicalRevision: 0,
  });
  s.rows.set('studentQrCredentials/stu-incomplete', {
    payload: TEST_QR,
    verificationStatus: 'pending',
  });
  s.rows.set('studentQrLookups/unused', {uid: 'stu-incomplete', status: 'pending'});

  // Second student attempting to claim the EXACT same LRN '004444444444'
  s.rows.set('studentProfiles/stu-dup-lrn', {
    schemaVersion: 1,
    fullName: 'Diana Duplicate',
    ageYearsAtRegistration: 19,
    lrn: '004444444444',
    status: 'pending_review',
    schoolAssignmentStatus: 'assigned',
    schoolId: 'school-a',
    schoolApprovalStatus: 'pending',
    schoolVerificationOutcome: 'manual_review',
    medicalStatus: 'not_started',
    medicalRevision: 0,
  });

  // Student with unresolved identity conflict
  s.rows.set('studentProfiles/stu-conflict', {
    schemaVersion: 1,
    fullName: 'Conflict Student',
    ageYearsAtRegistration: 18,
    lrn: '007777777777',
    status: 'pending_review',
    schoolAssignmentStatus: 'assigned',
    schoolId: 'school-a',
    schoolApprovalStatus: 'pending',
    schoolVerificationOutcome: 'conflict',
    medicalStatus: 'not_started',
    medicalRevision: 0,
  });

  t.mock.method(staffManagementDeps, 'db', () => s.db as never);
  t.mock.method(staffManagementDeps, 'auth', () => s.auth);

  // Authorized user cannot manually verify
  await assert.rejects(() =>
    verifySchoolStudentAccount.run(req('auth-a', {studentUid: 'stu-incomplete', requestId: 'req-0001'})),
  );

  // Conflict student cannot be manually verified
  await assert.rejects(
    () => verifySchoolStudentAccount.run(req('master-a', {studentUid: 'stu-conflict', requestId: 'req-conflict'})),
    /conflict/i,
  );

  // Master Admin verifies stu-incomplete; QR stays pending because medical is incomplete
  const approved = await verifySchoolStudentAccount.run(
    req('master-a', {studentUid: 'stu-incomplete', requestId: 'req-approve-01'}),
  );
  assert.equal(approved.schoolApprovalStatus, 'approved');
  assert.equal(approved.verificationMethod, 'manual_admin');
  assert.equal(approved.qrActivated, false);
  assert.equal(s.rows.get('studentQrCredentials/stu-incomplete')!.verificationStatus, 'pending');

  // Idempotent replay with same requestId succeeds
  const replay = await verifySchoolStudentAccount.run(
    req('master-a', {studentUid: 'stu-incomplete', requestId: 'req-approve-01'}),
  );
  assert.equal(replay.schoolApprovalStatus, 'approved');

  // Duplicate LRN claim by another UID in same school is rejected!
  await assert.rejects(
    () => verifySchoolStudentAccount.run(req('master-a', {studentUid: 'stu-dup-lrn', requestId: 'req-dup-01'})),
    /LRN|already claimed/i,
  );

  // Eligible adult student with complete medical record + pending QR activates QR upon approval
  const qrPayloadEligible = Buffer.alloc(32, 1).toString('base64url');
  const canonicalEligibleQr = `resqme:v1:${qrPayloadEligible}`;
  s.rows.set('studentProfiles/stu-full-eligible', {
    schemaVersion: 1,
    fullName: 'Francois Garcia',
    ageYearsAtRegistration: 20,
    lrn: '006666666666',
    status: 'pending_review',
    schoolAssignmentStatus: 'assigned',
    schoolId: 'school-a',
    schoolApprovalStatus: 'pending',
    schoolVerificationOutcome: 'manual_review',
    medicalStatus: 'complete',
    medicalRevision: 1,
  });
  s.rows.set('studentMedicalRecords/stu-full-eligible', {
    schemaVersion: 1,
    medicalStatus: 'complete',
    selfReported: true,
    revision: 1,
    conditions: {state: 'none_known', details: null},
    allergies: {state: 'none_known', details: null},
    primaryContact: {fullName: 'Parent Garcia', relationship: 'Father', phoneNumber: '09170001111'},
  });
  s.rows.set('studentQrCredentials/stu-full-eligible', {
    payload: canonicalEligibleQr,
    verificationStatus: 'pending',
  });
  s.rows.set(`studentQrLookups/${hashQrPayload(canonicalEligibleQr)}`, {
    uid: 'stu-full-eligible',
    status: 'pending',
  });

  const fullRes = await verifySchoolStudentAccount.run(
    req('master-a', {studentUid: 'stu-full-eligible', requestId: 'req-full-01'}),
  );
  assert.equal(fullRes.qrActivated, true);
  assert.equal(s.rows.get('studentQrCredentials/stu-full-eligible')!.verificationStatus, 'active');
  assert.equal(
    s.rows.get(`studentQrLookups/${hashQrPayload(canonicalEligibleQr)}`)!.status,
    'active',
  );
});

test('manual verification rejects roster LRN claimed by a different student UID', async (t) => {
  const prevKey = process.env.RESQME_SCHOOL_ROSTER_HMAC_KEY;
  process.env.RESQME_SCHOOL_ROSTER_HMAC_KEY = '0123456789abcdef0123456789abcdef0123456789abcdef';
  t.after(() => {
    if (prevKey === undefined) delete process.env.RESQME_SCHOOL_ROSTER_HMAC_KEY;
    else process.env.RESQME_SCHOOL_ROSTER_HMAC_KEY = prevKey;
  });

  const s = makeStore();
  seedMasterAdmin(s.rows, 'master-a', 'school-a');
  const lrn = '008888888888';
  const rosterId = rosterLookupId(lrn, process.env.RESQME_SCHOOL_ROSTER_HMAC_KEY!);
  s.rows.set(`schoolRosterClaims/${rosterId}`, {
    schoolId: 'school-a',
    normalizedName: 'real owner',
    claimedByUid: 'real-owner-uid',
  });
  s.rows.set('studentProfiles/impersonator-uid', {
    schemaVersion: 1,
    fullName: 'Real Owner',
    ageYearsAtRegistration: 18,
    lrn,
    status: 'pending_review',
    schoolAssignmentStatus: 'assigned',
    schoolId: 'school-a',
    schoolApprovalStatus: 'pending',
    schoolVerificationOutcome: 'manual_review',
    medicalStatus: 'not_started',
    medicalRevision: 0,
  });

  t.mock.method(staffManagementDeps, 'db', () => s.db as never);
  t.mock.method(staffManagementDeps, 'auth', () => s.auth);

  await assert.rejects(
    () => verifySchoolStudentAccount.run(req('master-a', {studentUid: 'impersonator-uid', requestId: 'req-imp-01'})),
    /claimed|conflict/i,
  );
});

test('disabling and reactivating student account enforces Auth lock, audits, and never restores revoked QR', async (t) => {
  const s = makeStore();
  seedMasterAdmin(s.rows, 'master-a', 'school-a');
  s.rows.set('studentProfiles/stu-revoked-qr', {
    schemaVersion: 1,
    fullName: 'Elena Ramos',
    ageYearsAtRegistration: 19,
    lrn: '003333333333',
    status: 'pending_review',
    schoolAssignmentStatus: 'assigned',
    schoolId: 'school-a',
    schoolApprovalStatus: 'revoked',
    schoolVerificationMethod: 'manual_admin',
    schoolVerificationOutcome: 'verified',
    medicalStatus: 'complete',
    medicalRevision: 1,
  });
  s.rows.set('studentQrCredentials/stu-revoked-qr', {
    payload: TEST_QR,
    verificationStatus: 'revoked',
  });
  s.rows.set('tier2Devices/stu-revoked-qr', {
    deviceId: 'stu-dev-1',
    status: 'active',
    keyVersion: 1,
  });
  s.users.set('stu-revoked-qr', {
    email: 'elena@student.test',
    password: 'pw',
    disabled: false,
    revokedTokens: 0,
    displayName: 'Elena Ramos',
  });

  t.mock.method(staffManagementDeps, 'db', () => s.db as never);
  t.mock.method(staffManagementDeps, 'auth', () => s.auth);

  // Stale auth is rejected
  await assert.rejects(() =>
    setStudentAccountStatus.run(
      req('master-a', {studentUid: 'stu-revoked-qr', action: 'disable'}, {authTime: Math.floor(Date.now() / 1000) - 300}),
    ),
  );

  // Disable account
  const disabledRes = await setStudentAccountStatus.run(
    req('master-a', {studentUid: 'stu-revoked-qr', action: 'disable'}),
  );
  assert.equal(disabledRes.accountCategory, 'disabled');
  assert.equal(s.rows.get('studentProfiles/stu-revoked-qr')!.accountDisabled, true);
  assert.equal(s.rows.get('studentProfiles/stu-revoked-qr')!.accountStatus, 'disabled');
  assert.equal(s.rows.get('tier2Devices/stu-revoked-qr')!.status, 'revoked');
  assert.equal(s.users.get('stu-revoked-qr')!.disabled, true);
  assert.equal(s.users.get('stu-revoked-qr')!.revokedTokens, 1);

  // Reactivate account -> QR credential MUST remain 'revoked' and schoolApprovalStatus unchanged!
  const enabledRes = await setStudentAccountStatus.run(
    req('master-a', {studentUid: 'stu-revoked-qr', action: 'enable'}),
  );
  assert.equal(enabledRes.accountCategory, 'registered');
  assert.equal(s.rows.get('studentProfiles/stu-revoked-qr')!.accountDisabled, false);
  assert.equal(s.rows.get('studentProfiles/stu-revoked-qr')!.accountStatus, 'active');
  assert.equal(s.users.get('stu-revoked-qr')!.disabled, false);
  assert.equal(s.rows.get('studentQrCredentials/stu-revoked-qr')!.verificationStatus, 'revoked');
  assert.equal(s.rows.get('studentProfiles/stu-revoked-qr')!.schoolApprovalStatus, 'revoked');

  const audits = [...s.rows.entries()].filter(([k]) => k.startsWith('staffManagementAudits/'));
  assert.equal(audits.length, 2);
});

test('Student Roster lists unregistered, registered, and verified roster claims and truthful empty state', async (t) => {
  const s = makeStore();
  seedMasterAdmin(s.rows, 'master-empty', 'school-empty');
  seedMasterAdmin(s.rows, 'master-a', 'school-a');

  s.rows.set('schoolRosterClaims/rc-1', {
    schoolId: 'school-a',
    normalizedName: 'zara bautista',
    displayName: 'Bautista, Zara',
    lrn: '002222222222',
    sex: 'F',
    birthDate: '2009-09-01',
    claimedByUid: null,
  });
  s.rows.set('schoolRosterClaims/rc-2', {
    schoolId: 'school-a',
    normalizedName: 'marco tan',
    displayName: 'Tan, Marco',
    lrn: '001111111111',
    gradeLevel: 'Grade 9',
    claimedByUid: 'stu-reg',
  });
  s.rows.set('studentProfiles/stu-reg', {
    schemaVersion: 1,
    fullName: 'Marco Tan',
    ageYearsAtRegistration: 15,
    lrn: '001111111111',
    status: 'pending_guardian',
    schoolAssignmentStatus: 'assigned',
    schoolId: 'school-a',
    schoolApprovalStatus: 'pending',
  });
  s.rows.set('schoolRosterClaims/rc-3', {
    schoolId: 'school-a',
    normalizedName: 'ana santos',
    displayName: 'Santos, Ana',
    lrn: '000099998888',
    gradeLevel: 'Grade 10',
    claimedByUid: 'stu-ver',
  });
  s.rows.set('studentProfiles/stu-ver', {
    schemaVersion: 1,
    fullName: 'Ana Santos',
    ageYearsAtRegistration: 16,
    lrn: '000099998888',
    status: 'pending_guardian',
    schoolAssignmentStatus: 'assigned',
    schoolId: 'school-a',
    schoolApprovalStatus: 'approved',
  });

  t.mock.method(staffManagementDeps, 'db', () => s.db as never);
  t.mock.method(staffManagementDeps, 'auth', () => s.auth);

  const emptyRoster = await listSchoolRoster.run(req('master-empty', {}));
  assert.equal(emptyRoster.rosterAvailable, false);
  assert.equal(emptyRoster.entries.length, 0);

  const roster = await listSchoolRoster.run(req('master-a', {}));
  assert.equal(roster.rosterAvailable, true);
  assert.equal(roster.entries.length, 3);
  // Sorted alphabetically by displayName: Bautista, Zara -> Santos, Ana -> Tan, Marco
  assert.equal(roster.entries[0].displayName, 'Bautista, Zara');
  assert.equal(roster.entries[0].registrationState, 'not_registered');
  assert.equal(roster.entries[0].gradeLevel, 'Unassigned Grade');
  assert.equal(roster.entries[1].displayName, 'Santos, Ana');
  assert.equal(roster.entries[1].registrationState, 'verified');
  assert.equal(roster.entries[1].lrn, '000099998888');
  assert.equal(roster.entries[2].displayName, 'Tan, Marco');
  assert.equal(roster.entries[2].registrationState, 'registered');
});
