import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqme/app/resqme_app.dart';
import 'package:resqme/features/welcome/data/consent_repository.dart';
import 'package:resqme/features/public_support/presentation/first_aid_screens.dart';

class _AcceptedConsentRepository implements ConsentRepository {
  @override
  Future<void> acceptTerms() async {}

  @override
  Future<bool> hasAcceptedTerms() async => true;
}

void main() {
  testWidgets('category menu retains filtering with expandable cards', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: FirstAidLibraryScreen()));
    await tester.tap(find.byTooltip('Filter guides'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bleeding & wounds').last);
    await tester.pumpAndSettle();
    expect(find.text('2 GUIDES'), findsOneWidget);
    expect(find.text('Asthma'), findsNothing);
    expect(find.text('Nosebleed'), findsOneWidget);
  });

  testWidgets('expanded guide fits narrow screens with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.8)),
          child: child!,
        ),
        home: const FirstAidLibraryScreen(),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('Open full guide'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'mockup search action filters guides and explains empty results',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: FirstAidLibraryScreen()));
      expect(find.text('IMMEDIATE CARE GUIDE'), findsOneWidget);
      expect(find.text('What do you need\nhelp with?'), findsOneWidget);
      expect(find.byIcon(Icons.camera_alt_outlined), findsNothing);
      await tester.enterText(find.byType(TextField), 'no-match-g5');
      await tester.tap(find.byTooltip('Search guides'));
      await tester.pumpAndSettle();
      expect(find.text('No guides found'), findsOneWidget);
      await tester.tap(find.text('Clear search & filters'));
      await tester.pumpAndSettle();
      expect(find.text('10 GUIDES'), findsOneWidget);
    },
  );

  testWidgets('filters first-aid guides by category and search', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ResQMeApp(consentRepository: _AcceptedConsentRepository()),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Go to Dashboard as Guest'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Go to Dashboard as Guest'));
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

    await tester.ensureVisible(find.text('Go to Dashboard as Guest'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Go to Dashboard as Guest'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('First-aid instructions'), 250);
    await tester.drag(find.byType(ListView), const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(find.text('First-aid instructions'));
    await tester.pumpAndSettle();
    expect(find.text('WHAT TO DO'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Open full guide'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open full guide'));
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
