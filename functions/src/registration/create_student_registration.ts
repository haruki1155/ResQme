import { HttpsError, onCall } from 'firebase-functions/v2/https';
import {getApps, initializeApp} from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import {noticeVersion, validateRegistration} from './registration_contract';
export const createStudentRegistration = onCall(async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in is required.');
  const data = request.data as Record<string, unknown>;
  let registration; try { registration=validateRegistration({fullName:typeof data.fullName==='string'?data.fullName:'',ageYears:data.ageYears as number,noticeVersion:data.noticeVersion as string,acknowledgmentAccepted:data.acknowledgmentAccepted===true,status:data.status,lrn:data.lrn}); } catch { throw new HttpsError('invalid-argument','Invalid registration request.'); }
  if (!getApps().some(app => app.name === '[DEFAULT]')) initializeApp();
  const db = getFirestore(); const profile = db.doc(`studentProfiles/${request.auth.uid}`); const acknowledgment = profile.collection('acknowledgments').doc(noticeVersion);
  await db.runTransaction(async (tx) => {
    const existing = await tx.get(profile);
    if (existing.exists) {
      if (existing.get('fullName') !== registration.fullName || existing.get('ageYearsAtRegistration') !== registration.ageYears) {
        throw new HttpsError('already-exists', 'Registration already submitted.');
      }
      return;
    }
    tx.create(profile, {schemaVersion: 1, fullName:registration.fullName, ageYearsAtRegistration:registration.ageYears, status:registration.status, lrn: null, schoolId: 'synthetic-pilot', createdAt: FieldValue.serverTimestamp()});
    tx.create(acknowledgment, {affirmativeAction: true, actorUid: request.auth!.uid, serverTimestamp: FieldValue.serverTimestamp()});
  });
  const result = await profile.get(); return {status: result.get('status'), profilePath: profile.path};
});
