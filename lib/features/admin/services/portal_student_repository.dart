import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/data/account_operation_lock.dart';
import '../../medical/services/platform_tier2_key.dart';
import 'portal_read_coordinator.dart';
import 'staff_tier2_repository.dart';

class PortalStudentException implements Exception, PortalSessionAuthError {
  const PortalStudentException(
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

  bool get isAuthorizationError => kind == PortalErrorKind.authorization;
  bool get isTransient => kind == PortalErrorKind.transient;

  @override
  String toString() => message;
}

class PortalDashboardStats {
  const PortalDashboardStats({
    required this.schoolId,
    required this.rosterAvailable,
    required this.importedRosterCount,
    required this.registeredStudentsCount,
    required this.verifiedStudentsCount,
    required this.disabledStudentsCount,
    required this.authorizedPersonnelCount,
  });

  final String schoolId;
  final bool rosterAvailable;
  final int importedRosterCount;
  final int registeredStudentsCount;
  final int verifiedStudentsCount;
  final int disabledStudentsCount;
  final int authorizedPersonnelCount;
}

class SchoolStudentSummary {
  const SchoolStudentSummary({
    required this.uid,
    required this.fullName,
    required this.maskedLrn,
    this.hasLrn = false,
    required this.gradeLevel,
    required this.accountCategory,
    required this.schoolApprovalStatus,
    required this.verificationMethod,
  });

  final String uid;
  final String fullName;
  final String? maskedLrn;
  final bool hasLrn;
  final String gradeLevel;
  final String accountCategory; // 'registered' | 'verified' | 'disabled'
  final String schoolApprovalStatus;
  final String? verificationMethod;

  bool get isVerified => accountCategory == 'verified';
  bool get isDisabled => accountCategory == 'disabled';
  bool get isRegisteredUnverified => accountCategory == 'registered';
}

class SchoolStudentPage {
  const SchoolStudentPage({
    required this.students,
    required this.nextCursor,
    required this.totalMatched,
    required this.availableGrades,
  });

  final List<SchoolStudentSummary> students;
  final String? nextCursor;
  final int totalMatched;
  final List<String> availableGrades;
}

class SchoolStudentDetails {
  const SchoolStudentDetails({
    required this.uid,
    required this.fullName,
    required this.maskedLrn,
    this.hasLrn = false,
    required this.gradeLevel,
    required this.sex,
    required this.birthDate,
    required this.ageYearsAtRegistration,
    required this.accountCategory,
    required this.accountDisabled,
    required this.registrationStatus,
    required this.schoolApprovalStatus,
    required this.verificationMethod,
    required this.verificationOutcome,
    required this.medicalCompletionStatus,
    required this.guardianAuthorizationStatus,
    required this.qrStatus,
    this.credentialVersion = 0,
    required this.canVerifyManually,
  });

  final String uid;
  final String fullName;
  final String? maskedLrn;
  final bool hasLrn;
  final String gradeLevel;
  final String? sex;
  final String? birthDate;
  final int? ageYearsAtRegistration;
  final String accountCategory;
  final bool accountDisabled;
  final String registrationStatus;
  final String schoolApprovalStatus;
  final String? verificationMethod;
  final String verificationOutcome;
  final String medicalCompletionStatus;
  final String guardianAuthorizationStatus;
  final String qrStatus;
  final int credentialVersion;
  final bool canVerifyManually;
}

class QrReplacementResult {
  const QrReplacementResult({
    required this.studentUid,
    required this.verificationStatus,
    required this.credentialVersion,
    required this.reason,
    this.issuedAt,
  });

  final String studentUid;
  final String verificationStatus;
  final int credentialVersion;
  final String reason;
  final String? issuedAt;
}

class ActivityLogEntry {
  const ActivityLogEntry({
    required this.id,
    required this.sourceCollection,
    required this.category,
    required this.action,
    required this.actionLabel,
    required this.outcome,
    required this.actorUid,
    required this.actorRole,
    required this.targetUid,
    required this.summary,
    required this.reasonCode,
    required this.method,
    required this.timestamp,
  });

  final String id;
  final String sourceCollection;
  final String category; // 'security' | 'management' | 'tier2'
  final String action;
  final String actionLabel;
  final String outcome; // 'allowed' | 'denied'
  final String actorUid;
  final String actorRole;
  final String? targetUid;
  final String summary;
  final String? reasonCode;
  final String? method;
  final String timestamp;
}

class ActivityLogPage {
  const ActivityLogPage({
    required this.entries,
    required this.nextCursor,
    required this.totalMatched,
  });

  final List<ActivityLogEntry> entries;
  final String? nextCursor;
  final int totalMatched;
}

class Sf1PickedFile {
  const Sf1PickedFile({
    required this.fileName,
    required this.fileBase64,
  });

  final String fileName;
  final String fileBase64;
}

class RosterImportPreviewRow {
  const RosterImportPreviewRow({
    required this.rowNumber,
    required this.status,
    required this.maskedLrn,
    required this.fullName,
    required this.gradeLevel,
    required this.sex,
    required this.birthDate,
    required this.reason,
  });

  final int rowNumber;
  final String status;
  final String? maskedLrn;
  final String fullName;
  final String gradeLevel;
  final String? sex;
  final String? birthDate;
  final String? reason;
}

class RosterImportPreview {
  const RosterImportPreview({
    required this.previewId,
    required this.fileName,
    required this.detectedGradeLevel,
    required this.confirmedGradeLevel,
    required this.totalRows,
    required this.newCount,
    required this.unchangedCount,
    required this.proposedUpdateCount,
    required this.duplicateCount,
    required this.conflictCount,
    required this.invalidCount,
    required this.rows,
  });

  final String previewId;
  final String fileName;
  final String? detectedGradeLevel;
  final String confirmedGradeLevel;
  final int totalRows;
  final int newCount;
  final int unchangedCount;
  final int proposedUpdateCount;
  final int duplicateCount;
  final int conflictCount;
  final int invalidCount;
  final List<RosterImportPreviewRow> rows;
}

class RosterGeneratedCredential {
  const RosterGeneratedCredential({
    required this.maskedLrn,
    required this.fullName,
    required this.gradeLevel,
    required this.enrollmentCode,
  });

  final String maskedLrn;
  final String fullName;
  final String gradeLevel;
  final String enrollmentCode;
}

class RosterImportCommitResult {
  const RosterImportCommitResult({
    required this.importId,
    required this.status,
    required this.committedCount,
    required this.newCount,
    required this.updatedCount,
    required this.generatedCredentials,
  });

  final String importId;
  final String status;
  final int committedCount;
  final int newCount;
  final int updatedCount;
  final List<RosterGeneratedCredential> generatedCredentials;
}

class RosterImportHistoryItem {
  const RosterImportHistoryItem({
    required this.importId,
    required this.fileName,
    required this.confirmedGradeLevel,
    required this.status,
    required this.committedCount,
    required this.newCount,
    required this.updatedCount,
    required this.timestamp,
  });

  final String importId;
  final String fileName;
  final String confirmedGradeLevel;
  final String status;
  final int committedCount;
  final int newCount;
  final int updatedCount;
  final String timestamp;
}

class SchoolRosterEntry {
  const SchoolRosterEntry({
    required this.rosterId,
    required this.displayName,
    required this.maskedLrn,
    this.hasLrn = false,
    required this.gradeLevel,
    required this.sex,
    required this.birthDate,
    required this.registrationState,
    required this.claimedStudentUid,
  });

  final String rosterId;
  final String displayName;
  final String? maskedLrn;
  final bool hasLrn;
  final String gradeLevel;
  final String? sex;
  final String? birthDate;
  final String registrationState; // 'not_registered' | 'registered' | 'verified'
  final String? claimedStudentUid;
}

class SchoolRosterPage {
  const SchoolRosterPage({
    required this.rosterAvailable,
    required this.entries,
    required this.nextCursor,
    required this.totalMatched,
    required this.availableGrades,
  });

  final bool rosterAvailable;
  final List<SchoolRosterEntry> entries;
  final String? nextCursor;
  final int totalMatched;
  final List<String> availableGrades;
}

abstract interface class PortalStudentRepository {
  String? get currentAdminUid;
  Future<PortalDashboardStats> loadDashboardStats();
  Future<SchoolStudentPage> listStudents({
    String search = '',
    String statusFilter = 'all',
    String? gradeFilter,
    int limit = 20,
    String? cursor,
  });
  Future<SchoolStudentDetails> getStudentDetails(String studentUid);
  Future<void> verifyStudentAccount({
    required String studentUid,
    required String requestId,
  });
  Future<void> setStudentAccountStatus({
    required String studentUid,
    required String action,
  });
  Future<SchoolRosterPage> listRoster({
    String search = '',
    String? gradeFilter,
    int limit = 20,
    String? cursor,
  });
  Future<String> revealLrnWithPassword({
    required String targetType,
    required String targetId,
    required String password,
  });
  Future<String> revealLrnWithBiometric({
    required String targetType,
    required String targetId,
  });
  Future<QrReplacementResult> replaceStudentQrWithPassword({
    required String studentUid,
    required String reason,
    required String requestId,
    required String password,
  });
  Future<QrReplacementResult> replaceStudentQrWithBiometric({
    required String studentUid,
    required String reason,
    required String requestId,
  });
  Future<ActivityLogPage> listActivityLogs({
    String category = 'all',
    String outcome = 'all',
    String? actorUid,
    String search = '',
    String? startDate,
    String? endDate,
    int limit = 25,
    String? cursor,
  });
  Future<Sf1PickedFile?> pickSf1ExcelFile();
  Future<RosterImportPreview> previewRosterImport({
    required String fileName,
    required String fileBase64,
    String? confirmedGradeLevel,
  });
  Future<RosterImportCommitResult> commitRosterImport({
    required String previewId,
    required String requestId,
  });
  Future<List<RosterImportHistoryItem>> listRosterImports();
  Future<void> setSecureScreen(bool enabled);
}

/// Optional server-side roster registration-state filter extension so
/// [StudentRosterScreen] filters across all pages on the server while keeping
/// lightweight test fakes backward-compatible.
abstract interface class RegistrationFilterableRosterRepository
    implements PortalStudentRepository {
  Future<SchoolRosterPage> listRosterFiltered({
    String search = '',
    String? gradeFilter,
    String registrationFilter = 'all',
    int limit = 20,
    String? cursor,
  });
}

class FirebasePortalStudentRepository
    implements RegistrationFilterableRosterRepository {
  FirebasePortalStudentRepository({
    required this.auth,
    required this.functions,
    required this.operationLock,
    required String expectedProjectId,
    PlatformTier2Key? keyProvider,
    PortalReadCoordinator? readCoordinator,
  })  : keyProvider = keyProvider ?? PlatformTier2Key(),
        readCoordinator = readCoordinator ??
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
  final PlatformTier2Key keyProvider;
  final PortalReadCoordinator readCoordinator;

  @override
  String? get currentAdminUid => auth.currentUser?.uid;

  HttpsCallable _callable(String name) => functions.httpsCallable(
        name,
        options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
      );

  Never _rethrowMapped(Object error, String fallback) {
    if (error is PortalStudentException) {
      if (error.isSessionAuthLoss) {
        readCoordinator.reportExternalError(error);
      }
      throw error;
    }
    if (error is StateError &&
        (error.message == 'unauthenticated' ||
            error.message == 'scope_invalidated')) {
      const mapped = PortalStudentException(
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
    if (error is FirebaseAuthException) {
      final msg = switch (error.code) {
        'wrong-password' ||
        'invalid-credential' ||
        'invalid-login-credentials' =>
          'Admin password verification failed. Check your password and try again.',
        'too-many-requests' => 'Too many attempts. Please wait before retrying.',
        'network-request-failed' =>
          'Network connection failed. Check your internet connection and retry.',
        _ => 'Admin authentication failed. Sign in again.',
      };
      throw PortalStudentException(
        msg,
        kind: kind,
        firebaseCode: code,
        isSessionAuthLoss: sessionLoss,
      );
    }
    if (error is FirebaseFunctionsException &&
        error.message != null &&
        error.message!.trim().isNotEmpty) {
      throw PortalStudentException(
        error.message!.trim(),
        kind: kind,
        firebaseCode: code,
        isSessionAuthLoss: sessionLoss,
      );
    }
    throw PortalStudentException(
      fallback,
      kind: kind,
      firebaseCode: code,
      isSessionAuthLoss: sessionLoss,
    );
  }

  @override
  Future<void> setSecureScreen(bool enabled) async {
    try {
      await keyProvider.setSecureScreen(enabled);
    } catch (_) {}
  }

  @override
  Future<PortalDashboardStats> loadDashboardStats() async {
    try {
      return await readCoordinator.runRead<PortalDashboardStats>(
        key: 'getPortalDashboardStats',
        action: () async {
          final result = await _callable('getPortalDashboardStats')
              .call<dynamic>(<String, dynamic>{});
          final row = Map<String, dynamic>.from(result.data as Map);
          return PortalDashboardStats(
            schoolId: row['schoolId'] as String? ?? '',
            rosterAvailable: row['rosterAvailable'] == true,
            importedRosterCount:
                (row['importedRosterCount'] as num?)?.toInt() ?? 0,
            registeredStudentsCount:
                (row['registeredStudentsCount'] as num?)?.toInt() ?? 0,
            verifiedStudentsCount:
                (row['verifiedStudentsCount'] as num?)?.toInt() ?? 0,
            disabledStudentsCount:
                (row['disabledStudentsCount'] as num?)?.toInt() ?? 0,
            authorizedPersonnelCount:
                (row['authorizedPersonnelCount'] as num?)?.toInt() ?? 0,
          );
        },
      );
    } catch (error) {
      _rethrowMapped(error, 'Unable to load school dashboard statistics.');
    }
  }

  @override
  Future<SchoolStudentPage> listStudents({
    String search = '',
    String statusFilter = 'all',
    String? gradeFilter,
    int limit = 20,
    String? cursor,
  }) async {
    final normalizedSearch = search.trim();
    try {
      return await readCoordinator.runRead<SchoolStudentPage>(
        key:
            'listSchoolStudents:s=$normalizedSearch|st=$statusFilter|g=${gradeFilter ?? ''}|l=$limit|c=${cursor ?? ''}',
        cacheResult: cursor == null,
        action: () async {
          final result = await _callable('listSchoolStudents').call<dynamic>(
            <String, dynamic>{
              'search': normalizedSearch,
              'statusFilter': statusFilter,
              'gradeFilter': gradeFilter,
              'limit': limit,
              'cursor': cursor,
            },
          );
          final raw = Map<String, dynamic>.from(result.data as Map);
          final items = (raw['students'] as List?) ?? const [];
          final grades = (raw['availableGrades'] as List?) ?? const [];
          return SchoolStudentPage(
            students: items.map((item) {
              final row = Map<String, dynamic>.from(item as Map);
              final maskedLrn = row['maskedLrn'] as String?;
              return SchoolStudentSummary(
                uid: row['uid'] as String,
                fullName: row['fullName'] as String? ?? '',
                maskedLrn: maskedLrn,
                hasLrn: row['hasLrn'] == true || maskedLrn != null,
                gradeLevel: row['gradeLevel'] as String? ?? 'Unassigned Grade',
                accountCategory:
                    row['accountCategory'] as String? ?? 'registered',
                schoolApprovalStatus:
                    row['schoolApprovalStatus'] as String? ?? 'pending',
                verificationMethod: row['verificationMethod'] as String?,
              );
            }).toList(),
            nextCursor: raw['nextCursor'] as String?,
            totalMatched: (raw['totalMatched'] as num?)?.toInt() ?? 0,
            availableGrades: grades.map((g) => g.toString()).toList(),
          );
        },
      );
    } catch (error) {
      _rethrowMapped(error, 'Unable to load school student accounts.');
    }
  }

  @override
  Future<SchoolStudentDetails> getStudentDetails(String studentUid) async {
    try {
      return await readCoordinator.runRead<SchoolStudentDetails>(
        key: 'getSchoolStudentDetails:$studentUid',
        action: () async {
          final result = await _callable('getSchoolStudentDetails')
              .call<dynamic>(<String, dynamic>{'studentUid': studentUid});
          final row = Map<String, dynamic>.from(result.data as Map);
          final maskedLrn = row['maskedLrn'] as String?;
          return SchoolStudentDetails(
            uid: row['uid'] as String,
            fullName: row['fullName'] as String? ?? '',
            maskedLrn: maskedLrn,
            hasLrn: row['hasLrn'] == true || maskedLrn != null,
            gradeLevel: row['gradeLevel'] as String? ?? 'Unassigned Grade',
            sex: row['sex'] as String?,
            birthDate: row['birthDate'] as String?,
            ageYearsAtRegistration:
                (row['ageYearsAtRegistration'] as num?)?.toInt(),
            accountCategory: row['accountCategory'] as String? ?? 'registered',
            accountDisabled: row['accountDisabled'] == true,
            registrationStatus:
                row['registrationStatus'] as String? ?? 'pending_review',
            schoolApprovalStatus:
                row['schoolApprovalStatus'] as String? ?? 'pending',
            verificationMethod: row['verificationMethod'] as String?,
            verificationOutcome:
                row['verificationOutcome'] as String? ?? 'manual_review',
            medicalCompletionStatus:
                row['medicalCompletionStatus'] as String? ?? 'not_started',
            guardianAuthorizationStatus:
                row['guardianAuthorizationStatus'] as String? ?? 'pending',
            qrStatus: row['qrStatus'] as String? ?? 'not_issued',
            credentialVersion:
                (row['credentialVersion'] as num?)?.toInt() ?? 0,
            canVerifyManually: row['canVerifyManually'] == true,
          );
        },
      );
    } catch (error) {
      _rethrowMapped(error, 'Unable to load student account details.');
    }
  }

  @override
  Future<void> verifyStudentAccount({
    required String studentUid,
    required String requestId,
  }) =>
      operationLock.run(() async {
        try {
          await _callable('verifySchoolStudentAccount').call<dynamic>(
            <String, dynamic>{
              'studentUid': studentUid,
              'requestId': requestId,
            },
          );
          readCoordinator.notifyMutation();
        } catch (error) {
          _rethrowMapped(error, 'Unable to verify student account.');
        }
      });

  @override
  Future<void> setStudentAccountStatus({
    required String studentUid,
    required String action,
  }) =>
      operationLock.run(() async {
        try {
          await _callable('setStudentAccountStatus').call<dynamic>(
            <String, dynamic>{
              'studentUid': studentUid,
              'action': action,
            },
          );
          readCoordinator.notifyMutation();
        } catch (error) {
          _rethrowMapped(error, 'Unable to update student account status.');
        }
      });

  @override
  Future<SchoolRosterPage> listRoster({
    String search = '',
    String? gradeFilter,
    int limit = 20,
    String? cursor,
  }) =>
      listRosterFiltered(
        search: search,
        gradeFilter: gradeFilter,
        registrationFilter: 'all',
        limit: limit,
        cursor: cursor,
      );

  @override
  Future<SchoolRosterPage> listRosterFiltered({
    String search = '',
    String? gradeFilter,
    String registrationFilter = 'all',
    int limit = 20,
    String? cursor,
  }) async {
    final normalizedSearch = search.trim();
    try {
      return await readCoordinator.runRead<SchoolRosterPage>(
        key:
            'listSchoolRoster:s=$normalizedSearch|g=${gradeFilter ?? ''}|rf=$registrationFilter|l=$limit|c=${cursor ?? ''}',
        cacheResult: cursor == null,
        action: () async {
          final result = await _callable('listSchoolRoster').call<dynamic>(
            <String, dynamic>{
              'search': normalizedSearch,
              'gradeFilter': gradeFilter,
              'registrationFilter': registrationFilter,
              'limit': limit,
              'cursor': cursor,
            },
          );
          final raw = Map<String, dynamic>.from(result.data as Map);
          final items = (raw['entries'] as List?) ?? const [];
          final grades = (raw['availableGrades'] as List?) ?? const [];
          return SchoolRosterPage(
            rosterAvailable: raw['rosterAvailable'] == true,
            entries: items.map((item) {
              final row = Map<String, dynamic>.from(item as Map);
              final maskedLrn = row['maskedLrn'] as String?;
              return SchoolRosterEntry(
                rosterId: row['rosterId'] as String,
                displayName: row['displayName'] as String? ?? '',
                maskedLrn: maskedLrn,
                hasLrn: row['hasLrn'] == true || maskedLrn != null,
                gradeLevel: row['gradeLevel'] as String? ?? 'Unassigned Grade',
                sex: row['sex'] as String?,
                birthDate: row['birthDate'] as String?,
                registrationState:
                    row['registrationState'] as String? ?? 'not_registered',
                claimedStudentUid: row['claimedStudentUid'] as String?,
              );
            }).toList(),
            nextCursor: raw['nextCursor'] as String?,
            totalMatched: (raw['totalMatched'] as num?)?.toInt() ?? 0,
            availableGrades: grades.map((g) => g.toString()).toList(),
          );
        },
      );
    } catch (error) {
      _rethrowMapped(error, 'Unable to load official school roster.');
    }
  }

  @override
  Future<String> revealLrnWithPassword({
    required String targetType,
    required String targetId,
    required String password,
  }) =>
      operationLock.run(() async {
        try {
          final user = auth.currentUser;
          final email = user?.email;
          if (user == null || email == null || email.isEmpty) {
            throw const PortalStudentException('Sign in is required.');
          }
          if (password.isEmpty) {
            throw const PortalStudentException(
              'Enter your Master Admin password.',
            );
          }
          final challengeRes =
              await _callable('issueAdminLrnRevealChallenge').call<dynamic>(
            <String, dynamic>{
              'targetType': targetType,
              'targetId': targetId,
              'authMethod': 'password',
            },
          );
          final ch = Map<String, dynamic>.from(challengeRes.data as Map);
          final challengeId = ch['challengeId'];
          if (challengeId is! String || challengeId.isEmpty) {
            throw const PortalStudentException(
              'Unable to start password LRN verification.',
            );
          }
          await user.reauthenticateWithCredential(
            EmailAuthProvider.credential(email: email, password: password),
          );
          await user.getIdToken(true);
          final result = await _callable('revealStudentLrn').call<dynamic>(
            <String, dynamic>{
              'targetType': targetType,
              'targetId': targetId,
              'authMethod': 'password',
              'challengeId': challengeId,
            },
          );
          final row = Map<String, dynamic>.from(result.data as Map);
          final lrn = row['lrn'];
          if (lrn is! String || lrn.length != 12) {
            throw const PortalStudentException('Unable to reveal full LRN.');
          }
          return lrn;
        } catch (error) {
          _rethrowMapped(error, 'Unable to reveal full LRN.');
        }
      });

  @override
  Future<String> revealLrnWithBiometric({
    required String targetType,
    required String targetId,
  }) =>
      operationLock.run(() async {
        try {
          final uid = auth.currentUser?.uid;
          if (uid == null) {
            throw const PortalStudentException('Sign in is required.');
          }
          final prefs = await SharedPreferences.getInstance();
          final deviceId = prefs.getString('resqme_staff_tier2_device_$uid');
          if (deviceId == null || deviceId.length < 20) {
            throw const PortalStudentException(
              'Enroll this device in Biometric Device Setup first, or confirm with your Admin password.',
            );
          }

          final challengeRes =
              await _callable('issueAdminLrnRevealChallenge').call<dynamic>(
            <String, dynamic>{
              'targetType': targetType,
              'targetId': targetId,
              'deviceId': deviceId,
            },
          );
          final ch = Map<String, dynamic>.from(challengeRes.data as Map);
          final challengeId = ch['challengeId'];
          final nonce = ch['nonce'];
          if (challengeId is! String || nonce is! String) {
            throw const PortalStudentException(
              'Unable to start biometric LRN verification.',
            );
          }

          final message =
              'resqme:admin-lrn-reveal:v1\n$uid\n$deviceId\n$targetType\n$targetId\n$challengeId\n$nonce';
          final String signature;
          try {
            signature = await keyProvider.signStaff(deviceId, message);
          } catch (bioError) {
            throw PortalStudentException(mapStaffTier2Error(bioError).message);
          }

          final revealRes = await _callable('revealStudentLrn').call<dynamic>(
            <String, dynamic>{
              'targetType': targetType,
              'targetId': targetId,
              'authMethod': 'biometric',
              'challengeId': challengeId,
              'deviceId': deviceId,
              'signature': signature,
            },
          );
          final row = Map<String, dynamic>.from(revealRes.data as Map);
          final lrn = row['lrn'];
          if (lrn is! String || lrn.length != 12) {
            throw const PortalStudentException('Unable to reveal full LRN.');
          }
          return lrn;
        } catch (error) {
          _rethrowMapped(error, 'Unable to verify biometrics for LRN reveal.');
        }
      });

  QrReplacementResult _parseReplacementResult(
    Map<String, dynamic> row,
    String fallbackUid,
    String fallbackReason,
  ) {
    final version = (row['credentialVersion'] as num?)?.toInt();
    if (version == null || version < 1) {
      throw const PortalStudentException('Unable to replace student QR.');
    }
    return QrReplacementResult(
      studentUid: row['studentUid'] as String? ?? fallbackUid,
      verificationStatus: row['verificationStatus'] as String? ?? 'active',
      credentialVersion: version,
      reason: row['reason'] as String? ?? fallbackReason,
      issuedAt: row['issuedAt'] as String?,
    );
  }

  @override
  Future<QrReplacementResult> replaceStudentQrWithPassword({
    required String studentUid,
    required String reason,
    required String requestId,
    required String password,
  }) =>
      operationLock.run(() async {
        try {
          final user = auth.currentUser;
          final email = user?.email;
          if (user == null || email == null || email.isEmpty) {
            throw const PortalStudentException('Sign in is required.');
          }
          if (password.isEmpty) {
            throw const PortalStudentException(
              'Enter your Master Admin password.',
            );
          }
          final challengeRes =
              await _callable('issueAdminQrReplaceChallenge').call<dynamic>(
            <String, dynamic>{
              'studentUid': studentUid,
              'reason': reason,
              'deviceId': null,
            },
          );
          final ch = Map<String, dynamic>.from(challengeRes.data as Map);
          final challengeId = ch['challengeId'];
          if (challengeId is! String || challengeId.isEmpty) {
            throw const PortalStudentException(
              'Unable to start QR replacement verification.',
            );
          }
          await user.reauthenticateWithCredential(
            EmailAuthProvider.credential(email: email, password: password),
          );
          await user.getIdToken(true);
          final result =
              await _callable('replaceSchoolStudentQr').call<dynamic>(
            <String, dynamic>{
              'studentUid': studentUid,
              'reason': reason,
              'requestId': requestId,
              'challengeId': challengeId,
              'method': 'password',
              'deviceId': null,
              'signature': null,
            },
          );
          final parsed = _parseReplacementResult(
            Map<String, dynamic>.from(result.data as Map),
            studentUid,
            reason,
          );
          readCoordinator.notifyMutation();
          return parsed;
        } catch (error) {
          _rethrowMapped(error, 'Unable to replace student QR.');
        }
      });

  @override
  Future<QrReplacementResult> replaceStudentQrWithBiometric({
    required String studentUid,
    required String reason,
    required String requestId,
  }) =>
      operationLock.run(() async {
        try {
          final uid = auth.currentUser?.uid;
          if (uid == null) {
            throw const PortalStudentException(
              'Sign in is required.',
              kind: PortalErrorKind.authorization,
              firebaseCode: 'unauthenticated',
              isSessionAuthLoss: true,
            );
          }
          final prefs = await SharedPreferences.getInstance();
          final deviceId = prefs.getString('resqme_staff_tier2_device_$uid');
          if (deviceId == null || deviceId.length < 20) {
            throw const PortalStudentException(
              'Enroll this device in Biometric Device Setup first, or confirm with your Admin password.',
              kind: PortalErrorKind.operation,
            );
          }
          final challengeRes =
              await _callable('issueAdminQrReplaceChallenge').call<dynamic>(
            <String, dynamic>{
              'studentUid': studentUid,
              'reason': reason,
              'deviceId': deviceId,
            },
          );
          final ch = Map<String, dynamic>.from(challengeRes.data as Map);
          final challengeId = ch['challengeId'];
          final nonce = ch['nonce'];
          if (challengeId is! String || nonce is! String) {
            throw const PortalStudentException(
              'Unable to start biometric QR replacement.',
            );
          }
          final message =
              'resqme:staff-qr-replace:v1\n$uid\n$deviceId\nadmin_replace_student_qr\n$studentUid\n$reason\n$challengeId\n$nonce';
          final String signature;
          try {
            signature = await keyProvider.signStaff(deviceId, message);
          } catch (bioError) {
            throw PortalStudentException(
              mapStaffTier2Error(bioError).message,
              kind: PortalErrorKind.operation,
            );
          }
          final result =
              await _callable('replaceSchoolStudentQr').call<dynamic>(
            <String, dynamic>{
              'studentUid': studentUid,
              'reason': reason,
              'requestId': requestId,
              'challengeId': challengeId,
              'method': 'biometric',
              'deviceId': deviceId,
              'signature': signature,
            },
          );
          final parsed = _parseReplacementResult(
            Map<String, dynamic>.from(result.data as Map),
            studentUid,
            reason,
          );
          readCoordinator.notifyMutation();
          return parsed;
        } catch (error) {
          _rethrowMapped(
            error,
            'Unable to verify biometrics for QR replacement.',
          );
        }
      });

  @override
  Future<ActivityLogPage> listActivityLogs({
    String category = 'all',
    String outcome = 'all',
    String? actorUid,
    String search = '',
    String? startDate,
    String? endDate,
    int limit = 25,
    String? cursor,
  }) async {
    final normalizedSearch = search.trim();
    try {
      return await readCoordinator.runRead<ActivityLogPage>(
        key:
            'listSchoolActivityLogs:cat=$category|out=$outcome|act=${actorUid ?? ''}|s=$normalizedSearch|sd=${startDate ?? ''}|ed=${endDate ?? ''}|l=$limit|c=${cursor ?? ''}',
        cacheResult: cursor == null,
        action: () async {
          final result =
              await _callable('listSchoolActivityLogs').call<dynamic>(
            <String, dynamic>{
              'category': category,
              'outcome': outcome,
              'actorUid': actorUid,
              'search': normalizedSearch,
              'startDate': startDate,
              'endDate': endDate,
              'limit': limit,
              'cursor': cursor,
            },
          );
          final raw = Map<String, dynamic>.from(result.data as Map);
          final items = (raw['entries'] as List?) ?? const [];
          return ActivityLogPage(
            entries: items.map((item) {
              final row = Map<String, dynamic>.from(item as Map);
              return ActivityLogEntry(
                id: row['id'] as String? ?? '',
                sourceCollection: row['sourceCollection'] as String? ?? '',
                category: row['category'] as String? ?? 'management',
                action: row['action'] as String? ?? '',
                actionLabel: row['actionLabel'] as String? ?? 'Activity',
                outcome: row['outcome'] as String? ?? 'allowed',
                actorUid: row['actorUid'] as String? ?? 'unknown',
                actorRole: row['actorRole'] as String? ?? 'admin',
                targetUid: row['targetUid'] as String?,
                summary: row['summary'] as String? ?? '',
                reasonCode: row['reasonCode'] as String?,
                method: row['method'] as String?,
                timestamp: row['timestamp'] as String? ?? '',
              );
            }).toList(),
            nextCursor: raw['nextCursor'] as String?,
            totalMatched: (raw['totalMatched'] as num?)?.toInt() ?? 0,
          );
        },
      );
    } catch (error) {
      _rethrowMapped(error, 'Unable to load school activity logs.');
    }
  }

  @override
  Future<Sf1PickedFile?> pickSf1ExcelFile() async {
    try {
      const channel = MethodChannel('resqme/tier2_key');
      final raw = await channel.invokeMethod<dynamic>('pickExcelFile');
      if (raw == null) return null;
      final map = Map<String, dynamic>.from(raw as Map);
      final name = map['fileName'] as String?;
      final b64 = map['fileBase64'] as String?;
      if (name == null || b64 == null) return null;
      return Sf1PickedFile(fileName: name, fileBase64: b64);
    } on PlatformException catch (error) {
      throw PortalStudentException(
        error.message ?? 'Unable to open spreadsheet file.',
        kind: PortalErrorKind.operation,
      );
    }
  }

  @override
  Future<RosterImportPreview> previewRosterImport({
    required String fileName,
    required String fileBase64,
    String? confirmedGradeLevel,
  }) async {
    try {
      if (auth.currentUser?.uid == null) {
        throw const PortalStudentException(
          'Sign in is required.',
          kind: PortalErrorKind.authorization,
          firebaseCode: 'unauthenticated',
          isSessionAuthLoss: true,
        );
      }
      final result =
          await _callable('previewSchoolRosterImport').call<dynamic>(
        <String, dynamic>{
          'fileName': fileName,
          'fileBase64': fileBase64,
          'confirmedGradeLevel': confirmedGradeLevel,
        },
      );
      final raw = Map<String, dynamic>.from(result.data as Map);
      final summary =
          Map<String, dynamic>.from(raw['summary'] as Map? ?? const {});
      final rows = (raw['rows'] as List?) ?? const [];
      return RosterImportPreview(
        previewId: raw['previewId'] as String? ?? '',
        fileName: raw['fileName'] as String? ?? fileName,
        detectedGradeLevel: raw['detectedGradeLevel'] as String?,
        confirmedGradeLevel: raw['confirmedGradeLevel'] as String? ?? '',
        totalRows: (summary['totalRows'] as num?)?.toInt() ?? 0,
        newCount: (summary['newCount'] as num?)?.toInt() ?? 0,
        unchangedCount: (summary['unchangedCount'] as num?)?.toInt() ?? 0,
        proposedUpdateCount:
            (summary['proposedUpdateCount'] as num?)?.toInt() ?? 0,
        duplicateCount: (summary['duplicateCount'] as num?)?.toInt() ?? 0,
        conflictCount: (summary['conflictCount'] as num?)?.toInt() ?? 0,
        invalidCount: (summary['invalidCount'] as num?)?.toInt() ?? 0,
        rows: rows.map((item) {
          final r = Map<String, dynamic>.from(item as Map);
          return RosterImportPreviewRow(
            rowNumber: (r['rowNumber'] as num?)?.toInt() ?? 0,
            status: r['status'] as String? ?? 'invalid',
            maskedLrn: r['maskedLrn'] as String?,
            fullName: r['fullName'] as String? ?? '',
            gradeLevel: r['gradeLevel'] as String? ?? '',
            sex: r['sex'] as String?,
            birthDate: r['birthDate'] as String?,
            reason: r['reason'] as String?,
          );
        }).toList(),
      );
    } catch (error) {
      _rethrowMapped(error, 'Unable to preview SF1 roster import.');
    }
  }

  @override
  Future<RosterImportCommitResult> commitRosterImport({
    required String previewId,
    required String requestId,
  }) =>
      operationLock.run(() async {
        try {
          final result =
              await _callable('commitSchoolRosterImport').call<dynamic>(
            <String, dynamic>{
              'previewId': previewId,
              'requestId': requestId,
            },
          );
          readCoordinator.notifyMutation();
          final raw = Map<String, dynamic>.from(result.data as Map);
          final creds = (raw['generatedCredentials'] as List?) ?? const [];
          return RosterImportCommitResult(
            importId: raw['importId'] as String? ?? requestId,
            status: raw['status'] as String? ?? 'completed',
            committedCount: (raw['committedCount'] as num?)?.toInt() ?? 0,
            newCount: (raw['newCount'] as num?)?.toInt() ?? 0,
            updatedCount: (raw['updatedCount'] as num?)?.toInt() ?? 0,
            generatedCredentials: creds.map((item) {
              final c = Map<String, dynamic>.from(item as Map);
              return RosterGeneratedCredential(
                maskedLrn: c['maskedLrn'] as String? ?? '',
                fullName: c['fullName'] as String? ?? '',
                gradeLevel: c['gradeLevel'] as String? ?? '',
                enrollmentCode: c['enrollmentCode'] as String? ?? '',
              );
            }).toList(),
          );
        } catch (error) {
          _rethrowMapped(error, 'Unable to commit SF1 roster import.');
        }
      });

  @override
  Future<List<RosterImportHistoryItem>> listRosterImports() async {
    try {
      return await readCoordinator.runRead<List<RosterImportHistoryItem>>(
        key: 'listSchoolRosterImports',
        action: () async {
          final result =
              await _callable('listSchoolRosterImports').call<dynamic>({});
          final raw = Map<String, dynamic>.from(result.data as Map);
          final items = (raw['imports'] as List?) ?? const [];
          return items.map((item) {
            final row = Map<String, dynamic>.from(item as Map);
            return RosterImportHistoryItem(
              importId: row['importId'] as String? ?? '',
              fileName: row['fileName'] as String? ?? 'SF1 Import',
              confirmedGradeLevel:
                  row['confirmedGradeLevel'] as String? ?? '',
              status: row['status'] as String? ?? 'completed',
              committedCount: (row['committedCount'] as num?)?.toInt() ?? 0,
              newCount: (row['newCount'] as num?)?.toInt() ?? 0,
              updatedCount: (row['updatedCount'] as num?)?.toInt() ?? 0,
              timestamp: row['timestamp'] as String? ?? '',
            );
          }).toList();
        },
      );
    } catch (error) {
      _rethrowMapped(error, 'Unable to load roster import history.');
    }
  }
}
