import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqme/core/data/account_operation_lock.dart';
import 'package:resqme/features/admin/admin_app.dart';
import 'package:resqme/features/admin/screens/active_students_screen.dart';
import 'package:resqme/features/admin/screens/activity_logs_screen.dart';
import 'package:resqme/features/admin/screens/authorized_personnel_screen.dart';
import 'package:resqme/features/admin/screens/portal_dashboard_screen.dart';
import 'package:resqme/features/admin/screens/student_details_screen.dart';
import 'package:resqme/features/admin/screens/student_roster_screen.dart';
import 'package:resqme/features/admin/services/portal_read_coordinator.dart';
import 'package:resqme/features/admin/services/portal_student_repository.dart';
import 'package:resqme/features/admin/services/staff_access_repository.dart';
import 'package:resqme/features/admin/services/staff_management_repository.dart';

const _masterAdmin = StaffAccess(
  uid: 'master-1',
  role: 'admin',
  schoolId: 'school-alpha',
  active: true,
  isMasterAdmin: true,
  mustChangePassword: false,
  requiresEmailVerification: true,
  emailVerified: true,
  fullName: 'Principal Cruz',
);

class _ControllableAccessRepo implements StaffAccessRepository {
  _ControllableAccessRepo({this.uid = 'master-1', this.access = _masterAdmin});

  String? uid;
  StaffAccess? access;
  Object? nextLoadError;
  int signOutCount = 0;
  int loadAccessCount = 0;

  @override
  String? get currentUid => uid;

  @override
  String? get currentEmail => 'principal@school.edu.ph';

  @override
  Future<void> signIn(String identifier, String password) async {
    uid = access?.uid ?? 'master-1';
  }

  @override
  Future<StaffAccess> loadAccess() async {
    loadAccessCount += 1;
    final err = nextLoadError;
    if (err != null) {
      nextLoadError = null;
      throw err;
    }
    if (uid == null || access == null) {
      throw const StaffAccessDenied('Staff access is unavailable.');
    }
    return access!;
  }

  @override
  Future<void> signOut() async {
    signOutCount += 1;
    uid = null;
  }

  @override
  Future<void> reauthenticate(String currentPassword) async {}

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {}

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<StaffAccess> reloadAndSyncEmail() async => loadAccess();

  @override
  Future<void> requestEmailUpdate({
    required String currentPassword,
    required String newEmail,
  }) async {}

  @override
  Future<void> sendPasswordResetEmail(String email) async {}
}

class _ControllableManagementRepo implements StaffManagementRepository {
  List<AuthorizedAccountSummary> accounts = const [
    AuthorizedAccountSummary(
      uid: 'auth-1',
      loginId: 'AUTH-1111AAAA',
      fullName: 'Nurse Clara',
      position: 'School Nurse',
      status: 'active',
      active: true,
      mustChangePassword: false,
      hasActiveDevice: true,
    ),
  ];
  Completer<List<AuthorizedAccountSummary>>? pendingLoad;
  Object? nextError;

  @override
  Future<List<AuthorizedAccountSummary>> listAccounts({
    String search = '',
  }) async {
    if (pendingLoad != null) {
      final c = pendingLoad!;
      pendingLoad = null;
      return c.future;
    }
    if (nextError != null) {
      final err = nextError!;
      nextError = null;
      throw err;
    }
    return accounts;
  }

  @override
  Future<IssuedAuthorizedCredentials> createAccount({
    required String fullName,
    required String position,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> updateAccount({
    required String targetUid,
    required String fullName,
    required String position,
  }) async {}

  @override
  Future<void> setAccountStatus({
    required String targetUid,
    required String action,
  }) async {}

  @override
  Future<IssuedAuthorizedCredentials> resetPassword({
    required String targetUid,
    required String fullName,
    required String position,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> revokeDevice({required String targetUid}) async {}
}

class _ControllableStudentRepo implements PortalStudentRepository {
  @override
  String? currentAdminUid = 'master-1';

  PortalDashboardStats stats = const PortalDashboardStats(
    schoolId: 'school-alpha',
    rosterAvailable: true,
    importedRosterCount: 42,
    registeredStudentsCount: 15,
    verifiedStudentsCount: 12,
    disabledStudentsCount: 1,
    authorizedPersonnelCount: 3,
  );

  List<SchoolStudentSummary> students = const [
    SchoolStudentSummary(
      uid: 'stu-1',
      fullName: 'Ana Santos',
      maskedLrn: '0098••••3210',
      hasLrn: true,
      gradeLevel: 'Grade 10',
      accountCategory: 'verified',
      schoolApprovalStatus: 'approved',
      verificationMethod: 'roster',
    ),
  ];

  List<SchoolRosterEntry> rosterEntries = const [
    SchoolRosterEntry(
      rosterId: 'r-1',
      displayName: 'Santos, Ana',
      maskedLrn: '0098••••3210',
      hasLrn: true,
      gradeLevel: 'Grade 10',
      sex: 'Female',
      birthDate: '2010-04-12',
      registrationState: 'verified',
      claimedStudentUid: 'stu-1',
    ),
  ];

  SchoolStudentDetails details = const SchoolStudentDetails(
    uid: 'stu-1',
    fullName: 'Ana Santos',
    maskedLrn: '0098••••3210',
    hasLrn: true,
    gradeLevel: 'Grade 10',
    sex: 'Female',
    birthDate: '2010-04-12',
    ageYearsAtRegistration: 16,
    accountCategory: 'verified',
    accountDisabled: false,
    registrationStatus: 'pending_guardian',
    schoolApprovalStatus: 'approved',
    verificationMethod: 'roster',
    verificationOutcome: 'verified',
    medicalCompletionStatus: 'complete',
    guardianAuthorizationStatus: 'verified',
    qrStatus: 'active',
    credentialVersion: 1,
    canVerifyManually: false,
  );

  List<ActivityLogEntry> logs = const [
    ActivityLogEntry(
      id: 'log-1',
      sourceCollection: 'staffManagementAudits',
      category: 'security',
      action: 'verify_student_account',
      actionLabel: 'Student Manually Verified',
      outcome: 'allowed',
      actorUid: 'master-1',
      actorRole: 'admin',
      targetUid: 'stu-1',
      summary: 'Student Manually Verified',
      reasonCode: null,
      method: 'manual_admin',
      timestamp: '2026-11-25T10:00:00.000Z',
    ),
  ];

  Object? nextStatsError;
  Object? nextStudentsError;
  Object? nextRosterError;
  Object? nextDetailsError;
  Object? nextLogsError;
  Completer<SchoolStudentPage>? pendingStudentsCompleter;
  final Map<String, Completer<SchoolStudentPage>> completersByStatus = {};

  @override
  Future<PortalDashboardStats> loadDashboardStats() async {
    if (nextStatsError != null) {
      final err = nextStatsError!;
      nextStatsError = null;
      throw err;
    }
    return stats;
  }

  @override
  Future<SchoolStudentPage> listStudents({
    String search = '',
    String statusFilter = 'all',
    String? gradeFilter,
    int limit = 20,
    String? cursor,
  }) async {
    if (completersByStatus.containsKey(statusFilter)) {
      final c = completersByStatus.remove(statusFilter)!;
      return c.future;
    }
    if (pendingStudentsCompleter != null) {
      final c = pendingStudentsCompleter!;
      pendingStudentsCompleter = null;
      return c.future;
    }
    if (nextStudentsError != null) {
      final err = nextStudentsError!;
      nextStudentsError = null;
      throw err;
    }
    return SchoolStudentPage(
      students: students,
      nextCursor: null,
      totalMatched: students.length,
      availableGrades: const ['Grade 10'],
    );
  }

  @override
  Future<SchoolStudentDetails> getStudentDetails(String studentUid) async {
    if (nextDetailsError != null) {
      final err = nextDetailsError!;
      nextDetailsError = null;
      throw err;
    }
    return details;
  }

  @override
  Future<SchoolRosterPage> listRoster({
    String search = '',
    String? gradeFilter,
    int limit = 20,
    String? cursor,
  }) async {
    if (nextRosterError != null) {
      final err = nextRosterError!;
      nextRosterError = null;
      throw err;
    }
    return SchoolRosterPage(
      rosterAvailable: rosterEntries.isNotEmpty,
      entries: rosterEntries,
      nextCursor: null,
      totalMatched: rosterEntries.length,
      availableGrades: const ['Grade 10'],
    );
  }

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
    if (nextLogsError != null) {
      final err = nextLogsError!;
      nextLogsError = null;
      throw err;
    }
    return ActivityLogPage(
      entries: logs,
      nextCursor: null,
      totalMatched: logs.length,
    );
  }

  @override
  Future<void> verifyStudentAccount({
    required String studentUid,
    required String requestId,
  }) async {}

  @override
  Future<void> setStudentAccountStatus({
    required String studentUid,
    required String action,
  }) async {}

  @override
  Future<String> revealLrnWithPassword({
    required String targetType,
    required String targetId,
    required String password,
  }) async =>
      '009876543210';

  @override
  Future<String> revealLrnWithBiometric({
    required String targetType,
    required String targetId,
  }) async =>
      '009876543210';

  @override
  Future<QrReplacementResult> replaceStudentQrWithPassword({
    required String studentUid,
    required String reason,
    required String requestId,
    required String password,
  }) async =>
      QrReplacementResult(
        studentUid: studentUid,
        verificationStatus: 'active',
        credentialVersion: 2,
        reason: reason,
      );

  @override
  Future<QrReplacementResult> replaceStudentQrWithBiometric({
    required String studentUid,
    required String reason,
    required String requestId,
  }) async =>
      QrReplacementResult(
        studentUid: studentUid,
        verificationStatus: 'active',
        credentialVersion: 2,
        reason: reason,
      );

  @override
  Future<Sf1PickedFile?> pickSf1ExcelFile() async => null;

  @override
  Future<RosterImportPreview> previewRosterImport({
    required String fileName,
    required String fileBase64,
    String? confirmedGradeLevel,
  }) =>
      throw UnimplementedError();

  @override
  Future<RosterImportCommitResult> commitRosterImport({
    required String previewId,
    required String requestId,
  }) =>
      throw UnimplementedError();

  @override
  Future<List<RosterImportHistoryItem>> listRosterImports() async => const [];

  @override
  Future<void> setSecureScreen(bool enabled) async {}
}

void main() {
  testWidgets(
      'RC-2: cold-start transient failure during loadAccess does NOT destroy valid session with signOut',
      (tester) async {
    final accessRepo = _ControllableAccessRepo()
      ..nextLoadError = FirebaseFunctionsException(
        code: 'unavailable',
        message: 'Service temporarily unavailable during cold start.',
      );

    await tester.pumpWidget(
      AdminApp(
        accessRepository: accessRepo,
        portalStudentRepository: _ControllableStudentRepo(),
      ),
    );
    await tester.pumpAndSettle();

    // Must NOT wipe session on transient unavailable error, and must allow retry!
    expect(accessRepo.signOutCount, 0);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets(
      'RC-3: ActiveStudentsScreen, StudentRosterScreen, AuthorizedPersonnelScreen, Dashboard, Details, and ActivityLogs retain valid data during refresh and transient errors',
      (tester) async {
    final accessRepo = _ControllableAccessRepo();
    final studentRepo = _ControllableStudentRepo();
    final mgmtRepo = _ControllableManagementRepo();

    // 1. ActiveStudentsScreen retains Ana Santos when refresh fails transiently
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ActiveStudentsScreen(
            accessRepository: accessRepo,
            portalStudentRepository: studentRepo,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ana Santos'), findsOneWidget);

    studentRepo.nextStudentsError = const PortalStudentException(
      'Temporary network disconnection.',
    );
    await tester.tap(find.byTooltip('Refresh students'));
    await tester.pumpAndSettle();

    // Previously loaded valid data MUST NOT disappear on refresh failure!
    expect(find.text('Ana Santos'), findsOneWidget);
    expect(find.textContaining('Temporary network disconnection'), findsOneWidget);

    // 2. StudentRosterScreen retains Santos, Ana when refresh fails transiently
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StudentRosterScreen(portalStudentRepository: studentRepo),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Santos, Ana'), findsOneWidget);

    studentRepo.nextRosterError = const PortalStudentException(
      'Roster refresh timed out.',
    );
    await tester.tap(find.byTooltip('Refresh roster'));
    await tester.pumpAndSettle();
    expect(find.text('Santos, Ana'), findsOneWidget);

    // 3. AuthorizedPersonnelScreen retains Nurse Clara while in-flight refresh runs
    await tester.pumpWidget(
      MaterialApp(
        home: AuthorizedPersonnelScreen(
          embedded: true,
          accessRepository: accessRepo,
          managementRepository: mgmtRepo,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nurse Clara'), findsOneWidget);

    final pendingMgmt = Completer<List<AuthorizedAccountSummary>>();
    mgmtRepo.pendingLoad = pendingMgmt;
    await tester.tap(find.byTooltip('Refresh'));
    await tester.pump();
    // Must stay visible during refresh instead of replacing with blank spinner!
    expect(find.text('Nurse Clara'), findsOneWidget);
    pendingMgmt.complete(mgmtRepo.accounts);
    await tester.pumpAndSettle();

    // 4. ActivityLogsScreen retains existing audit entries when refresh fails
    await tester.pumpWidget(
      MaterialApp(home: ActivityLogsScreen(repository: studentRepo)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Student Manually Verified'), findsWidgets);

    studentRepo.nextLogsError = const PortalStudentException(
      'Activity logs refresh failed.',
    );
    await tester.tap(find.byTooltip('Refresh activity logs'));
    await tester.pumpAndSettle();
    expect(find.text('Student Manually Verified'), findsWidgets);

    // 5. PortalDashboardScreen surfaces transient refresh error while preserving stats
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PortalDashboardScreen(
            access: _masterAdmin,
            onScanStudentQr: null,
            portalStudentRepository: studentRepo,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('42'), findsOneWidget);

    studentRepo.nextStatsError = const PortalStudentException(
      'Dashboard refresh failed.',
    );
    await tester.tap(find.byTooltip('Refresh statistics'));
    await tester.pumpAndSettle();
    expect(find.text('42'), findsOneWidget);
    expect(find.textContaining('Dashboard refresh failed'), findsOneWidget);

    // 6. StudentDetailsScreen retains loaded details during refresh
    await tester.pumpWidget(
      MaterialApp(
        home: StudentDetailsScreen(
          studentUid: 'stu-1',
          initialName: 'Ana Santos',
          accessRepository: accessRepo,
          portalStudentRepository: studentRepo,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ana Santos'), findsOneWidget);
  });

  testWidgets(
      'RC-4: out-of-order slow response does NOT overwrite newer filter selection',
      (tester) async {
    final accessRepo = _ControllableAccessRepo();
    final studentRepo = _ControllableStudentRepo();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ActiveStudentsScreen(
            accessRepository: accessRepo,
            portalStudentRepository: studentRepo,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final slowRegistered = Completer<SchoolStudentPage>();
    final fastVerified = Completer<SchoolStudentPage>();
    studentRepo.completersByStatus['registered'] = slowRegistered;
    studentRepo.completersByStatus['verified'] = fastVerified;

    // Tap Registered first (slow request #1)
    await tester.tap(find.widgetWithText(ChoiceChip, 'Registered'));
    await tester.pump();

    // Immediately switch to Verified (newer fast request #2) while #1 is still in flight!
    await tester.tap(find.widgetWithText(ChoiceChip, 'Verified'));
    await tester.pump();

    fastVerified.complete(
      const SchoolStudentPage(
        students: [
          SchoolStudentSummary(
            uid: 'stu-fast',
            fullName: 'Verified Winner',
            maskedLrn: '1111••••2222',
            hasLrn: true,
            gradeLevel: 'Grade 10',
            accountCategory: 'verified',
            schoolApprovalStatus: 'approved',
            verificationMethod: 'roster',
          ),
        ],
        nextCursor: null,
        totalMatched: 1,
        availableGrades: ['Grade 10'],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Verified Winner'), findsOneWidget);

    // Now the stale Registered response arrives late — MUST BE IGNORED!
    slowRegistered.complete(
      const SchoolStudentPage(
        students: [
          SchoolStudentSummary(
            uid: 'stu-stale',
            fullName: 'Stale Loser',
            maskedLrn: '9999••••0000',
            hasLrn: true,
            gradeLevel: 'Grade 10',
            accountCategory: 'registered',
            schoolApprovalStatus: 'pending',
            verificationMethod: null,
          ),
        ],
        nextCursor: null,
        totalMatched: 1,
        availableGrades: ['Grade 10'],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Verified Winner'), findsOneWidget);
    expect(find.text('Stale Loser'), findsNothing);
  });

  test(
      'RC-1, RC-4, RC-5: PortalReadCoordinator runs concurrent reads outside AccountOperationLock, deduplicates identical requests, retries transient reads only, and purges on scope change',
      () async {
    String? currentUid = 'master-1';
    final sharedLock = AccountOperationLock();
    final delays = <Duration>[];
    Object? authLossCaptured;
    final coordinator = PortalReadCoordinator(
      currentUidProvider: () => currentUid,
      maxReadAttempts: 3,
      initialBackoff: const Duration(milliseconds: 100),
      delayFn: (d) async => delays.add(d),
      onSessionAuthorizationLost: (err) => authLossCaptured = err,
    )..bindScope(uid: 'master-1', schoolId: 'school-alpha', role: 'admin');

    // 1. Even while a destructive AccountOperationLock mutation is active,
    // concurrent reads across all 6 Portal surfaces succeed without StateError!
    final mutationCompleter = Completer<void>();
    final mutationFuture = sharedLock.run(() => mutationCompleter.future);
    expect(sharedLock.busy, isTrue);

    final concurrentResults = await Future.wait<String>([
      coordinator.runRead(
        key: 'dashboard',
        action: () async => 'stats-ok',
      ),
      coordinator.runRead(
        key: 'students',
        action: () async => 'students-ok',
      ),
      coordinator.runRead(
        key: 'roster',
        action: () async => 'roster-ok',
      ),
      coordinator.runRead(
        key: 'personnel',
        action: () async => 'personnel-ok',
      ),
      coordinator.runRead(
        key: 'details:stu-1',
        action: () async => 'details-ok',
      ),
      coordinator.runRead(
        key: 'logs',
        action: () async => 'logs-ok',
      ),
    ]);
    expect(concurrentResults, hasLength(6));
    mutationCompleter.complete();
    await mutationFuture;

    // 2. Deduplication: 4 identical concurrent reads invoke the backend once!
    var backendCalls = 0;
    final dedupCompleter = Completer<int>();
    final f1 = coordinator.runRead<int>(
      key: 'listSchoolStudents:s=|st=all',
      action: () {
        backendCalls += 1;
        return dedupCompleter.future;
      },
    );
    final f2 = coordinator.runRead<int>(
      key: 'listSchoolStudents:s=|st=all',
      action: () {
        backendCalls += 1;
        return dedupCompleter.future;
      },
    );
    final f3 = coordinator.runRead<int>(
      key: 'listSchoolStudents:s=|st=all',
      action: () {
        backendCalls += 1;
        return dedupCompleter.future;
      },
    );
    dedupCompleter.complete(99);
    expect(await Future.wait([f1, f2, f3]), [99, 99, 99]);
    expect(backendCalls, 1);

    // 3. Bounded retry with exponential backoff on transient read failure
    var transientAttempts = 0;
    final recovered = await coordinator.runRead<String>(
      key: 'coldStartQuery',
      action: () async {
        transientAttempts += 1;
        if (transientAttempts < 3) {
          throw FirebaseFunctionsException(
            code: 'unavailable',
            message: 'Cold start unavailable',
          );
        }
        return 'recovered-on-attempt-3';
      },
    );
    expect(recovered, 'recovered-on-attempt-3');
    expect(transientAttempts, 3);
    expect(
      delays,
      [const Duration(milliseconds: 100), const Duration(milliseconds: 200)],
    );

    // 4. Non-transient errors (e.g. invalid-argument) are NEVER retried
    var invalidArgAttempts = 0;
    await expectLater(
      coordinator.runRead<void>(
        key: 'badQuery',
        action: () async {
          invalidArgAttempts += 1;
          throw FirebaseFunctionsException(
            code: 'invalid-argument',
            message: 'Invalid filter',
          );
        },
      ),
      throwsA(isA<FirebaseFunctionsException>()),
    );
    expect(invalidArgAttempts, 1);

    // 5. Session authorization loss immediately clears cached scope & notifies shell
    expect(coordinator.cachedEntryCount, greaterThan(0));
    await expectLater(
      coordinator.runRead<void>(
        key: 'suspendedCheck',
        action: () async {
          throw FirebaseFunctionsException(
            code: 'permission-denied',
            message: 'Staff access is unavailable.',
          );
        },
      ),
      throwsA(isA<FirebaseFunctionsException>()),
    );
    expect(coordinator.cachedEntryCount, 0);
    expect(coordinator.activeScopeKey, isNull);
    expect(authLossCaptured, isNotNull);

    // 6. Unauthenticated read blocked before firing network request
    currentUid = null;
    var unauthNetworkFired = false;
    await expectLater(
      coordinator.runRead<void>(
        key: 'blockedRead',
        action: () async {
          unauthNetworkFired = true;
        },
      ),
      throwsA(isA<StateError>()),
    );
    expect(unauthNetworkFired, isFalse);
  });

  testWidgets(
      'RC-2 & RC-6: cold-start waits for auth readiness, and suspension on app resume immediately clears protected data',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(412, 960);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final authReadyCompleter = Completer<String?>();
    final uidStream = StreamController<String?>.broadcast();
    addTearDown(uidStream.close);

    final accessRepo = _LifecycleAwareAccessRepo(
      waitFuture: authReadyCompleter.future,
      uidStream: uidStream.stream,
      initialAccess: _masterAdmin,
    );
    final studentRepo = _ControllableStudentRepo();
    final coordinator = PortalReadCoordinator(
      currentUidProvider: () => accessRepo.currentUid,
    );

    await tester.pumpWidget(
      AdminApp(
        accessRepository: accessRepo,
        portalStudentRepository: studentRepo,
        readCoordinator: coordinator,
      ),
    );
    await tester.pump();

    // Protected loadAccess MUST NOT run until waitForInitialAuthUid resolves!
    expect(accessRepo.loadAccessCount, 0);
    expect(find.text('42'), findsNothing);

    accessRepo.uid = 'master-1';
    authReadyCompleter.complete('master-1');
    await tester.pumpAndSettle();

    expect(accessRepo.loadAccessCount, 1);
    expect(find.text('42'), findsOneWidget);

    // Simulate account suspension while app was in background, then resume!
    accessRepo.nextLoadError = const StaffAccessDenied(
      'Staff access is unavailable for this account.',
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    // Protected dashboard statistics MUST be cleared immediately and user returned to Sign In!
    expect(find.text('42'), findsNothing);
    expect(find.text('Staff Sign In'), findsOneWidget);
    expect(coordinator.cachedEntryCount, 0);
    expect(accessRepo.signOutCount, 1);
  });
}

class _LifecycleAwareAccessRepo extends _ControllableAccessRepo
    implements SessionLifecycleAccessRepository {
  _LifecycleAwareAccessRepo({
    required this.waitFuture,
    required this.uidStream,
    required StaffAccess initialAccess,
  }) : super(uid: null, access: initialAccess);

  final Future<String?> waitFuture;
  final Stream<String?> uidStream;

  @override
  Future<String?> waitForInitialAuthUid() => waitFuture;

  @override
  Stream<String?> get authUidChanges => uidStream;
}
