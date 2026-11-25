import {randomBytes} from 'node:crypto';
import {getApps, initializeApp} from 'firebase-admin/app';
import {FieldValue, getFirestore, type Firestore} from 'firebase-admin/firestore';
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {isStudentAccountDisabled, resqmeRuntimeOptions} from '../onboarding/authorization';
import {
  canonicalizeRosterNameInput,
  evaluateRosterClaim,
  matchingRosterSchool,
  rosterCodeDigest,
  rosterLookupId,
  type SchoolRosterRecord,
} from '../school/roster_contract';
import {noticeVersion, parseIsoBirthDate, validateRegistration} from './registration_contract';

export const registrationDeps = {
  db(): Firestore {
    if (!getApps().some((app) => app.name === '[DEFAULT]')) {
      initializeApp();
    }
    return getFirestore();
  },
};

function computeAgeFromIsoBirthDate(birthDate: unknown, now = new Date()): number | null {
  try {
    return parseIsoBirthDate(birthDate, now)?.ageYears ?? null;
  } catch {
    return null;
  }
}

export const createStudentRegistration = onCall(resqmeRuntimeOptions, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in is required.');
  const data = request.data as Record<string, unknown>;
  let registration;
  try {
    registration = validateRegistration({
      fullName: typeof data?.fullName === 'string' ? data.fullName : '',
      ageYears: data?.ageYears as number | undefined,
      birthDate: data?.birthDate,
      noticeVersion: data?.noticeVersion as string,
      acknowledgmentAccepted: data?.acknowledgmentAccepted === true,
      lrn: data?.lrn,
      enrollmentCode: data?.enrollmentCode,
      gender: data?.gender,
      personalPhone: data?.personalPhone,
      guardianName: data?.guardianName,
      guardianRelationship: data?.guardianRelationship,
      guardianPhone: data?.guardianPhone,
      secondaryName: data?.secondaryName,
      secondaryPhone: data?.secondaryPhone,
    });
  } catch {
    throw new HttpsError('invalid-argument', 'Invalid registration request.');
  }

  const uid = request.auth.uid;
  const db = registrationDeps.db();
  const profile = db.doc(`studentProfiles/${uid}`);
  const acknowledgment = profile.collection('acknowledgments').doc(noticeVersion);
  const rosterKey = process.env.RESQME_SCHOOL_ROSTER_HMAC_KEY;
  if (rosterKey && Buffer.byteLength(rosterKey, 'utf8') < 32) {
    throw new HttpsError('failed-precondition', 'Registration verification is unavailable.');
  }
  const rosterRef = rosterKey
    ? db.doc(`schoolRosterClaims/${rosterLookupId(registration.lrn, rosterKey)}`)
    : undefined;
  const codeDigest =
    rosterKey && registration.enrollmentCode
      ? rosterCodeDigest(registration.enrollmentCode, rosterKey)
      : null;
  const codeClaimRef = codeDigest ? db.doc(`schoolRosterCodes/${codeDigest}`) : undefined;

  await db.runTransaction(async (tx) => {
    const existing = await tx.get(profile);
    const rosterSnapshot = rosterRef ? await tx.get(rosterRef) : undefined;
    const codeClaimSnapshot = codeClaimRef ? await tx.get(codeClaimRef) : undefined;

    const rosterRaw = rosterSnapshot?.data() as
      | (SchoolRosterRecord & {
          fullName?: unknown;
          gradeLevel?: unknown;
          birthDate?: unknown;
          sex?: unknown;
        })
      | undefined;

    const rosterSchoolId =
      typeof rosterRaw?.schoolId === 'string' && /^[a-z0-9][a-z0-9_-]{1,63}$/.test(rosterRaw.schoolId)
        ? rosterRaw.schoolId
        : null;
    const lrnLockRef = rosterSchoolId
      ? db.doc(`studentLrnLocks/${rosterSchoolId}_${registration.lrn}`)
      : null;
    const lrnLockSnap = lrnLockRef ? await tx.get(lrnLockRef) : null;

    if (existing.exists) {
      if (isStudentAccountDisabled(existing.data())) {
        throw new HttpsError('permission-denied', 'Student account is disabled.');
      }
      const existingName = String(existing.get('fullName') ?? '');
      const existingBirth = existing.get('birthDate') ?? null;
      const birthMismatch =
        registration.birthDate !== null && existingBirth !== registration.birthDate;
      const ageMismatch =
        registration.birthDate === null &&
        existing.get('ageYearsAtRegistration') !== registration.ageYears &&
        existingBirth === null;
      if (
        canonicalizeRosterNameInput(existingName) !==
          canonicalizeRosterNameInput(registration.fullName) ||
        ageMismatch ||
        birthMismatch ||
        existing.get('lrn') !== registration.lrn
      ) {
        throw new HttpsError('already-exists', 'Registration already submitted.');
      }
      const oldContacts = existing.get('emergencyContacts');
      const emptyContacts = {
        primary: {fullName: null, relationship: null, phoneNumber: null},
        secondary: {fullName: null, phoneNumber: null},
      };
      const expected = registration.emergencyContacts;
      const previous = oldContacts ?? emptyContacts;
      const expectedGender =
        registration.gender ??
        (existing.get('schoolVerificationMethod') === 'roster'
          ? (existing.get('gender') ?? null)
          : null);
      if (
        (existing.get('gender') ?? null) !== expectedGender ||
        (existing.get('personalContactNumber') ?? null) !== registration.personalContactNumber ||
        previous.primary?.fullName !== expected.primary.fullName ||
        previous.primary?.relationship !== expected.primary.relationship ||
        previous.primary?.phoneNumber !== expected.primary.phoneNumber ||
        previous.secondary?.fullName !== expected.secondary.fullName ||
        previous.secondary?.phoneNumber !== expected.secondary.phoneNumber
      ) {
        throw new HttpsError('already-exists', 'Registration already submitted.');
      }
      return;
    }

    const assignmentSchoolId = matchingRosterSchool(
      rosterRaw,
      registration.fullName,
      registration.birthDate,
    );
    const lockOwner = lrnLockSnap?.get('uid') ?? lrnLockSnap?.get('studentUid');
    const lrnLockedByOther = Boolean(
      lrnLockSnap?.exists &&
        lrnLockSnap.get('status') !== 'released' &&
        lockOwner &&
        lockOwner !== uid,
    );

    const rawVerification = rosterKey
      ? evaluateRosterClaim({
          roster: rosterRaw,
          codeClaim: codeClaimSnapshot?.data(),
          rosterId: rosterRef?.id,
          lrn: registration.lrn,
          fullName: registration.fullName,
          birthDate: registration.birthDate,
          enrollmentCode: registration.enrollmentCode,
          uid,
          key: rosterKey,
        })
      : 'manual_review';

    // Only surface 'conflict' when biographical identity matched the roster row;
    // mismatched biographical guesses stay 'manual_review' to prevent LRN claim enumeration.
    const verification =
      assignmentSchoolId && lrnLockedByOther
        ? 'conflict'
        : rawVerification === 'conflict' && !assignmentSchoolId
          ? 'manual_review'
          : rawVerification;
    const autoApproved =
      verification === 'auto_approve' &&
      !!assignmentSchoolId &&
      !!rosterRef &&
      !lrnLockedByOther;

    // Roster gradeLevel, sex, and canonical fullName are written to studentProfiles ONLY when
    // identity ownership is verified (autoApproved), preventing roster attribute disclosure
    // via owner profile reads on unverified/conflicted submissions.
    const trustedGradeLevel =
      autoApproved &&
      typeof rosterRaw?.gradeLevel === 'string' &&
      rosterRaw.gradeLevel.trim().length > 0
        ? rosterRaw.gradeLevel.trim()
        : null;
    const trustedBirthDate =
      assignmentSchoolId &&
      typeof rosterRaw?.birthDate === 'string' &&
      /^\d{4}-\d{2}-\d{2}$/.test(rosterRaw.birthDate)
        ? rosterRaw.birthDate
        : null;
    const trustedRosterSex =
      autoApproved && typeof rosterRaw?.sex === 'string' && rosterRaw.sex.trim().length > 0
        ? rosterRaw.sex.trim()
        : null;
    const effectiveBirthDate = autoApproved
      ? (trustedBirthDate ?? registration.birthDate)
      : registration.birthDate;
    const trustedAge = computeAgeFromIsoBirthDate(trustedBirthDate ?? registration.birthDate);
    const effectiveAge = trustedAge ?? registration.ageYears;
    const effectiveStatus = effectiveAge < 18 ? 'pending_guardian' : 'pending_review';
    const canonicalFullName =
      autoApproved &&
      typeof rosterRaw?.fullName === 'string' &&
      rosterRaw.fullName.trim().length >= 2
        ? rosterRaw.fullName.trim()
        : registration.fullName;

    if (autoApproved) {
      tx.update(rosterRef!, {
        claimedByUid: uid,
        claimedAt: FieldValue.serverTimestamp(),
        enrollmentCodeDigest: null,
      });
      tx.update(codeClaimRef!, {
        claimedByUid: uid,
        claimedAt: FieldValue.serverTimestamp(),
      });
      if (lrnLockRef) {
        tx.set(
          lrnLockRef,
          {
            uid,
            studentUid: uid,
            lrn: registration.lrn,
            schoolId: assignmentSchoolId,
            status: 'active',
            method: 'roster',
            recordedAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          },
          {merge: true},
        );
      }
      tx.create(db.doc(`staffManagementAudits/${randomBytes(16).toString('hex')}`), {
        actorUid: uid,
        actorRole: 'student',
        schoolId: assignmentSchoolId,
        action: 'auto_verify_student_roster',
        targetUid: uid,
        method: 'roster',
        outcome: 'allowed',
        createdAt: FieldValue.serverTimestamp(),
      });
    } else if (verification === 'conflict' && rosterSchoolId) {
      tx.create(db.doc(`staffManagementAudits/${randomBytes(16).toString('hex')}`), {
        actorUid: uid,
        actorRole: 'student',
        schoolId: rosterSchoolId,
        action: 'student_registration_conflict',
        targetUid: uid,
        outcome: 'denied',
        reason: 'lrn_or_roster_already_claimed',
        createdAt: FieldValue.serverTimestamp(),
      });
    }

    tx.create(profile, {
      schemaVersion: 1,
      fullName: canonicalFullName,
      ageYearsAtRegistration: effectiveAge,
      ...(effectiveBirthDate ? {birthDate: effectiveBirthDate} : {}),
      ...(trustedGradeLevel ? {gradeLevel: trustedGradeLevel} : {}),
      status: effectiveStatus,
      schoolApprovalStatus: autoApproved ? 'approved' : 'pending',
      schoolAssignmentStatus: assignmentSchoolId ? 'assigned' : 'unassigned',
      schoolId: assignmentSchoolId,
      schoolVerificationMethod: autoApproved ? 'roster' : null,
      schoolVerificationOutcome: autoApproved
          ? 'verified'
          : verification === 'conflict'
            ? 'conflict'
            : 'manual_review',
      medicalStatus: 'not_started',
      medicalRevision: 0,
      lrn: registration.lrn,
      gender: registration.gender ?? trustedRosterSex,
      personalContactNumber: registration.personalContactNumber,
      emergencyContacts: registration.emergencyContacts,
      createdAt: FieldValue.serverTimestamp(),
    });
    tx.create(acknowledgment, {
      affirmativeAction: true,
      actorUid: uid,
      serverTimestamp: FieldValue.serverTimestamp(),
    });
  });

  const result = await profile.get();
  return {status: result.get('status'), profilePath: profile.path};
});
