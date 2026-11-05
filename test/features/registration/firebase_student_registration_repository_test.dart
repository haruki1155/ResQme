import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqme/features/registration/models/registration_draft.dart';
import 'package:resqme/features/registration/services/student_registration_repository.dart';
import 'package:resqme/features/registration/services/firebase_student_registration_repository.dart';

class FakeRegistrationClient implements RegistrationClient {
  @override
  String? currentEmail;
  int creates = 0, calls = 0;
  String? authError, callError;
  Map<String, dynamic>? payload;
  Map<String, dynamic>? profile = {
    'schemaVersion': 1,
    'fullName': 'Synthetic Student',
    'ageYearsAtRegistration': 17,
    'status': 'pending_guardian',
    'lrn': null,
  };
  @override
  Future<void> createAccount(String email, String password) async {
    creates++;
    if (authError != null) {
      throw FirebaseException(plugin: 'auth', code: authError!);
    }
    currentEmail = email;
  }

  @override
  Future<void> submit(Map<String, dynamic> data) async {
    calls++;
    payload = data;
    if (callError != null) {
      throw FirebaseException(plugin: 'functions', code: callError!);
    }
  }

  @override
  Future<Map<String, dynamic>?> readOwnProfile() async => profile;
  @override
  Future<void> signIn(String email, String password) async {
    if (authError != null) {
      throw FirebaseException(plugin: 'auth', code: authError!);
    }
    currentEmail = email;
  }

  @override
  Future<void> sendPasswordReset(String email) async {}
  @override
  Future<void> signOut() async {
    currentEmail = null;
  }
}

const draft = RegistrationDraft(
  fullName: 'Synthetic Student',
  ageYears: 17,
  email: 'synthetic@example.test',
  password: 'secret-password',
);

class _BlockedClient extends FakeRegistrationClient {
  final started = Completer<void>(), release = Completer<void>();
  @override
  Future<void> submit(Map<String, dynamic> data) async {
    started.complete();
    await release.future;
    await super.submit(data);
  }
}

void main() {
  test(
    'session mutations cannot switch identity during registration',
    () async {
      final client = _BlockedClient();
      final repo = FirebaseStudentRegistrationRepository(client);
      final submission = repo.register(draft, acknowledged: true);
      await client.started.future;
      expect(
        (await repo.signIn('other@example.test', 'secret-password')).state,
        RegistrationState.failure,
      );
      await expectLater(repo.signOut(), throwsStateError);
      expect(client.currentEmail, draft.email);
      client.release.complete();
      await submission;
    },
  );
  test('decline performs zero Auth and callable requests', () async {
    final client = FakeRegistrationClient();
    final repo = FirebaseStudentRegistrationRepository(client);
    expect(
      (await repo.register(draft, acknowledged: false)).state,
      RegistrationState.failure,
    );
    expect(client.creates, 0);
    expect(client.calls, 0);
  });
  test(
    'accepted registration creates once with versioned non-password payload',
    () async {
      final client = FakeRegistrationClient();
      final repo = FirebaseStudentRegistrationRepository(client);
      expect(
        (await repo.register(draft, acknowledged: true)).state,
        RegistrationState.pending,
      );
      expect(client.creates, 1);
      expect(client.calls, 1);
      expect(client.payload!['noticeVersion'], 'tier1-registration-v1');
      expect(client.payload!.containsKey('password'), false);
      expect(client.payload!.containsKey('email'), false);
    },
  );
  test(
    'Auth success and failed callable recover without duplicate Auth creation',
    () async {
      final client = FakeRegistrationClient()..callError = 'unavailable';
      final repo = FirebaseStudentRegistrationRepository(client);
      expect(
        (await repo.register(draft, acknowledged: true)).state,
        RegistrationState.authCreatedProfileIncomplete,
      );
      client.callError = null;
      expect(
        (await repo.register(draft, acknowledged: true)).state,
        RegistrationState.pending,
      );
      expect(client.creates, 1);
      expect(client.calls, 2);
    },
  );
  test('concurrent taps cannot create duplicate users', () async {
    final client = FakeRegistrationClient();
    final repo = FirebaseStudentRegistrationRepository(client);
    await Future.wait([
      repo.register(draft, acknowledged: true),
      repo.register(draft, acknowledged: true),
    ]);
    expect(client.creates, 1);
    expect(client.calls, 1);
  });
  test(
    'safe error messages and missing/approved profiles stay restricted',
    () async {
      final client = FakeRegistrationClient()
        ..authError = 'email-already-in-use';
      final repo = FirebaseStudentRegistrationRepository(client);
      expect(
        (await repo.register(draft, acknowledged: true)).message,
        contains('Sign in'),
      );
      client.authError = 'invalid-credential';
      expect(
        (await repo.signIn(draft.email, draft.password)).message,
        'Unable to sign in. Check your email and password.',
      );
      client.authError = 'network-request-failed';
      expect(
        (await repo.signIn(draft.email, draft.password)).state,
        RegistrationState.offline,
      );
      client.currentEmail = draft.email;
      client.profile = null;
      expect(
        (await repo.loadOwnProfile()).state,
        RegistrationState.authCreatedProfileIncomplete,
      );
      client.profile = {'status': 'approved'};
      expect((await repo.loadOwnProfile()).state, RegistrationState.failure);
    },
  );
}
