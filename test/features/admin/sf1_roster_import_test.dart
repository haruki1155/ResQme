import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqme/features/admin/screens/student_roster_screen.dart';
import 'package:resqme/features/admin/services/portal_student_repository.dart';
import 'package:resqme/features/admin/widgets/portal_widgets.dart';

class _FakeSf1RosterRepo implements IntegrityBoundRosterImportRepository {
  bool committed = false;
  String? lastExpectedFileSha256;
  bool? lastPrivacyAck;

  @override
  String? get currentAdminUid => 'admin-1';

  @override
  Future<Sf1PickedFile?> pickSf1ExcelFile() async => const Sf1PickedFile(
        fileName: 'sf1_grade10_fictional.xlsx',
        fileBase64: 'ZmFrZQ==',
      );

  @override
  Future<RosterImportPreview> previewRosterImport({
    required String fileName,
    required String fileBase64,
    String? confirmedGradeLevel,
  }) async =>
      RosterImportPreview(
        previewId: 'a' * 32,
        fileName: fileName,
        fileSha256: 'b' * 64,
        detectedGradeLevel: 'Grade 10',
        confirmedGradeLevel: confirmedGradeLevel ?? 'Grade 10',
        totalRows: 2,
        newCount: 1,
        unchangedCount: 0,
        proposedUpdateCount: 0,
        duplicateCount: 0,
        conflictCount: 1,
        invalidCount: 0,
        rows: const [
          RosterImportPreviewRow(
            rowNumber: 10,
            status: 'new',
            maskedLrn: '0098••••3210',
            fullName: 'Juan Santos Dela Cruz',
            gradeLevel: 'Grade 10',
            sex: 'Male',
            birthDate: '2010-05-10',
            reason: null,
          ),
          RosterImportPreviewRow(
            rowNumber: 11,
            status: 'conflict',
            maskedLrn: '0011••••4455',
            fullName: 'Ana Reyes',
            gradeLevel: 'Grade 10',
            sex: 'Female',
            birthDate: '2010-06-11',
            reason: 'LRN already claimed by another student.',
          ),
        ],
      );

  @override
  Future<RosterImportCommitResult> commitRosterImport({
    required String previewId,
    required String requestId,
  }) =>
      commitBoundRosterImport(
        previewId: previewId,
        requestId: requestId,
        privacyNoticeAcknowledged: true,
      );

  @override
  Future<RosterImportCommitResult> commitBoundRosterImport({
    required String previewId,
    required String requestId,
    String? expectedFileSha256,
    required bool privacyNoticeAcknowledged,
  }) async {
    committed = true;
    lastExpectedFileSha256 = expectedFileSha256;
    lastPrivacyAck = privacyNoticeAcknowledged;
    return const RosterImportCommitResult(
      importId: 'imp_1',
      status: 'completed',
      committedCount: 1,
      newCount: 1,
      updatedCount: 0,
      generatedCredentials: [
        RosterGeneratedCredential(
          maskedLrn: '0098••••3210',
          fullName: 'Juan Santos Dela Cruz',
          gradeLevel: 'Grade 10',
          enrollmentCode: 'ABCD2345EFGH6789JKLM',
        ),
      ],
    );
  }

  @override
  Future<List<RosterImportHistoryItem>> listRosterImports() async => const [
        RosterImportHistoryItem(
          importId: 'imp_1',
          fileName: 'sf1_grade10_fictional.xlsx',
          confirmedGradeLevel: 'Grade 10',
          status: 'completed',
          committedCount: 1,
          newCount: 1,
          updatedCount: 0,
          timestamp: '2026-11-25T12:00:00.000Z',
        ),
      ];

  @override
  Future<SchoolRosterPage> listRoster({
    String search = '',
    String? gradeFilter,
    int limit = 20,
    String? cursor,
  }) async =>
      SchoolRosterPage(
        rosterAvailable: true,
        entries: [
          const SchoolRosterEntry(
            rosterId: 'r-1',
            displayName: 'Dela Cruz, Juan Santos',
            maskedLrn: '0098••••3210',
            hasLrn: true,
            gradeLevel: 'Grade 10',
            sex: 'Male',
            birthDate: '2010-05-10',
            registrationState: 'not_registered',
            claimedStudentUid: null,
          ),
          if (committed)
            const SchoolRosterEntry(
              rosterId: 'r-2',
              displayName: 'Reyes, Ana',
              maskedLrn: '0011••••4455',
              hasLrn: true,
              gradeLevel: 'Grade 10',
              sex: 'Female',
              birthDate: '2010-06-11',
              registrationState: 'verified',
              claimedStudentUid: 'stu-2',
            ),
        ],
        nextCursor: null,
        totalMatched: committed ? 2 : 1,
        availableGrades: const ['Grade 10'],
      );

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
  Future<PortalDashboardStats> loadDashboardStats() async =>
      const PortalDashboardStats(
        schoolId: '000000123',
        rosterAvailable: true,
        importedRosterCount: 1,
        registeredStudentsCount: 0,
        verifiedStudentsCount: 0,
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
  testWidgets('StudentRosterScreen completes SF1 import, displays masked LRNs, and shows history',
      (tester) async {
    final repo = _FakeSf1RosterRepo();
    await tester.pumpWidget(
      MaterialApp(
        theme: _testTheme(),
        home: Scaffold(
          body: StudentRosterScreen(portalStudentRepository: repo),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Import Student Roster'), findsOneWidget);
    expect(find.text('Import History'), findsOneWidget);

    await tester.tap(find.text('Import Student Roster'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Confirm SF1 Grade Level'), findsOneWidget);

    await tester.tap(find.text('Preview Import'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('SF1 Import Preview'), findsOneWidget);
    expect(find.text('New: 1'), findsOneWidget);
    expect(find.text('Conflicts: 1'), findsOneWidget);
    expect(find.textContaining('0098••••3210'), findsAtLeastNWidgets(1));
    expect(find.textContaining('009876543210'), findsNothing);
    expect(find.textContaining('Data Privacy Act Notice'), findsOneWidget);

    // Confirm & Import must stay disabled until explicit Data Privacy acknowledgement!
    final confirmBtnBefore = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Confirm & Import (1)'),
    );
    expect(confirmBtnBefore.onPressed, isNull);

    await tester.ensureVisible(find.byKey(const Key('sf1-privacy-ack-checkbox')));
    await tester.tap(find.byKey(const Key('sf1-privacy-ack-checkbox')));
    await tester.pump();

    await tester.tap(find.text('Confirm & Import (1)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('SF1 Import Complete'), findsOneWidget);
    expect(find.textContaining('ABCD2345EFGH6789JKLM'), findsOneWidget);
    expect(repo.lastExpectedFileSha256, 'b' * 64);
    expect(repo.lastPrivacyAck, isTrue);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(repo.committed, isTrue);

    await tester.tap(find.text('Import History'));
    await tester.pumpAndSettle();
    expect(find.text('SF1 Import History'), findsOneWidget);
    expect(find.text('sf1_grade10_fictional.xlsx'), findsOneWidget);
  });

  testWidgets('Captures 360dp and 412dp Student Roster Import screenshots',
      (tester) async {
    final screenshotDir = Platform.environment['RESQME_PHASE3_SCREENSHOT_DIR'];
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
            home: Scaffold(
              body: StudentRosterScreen(
                portalStudentRepository: _FakeSf1RosterRepo(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await _capturePng(
          tester,
          key,
          '$screenshotDir/student_roster_${width.toInt()}dp.png',
        );
      });
    }
  });
}
