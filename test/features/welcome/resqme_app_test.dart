import 'dart:async';

import 'package:flutter/material.dart';
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

    expect(find.text('Terms and Conditions'), findsOneWidget);
    expect(find.text('Flutter Demo Home Page'), findsNothing);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('requires agreement before Terms can be accepted', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ResQMeApp(consentRepository: _FakeConsentRepository(accepted: false)),
    );
    await tester.pumpAndSettle();

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('opens scanner entry when consent has already been accepted', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ResQMeApp(consentRepository: _FakeConsentRepository(accepted: true)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Continue as Guest'), findsOneWidget);
    expect(find.text('Flutter Demo Home Page'), findsNothing);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('persists consent and opens scanner entry', (
    WidgetTester tester,
  ) async {
    final repository = _FakeConsentRepository(accepted: false);
    await tester.pumpWidget(ResQMeApp(consentRepository: repository));
    await tester.pumpAndSettle();

    expect(find.text('Accept & continue'), findsOneWidget);
    await tester.scrollUntilVisible(find.byType(Checkbox), 300);
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text('Accept & continue'));
    await tester.pumpAndSettle();

    expect(repository.accepted, isTrue);
    expect(find.text('Continue as Guest'), findsOneWidget);
  });

  testWidgets('waits for consent persistence before opening scanner entry', (
    WidgetTester tester,
  ) async {
    final persistence = Completer<void>();
    final repository = _FakeConsentRepository(
      accepted: false,
      acceptanceCompleter: persistence,
    );
    await tester.pumpWidget(ResQMeApp(consentRepository: repository));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.byType(Checkbox), 300);
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text('Accept & continue'));
    await tester.pump();

    expect(repository.accepted, isFalse);
    expect(find.text('Continue as Guest'), findsNothing);

    persistence.complete();
    await tester.pumpAndSettle();

    expect(repository.accepted, isTrue);
    expect(find.text('Continue as Guest'), findsOneWidget);
  });
}
