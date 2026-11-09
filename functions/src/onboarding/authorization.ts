import {getApps, initializeApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import {HttpsError} from 'firebase-functions/v2/https';
export const resqmeRuntimeOptions = {
  serviceAccount:'resqme-functions-runtime@resqme-943ee.iam.gserviceaccount.com',
} as const;
export function onboardingDatabase(uid:string|undefined) {
  if(!uid) throw new HttpsError('unauthenticated','Sign in is required.');
  const project=process.env.GCLOUD_PROJECT||process.env.GOOGLE_CLOUD_PROJECT;
  if(!['demo-resqme','resqme-943ee'].includes(project??'')) throw new HttpsError('failed-precondition','Pilot backend is not configured.');
  if(!getApps().some(app=>app.name==='[DEFAULT]')) initializeApp();
  return getFirestore();
}
export function requirePending(data:FirebaseFirestore.DocumentData|undefined) {
  if(!data||data.schemaVersion!==1||!['pending_guardian','pending_review'].includes(data.status)||!Number.isInteger(data.ageYearsAtRegistration)||data.ageYearsAtRegistration<0||data.ageYearsAtRegistration>130) throw new HttpsError('failed-precondition','A pending registration is required.');
  return data;
}
export function requireQrEligible(data:FirebaseFirestore.DocumentData|undefined) {
  if(!data||data.schemaVersion!==1||!['pending_review','pending_guardian'].includes(data.status)||
    data.schoolAssignmentStatus!=='assigned'||typeof data.schoolId!=='string'||!/^[a-z0-9][a-z0-9_-]{1,63}$/.test(data.schoolId)||
    data.schoolApprovalStatus!=='approved'||data.medicalStatus!=='complete'||
    !Number.isSafeInteger(data.medicalRevision)||data.medicalRevision<1) {
    throw new HttpsError('failed-precondition','QR credential unavailable.');
  }
  return data;
}
