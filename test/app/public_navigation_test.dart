import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqme/app/resqme_app.dart';
import 'package:resqme/features/emergency/presentation/emergency_dashboard_screen.dart';
import 'package:resqme/features/welcome/data/consent_repository.dart';

class _AcceptedConsentRepository implements ConsentRepository {
  @override
  Future<void> acceptTerms() async {}

  @override
  Future<bool> hasAcceptedTerms() async => true;
}

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ResQMeApp(consentRepository: _AcceptedConsentRepository()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue as Guest'));
    await tester.pumpAndSettle();
  }

  testWidgets('opens each public service and returns to the Home Lobby', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    for (final destination in const [
      'First-aid instructions',
      'Emergency hotlines',
      'DRRM instructions',
    ]) {
      await tester.scrollUntilVisible(find.text(destination), 250);
      await tester.drag(find.byType(ListView), const Offset(0, -120));
      await tester.pumpAndSettle();
      await tester.tap(find.text(destination));
      await tester.pumpAndSettle();

      expect(find.text(destination), findsOneWidget);
      expect(find.byTooltip('Back'), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(EmergencyDashboardScreen), findsOneWidget);
    }
  });

  testWidgets('opens scan and profile entry from the bottom navigation', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tester.scrollUntilVisible(find.byTooltip('Scan QR'), 250);
    await tester.tap(find.byTooltip('Scan QR'));
    await tester.pumpAndSettle();
    expect(find.text('Scan QR'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byTooltip('Profile'), 250);
    await tester.tap(find.byTooltip('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Student Account'), findsOneWidget);
  });

  testWidgets('Tier 2 route presents a boundary without profile data', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('Tier 2 information'));
    await tester.pumpAndSettle();

    expect(find.text('Restricted information'), findsOneWidget);
    expect(find.text('Blood Type'), findsNothing);
    expect(find.text('Juan Dela Cruz'), findsNothing);
    expect(find.text('Fingerprint / Facial Recognition'), findsNothing);
  });
}
