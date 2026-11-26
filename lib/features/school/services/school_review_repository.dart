import 'dart:math';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/data/account_operation_lock.dart';

class SchoolReviewCandidate {
  const SchoolReviewCandidate({
    required this.studentUid,
    required this.fullName,
    required this.schoolApprovalStatus,
    required this.schoolVerificationOutcome,
  });
  final String studentUid,
      fullName,
      schoolApprovalStatus,
      schoolVerificationOutcome;
}

class SchoolReviewStatus {
  const SchoolReviewStatus({
    required this.schoolStatus,
    required this.qrActive,
  });
  final String schoolStatus;
  final bool qrActive;
}

abstract interface class SchoolReviewRepository {
  String? get currentUid;
  Stream<void> get sessionChanges;
  Future<void> signIn(String email, String password);
  Future<SchoolReviewCandidate> loadCandidate(String studentUid);
  Future<SchoolReviewCandidate> loadCandidateByQr(String payload);
  Future<void> approve(String studentUid, String requestId);
  Future<void> signOut();
  Future<SchoolReviewStatus> refreshStatus(String studentUid);
}

class FirebaseSchoolReviewRepository implements SchoolReviewRepository {
  FirebaseSchoolReviewRepository({
    required this.auth,
    required this.functions,
    required this.operationLock,
    required String expectedProjectId,
  }) {
    if (!['demo-resqme', 'resqme-943ee'].contains(expectedProjectId) ||
        auth.app.options.projectId != expectedProjectId ||
        functions.app.options.projectId != expectedProjectId ||
        auth.app.name != functions.app.name) {
      throw StateError('Unexpected school review Firebase app.');
    }
  }
  final FirebaseAuth auth;
  final FirebaseFunctions functions;
  final AccountOperationLock operationLock;
  @override
  Stream<void> get sessionChanges => auth.authStateChanges().map<void>((_) {});

  @override
  Future<SchoolReviewCandidate> loadCandidateByQr(String payload) =>
      operationLock.run(() async {
        final owner = currentUid;
        if (owner == null) throw StateError('Sign in required.');
        final result = await functions
            .httpsCallable('getSchoolReviewCandidateByQr')
            .call<dynamic>({'payload': payload});
        if (currentUid != owner || result.data is! Map) {
          throw StateError('Review unavailable.');
        }
        final data = Map<String, dynamic>.from(result.data as Map);
        if (data.keys.toSet().difference({
              'studentUid',
              'fullName',
              'schoolApprovalStatus',
              'schoolVerificationOutcome',
              'qrStatus',
              'verificationStatus',
            }).isNotEmpty ||
            data['studentUid'] is! String ||
            data['fullName'] is! String ||
            data['schoolApprovalStatus'] != 'pending' ||
            data['qrStatus'] != 'INACTIVE' ||
            data['verificationStatus'] != 'PENDING' ||
            ![
              'verified',
              'manual_review',
              'conflict',
            ].contains(data['schoolVerificationOutcome'])) {
          throw StateError('Review unavailable.');
        }
        return SchoolReviewCandidate(
          studentUid: data['studentUid'] as String,
          fullName: data['fullName'] as String,
          schoolApprovalStatus: 'pending',
          schoolVerificationOutcome:
              data['schoolVerificationOutcome'] as String,
        );
      });
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
  Future<SchoolReviewCandidate> loadCandidate(
    String studentUid,
  ) => operationLock.run(() async {
    final owner = currentUid;
    if (owner == null) throw StateError('Sign in required.');
    final result = await functions
        .httpsCallable(
          'getSchoolReviewCandidate',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 10)),
        )
        .call<dynamic>({'studentUid': studentUid.trim()});
    if (currentUid != owner || result.data is! Map) {
      throw StateError('Review unavailable.');
    }
    final data = Map<String, dynamic>.from(result.data as Map);
    if (data.keys.toSet().difference({
          'studentUid',
          'fullName',
          'schoolApprovalStatus',
          'schoolVerificationOutcome',
        }).isNotEmpty ||
        data['studentUid'] is! String ||
        data['fullName'] is! String ||
        data['schoolApprovalStatus'] != 'pending' ||
        ![
          'verified',
          'manual_review',
          'conflict',
        ].contains(data['schoolVerificationOutcome'])) {
      throw StateError('Review unavailable.');
    }
    return SchoolReviewCandidate(
      studentUid: data['studentUid'] as String,
      fullName: data['fullName'] as String,
      schoolApprovalStatus: 'pending',
      schoolVerificationOutcome: data['schoolVerificationOutcome'] as String,
    );
  });
  @override
  Future<void> approve(String studentUid, String requestId) =>
      operationLock.run(() async {
        final owner = currentUid;
        if (owner == null) throw StateError('Sign in required.');
        await functions
            .httpsCallable(
              'approveStudentQr',
              options: HttpsCallableOptions(
                timeout: const Duration(seconds: 10),
              ),
            )
            .call<dynamic>({'studentUid': studentUid, 'requestId': requestId});
        if (currentUid != owner) throw StateError('Account changed.');
      });
  @override
  Future<void> signOut() => operationLock.run(auth.signOut);
  @override
  Future<SchoolReviewStatus> refreshStatus(String studentUid) =>
      operationLock.run(() async {
        final owner = currentUid;
        if (owner == null) throw StateError('Sign in required.');
        final response = await functions
            .httpsCallable('getSchoolReviewStatus')
            .call<dynamic>({'studentUid': studentUid});
        if (currentUid != owner || response.data is! Map) {
          throw StateError('Status unavailable.');
        }
        final data = Map<String, dynamic>.from(response.data as Map);
        if (data.length != 2 ||
            ![
              'pending',
              'approved',
              'rejected',
              'revoked',
            ].contains(data['schoolStatus']) ||
            data['qrActive'] is! bool) {
          throw StateError('Status unavailable.');
        }
        return SchoolReviewStatus(
          schoolStatus: data['schoolStatus'] as String,
          qrActive: data['qrActive'] as bool,
        );
      });
  static String createRequestId() {
    final random = Random.secure();
    final bytes = List<int>.generate(24, (_) => random.nextInt(256));
    const alphabet =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-';
    return bytes.map((byte) => alphabet[byte % alphabet.length]).join();
  }
}
