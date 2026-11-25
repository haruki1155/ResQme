import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqme/core/widgets/resqme_skeleton.dart';
import 'package:resqme/features/admin/screens/activity_logs_screen.dart';
import 'package:resqme/features/admin/screens/portal_dashboard_screen.dart';
import 'package:resqme/features/admin/screens/student_roster_screen.dart';
import 'package:resqme/features/admin/services/portal_student_repository.dart';
import 'package:resqme/features/admin/services/staff_access_repository.dart';
import 'package:resqme/features/admin/widgets/portal_widgets.dart';

const _screenshotDir = String.fromEnvironment('RESQME_SCREENSHOT_DIR');

Future<void> _maybeCaptureScreenshot(
  WidgetTester tester,
  String fileName,
) async {
  if (_screenshotDir.isEmpty) return;
  final renderView = tester.binding.renderViews.first;
  // ignore: invalid_use_of_protected_member
  final layer = renderView.debugLayer as OffsetLayer?;
  if (layer == null) return;
  await tester.runAsync(() async {
    final image = await layer.toImage(renderView.paintBounds);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (byteData != null) {
      final file = File('$_screenshotDir/$fileName');
      await file.writeAsBytes(byteData.buffer.asUint8List());
    }
  });
}

class _ControllablePortalRepo implements PortalStudentRepository {
  Completer<PortalDashboardStats> statsCompleter =
      Completer<PortalDashboardStats>();
  Completer<SchoolRosterPage> rosterCompleter = Completer<SchoolRosterPage>();
  Completer<ActivityLogPage> logsCompleter = Completer<ActivityLogPage>();

  @override
  String? get currentAdminUid => 'admin-1';

  @override
  Future<PortalDashboardStats> loadDashboardStats() => statsCompleter.future;

  @override
  Future<SchoolRosterPage> listRoster({
    String search = '',
    String? gradeFilter,
    String registrationFilter = 'all',
    int limit = 20,
    String? cursor,
  }) =>
      rosterCompleter.future;

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
      logsCompleter.future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const testAccess = StaffAccess(
    uid: 'admin-1',
    role: 'master_admin',
    schoolId: 'pilot-school-main',
    active: true,
    isMasterAdmin: true,
    mustChangePassword: false,
    fullName: 'Maria Santos',
  );

  testWidgets(
      'Phase 8: Skeletons render during initialLoading only, preserve valid data during refresh, never show on empty state, and honor reduced motion',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 860));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repo = _ControllablePortalRepo();

    // 1. Reduced-motion Dashboard initial load shows PortalDashboardSkeleton (not raw spinner) and settles cleanly
    await tester.pumpWidget(
      MaterialApp(
        theme: buildResQMePortalTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          body: PortalDashboardScreen(
            access: testAccess,
            onScanStudentQr: () {},
            portalStudentRepository: repo,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(PortalDashboardSkeleton), findsOneWidget);
    expect(find.byType(ResQMeSkeletonBox), findsWidgets);
    await _maybeCaptureScreenshot(tester, 'skeleton_portal_dashboard.png');

    // Complete initial load -> skeleton disappears, real stats appear
    repo.statsCompleter.complete(
      const PortalDashboardStats(
        schoolId: 'pilot-school-main',
        rosterAvailable: true,
        importedRosterCount: 120,
        registeredStudentsCount: 85,
        verifiedStudentsCount: 80,
        disabledStudentsCount: 2,
        authorizedPersonnelCount: 4,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PortalDashboardSkeleton), findsNothing);
    expect(find.text('120'), findsOneWidget);

    // Trigger refresh -> existing data remains visible, skeleton does NOT replace it!
    repo.statsCompleter = Completer<PortalDashboardStats>();
    await tester.tap(find.byTooltip('Refresh statistics'));
    await tester.pump();
    expect(find.text('120'), findsOneWidget);
    expect(find.byType(PortalDashboardSkeleton), findsNothing);
    expect(find.byType(PortalRefreshStrip), findsOneWidget);

    repo.statsCompleter.complete(
      const PortalDashboardStats(
        schoolId: 'pilot-school-main',
        rosterAvailable: true,
        importedRosterCount: 124,
        registeredStudentsCount: 86,
        verifiedStudentsCount: 81,
        disabledStudentsCount: 2,
        authorizedPersonnelCount: 4,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('124'), findsOneWidget);

    // 2. Empty state on ActivityLogsScreen shows PortalStateView, never perpetual skeleton
    await tester.pumpWidget(
      MaterialApp(
        theme: buildResQMePortalTheme(),
        home: ActivityLogsScreen(repository: repo),
      ),
    );
    await tester.pump();
    expect(find.byType(ActivityLogsSkeleton), findsOneWidget);

    repo.logsCompleter.complete(
      const ActivityLogPage(
        entries: <ActivityLogEntry>[],
        totalMatched: 0,
        nextCursor: null,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ActivityLogsSkeleton), findsNothing);
    expect(find.text('No Matching Activity Logs'), findsOneWidget);
  });

  testWidgets(
      'Phase 8: Responsive layouts pass without overflow across 360dp narrow, 412dp standard, 800dp tablet, and 1.6x enlarged text scale',
      (tester) async {
    final repo = _ControllablePortalRepo();
    repo.rosterCompleter.complete(
      const SchoolRosterPage(
        rosterAvailable: true,
        entries: <SchoolRosterEntry>[
          SchoolRosterEntry(
            rosterId: 'claim-1',
            displayName: 'Dela Cruz, Juan Santos',
            maskedLrn: '1098••••3210',
            hasLrn: true,
            gradeLevel: 'Grade 10',
            sex: 'M',
            birthDate: '2010-05-10',
            registrationState: 'verified',
            claimedStudentUid: 'student-1',
          ),
          SchoolRosterEntry(
            rosterId: 'claim-2',
            displayName: 'Reyes, Maria Clara',
            maskedLrn: '1098••••9999',
            hasLrn: true,
            gradeLevel: 'Grade 9',
            sex: 'F',
            birthDate: '2011-08-22',
            registrationState: 'not_registered',
            claimedStudentUid: null,
          ),
        ],
        availableGrades: <String>['Grade 9', 'Grade 10'],
        totalMatched: 2,
        nextCursor: null,
      ),
    );
    repo.statsCompleter.complete(
      const PortalDashboardStats(
        schoolId: 'pilot-school-main',
        rosterAvailable: true,
        importedRosterCount: 124,
        registeredStudentsCount: 86,
        verifiedStudentsCount: 81,
        disabledStudentsCount: 2,
        authorizedPersonnelCount: 4,
      ),
    );

    // 360dp narrow screen + 1.6x enlarged text on StudentRosterScreen
    await tester.binding.setSurfaceSize(const Size(360, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: buildResQMePortalTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.6),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: StudentRosterScreen(portalStudentRepository: repo),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('Dela Cruz, Juan Santos'),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Dela Cruz, Juan Santos'), findsOneWidget);
    await _maybeCaptureScreenshot(tester, 'responsive_360dp_roster.png');

    // 412dp standard screen
    await tester.binding.setSurfaceSize(const Size(412, 860));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // 800dp tablet screen on PortalDashboardScreen
    await tester.binding.setSurfaceSize(const Size(800, 1024));
    await tester.pumpWidget(
      MaterialApp(
        theme: buildResQMePortalTheme(),
        home: Scaffold(
          body: PortalDashboardScreen(
            access: testAccess,
            onScanStudentQr: () {},
            onOpenLostQrManagement: () {},
            onOpenActivityLogs: () {},
            portalStudentRepository: repo,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('124'), findsOneWidget);
    await _maybeCaptureScreenshot(tester, 'responsive_800dp_dashboard.png');
  });
}
