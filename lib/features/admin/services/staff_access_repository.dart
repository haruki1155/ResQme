import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/data/account_operation_lock.dart';

class StaffAccessDenied implements Exception {
  const StaffAccessDenied(this.message);
  final String message;
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

class FirebaseStaffAccessRepository implements StaffAccessRepository {
  FirebaseStaffAccessRepository({
    required this.auth,
    required this.functions,
    required this.operationLock,
    required String expectedProjectId,
  }) {
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

  @override
  String? get currentUid => auth.currentUser?.uid;

  @override
  String? get currentEmail => auth.currentUser?.email;

  @override
  Future<void> signIn(String identifier, String password) =>
      operationLock.run(() async {
        final email = normalizeStaffLoginIdentifier(identifier);
        await auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      });

  @override
  Future<StaffAccess> loadAccess() => operationLock.run(() async {
        final uid = currentUid;
        if (uid == null) {
          throw const StaffAccessDenied('Sign in is required.');
        }
        try {
          await auth.currentUser?.getIdToken(true);
          final result = await functions
              .httpsCallable(
                'getStaffAccess',
                options: HttpsCallableOptions(
                  timeout: const Duration(seconds: 10),
                ),
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
            fullName: data['fullName'] is String
                ? data['fullName'] as String
                : null,
            position: data['position'] is String
                ? data['position'] as String
                : null,
            loginId:
                data['loginId'] is String ? data['loginId'] as String : null,
          );
        } catch (error) {
          if (error is StaffAccessDenied) rethrow;
          throw const StaffAccessDenied(
            'Staff access is unavailable for this account.',
          );
        }
      });

  @override
  Future<void> signOut() => operationLock.run(auth.signOut);

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
