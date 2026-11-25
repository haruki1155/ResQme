import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/data/account_operation_lock.dart';
import 'portal_read_coordinator.dart';

class StaffAccessDenied implements Exception, PortalSessionAuthError {
  const StaffAccessDenied(this.message);
  final String message;

  @override
  bool get isSessionAuthLoss => true;

  @override
  String toString() => message;
}

class StaffAccess {
  const StaffAccess({
    required this.uid,
    required this.role,
    required this.schoolId,
    required this.active,
    this.isMasterAdmin = false,
    this.mustChangePassword = false,
    this.requiresEmailVerification = false,
    this.emailVerified = false,
    this.fullName,
    this.position,
    this.loginId,
  });

  final String uid;
  final String role;
  final String schoolId;
  final bool active;
  final bool isMasterAdmin;
  final bool mustChangePassword;
  final bool requiresEmailVerification;
  final bool emailVerified;
  final String? fullName;
  final String? position;
  final String? loginId;

  bool get isAdmin => role == 'admin';
  bool get isAuthorized => role == 'authorized';
  bool get needsEmailVerification =>
      requiresEmailVerification && !emailVerified;
  bool get isSetupComplete => !mustChangePassword && !needsEmailVerification;
}

abstract interface class StaffAccessRepository {
  String? get currentUid;
  String? get currentEmail;
  Future<void> signIn(String identifier, String password);
  Future<StaffAccess> loadAccess();
  Future<void> signOut();
  Future<void> reauthenticate(String currentPassword);
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });
  Future<void> sendEmailVerification();
  Future<StaffAccess> reloadAndSyncEmail();
  Future<void> requestEmailUpdate({
    required String currentPassword,
    required String newEmail,
  });
  Future<void> sendPasswordResetEmail(String email);
}

/// Optional lifecycle extension allowing [AdminApp] to await cold-start
/// Firebase Auth restoration and react immediately to external session changes
/// without breaking lightweight test fakes that implement [StaffAccessRepository].
abstract interface class SessionLifecycleAccessRepository
    implements StaffAccessRepository {
  Future<String?> waitForInitialAuthUid();
  Stream<String?> get authUidChanges;
}

const _staffInternalDomain = 'staff.resqme.internal';
final _authorizedLoginIdPattern = RegExp(r'^AUTH-[A-Z0-9]{6,16}$');

/// Normalizes either an Admin email or a generated Authorized Login ID
/// (`AUTH-XXXXXXXX`) into the Firebase Auth email identifier.
String normalizeStaffLoginIdentifier(String raw) {
  final trimmed = raw.trim();
  if (trimmed.contains('@')) {
    return trimmed.toLowerCase();
  }
  final upper = trimmed.toUpperCase();
  if (_authorizedLoginIdPattern.hasMatch(upper)) {
    return '${upper.toLowerCase()}@$_staffInternalDomain';
  }
  return trimmed.toLowerCase();
}

class FirebaseStaffAccessRepository
    implements SessionLifecycleAccessRepository {
  FirebaseStaffAccessRepository({
    required this.auth,
    required this.functions,
    required this.operationLock,
    required String expectedProjectId,
    this.callableTimeout = const Duration(seconds: 20),
    this.maxLoadAttempts = 3,
    Future<void> Function(Duration)? retryDelay,
  }) : _retryDelay = retryDelay ?? Future<void>.delayed {
    if (!['demo-resqme', 'resqme-943ee'].contains(expectedProjectId) ||
        auth.app.options.projectId != expectedProjectId ||
        functions.app.options.projectId != expectedProjectId ||
        auth.app.name != functions.app.name) {
      throw StateError('Unexpected staff Firebase app.');
    }
  }

  final FirebaseAuth auth;
  final FirebaseFunctions functions;
  final AccountOperationLock operationLock;
  final Duration callableTimeout;
  final int maxLoadAttempts;
  final Future<void> Function(Duration) _retryDelay;

  Future<StaffAccess>? _inFlightLoadAccess;
  String? _inFlightLoadUid;

  @override
  String? get currentUid => auth.currentUser?.uid;

  @override
  String? get currentEmail => auth.currentUser?.email;

  @override
  Future<String?> waitForInitialAuthUid() async {
    final immediate = auth.currentUser?.uid;
    if (immediate != null) return immediate;
    try {
      final restored = await auth
          .authStateChanges()
          .first
          .timeout(const Duration(seconds: 4), onTimeout: () => auth.currentUser);
      return restored?.uid;
    } catch (_) {
      return auth.currentUser?.uid;
    }
  }

  @override
  Stream<String?> get authUidChanges =>
      auth.authStateChanges().map((u) => u?.uid);

  @override
  Future<void> signIn(String identifier, String password) =>
      operationLock.run(() async {
        _inFlightLoadAccess = null;
        _inFlightLoadUid = null;
        final email = normalizeStaffLoginIdentifier(identifier);
        await auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      });

  @override
  Future<StaffAccess> loadAccess() {
    final uid = currentUid;
    if (uid == null) {
      return Future<StaffAccess>.error(
        const StaffAccessDenied('Sign in is required.'),
      );
    }
    if (_inFlightLoadAccess != null && _inFlightLoadUid == uid) {
      return _inFlightLoadAccess!;
    }
    final future = _loadAccessWithRetry(uid);
    _inFlightLoadUid = uid;
    _inFlightLoadAccess = future;
    future.whenComplete(() {
      if (identical(_inFlightLoadAccess, future)) {
        _inFlightLoadAccess = null;
        _inFlightLoadUid = null;
      }
    }).ignore();
    return future;
  }

  Future<StaffAccess> _loadAccessWithRetry(String uid) async {
    var attempt = 0;
    while (true) {
      attempt += 1;
      if (currentUid != uid) {
        throw const StaffAccessDenied('Sign in is required.');
      }
      try {
        await auth.currentUser?.getIdToken(attempt == 1);
        final result = await functions
            .httpsCallable(
              'getStaffAccess',
              options: HttpsCallableOptions(timeout: callableTimeout),
            )
            .call<dynamic>(<String, dynamic>{});
        if (currentUid != uid || result.data is! Map) {
          throw const StaffAccessDenied(
            'Staff access is unavailable for this account.',
          );
        }
        final data = Map<String, dynamic>.from(result.data as Map);
        final role = data['role'];
        final schoolId = data['schoolId'];
        final active = data['active'];
        const allowedKeys = {
          'role',
          'schoolId',
          'active',
          'isMasterAdmin',
          'mustChangePassword',
          'requiresEmailVerification',
          'emailVerified',
          'fullName',
          'position',
          'loginId',
        };
        if (data.keys.toSet().difference(allowedKeys).isNotEmpty ||
            (role != 'admin' && role != 'authorized') ||
            schoolId is! String ||
            schoolId.isEmpty ||
            active != true) {
          throw const StaffAccessDenied(
            'Staff access is unavailable for this account.',
          );
        }
        return StaffAccess(
          uid: uid,
          role: role as String,
          schoolId: schoolId,
          active: true,
          isMasterAdmin: data['isMasterAdmin'] == true,
          mustChangePassword: data['mustChangePassword'] == true,
          requiresEmailVerification:
              data['requiresEmailVerification'] == true,
          emailVerified: data['emailVerified'] == true,
          fullName:
              data['fullName'] is String ? data['fullName'] as String : null,
          position:
              data['position'] is String ? data['position'] as String : null,
          loginId: data['loginId'] is String ? data['loginId'] as String : null,
        );
      } catch (error) {
        if (error is StaffAccessDenied) rethrow;
        if (PortalErrorClassifier.isTransientError(error)) {
          if (attempt < maxLoadAttempts && currentUid == uid) {
            await _retryDelay(
              Duration(milliseconds: 250 * (1 << (attempt - 1))),
            );
            continue;
          }
          throw StaffAccessTransientError(
            'Unable to verify your Portal session right now due to a temporary connection or service delay. Please retry.',
            firebaseCode: PortalErrorClassifier.sanitizedCode(error),
          );
        }
        throw const StaffAccessDenied(
          'Staff access is unavailable for this account.',
        );
      }
    }
  }

  @override
  Future<void> signOut() async {
    _inFlightLoadAccess = null;
    _inFlightLoadUid = null;
    await auth.signOut();
  }

  @override
  Future<void> reauthenticate(String currentPassword) =>
      operationLock.run(() async {
        final user = auth.currentUser;
        final email = user?.email;
        if (user == null || email == null || email.isEmpty) {
          throw const StaffAccessDenied('Sign in is required.');
        }
        final credential = EmailAuthProvider.credential(
          email: email,
          password: currentPassword,
        );
        await user.reauthenticateWithCredential(credential);
        await user.getIdToken(true);
      });

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) =>
      operationLock.run(() async {
        final user = auth.currentUser;
        final email = user?.email;
        if (user == null || email == null || email.isEmpty) {
          throw const StaffAccessDenied('Sign in is required.');
        }
        final credential = EmailAuthProvider.credential(
          email: email,
          password: currentPassword,
        );
        await user.reauthenticateWithCredential(credential);
        await user.getIdToken(true);
        await functions
            .httpsCallable(
              'changeMyStaffPassword',
              options: HttpsCallableOptions(
                timeout: const Duration(seconds: 15),
              ),
            )
            .call<dynamic>(<String, dynamic>{'newPassword': newPassword});
        // Re-sign in cleanly with the updated password so the session stays fresh.
        await auth.signInWithEmailAndPassword(
          email: email,
          password: newPassword,
        );
      });

  @override
  Future<void> sendEmailVerification() => operationLock.run(() async {
        final user = auth.currentUser;
        if (user == null) {
          throw const StaffAccessDenied('Sign in is required.');
        }
        await user.sendEmailVerification();
      });

  @override
  Future<StaffAccess> reloadAndSyncEmail() async {
    await operationLock.run(() async {
      final user = auth.currentUser;
      if (user == null) {
        throw const StaffAccessDenied('Sign in is required.');
      }
      await user.reload();
      await auth.currentUser?.getIdToken(true);
      if (auth.currentUser?.emailVerified == true) {
        await functions
            .httpsCallable(
              'syncMasterAdminEmail',
              options: HttpsCallableOptions(
                timeout: const Duration(seconds: 10),
              ),
            )
            .call<dynamic>(<String, dynamic>{});
      }
    });
    return loadAccess();
  }

  @override
  Future<void> requestEmailUpdate({
    required String currentPassword,
    required String newEmail,
  }) =>
      operationLock.run(() async {
        final user = auth.currentUser;
        final email = user?.email;
        if (user == null || email == null || email.isEmpty) {
          throw const StaffAccessDenied('Sign in is required.');
        }
        final credential = EmailAuthProvider.credential(
          email: email,
          password: currentPassword,
        );
        await user.reauthenticateWithCredential(credential);
        await user.verifyBeforeUpdateEmail(newEmail.trim().toLowerCase());
      });

  @override
  Future<void> sendPasswordResetEmail(String email) =>
      operationLock.run(() async {
        final trimmed = email.trim().toLowerCase();
        if (!trimmed.contains('@') || trimmed.endsWith('@$_staffInternalDomain')) {
          throw const StaffAccessDenied(
            'Password recovery email is only available for Admin email accounts.',
          );
        }
        await auth.sendPasswordResetEmail(email: trimmed);
      });
}
