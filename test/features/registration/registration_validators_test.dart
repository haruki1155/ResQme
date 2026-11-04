import 'package:flutter_test/flutter_test.dart';
import 'package:resqme/features/registration/registration_validators.dart';

void main() {
  test('validates Tier 1 registration basics', () {
    expect(isMinor(17), isTrue);
    expect(isMinor(18), isFalse);
    expect(validateFullName(''), isNotNull);
    expect(validateAge(-1), isNotNull);
    expect(validatePassword('12345678'), isNull);
    expect(validateConfirmation('x', 'y'), isNotNull);
    expect(validatePhone(null), isNull);
    expect(validateSecondaryContactPair('Name', null), isNotNull);
  });
}
