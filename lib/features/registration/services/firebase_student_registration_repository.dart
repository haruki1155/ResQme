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

abstract interface class LoginQrRegistrationClient
    implements RegistrationClient {
  Future<Map<String, dynamic>> resolveStudentLoginQr(String payload);
  Future<Map<String, dynamic>> ensureMyStudentLoginQr();
  Future<Map<String, dynamic>> replaceMyStudentLoginQr();
  Future<void> revokeMyStudentLoginQr();
}

class FlutterFireRegistrationClient
    implements RegistrationClient, LoginQrRegistrationClient {
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

  @override
  Future<Map<String, dynamic>> resolveStudentLoginQr(String payload) async {
    final res = await functions
        .httpsCallable(
          'resolveStudentLoginQr',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 10)),
        )
        .call<dynamic>({'payload': payload});
    if (res.data is! Map) {
      throw StateError('Invalid Login QR response.');
    }
    return Map<String, dynamic>.from(res.data as Map);
  }

  @override
  Future<Map<String, dynamic>> ensureMyStudentLoginQr() async {
    final res = await functions
        .httpsCallable(
          'ensureMyStudentLoginQr',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 10)),
        )
        .call<dynamic>({});
    if (res.data is! Map) {
      throw StateError('Invalid Login QR response.');
    }
    return Map<String, dynamic>.from(res.data as Map);
  }

  @override
  Future<Map<String, dynamic>> replaceMyStudentLoginQr() async {
    final res = await functions
        .httpsCallable(
          'replaceMyStudentLoginQr',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 10)),
        )
        .call<dynamic>({});
    if (res.data is! Map) {
      throw StateError('Invalid Login QR response.');
    }
    return Map<String, dynamic>.from(res.data as Map);
  }

  @override
  Future<void> revokeMyStudentLoginQr() async {
    await functions
        .httpsCallable(
          'revokeMyStudentLoginQr',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 10)),
        )
        .call<dynamic>({});
  }
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
  Future<LoginQrResolutionResult> resolveLoginQr(String qrPayload) async {
    final trimmed = qrPayload.trim();
    if (trimmed.startsWith('resqme:v1:') ||
        trimmed.startsWith('resqme:tier2:v1:')) {
      return const LoginQrResolutionResult.failure(
        'This is an emergency QR code, not a Student Login QR code.',
      );
    }
    if (!RegExp(r'^resqme:login:v1:[A-Za-z0-9_-]{43}$').hasMatch(trimmed)) {
      return const LoginQrResolutionResult.failure(
        'Invalid Student Login QR code.',
      );
    }
    final qrClient = client;
    if (qrClient is! LoginQrRegistrationClient) {
      return const LoginQrResolutionResult.failure(
        'Login QR service is unavailable. Sign in with your email and password.',
      );
    }
    try {
      final data = await qrClient.resolveStudentLoginQr(trimmed);
      final email = data['email'];
      final maskedEmail = data['maskedEmail'];
      if (email is! String ||
          email.trim().isEmpty ||
          maskedEmail is! String ||
          maskedEmail.trim().isEmpty) {
        return const LoginQrResolutionResult.failure(
          'This Login QR code is inactive, expired, or unavailable.',
        );
      }
      return LoginQrResolutionResult.resolved(
        email: email.trim().toLowerCase(),
        maskedEmail: maskedEmail.trim(),
      );
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'invalid-argument') {
        return LoginQrResolutionResult.failure(
          error.message?.isNotEmpty == true
              ? error.message!
              : 'Invalid Student Login QR code.',
        );
      }
      if (error.code == 'resource-exhausted') {
        return const LoginQrResolutionResult.failure(
          'Too many QR sign-in attempts. Wait a few minutes or sign in with email and password.',
        );
      }
      if (['unavailable', 'deadline-exceeded', 'network-request-failed']
          .contains(error.code)) {
        return const LoginQrResolutionResult.failure(
          'Connection unavailable. Check your internet connection or sign in with email and password.',
        );
      }
      return const LoginQrResolutionResult.failure(
        'This Login QR code is inactive, expired, or unavailable.',
      );
    } catch (_) {
      return const LoginQrResolutionResult.failure(
        'Unable to verify this Login QR code. Sign in with your email and password.',
      );
    }
  }

  StudentLoginQrManageResult _parseManagedLoginQr(Map<String, dynamic> data) {
    final payload = data['payload'];
    final version = data['credentialVersion'];
    final status = data['status'];
    if (payload is! String || version is! int || status is! String) {
      return const StudentLoginQrManageResult(
        errorMessage: 'Unable to load Student Login QR.',
      );
    }
    return StudentLoginQrManageResult(
      credential: StudentLoginQrCredential(
        payload: payload,
        credentialVersion: version,
        status: status,
      ),
    );
  }

  @override
  Future<StudentLoginQrManageResult> ensureMyLoginQr() async {
    final qrClient = client;
    if (qrClient is! LoginQrRegistrationClient) {
      return const StudentLoginQrManageResult(
        errorMessage: 'Login QR management is unavailable.',
      );
    }
    try {
      return _parseManagedLoginQr(await qrClient.ensureMyStudentLoginQr());
    } on FirebaseFunctionsException catch (error) {
      return StudentLoginQrManageResult(
        errorMessage: error.code == 'permission-denied'
            ? 'Student Login QR is unavailable for this account.'
            : 'Unable to load Student Login QR. Please try again.',
      );
    } catch (_) {
      return const StudentLoginQrManageResult(
        errorMessage: 'Unable to load Student Login QR. Please try again.',
      );
    }
  }

  @override
  Future<StudentLoginQrManageResult> replaceMyLoginQr() async {
    final qrClient = client;
    if (qrClient is! LoginQrRegistrationClient) {
      return const StudentLoginQrManageResult(
        errorMessage: 'Login QR management is unavailable.',
      );
    }
    try {
      return _parseManagedLoginQr(await qrClient.replaceMyStudentLoginQr());
    } catch (_) {
      return const StudentLoginQrManageResult(
        errorMessage: 'Unable to replace Student Login QR. Please try again.',
      );
    }
  }

  @override
  Future<String?> revokeMyLoginQr() async {
    final qrClient = client;
    if (qrClient is! LoginQrRegistrationClient) {
      return 'Login QR management is unavailable.';
    }
    try {
      await qrClient.revokeMyStudentLoginQr();
      return null;
    } catch (_) {
      return 'Unable to revoke Student Login QR. Please try again.';
    }
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
