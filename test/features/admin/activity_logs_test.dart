import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqme/features/admin/screens/activity_logs_screen.dart';
import 'package:resqme/features/admin/screens/portal_dashboard_screen.dart';
import 'package:resqme/features/admin/services/portal_student_repository.dart';
import 'package:resqme/features/admin/services/staff_access_repository.dart';
import 'package:resqme/features/admin/widgets/portal_widgets.dart';

class _FakeActivityRepo implements PortalStudentRepository {
  @override
  String? get currentAdminUid => 'admin-1';

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
    const all = [
      ActivityLogEntry(
        id: 't1',
        sourceCollection: 'tier2AccessAudits',
        category: 'tier2',
        action: 'tier2_emergency_read',
        actionLabel: 'Emergency Tier 2 Scan',
        outcome: 'denied',
        actorUid: 'auth-1',
        actorDisplayName: 'Nurse One',
        actorRole: 'authorized',
        targetUid: 'stu-1',
        summary: 'Emergency Tier 2 Scan (emergency_response) • target_ineligible',
        reasonCode: 'target_ineligible',
        method: 'biometric',
        timestamp: '2026-11-25T11:00:00.000Z',
      ),
      ActivityLogEntry(
        id: 'a1',
        sourceCollection: 'staffManagementAudits',
        category: 'security',
        action: 'replace_student_qr',
        actionLabel: 'Student QR Replaced',
        outcome: 'allowed',
        actorUid: 'admin-1',
        actorDisplayName: 'Principal Elena Cruz',
        actorRole: 'admin',
        targetUid: 'stu-1',
        summary: 'Student QR Replaced via biometric (lost) v2',
        reasonCode: 'lost',
        method: 'biometric',
        timestamp: '2026-11-25T10:00:00.000Z',
      ),
    ];
    final filtered = all.where((e) {
      if (category != 'all' && e.category != category) return false;
      if (outcome != 'all' && e.outcome != outcome) return false;
      if (search.trim().isNotEmpty &&
          !e.actionLabel.toLowerCase().contains(search.trim().toLowerCase())) {
        return false;
      }
      return true;
    }).toList();
    return ActivityLogPage(
      entries: filtered,
      nextCursor: null,
      totalMatched: filtered.length,
    );
  }

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
  }) async =>
      const SchoolStudentPage(
        students: [],
        nextCursor: null,
        totalMatched: 0,
        availableGrades: [],
      );

  @override
  Future<SchoolStudentDetails> getStudentDetails(String studentUid) =>
      throw UnimplementedError();

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
  Future<QrReplacementResult> replaceStudentQrWithBiometric({
    required String studentUid,
    required String reason,
    required String requestId,
  }) =>
      throw UnimplementedError();

  @override
  Future<QrReplacementResult> replaceStudentQrWithPassword({
    required String studentUid,
    required String reason,
    required String requestId,
    required String password,
  }) =>
      throw UnimplementedError();

  @override
  Future<String> revealLrnWithBiometric({
    required String targetType,
    required String targetId,
  }) =>
      throw UnimplementedError();

  @override
  Future<String> revealLrnWithPassword({
    required String targetType,
    required String targetId,
    required String password,
  }) =>
      throw UnimplementedError();

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
  testWidgets('Dashboard shows Activity Logs quick action only when provided',
      (tester) async {
    var opened = false;
    final repo = _FakeActivityRepo();
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
            onOpenActivityLogs: () => opened = true,
            portalStudentRepository: repo,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Activity Logs'), findsOneWidget);
    await tester.tap(find.text('View'));
    expect(opened, isTrue);
  });

  testWidgets('ActivityLogsScreen filters by category/outcome and opens details',
      (tester) async {
    final repo = _FakeActivityRepo();
    await tester.pumpWidget(
      MaterialApp(
        theme: _testTheme(),
        home: ActivityLogsScreen(repository: repo),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Emergency Tier 2 Scan'), findsOneWidget);
    expect(find.text('Student QR Replaced'), findsOneWidget);
    // Date grouping header & PHT timestamp + actor display name & role badge
    expect(find.text('Nov 25, 2026 (Asia/Manila)'), findsOneWidget);
    expect(find.text('Nurse One'), findsOneWidget);
    expect(find.text('AUTHORIZED STAFF'), findsOneWidget);
    expect(find.textContaining('7:00 PM PHT'), findsOneWidget);

    await tester.tap(find.text('Security'));
    await tester.pumpAndSettle();
    expect(find.text('Emergency Tier 2 Scan'), findsNothing);
    expect(find.text('Student QR Replaced'), findsOneWidget);

    await tester.tap(find.text('Student QR Replaced'));
    await tester.pumpAndSettle();
    expect(find.text('staffManagementAudits'), findsOneWidget);
  });

  testWidgets('Captures 360dp and 412dp Activity Logs screenshots',
      (tester) async {
    final screenshotDir = Platform.environment['RESQME_PHASE25_SCREENSHOT_DIR'];
    if (screenshotDir == null || screenshotDir.isEmpty) return;

    for (final width in [360.0, 412.0]) {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: _testTheme(),
            home: ActivityLogsScreen(repository: _FakeActivityRepo()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await _capturePng(
          tester,
          key,
          '$screenshotDir/activity_logs_${width.toInt()}dp.png',
        );
      });
    }
  });
}
