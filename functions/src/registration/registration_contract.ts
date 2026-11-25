export const noticeVersion = 'tier1-registration-v1';

export type RegistrationInput = {
  fullName: string;
  ageYears?: number;
  birthDate?: unknown;
  noticeVersion: string;
  acknowledgmentAccepted: boolean;
  status?: unknown;
  lrn?: unknown;
  enrollmentCode?: unknown;
  gender?: unknown;
  personalPhone?: unknown;
  guardianName?: unknown;
  guardianRelationship?: unknown;
  guardianPhone?: unknown;
  secondaryName?: unknown;
  secondaryPhone?: unknown;
};

function optionalText(value: unknown, max = 120): string | null {
  if (value == null) return null;
  if (typeof value !== 'string' || value.trim().length > max) throw new Error('profile');
  return value.trim() || null;
}

function name(value: unknown): string | null {
  const result = optionalText(value);
  if (result && result.length < 2) throw new Error('profile');
  return result;
}

function phone(value: unknown): string | null {
  const result = optionalText(value, 32)?.replace(/[ -]/g, '') ?? null;
  if (result && !/^(09\d{9}|\+639\d{9})$/.test(result)) throw new Error('phone');
  return result;
}

const PHT_OFFSET_MS = 8 * 60 * 60 * 1000;

export function parseIsoBirthDate(
  value: unknown,
  now = new Date(),
): {birthDate: string; ageYears: number} | null {
  if (value === undefined || value === null || value === '') return null;
  if (typeof value !== 'string') throw new Error('birthDate');
  const trimmed = value.trim();
  if (!/^\d{4}-\d{2}-\d{2}$/.test(trimmed)) throw new Error('birthDate');
  const [y, m, d] = trimmed.split('-').map(Number);
  if (y < 1900) throw new Error('birthDate');
  const utc = new Date(Date.UTC(y, m - 1, d));
  if (
    utc.getUTCFullYear() !== y ||
    utc.getUTCMonth() !== m - 1 ||
    utc.getUTCDate() !== d
  ) {
    throw new Error('birthDate');
  }
  const phtNow = new Date(now.getTime() + PHT_OFFSET_MS);
  const phtTodayUtc = Date.UTC(
    phtNow.getUTCFullYear(),
    phtNow.getUTCMonth(),
    phtNow.getUTCDate(),
  );
  if (utc.getTime() > phtTodayUtc) {
    throw new Error('birthDate');
  }
  let ageYears = phtNow.getUTCFullYear() - y;
  const monthDiff = phtNow.getUTCMonth() + 1 - m;
  if (monthDiff < 0 || (monthDiff === 0 && phtNow.getUTCDate() < d)) {
    ageYears -= 1;
  }
  if (ageYears < 0 || ageYears > 130) throw new Error('birthDate');
  return {birthDate: trimmed, ageYears};
}

export function validateRegistration(input: RegistrationInput) {
  if (input.noticeVersion !== noticeVersion || input.acknowledgmentAccepted !== true) {
    throw new Error('acknowledgment');
  }
  const fullName = name(input.fullName);
  if (!fullName) throw new Error('profile');

  const parsedBirth = parseIsoBirthDate(input.birthDate);
  let resolvedAge: number;
  if (parsedBirth) {
    if (
      input.ageYears !== undefined &&
      input.ageYears !== null &&
      (!Number.isInteger(input.ageYears) || input.ageYears < 0 || input.ageYears > 130)
    ) {
      throw new Error('profile');
    }
    resolvedAge = parsedBirth.ageYears;
  } else {
    if (
      typeof input.ageYears !== 'number' ||
      !Number.isInteger(input.ageYears) ||
      input.ageYears < 0 ||
      input.ageYears > 130
    ) {
      throw new Error('profile');
    }
    resolvedAge = input.ageYears;
  }

  if (typeof input.lrn !== 'string' || !/^\d{12}$/.test(input.lrn)) {
    throw new Error('lrn');
  }
  const enrollmentCode =
    typeof input.enrollmentCode === 'string' &&
    /^[A-Za-z0-9_-]{16,128}$/.test(input.enrollmentCode.trim())
      ? input.enrollmentCode.trim().toUpperCase()
      : null;
  const secondaryName = name(input.secondaryName);
  const secondaryPhone = phone(input.secondaryPhone);
  if (Boolean(secondaryName) !== Boolean(secondaryPhone)) throw new Error('secondary');
  return {
    fullName,
    ageYears: resolvedAge,
    birthDate: parsedBirth?.birthDate ?? null,
    status: 'pending_review',
    lrn: input.lrn,
    enrollmentCode,
    gender: optionalText(input.gender, 40),
    personalContactNumber: phone(input.personalPhone),
    emergencyContacts: {
      primary: {
        fullName: name(input.guardianName),
        relationship: optionalText(input.guardianRelationship, 40),
        phoneNumber: phone(input.guardianPhone),
      },
      secondary: {
        fullName: secondaryName,
        phoneNumber: secondaryPhone,
      },
    },
  };
}
