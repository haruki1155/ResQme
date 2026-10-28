import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqme/features/emergency/presentation/emergency_dashboard_screen.dart';

void main() {
  testWidgets(
    'fits every public destination on a narrow enlarged-text screen',
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
      expect(find.text('Scan QR'), findsOneWidget);
      expect(find.text('First Aid'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Emergency Hotlines'), 300);
      expect(find.text('Emergency Hotlines'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('DRRM Guidance'), 300);
      expect(find.text('DRRM Guidance'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
