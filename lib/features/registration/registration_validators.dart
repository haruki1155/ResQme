bool isMinor(int ageYears) => ageYears < 18;
String? validateFullName(String? value) =>
    value == null || value.trim().isEmpty ? 'Full name is required.' : null;
String? validateAge(int? value) =>
    value == null || value < 0 || value > 130 ? 'Enter a valid age.' : null;
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
