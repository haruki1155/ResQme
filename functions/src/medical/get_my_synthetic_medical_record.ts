import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {onboardingDatabase, requirePending, resqmeRuntimeOptions} from '../onboarding/authorization';
import {keys, object} from './medical_contract';
import {requireRecentAuth} from './tier2_challenge';

function validateEmptyRequest(value: unknown): void {
  keys(object(value), []);
}

function sanitizeSyntheticAnswer(value: unknown): {state: string; details: string | null} | null {
  if (value == null) return null;
  if (typeof value !== 'object' || Array.isArray(value)) {
    throw new HttpsError('failed-precondition', 'Test record unavailable.');
  }
  const data = value as Record<string, unknown>;
  if (
    !['unknown', 'none_known', 'listed'].includes(data.state as string) ||
    (data.details !== null && data.details !== undefined && typeof data.details !== 'string')
  ) {
    throw new HttpsError('failed-precondition', 'Test record unavailable.');
  }
  const details = data.state === 'listed' ? (data.details as string) : null;
  if (data.state === 'listed' && (!details || !details.trim())) {
    throw new HttpsError('failed-precondition', 'Test record unavailable.');
  }
  return {state: data.state as string, details};
}

/**
 * Metadata-only owner medical status projection.
 * Never returns conditions, allergies, emergency contacts, or LRN.
 */
export const getMyMedicalRecordStatus = onCall(resqmeRuntimeOptions, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in is required.');
  validateEmptyRequest(request.data);
  const db = onboardingDatabase(uid);
  const profileSnap = await db.doc(`studentProfiles/${uid}`).get();
  if (!profileSnap.exists) {
    throw new HttpsError('not-found', 'Profile unavailable.');
  }
  const profile = requirePending(profileSnap.data());
  const medicalStatus = typeof profile.medicalStatus === 'string' ? profile.medicalStatus : 'not_started';
  const revision = Number.isSafeInteger(profile.medicalRevision) && Number(profile.medicalRevision) >= 0
    ? Number(profile.medicalRevision)
    : 0;
  return {
    medicalStatus,
    revision,
    completed: medicalStatus === 'complete' || medicalStatus === 'completed_synthetic',
  };
});

/**
 * Purpose-scoped owner reader for the synthetic pilot medical editor.
 * Requires fresh owner authentication and enabled qaTester flag; refuses production medical records.
 */
export const getMySyntheticMedicalRecord = onCall(resqmeRuntimeOptions, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in is required.');
  requireRecentAuth(request.auth?.token.auth_time);
  validateEmptyRequest(request.data);
  const db = onboardingDatabase(uid);

  const [qaSnap, profileSnap, recordSnap] = await Promise.all([
    db.doc(`qaTesters/${uid}`).get(),
    db.doc(`studentProfiles/${uid}`).get(),
    db.doc(`studentMedicalRecords/${uid}`).get(),
  ]);
  if (qaSnap.get('enabled') !== true || qaSnap.get('syntheticOnly') !== true) {
    throw new HttpsError('permission-denied', 'Test record access is not enabled for this account.');
  }
  const owner = requirePending(profileSnap.data());
  const data = recordSnap.exists ? recordSnap.data() : undefined;
  if (data) {
    if (
      data.schemaVersion !== 1 ||
      data.syntheticOnly !== true ||
      data.guardianAuthorizationStatus !== 'not_verified' ||
      !Number.isSafeInteger(data.revision) ||
      !['not_started', 'completed_synthetic'].includes(data.medicalStatus as string)
    ) {
      throw new HttpsError('failed-precondition', 'Test record unavailable.');
    }
  }
  const rawContacts = owner.emergencyContacts as Record<string, unknown> | undefined;
  const rawPrimary = rawContacts && typeof rawContacts.primary === 'object' && rawContacts.primary
    ? (rawContacts.primary as Record<string, unknown>)
    : undefined;
  const primaryContact = {
    fullName: typeof rawPrimary?.fullName === 'string' ? rawPrimary.fullName : null,
    relationship: typeof rawPrimary?.relationship === 'string' ? rawPrimary.relationship : null,
    phoneNumber: typeof rawPrimary?.phoneNumber === 'string' ? rawPrimary.phoneNumber : null,
  };
  const medicalStatus = (data?.medicalStatus as string | undefined) ?? 'not_started';
  const revision = (data?.revision as number | undefined) ?? 0;
  return {
    revision,
    medicalStatus,
    completed: medicalStatus === 'completed_synthetic',
    primaryContact,
    conditions: medicalStatus === 'not_started' ? null : sanitizeSyntheticAnswer(data?.conditions),
    allergies: medicalStatus === 'not_started' ? null : sanitizeSyntheticAnswer(data?.allergies),
  };
});
