import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqme/core/widgets/feature_guide.dart';
import 'package:resqme/features/admin/screens/portal_dashboard_screen.dart';
import 'package:resqme/features/admin/services/staff_access_repository.dart';
import 'package:resqme/features/emergency/presentation/emergency_dashboard_screen.dart';
import 'package:resqme/features/public_support/presentation/first_aid_screens.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    FeatureGuidePolicy.resetSessionCacheForTesting();
  });

  testWidgets(
      'Phase 7: FeatureGuide auto-opens once per account+feature+version, shows non-blocking locator hint on dismiss, never reopens on rebuild, reopens via >=48dp info icon, and stores zero PII',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 860));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final rebuildTrigger = ValueNotifier<int>(0);
    addTearDown(rebuildTrigger.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<int>(
          valueListenable: rebuildTrigger,
          builder: (_, count, _) => Scaffold(
            appBar: AppBar(
              title: Text('Roster Screen $count'),
              actions: const [
                FeatureGuideIconButton(
                  guide: ResQMeFeatureGuides.portalStudentRoster,
                  accountScope: 'sensitive-admin@school.edu.ph',
                  autoOpenOnFirstVisit: true,
                ),
              ],
            ),
            body: const Center(child: Text('Roster Body Content')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Auto-opened on first visit for this account+feature+version
    expect(
      find.text(ResQMeFeatureGuides.portalStudentRoster.title),
      findsOneWidget,
    );
    expect(find.text('Got it'), findsOneWidget);

    // Dismiss via 'Got it'
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();

    // Modal closed; brief non-obstructive locator hint appears without blocking body
    expect(find.text('Got it'), findsNothing);
    expect(find.textContaining('info icon'), findsOneWidget);
    expect(find.text('Roster Body Content'), findsOneWidget);

    // Trigger widget rebuild: must NOT reopen automatically!
    rebuildTrigger.value = 1;
    await tester.pumpAndSettle();
    expect(find.text('Got it'), findsNothing);

    // Verify tap target is >= 48x48 dp and manual tap reopens guide anytime
    final iconFinder = find.byIcon(Icons.info_outline);
    expect(iconFinder, findsOneWidget);
    final buttonSize = tester.getSize(
      find.ancestor(of: iconFinder, matching: find.byType(IconButton)),
    );
    expect(buttonSize.width, greaterThanOrEqualTo(48));
    expect(buttonSize.height, greaterThanOrEqualTo(48));

    await tester.tap(iconFinder);
    await tester.pumpAndSettle();
    expect(
      find.text(ResQMeFeatureGuides.portalStudentRoster.title),
      findsOneWidget,
    );

    // Close via top-right close icon
    await tester.tap(find.byTooltip('Close guide'));
    await tester.pumpAndSettle();
    expect(find.text('Got it'), findsNothing);

    // SharedPreferences must contain ONLY hashed boolean key — zero raw email/PII!
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    expect(keys, isNotEmpty);
    for (final k in keys) {
      expect(k.contains('sensitive-admin'), isFalse);
      expect(k.contains('@'), isFalse);
      expect(prefs.get(k), isA<bool>());
    }
  });

  testWidgets(
      'Phase 7: FeatureGuide modal scrolls cleanly without overflow at 1.8x enlarged text scale on 360dp narrow screen',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.8),
          ),
          child: child!,
        ),
        home: Scaffold(
          appBar: AppBar(
            title: const Text('Tier 2 QR'),
            actions: const [
              FeatureGuideIconButton(
                guide: ResQMeFeatureGuides.studentTier2Qr,
                accountScope: 'guest',
                autoOpenOnFirstVisit: true,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(ResQMeFeatureGuides.studentTier2Qr.title), findsOneWidget);
    await tester.ensureVisible(find.text('Got it'));
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Phase 7: Student and Admin screens expose >=48dp FeatureGuide info triggers that open offline instructions on tap',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 860));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // 1. EmergencyDashboardScreen
    await tester.pumpWidget(
      const MaterialApp(home: EmergencyDashboardScreen()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.info_outline).first);
    await tester.pumpAndSettle();
    expect(
      find.text(ResQMeFeatureGuides.studentDashboard.title),
      findsOneWidget,
    );
    await _maybeCaptureScreenshot(tester, 'feature_guide_student_modal.png');
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();

    // 2. FirstAidLibraryScreen (offline)
    await tester.pumpWidget(
      const MaterialApp(home: FirstAidLibraryScreen()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.info_outline).first);
    await tester.pumpAndSettle();
    expect(
      find.text(ResQMeFeatureGuides.studentFirstAid.title),
      findsOneWidget,
    );
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();

    // 3. PortalDashboardScreen
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PortalDashboardScreen(
            access: const StaffAccess(
              uid: 'admin-uid-1',
              role: 'master_admin',
              schoolId: 'pilot-school-main',
              active: true,
              isMasterAdmin: true,
              mustChangePassword: false,
              fullName: 'Test Admin',
            ),
            onScanStudentQr: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.info_outline).first);
    await tester.pumpAndSettle();
    expect(
      find.text(ResQMeFeatureGuides.portalDashboard.title),
      findsOneWidget,
    );
    await _maybeCaptureScreenshot(tester, 'feature_guide_portal_modal.png');
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
  });
}
