import { HttpsError, onCall } from 'firebase-functions/v2/https';
import {getApps, initializeApp} from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import {noticeVersion, validateRegistration} from './registration_contract';
import {resqmeRuntimeOptions} from '../onboarding/authorization';
export const createStudentRegistration = onCall(resqmeRuntimeOptions, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in is required.');
  const data = request.data as Record<string, unknown>;
  let registration; try { registration=validateRegistration({fullName:typeof data?.fullName==='string'?data.fullName:'',ageYears:data?.ageYears as number,noticeVersion:data?.noticeVersion as string,acknowledgmentAccepted:data?.acknowledgmentAccepted===true,gender:data?.gender,personalPhone:data?.personalPhone,guardianName:data?.guardianName,guardianRelationship:data?.guardianRelationship,guardianPhone:data?.guardianPhone,secondaryName:data?.secondaryName,secondaryPhone:data?.secondaryPhone}); } catch { throw new HttpsError('invalid-argument','Invalid registration request.'); }
  if (!getApps().some(app => app.name === '[DEFAULT]')) initializeApp();
  const db = getFirestore(); const profile = db.doc(`studentProfiles/${request.auth.uid}`); const acknowledgment = profile.collection('acknowledgments').doc(noticeVersion);
  await db.runTransaction(async (tx) => {
    const existing = await tx.get(profile);
    if (existing.exists) {
      if (existing.get('fullName') !== registration.fullName || existing.get('ageYearsAtRegistration') !== registration.ageYears) {
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
    tx.create(profile, {schemaVersion: 1, fullName:registration.fullName, ageYearsAtRegistration:registration.ageYears, status:registration.status, schoolApprovalStatus:'pending', schoolAssignmentStatus:'unassigned', medicalStatus:'not_started', medicalRevision:0, lrn: null, gender:registration.gender,personalContactNumber:registration.personalContactNumber,emergencyContacts:registration.emergencyContacts, createdAt: FieldValue.serverTimestamp()});
    tx.create(acknowledgment, {affirmativeAction: true, actorUid: request.auth!.uid, serverTimestamp: FieldValue.serverTimestamp()});
  });
  const result = await profile.get(); return {status: result.get('status'), profilePath: profile.path};
});
