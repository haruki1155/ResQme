import 'package:flutter_test/flutter_test.dart';
import 'package:resqme/features/registration/registration_validators.dart';

void main() {
  test('validates Tier 1 registration basics', () {
    expect(isMinor(17), isTrue);
    expect(isMinor(18), isFalse);
    expect(validateFullName(''), isNotNull);
    expect(validateLrn('001234567890'), isNull);
    for (final invalid in [
      null,
      '',
      '12345678901',
      '1234567890123',
      '12345678901x',
    ]) {
      expect(validateLrn(invalid), isNotNull);
    }
    expect(validateEnrollmentCode(''), isNull);
    expect(validateEnrollmentCode(' short '), isNull);
    expect(validateAge(-1), isNotNull);
    expect(validatePassword('12345678'), isNull);
    expect(validateConfirmation('x', 'y'), isNotNull);
    expect(validatePhone(null), isNull);
    expect(validateSecondaryContactPair('Name', null), isNotNull);
  });
}
