import 'package:flutter_test/flutter_test.dart';
import 'package:resqme/app/resqme_app.dart';
import 'package:resqme/features/welcome/data/consent_repository.dart';

class _FakeConsentRepository implements ConsentRepository {
  _FakeConsentRepository({required this.accepted});

  final bool accepted;

  @override
  Future<void> acceptTerms() async {}

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
}
