import 'package:flutter_test/flutter_test.dart';
import 'package:resqme/features/welcome/data/shared_preferences_consent_repository.dart';

class _FakeBooleanStore implements BooleanStore {
  final Map<String, bool> values = {};

  @override
  Future<bool?> getBool(String key) async => values[key];

  @override
  Future<void> setBool(String key, bool value) async {
    values[key] = value;
  }
}

void main() {
  test('returns false until Terms & Privacy has been accepted', () async {
    final repository = SharedPreferencesConsentRepository(_FakeBooleanStore());

    expect(await repository.hasAcceptedTerms(), isFalse);
  });

  test('persists acceptance for later app launches', () async {
    final store = _FakeBooleanStore();
    final repository = SharedPreferencesConsentRepository(store);

    await repository.acceptTerms();

    expect(await repository.hasAcceptedTerms(), isTrue);
  });
}
