import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:resqme/app/resqme_app.dart';
import 'package:resqme/features/welcome/data/consent_repository.dart';

class _FakeConsentRepository implements ConsentRepository {
  _FakeConsentRepository({required this.accepted, this.acceptanceCompleter});

  bool accepted;
  final Completer<void>? acceptanceCompleter;

  @override
  Future<void> acceptTerms() async {
    await acceptanceCompleter?.future;
    accepted = true;
  }

  @override
  Future<bool> hasAcceptedTerms() async => accepted;
}

void main() {
  testWidgets('shows Terms & Privacy when consent has not been accepted', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ResQMeApp(consentRepository: _FakeConsentRepository(accepted: false)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Terms & Privacy'), findsOneWidget);
    expect(find.text('Flutter Demo Home Page'), findsNothing);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('opens the dashboard when consent has already been accepted', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ResQMeApp(consentRepository: _FakeConsentRepository(accepted: true)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Emergency Support'), findsOneWidget);
    expect(find.text('Flutter Demo Home Page'), findsNothing);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('persists consent and opens public emergency support', (
    WidgetTester tester,
  ) async {
    final repository = _FakeConsentRepository(accepted: false);
    await tester.pumpWidget(ResQMeApp(consentRepository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('I Agree'));
    await tester.pumpAndSettle();

    expect(repository.accepted, isTrue);
    expect(find.text('Emergency Support'), findsOneWidget);
    expect(find.text('Scan QR'), findsOneWidget);
    expect(find.text('First Aid'), findsOneWidget);
    expect(find.text('Emergency Hotlines'), findsOneWidget);
    expect(find.text('DRRM Guidance'), findsOneWidget);
  });

  testWidgets(
    'waits for consent persistence before opening emergency support',
    (WidgetTester tester) async {
      final persistence = Completer<void>();
      final repository = _FakeConsentRepository(
        accepted: false,
        acceptanceCompleter: persistence,
      );
      await tester.pumpWidget(ResQMeApp(consentRepository: repository));
      await tester.pumpAndSettle();

      await tester.tap(find.text('I Agree'));
      await tester.pump();

      expect(repository.accepted, isFalse);
      expect(find.text('Emergency Support'), findsNothing);

      persistence.complete();
      await tester.pumpAndSettle();

      expect(repository.accepted, isTrue);
      expect(find.text('Emergency Support'), findsOneWidget);
    },
  );
}
