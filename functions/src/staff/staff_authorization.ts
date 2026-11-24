import type {Firestore, Transaction} from 'firebase-admin/firestore';
import {HttpsError} from 'firebase-functions/v2/https';

export type StaffRole = 'admin' | 'authorized';

export interface StaffAccessScope {
  role: StaffRole;
  schoolId: string;
  active: true;
}

const SCHOOL_ID_PATTERN = /^[a-z0-9][a-z0-9_-]{1,63}$/;
const ALLOWED_ROLES: readonly StaffRole[] = ['admin', 'authorized'];

export function assertStaffAccount(
  data: Record<string, unknown> | undefined,
  allowedRoles: readonly StaffRole[] = ALLOWED_ROLES,
): StaffAccessScope {
  if (
    !data ||
    data.active !== true ||
    typeof data.role !== 'string' ||
    !ALLOWED_ROLES.includes(data.role as StaffRole) ||
    !allowedRoles.includes(data.role as StaffRole) ||
    typeof data.schoolId !== 'string' ||
    !SCHOOL_ID_PATTERN.test(data.schoolId)
  ) {
    throw new HttpsError('permission-denied', 'Staff access is unavailable.');
  }
  return {
    role: data.role as StaffRole,
    schoolId: data.schoolId,
    active: true,
  };
}

export async function requireStaff(
  db: Firestore,
  uid: string | undefined,
  allowedRoles: readonly StaffRole[] = ALLOWED_ROLES,
  tx?: Transaction,
): Promise<StaffAccessScope> {
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Sign in is required.');
  }
  const ref = db.doc(`staffAccounts/${uid}`);
  const snap = tx ? await tx.get(ref) : await ref.get();
  return assertStaffAccount(snap.exists ? snap.data() : undefined, allowedRoles);
}
