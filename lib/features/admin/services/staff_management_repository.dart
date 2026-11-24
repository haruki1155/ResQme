import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/data/account_operation_lock.dart';

class AuthorizedAccountSummary {
  const AuthorizedAccountSummary({
    required this.uid,
    required this.loginId,
    required this.fullName,
    required this.position,
    required this.status,
    required this.active,
    required this.mustChangePassword,
    required this.hasActiveDevice,
  });

  final String uid;
  final String loginId;
  final String fullName;
  final String position;
  final String status;
  final bool active;
  final bool mustChangePassword;
  final bool hasActiveDevice;

  bool get isSuspended => status == 'suspended';
  bool get isRevoked => status == 'revoked';
}

class IssuedAuthorizedCredentials {
  const IssuedAuthorizedCredentials({
    required this.uid,
    required this.loginId,
    required this.temporaryPassword,
    required this.fullName,
    required this.position,
  });

  final String uid;
  final String loginId;
  final String temporaryPassword;
  final String fullName;
  final String position;
}

abstract interface class StaffManagementRepository {
  Future<List<AuthorizedAccountSummary>> listAccounts({String search = ''});
  Future<IssuedAuthorizedCredentials> createAccount({
    required String fullName,
    required String position,
  });
  Future<void> updateAccount({
    required String targetUid,
    required String fullName,
    required String position,
  });
  Future<void> setAccountStatus({
    required String targetUid,
    required String action,
  });
  Future<IssuedAuthorizedCredentials> resetPassword({
    required String targetUid,
    required String fullName,
    required String position,
  });
  Future<void> revokeDevice({required String targetUid});
}

class FirebaseStaffManagementRepository implements StaffManagementRepository {
  FirebaseStaffManagementRepository({
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

  HttpsCallable _callable(String name) => functions.httpsCallable(
        name,
        options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
      );

  @override
  Future<List<AuthorizedAccountSummary>> listAccounts({String search = ''}) =>
      operationLock.run(() async {
        final result = await _callable('listAuthorizedAccounts')
            .call<dynamic>(<String, dynamic>{'search': search.trim()});
        final raw = Map<String, dynamic>.from(result.data as Map);
        final list = (raw['accounts'] as List?) ?? const [];
        return list.map((item) {
          final row = Map<String, dynamic>.from(item as Map);
          return AuthorizedAccountSummary(
            uid: row['uid'] as String,
            loginId: row['loginId'] as String? ?? '',
            fullName: row['fullName'] as String? ?? '',
            position: row['position'] as String? ?? '',
            status: row['status'] as String? ?? 'active',
            active: row['active'] == true,
            mustChangePassword: row['mustChangePassword'] == true,
            hasActiveDevice: row['hasActiveDevice'] == true,
          );
        }).toList();
      });

  @override
  Future<IssuedAuthorizedCredentials> createAccount({
    required String fullName,
    required String position,
  }) =>
      operationLock.run(() async {
        final result = await _callable('createAuthorizedAccount')
            .call<dynamic>(<String, dynamic>{
          'fullName': fullName.trim(),
          'position': position.trim(),
        });
        final row = Map<String, dynamic>.from(result.data as Map);
        return IssuedAuthorizedCredentials(
          uid: row['uid'] as String,
          loginId: row['loginId'] as String,
          temporaryPassword: row['temporaryPassword'] as String,
          fullName: row['fullName'] as String,
          position: row['position'] as String,
        );
      });

  @override
  Future<void> updateAccount({
    required String targetUid,
    required String fullName,
    required String position,
  }) =>
      operationLock.run(() async {
        await _callable('updateAuthorizedAccount')
            .call<dynamic>(<String, dynamic>{
          'targetUid': targetUid,
          'fullName': fullName.trim(),
          'position': position.trim(),
        });
      });

  @override
  Future<void> setAccountStatus({
    required String targetUid,
    required String action,
  }) =>
      operationLock.run(() async {
        await _callable('setAuthorizedAccountStatus')
            .call<dynamic>(<String, dynamic>{
          'targetUid': targetUid,
          'action': action,
        });
      });

  @override
  Future<IssuedAuthorizedCredentials> resetPassword({
    required String targetUid,
    required String fullName,
    required String position,
  }) =>
      operationLock.run(() async {
        final result = await _callable('resetAuthorizedPassword')
            .call<dynamic>(<String, dynamic>{'targetUid': targetUid});
        final row = Map<String, dynamic>.from(result.data as Map);
        return IssuedAuthorizedCredentials(
          uid: row['uid'] as String,
          loginId: row['loginId'] as String? ?? '',
          temporaryPassword: row['temporaryPassword'] as String,
          fullName: fullName,
          position: position,
        );
      });

  @override
  Future<void> revokeDevice({required String targetUid}) =>
      operationLock.run(() async {
        await _callable('revokeAuthorizedDevice')
            .call<dynamic>(<String, dynamic>{'targetUid': targetUid});
      });
}
