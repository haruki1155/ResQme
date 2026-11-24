import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {keys, object} from '../medical/medical_contract';
import {onboardingDatabase, resqmeRuntimeOptions} from '../onboarding/authorization';
import {requireStaff} from './staff_authorization';

export const getStaffAccess = onCall(resqmeRuntimeOptions, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Sign in is required.');
  }
  keys(object(request.data), []);
  const db = onboardingDatabase(uid);
  return requireStaff(db, uid);
});
