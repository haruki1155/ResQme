import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqme/features/emergency/presentation/emergency_dashboard_screen.dart';

void main() {
  testWidgets(
    'shows the mockup-aligned Tier 1 Home Lobby on a narrow enlarged-text screen',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      await tester.pumpWidget(
        const MaterialApp(home: EmergencyDashboardScreen()),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Ready when it matters.'), findsOneWidget);
      expect(find.text('Emergency ID is active'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Tier 2 information'), 300);
      expect(find.text('Tier 2 information'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('First-aid instructions'), 300);
      expect(find.text('First-aid instructions'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Emergency hotlines'), 300);
      expect(find.text('Emergency hotlines'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('DRRM instructions'), 300);
      expect(find.text('DRRM instructions'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
