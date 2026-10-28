import 'package:resqme/features/welcome/data/consent_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class BooleanStore {
  Future<bool?> getBool(String key);
  Future<void> setBool(String key, bool value);
}

class SharedPreferencesBooleanStore implements BooleanStore {
  SharedPreferencesBooleanStore([SharedPreferencesAsync? preferences])
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  @override
  Future<bool?> getBool(String key) => _preferences.getBool(key);

  @override
  Future<void> setBool(String key, bool value) =>
      _preferences.setBool(key, value);
}

class SharedPreferencesConsentRepository implements ConsentRepository {
  SharedPreferencesConsentRepository(this._store);

  static const _acceptedTermsKey = 'accepted_terms_v1';

  final BooleanStore _store;

  @override
  Future<bool> hasAcceptedTerms() async {
    return await _store.getBool(_acceptedTermsKey) ?? false;
  }

  @override
  Future<void> acceptTerms() {
    return _store.setBool(_acceptedTermsKey, true);
  }
}
