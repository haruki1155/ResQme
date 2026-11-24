import type {Firestore, Transaction} from 'firebase-admin/firestore';
import {HttpsError} from 'firebase-functions/v2/https';

export type StaffRole = 'admin' | 'authorized';

export interface StaffAccessScope {
  role: StaffRole;
  schoolId: string;
  active: true;
  isMasterAdmin: boolean;
  mustChangePassword: boolean;
  requiresEmailVerification: boolean;
  emailVerified: boolean;
  fullName: string | null;
  position: string | null;
  loginId: string | null;
}

export interface StaffAuthOptions {
  requireSetupComplete?: boolean;
  emailVerified?: boolean;
}

const SCHOOL_ID_PATTERN = /^[a-z0-9][a-z0-9_-]{1,63}$/;
const ALLOWED_ROLES: readonly StaffRole[] = ['admin', 'authorized'];

export function assertStaffAccount(
  data: Record<string, unknown> | undefined,
  allowedRoles: readonly StaffRole[] = ALLOWED_ROLES,
  options: StaffAuthOptions = {},
): StaffAccessScope {
  if (
    !data ||
    data.active !== true ||
    (data.status !== undefined && data.status !== 'active') ||
    typeof data.role !== 'string' ||
    !ALLOWED_ROLES.includes(data.role as StaffRole) ||
    !allowedRoles.includes(data.role as StaffRole) ||
    typeof data.schoolId !== 'string' ||
    !SCHOOL_ID_PATTERN.test(data.schoolId)
  ) {
    throw new HttpsError('permission-denied', 'Staff access is unavailable.');
  }

  const isMasterAdmin = data.isMasterAdmin === true && data.role === 'admin';
  const mustChangePassword = data.mustChangePassword === true;
  const requiresEmailVerification = data.requiresEmailVerification === true;
  const emailVerified = options.emailVerified === true;

  if (options.requireSetupComplete !== false) {
    if (mustChangePassword) {
      throw new HttpsError(
        'failed-precondition',
        'Password setup is required before continuing.',
      );
    }
    if (requiresEmailVerification && !emailVerified) {
      throw new HttpsError(
        'failed-precondition',
        'Email verification is required before continuing.',
      );
    }
  }

  return {
    role: data.role as StaffRole,
    schoolId: data.schoolId,
    active: true,
    isMasterAdmin,
    mustChangePassword,
    requiresEmailVerification,
    emailVerified,
    fullName: typeof data.fullName === 'string' ? data.fullName : null,
    position: typeof data.position === 'string' ? data.position : null,
    loginId: typeof data.loginId === 'string' ? data.loginId : null,
  };
}

export async function requireStaff(
  db: Firestore,
  uid: string | undefined,
  allowedRoles: readonly StaffRole[] = ALLOWED_ROLES,
  tx?: Transaction,
  options: StaffAuthOptions = {},
): Promise<StaffAccessScope> {
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Sign in is required.');
  }
  const ref = db.doc(`staffAccounts/${uid}`);
  const snap = tx ? await tx.get(ref) : await ref.get();
  return assertStaffAccount(
    snap.exists ? snap.data() : undefined,
    allowedRoles,
    options,
  );
}
