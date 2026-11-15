class RegistrationDraft {
  const RegistrationDraft({
    required this.fullName,
    required this.ageYears,
    required this.email,
    required this.password,
    required this.lrn,
    this.enrollmentCode,
    this.gender,
    this.personalPhone,
    this.guardianName,
    this.guardianRelationship,
    this.guardianPhone,
    this.secondaryName,
    this.secondaryPhone,
  });
  final String fullName, email, password;
  final int ageYears;
  final String lrn;
  final String? enrollmentCode;
  final String? gender,
      personalPhone,
      guardianName,
      guardianRelationship,
      guardianPhone,
      secondaryName,
      secondaryPhone;
  static String? clean(String? value) =>
      value == null || value.trim().isEmpty ? null : value.trim();
  static String? phone(String? value) =>
      clean(value)?.replaceAll(RegExp(r'[ -]'), '');
  Map<String, dynamic> toProfilePayload() => {
    'fullName': fullName.trim(),
    'ageYears': ageYears,
    'lrn': lrn.trim(),
    'enrollmentCode': clean(enrollmentCode)?.toUpperCase(),
    'gender': clean(gender),
    'personalPhone': phone(personalPhone),
    'guardianName': clean(guardianName),
    'guardianRelationship': clean(guardianRelationship),
    'guardianPhone': phone(guardianPhone),
    'secondaryName': clean(secondaryName),
    'secondaryPhone': phone(secondaryPhone),
  };
  @override
  String toString() => 'RegistrationDraft(private)';
}
