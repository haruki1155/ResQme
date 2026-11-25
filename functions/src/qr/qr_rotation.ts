import {createHash, randomBytes} from 'node:crypto';
import {
  FieldValue,
  type DocumentSnapshot,
  type Firestore,
  type Transaction,
} from 'firebase-admin/firestore';
import {HttpsError} from 'firebase-functions/v2/https';
import {isQrPayload} from './ensure_my_tier1_qr';
import {evaluateQrEligibility} from './qr_eligibility';

export type QrReplacementReason = 'lost' | 'damaged' | 'compromised';

function hashQr(payload: string): string {
  return createHash('sha256').update(payload, 'utf8').digest('hex');
}

export interface RotateStudentQrInput {
  db: Firestore;
  tx: Transaction;
  uid: string;
  profile: Record<string, unknown>;
  medical: Record<string, unknown> | undefined;
  guardianAuthorization: Record<string, unknown> | undefined;
  existingCredential: DocumentSnapshot;
  replacedByUid?: string;
  replacementReason?: QrReplacementReason;
}

export interface RotateStudentQrResult {
  payload: string;
  verificationStatus: 'pending' | 'active';
  previousCredentialVersion: number;
  credentialVersion: number;
}

/**
 * Atomically revokes any prior Tier 1 QR lookup and issues a new
 * cryptographically random `resqme:v1:` credential with an incremented
 * `credentialVersion`. Shared between student-initiated (`replaceMyTier1Qr`)
 * and Master Admin-initiated (`replaceSchoolStudentQr`) rotations.
 */
export async function rotateStudentTier1QrInTx(
  input: RotateStudentQrInput,
): Promise<RotateStudentQrResult> {
  const {
    db,
    tx,
    uid,
    profile,
    medical,
    guardianAuthorization,
    existingCredential,
    replacedByUid,
    replacementReason,
  } = input;

  const oldPayload = existingCredential.exists ? existingCredential.get('payload') : undefined;
  const oldLookupRef = isQrPayload(oldPayload)
    ? db.doc(`studentQrLookups/${hashQr(oldPayload)}`)
    : null;
  const oldLookupSnap = oldLookupRef ? await tx.get(oldLookupRef) : null;

  const rawPrevVersion = existingCredential.exists
    ? existingCredential.get('credentialVersion')
    : undefined;
  const previousCredentialVersion = existingCredential.exists
    ? Number.isSafeInteger(rawPrevVersion) && Number(rawPrevVersion) >= 1
      ? Number(rawPrevVersion)
      : 1
    : 0;
  const credentialVersion = previousCredentialVersion + 1;

  const issuedPayload = `resqme:v1:${randomBytes(32).toString('base64url')}`;
  const nextLookupRef = db.doc(`studentQrLookups/${hashQr(issuedPayload)}`);
  const lookupCollision = await tx.get(nextLookupRef);
  if (lookupCollision.exists) {
    throw new HttpsError('internal', 'Credential unavailable.');
  }

  const verificationStatus: 'pending' | 'active' = evaluateQrEligibility({
    uid,
    profile,
    medical,
    guardianAuthorization,
    credential: {payload: issuedPayload, verificationStatus: 'pending'},
  })
    ? 'active'
    : 'pending';

  if (oldLookupRef && oldLookupSnap?.exists) {
    tx.update(oldLookupRef, {
      status: 'revoked',
      revokedAt: FieldValue.serverTimestamp(),
      ...(replacementReason ? {revokedReason: replacementReason} : {}),
    });
  }

  const activation =
    verificationStatus === 'active' ? {activatedAt: FieldValue.serverTimestamp()} : {};
  const adminMeta =
    replacedByUid && replacementReason
      ? {
          replacedAt: FieldValue.serverTimestamp(),
          replacedByUid,
          replacementReason,
        }
      : {};

  const credentialRef = db.doc(`studentQrCredentials/${uid}`);
  const credentialFields = {
    payload: issuedPayload,
    verificationStatus,
    credentialVersion,
    issuedAt: FieldValue.serverTimestamp(),
    ...activation,
    ...adminMeta,
  };

  if (existingCredential.exists) {
    tx.update(credentialRef, credentialFields);
  } else {
    tx.create(credentialRef, credentialFields);
  }

  tx.create(nextLookupRef, {
    uid,
    status: verificationStatus,
    credentialVersion,
    createdAt: FieldValue.serverTimestamp(),
    ...activation,
  });

  return {
    payload: issuedPayload,
    verificationStatus,
    previousCredentialVersion,
    credentialVersion,
  };
}
