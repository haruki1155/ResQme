import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/data/account_operation_lock.dart';
import '../../medical/services/platform_tier2_key.dart';
import 'staff_tier2_repository.dart';

class PortalStudentException implements Exception {
  const PortalStudentException(this.message);
  final String message;

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
  Future<void> setSecureScreen(bool enabled);
}

class FirebasePortalStudentRepository implements PortalStudentRepository {
  FirebasePortalStudentRepository({
    required this.auth,
    required this.functions,
    required this.operationLock,
    required String expectedProjectId,
    PlatformTier2Key? keyProvider,
  }) : keyProvider = keyProvider ?? PlatformTier2Key() {
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

  @override
  String? get currentAdminUid => auth.currentUser?.uid;

  HttpsCallable _callable(String name) => functions.httpsCallable(
        name,
        options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
      );

  Never _rethrowMapped(Object error, String fallback) {
    if (error is PortalStudentException) throw error;
    if (error is FirebaseAuthException) {
      final msg = switch (error.code) {
        'wrong-password' ||
        'invalid-credential' ||
        'invalid-login-credentials' =>
          'Admin password verification failed. Check your password and try again.',
        'too-many-requests' => 'Too many attempts. Please wait before retrying.',
        _ => 'Admin authentication failed. Sign in again.',
      };
      throw PortalStudentException(msg);
    }
    if (error is FirebaseFunctionsException &&
        error.message != null &&
        error.message!.trim().isNotEmpty) {
      throw PortalStudentException(error.message!.trim());
    }
    throw PortalStudentException(fallback);
  }

  @override
  Future<void> setSecureScreen(bool enabled) async {
    try {
      await keyProvider.setSecureScreen(enabled);
    } catch (_) {}
  }

  @override
  Future<PortalDashboardStats> loadDashboardStats() =>
      operationLock.run(() async {
        try {
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
        } catch (error) {
          _rethrowMapped(error, 'Unable to load school dashboard statistics.');
        }
      });

  @override
  Future<SchoolStudentPage> listStudents({
    String search = '',
    String statusFilter = 'all',
    String? gradeFilter,
    int limit = 20,
    String? cursor,
  }) =>
      operationLock.run(() async {
        try {
          final result = await _callable('listSchoolStudents').call<dynamic>(
            <String, dynamic>{
              'search': search.trim(),
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
        } catch (error) {
          _rethrowMapped(error, 'Unable to load school student accounts.');
        }
      });

  @override
  Future<SchoolStudentDetails> getStudentDetails(String studentUid) =>
      operationLock.run(() async {
        try {
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
        } catch (error) {
          _rethrowMapped(error, 'Unable to load student account details.');
        }
      });

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
      operationLock.run(() async {
        try {
          final result = await _callable('listSchoolRoster').call<dynamic>(
            <String, dynamic>{
              'search': search.trim(),
              'gradeFilter': gradeFilter,
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
        } catch (error) {
          _rethrowMapped(error, 'Unable to load official school roster.');
        }
      });

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
          return _parseReplacementResult(
            Map<String, dynamic>.from(result.data as Map),
            studentUid,
            reason,
          );
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
            throw PortalStudentException(mapStaffTier2Error(bioError).message);
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
          return _parseReplacementResult(
            Map<String, dynamic>.from(result.data as Map),
            studentUid,
            reason,
          );
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
  }) =>
      operationLock.run(() async {
        try {
          final result =
              await _callable('listSchoolActivityLogs').call<dynamic>(
            <String, dynamic>{
              'category': category,
              'outcome': outcome,
              'actorUid': actorUid,
              'search': search.trim(),
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
        } catch (error) {
          _rethrowMapped(error, 'Unable to load school activity logs.');
        }
      });
}
