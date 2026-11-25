import {randomBytes} from 'node:crypto';
import {FieldValue, Timestamp} from 'firebase-admin/firestore';
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {keys, object} from '../medical/medical_contract';
import {requireRecentAuth, verifyTier2Signature} from '../medical/tier2_challenge';
import {isStudentAccountDisabled, resqmeRuntimeOptions} from '../onboarding/authorization';
import {isQrPayload} from '../qr/ensure_my_tier1_qr';
import {evaluateQrEligibility} from '../qr/qr_eligibility';
import {hashQrPayload} from '../qr/resolve_tier1_qr';
import {rosterLookupId} from '../school/roster_contract';
import {auditRecord, requireMasterAdmin, staffManagementDeps} from './staff_account_management';
import {assertAttestationSerialsNotRevoked} from './staff_attestation';
import {STAFF_ENROLLMENT_PROOF_VERSION} from './staff_tier2_contract';

export type VisibleStudentCategory = 'registered' | 'verified' | 'disabled';
export type RosterRegistrationState = 'not_registered' | 'registered' | 'verified';
export type LrnRevealTargetType = 'student' | 'roster';

export const UNASSIGNED_GRADE_LABEL = 'Unassigned Grade';
const UID_PATTERN = /^[A-Za-z0-9_-]{2,128}$/;
const DEVICE_ID_PATTERN = /^[A-Za-z0-9_-]{16,128}$/;
const CHALLENGE_ID_PATTERN = /^[a-f0-9]{32,64}$/;
const REQUEST_ID_PATTERN = /^[A-Za-z0-9_-]{8,128}$/;
const MAX_PAGE_SIZE = 25;
const LRN_REVEAL_PURPOSE = 'reveal_student_lrn';
const RATE_WINDOW_MS = 10 * 60_000;
const MAX_LRN_REVEALS_PER_WINDOW = 15;
const MAX_EXACT_LRN_SEARCHES_PER_WINDOW = 20;

export async function enforceTransactionalRateLimit(
  db: FirebaseFirestore.Firestore,
  docPath: string,
  maxAttempts: number,
  errorMessage: string,
): Promise<void> {
  const now = Date.now();
  const rateRef = db.doc(docPath);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(rateRef);
    const started = snap.get('windowStartedAt');
    const attempts = snap.get('attempts');
    const startedMs =
      started instanceof Timestamp
        ? started.toMillis()
        : started instanceof Date
          ? started.getTime()
          : 0;
    const sameWindow = startedMs > 0 && now - startedMs < RATE_WINDOW_MS;
    const count = sameWindow && Number.isSafeInteger(attempts) ? Number(attempts) : 0;
    if (count >= maxAttempts) {
      throw new HttpsError('resource-exhausted', errorMessage);
    }
    tx.set(rateRef, {
      windowStartedAt: sameWindow ? started : Timestamp.fromMillis(now),
      attempts: count + 1,
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
}

function normalizeGradeLevel(raw: unknown): string {
  if (typeof raw !== 'string') return UNASSIGNED_GRADE_LABEL;
  const trimmed = raw.trim().replace(/\s+/g, ' ');
  return trimmed.length > 0 ? trimmed : UNASSIGNED_GRADE_LABEL;
}

function normalizeLrnDisplay(raw: unknown): string | null {
  if (typeof raw === 'string' && /^\d{12}$/.test(raw)) return raw;
  return null;
}

/**
 * Masks a 12-digit LRN so only the first 4 and last 4 digits are visible
 * (`XXXX••••XXXX`), keeping the middle 4 digits unexposed in standard reads.
 */
export function maskLrn(raw: unknown): string | null {
  const valid = normalizeLrnDisplay(raw);
  if (!valid) return null;
  return `${valid.slice(0, 4)}••••${valid.slice(8)}`;
}

export function adminLrnRevealSignedMessage(input: {
  adminUid: string;
  deviceId: string;
  targetType: LrnRevealTargetType;
  targetId: string;
  challengeId: string;
  nonce: string;
}): string {
  return `resqme:admin-lrn-reveal:v1\n${input.adminUid}\n${input.deviceId}\n${input.targetType}\n${input.targetId}\n${input.challengeId}\n${input.nonce}`;
}

export function deriveVisibleStudentCategory(profile: Record<string, unknown>): VisibleStudentCategory {
  if (isStudentAccountDisabled(profile)) return 'disabled';
  if (profile.schoolApprovalStatus === 'approved') return 'verified';
  return 'registered';
}

function validateStudentUid(raw: unknown): string {
  if (typeof raw !== 'string' || !UID_PATTERN.test(raw)) {
    throw new HttpsError('invalid-argument', 'Invalid student account.');
  }
  return raw;
}

function validatePageLimit(raw: unknown): number {
  if (raw == null) return MAX_PAGE_SIZE;
  if (!Number.isInteger(raw) || Number(raw) < 1 || Number(raw) > MAX_PAGE_SIZE) {
    throw new HttpsError('invalid-argument', `Page limit must be between 1 and ${MAX_PAGE_SIZE}.`);
  }
  return Number(raw);
}

function validateCursor(raw: unknown): string | null {
  if (raw == null || raw === '') return null;
  if (typeof raw !== 'string' || raw.length > 256) {
    throw new HttpsError('invalid-argument', 'Invalid pagination cursor.');
  }
  return raw;
}

function validateSearch(raw: unknown): string {
  if (raw == null) return '';
  if (typeof raw !== 'string') throw new HttpsError('invalid-argument', 'Invalid search query.');
  const trimmed = raw.trim();
  if (trimmed.length > 100) throw new HttpsError('invalid-argument', 'Search query is too long.');
  return trimmed;
}

function validateGradeFilter(raw: unknown): string | null {
  if (raw == null || raw === '' || raw === 'all') return null;
  if (typeof raw !== 'string' || raw.trim().length > 64) {
    throw new HttpsError('invalid-argument', 'Invalid grade filter.');
  }
  return raw.trim();
}

function formatRosterDisplayName(row: Record<string, unknown>): string {
  for (const field of ['displayName', 'sf1Name', 'fullName']) {
    if (typeof row[field] === 'string' && row[field].trim().length > 0) {
      return (row[field] as string).trim();
    }
  }
  if (typeof row.normalizedName === 'string' && row.normalizedName.trim().length > 0) {
    return row.normalizedName
      .trim()
      .split(/\s+/)
      .map((part) => (part.length > 0 ? part[0].toUpperCase() + part.slice(1) : part))
      .join(' ');
  }
  return 'Unnamed Roster Student';
}

export const getPortalDashboardStats = onCall(resqmeRuntimeOptions, async (request) => {
  const adminUid = request.auth?.uid;
  if (!adminUid) throw new HttpsError('unauthenticated', 'Sign in is required.');
  const data = request.data == null ? {} : object(request.data);
  keys(data, []);

  const db = staffManagementDeps.db(adminUid);
  const admin = await requireMasterAdmin(
    db,
    adminUid,
    request.auth?.token.email_verified === true,
  );

  const [studentsSnap, rosterSnap, staffSnap] = await Promise.all([
    db.collection('studentProfiles').where('schoolId', '==', admin.schoolId).get(),
    db.collection('schoolRosterClaims').where('schoolId', '==', admin.schoolId).get(),
    db
      .collection('staffAccounts')
      .where('schoolId', '==', admin.schoolId)
      .where('role', '==', 'authorized')
      .get(),
  ]);

  let registeredStudentsCount = 0;
  let verifiedStudentsCount = 0;
  let disabledStudentsCount = 0;

  for (const doc of studentsSnap.docs) {
    const profile = doc.data();
    if (profile.schemaVersion !== 1) continue;
    registeredStudentsCount += 1;
    const category = deriveVisibleStudentCategory(profile);
    if (category === 'disabled') {
      disabledStudentsCount += 1;
    } else if (category === 'verified') {
      verifiedStudentsCount += 1;
    }
  }

  let authorizedPersonnelCount = 0;
  for (const doc of staffSnap.docs) {
    const row = doc.data();
    if (row.status !== 'revoked') {
      authorizedPersonnelCount += 1;
    }
  }

  const importedRosterCount = rosterSnap.docs.length;

  return {
    schoolId: admin.schoolId,
    rosterAvailable: importedRosterCount > 0,
    importedRosterCount,
    registeredStudentsCount,
    verifiedStudentsCount,
    disabledStudentsCount,
    authorizedPersonnelCount,
  };
});

export const listSchoolStudents = onCall(resqmeRuntimeOptions, async (request) => {
  const adminUid = request.auth?.uid;
  if (!adminUid) throw new HttpsError('unauthenticated', 'Sign in is required.');
  const data = request.data == null ? {} : object(request.data);
  keys(data, ['search', 'statusFilter', 'gradeFilter', 'limit', 'cursor']);

  const search = validateSearch(data.search);
  const statusFilter = data.statusFilter == null ? 'all' : data.statusFilter;
  if (!['all', 'registered', 'verified', 'disabled'].includes(statusFilter as string)) {
    throw new HttpsError('invalid-argument', 'Invalid student status filter.');
  }
  const gradeFilter = validateGradeFilter(data.gradeFilter);
  const limit = validatePageLimit(data.limit);
  const cursor = validateCursor(data.cursor);

  const db = staffManagementDeps.db(adminUid);
  const admin = await requireMasterAdmin(
    db,
    adminUid,
    request.auth?.token.email_verified === true,
  );

  const isExactLrnQuery = /^\d{12}$/.test(search);
  if (isExactLrnQuery) {
    await enforceTransactionalRateLimit(
      db,
      `staffLrnSearchRateLimits/${adminUid}`,
      MAX_EXACT_LRN_SEARCHES_PER_WINDOW,
      'Too many exact LRN searches. Please wait before trying again.',
    );
  }

  const snap = await db
    .collection('studentProfiles')
    .where('schoolId', '==', admin.schoolId)
    .get();

  const availableGradesSet = new Set<string>();
  const allRows: Array<{
    uid: string;
    fullName: string;
    rawLrn: string | null;
    maskedLrn: string | null;
    hasLrn: boolean;
    gradeLevel: string;
    accountCategory: VisibleStudentCategory;
    schoolApprovalStatus: string;
    verificationMethod: string | null;
  }> = [];

  for (const doc of snap.docs) {
    const profile = doc.data();
    if (profile.schemaVersion !== 1 || typeof profile.fullName !== 'string') continue;
    const gradeLevel = normalizeGradeLevel(profile.gradeLevel);
    availableGradesSet.add(gradeLevel);
    const rawLrn = normalizeLrnDisplay(profile.lrn);
    allRows.push({
      uid: doc.id,
      fullName: profile.fullName.trim(),
      rawLrn,
      maskedLrn: maskLrn(rawLrn),
      hasLrn: rawLrn !== null,
      gradeLevel,
      accountCategory: deriveVisibleStudentCategory(profile),
      schoolApprovalStatus:
        typeof profile.schoolApprovalStatus === 'string' ? profile.schoolApprovalStatus : 'pending',
      verificationMethod:
        typeof profile.schoolVerificationMethod === 'string'
          ? profile.schoolVerificationMethod
          : null,
    });
  }

  const isExactLrnQuery2 = /^\d{12}$/.test(search);
  const loweredSearch = search.toLowerCase();

  const filtered = allRows.filter((row) => {
    if (statusFilter !== 'all' && row.accountCategory !== statusFilter) return false;
    if (gradeFilter && row.gradeLevel !== gradeFilter) return false;
    if (search.length > 0) {
      if (isExactLrnQuery2) {
        return row.rawLrn === search;
      }
      const matchesName = row.fullName.toLowerCase().includes(loweredSearch);
      const matchesExactLrn = row.rawLrn === search;
      return matchesName || matchesExactLrn;
    }
    return true;
  });

  filtered.sort((a, b) => {
    const cmp = a.fullName.localeCompare(b.fullName, 'en', {sensitivity: 'base'});
    return cmp !== 0 ? cmp : a.uid.localeCompare(b.uid);
  });

  let startIndex = 0;
  if (cursor) {
    const idx = filtered.findIndex((item) => item.uid === cursor);
    if (idx === -1) {
      throw new HttpsError('invalid-argument', 'Invalid pagination cursor.');
    }
    startIndex = idx + 1;
  }

  const pageSlice = filtered.slice(startIndex, startIndex + limit);
  const hasMore = startIndex + limit < filtered.length;
  const nextCursor = hasMore && pageSlice.length > 0 ? pageSlice[pageSlice.length - 1].uid : null;

  // Strip rawLrn before returning over the wire so only maskedLrn leaves the server.
  const page = pageSlice.map(({rawLrn: _omitted, ...publicRow}) => publicRow);

  const availableGrades = [...availableGradesSet].sort((a, b) => {
    if (a === UNASSIGNED_GRADE_LABEL) return 1;
    if (b === UNASSIGNED_GRADE_LABEL) return -1;
    return a.localeCompare(b, 'en', {numeric: true, sensitivity: 'base'});
  });

  return {
    students: page,
    nextCursor,
    totalMatched: filtered.length,
    availableGrades,
  };
});

export const getSchoolStudentDetails = onCall(resqmeRuntimeOptions, async (request) => {
  const adminUid = request.auth?.uid;
  if (!adminUid) throw new HttpsError('unauthenticated', 'Sign in is required.');
  const data = object(request.data);
  keys(data, ['studentUid']);
  const studentUid = validateStudentUid(data.studentUid);

  const db = staffManagementDeps.db(adminUid);
  const admin = await requireMasterAdmin(
    db,
    adminUid,
    request.auth?.token.email_verified === true,
  );

  // Never read studentMedicalRecords in administration screens.
  const [profileSnap, guardianSnap, credentialSnap] = await Promise.all([
    db.doc(`studentProfiles/${studentUid}`).get(),
    db.doc(`studentGuardianAuthorizations/${studentUid}`).get(),
    db.doc(`studentQrCredentials/${studentUid}`).get(),
  ]);

  const profile = profileSnap.data();
  if (
    !profileSnap.exists ||
    !profile ||
    profile.schemaVersion !== 1 ||
    profile.schoolAssignmentStatus !== 'assigned' ||
    profile.schoolId !== admin.schoolId ||
    typeof profile.fullName !== 'string'
  ) {
    throw new HttpsError('permission-denied', 'Student account is unavailable.');
  }

  const ageYears = Number.isInteger(profile.ageYearsAtRegistration)
    ? Number(profile.ageYearsAtRegistration)
    : null;
  const guardianData = guardianSnap.data();
  let guardianAuthorizationStatus: 'not_required_adult' | 'verified' | 'pending' = 'pending';
  if (ageYears !== null && ageYears >= 18) {
    guardianAuthorizationStatus = 'not_required_adult';
  } else if (guardianSnap.exists && guardianData?.status === 'verified') {
    guardianAuthorizationStatus = 'verified';
  }

  const credStatus = credentialSnap.exists ? credentialSnap.get('verificationStatus') : null;
  const qrStatus: 'not_issued' | 'pending' | 'active' | 'revoked' =
    credStatus === 'active' || credStatus === 'pending' || credStatus === 'revoked'
      ? credStatus
      : 'not_issued';

  const sexRaw =
    typeof profile.sex === 'string' && profile.sex.trim().length > 0
      ? profile.sex.trim()
      : typeof profile.gender === 'string' && profile.gender.trim().length > 0
        ? profile.gender.trim()
        : null;

  const birthDate =
    typeof profile.birthDate === 'string' && profile.birthDate.trim().length > 0
      ? profile.birthDate.trim()
      : null;

  const accountCategory = deriveVisibleStudentCategory(profile);
  const schoolApprovalStatus =
    typeof profile.schoolApprovalStatus === 'string' ? profile.schoolApprovalStatus : 'pending';
  const verificationOutcome =
    typeof profile.schoolVerificationOutcome === 'string'
      ? profile.schoolVerificationOutcome
      : 'manual_review';

  const canVerifyManually =
    accountCategory === 'registered' &&
    schoolApprovalStatus === 'pending' &&
    verificationOutcome !== 'conflict';

  const rawLrn = normalizeLrnDisplay(profile.lrn);

  return {
    uid: studentUid,
    fullName: profile.fullName.trim(),
    maskedLrn: maskLrn(rawLrn),
    hasLrn: rawLrn !== null,
    gradeLevel: normalizeGradeLevel(profile.gradeLevel),
    sex: sexRaw,
    birthDate,
    ageYearsAtRegistration: ageYears,
    accountCategory,
    accountDisabled: isStudentAccountDisabled(profile),
    registrationStatus: typeof profile.status === 'string' ? profile.status : 'pending_review',
    schoolApprovalStatus,
    verificationMethod:
      typeof profile.schoolVerificationMethod === 'string'
        ? profile.schoolVerificationMethod
        : null,
    verificationOutcome,
    medicalCompletionStatus:
      profile.medicalStatus === 'complete' ? 'complete' : 'not_started',
    guardianAuthorizationStatus,
    qrStatus,
    credentialVersion: credentialSnap.exists
      ? Number.isSafeInteger(credentialSnap.get('credentialVersion')) &&
          Number(credentialSnap.get('credentialVersion')) >= 1
        ? Number(credentialSnap.get('credentialVersion'))
        : 1
      : 0,
    canVerifyManually,
  };
});

export const verifySchoolStudentAccount = onCall(resqmeRuntimeOptions, async (request) => {
  const adminUid = request.auth?.uid;
  if (!adminUid) throw new HttpsError('unauthenticated', 'Sign in is required.');
  const data = object(request.data);
  keys(data, ['studentUid', 'requestId']);
  const studentUid = validateStudentUid(data.studentUid);
  if (typeof data.requestId !== 'string' || !REQUEST_ID_PATTERN.test(data.requestId)) {
    throw new HttpsError('invalid-argument', 'Invalid verification request ID.');
  }
  const requestId = data.requestId;
  if (studentUid === adminUid) {
    throw new HttpsError('permission-denied', 'Cannot verify your own account.');
  }

  const rosterKey = process.env.RESQME_SCHOOL_ROSTER_HMAC_KEY;
  if (rosterKey && Buffer.byteLength(rosterKey, 'utf8') < 32) {
    throw new HttpsError('failed-precondition', 'Roster verification key is misconfigured.');
  }

  const emailVerified = request.auth?.token.email_verified === true;
  const db = staffManagementDeps.db(adminUid);

  return db.runTransaction(async (tx) => {
    const admin = await requireMasterAdmin(db, adminUid, emailVerified, tx);
    const profileRef = db.doc(`studentProfiles/${studentUid}`);
    const approvalRef = profileRef.collection('schoolApprovals').doc(requestId);
    const credentialRef = db.doc(`studentQrCredentials/${studentUid}`);
    const medicalRef = db.doc(`studentMedicalRecords/${studentUid}`);
    const guardianRef = db.doc(`studentGuardianAuthorizations/${studentUid}`);

    const [profileSnap, approvalSnap, credentialSnap, medicalSnap, guardianSnap] =
      await Promise.all([
        tx.get(profileRef),
        tx.get(approvalRef),
        tx.get(credentialRef),
        tx.get(medicalRef),
        tx.get(guardianRef),
      ]);

    const profile = profileSnap.data();
    if (
      !profileSnap.exists ||
      !profile ||
      profile.schemaVersion !== 1 ||
      profile.schoolAssignmentStatus !== 'assigned' ||
      profile.schoolId !== admin.schoolId
    ) {
      throw new HttpsError('permission-denied', 'Student account is unavailable for this school.');
    }

    if (isStudentAccountDisabled(profile)) {
      throw new HttpsError('failed-precondition', 'Disabled student accounts cannot be verified.');
    }

    if (approvalSnap.exists) {
      return {
        uid: studentUid,
        schoolApprovalStatus: 'approved' as const,
        verificationMethod: 'manual_admin' as const,
        qrActivated: approvalSnap.get('qrActivated') === true,
      };
    }

    if (profile.schoolVerificationOutcome === 'conflict') {
      throw new HttpsError(
        'failed-precondition',
        'Unresolved LRN or roster identity conflict must be resolved before approval.',
      );
    }

    if (profile.schoolApprovalStatus === 'approved') {
      throw new HttpsError('failed-precondition', 'Student account is already school-verified.');
    }

    if (profile.schoolApprovalStatus !== 'pending') {
      throw new HttpsError(
        'failed-precondition',
        'Only pending Registered student accounts are eligible for manual school verification.',
      );
    }

    const lrn = normalizeLrnDisplay(profile.lrn);
    if (!lrn) {
      throw new HttpsError('failed-precondition', 'A valid 12-digit LRN is required for school verification.');
    }

    const lrnLockRef = db.doc(`studentLrnLocks/${admin.schoolId}_${lrn}`);
    const rosterRef = rosterKey ? db.doc(`schoolRosterClaims/${rosterLookupId(lrn, rosterKey)}`) : null;
    const rawQrPayload = credentialSnap.exists ? credentialSnap.get('payload') : null;
    const lookupRef =
      credentialSnap.exists && isQrPayload(rawQrPayload)
        ? db.doc(`studentQrLookups/${hashQrPayload(rawQrPayload)}`)
        : null;

    const [lrnLockSnap, rosterSnap, lookupSnap] = await Promise.all([
      tx.get(lrnLockRef),
      rosterRef ? tx.get(rosterRef) : Promise.resolve(null),
      lookupRef ? tx.get(lookupRef) : Promise.resolve(null),
    ]);

    if (
      lrnLockSnap.exists &&
      lrnLockSnap.get('status') === 'active' &&
      lrnLockSnap.get('uid') !== studentUid
    ) {
      throw new HttpsError(
        'already-exists',
        'This LRN is already claimed by another verified student account in this school.',
      );
    }

    if (rosterSnap && rosterSnap.exists) {
      const rosterSchool = rosterSnap.get('schoolId');
      const claimedBy = rosterSnap.get('claimedByUid');
      if (typeof rosterSchool === 'string' && rosterSchool !== admin.schoolId) {
        throw new HttpsError(
          'failed-precondition',
          'Roster LRN belongs to a different school assignment.',
        );
      }
      if (typeof claimedBy === 'string' && claimedBy.length > 0 && claimedBy !== studentUid) {
        throw new HttpsError(
          'failed-precondition',
          'This LRN is already claimed on the official school roster by another account.',
        );
      }
    }

    const nextProfile: Record<string, unknown> = {
      ...profile,
      schoolApprovalStatus: 'approved',
      schoolVerificationMethod: 'manual_admin',
      schoolVerificationOutcome: 'verified',
    };

    let qrActivated = false;
    if (
      credentialSnap.exists &&
      credentialSnap.get('verificationStatus') === 'pending' &&
      lookupRef &&
      lookupSnap?.exists &&
      evaluateQrEligibility({
        uid: studentUid,
        profile: nextProfile,
        medical: medicalSnap.data(),
        guardianAuthorization: guardianSnap.data(),
        credential: credentialSnap.data(),
        lookup: lookupSnap.data(),
      })
    ) {
      qrActivated = true;
      tx.update(credentialRef, {
        verificationStatus: 'active',
        activatedAt: FieldValue.serverTimestamp(),
      });
      tx.update(lookupRef, {
        status: 'active',
        activatedAt: FieldValue.serverTimestamp(),
      });
    }

    tx.set(
      lrnLockRef,
      {
        uid: studentUid,
        lrn,
        schoolId: admin.schoolId,
        status: 'active',
        approvedBy: adminUid,
        updatedAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );

    if (rosterRef && rosterSnap?.exists && !rosterSnap.get('claimedByUid')) {
      tx.update(rosterRef, {
        claimedByUid: studentUid,
        claimedAt: FieldValue.serverTimestamp(),
      });
    }

    tx.update(profileRef, {
      schoolApprovalStatus: 'approved',
      schoolVerificationMethod: 'manual_admin',
      schoolVerificationOutcome: 'verified',
      schoolApprovedBy: adminUid,
      schoolApprovedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    tx.create(approvalRef, {
      action: 'approve',
      method: 'manual_admin',
      reviewerUid: adminUid,
      schoolId: admin.schoolId,
      qrActivated,
      recordedAt: FieldValue.serverTimestamp(),
    });

    tx.create(
      db.doc(`staffManagementAudits/${randomBytes(16).toString('hex')}`),
      auditRecord({
        actorUid: adminUid,
        actorRole: admin.role,
        schoolId: admin.schoolId,
        action: 'verify_student_account',
        targetUid: studentUid,
        outcome: 'allowed',
      }),
    );

    return {
      uid: studentUid,
      schoolApprovalStatus: 'approved' as const,
      verificationMethod: 'manual_admin' as const,
      qrActivated,
    };
  });
});

export const setStudentAccountStatus = onCall(resqmeRuntimeOptions, async (request) => {
  const adminUid = request.auth?.uid;
  if (!adminUid) throw new HttpsError('unauthenticated', 'Sign in is required.');
  requireRecentAuth(request.auth?.token.auth_time, undefined, 120);
  const data = object(request.data);
  keys(data, ['studentUid', 'action']);
  const studentUid = validateStudentUid(data.studentUid);
  const action = data.action;
  if (action !== 'disable' && action !== 'enable') {
    throw new HttpsError('invalid-argument', 'Invalid student account action.');
  }
  if (studentUid === adminUid) {
    throw new HttpsError('permission-denied', 'Cannot modify your own account status.');
  }

  const emailVerified = request.auth?.token.email_verified === true;
  const db = staffManagementDeps.db(adminUid);
  const disabling = action === 'disable';

  const nextCategory = await db.runTransaction(async (tx) => {
    const admin = await requireMasterAdmin(db, adminUid, emailVerified, tx);
    const profileRef = db.doc(`studentProfiles/${studentUid}`);
    const tier2DeviceRef = db.doc(`tier2Devices/${studentUid}`);
    const [profileSnap, tier2DeviceSnap] = await Promise.all([
      tx.get(profileRef),
      tx.get(tier2DeviceRef),
    ]);

    const profile = profileSnap.data();
    if (
      !profileSnap.exists ||
      !profile ||
      profile.schemaVersion !== 1 ||
      profile.schoolAssignmentStatus !== 'assigned' ||
      profile.schoolId !== admin.schoolId
    ) {
      throw new HttpsError('permission-denied', 'Student account is unavailable for this school.');
    }

    const patch: Record<string, unknown> = {
      accountDisabled: disabling,
      accountStatus: disabling ? 'disabled' : 'active',
      updatedAt: FieldValue.serverTimestamp(),
    };
    if (disabling) {
      patch.disabledAt = FieldValue.serverTimestamp();
      patch.disabledBy = adminUid;
    } else {
      patch.reactivatedAt = FieldValue.serverTimestamp();
      patch.reactivatedBy = adminUid;
    }

    // Never alter studentQrCredentials or auto-restore revoked QRs on reactivation.
    tx.update(profileRef, patch);

    if (disabling && tier2DeviceSnap.exists && tier2DeviceSnap.get('status') === 'active') {
      tx.update(tier2DeviceRef, {
        status: 'revoked',
        revokedAt: FieldValue.serverTimestamp(),
      });
    }

    tx.create(
      db.doc(`staffManagementAudits/${randomBytes(16).toString('hex')}`),
      auditRecord({
        actorUid: adminUid,
        actorRole: admin.role,
        schoolId: admin.schoolId,
        action: disabling ? 'disable_student_account' : 'enable_student_account',
        targetUid: studentUid,
        outcome: 'allowed',
      }),
    );

    return deriveVisibleStudentCategory({...profile, ...patch});
  });

  const authPort = staffManagementDeps.auth();
  if (disabling) {
    await authPort.updateUser(studentUid, {disabled: true});
    await authPort.revokeRefreshTokens(studentUid);
  } else {
    await authPort.updateUser(studentUid, {disabled: false});
  }

  return {
    uid: studentUid,
    accountDisabled: disabling,
    accountCategory: nextCategory,
  };
});

export const listSchoolRoster = onCall(resqmeRuntimeOptions, async (request) => {
  const adminUid = request.auth?.uid;
  if (!adminUid) throw new HttpsError('unauthenticated', 'Sign in is required.');
  const data = request.data == null ? {} : object(request.data);
  keys(data, ['search', 'gradeFilter', 'limit', 'cursor']);

  const search = validateSearch(data.search);
  const gradeFilter = validateGradeFilter(data.gradeFilter);
  const limit = validatePageLimit(data.limit);
  const cursor = validateCursor(data.cursor);

  const db = staffManagementDeps.db(adminUid);
  const admin = await requireMasterAdmin(
    db,
    adminUid,
    request.auth?.token.email_verified === true,
  );

  const isExactLrnQuery = /^\d{12}$/.test(search);
  if (isExactLrnQuery) {
    await enforceTransactionalRateLimit(
      db,
      `staffLrnSearchRateLimits/${adminUid}`,
      MAX_EXACT_LRN_SEARCHES_PER_WINDOW,
      'Too many exact LRN searches. Please wait before trying again.',
    );
  }

  const rosterSnap = await db
    .collection('schoolRosterClaims')
    .where('schoolId', '==', admin.schoolId)
    .get();

  if (rosterSnap.docs.length === 0) {
    return {
      rosterAvailable: false,
      entries: [],
      nextCursor: null,
      totalMatched: 0,
      availableGrades: [],
    };
  }

  const claimedUids = [
    ...new Set(
      rosterSnap.docs
        .map((d) => d.get('claimedByUid'))
        .filter((u): u is string => typeof u === 'string' && u.length > 0),
    ),
  ];

  const claimedProfiles = new Map<string, Record<string, unknown>>();
  await Promise.all(
    claimedUids.map(async (uid) => {
      const snap = await db.doc(`studentProfiles/${uid}`).get();
      const p = snap.data();
      if (snap.exists && p && p.schoolId === admin.schoolId) {
        claimedProfiles.set(uid, p);
      }
    }),
  );

  const availableGradesSet = new Set<string>();
  const allEntries = rosterSnap.docs.map((doc) => {
    const row = doc.data();
    const claimedUid =
      typeof row.claimedByUid === 'string' && row.claimedByUid.length > 0
        ? row.claimedByUid
        : null;
    const linkedProfile = claimedUid ? claimedProfiles.get(claimedUid) : undefined;

    let registrationState: RosterRegistrationState = 'not_registered';
    if (linkedProfile) {
      registrationState =
        linkedProfile.schoolApprovalStatus === 'approved' && !isStudentAccountDisabled(linkedProfile)
          ? 'verified'
          : 'registered';
    }

    const gradeLevel = normalizeGradeLevel(row.gradeLevel ?? linkedProfile?.gradeLevel);
    availableGradesSet.add(gradeLevel);

    const rawLrn = normalizeLrnDisplay(row.lrn ?? linkedProfile?.lrn);
    const sex =
      typeof row.sex === 'string' && row.sex.trim().length > 0
        ? row.sex.trim()
        : typeof linkedProfile?.gender === 'string' && linkedProfile.gender.trim().length > 0
          ? linkedProfile.gender.trim()
          : null;
    const birthDate =
      typeof row.birthDate === 'string' && row.birthDate.trim().length > 0
        ? row.birthDate.trim()
        : null;

    return {
      rosterId: doc.id,
      displayName: formatRosterDisplayName(row),
      rawLrn,
      maskedLrn: maskLrn(rawLrn),
      hasLrn: rawLrn !== null,
      gradeLevel,
      sex,
      birthDate,
      registrationState,
      claimedStudentUid: linkedProfile ? claimedUid : null,
    };
  });

  const isExactLrnQuery2 = /^\d{12}$/.test(search);
  const loweredSearch = search.toLowerCase();

  const filtered = allEntries.filter((entry) => {
    if (gradeFilter && entry.gradeLevel !== gradeFilter) return false;
    if (search.length > 0) {
      if (isExactLrnQuery2) return entry.rawLrn === search;
      return entry.displayName.toLowerCase().includes(loweredSearch) || entry.rawLrn === search;
    }
    return true;
  });

  filtered.sort((a, b) => {
    const cmp = a.displayName.localeCompare(b.displayName, 'en', {sensitivity: 'base'});
    return cmp !== 0 ? cmp : a.rosterId.localeCompare(b.rosterId);
  });

  let startIndex = 0;
  if (cursor) {
    const idx = filtered.findIndex((item) => item.rosterId === cursor);
    if (idx === -1) {
      throw new HttpsError('invalid-argument', 'Invalid pagination cursor.');
    }
    startIndex = idx + 1;
  }

  const pageSlice = filtered.slice(startIndex, startIndex + limit);
  const hasMore = startIndex + limit < filtered.length;
  const nextCursor = hasMore && pageSlice.length > 0 ? pageSlice[pageSlice.length - 1].rosterId : null;

  const page = pageSlice.map(({rawLrn: _omitted, ...publicEntry}) => publicEntry);

  const availableGrades = [...availableGradesSet].sort((a, b) => {
    if (a === UNASSIGNED_GRADE_LABEL) return 1;
    if (b === UNASSIGNED_GRADE_LABEL) return -1;
    return a.localeCompare(b, 'en', {numeric: true, sensitivity: 'base'});
  });

  return {
    rosterAvailable: true,
    entries: page,
    nextCursor,
    totalMatched: filtered.length,
    availableGrades,
  };
});

async function resolveSchoolScopedTargetLrn(
  db: FirebaseFirestore.Firestore,
  tx: FirebaseFirestore.Transaction,
  schoolId: string,
  targetType: LrnRevealTargetType,
  targetId: string,
): Promise<string> {
  if (targetType === 'student') {
    const snap = await tx.get(db.doc(`studentProfiles/${targetId}`));
    const profile = snap.data();
    if (
      !snap.exists ||
      !profile ||
      profile.schemaVersion !== 1 ||
      profile.schoolAssignmentStatus !== 'assigned' ||
      profile.schoolId !== schoolId
    ) {
      throw new HttpsError('permission-denied', 'Student LRN is unavailable for this school.');
    }
    const lrn = normalizeLrnDisplay(profile.lrn);
    if (!lrn) {
      throw new HttpsError('not-found', 'No 12-digit LRN is recorded for this account.');
    }
    return lrn;
  }

  const rosterSnap = await tx.get(db.doc(`schoolRosterClaims/${targetId}`));
  const roster = rosterSnap.data();
  if (!rosterSnap.exists || !roster || roster.schoolId !== schoolId) {
    throw new HttpsError('permission-denied', 'Roster LRN is unavailable for this school.');
  }
  const directLrn = normalizeLrnDisplay(roster.lrn);
  if (directLrn) return directLrn;

  if (typeof roster.claimedByUid === 'string' && roster.claimedByUid.length > 0) {
    const linkedSnap = await tx.get(db.doc(`studentProfiles/${roster.claimedByUid}`));
    const linked = linkedSnap.data();
    if (linkedSnap.exists && linked && linked.schoolId === schoolId) {
      const linkedLrn = normalizeLrnDisplay(linked.lrn);
      if (linkedLrn) return linkedLrn;
    }
  }

  throw new HttpsError('not-found', 'Full LRN is not stored on this HMAC-only roster claim.');
}

function validateRevealTarget(data: Record<string, unknown>): {
  targetType: LrnRevealTargetType;
  targetId: string;
} {
  const targetType = data.targetType;
  if (targetType !== 'student' && targetType !== 'roster') {
    throw new HttpsError('invalid-argument', 'Invalid LRN reveal target type.');
  }
  if (typeof data.targetId !== 'string' || !UID_PATTERN.test(data.targetId)) {
    throw new HttpsError('invalid-argument', 'Invalid LRN reveal target identifier.');
  }
  return {targetType, targetId: data.targetId};
}

export const issueAdminLrnRevealChallenge = onCall(resqmeRuntimeOptions, async (request) => {
  const adminUid = request.auth?.uid;
  if (!adminUid) throw new HttpsError('unauthenticated', 'Sign in is required.');
  const data = object(request.data);
  keys(data, ['targetType', 'targetId', 'authMethod', 'deviceId']);
  const {targetType, targetId} = validateRevealTarget(data);
  const authMethod = data.authMethod == null ? 'biometric' : data.authMethod;
  if (authMethod !== 'biometric' && authMethod !== 'password') {
    throw new HttpsError('invalid-argument', 'Invalid LRN reveal verification method.');
  }

  let deviceId: string | null = null;
  if (authMethod === 'biometric') {
    if (typeof data.deviceId !== 'string' || !DEVICE_ID_PATTERN.test(data.deviceId)) {
      throw new HttpsError('invalid-argument', 'Invalid staff device identifier.');
    }
    deviceId = data.deviceId;
  }

  const emailVerified = request.auth?.token.email_verified === true;
  const db = staffManagementDeps.db(adminUid);
  await enforceTransactionalRateLimit(
    db,
    `staffLrnRevealRateLimits/${adminUid}`,
    MAX_LRN_REVEALS_PER_WINDOW,
    'Too many LRN reveal attempts. Please wait before trying again.',
  );

  const challengeId = randomBytes(24).toString('hex');
  const nonce = randomBytes(32).toString('base64url');
  const issuedAtMs = Date.now();
  const issuedAtSec = Math.floor(issuedAtMs / 1000);
  const expiresAtMs = issuedAtMs + 60_000;

  await db.runTransaction(async (tx) => {
    const admin = await requireMasterAdmin(db, adminUid, emailVerified, tx);
    let keyVersion: number | null = null;
    if (authMethod === 'biometric') {
      const deviceSnap = await tx.get(db.doc(`staffTier2Devices/${adminUid}`));
      if (
        !deviceSnap.exists ||
        deviceSnap.get('status') !== 'active' ||
        deviceSnap.get('deviceId') !== deviceId ||
        typeof deviceSnap.get('publicKey') !== 'string' ||
        !Number.isSafeInteger(deviceSnap.get('keyVersion'))
      ) {
        throw new HttpsError(
          'failed-precondition',
          'Enroll this device in Biometric Device Setup first, or confirm with your Admin password.',
        );
      }
      if (deviceSnap.get('enrollmentProofVersion') !== STAFF_ENROLLMENT_PROOF_VERSION) {
        throw new HttpsError(
          'failed-precondition',
          'Biometric device re-enrollment is required before using biometric reveal.',
        );
      }
      await assertAttestationSerialsNotRevoked(deviceSnap.get('attestationSerials'));
      keyVersion = Number(deviceSnap.get('keyVersion'));
    }

    await resolveSchoolScopedTargetLrn(db, tx, admin.schoolId, targetType, targetId);

    tx.create(db.doc(`staffLrnRevealChallenges/${challengeId}`), {
      adminUid,
      schoolId: admin.schoolId,
      purpose: LRN_REVEAL_PURPOSE,
      authMethod,
      deviceId,
      keyVersion,
      targetType,
      targetId,
      nonce,
      issuedAtSec,
      expiresAt: new Date(expiresAtMs),
      consumedAt: null,
      createdAt: FieldValue.serverTimestamp(),
    });
  });

  return {
    challengeId,
    nonce,
    deviceId,
    authMethod,
    expiresAt: expiresAtMs,
  };
});

export const revealStudentLrn = onCall(resqmeRuntimeOptions, async (request) => {
  const adminUid = request.auth?.uid;
  if (!adminUid) throw new HttpsError('unauthenticated', 'Sign in is required.');
  const data = object(request.data);
  keys(data, ['targetType', 'targetId', 'authMethod', 'challengeId', 'deviceId', 'signature']);
  const {targetType, targetId} = validateRevealTarget(data);
  const authMethod = data.authMethod;
  if (authMethod !== 'password' && authMethod !== 'biometric') {
    throw new HttpsError('invalid-argument', 'Select password or biometric step-up verification.');
  }
  if (typeof data.challengeId !== 'string' || !CHALLENGE_ID_PATTERN.test(data.challengeId)) {
    throw new HttpsError('invalid-argument', 'Missing or invalid LRN verification challenge.');
  }
  const challengeId = data.challengeId;

  const emailVerified = request.auth?.token.email_verified === true;
  const db = staffManagementDeps.db(adminUid);
  await enforceTransactionalRateLimit(
    db,
    `staffLrnRevealRateLimits/${adminUid}`,
    MAX_LRN_REVEALS_PER_WINDOW,
    'Too many LRN reveal attempts. Please wait before trying again.',
  );

  if (authMethod === 'password') {
    // Layer 2A: Fresh password reauthentication within 60 seconds.
    requireRecentAuth(request.auth?.token.auth_time, undefined, 60);
  }

  return db.runTransaction(async (tx) => {
    // Layer 1: Active, verified Master Admin session + strict school-scope isolation.
    const admin = await requireMasterAdmin(db, adminUid, emailVerified, tx);
    const challengeRef = db.doc(`staffLrnRevealChallenges/${challengeId}`);
    const challengeSnap = await tx.get(challengeRef);
    const challenge = challengeSnap.data();
    const expiresAt = challenge?.expiresAt;
    const expiresMs =
      expiresAt instanceof Timestamp
        ? expiresAt.toMillis()
        : expiresAt instanceof Date
          ? expiresAt.getTime()
          : 0;

    if (
      !challengeSnap.exists ||
      !challenge ||
      challenge.adminUid !== adminUid ||
      challenge.schoolId !== admin.schoolId ||
      challenge.purpose !== LRN_REVEAL_PURPOSE ||
      challenge.authMethod !== authMethod ||
      challenge.targetType !== targetType ||
      challenge.targetId !== targetId ||
      challenge.consumedAt != null ||
      typeof challenge.nonce !== 'string' ||
      expiresMs <= Date.now()
    ) {
      throw new HttpsError('permission-denied', 'LRN verification challenge failed or expired.');
    }

    if (authMethod === 'biometric') {
      // Layer 2B: Hardware-backed biometric signature over single-use server challenge.
      if (
        typeof data.deviceId !== 'string' ||
        !DEVICE_ID_PATTERN.test(data.deviceId) ||
        typeof data.signature !== 'string' ||
        data.signature.length < 16 ||
        data.signature.length > 512
      ) {
        throw new HttpsError('invalid-argument', 'Invalid biometric verification proof.');
      }

      const deviceSnap = await tx.get(db.doc(`staffTier2Devices/${adminUid}`));
      if (
        !deviceSnap.exists ||
        deviceSnap.get('status') !== 'active' ||
        deviceSnap.get('deviceId') !== data.deviceId ||
        challenge.deviceId !== data.deviceId ||
        challenge.keyVersion !== deviceSnap.get('keyVersion') ||
        typeof deviceSnap.get('publicKey') !== 'string'
      ) {
        throw new HttpsError('permission-denied', 'Biometric LRN verification failed or expired.');
      }
      if (deviceSnap.get('enrollmentProofVersion') !== STAFF_ENROLLMENT_PROOF_VERSION) {
        throw new HttpsError(
          'failed-precondition',
          'Biometric device re-enrollment is required.',
        );
      }
      await assertAttestationSerialsNotRevoked(deviceSnap.get('attestationSerials'));

      const expectedMessage = adminLrnRevealSignedMessage({
        adminUid,
        deviceId: data.deviceId,
        targetType,
        targetId,
        challengeId,
        nonce: challenge.nonce,
      });
      if (
        !verifyTier2Signature(
          deviceSnap.get('publicKey') as string,
          expectedMessage,
          data.signature,
        )
      ) {
        throw new HttpsError('permission-denied', 'Biometric LRN signature verification failed.');
      }
    } else {
      // Password reveal must reauthenticate AFTER this reveal challenge was issued,
      // preventing reuse of an unrelated recent login or prior reveal's auth_time.
      const authTime = request.auth?.token.auth_time;
      const issuedAtSec = Number(challenge.issuedAtSec);
      if (
        typeof authTime !== 'number' ||
        !Number.isFinite(issuedAtSec) ||
        authTime < issuedAtSec
      ) {
        throw new HttpsError(
          'failed-precondition',
          'Confirm your Master Admin password again to reveal this LRN.',
        );
      }
    }

    const fullLrn = await resolveSchoolScopedTargetLrn(
      db,
      tx,
      admin.schoolId,
      targetType,
      targetId,
    );

    tx.update(challengeRef, {consumedAt: FieldValue.serverTimestamp()});
    tx.create(
      db.doc(`staffManagementAudits/${randomBytes(16).toString('hex')}`),
      auditRecord({
        actorUid: adminUid,
        actorRole: admin.role,
        schoolId: admin.schoolId,
        action: 'reveal_student_lrn',
        targetUid: targetId,
        outcome: 'allowed',
        reason: `method:${authMethod};targetType:${targetType}`,
      }),
    );

    return {lrn: fullLrn, maskedLrn: maskLrn(fullLrn)!};
  });
});
