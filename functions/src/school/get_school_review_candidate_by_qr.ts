import {createHash} from 'node:crypto';
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {onboardingDatabase, resqmeRuntimeOptions} from '../onboarding/authorization';
import {isQrPayload} from '../qr/ensure_my_tier1_qr';
import {assertReviewerQrEligible} from './reviewer_qr_contract';

export const getSchoolReviewCandidateByQr = onCall(resqmeRuntimeOptions, async request => {
  const reviewerUid = request.auth?.uid;
  if (!reviewerUid) throw new HttpsError('unauthenticated', 'Sign in is required.');
  const payload = (request.data as {payload?: unknown} | null)?.payload;
  if (!isQrPayload(payload)) throw new HttpsError('invalid-argument', 'Unsupported student QR.');
  const db = onboardingDatabase(reviewerUid);
  const reviewerRef = db.doc(`schoolReviewers/${reviewerUid}`);
  const reviewerSnapshot = await reviewerRef.get();
  if (reviewerSnapshot.get('active') !== true || typeof reviewerSnapshot.get('schoolId') !== 'string') {
    throw new HttpsError('permission-denied', 'School review is unavailable.');
  }
  const hash = createHash('sha256').update(payload, 'utf8').digest('hex');
  const lookupSnapshot = await db.doc(`studentQrLookups/${hash}`).get();
  const studentUid = lookupSnapshot.get('uid');
  if (!lookupSnapshot.exists || typeof studentUid !== 'string' || studentUid === reviewerUid) {
    throw new HttpsError('not-found', 'Registration unavailable for review.');
  }
  const [studentSnapshot, credentialSnapshot] = await Promise.all([
    db.doc(`studentProfiles/${studentUid}`).get(), db.doc(`studentQrCredentials/${studentUid}`).get(),
  ]);
  const candidate = assertReviewerQrEligible({reviewer: reviewerSnapshot.data(), reviewerUid, studentUid,
    student: studentSnapshot.data(), credential: credentialSnapshot.data(), lookup: lookupSnapshot.data()});
  if (credentialSnapshot.get('payload') !== payload) throw new HttpsError('not-found', 'Registration unavailable for review.');
  return {...candidate, qrStatus: 'INACTIVE' as const, verificationStatus: 'PENDING' as const};
});
