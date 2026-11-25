import {createHmac} from 'node:crypto';

export type SchoolRosterRecord = {
  schoolId: string;
  normalizedName: string;
  enrollmentCodeDigest: string | null;
  claimedByUid?: string | null;
  codeExpiresAt?: number | null;
  birthDate?: string | null;
  lastName?: string | null;
  firstName?: string | null;
  middleName?: string | null;
};

export function normalizeLrn(value: unknown): string {
  if (typeof value !== 'string' || !/^\d{12}$/.test(value)) throw new Error('lrn');
  return value;
}

export function normalizeRosterName(value: string): string {
  return value.normalize('NFKC').trim().toLocaleLowerCase('en').replace(/\s+/g, ' ');
}

/**
 * Deterministically canonicalizes student full names in either `"First [Middle] Last"`
 * or official DepEd SF1 `"Last, First[, Middle]"` comma order without permitting
 * partial, prefix, phonetic, or fuzzy matches.
 */
export function canonicalizeRosterNameInput(value: string): string {
  const normalized = value.normalize('NFKC').trim();
  if (!normalized.includes(',')) {
    return normalizeRosterName(normalized);
  }
  const rawSegments = normalized.split(',');
  if (rawSegments.length < 2 || rawSegments.length > 3) {
    return normalizeRosterName(normalized);
  }
  const parts = rawSegments.map((s) => s.trim());
  if (parts.some((p) => p.length === 0)) {
    return normalizeRosterName(normalized);
  }
  const lastName = parts[0];
  const givenAndMiddle = parts.slice(1).join(' ');
  return normalizeRosterName(`${givenAndMiddle} ${lastName}`);
}

function keyBytes(key: string): Buffer {
  const bytes = Buffer.from(key, 'utf8');
  if (bytes.length < 32) throw new Error('roster-key');
  return bytes;
}

export function rosterLookupId(lrn: string, key: string): string {
  return createHmac('sha256', keyBytes(key)).update(`lrn:${normalizeLrn(lrn)}`).digest('hex');
}

export function rosterCodeDigest(code: string, key: string): string {
  if (!/^[A-Z0-9_-]{16,128}$/.test(code)) throw new Error('enrollment-code');
  return createHmac('sha256', keyBytes(key)).update(`code:${code}`).digest('hex');
}

function matchesRosterIdentity(
  roster: SchoolRosterRecord | undefined,
  fullName: string,
  birthDate?: string | null,
): boolean {
  if (!roster || !/^[a-z0-9][a-z0-9_-]{1,63}$/.test(roster.schoolId)) {
    return false;
  }
  if (normalizeRosterName(roster.normalizedName) !== canonicalizeRosterNameInput(fullName)) {
    return false;
  }
  if (typeof roster.birthDate === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(roster.birthDate)) {
    if (typeof birthDate !== 'string' || birthDate !== roster.birthDate) {
      return false;
    }
  }
  return true;
}

export function evaluateRosterClaim(input: {
  roster: SchoolRosterRecord | undefined;
  codeClaim?: {rosterId?: string; claimedByUid?: string | null} | undefined;
  rosterId?: string;
  lrn: string;
  fullName: string;
  birthDate?: string | null;
  enrollmentCode: string | null;
  uid: string;
  key: string;
  now?: number;
}): 'auto_approve' | 'manual_review' | 'conflict' {
  const row = input.roster;
  if (!row || !/^[-a-z0-9_]{2,64}$/.test(row.schoolId)) {
    return 'manual_review';
  }
  const expectedRosterId = rosterLookupId(input.lrn, input.key);
  if (input.rosterId !== expectedRosterId) {
    return 'manual_review';
  }
  if (
    (row.claimedByUid && row.claimedByUid !== input.uid) ||
    (input.codeClaim?.claimedByUid && input.codeClaim.claimedByUid !== input.uid)
  ) {
    return 'conflict';
  }
  if (!matchesRosterIdentity(row, input.fullName, input.birthDate)) {
    return 'manual_review';
  }
  if (
    !input.enrollmentCode ||
    row.enrollmentCodeDigest !== rosterCodeDigest(input.enrollmentCode, input.key)
  ) {
    return 'manual_review';
  }
  if (!input.codeClaim || input.codeClaim.rosterId !== input.rosterId) {
    return 'manual_review';
  }
  if (row.codeExpiresAt != null && row.codeExpiresAt <= (input.now ?? Date.now())) {
    return 'manual_review';
  }
  return 'auto_approve';
}

export function matchingRosterSchool(
  roster: SchoolRosterRecord | undefined,
  fullName: string,
  birthDate?: string | null,
): string | null {
  if (!matchesRosterIdentity(roster, fullName, birthDate)) return null;
  return roster!.schoolId;
}
