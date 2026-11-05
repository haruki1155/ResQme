class StudentRegistrationProfile {
  StudentRegistrationProfile._(
    this.fullName,
    this.ageYearsAtRegistration,
    this.status,
    this.gender,
    this.personalPhone,
    this.guardianName,
    this.guardianRelationship,
    this.guardianPhone,
    this.secondaryName,
    this.secondaryPhone,
  );
  final String fullName, status;
  final int ageYearsAtRegistration;
  final String? gender,
      personalPhone,
      guardianName,
      guardianRelationship,
      guardianPhone,
      secondaryName,
      secondaryPhone;
  int get schemaVersion => 1;
  String? get lrn => null;
  bool get canAccessRestrictedFeatures => false;
  factory StudentRegistrationProfile.fromFirestore(Map<String, dynamic> data) {
    if (data['schemaVersion'] != 1 ||
        data['fullName'] is! String ||
        (data['fullName'] as String).trim().length < 2 ||
        data['ageYearsAtRegistration'] is! int ||
        (data['ageYearsAtRegistration'] as int) < 0 ||
        (data['ageYearsAtRegistration'] as int) > 130 ||
        !['pending_review', 'pending_guardian'].contains(data['status']) ||
        data['lrn'] != null) {
      throw const FormatException('Registration unavailable.');
    }
    final contacts = data['emergencyContacts'];
    if (contacts != null && contacts is! Map) {
      throw const FormatException('Registration unavailable.');
    }
    final primary = contacts is Map ? contacts['primary'] : null;
    final secondary = contacts is Map ? contacts['secondary'] : null;
    if ((primary != null && primary is! Map) ||
        (secondary != null && secondary is! Map)) {
      throw const FormatException('Registration unavailable.');
    }
    String? optional(dynamic value) {
      if (value != null && value is! String) {
        throw const FormatException('Registration unavailable.');
      }
      return value as String?;
    }

    return StudentRegistrationProfile._(
      data['fullName'] as String,
      data['ageYearsAtRegistration'] as int,
      data['status'] as String,
      optional(data['gender']),
      optional(data['personalContactNumber']),
      optional(primary?['fullName']),
      optional(primary?['relationship']),
      optional(primary?['phoneNumber']),
      optional(secondary?['fullName']),
      optional(secondary?['phoneNumber']),
    );
  }
  @override
  String toString() => 'StudentRegistrationProfile(private)';
}
