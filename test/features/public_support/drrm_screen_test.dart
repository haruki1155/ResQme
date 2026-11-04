import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqme/app/resqme_app.dart';
import 'package:resqme/features/welcome/data/consent_repository.dart';

class R implements ConsentRepository {
  @override
  Future<void> acceptTerms() async {}

  @override
  Future<bool> hasAcceptedTerms() async => true;
}

void main() {
  testWidgets('shows searchable DRRM guidance', (t) async {
    await t.pumpWidget(ResQMeApp(consentRepository: R()));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.text('DRRM instructions'), 250);
    await t.drag(find.byType(ListView), const Offset(0, -120));
    await t.pumpAndSettle();
    await t.tap(find.text('DRRM instructions'));
    await t.pumpAndSettle();
    expect(find.text('Disaster preparedness'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'Tsunami');
    await t.pump();
    expect(find.text('Tsunami'), findsWidgets);
  });
}
