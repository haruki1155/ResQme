import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {onboardingDatabase, resqmeRuntimeOptions} from '../onboarding/authorization';
import {keys, object} from '../medical/medical_contract';

type ProfileData = Record<string, unknown>;

function isRecord(value: unknown): value is ProfileData {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function has(data: ProfileData, field: string): boolean {
  return Object.prototype.hasOwnProperty.call(data, field);
}

function optionalText(source: ProfileData, field: string, target: ProfileData) {
  if (!has(source, field)) return;
  const value = source[field];
  if (value !== null && typeof value !== 'string') {
    throw new HttpsError('failed-precondition', 'Profile unavailable.');
  }
  target[field] = value;
}

function contact(value: unknown): ProfileData | undefined {
  if (value == null) return;
  if (!isRecord(value)) {
    throw new HttpsError('failed-precondition', 'Profile unavailable.');
  }
  const result: ProfileData = {};
  for (const field of ['fullName', 'relationship', 'phoneNumber']) {
    optionalText(value, field, result);
  }
  return Object.keys(result).length ? result : undefined;
}

export function validateStudentProfileRequest(value: unknown): void {
  keys(object(value), []);
}

export function sanitizeStudentProfile(value: unknown): ProfileData {
  if (!isRecord(value) ||
      value.schemaVersion !== 1 ||
      typeof value.fullName !== 'string' ||
      value.fullName.trim().length < 2 ||
      !Number.isInteger(value.ageYearsAtRegistration) ||
      (value.ageYearsAtRegistration as number) < 0 ||
      (value.ageYearsAtRegistration as number) > 130 ||
      !['pending_review', 'pending_guardian'].includes(value.status as string) ||
      (value.lrn !== undefined && value.lrn !== null)) {
    throw new HttpsError('failed-precondition', 'Profile unavailable.');
  }

  const result: ProfileData = {
    schemaVersion: 1,
    fullName: value.fullName,
    ageYearsAtRegistration: value.ageYearsAtRegistration,
    status: value.status,
    schoolApprovalStatus: value.schoolApprovalStatus ?? 'pending',
    medicalStatus: value.medicalStatus ?? 'not_started',
    medicalRevision: value.medicalRevision ?? 0,
  };
  if(!['pending','approved','revoked'].includes(result.schoolApprovalStatus as string)||
     !['not_started','complete'].includes(result.medicalStatus as string)||
     !Number.isSafeInteger(result.medicalRevision)||Number(result.medicalRevision)<0) {
    throw new HttpsError('failed-precondition','Profile unavailable.');
  }
  optionalText(value, 'gender', result);
  optionalText(value, 'personalContactNumber', result);

  if (has(value, 'emergencyContacts') && value.emergencyContacts != null) {
    if (!isRecord(value.emergencyContacts)) {
      throw new HttpsError('failed-precondition', 'Profile unavailable.');
    }
    const emergencyContacts: ProfileData = {};
    for (const field of ['primary', 'secondary']) {
      const selected = contact(value.emergencyContacts[field]);
      if (selected) emergencyContacts[field] = selected;
    }
    if (Object.keys(emergencyContacts).length) {
      result.emergencyContacts = emergencyContacts;
    }
  }

  return result;
}

export const getMyStudentProfile = onCall(resqmeRuntimeOptions, async (request) => {
  const db = onboardingDatabase(request.auth?.uid);
  validateStudentProfileRequest(request.data);
  const snapshot = await db.doc(`studentProfiles/${request.auth!.uid}`).get();
  if (!snapshot.exists) {
    throw new HttpsError('not-found', 'Profile unavailable.');
  }
  return sanitizeStudentProfile(snapshot.data());
});
