import {Timestamp} from 'firebase-admin/firestore';
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {keys, object} from '../medical/medical_contract';
import {resqmeRuntimeOptions} from '../onboarding/authorization';
import {requireMasterAdmin, staffManagementDeps} from './staff_account_management';

export type ActivityLogCategory = 'all' | 'security' | 'management' | 'tier2';
export type ActivityLogOutcome = 'all' | 'allowed' | 'denied';

const VALID_CATEGORIES: readonly ActivityLogCategory[] = ['all', 'security', 'management', 'tier2'];
const VALID_OUTCOMES: readonly ActivityLogOutcome[] = ['all', 'allowed', 'denied'];
const DATE_PATTERN = /^\d{4}-\d{2}-\d{2}$/;
const ACTOR_PATTERN = /^[A-Za-z0-9_-]{2,128}$/;

const SECURITY_ACTIONS = new Set([
  'change_own_password',
  'enroll_staff_tier2_device',
  'revoke_authorized_device',
  'reset_authorized_password',
  'reveal_student_lrn',
  'replace_student_qr',
  'disable_student_account',
  'enable_student_account',
  'disable_authorized_account',
  'enable_authorized_account',
  'suspend_authorized_account',
  'reactivate_authorized_account',
  'revoke_authorized_account',
  'student_registration_conflict',
  'issue_student_login_qr',
  'replace_student_login_qr',
  'revoke_student_login_qr',
  'enroll_student_trusted_device',
  'replace_student_trusted_device',
  'revoke_student_trusted_device',
  'approve_student_device_transfer',
  'reset_student_trusted_device',
]);

const ACTION_LABELS: Record<string, string> = {
  provision_master_admin: 'Master Admin Provisioned',
  change_own_password: 'Staff Password Changed',
  sync_master_admin_email: 'Master Admin Email Synced',
  create_authorized_account: 'Authorized Account Created',
  update_authorized_account: 'Authorized Account Updated',
  disable_authorized_account: 'Authorized Account Disabled',
  enable_authorized_account: 'Authorized Account Enabled',
  suspend_authorized_account: 'Authorized Account Suspended',
  reactivate_authorized_account: 'Authorized Account Reactivated',
  revoke_authorized_account: 'Authorized Account Revoked',
  reset_authorized_password: 'Authorized Password Reset',
  revoke_authorized_device: 'Authorized Device Revoked',
  enroll_staff_tier2_device: 'Biometric Device Enrolled',
  auto_verify_student_roster: 'Student Auto-Verified via Roster',
  student_registration_conflict: 'Student Registration Conflict Blocked',
  issue_student_login_qr: 'Student Login QR Issued',
  replace_student_login_qr: 'Student Login QR Replaced',
  revoke_student_login_qr: 'Student Login QR Revoked',
  enroll_student_trusted_device: 'Student Trusted Device Enrolled',
  replace_student_trusted_device: 'Student Trusted Device Replaced',
  revoke_student_trusted_device: 'Student Trusted Device Revoked',
  approve_student_device_transfer: 'Student Device Transfer Approved',
  reset_student_trusted_device: 'Student Trusted Device Reset by Admin',
  verify_student_account: 'Student Manually Verified',
  disable_student_account: 'Student Account Disabled',
  enable_student_account: 'Student Account Enabled',
  reveal_student_lrn: 'Protected LRN Revealed',
  replace_student_qr: 'Student QR Replaced',
  commit_roster_import: 'SF1 Roster Imported',
  tier2_emergency_read: 'Emergency Tier 2 Scan',
};

function toMillis(raw: unknown): number {
  if (raw instanceof Timestamp) return raw.toMillis();
  if (raw instanceof Date) return raw.getTime();
  if (typeof raw === 'string') {
    const parsed = Date.parse(raw);
    return Number.isFinite(parsed) ? parsed : 0;
  }
  return 0;
}

function safeString(raw: unknown, maxLen = 128): string | null {
  if (typeof raw !== 'string') return null;
  const trimmed = raw.trim();
  return trimmed.length > 0 ? trimmed.slice(0, maxLen) : null;
}

function normalizeStaffAudit(
  id: string,
  data: Record<string, unknown>,
): {
  id: string;
  sourceCollection: 'staffManagementAudits';
  category: 'security' | 'management';
  action: string;
  actionLabel: string;
  outcome: 'allowed' | 'denied';
  actorUid: string;
  actorRole: string;
  targetUid: string | null;
  summary: string;
  reasonCode: string | null;
  method: string | null;
  timestampMs: number;
  timestamp: string;
} {
  const action = safeString(data.action) ?? 'staff_management_event';
  const category: 'security' | 'management' = SECURITY_ACTIONS.has(action)
    ? 'security'
    : 'management';
  const outcome: 'allowed' | 'denied' = data.outcome === 'denied' ? 'denied' : 'allowed';
  const actorUid = safeString(data.actorUid) ?? 'unknown';
  const actorRole = safeString(data.actorRole) ?? 'admin';
  const targetUid = safeString(data.targetUid) ?? safeString(data.targetId);
  const method = safeString(data.method);
  const reasonCode = safeString(data.reasonCode) ?? safeString(data.reason);
  const timestampMs = toMillis(data.recordedAt ?? data.createdAt);
  const actionLabel = ACTION_LABELS[action] ?? action.replace(/_/g, ' ');

  const parts: string[] = [actionLabel];
  if (method) parts.push(`via ${method}`);
  if (reasonCode) parts.push(`(${reasonCode})`);
  if (Number.isSafeInteger(data.credentialVersion)) {
    parts.push(`v${Number(data.credentialVersion)}`);
  }

  return {
    id,
    sourceCollection: 'staffManagementAudits',
    category,
    action,
    actionLabel,
    outcome,
    actorUid,
    actorRole,
    targetUid,
    summary: parts.join(' '),
    reasonCode,
    method,
    timestampMs,
    timestamp: timestampMs > 0 ? new Date(timestampMs).toISOString() : new Date(0).toISOString(),
  };
}

function normalizeTier2Audit(
  id: string,
  data: Record<string, unknown>,
): {
  id: string;
  sourceCollection: 'tier2AccessAudits';
  category: 'tier2';
  action: string;
  actionLabel: string;
  outcome: 'allowed' | 'denied';
  actorUid: string;
  actorRole: string;
  targetUid: string | null;
  summary: string;
  reasonCode: string | null;
  method: string | null;
  timestampMs: number;
  timestamp: string;
} {
  const outcome: 'allowed' | 'denied' = data.outcome === 'denied' ? 'denied' : 'allowed';
  const actorUid = safeString(data.actorUid) ?? 'unknown';
  const actorRole = safeString(data.actorRole) ?? 'staff';
  const targetUid = safeString(data.targetUid);
  const purpose = safeString(data.purpose);
  const reasonCode = safeString(data.reasonCode);
  const timestampMs = toMillis(data.recordedAt ?? data.createdAt);
  const actionLabel = ACTION_LABELS.tier2_emergency_read;

  const parts: string[] = [actionLabel];
  if (purpose) parts.push(`(${purpose})`);
  if (outcome === 'denied' && reasonCode) parts.push(`• ${reasonCode}`);

  return {
    id,
    sourceCollection: 'tier2AccessAudits',
    category: 'tier2',
    action: 'tier2_emergency_read',
    actionLabel,
    outcome,
    actorUid,
    actorRole,
    targetUid,
    summary: parts.join(' '),
    reasonCode,
    method: 'biometric',
    timestampMs,
    timestamp: timestampMs > 0 ? new Date(timestampMs).toISOString() : new Date(0).toISOString(),
  };
}

export const listSchoolActivityLogs = onCall(resqmeRuntimeOptions, async (request) => {
  const adminUid = request.auth?.uid;
  if (!adminUid) throw new HttpsError('unauthenticated', 'Sign in is required.');
  const data = object(request.data ?? {});
  keys(data, ['category', 'outcome', 'actorUid', 'search', 'startDate', 'endDate', 'limit', 'cursor']);

  const category = (data.category ?? 'all') as ActivityLogCategory;
  if (typeof category !== 'string' || !VALID_CATEGORIES.includes(category)) {
    throw new HttpsError('invalid-argument', 'Invalid activity category filter.');
  }
  const outcome = (data.outcome ?? 'all') as ActivityLogOutcome;
  if (typeof outcome !== 'string' || !VALID_OUTCOMES.includes(outcome)) {
    throw new HttpsError('invalid-argument', 'Invalid outcome filter.');
  }

  let actorUidFilter: string | null = null;
  if (data.actorUid != null && data.actorUid !== '') {
    if (typeof data.actorUid !== 'string' || !ACTOR_PATTERN.test(data.actorUid)) {
      throw new HttpsError('invalid-argument', 'Invalid actor filter.');
    }
    actorUidFilter = data.actorUid;
  }

  const search = typeof data.search === 'string' ? data.search.trim().toLowerCase().slice(0, 80) : '';

  let startMs: number | null = null;
  if (data.startDate != null && data.startDate !== '') {
    if (typeof data.startDate !== 'string' || !DATE_PATTERN.test(data.startDate)) {
      throw new HttpsError('invalid-argument', 'Invalid startDate filter.');
    }
    startMs = Date.parse(`${data.startDate}T00:00:00.000Z`);
  }

  let endMs: number | null = null;
  if (data.endDate != null && data.endDate !== '') {
    if (typeof data.endDate !== 'string' || !DATE_PATTERN.test(data.endDate)) {
      throw new HttpsError('invalid-argument', 'Invalid endDate filter.');
    }
    endMs = Date.parse(`${data.endDate}T23:59:59.999Z`);
  }

  const rawLimit = data.limit ?? 25;
  if (!Number.isInteger(rawLimit) || Number(rawLimit) < 1 || Number(rawLimit) > 50) {
    throw new HttpsError('invalid-argument', 'Invalid pagination limit.');
  }
  const limit = Number(rawLimit);

  let cursor: string | null = null;
  if (data.cursor != null && data.cursor !== '') {
    if (typeof data.cursor !== 'string' || data.cursor.length > 256) {
      throw new HttpsError('invalid-argument', 'Invalid pagination cursor.');
    }
    const validV2 =
      /^(\d+):(staffManagementAudits|tier2AccessAudits):([A-Za-z0-9_-]{1,128})$/.test(
        data.cursor,
      );
    const validLegacy = /^(\d+):([A-Za-z0-9_-]{1,128})$/.test(data.cursor);
    if (!validV2 && !validLegacy) {
      throw new HttpsError('invalid-argument', 'Invalid pagination cursor.');
    }
    cursor = data.cursor;
  }

  const db = staffManagementDeps.db(adminUid);
  const admin = await requireMasterAdmin(
    db,
    adminUid,
    request.auth?.token.email_verified === true,
  );

  const [staffSnap, tier2Snap] = await Promise.all([
    db.collection('staffManagementAudits').where('schoolId', '==', admin.schoolId).get(),
    db.collection('tier2AccessAudits').where('schoolId', '==', admin.schoolId).get(),
  ]);

  const combined = [
    ...staffSnap.docs.map((doc) => normalizeStaffAudit(doc.id, doc.data())),
    ...tier2Snap.docs.map((doc) => normalizeTier2Audit(doc.id, doc.data())),
  ];

  const filtered = combined.filter((item) => {
    if (category !== 'all' && item.category !== category) return false;
    if (outcome !== 'all' && item.outcome !== outcome) return false;
    if (actorUidFilter && item.actorUid !== actorUidFilter) return false;
    if (startMs !== null && item.timestampMs < startMs) return false;
    if (endMs !== null && item.timestampMs > endMs) return false;
    if (search.length > 0) {
      const hay = `${item.actionLabel} ${item.action} ${item.summary} ${item.actorUid} ${item.targetUid ?? ''}`.toLowerCase();
      if (!hay.includes(search)) return false;
    }
    return true;
  });

  const compareAuditOrder = (
    a: {timestampMs: number; sourceCollection: string; id: string},
    b: {timestampMs: number; sourceCollection: string; id: string},
  ): number => {
    if (b.timestampMs !== a.timestampMs) return b.timestampMs - a.timestampMs;
    const srcCmp =
      b.sourceCollection < a.sourceCollection
        ? -1
        : b.sourceCollection > a.sourceCollection
          ? 1
          : 0;
    if (srcCmp !== 0) return srcCmp;
    return b.id < a.id ? -1 : b.id > a.id ? 1 : 0;
  };

  filtered.sort(compareAuditOrder);

  let startIndex = 0;
  if (cursor) {
    const v2Match = /^(\d+):(staffManagementAudits|tier2AccessAudits):([A-Za-z0-9_-]{1,128})$/.exec(
      cursor,
    );
    const legacyMatch = v2Match ? null : /^(\d+):([A-Za-z0-9_-]{1,128})$/.exec(cursor);
    if (v2Match) {
      const curTs = Number(v2Match[1]);
      const curSource = v2Match[2];
      const curId = v2Match[3];
      if (!Number.isSafeInteger(curTs)) {
        throw new HttpsError('invalid-argument', 'Invalid pagination cursor.');
      }
      const anchor = {timestampMs: curTs, sourceCollection: curSource, id: curId};
      const idx = filtered.findIndex((item) => compareAuditOrder(anchor, item) < 0);
      startIndex = idx === -1 ? filtered.length : idx;
    } else if (legacyMatch) {
      const idx = filtered.findIndex((item) => `${item.timestampMs}:${item.id}` === cursor);
      if (idx === -1) {
        throw new HttpsError('invalid-argument', 'Invalid pagination cursor.');
      }
      startIndex = idx + 1;
    } else {
      throw new HttpsError('invalid-argument', 'Invalid pagination cursor.');
    }
  }

  const pageSlice = filtered.slice(startIndex, startIndex + limit);
  const hasMore = startIndex + limit < filtered.length;
  const last = pageSlice[pageSlice.length - 1];
  const nextCursor =
    hasMore && last ? `${last.timestampMs}:${last.sourceCollection}:${last.id}` : null;

  return {
    entries: pageSlice.map(({timestampMs: _omitted, ...safeEntry}) => safeEntry),
    nextCursor,
    totalMatched: filtered.length,
  };
});
