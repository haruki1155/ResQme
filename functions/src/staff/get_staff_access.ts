import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {keys, object} from '../medical/medical_contract';
import {onboardingDatabase, resqmeRuntimeOptions} from '../onboarding/authorization';
import {requireStaff} from './staff_authorization';

export const getStaffAccess = onCall(resqmeRuntimeOptions, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Sign in is required.');
  }
  keys(object(request.data ?? {}), []);
  const db = onboardingDatabase(uid);
  const scope = await requireStaff(db, uid, undefined, undefined, {
    requireSetupComplete: false,
    emailVerified: request.auth?.token.email_verified === true,
  });
  return {
    role: scope.role,
    schoolId: scope.schoolId,
    active: scope.active,
    isMasterAdmin: scope.isMasterAdmin,
    mustChangePassword: scope.mustChangePassword,
    requiresEmailVerification: scope.requiresEmailVerification,
    emailVerified: scope.emailVerified,
    fullName: scope.fullName,
    position: scope.position,
    loginId: scope.loginId,
  };
});
