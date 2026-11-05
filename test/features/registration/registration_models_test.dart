import 'package:flutter_test/flutter_test.dart';
import 'package:resqme/features/registration/models/registration_draft.dart';
import 'package:resqme/features/registration/models/student_registration_profile.dart';

void main() {
  test(
    'draft normalizes private fields and excludes credentials from payload',
    () {
      final draft = RegistrationDraft(
        fullName: ' Synthetic Student ',
        ageYears: 17,
        email: 'synthetic@example.test',
        password: 'secret-value',
        gender: 'Female',
        personalPhone: '0912 345 6789',
        secondaryName: 'Synthetic Contact',
        secondaryPhone: '+63 912 345 6789',
      );
      final payload = draft.toProfilePayload();
      expect(payload['fullName'], 'Synthetic Student');
      expect(payload['personalPhone'], '09123456789');
      expect(payload['guardianName'], null);
      expect(payload.keys, isNot(contains('password')));
      expect(payload.keys, isNot(contains('email')));
      expect(draft.toString(), isNot(contains('secret-value')));
      expect(draft.toString(), isNot(contains('Synthetic Contact')));
    },
  );
  test(
    'profile reads absent optional fields defensively and stays restricted',
    () {
      final profile = StudentRegistrationProfile.fromFirestore({
        'schemaVersion': 1,
        'fullName': 'Synthetic Student',
        'ageYearsAtRegistration': 18,
        'status': 'pending_review',
        'lrn': null,
      });
      expect(profile.status, 'pending_review');
      expect(profile.personalPhone, null);
      expect(profile.lrn, null);
      expect(profile.canAccessRestrictedFeatures, false);
      expect(
        () => StudentRegistrationProfile.fromFirestore({'status': 'approved'}),
        throwsFormatException,
      );
    },
  );
}
