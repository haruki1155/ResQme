import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/data/account_operation_lock.dart';
import 'portal_read_coordinator.dart';

class StaffManagementException implements Exception, PortalSessionAuthError {
  const StaffManagementException(
    this.message, {
    this.kind = PortalErrorKind.transient,
    this.firebaseCode,
    this.isSessionAuthLoss = false,
  });

  final String message;
  final PortalErrorKind kind;
  final String? firebaseCode;

  @override
  final bool isSessionAuthLoss;

  @override
  String toString() => message;
}

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
    PortalReadCoordinator? readCoordinator,
  }) : readCoordinator = readCoordinator ??
            PortalReadCoordinator(
              currentUidProvider: () => auth.currentUser?.uid,
            ) {
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
  final PortalReadCoordinator readCoordinator;

  HttpsCallable _callable(String name) => functions.httpsCallable(
        name,
        options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
      );

  Never _rethrowMapped(Object error, String fallback) {
    if (error is StaffManagementException) {
      if (error.isSessionAuthLoss) {
        readCoordinator.reportExternalError(error);
      }
      throw error;
    }
    if (error is StateError &&
        (error.message == 'unauthenticated' ||
            error.message == 'scope_invalidated')) {
      const mapped = StaffManagementException(
        'Sign in is required.',
        kind: PortalErrorKind.authorization,
        firebaseCode: 'unauthenticated',
        isSessionAuthLoss: true,
      );
      readCoordinator.reportExternalError(mapped);
      throw mapped;
    }
    final kind = PortalErrorClassifier.classify(error);
    final code = PortalErrorClassifier.sanitizedCode(error);
    final sessionLoss = PortalErrorClassifier.isSessionAuthorizationError(error);
    if (sessionLoss) {
      readCoordinator.reportExternalError(error);
    }
    if (error is FirebaseFunctionsException &&
        error.message != null &&
        error.message!.trim().isNotEmpty) {
      throw StaffManagementException(
        error.message!.trim(),
        kind: kind,
        firebaseCode: code,
        isSessionAuthLoss: sessionLoss,
      );
    }
    throw StaffManagementException(
      fallback,
      kind: kind,
      firebaseCode: code,
      isSessionAuthLoss: sessionLoss,
    );
  }

  @override
  Future<List<AuthorizedAccountSummary>> listAccounts({String search = ''}) async {
    final normalized = search.trim();
    try {
      return await readCoordinator.runRead<List<AuthorizedAccountSummary>>(
        key: 'listAuthorizedAccounts:search=$normalized',
        action: () async {
          final result = await _callable('listAuthorizedAccounts')
              .call<dynamic>(<String, dynamic>{'search': normalized});
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
        },
      );
    } catch (error) {
      _rethrowMapped(error, 'Unable to load Authorized personnel.');
    }
  }

  @override
  Future<IssuedAuthorizedCredentials> createAccount({
    required String fullName,
    required String position,
  }) =>
      operationLock.run(() async {
        try {
          final result = await _callable('createAuthorizedAccount')
              .call<dynamic>(<String, dynamic>{
            'fullName': fullName.trim(),
            'position': position.trim(),
          });
          readCoordinator.notifyMutation();
          final row = Map<String, dynamic>.from(result.data as Map);
          return IssuedAuthorizedCredentials(
            uid: row['uid'] as String,
            loginId: row['loginId'] as String,
            temporaryPassword: row['temporaryPassword'] as String,
            fullName: row['fullName'] as String,
            position: row['position'] as String,
          );
        } catch (error) {
          _rethrowMapped(error, 'Unable to create Authorized account.');
        }
      });

  @override
  Future<void> updateAccount({
    required String targetUid,
    required String fullName,
    required String position,
  }) =>
      operationLock.run(() async {
        try {
          await _callable('updateAuthorizedAccount')
              .call<dynamic>(<String, dynamic>{
            'targetUid': targetUid,
            'fullName': fullName.trim(),
            'position': position.trim(),
          });
          readCoordinator.notifyMutation();
        } catch (error) {
          _rethrowMapped(error, 'Unable to update Authorized account.');
        }
      });

  @override
  Future<void> setAccountStatus({
    required String targetUid,
    required String action,
  }) =>
      operationLock.run(() async {
        try {
          await _callable('setAuthorizedAccountStatus')
              .call<dynamic>(<String, dynamic>{
            'targetUid': targetUid,
            'action': action,
          });
          readCoordinator.notifyMutation();
        } catch (error) {
          _rethrowMapped(error, 'Unable to update Authorized account status.');
        }
      });

  @override
  Future<IssuedAuthorizedCredentials> resetPassword({
    required String targetUid,
    required String fullName,
    required String position,
  }) =>
      operationLock.run(() async {
        try {
          final result = await _callable('resetAuthorizedPassword')
              .call<dynamic>(<String, dynamic>{'targetUid': targetUid});
          readCoordinator.notifyMutation();
          final row = Map<String, dynamic>.from(result.data as Map);
          return IssuedAuthorizedCredentials(
            uid: row['uid'] as String,
            loginId: row['loginId'] as String? ?? '',
            temporaryPassword: row['temporaryPassword'] as String,
            fullName: fullName,
            position: position,
          );
        } catch (error) {
          _rethrowMapped(error, 'Unable to reset Authorized password.');
        }
      });

  @override
  Future<void> revokeDevice({required String targetUid}) =>
      operationLock.run(() async {
        try {
          await _callable('revokeAuthorizedDevice')
              .call<dynamic>(<String, dynamic>{'targetUid': targetUid});
          readCoordinator.notifyMutation();
        } catch (error) {
          _rethrowMapped(error, 'Unable to revoke Authorized device.');
        }
      });
}
