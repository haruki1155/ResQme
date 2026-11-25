import {createHash, randomBytes} from 'node:crypto';
import {getApps, initializeApp} from 'firebase-admin/app';
import {getAuth} from 'firebase-admin/auth';
import {FieldValue, getFirestore, Timestamp, type Firestore} from 'firebase-admin/firestore';
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {keys, object} from '../medical/medical_contract';
import {isStudentAccountDisabled, resqmeRuntimeOptions} from '../onboarding/authorization';

export const STUDENT_LOGIN_QR_PREFIX = 'resqme:login:v1:';
const STUDENT_LOGIN_QR_PATTERN = /^resqme:login:v1:[A-Za-z0-9_-]{43}$/;
const RATE_WINDOW_MS = 10 * 60_000;
const MAX_LOGIN_QR_RESOLVES_PER_WINDOW = 10;

const UNAVAILABLE_LOGIN_QR_MESSAGE =
  'This Login QR code is inactive, expired, or unavailable.';

export interface StudentLoginQrAuthPort {
  getUser(uid: string): Promise<{uid: string; email?: string; disabled?: boolean}>;
}

export const studentLoginQrDeps = {
  db(): Firestore {
    if (!getApps().some((app) => app.name === '[DEFAULT]')) {
      initializeApp();
    }
    return getFirestore();
  },
  auth(): StudentLoginQrAuthPort {
    if (!getApps().some((app) => app.name === '[DEFAULT]')) {
      initializeApp();
    }
    return getAuth();
  },
};

export function isStudentLoginQrPayload(value: unknown): value is string {
  return typeof value === 'string' && STUDENT_LOGIN_QR_PATTERN.test(value);
}

export function hashLoginQrPayload(payload: string): string {
  return createHash('sha256').update(payload, 'utf8').digest('hex');
}

export function maskLoginEmail(email: string): string {
  const trimmed = email.trim().toLowerCase();
  const atIndex = trimmed.indexOf('@');
  if (atIndex <= 0 || atIndex === trimmed.length - 1) return '•••';
  const local = trimmed.slice(0, atIndex);
  const domain = trimmed.slice(atIndex + 1);
  if (local.length <= 2) {
    return `${local[0]}•••@${domain}`;
  }
  return `${local[0]}•••${local[local.length - 1]}@${domain}`;
}

function generateLoginQrPayload(): string {
  return `${STUDENT_LOGIN_QR_PREFIX}${randomBytes(32).toString('base64url')}`;
}

async function enforceLoginQrRateLimit(
  db: Firestore,
  bucketId: string,
  maxAttempts: number,
): Promise<void> {
  const now = Date.now();
  const ref = db.doc(`studentLoginQrRateLimits/${bucketId}`);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const started = snap.get('windowStartedAt');
    const attempts = snap.get('attempts');
    const sameWindow =
      started instanceof Timestamp && now - started.toMillis() < RATE_WINDOW_MS;
    const count = sameWindow && Number.isSafeInteger(attempts) ? Number(attempts) : 0;
    if (count >= maxAttempts) {
      throw new HttpsError(
        'resource-exhausted',
        'Too many QR sign-in attempts. Please wait a few minutes or sign in with email and password.',
      );
    }
    tx.set(ref, {
      windowStartedAt: sameWindow ? started : Timestamp.fromMillis(now),
      attempts: count + 1,
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
}

function maybeWriteStudentLoginAudit(
  db: Firestore,
  tx: FirebaseFirestore.Transaction,
  profile: FirebaseFirestore.DocumentData | undefined,
  uid: string,
  action: string,
  outcome: 'allowed' | 'denied' = 'allowed',
): void {
  if (
    profile?.schoolAssignmentStatus === 'assigned' &&
    typeof profile.schoolId === 'string' &&
    profile.schoolId.length >= 2
  ) {
    tx.create(db.doc(`staffManagementAudits/${randomBytes(16).toString('hex')}`), {
      actorUid: uid,
      actorRole: 'student',
      schoolId: profile.schoolId,
      action,
      targetUid: uid,
      outcome,
      createdAt: FieldValue.serverTimestamp(),
    });
  }
}

export function revokeStudentLoginQrFromSnapshotInTx(
  db: Firestore,
  tx: FirebaseFirestore.Transaction,
  uid: string,
  credSnap: FirebaseFirestore.DocumentSnapshot,
): void {
  if (!credSnap.exists || credSnap.get('status') !== 'active') return;
  const oldHash = credSnap.get('tokenHash');
  tx.update(db.doc(`studentLoginQrCredentials/${uid}`), {
    status: 'revoked',
    revokedAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  if (typeof oldHash === 'string' && oldHash.length === 64) {
    tx.set(
      db.doc(`studentLoginQrLookups/${oldHash}`),
      {
        uid,
        status: 'revoked',
        revokedAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
  }
}

export const ensureMyStudentLoginQr = onCall(resqmeRuntimeOptions, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in is required.');
  keys(object(request.data ?? {}), []);

  const db = studentLoginQrDeps.db();
  const profileRef = db.doc(`studentProfiles/${uid}`);
  const credRef = db.doc(`studentLoginQrCredentials/${uid}`);

  return db.runTransaction(async (tx) => {
    const [profileSnap, credSnap] = await Promise.all([
      tx.get(profileRef),
      tx.get(credRef),
    ]);
    const profile = profileSnap.data();
    if (!profileSnap.exists || !profile || profile.schemaVersion !== 1) {
      throw new HttpsError('failed-precondition', 'Complete student registration first.');
    }
    if (isStudentAccountDisabled(profile)) {
      throw new HttpsError('permission-denied', 'Student account is disabled.');
    }

    const existingPayload = credSnap.get('payload');
    const existingVersion = credSnap.get('credentialVersion');
    if (
      credSnap.exists &&
      credSnap.get('status') === 'active' &&
      isStudentLoginQrPayload(existingPayload) &&
      Number.isSafeInteger(existingVersion)
    ) {
      return {
        payload: existingPayload,
        credentialVersion: Number(existingVersion),
        status: 'active' as const,
      };
    }

    const nextPayload = generateLoginQrPayload();
    const nextHash = hashLoginQrPayload(nextPayload);
    const nextLookupRef = db.doc(`studentLoginQrLookups/${nextHash}`);
    const nextLookupSnap = await tx.get(nextLookupRef);
    if (nextLookupSnap.exists) {
      throw new HttpsError('aborted', 'Retry Login QR generation.');
    }

    const oldHash = credSnap.get('tokenHash');
    if (typeof oldHash === 'string' && oldHash.length === 64 && oldHash !== nextHash) {
      tx.set(
        db.doc(`studentLoginQrLookups/${oldHash}`),
        {uid, status: 'revoked', revokedAt: FieldValue.serverTimestamp()},
        {merge: true},
      );
    }

    const nextVersion = Number(credSnap.get('credentialVersion') || 0) + 1;
    tx.create(nextLookupRef, {
      uid,
      credentialVersion: nextVersion,
      status: 'active',
      createdAt: FieldValue.serverTimestamp(),
    });
    tx.set(credRef, {
      uid,
      payload: nextPayload,
      tokenHash: nextHash,
      credentialVersion: nextVersion,
      status: 'active',
      issuedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    maybeWriteStudentLoginAudit(db, tx, profile, uid, 'issue_student_login_qr');

    return {
      payload: nextPayload,
      credentialVersion: nextVersion,
      status: 'active' as const,
    };
  });
});

export const replaceMyStudentLoginQr = onCall(resqmeRuntimeOptions, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in is required.');
  keys(object(request.data ?? {}), []);

  const db = studentLoginQrDeps.db();
  const profileRef = db.doc(`studentProfiles/${uid}`);
  const credRef = db.doc(`studentLoginQrCredentials/${uid}`);

  return db.runTransaction(async (tx) => {
    const [profileSnap, credSnap] = await Promise.all([
      tx.get(profileRef),
      tx.get(credRef),
    ]);
    const profile = profileSnap.data();
    if (!profileSnap.exists || !profile || profile.schemaVersion !== 1) {
      throw new HttpsError('failed-precondition', 'Complete student registration first.');
    }
    if (isStudentAccountDisabled(profile)) {
      throw new HttpsError('permission-denied', 'Student account is disabled.');
    }

    const nextPayload = generateLoginQrPayload();
    const nextHash = hashLoginQrPayload(nextPayload);
    const nextLookupRef = db.doc(`studentLoginQrLookups/${nextHash}`);
    const nextLookupSnap = await tx.get(nextLookupRef);
    if (nextLookupSnap.exists) {
      throw new HttpsError('aborted', 'Retry Login QR rotation.');
    }

    const oldHash = credSnap.get('tokenHash');
    if (typeof oldHash === 'string' && oldHash.length === 64) {
      tx.set(
        db.doc(`studentLoginQrLookups/${oldHash}`),
        {uid, status: 'revoked', revokedAt: FieldValue.serverTimestamp()},
        {merge: true},
      );
    }

    const nextVersion = Number(credSnap.get('credentialVersion') || 0) + 1;
    tx.create(nextLookupRef, {
      uid,
      credentialVersion: nextVersion,
      status: 'active',
      createdAt: FieldValue.serverTimestamp(),
    });
    tx.set(credRef, {
      uid,
      payload: nextPayload,
      tokenHash: nextHash,
      credentialVersion: nextVersion,
      status: 'active',
      issuedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    maybeWriteStudentLoginAudit(db, tx, profile, uid, 'replace_student_login_qr');

    return {
      payload: nextPayload,
      credentialVersion: nextVersion,
      status: 'active' as const,
    };
  });
});

export const revokeMyStudentLoginQr = onCall(resqmeRuntimeOptions, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in is required.');
  keys(object(request.data ?? {}), []);

  const db = studentLoginQrDeps.db();
  const profileRef = db.doc(`studentProfiles/${uid}`);
  const credRef = db.doc(`studentLoginQrCredentials/${uid}`);

  await db.runTransaction(async (tx) => {
    const [profileSnap, credSnap] = await Promise.all([
      tx.get(profileRef),
      tx.get(credRef),
    ]);
    const profile = profileSnap.data();
    if (isStudentAccountDisabled(profile)) {
      throw new HttpsError('permission-denied', 'Student account is disabled.');
    }
    if (credSnap.exists && credSnap.get('status') === 'active') {
      revokeStudentLoginQrFromSnapshotInTx(db, tx, uid, credSnap);
      maybeWriteStudentLoginAudit(db, tx, profile, uid, 'revoke_student_login_qr');
    }
  });

  return {status: 'revoked' as const};
});

export const resolveStudentLoginQr = onCall(resqmeRuntimeOptions, async (request) => {
  const data = object(request.data);
  keys(data, ['payload']);
  if (typeof data.payload !== 'string') {
    throw new HttpsError('invalid-argument', 'Invalid Student Login QR code.');
  }
  const payload = data.payload.trim();
  if (payload.startsWith('resqme:v1:') || payload.startsWith('resqme:tier2:v1:')) {
    throw new HttpsError(
      'invalid-argument',
      'This is an emergency QR code, not a Student Login QR code.',
    );
  }
  if (!isStudentLoginQrPayload(payload)) {
    throw new HttpsError('invalid-argument', 'Invalid Student Login QR code.');
  }

  const db = studentLoginQrDeps.db();
  const rawCaller =
    request.auth?.uid ??
    (typeof request.rawRequest?.ip === 'string' && request.rawRequest.ip
      ? request.rawRequest.ip
      : 'anonymous');
  const callerBucket = createHash('sha256')
    .update(`login-qr-caller:${rawCaller}`, 'utf8')
    .digest('hex');
  await enforceLoginQrRateLimit(db, callerBucket, MAX_LOGIN_QR_RESOLVES_PER_WINDOW);

  const tokenHash = hashLoginQrPayload(payload);
  const unavailable = () =>
    new HttpsError('permission-denied', UNAVAILABLE_LOGIN_QR_MESSAGE);

  const target = await db.runTransaction(async (tx) => {
    const lookupSnap = await tx.get(db.doc(`studentLoginQrLookups/${tokenHash}`));
    const targetUid = lookupSnap.get('uid');
    if (
      !lookupSnap.exists ||
      lookupSnap.get('status') !== 'active' ||
      typeof targetUid !== 'string' ||
      !targetUid
    ) {
      throw unavailable();
    }

    const [credSnap, profileSnap] = await Promise.all([
      tx.get(db.doc(`studentLoginQrCredentials/${targetUid}`)),
      tx.get(db.doc(`studentProfiles/${targetUid}`)),
    ]);
    const cred = credSnap.data();
    const profile = profileSnap.data();
    if (
      !credSnap.exists ||
      !cred ||
      cred.status !== 'active' ||
      cred.payload !== payload ||
      cred.credentialVersion !== lookupSnap.get('credentialVersion') ||
      !profileSnap.exists ||
      !profile ||
      profile.schemaVersion !== 1 ||
      isStudentAccountDisabled(profile)
    ) {
      throw unavailable();
    }
    return {uid: targetUid, profile};
  });

  let userRecord: {uid: string; email?: string; disabled?: boolean};
  try {
    userRecord = await studentLoginQrDeps.auth().getUser(target.uid);
  } catch {
    throw unavailable();
  }
  if (
    userRecord.disabled === true ||
    typeof userRecord.email !== 'string' ||
    !userRecord.email.trim()
  ) {
    throw unavailable();
  }

  const normalizedEmail = userRecord.email.trim().toLowerCase();
  return {
    email: normalizedEmail,
    maskedEmail: maskLoginEmail(normalizedEmail),
  };
});
