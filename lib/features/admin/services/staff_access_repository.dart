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
  });

  final String uid;
  final String role;
  final String schoolId;
  final bool active;

  bool get isAdmin => role == 'admin';
  bool get isAuthorized => role == 'authorized';
}

abstract interface class StaffAccessRepository {
  String? get currentUid;
  Future<void> signIn(String email, String password);
  Future<StaffAccess> loadAccess();
  Future<void> signOut();
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
  Future<void> signIn(String email, String password) =>
      operationLock.run(() async {
        await auth.signInWithEmailAndPassword(
          email: email.trim().toLowerCase(),
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
          if (data.keys
                  .toSet()
                  .difference({'role', 'schoolId', 'active'})
                  .isNotEmpty ||
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
}
