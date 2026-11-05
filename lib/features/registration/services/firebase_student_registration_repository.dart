import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/registration_draft.dart';
import '../models/student_registration_profile.dart';
import 'student_registration_repository.dart';

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
  }) {
    if ([
      auth.app,
      firestore.app,
      functions.app,
    ].any((app) => app.options.projectId != 'demo-resqme')) {
      throw StateError('Registration requires the local demo project.');
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
    final uid = auth.currentUser?.uid;
    if (uid == null) return null;
    return (await firestore
            .doc('studentProfiles/$uid')
            .get(const GetOptions(source: Source.server)))
        .data();
  }

  @override
  Future<void> sendPasswordReset(String email) =>
      auth.sendPasswordResetEmail(email: email);
  @override
  Future<void> signOut() => auth.signOut();
}

class FirebaseStudentRegistrationRepository
    implements StudentRegistrationRepository {
  FirebaseStudentRegistrationRepository(this.client);
  final RegistrationClient client;
  bool _busy = false;
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
    try {
      await client.signIn(email.trim().toLowerCase(), password);
      return await loadOwnProfile();
    } catch (error) {
      return _error(error, signIn: true);
    }
  }

  @override
  Future<RegistrationResult> loadOwnProfile() async {
    if (client.currentEmail == null) {
      return const RegistrationResult(RegistrationState.signedOut);
    }
    try {
      final data = await client.readOwnProfile();
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
  Future<void> signOut() => client.signOut();
}
