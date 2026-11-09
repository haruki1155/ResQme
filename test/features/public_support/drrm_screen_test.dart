import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqme/app/resqme_app.dart';
import 'package:resqme/features/welcome/data/consent_repository.dart';
import 'package:resqme/features/public_support/presentation/drrm_screen.dart';

class R implements ConsentRepository {
  @override
  Future<void> acceptTerms() async {}

  @override
  Future<bool> hasAcceptedTerms() async => true;
}

void main() {
  testWidgets('empty search offers recovery to the hazard grid', (t) async {
    await t.pumpWidget(const MaterialApp(home: DrrmScreen()));
    await t.tap(find.byTooltip('Search hazards'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'no-match-g5');
    await t.pump();
    expect(find.text('No hazards found'), findsOneWidget);
    await t.tap(find.text('Clear search'));
    await t.pump();
    expect(find.byKey(const ValueKey('hazard-Earthquake')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('hazard-Transportation accidents')),
      findsOneWidget,
    );
  });

  testWidgets('action plan scrolls on small screens with enlarged text', (
    t,
  ) async {
    t.view.physicalSize = const Size(320, 568);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.8)),
          child: child!,
        ),
        home: const DrrmScreen(),
      ),
    );
    final card = find.byKey(const ValueKey('hazard-Earthquake'));
    await t.scrollUntilVisible(
      card,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await t.tap(card);
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      find.text('I understand'),
      180,
      scrollable: find.byType(Scrollable).last,
    );
    await t.tap(find.text('I understand'));
    await t.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('hazard opens mockup action plan and both actions dismiss it', (
    t,
  ) async {
    await t.pumpWidget(const MaterialApp(home: DrrmScreen()));
    expect(find.text('Know what to do.\nAct with confidence.'), findsOneWidget);
    await t.tap(find.text('Earthquake'));
    await t.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('EMERGENCY ACTION PLAN'), findsOneWidget);
    expect(find.textContaining('Before: Prepare kit'), findsOneWidget);
    await t.tap(find.text('Close'));
    await t.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    await t.tap(find.text('Earthquake'));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      find.text('I understand'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await t.tap(find.text('I understand'));
    await t.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('keeps all ten hazards and opens the selected guidance', (
    t,
  ) async {
    await t.pumpWidget(const MaterialApp(home: DrrmScreen()));
    for (final hazard in const [
      'Earthquake',
      'Tropical cyclone',
      'Flood',
      'Extreme heatwaves',
      'Fire',
      'Landslides and mudslides',
      'Tsunami',
      'Severe thunderstorm',
      'Drought',
      'Transportation accidents',
    ]) {
      final card = find.byKey(ValueKey('hazard-$hazard'));
      await t.scrollUntilVisible(
        card,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await t.ensureVisible(card);
      await t.pumpAndSettle();
      await t.tap(card);
      await t.pumpAndSettle();
      expect(
        find.descendant(of: find.byType(Dialog), matching: find.text(hazard)),
        findsOneWidget,
      );
      await t.tap(find.text('Close'));
      await t.pumpAndSettle();
    }
  });

  testWidgets('shows searchable DRRM guidance', (t) async {
    await t.pumpWidget(ResQMeApp(consentRepository: R()));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Go to Dashboard as Guest'));
    await t.pumpAndSettle();
    await t.tap(find.text('Go to Dashboard as Guest'));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.text('DRRM instructions'), 250);
    await t.drag(find.byType(ListView), const Offset(0, -120));
    await t.pumpAndSettle();
    await t.tap(find.text('DRRM instructions'));
    await t.pumpAndSettle();
    expect(find.text('DISASTER PREPAREDNESS'), findsOneWidget);
    await t.tap(find.byTooltip('Search hazards'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'Tsunami');
    await t.pump();
    expect(find.text('Tsunami'), findsWidgets);
  });
}
