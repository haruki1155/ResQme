import { HttpsError, onCall } from 'firebase-functions/v2/https';
import {getApps, initializeApp} from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import {noticeVersion, validateRegistration} from './registration_contract';
import {isStudentAccountDisabled, resqmeRuntimeOptions} from '../onboarding/authorization';
import {evaluateRosterClaim,matchingRosterSchool,rosterCodeDigest,rosterLookupId,type SchoolRosterRecord} from '../school/roster_contract';

function computeAgeFromIsoBirthDate(birthDate: unknown, now = new Date()): number | null {
  if (typeof birthDate !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(birthDate)) return null;
  const [y, m, d] = birthDate.split('-').map(Number);
  const utc = new Date(Date.UTC(y, m - 1, d));
  if (utc.getUTCFullYear() !== y || utc.getUTCMonth() !== m - 1 || utc.getUTCDate() !== d) return null;
  let age = now.getUTCFullYear() - y;
  const monthDiff = now.getUTCMonth() + 1 - m;
  if (monthDiff < 0 || (monthDiff === 0 && now.getUTCDate() < d)) age -= 1;
  return age >= 0 && age <= 130 ? age : null;
}

export const createStudentRegistration = onCall(resqmeRuntimeOptions, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in is required.');
  const data = request.data as Record<string, unknown>;
  let registration; try { registration=validateRegistration({fullName:typeof data?.fullName==='string'?data.fullName:'',ageYears:data?.ageYears as number,noticeVersion:data?.noticeVersion as string,acknowledgmentAccepted:data?.acknowledgmentAccepted===true,lrn:data?.lrn,enrollmentCode:data?.enrollmentCode,gender:data?.gender,personalPhone:data?.personalPhone,guardianName:data?.guardianName,guardianRelationship:data?.guardianRelationship,guardianPhone:data?.guardianPhone,secondaryName:data?.secondaryName,secondaryPhone:data?.secondaryPhone}); } catch { throw new HttpsError('invalid-argument','Invalid registration request.'); }
  if (!getApps().some(app => app.name === '[DEFAULT]')) initializeApp();
  const db = getFirestore(); const profile = db.doc(`studentProfiles/${request.auth.uid}`); const acknowledgment = profile.collection('acknowledgments').doc(noticeVersion);
  const rosterKey=process.env.RESQME_SCHOOL_ROSTER_HMAC_KEY;
  if(rosterKey&&Buffer.byteLength(rosterKey,'utf8')<32) throw new HttpsError('failed-precondition','Registration verification is unavailable.');
  const rosterRef=rosterKey?db.doc(`schoolRosterClaims/${rosterLookupId(registration.lrn,rosterKey)}`):undefined;
  const codeDigest=rosterKey&&registration.enrollmentCode?rosterCodeDigest(registration.enrollmentCode,rosterKey):null;
  const codeClaimRef=codeDigest?db.doc(`schoolRosterCodes/${codeDigest}`):undefined;
  await db.runTransaction(async (tx) => {
    const existing = await tx.get(profile);
    const rosterSnapshot=rosterRef?await tx.get(rosterRef):undefined;
    const codeClaimSnapshot=codeClaimRef?await tx.get(codeClaimRef):undefined;
    if (existing.exists) {
      if (isStudentAccountDisabled(existing.data())) {
        throw new HttpsError('permission-denied', 'Student account is disabled.');
      }
      if (existing.get('fullName') !== registration.fullName || existing.get('ageYearsAtRegistration') !== registration.ageYears || existing.get('lrn')!==registration.lrn) {
        throw new HttpsError('already-exists', 'Registration already submitted.');
      }
      const oldContacts = existing.get('emergencyContacts');
      const emptyContacts = {primary:{fullName:null,relationship:null,phoneNumber:null},secondary:{fullName:null,phoneNumber:null}};
      const expected = registration.emergencyContacts;
      const previous = oldContacts ?? emptyContacts;
      if ((existing.get('gender') ?? null) !== registration.gender || (existing.get('personalContactNumber') ?? null) !== registration.personalContactNumber ||
          previous.primary?.fullName !== expected.primary.fullName || previous.primary?.relationship !== expected.primary.relationship || previous.primary?.phoneNumber !== expected.primary.phoneNumber ||
          previous.secondary?.fullName !== expected.secondary.fullName || previous.secondary?.phoneNumber !== expected.secondary.phoneNumber) {
        throw new HttpsError('already-exists', 'Registration already submitted.');
      }
      return;
    }
    const rosterRaw = rosterSnapshot?.data() as (SchoolRosterRecord & {gradeLevel?: unknown; birthDate?: unknown}) | undefined;
    const assignmentSchoolId=matchingRosterSchool(rosterRaw,registration.fullName);
    const lrnLockRef = assignmentSchoolId ? db.doc(`studentLrnLocks/${assignmentSchoolId}_${registration.lrn}`) : null;
    const lrnLockSnap = lrnLockRef ? await tx.get(lrnLockRef) : null;
    const lrnLockedByOther = Boolean(lrnLockSnap?.exists && lrnLockSnap.get('studentUid') !== request.auth!.uid);

    const rawVerification=rosterKey?evaluateRosterClaim({roster:rosterRaw,codeClaim:codeClaimSnapshot?.data(),rosterId:rosterRef?.id,lrn:registration.lrn,fullName:registration.fullName,enrollmentCode:registration.enrollmentCode,uid:request.auth!.uid,key:rosterKey}):'manual_review';
    const verification = lrnLockedByOther ? 'conflict' : rawVerification;
    const autoApproved=verification==='auto_approve'&&!!assignmentSchoolId&&!!rosterRef&&!lrnLockedByOther;

    // Trusted roster gradeLevel and authoritative birthDate/age cannot be overridden by student-supplied age.
    const trustedGradeLevel = assignmentSchoolId && typeof rosterRaw?.gradeLevel === 'string' && rosterRaw.gradeLevel.trim().length > 0
      ? rosterRaw.gradeLevel.trim()
      : null;
    const trustedBirthDate = assignmentSchoolId && typeof rosterRaw?.birthDate === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(rosterRaw.birthDate)
      ? rosterRaw.birthDate
      : null;
    const trustedAge = computeAgeFromIsoBirthDate(trustedBirthDate);
    const effectiveAge = trustedAge ?? registration.ageYears;
    const effectiveStatus = effectiveAge < 18 ? 'pending_guardian' : 'pending_review';

    if(autoApproved){
      tx.update(rosterRef!,{claimedByUid:request.auth!.uid,claimedAt:FieldValue.serverTimestamp(),enrollmentCodeDigest:null});
      tx.update(codeClaimRef!,{claimedByUid:request.auth!.uid,claimedAt:FieldValue.serverTimestamp()});
      if (lrnLockRef && !lrnLockSnap?.exists) {
        tx.create(lrnLockRef, {studentUid: request.auth!.uid, schoolId: assignmentSchoolId, method: 'roster', recordedAt: FieldValue.serverTimestamp()});
      }
    }
    tx.create(profile, {
      schemaVersion: 1,
      fullName: registration.fullName,
      ageYearsAtRegistration: effectiveAge,
      ...(trustedBirthDate ? {birthDate: trustedBirthDate} : {}),
      ...(trustedGradeLevel ? {gradeLevel: trustedGradeLevel} : {}),
      status: effectiveStatus,
      schoolApprovalStatus: autoApproved ? 'approved' : 'pending',
      schoolAssignmentStatus: assignmentSchoolId ? 'assigned' : 'unassigned',
      schoolId: assignmentSchoolId,
      schoolVerificationMethod: autoApproved ? 'roster' : null,
      schoolVerificationOutcome: autoApproved ? 'verified' : (verification === 'conflict' ? 'conflict' : 'manual_review'),
      medicalStatus: 'not_started',
      medicalRevision: 0,
      lrn: registration.lrn,
      gender: registration.gender,
      personalContactNumber: registration.personalContactNumber,
      emergencyContacts: registration.emergencyContacts,
      createdAt: FieldValue.serverTimestamp(),
    });
    tx.create(acknowledgment, {affirmativeAction: true, actorUid: request.auth!.uid, serverTimestamp: FieldValue.serverTimestamp()});
  });
  const result = await profile.get(); return {status: result.get('status'), profilePath: profile.path};
});
