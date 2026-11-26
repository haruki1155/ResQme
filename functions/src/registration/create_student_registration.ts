import {randomBytes} from 'node:crypto';
import {getApps, initializeApp} from 'firebase-admin/app';
import {FieldValue, getFirestore, type Firestore} from 'firebase-admin/firestore';
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {isStudentAccountDisabled, resqmeRuntimeOptions} from '../onboarding/authorization';
import {evaluateQrEligibility} from '../qr/qr_eligibility';
import {hashQrPayload} from '../qr/resolve_tier1_qr';
import {
  canonicalizeRosterNameInput,
  evaluateRosterClaim,
  matchingRosterSchool,
  rosterCodeDigest,
  rosterLookupId,
  type SchoolRosterRecord,
} from '../school/roster_contract';
import {enforceTransactionalRateLimit} from '../staff/staff_student_management';
import {noticeVersion, parseIsoBirthDate, validateRegistration} from './registration_contract';

export const registrationDeps = {
  db(): Firestore {
    if (!getApps().some((app) => app.name === '[DEFAULT]')) {
      initializeApp();
    }
    return getFirestore();
  },
};

type RosterRowData = SchoolRosterRecord & {
  fullName?: unknown;
  gradeLevel?: unknown;
  birthDate?: unknown;
  sex?: unknown;
};

type VerificationEvaluation = {
  assignmentSchoolId: string | null;
  rosterSchoolId: string | null;
  lrnLockedByOther: boolean;
  verification: 'auto_approve' | 'manual_review' | 'conflict';
  autoApproved: boolean;
};

function computeAgeFromIsoBirthDate(birthDate: unknown, now = new Date()): number | null {
  try {
    return parseIsoBirthDate(birthDate, now)?.ageYears ?? null;
  } catch {
    return null;
  }
}

function evaluateRosterRegistrationAttempt(input: {
  rosterRaw: RosterRowData | undefined;
  codeClaim: {rosterId?: string; claimedByUid?: string | null} | undefined;
  rosterId: string | undefined;
  lrn: string;
  fullName: string;
  birthDate: string | null;
  enrollmentCode: string | null;
  uid: string;
  rosterKey: string | undefined;
  lrnLockSnap: FirebaseFirestore.DocumentSnapshot | null;
}): VerificationEvaluation {
  const rosterSchoolId =
    typeof input.rosterRaw?.schoolId === 'string' &&
    /^[a-z0-9][a-z0-9_-]{1,63}$/.test(input.rosterRaw.schoolId)
      ? input.rosterRaw.schoolId
      : null;

  const assignmentSchoolId = matchingRosterSchool(
    input.rosterRaw,
    input.fullName,
    input.birthDate,
  );
  const lockOwner = input.lrnLockSnap?.get('uid') ?? input.lrnLockSnap?.get('studentUid');
  const lrnLockedByOther = Boolean(
    input.lrnLockSnap?.exists &&
      input.lrnLockSnap.get('status') !== 'released' &&
      lockOwner &&
      lockOwner !== input.uid,
  );

  const rawVerification = input.rosterKey
    ? evaluateRosterClaim({
        roster: input.rosterRaw,
        codeClaim: input.codeClaim,
        rosterId: input.rosterId,
        lrn: input.lrn,
        fullName: input.fullName,
        birthDate: input.birthDate,
        enrollmentCode: input.enrollmentCode,
        uid: input.uid,
        key: input.rosterKey,
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
    !!input.rosterId &&
    !lrnLockedByOther;

  return {
    assignmentSchoolId,
    rosterSchoolId,
    lrnLockedByOther,
    verification,
    autoApproved,
  };
}

function recordAutoVerifyClaimInTx(input: {
  db: Firestore;
  tx: FirebaseFirestore.Transaction;
  uid: string;
  lrn: string;
  schoolId: string;
  rosterRef: FirebaseFirestore.DocumentReference;
  codeClaimRef: FirebaseFirestore.DocumentReference;
  lrnLockRef: FirebaseFirestore.DocumentReference | null;
}) {
  input.tx.update(input.rosterRef, {
    claimedByUid: input.uid,
    claimedAt: FieldValue.serverTimestamp(),
    enrollmentCodeDigest: null,
  });
  input.tx.update(input.codeClaimRef, {
    claimedByUid: input.uid,
    claimedAt: FieldValue.serverTimestamp(),
  });
  if (input.lrnLockRef) {
    input.tx.set(
      input.lrnLockRef,
      {
        uid: input.uid,
        studentUid: input.uid,
        lrn: input.lrn,
        schoolId: input.schoolId,
        status: 'active',
        method: 'roster',
        recordedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
  }
  input.tx.create(input.db.doc(`staffManagementAudits/${randomBytes(16).toString('hex')}`), {
    actorUid: input.uid,
    actorRole: 'student',
    schoolId: input.schoolId,
    action: 'auto_verify_student_roster',
    targetUid: input.uid,
    method: 'roster',
    outcome: 'allowed',
    createdAt: FieldValue.serverTimestamp(),
  });
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
  if (
    (!rosterKey && registration.enrollmentCode) ||
    (rosterKey && Buffer.byteLength(rosterKey, 'utf8') < 32)
  ) {
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

    const lrnLockSchoolId =
      typeof rosterRaw?.schoolId === 'string' && /^[a-z0-9][a-z0-9_-]{1,63}$/.test(rosterRaw.schoolId)
        ? rosterRaw.schoolId
        : null;
    const lrnLockRef = lrnLockSchoolId
      ? db.doc(`studentLrnLocks/${lrnLockSchoolId}_${registration.lrn}`)
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

    const evalResult = evaluateRosterRegistrationAttempt({
      rosterRaw,
      codeClaim: codeClaimSnapshot?.data(),
      rosterId: rosterRef?.id,
      lrn: registration.lrn,
      fullName: registration.fullName,
      birthDate: registration.birthDate,
      enrollmentCode: registration.enrollmentCode,
      uid,
      rosterKey,
      lrnLockSnap,
    });
    const {
      assignmentSchoolId,
      rosterSchoolId,
      verification,
      autoApproved,
    } = evalResult;

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
      recordAutoVerifyClaimInTx({
        db,
        tx,
        uid,
        lrn: registration.lrn,
        schoolId: assignmentSchoolId!,
        rosterRef: rosterRef!,
        codeClaimRef: codeClaimRef!,
        lrnLockRef,
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

export const claimMyRosterVerification = onCall(resqmeRuntimeOptions, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in is required.');
  const data = request.data as Record<string, unknown>;
  const fullNameRaw = typeof data?.fullName === 'string' ? data.fullName.trim() : '';
  const lrnRaw = typeof data?.lrn === 'string' ? data.lrn.trim() : '';
  const codeRaw =
    typeof data?.enrollmentCode === 'string' ? data.enrollmentCode.trim().toUpperCase() : '';
  let parsedBirth: {birthDate: string; ageYears: number} | null = null;
  try {
    parsedBirth = parseIsoBirthDate(data?.birthDate);
  } catch {
    throw new HttpsError('invalid-argument', 'Enter a valid birth date in YYYY-MM-DD format.');
  }
  if (
    fullNameRaw.length < 2 ||
    fullNameRaw.length > 120 ||
    !parsedBirth ||
    !/^\d{12}$/.test(lrnRaw) ||
    !/^[A-Z0-9_-]{16,128}$/.test(codeRaw)
  ) {
    throw new HttpsError(
      'invalid-argument',
      'Provide your full name, birth date (YYYY-MM-DD), 12-digit LRN, and enrollment code.',
    );
  }

  const rosterKey = process.env.RESQME_SCHOOL_ROSTER_HMAC_KEY;
  if (!rosterKey || Buffer.byteLength(rosterKey, 'utf8') < 32) {
    throw new HttpsError('failed-precondition', 'Automatic roster verification is unavailable.');
  }

  const uid = request.auth.uid;
  const db = registrationDeps.db();
  await enforceTransactionalRateLimit(
    db,
    `studentRosterClaimRateLimits/${uid}`,
    10,
    'Too many verification attempts. Wait a few minutes before trying again.',
  );

  const profileRef = db.doc(`studentProfiles/${uid}`);
  const rosterRef = db.doc(`schoolRosterClaims/${rosterLookupId(lrnRaw, rosterKey)}`);
  const codeClaimRef = db.doc(`schoolRosterCodes/${rosterCodeDigest(codeRaw, rosterKey)}`);
  const credentialRef = db.doc(`studentQrCredentials/${uid}`);
  const medicalRef = db.doc(`studentMedicalRecords/${uid}`);
  const guardianRef = db.doc(`studentGuardianAuthorizations/${uid}`);

  return db.runTransaction(async (tx) => {
    const [existing, rosterSnapshot, codeClaimSnapshot, credentialSnap, medicalSnap, guardianSnap] =
      await Promise.all([
        tx.get(profileRef),
        tx.get(rosterRef),
        tx.get(codeClaimRef),
        tx.get(credentialRef),
        tx.get(medicalRef),
        tx.get(guardianRef),
      ]);

    const existingData = existing.data();
    if (!existing.exists || !existingData || existingData.schemaVersion !== 1) {
      throw new HttpsError('failed-precondition', 'Complete registration before verifying enrollment.');
    }
    if (isStudentAccountDisabled(existingData)) {
      throw new HttpsError('permission-denied', 'Student account is disabled.');
    }
    if (existingData.schoolApprovalStatus === 'revoked') {
      throw new HttpsError('failed-precondition', 'School verification is unavailable for this account.');
    }
    if (existingData.schoolApprovalStatus === 'approved') {
      return {
        verified: true,
        status: existingData.status,
        schoolApprovalStatus: 'approved',
        schoolVerificationOutcome: 'verified',
      };
    }

    const rosterRaw = rosterSnapshot.data() as RosterRowData | undefined;
    const rosterSchoolId =
      typeof rosterRaw?.schoolId === 'string' && /^[a-z0-9][a-z0-9_-]{1,63}$/.test(rosterRaw.schoolId)
        ? rosterRaw.schoolId
        : null;
    const lrnLockRef = rosterSchoolId ? db.doc(`studentLrnLocks/${rosterSchoolId}_${lrnRaw}`) : null;
    const lrnLockSnap = lrnLockRef ? await tx.get(lrnLockRef) : null;

    const evalResult = evaluateRosterRegistrationAttempt({
      rosterRaw,
      codeClaim: codeClaimSnapshot.data(),
      rosterId: rosterRef.id,
      lrn: lrnRaw,
      fullName: fullNameRaw,
      birthDate: parsedBirth!.birthDate,
      enrollmentCode: codeRaw,
      uid,
      rosterKey,
      lrnLockSnap,
    });

    if (!evalResult.autoApproved || !evalResult.assignmentSchoolId) {
      throw new HttpsError(
        'failed-precondition',
        'Details did not match an unclaimed official school roster record. Check your full name, birth date (YYYY-MM-DD), 12-digit LRN, and enrollment code.',
      );
    }

    const trustedBirthDate =
      typeof rosterRaw?.birthDate === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(rosterRaw.birthDate)
        ? rosterRaw.birthDate
        : parsedBirth!.birthDate;
    const effectiveAge =
      computeAgeFromIsoBirthDate(trustedBirthDate) ?? parsedBirth!.ageYears;
    const effectiveStatus = effectiveAge < 18 ? 'pending_guardian' : 'pending_review';
    const canonicalFullName =
      typeof rosterRaw?.fullName === 'string' && rosterRaw.fullName.trim().length >= 2
        ? rosterRaw.fullName.trim()
        : fullNameRaw;
    const trustedGradeLevel =
      typeof rosterRaw?.gradeLevel === 'string' && rosterRaw.gradeLevel.trim().length > 0
        ? rosterRaw.gradeLevel.trim()
        : null;
    const trustedRosterSex =
      typeof rosterRaw?.sex === 'string' && rosterRaw.sex.trim().length > 0
        ? rosterRaw.sex.trim()
        : null;

    const profilePatch: Record<string, unknown> = {
      fullName: canonicalFullName,
      lrn: lrnRaw,
      birthDate: trustedBirthDate,
      ageYearsAtRegistration: effectiveAge,
      status: effectiveStatus,
      schoolApprovalStatus: 'approved',
      schoolAssignmentStatus: 'assigned',
      schoolId: evalResult.assignmentSchoolId,
      schoolVerificationMethod: 'roster',
      schoolVerificationOutcome: 'verified',
      updatedAt: FieldValue.serverTimestamp(),
    };
    if (trustedGradeLevel) {
      profilePatch.gradeLevel = trustedGradeLevel;
    }
    if (!existingData.gender && trustedRosterSex) {
      profilePatch.gender = trustedRosterSex;
    }

    const payload = credentialSnap.get('payload');
    const lookupRef =
      credentialSnap.get('verificationStatus') === 'pending' && typeof payload === 'string'
        ? db.doc(`studentQrLookups/${hashQrPayload(payload)}`)
        : null;
    const lookupSnap = lookupRef ? await tx.get(lookupRef) : null;

    recordAutoVerifyClaimInTx({
      db,
      tx,
      uid,
      lrn: lrnRaw,
      schoolId: evalResult.assignmentSchoolId,
      rosterRef,
      codeClaimRef,
      lrnLockRef,
    });
    tx.update(profileRef, profilePatch);

    if (
      lookupRef && lookupSnap?.exists &&
      evaluateQrEligibility({
        uid,
        profile: {...existingData, ...profilePatch},
        medical: medicalSnap.data(),
        guardianAuthorization: guardianSnap.data(),
        credential: credentialSnap.data(),
        lookup: lookupSnap.data(),
      })
    ) {
      tx.update(credentialRef, {
        verificationStatus: 'active',
        activatedAt: FieldValue.serverTimestamp(),
      });
      tx.update(lookupRef, {
        status: 'active',
        activatedAt: FieldValue.serverTimestamp(),
      });
    }

    return {
      verified: true,
      status: effectiveStatus,
      schoolApprovalStatus: 'approved',
      schoolVerificationOutcome: 'verified',
    };
  });
});
