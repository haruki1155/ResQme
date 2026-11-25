import {randomBytes} from 'node:crypto';
import {getAuth} from 'firebase-admin/auth';
import {FieldValue, type Firestore} from 'firebase-admin/firestore';
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {keys, object} from '../medical/medical_contract';
import {requireRecentAuth} from '../medical/tier2_challenge';
import {onboardingDatabase, resqmeRuntimeOptions} from '../onboarding/authorization';
import {generateSecurePassword} from './master_admin_provisioning';
import {requireStaff} from './staff_authorization';

const LOGIN_ID_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const STAFF_INTERNAL_DOMAIN = 'staff.resqme.internal';
const UID_PATTERN = /^[A-Za-z0-9_-]{3,128}$/;

export interface StaffAdminAuthPort {
  createUser(input: {
    email: string;
    password: string;
    displayName: string;
    emailVerified: boolean;
  }): Promise<{uid: string}>;
  updateUser(uid: string, input: {password?: string; disabled?: boolean; displayName?: string}): Promise<void>;
  revokeRefreshTokens(uid: string): Promise<void>;
  deleteUser(uid: string): Promise<void>;
}

const defaultAuthPort: StaffAdminAuthPort = {
  async createUser(input) {
    const rec = await getAuth().createUser(input);
    return {uid: rec.uid};
  },
  async updateUser(uid, input) {
    await getAuth().updateUser(uid, input);
  },
  async revokeRefreshTokens(uid) {
    await getAuth().revokeRefreshTokens(uid);
  },
  async deleteUser(uid) {
    await getAuth().deleteUser(uid);
  },
};

export const staffManagementDeps = {
  auth: (): StaffAdminAuthPort => defaultAuthPort,
  db: (uid: string): Firestore => onboardingDatabase(uid),
};

export function generateAuthorizedLoginId(): string {
  const chars: string[] = [];
  const limit = 256 - (256 % LOGIN_ID_ALPHABET.length);
  while (chars.length < 8) {
    const b = randomBytes(1)[0];
    if (b < limit) {
      chars.push(LOGIN_ID_ALPHABET[b % LOGIN_ID_ALPHABET.length]);
    }
  }
  return `AUTH-${chars.join('')}`;
}

export function loginIdToInternalEmail(loginId: string): string {
  return `${loginId.trim().toLowerCase()}@${STAFF_INTERNAL_DOMAIN}`;
}

export function validateStrongPassword(raw: unknown): string {
  if (
    typeof raw !== 'string' ||
    raw.length < 12 ||
    raw.length > 128 ||
    !/[A-Z]/.test(raw) ||
    !/[a-z]/.test(raw) ||
    !/[0-9]/.test(raw) ||
    !/[^A-Za-z0-9]/.test(raw)
  ) {
    throw new HttpsError(
      'invalid-argument',
      'Password must be at least 12 characters and include uppercase, lowercase, number, and symbol.',
    );
  }
  return raw;
}

function validateStaffText(raw: unknown, label: string, min = 2, max = 100): string {
  if (typeof raw !== 'string') {
    throw new HttpsError('invalid-argument', `Invalid ${label}.`);
  }
  const trimmed = raw.trim().replace(/\s+/g, ' ');
  if (trimmed.length < min || trimmed.length > max) {
    throw new HttpsError('invalid-argument', `Invalid ${label}.`);
  }
  return trimmed;
}

function validateTargetUid(raw: unknown): string {
  if (typeof raw !== 'string' || !UID_PATTERN.test(raw)) {
    throw new HttpsError('invalid-argument', 'Invalid target account.');
  }
  return raw;
}

export function auditRecord(input: {
  actorUid: string;
  actorRole: string;
  schoolId: string;
  action: string;
  targetUid: string;
  outcome: 'allowed' | 'denied';
  reason?: string;
}): Record<string, unknown> {
  return {
    actorUid: input.actorUid,
    actorRole: input.actorRole,
    schoolId: input.schoolId,
    action: input.action,
    targetUid: input.targetUid,
    outcome: input.outcome,
    ...(input.reason ? {reason: input.reason} : {}),
    createdAt: FieldValue.serverTimestamp(),
  };
}

export async function requireMasterAdmin(
  db: Firestore,
  uid: string,
  emailVerified: boolean,
  tx?: FirebaseFirestore.Transaction,
) {
  const staff = await requireStaff(db, uid, ['admin'], tx, {emailVerified});
  if (!staff.isMasterAdmin) {
    throw new HttpsError('permission-denied', 'Master Admin access is required.');
  }
  if (!staff.emailVerified) {
    throw new HttpsError(
      'failed-precondition',
      'Email verification is required before continuing.',
    );
  }
  return staff;
}

async function invalidateOutstandingChallenges(db: Firestore, staffUid: string): Promise<void> {
  for (const col of ['staffTier2Challenges', 'staffEnrollmentChallenges']) {
    const snap = await db.collection(col).where('staffUid', '==', staffUid).get();
    for (const d of snap.docs) {
      if (d.get('consumedAt') == null) {
        await d.ref.update({
          consumedAt: FieldValue.serverTimestamp(),
          invalidatedReason: 'account_security_change',
        });
      }
    }
  }
}

export const changeMyStaffPassword = onCall(resqmeRuntimeOptions, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in is required.');
  requireRecentAuth(request.auth?.token.auth_time, undefined, 120);
  const data = object(request.data);
  keys(data, ['newPassword']);
  const newPassword = validateStrongPassword(data.newPassword);

  const db = staffManagementDeps.db(uid);
  const staff = await requireStaff(db, uid, ['admin', 'authorized'], undefined, {
    requireSetupComplete: false,
    emailVerified: request.auth?.token.email_verified === true,
  });

  await staffManagementDeps.auth().updateUser(uid, {password: newPassword});
  await db.runTransaction(async (tx) => {
    await requireStaff(db, uid, ['admin', 'authorized'], tx, {
      requireSetupComplete: false,
      emailVerified: request.auth?.token.email_verified === true,
    });
    tx.update(db.doc(`staffAccounts/${uid}`), {
      mustChangePassword: false,
      passwordChangedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    tx.create(
      db.doc(`staffManagementAudits/${randomBytes(16).toString('hex')}`),
      auditRecord({
        actorUid: uid,
        actorRole: staff.role,
        schoolId: staff.schoolId,
        action: 'change_own_password',
        targetUid: uid,
        outcome: 'allowed',
      }),
    );
  });

  return {mustChangePassword: false as const};
});

export const syncMasterAdminEmail = onCall(resqmeRuntimeOptions, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in is required.');
  keys(object(request.data), []);
  const email = request.auth?.token.email;
  const emailVerified = request.auth?.token.email_verified === true;
  if (!emailVerified || typeof email !== 'string' || !email.includes('@')) {
    throw new HttpsError('failed-precondition', 'Email verification is required before continuing.');
  }

  const db = staffManagementDeps.db(uid);
  await db.runTransaction(async (tx) => {
    const staff = await requireStaff(db, uid, ['admin'], tx, {
      requireSetupComplete: false,
      emailVerified: true,
    });
    if (!staff.isMasterAdmin) {
      throw new HttpsError('permission-denied', 'Master Admin access is required.');
    }
    tx.update(db.doc(`staffAccounts/${uid}`), {
      loginEmail: email.trim().toLowerCase(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    tx.create(
      db.doc(`staffManagementAudits/${randomBytes(16).toString('hex')}`),
      auditRecord({
        actorUid: uid,
        actorRole: staff.role,
        schoolId: staff.schoolId,
        action: 'sync_master_admin_email',
        targetUid: uid,
        outcome: 'allowed',
      }),
    );
  });

  return {email: email.trim().toLowerCase(), emailVerified: true as const};
});

export const createAuthorizedAccount = onCall(resqmeRuntimeOptions, async (request) => {
  const adminUid = request.auth?.uid;
  if (!adminUid) throw new HttpsError('unauthenticated', 'Sign in is required.');
  const data = object(request.data);
  keys(data, ['fullName', 'position']);
  const fullName = validateStaffText(data.fullName, 'full name');
  const position = validateStaffText(data.position, 'position');
  const emailVerified = request.auth?.token.email_verified === true;

  const db = staffManagementDeps.db(adminUid);
  const admin = await requireMasterAdmin(db, adminUid, emailVerified);

  const authPort = staffManagementDeps.auth();
  let loginId = '';
  let internalEmail = '';
  let createdUid = '';
  const temporaryPassword = generateSecurePassword(16);

  for (let attempt = 0; attempt < 5; attempt++) {
    const candidateId = generateAuthorizedLoginId();
    const candidateEmail = loginIdToInternalEmail(candidateId);
    const existingLock = await db.doc(`staffLoginIds/${candidateId.toLowerCase()}`).get();
    if (existingLock.exists) continue;
    try {
      const created = await authPort.createUser({
        email: candidateEmail,
        password: temporaryPassword,
        displayName: fullName,
        emailVerified: false,
      });
      loginId = candidateId;
      internalEmail = candidateEmail;
      createdUid = created.uid;
      break;
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      if (msg.includes('email-already-exists') && attempt < 4) continue;
      throw new HttpsError('internal', 'Unable to create Authorized account.');
    }
  }
  if (!createdUid || !loginId) {
    throw new HttpsError('aborted', 'Unable to allocate a unique login ID. Please retry.');
  }

  try {
    await db.runTransaction(async (tx) => {
      const liveAdmin = await requireMasterAdmin(db, adminUid, emailVerified, tx);
      const loginRef = db.doc(`staffLoginIds/${loginId.toLowerCase()}`);
      const loginSnap = await tx.get(loginRef);
      if (loginSnap.exists) {
        throw new HttpsError('aborted', 'Login ID collision detected. Please retry.');
      }
      tx.create(loginRef, {
        uid: createdUid,
        loginId,
        schoolId: liveAdmin.schoolId,
        createdAt: FieldValue.serverTimestamp(),
      });
      tx.create(db.doc(`staffAccounts/${createdUid}`), {
        role: 'authorized',
        isMasterAdmin: false,
        active: true,
        status: 'active',
        schoolId: liveAdmin.schoolId,
        fullName,
        position,
        loginId,
        loginEmail: internalEmail,
        mustChangePassword: true,
        requiresEmailVerification: false,
        createdByUid: adminUid,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      tx.create(
        db.doc(`staffManagementAudits/${randomBytes(16).toString('hex')}`),
        auditRecord({
          actorUid: adminUid,
          actorRole: liveAdmin.role,
          schoolId: liveAdmin.schoolId,
          action: 'create_authorized_account',
          targetUid: createdUid,
          outcome: 'allowed',
        }),
      );
    });
  } catch (err) {
    try {
      await authPort.deleteUser(createdUid);
    } catch {
      // Best-effort cleanup so failed writes never leave orphaned Auth users.
    }
    if (err instanceof HttpsError) throw err;
    throw new HttpsError('internal', 'Unable to finalize Authorized account creation.');
  }

  return {
    uid: createdUid,
    loginId,
    temporaryPassword,
    fullName,
    position,
    role: 'authorized' as const,
    schoolId: admin.schoolId,
  };
});

export const listAuthorizedAccounts = onCall(resqmeRuntimeOptions, async (request) => {
  const adminUid = request.auth?.uid;
  if (!adminUid) throw new HttpsError('unauthenticated', 'Sign in is required.');
  const data = request.data == null ? {} : object(request.data);
  keys(data, ['search']);
  const search = typeof data.search === 'string' ? data.search.trim().toLowerCase() : '';
  if (search.length > 100) {
    throw new HttpsError('invalid-argument', 'Search query is too long.');
  }

  const db = staffManagementDeps.db(adminUid);
  const admin = await requireMasterAdmin(
    db,
    adminUid,
    request.auth?.token.email_verified === true,
  );

  const snap = await db
    .collection('staffAccounts')
    .where('schoolId', '==', admin.schoolId)
    .where('role', '==', 'authorized')
    .get();

  const accounts = await Promise.all(
    snap.docs.map(async (d) => {
      const row = d.data();
      const deviceSnap = await db.doc(`staffTier2Devices/${d.id}`).get();
      const status =
        typeof row.status === 'string'
          ? row.status
          : row.active === true
            ? 'active'
            : 'suspended';
      return {
        uid: d.id,
        loginId: typeof row.loginId === 'string' ? row.loginId : '',
        fullName: typeof row.fullName === 'string' ? row.fullName : '',
        position: typeof row.position === 'string' ? row.position : '',
        status,
        active: row.active === true && status === 'active',
        mustChangePassword: row.mustChangePassword === true,
        hasActiveDevice: deviceSnap.exists && deviceSnap.get('status') === 'active',
      };
    }),
  );

  const filtered = search
    ? accounts.filter(
        (a) =>
          a.fullName.toLowerCase().includes(search) ||
          a.position.toLowerCase().includes(search) ||
          a.loginId.toLowerCase().includes(search),
      )
    : accounts;

  filtered.sort((a, b) => a.fullName.localeCompare(b.fullName));
  return {accounts: filtered};
});

export const updateAuthorizedAccount = onCall(resqmeRuntimeOptions, async (request) => {
  const adminUid = request.auth?.uid;
  if (!adminUid) throw new HttpsError('unauthenticated', 'Sign in is required.');
  const data = object(request.data);
  keys(data, ['targetUid', 'fullName', 'position']);
  const targetUid = validateTargetUid(data.targetUid);
  const fullName = validateStaffText(data.fullName, 'full name');
  const position = validateStaffText(data.position, 'position');
  const emailVerified = request.auth?.token.email_verified === true;

  if (targetUid === adminUid) {
    throw new HttpsError('permission-denied', 'Cannot modify your own account here.');
  }

  const db = staffManagementDeps.db(adminUid);
  await db.runTransaction(async (tx) => {
    const admin = await requireMasterAdmin(db, adminUid, emailVerified, tx);
    const targetRef = db.doc(`staffAccounts/${targetUid}`);
    const targetSnap = await tx.get(targetRef);
    const target = targetSnap.data();
    if (
      !targetSnap.exists ||
      !target ||
      target.schoolId !== admin.schoolId ||
      target.role !== 'authorized' ||
      target.isMasterAdmin === true ||
      target.status === 'revoked'
    ) {
      throw new HttpsError('permission-denied', 'Authorized account cannot be modified.');
    }
    tx.update(targetRef, {
      fullName,
      position,
      updatedAt: FieldValue.serverTimestamp(),
    });
    tx.create(
      db.doc(`staffManagementAudits/${randomBytes(16).toString('hex')}`),
      auditRecord({
        actorUid: adminUid,
        actorRole: admin.role,
        schoolId: admin.schoolId,
        action: 'update_authorized_account',
        targetUid,
        outcome: 'allowed',
      }),
    );
  });

  await staffManagementDeps.auth().updateUser(targetUid, {displayName: fullName});
  return {uid: targetUid, fullName, position};
});

export const setAuthorizedAccountStatus = onCall(resqmeRuntimeOptions, async (request) => {
  const adminUid = request.auth?.uid;
  if (!adminUid) throw new HttpsError('unauthenticated', 'Sign in is required.');
  const data = object(request.data);
  keys(data, ['targetUid', 'action']);
  const targetUid = validateTargetUid(data.targetUid);
  const action = data.action;
  if (action !== 'suspend' && action !== 'reactivate' && action !== 'revoke') {
    throw new HttpsError('invalid-argument', 'Invalid account status action.');
  }
  if (action === 'revoke') {
    requireRecentAuth(request.auth?.token.auth_time, undefined, 120);
  }
  if (targetUid === adminUid) {
    throw new HttpsError('permission-denied', 'Master Admin cannot suspend or revoke itself.');
  }

  const emailVerified = request.auth?.token.email_verified === true;
  const db = staffManagementDeps.db(adminUid);

  const nextStatus = action === 'reactivate' ? 'active' : action === 'suspend' ? 'suspended' : 'revoked';
  const nextActive = action === 'reactivate';

  await db.runTransaction(async (tx) => {
    const admin = await requireMasterAdmin(db, adminUid, emailVerified, tx);
    const targetRef = db.doc(`staffAccounts/${targetUid}`);
    const deviceRef = db.doc(`staffTier2Devices/${targetUid}`);
    const [targetSnap, deviceSnap] = await Promise.all([tx.get(targetRef), tx.get(deviceRef)]);
    const target = targetSnap.data();

    if (
      !targetSnap.exists ||
      !target ||
      target.schoolId !== admin.schoolId ||
      target.role !== 'authorized' ||
      target.isMasterAdmin === true
    ) {
      throw new HttpsError('permission-denied', 'Authorized account cannot be modified.');
    }
    if (target.status === 'revoked') {
      throw new HttpsError('failed-precondition', 'Permanently revoked accounts cannot be changed.');
    }

    const patch: Record<string, unknown> = {
      active: nextActive,
      status: nextStatus,
      updatedAt: FieldValue.serverTimestamp(),
    };
    if (action === 'suspend') patch.suspendedAt = FieldValue.serverTimestamp();
    if (action === 'revoke') patch.revokedAt = FieldValue.serverTimestamp();
    tx.update(targetRef, patch);

    if (!nextActive && deviceSnap.exists) {
      tx.set(
        deviceRef,
        {
          status: 'revoked',
          keyVersion: Number(deviceSnap.get('keyVersion') || 0) + 1,
          revokedAt: FieldValue.serverTimestamp(),
        },
        {merge: true},
      );
    }

    tx.create(
      db.doc(`staffManagementAudits/${randomBytes(16).toString('hex')}`),
      auditRecord({
        actorUid: adminUid,
        actorRole: admin.role,
        schoolId: admin.schoolId,
        action: `${action}_authorized_account`,
        targetUid,
        outcome: 'allowed',
      }),
    );
  });

  const authPort = staffManagementDeps.auth();
  if (nextActive) {
    await authPort.updateUser(targetUid, {disabled: false});
  } else {
    await authPort.updateUser(targetUid, {disabled: true});
    await authPort.revokeRefreshTokens(targetUid);
    await invalidateOutstandingChallenges(db, targetUid);
  }

  return {uid: targetUid, status: nextStatus, active: nextActive};
});

export const resetAuthorizedPassword = onCall(resqmeRuntimeOptions, async (request) => {
  const adminUid = request.auth?.uid;
  if (!adminUid) throw new HttpsError('unauthenticated', 'Sign in is required.');
  requireRecentAuth(request.auth?.token.auth_time, undefined, 120);
  const data = object(request.data);
  keys(data, ['targetUid']);
  const targetUid = validateTargetUid(data.targetUid);
  if (targetUid === adminUid) {
    throw new HttpsError('permission-denied', 'Use self-service password change for your own account.');
  }

  const emailVerified = request.auth?.token.email_verified === true;
  const db = staffManagementDeps.db(adminUid);
  const temporaryPassword = generateSecurePassword(16);

  const loginId = await db.runTransaction(async (tx) => {
    const admin = await requireMasterAdmin(db, adminUid, emailVerified, tx);
    const targetRef = db.doc(`staffAccounts/${targetUid}`);
    const targetSnap = await tx.get(targetRef);
    const target = targetSnap.data();
    if (
      !targetSnap.exists ||
      !target ||
      target.schoolId !== admin.schoolId ||
      target.role !== 'authorized' ||
      target.isMasterAdmin === true ||
      target.status === 'revoked'
    ) {
      throw new HttpsError('permission-denied', 'Authorized account cannot be reset.');
    }
    tx.update(targetRef, {
      mustChangePassword: true,
      updatedAt: FieldValue.serverTimestamp(),
    });
    tx.create(
      db.doc(`staffManagementAudits/${randomBytes(16).toString('hex')}`),
      auditRecord({
        actorUid: adminUid,
        actorRole: admin.role,
        schoolId: admin.schoolId,
        action: 'reset_authorized_password',
        targetUid,
        outcome: 'allowed',
      }),
    );
    return typeof target.loginId === 'string' ? target.loginId : '';
  });

  const authPort = staffManagementDeps.auth();
  await authPort.updateUser(targetUid, {password: temporaryPassword});
  await authPort.revokeRefreshTokens(targetUid);
  await invalidateOutstandingChallenges(db, targetUid);

  return {uid: targetUid, loginId, temporaryPassword};
});

export const revokeAuthorizedDevice = onCall(resqmeRuntimeOptions, async (request) => {
  const adminUid = request.auth?.uid;
  if (!adminUid) throw new HttpsError('unauthenticated', 'Sign in is required.');
  const data = object(request.data);
  keys(data, ['targetUid']);
  const targetUid = validateTargetUid(data.targetUid);
  const emailVerified = request.auth?.token.email_verified === true;
  const db = staffManagementDeps.db(adminUid);

  await db.runTransaction(async (tx) => {
    const admin = await requireMasterAdmin(db, adminUid, emailVerified, tx);
    const targetSnap = await tx.get(db.doc(`staffAccounts/${targetUid}`));
    const target = targetSnap.data();
    if (
      !targetSnap.exists ||
      !target ||
      target.schoolId !== admin.schoolId ||
      target.role !== 'authorized' ||
      target.isMasterAdmin === true
    ) {
      throw new HttpsError('permission-denied', 'Authorized device cannot be revoked.');
    }
    const deviceRef = db.doc(`staffTier2Devices/${targetUid}`);
    const deviceSnap = await tx.get(deviceRef);
    tx.set(
      deviceRef,
      {
        status: 'revoked',
        keyVersion: Number(deviceSnap.get('keyVersion') || 0) + 1,
        revokedAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
    tx.create(
      db.doc(`staffManagementAudits/${randomBytes(16).toString('hex')}`),
      auditRecord({
        actorUid: adminUid,
        actorRole: admin.role,
        schoolId: admin.schoolId,
        action: 'revoke_authorized_device',
        targetUid,
        outcome: 'allowed',
      }),
    );
  });

  await invalidateOutstandingChallenges(db, targetUid);
  return {uid: targetUid, deviceStatus: 'revoked' as const};
});
