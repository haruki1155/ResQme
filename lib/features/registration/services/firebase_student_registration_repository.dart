import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/registration_draft.dart';
import '../models/student_registration_profile.dart';
import 'student_registration_repository.dart';
import '../../../core/data/account_operation_lock.dart';

/// Implementations must be configured for local emulators before injection.
abstract interface class RegistrationClient {
  String? get currentEmail;
  Future<void> createAccount(String email, String password);
  Future<void> submit(Map<String, dynamic> data);
  Future<Map<String, dynamic>?> readOwnProfile();
  Future<void> signIn(String email, String password);
  Future<void> sendPasswordReset(String email);
  Future<void> signOut();
}

class FlutterFireRegistrationClient implements RegistrationClient {
  FlutterFireRegistrationClient({
    required this.auth,
    required this.firestore,
    required this.functions,
    String expectedProjectId = 'demo-resqme',
  }) {
    if (!['demo-resqme', 'resqme-943ee'].contains(expectedProjectId)) {
      throw StateError('Unsupported registration project.');
    }
    if ([
          auth.app,
          firestore.app,
          functions.app,
        ].any((app) => app.options.projectId != expectedProjectId) ||
        auth.app.name != firestore.app.name ||
        auth.app.name != functions.app.name) {
      throw StateError(
        'Registration clients must share the selected Firebase app.',
      );
    }
  }
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;
  @override
  String? get currentEmail => auth.currentUser?.email;
  @override
  Future<void> createAccount(String email, String password) async {
    await auth.createUserWithEmailAndPassword(email: email, password: password);
  }

  @override
  Future<void> signIn(String email, String password) async {
    await auth.signInWithEmailAndPassword(email: email, password: password);
  }

  @override
  Future<void> submit(Map<String, dynamic> data) async {
    await functions
        .httpsCallable(
          'createStudentRegistration',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 10)),
        )
        .call<dynamic>(data);
  }

  @override
  Future<Map<String, dynamic>?> readOwnProfile() async {
    if (auth.currentUser == null) return null;
    return (await functions
            .httpsCallable(
              'getMyStudentProfile',
              options: HttpsCallableOptions(
                timeout: const Duration(seconds: 10),
              ),
            )
            .call<Map<String, dynamic>>({}))
        .data;
  }

  @override
  Future<void> sendPasswordReset(String email) =>
      auth.sendPasswordResetEmail(email: email);
  @override
  Future<void> signOut() => auth.signOut();
}

class FirebaseStudentRegistrationRepository
    implements StudentRegistrationRepository {
  FirebaseStudentRegistrationRepository(
    this.client, {
    AccountOperationLock? operationLock,
  }) : operationLock = operationLock ?? AccountOperationLock();
  final RegistrationClient client;
  final AccountOperationLock operationLock;
  bool get _busy => operationLock.busy;
  set _busy(bool value) => operationLock.busy = value;
  static const _retry =
      'Unable to complete registration. Please retry. Your account remains restricted.';
  RegistrationResult _error(Object error, {bool signIn = false}) {
    final code = error is FirebaseException ? error.code : '';
    if ([
      'network-request-failed',
      'unavailable',
      'deadline-exceeded',
    ].contains(code)) {
      return const RegistrationResult(
        RegistrationState.offline,
        message: 'Connection unavailable. Please retry.',
      );
    }
    if (code == 'email-already-in-use') {
      return const RegistrationResult(
        RegistrationState.failure,
        message: 'Unable to create account. Sign in or reset your password.',
      );
    }
    return RegistrationResult(
      RegistrationState.failure,
      message: signIn
          ? 'Unable to sign in. Check your email and password.'
          : _retry,
    );
  }

  @override
  Future<RegistrationResult> register(
    RegistrationDraft draft, {
    required bool acknowledged,
  }) async {
    if (!acknowledged || _busy) {
      return const RegistrationResult(
        RegistrationState.failure,
        message: 'Confirm the privacy acknowledgment before submitting.',
      );
    }
    _busy = true;
    var hasAccount = false;
    try {
      final email = draft.email.trim().toLowerCase();
      if (client.currentEmail != null &&
          client.currentEmail!.toLowerCase() != email) {
        return const RegistrationResult(
          RegistrationState.failure,
          message: 'Sign out before registering another account.',
        );
      }
      hasAccount = client.currentEmail != null;
      if (!hasAccount) {
        await client.createAccount(email, draft.password);
        hasAccount = true;
      }
      await client.submit({
        ...draft.toProfilePayload(),
        'noticeVersion': 'tier1-registration-v1',
        'acknowledgmentAccepted': true,
      });
      return await loadOwnProfile();
    } catch (error) {
      if (hasAccount) {
        return const RegistrationResult(
          RegistrationState.authCreatedProfileIncomplete,
          message: _retry,
        );
      }
      return _error(error);
    } finally {
      _busy = false;
    }
  }

  @override
  Future<RegistrationResult> signIn(String email, String password) async {
    if (_busy) {
      return const RegistrationResult(
        RegistrationState.failure,
        message: 'An account operation is in progress. Please wait.',
      );
    }
    _busy = true;
    try {
      await client.signIn(email.trim().toLowerCase(), password);
      return await loadOwnProfile();
    } catch (error) {
      return _error(error, signIn: true);
    } finally {
      _busy = false;
    }
  }

  @override
  Future<RegistrationResult> loadOwnProfile() async {
    final session = client.currentEmail;
    if (client.currentEmail == null) {
      return const RegistrationResult(RegistrationState.signedOut);
    }
    try {
      final data = await client.readOwnProfile();
      if (client.currentEmail != session) {
        return const RegistrationResult(
          RegistrationState.failure,
          message: 'Account changed. Please retry.',
        );
      }
      if (data == null) {
        return const RegistrationResult(
          RegistrationState.authCreatedProfileIncomplete,
          message: _retry,
        );
      }
      return RegistrationResult(
        RegistrationState.pending,
        profile: StudentRegistrationProfile.fromFirestore(data),
      );
    } catch (error) {
      return _error(error);
    }
  }

  @override
  Future<RegistrationResult> sendPasswordReset(String email) async {
    try {
      await client.sendPasswordReset(email.trim().toLowerCase());
    } catch (error) {
      if (error is! FirebaseException ||
          !['user-not-found', 'invalid-email'].contains(error.code)) {
        return _error(error);
      }
    }
    return const RegistrationResult(
      RegistrationState.signedOut,
      message:
          'If an account can receive recovery email, reset instructions will be sent.',
    );
  }

  @override
  Future<void> signOut() async {
    if (_busy) throw StateError('An account operation is in progress.');
    _busy = true;
    try {
      await client.signOut();
    } finally {
      _busy = false;
    }
  }
}
