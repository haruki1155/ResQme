import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqme/app/resqme_app.dart';
import 'package:resqme/features/welcome/data/consent_repository.dart';

class _AcceptedConsentRepository implements ConsentRepository {
  @override
  Future<void> acceptTerms() async {}

  @override
  Future<bool> hasAcceptedTerms() async => true;
}

void main() {
  testWidgets('filters first-aid guides by category and search', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ResQMeApp(consentRepository: _AcceptedConsentRepository()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue as Guest'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('First-aid instructions'), 250);
    await tester.drag(find.byType(ListView), const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(find.text('First-aid instructions'));
    await tester.pumpAndSettle();

    expect(find.text('First-aid instructions'), findsOneWidget);
    expect(find.text('Breathing & response'), findsWidgets);
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'nosebleed');
    await tester.pump();
    expect(find.text('Nosebleed'), findsOneWidget);
    expect(find.text('Asthma'), findsNothing);
  });

  testWidgets('opens a complete guide with a future image area', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ResQMeApp(consentRepository: _AcceptedConsentRepository()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue as Guest'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('First-aid instructions'), 250);
    await tester.drag(find.byType(ListView), const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(find.text('First-aid instructions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Asthma'));
    await tester.pumpAndSettle();

    expect(find.text('Instruction image'), findsOneWidget);
    expect(find.text('Step 1: Sit the person upright'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('What if only 1 puff is available?'),
      300,
    );
    expect(find.text('What if only 1 puff is available?'), findsOneWidget);
    expect(find.text('Step 1: Use the puffer'), findsNothing);

    await tester.tap(find.text('What if only 1 puff is available?'));
    await tester.pump();
    expect(find.text('Step 1: Use the puffer'), findsOneWidget);
  });
}
