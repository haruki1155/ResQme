import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqme/features/medical/services/tier2_authorization_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'tier2_test_fakes.dart';

Matcher failure(String message) => isA<Tier2AuthorizationFailure>().having(
  (e) => e.message,
  'message',
  message,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final entry in {
    'cancelled': 'Biometric confirmation cancelled.',
    'biometric_lockout':
        'Biometrics are locked. Use your account password to continue.',
    'biometric_unavailable':
        'Biometric access is unavailable. Use your account password to continue.',
    'key_unavailable': 'Set up biometrics again using your account password.',
    'sign_failed':
        'Biometric verification failed. Try again or use your account password.',
  }.entries) {
    test(
      'biometric ${entry.key} remains distinct and never reads the record',
      () async {
        final f = Tier2Fixture();
        addTearDown(f.auth.changes.close);
        f.key.failure = PlatformException(code: entry.key);
        await expectLater(
          f.repository.readWithBiometrics(),
          throwsA(failure(entry.value)),
        );
        expect(f.functions.calls, ['issueTier2Challenge']);
      },
    );
  }
  test(
    'enrollment cancellation after correct password is not a password error',
    () async {
      final f = Tier2Fixture();
      addTearDown(f.auth.changes.close);
      f.key.failure = PlatformException(code: 'cancelled');
      await expectLater(
        f.repository.enrollWithPassword('fictional'),
        throwsA(failure('Biometric confirmation cancelled.')),
      );
      expect(f.functions.calls, ['enrollTier2Device', 'issueTier2Challenge']);
    },
  );
  test('wrong password performs no key or callable operation', () async {
    final f = Tier2Fixture();
    addTearDown(f.auth.changes.close);
    (f.auth.currentUser as TestUser).reauthError = FirebaseAuthException(
      code: 'wrong-password',
    );
    await expectLater(
      f.repository.enrollWithPassword('fictional'),
      throwsA(
        failure(
          'Password verification failed. Check your password and try again.',
        ),
      ),
    );
    expect(f.key.calls, isEmpty);
    expect(f.functions.calls, isEmpty);
  });
  for (final entry in {
    'failed-precondition': 'Please reauthenticate to access Tier 2.',
    'permission-denied': 'Tier 2 access is unavailable for this account.',
    'resource-exhausted': 'Too many Tier 2 attempts. Try again later.',
    'unavailable': 'Tier 2 could not be reached. Try again later.',
  }.entries) {
    test(
      'server ${entry.key} is not attributed to password or sensor',
      () async {
        final f = Tier2Fixture();
        addTearDown(f.auth.changes.close);
        f.functions.onCall = (_, _) async => throw FirebaseFunctionsException(
          code: entry.key,
          message: 'not displayed',
        );
        await expectLater(
          f.repository.readWithPassword('fictional'),
          throwsA(failure(entry.value)),
        );
      },
    );
  }
  for (final stage in ['reauth', 'token', 'create', 'delete', 'sign']) {
    test('account change during $stage stops the original operation', () async {
      final f = Tier2Fixture();
      addTearDown(f.auth.changes.close);
      Future<void> change() async => f.auth.switchUser(TestUser('adult-b'));
      final user = f.auth.currentUser as TestUser;
      if (stage == 'reauth') user.onReauth = change;
      if (stage == 'token') user.onToken = change;
      if (stage == 'create') f.key.onCreate = change;
      if (stage == 'delete') f.key.onDelete = change;
      if (stage == 'sign') f.key.onSign = change;
      await expectLater(
        f.repository.enrollWithPassword('fictional'),
        throwsA(failure('Account changed. Reopen Tier 2.')),
      );
      expect(f.functions.calls, isNot(contains('readMyTier2Record')));
      if (stage != 'sign') expect(f.functions.calls, isEmpty);
    });
  }
  test(
    'account away and back during signing invalidates the operation',
    () async {
      final f = Tier2Fixture();
      addTearDown(f.auth.changes.close);
      final owner = f.auth.currentUser;
      f.key.onSign = () async {
        f.auth.switchUser(TestUser('adult-b'));
        f.auth.switchUser(owner);
      };
      await expectLater(
        f.repository.readWithBiometrics(),
        throwsA(failure('Account changed. Reopen Tier 2.')),
      );
      expect(f.functions.calls, ['issueTier2Challenge']);
    },
  );
}
