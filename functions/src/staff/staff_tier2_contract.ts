import {HttpsError} from 'firebase-functions/v2/https';
import {keys, object} from '../medical/medical_contract';
import {isTier2PresentationPayload} from '../medical/trusted_device_management';
import {isQrPayload} from '../qr/ensure_my_tier1_qr';

export function isStaffScannableTier2Payload(value: unknown): value is string {
  return isQrPayload(value) || isTier2PresentationPayload(value);
}

export const staffTier2Operation = 'staff_read_medical' as const;
export const STAFF_ENROLLMENT_PROOF_VERSION = 2 as const;

export function staffEnrollmentSignedMessage(input: {
  staffUid: string;
  deviceId: string;
  challengeId: string;
  nonce: string;
}): string {
  return `resqme:staff-enroll:v2\n${input.staffUid}\n${input.deviceId}\n${input.challengeId}\n${input.nonce}`;
}

export const STAFF_TIER2_PURPOSES = [
  'emergency_response',
  'clinic_triage',
  'incident_assistance',
] as const;

export type StaffTier2Purpose = (typeof STAFF_TIER2_PURPOSES)[number];

export function validateStaffChallengeRequest(value: unknown): {
  payload: string;
  deviceId: string;
  purpose: StaffTier2Purpose;
} {
  const data = object(value);
  keys(data, ['payload', 'deviceId', 'purpose']);
  if (
    !isStaffScannableTier2Payload(data.payload) ||
    typeof data.deviceId !== 'string' ||
    !/^[A-Za-z0-9_-]{20,80}$/.test(data.deviceId) ||
    typeof data.purpose !== 'string' ||
    !STAFF_TIER2_PURPOSES.includes(data.purpose as StaffTier2Purpose)
  ) {
    throw new HttpsError('invalid-argument', 'Invalid staff Tier 2 challenge request.');
  }
  return {
    payload: data.payload,
    deviceId: data.deviceId,
    purpose: data.purpose as StaffTier2Purpose,
  };
}

export function validateStaffProofRequest(value: unknown): {
  challengeId: string;
  deviceId: string;
  signature: string;
} {
  const data = object(value);
  keys(data, ['challengeId', 'deviceId', 'signature']);
  if (
    typeof data.challengeId !== 'string' ||
    !/^[A-Fa-f0-9]{32,64}$/.test(data.challengeId) ||
    typeof data.deviceId !== 'string' ||
    !/^[A-Za-z0-9_-]{20,80}$/.test(data.deviceId) ||
    typeof data.signature !== 'string' ||
    !/^[A-Za-z0-9_-]{80,160}$/.test(data.signature)
  ) {
    throw new HttpsError('invalid-argument', 'Invalid staff Tier 2 proof.');
  }
  return {
    challengeId: data.challengeId,
    deviceId: data.deviceId,
    signature: data.signature,
  };
}

export function staffTier2SignedMessage(input: {
  staffUid: string;
  deviceId: string;
  operation: string;
  purpose: string;
  challengeId: string;
  nonce: string;
}): string {
  return `resqme:staff-tier2:v1\n${input.staffUid}\n${input.deviceId}\n${input.operation}\n${input.purpose}\n${input.challengeId}\n${input.nonce}`;
}

const staffRateBuckets = new Map<string, {startedAt: number; count: number}>();

export function allowStaffTier2Challenge(staffUid: string, now = Date.now()): boolean {
  for (const [key, bucket] of staffRateBuckets) {
    if (now - bucket.startedAt >= 60_000) staffRateBuckets.delete(key);
  }
  if (staffRateBuckets.size > 1000) staffRateBuckets.clear();
  const bucket = staffRateBuckets.get(staffUid);
  if (!bucket || now - bucket.startedAt >= 60_000) {
    staffRateBuckets.set(staffUid, {startedAt: now, count: 1});
    return true;
  }
  if (bucket.count >= 20) return false;
  bucket.count++;
  return true;
}
