bool isMinor(int ageYears) => ageYears < 18;

String? validateFullName(String? value) =>
    value == null || value.trim().length < 2 || value.trim().length > 120
    ? 'Use 2–120 characters for the name.'
    : null;

String? validateAge(int? value) =>
    value == null || value < 0 || value > 130 ? 'Enter a valid age.' : null;

int? computeAgeYearsFromBirthDate(String? value, {DateTime? now}) {
  if (value == null) return null;
  final trimmed = value.trim();
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(trimmed)) return null;
  final parts = trimmed.split('-').map(int.parse).toList();
  final y = parts[0], m = parts[1], d = parts[2];
  if (y < 1900) return null;
  final parsed = DateTime.utc(y, m, d);
  if (parsed.year != y || parsed.month != m || parsed.day != d) return null;
  final ref = (now ?? DateTime.now()).toUtc();
  if (parsed.isAfter(ref)) return null;
  var age = ref.year - y;
  final monthDiff = ref.month - m;
  if (monthDiff < 0 || (monthDiff == 0 && ref.day < d)) {
    age -= 1;
  }
  if (age < 0 || age > 130) return null;
  return age;
}

String? validateBirthDate(
  String? value, {
  bool required = false,
  DateTime? now,
}) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) {
    return required ? 'Enter your birth date (YYYY-MM-DD).' : null;
  }
  return computeAgeYearsFromBirthDate(trimmed, now: now) == null
      ? 'Enter a valid birth date (YYYY-MM-DD).'
      : null;
}

String? validateLrn(String? value) =>
    value != null && RegExp(r'^\d{12}$').hasMatch(value)
    ? null
    : 'Enter a valid 12-digit LRN.';

// Invalid or missing codes use manual review and do not block registration.
String? validateEnrollmentCode(String? value) => null;

String? validatePassword(String? value) =>
    value == null || value.length < 8 ? 'Use at least 8 characters.' : null;

String? validateConfirmation(String? value, String password) =>
    value != password ? 'Passwords do not match.' : null;

String? validatePhone(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final v = value.replaceAll(RegExp(r'[ -]'), '');
  return RegExp(r'^(09\d{9}|\+639\d{9})$').hasMatch(v)
      ? null
      : 'Enter a valid mobile number.';
}

String? validateSecondaryContactPair(String? name, String? phone) =>
    ((name ?? '').trim().isEmpty) == ((phone ?? '').trim().isEmpty)
    ? null
    : 'Provide both secondary contact name and phone.';
