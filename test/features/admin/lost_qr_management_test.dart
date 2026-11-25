import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqme/core/data/pilot_client.dart';
import 'package:resqme/features/admin/screens/lost_qr_management_screen.dart';
import 'package:resqme/features/admin/screens/portal_dashboard_screen.dart';
import 'package:resqme/features/admin/screens/student_details_screen.dart';
import 'package:resqme/features/admin/services/portal_student_repository.dart';
import 'package:resqme/features/admin/services/staff_access_repository.dart';
import 'package:resqme/features/admin/widgets/portal_widgets.dart';
import 'package:resqme/features/qr/screens/my_unverified_qr_screen.dart';
import 'package:resqme/features/qr/services/tier1_qr_repository.dart';

class _FakePortalStudentRepo implements PortalStudentRepository {
  int version = 1;
  bool shouldFail = false;

  @override
  String? get currentAdminUid => 'admin-1';

  @override
  Future<PortalDashboardStats> loadDashboardStats() async =>
      const PortalDashboardStats(
        schoolId: '000000123',
        rosterAvailable: false,
        importedRosterCount: 0,
        registeredStudentsCount: 1,
        verifiedStudentsCount: 1,
        disabledStudentsCount: 0,
        authorizedPersonnelCount: 1,
      );

  @override
  Future<SchoolStudentPage> listStudents({
    String search = '',
    String statusFilter = 'all',
    String? gradeFilter,
    int limit = 20,
    String? cursor,
  }) async {
    return const SchoolStudentPage(
      students: [
        SchoolStudentSummary(
          uid: 'student-1',
          fullName: 'Juan Dela Cruz',
          maskedLrn: '1234••••9012',
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
    );
  }

  @override
  Future<SchoolStudentDetails> getStudentDetails(String studentUid) async {
    return SchoolStudentDetails(
      uid: studentUid,
      fullName: 'Juan Dela Cruz',
      maskedLrn: '1234••••9012',
      hasLrn: true,
      gradeLevel: 'Grade 10',
      sex: 'Male',
      birthDate: '2009-05-10',
      ageYearsAtRegistration: 16,
      accountCategory: 'verified',
      accountDisabled: false,
      registrationStatus: 'pending_guardian',
      schoolApprovalStatus: 'approved',
      verificationMethod: 'roster',
      verificationOutcome: 'roster_matched',
      medicalCompletionStatus: 'complete',
      guardianAuthorizationStatus: 'verified',
      qrStatus: 'active',
      credentialVersion: version,
      canVerifyManually: false,
    );
  }

  @override
  Future<QrReplacementResult> replaceStudentQrWithBiometric({
    required String studentUid,
    required String reason,
    required String requestId,
  }) async {
    if (shouldFail) {
      throw const PortalStudentException('Simulated biometric failure');
    }
    version += 1;
    return QrReplacementResult(
      studentUid: studentUid,
      verificationStatus: 'active',
      credentialVersion: version,
      reason: reason,
    );
  }

  @override
  Future<QrReplacementResult> replaceStudentQrWithPassword({
    required String studentUid,
    required String reason,
    required String requestId,
    required String password,
  }) async {
    if (shouldFail) {
      throw const PortalStudentException('Incorrect password.');
    }
    version += 1;
    return QrReplacementResult(
      studentUid: studentUid,
      verificationStatus: 'active',
      credentialVersion: version,
      reason: reason,
    );
  }

  @override
  Future<SchoolRosterPage> listRoster({
    String search = '',
    String? gradeFilter,
    int limit = 20,
    String? cursor,
  }) async =>
      const SchoolRosterPage(
        rosterAvailable: false,
        entries: [],
        nextCursor: null,
        totalMatched: 0,
        availableGrades: [],
      );

  @override
  Future<String> revealLrnWithBiometric({
    required String targetType,
    required String targetId,
  }) async =>
      '123456789012';

  @override
  Future<String> revealLrnWithPassword({
    required String targetType,
    required String targetId,
    required String password,
  }) async =>
      '123456789012';

  @override
  Future<void> setSecureScreen(bool enabled) async {}

  @override
  Future<void> setStudentAccountStatus({
    required String studentUid,
    required String action,
  }) async {}

  @override
  Future<void> verifyStudentAccount({
    required String studentUid,
    required String requestId,
  }) async {}

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
  }) async =>
      const ActivityLogPage(entries: [], nextCursor: null, totalMatched: 0);

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
}

class _FakeAccessRepo implements StaffAccessRepository {
  @override
  String? get currentUid => 'admin-1';

  @override
  String? get currentEmail => 'admin@pilot.edu.ph';

  @override
  Future<StaffAccess> loadAccess() async => const StaffAccess(
        uid: 'admin-1',
        role: 'admin',
        schoolId: '000000123',
        active: true,
        isMasterAdmin: true,
        mustChangePassword: false,
        requiresEmailVerification: true,
        emailVerified: true,
        fullName: 'Master Admin',
      );

  @override
  Future<void> signIn(String identifier, String password) async {}

  @override
  Future<void> signOut() async {}

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

class _FakePilotClient implements PilotClient {
  int ensureCalls = 0;

  @override
  String? get uid => 'student-1';

  @override
  Future<Map<String, dynamic>> invoke(
    String name,
    Map<String, dynamic> data,
  ) async {
    ensureCalls += 1;
    final suffix = ensureCalls == 1
        ? 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
        : 'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB';
    return {
      'payload': 'resqme:v1:$suffix',
      'verificationStatus': 'active',
      'issuedAt': '2026-11-25T00:00:00.000Z',
    };
  }

  @override
  Future<Map<String, dynamic>?> readMine(String collection) async => null;

  @override
  Future<bool> resolveQr(String payload) async => true;
}

ThemeData _testTheme() => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: PortalColors.brandRed),
      scaffoldBackgroundColor: PortalColors.background,
    );

Future<void> _capturePng(
  WidgetTester tester,
  GlobalKey boundaryKey,
  String path,
) async {
  final boundary =
      boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1.5);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  if (data != null) {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data.buffer.asUint8List());
  }
}

void main() {
  testWidgets('Dashboard shows Lost QR Management quick action', (tester) async {
    var opened = false;
    final repo = _FakePortalStudentRepo();
    await tester.pumpWidget(
      MaterialApp(
        theme: _testTheme(),
        home: Scaffold(
          body: PortalDashboardScreen(
            access: const StaffAccess(
              uid: 'admin-1',
              role: 'admin',
              schoolId: '000000123',
              active: true,
              isMasterAdmin: true,
              mustChangePassword: false,
              requiresEmailVerification: true,
              emailVerified: true,
              fullName: 'Master Admin',
            ),
            onScanStudentQr: () {},
            onOpenLostQrManagement: () => opened = true,
            portalStudentRepository: repo,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Lost QR Management'), findsOneWidget);
    await tester.tap(find.text('Open'));
    expect(opened, isTrue);
  });

  testWidgets('Lost QR Management replaces QR with reason and updates version',
      (tester) async {
    final repo = _FakePortalStudentRepo();
    await tester.pumpWidget(
      MaterialApp(
        theme: _testTheme(),
        home: LostQrManagementScreen(repository: repo),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Juan Dela Cruz'), findsOneWidget);
    expect(find.textContaining('1234••••9012'), findsOneWidget);

    await tester.tap(find.text('Replace QR'));
    await tester.pumpAndSettle();

    expect(find.text('Replace Student QR Code'), findsOneWidget);
    expect(find.textContaining('Permanent Invalidation Warning'), findsOneWidget);
    await tester.tap(find.text('Damaged QR code'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Confirm & Replace QR'));
    await tester.pumpAndSettle();

    expect(repo.version, 2);
    expect(find.textContaining('Credential v2'), findsOneWidget);
    expect(find.textContaining('reason: damaged'), findsOneWidget);
  });

  testWidgets('Student Details shows Replace QR Code and Credential Version',
      (tester) async {
    final repo = _FakePortalStudentRepo();
    await tester.pumpWidget(
      MaterialApp(
        theme: _testTheme(),
        home: StudentDetailsScreen(
          studentUid: 'student-1',
          initialName: 'Juan Dela Cruz',
          accessRepository: _FakeAccessRepo(),
          portalStudentRepository: repo,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('v1'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.text('Replace QR Code'), findsOneWidget);
    await tester.tap(find.text('Replace QR Code'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Confirm & Replace QR'));
    await tester.pumpAndSettle();

    expect(repo.version, 2);
    expect(find.text('v2'), findsOneWidget);
  });

  testWidgets('Student MyUnverifiedQrScreen refreshes replaced QR from server',
      (tester) async {
    final client = _FakePilotClient();
    final qrRepo = Tier1QrRepository(client);
    await tester.pumpWidget(
      MaterialApp(
        home: MyUnverifiedQrScreen(
          repository: qrRepo,
          onDashboard: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(client.ensureCalls, 1);

    await tester.tap(find.byTooltip('Refresh QR'));
    await tester.pumpAndSettle();
    expect(client.ensureCalls, 2);
  });

  testWidgets('Captures 360dp and 412dp Lost QR Management screenshots',
      (tester) async {
    final screenshotDir = Platform.environment['RESQME_PHASE24_SCREENSHOT_DIR'];
    if (screenshotDir == null || screenshotDir.isEmpty) return;

    for (final width in [360.0, 412.0]) {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = _FakePortalStudentRepo();
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: _testTheme(),
            home: LostQrManagementScreen(repository: repo),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await _capturePng(
          tester,
          key,
          '$screenshotDir/lost_qr_management_${width.toInt()}dp.png',
        );
      });
    }
  });
}
