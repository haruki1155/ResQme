import {HttpsError} from 'firebase-functions/v2/https';
import {requireSchoolReviewer} from './approval_contract';

type RecordValue = Record<string, unknown> | undefined;

/** A scan may identify only the student's current, reviewable pending QR. */
export function assertReviewerQrEligible(input: {
  reviewer: RecordValue; reviewerUid: string; studentUid: string;
  student: RecordValue; credential: RecordValue; lookup: RecordValue;
}) {
  const schoolId = requireSchoolReviewer(input.reviewer);
  const {student, credential, lookup} = input;
  const valid = input.reviewerUid !== input.studentUid &&
    student?.schemaVersion === 1 && student.schoolAssignmentStatus === 'assigned' &&
    student.schoolId === schoolId && student.schoolApprovalStatus === 'pending' &&
    ['pending_review', 'pending_guardian'].includes(String(student.status)) &&
    typeof student.fullName === 'string' && student.fullName.trim().length >= 2 &&
    typeof credential?.payload === 'string' && credential.verificationStatus === 'pending' &&
    credential.schoolApprovalStatus !== 'revoked' && lookup?.uid === input.studentUid &&
    lookup.status === 'pending';
  if (!valid) throw new HttpsError('not-found', 'Registration unavailable for review.');
  return {studentUid: input.studentUid, fullName: (student!.fullName as string).trim(),
    schoolApprovalStatus: 'pending' as const,
    schoolVerificationOutcome: ['verified', 'manual_review', 'conflict'].includes(String(student!.schoolVerificationOutcome))
      ? String(student!.schoolVerificationOutcome) : 'manual_review'};
}
