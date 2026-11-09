import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqme/app/app_routes.dart';
import 'package:resqme/features/welcome/data/consent_repository.dart';
import 'package:resqme/features/welcome/presentation/splash_screen.dart';

class _PendingConsent implements ConsentRepository {
  final result = Completer<bool>();
  @override
  Future<bool> hasAcceptedTerms() => result.future;
  @override
  Future<void> acceptTerms() async {}
}

void main() {
  for (final accepted in [false, true]) {
    testWidgets(
      'branded splash waits for consent then opens ${accepted ? 'entry' : 'terms'}',
      (tester) async {
        final consent = _PendingConsent();
        await tester.pumpWidget(
          MaterialApp(
            home: SplashScreen(consentRepository: consent),
            routes: {
              AppRoutes.entry: (_) =>
                  const Scaffold(body: Text('Entry destination')),
              AppRoutes.terms: (_) =>
                  const Scaffold(body: Text('Terms destination')),
            },
          ),
        );
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel('ResQme logo'), findsOneWidget);
        expect(find.text('EMERGENCY IDENTITY'), findsOneWidget);
        expect(find.text('Entry destination'), findsNothing);
        expect(find.text('Terms destination'), findsNothing);
        consent.result.complete(accepted);
        await tester.pumpAndSettle();
        expect(
          find.text(accepted ? 'Entry destination' : 'Terms destination'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
