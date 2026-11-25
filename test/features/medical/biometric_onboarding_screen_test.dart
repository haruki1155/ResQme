import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqme/features/medical/screens/biometric_onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'tier2_test_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'resqme-tier2-device-adult-a': 'device_0123456789abcdef',
    });
    await SharedPreferences.getInstance();
  });

  testWidgets('shows Android enrollment instructions when no biometric enrolled',
      (tester) async {
    final f = Tier2Fixture();
    addTearDown(f.auth.changes.close);
    f.key.availability = 'biometric_not_enrolled';
    var continued = false;

    await tester.pumpWidget(
      MaterialApp(
        home: BiometricOnboardingScreen(
          repository: f.repository,
          onContinue: () => continued = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No strong biometric enrolled'), findsOneWidget);
    expect(find.text('Check Again'), findsOneWidget);
    await tester.tap(find.text('Continue to My QR for now'));
    expect(continued, isTrue);
  });

  testWidgets('shows hardware unavailable fallback when unsupported',
      (tester) async {
    final f = Tier2Fixture();
    addTearDown(f.auth.changes.close);
    f.key.availability = 'biometric_unsupported';

    await tester.pumpWidget(
      MaterialApp(
        home: BiometricOnboardingScreen(
          repository: f.repository,
          onContinue: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Biometric hardware unavailable'), findsOneWidget);
    expect(find.text('Retry hardware check'), findsOneWidget);
  });

  testWidgets('cancellation does not mark setup complete and allows retry',
      (tester) async {
    final f = Tier2Fixture();
    addTearDown(f.auth.changes.close);
    f.key.enrollFailure = PlatformException(code: 'cancelled');

    await tester.pumpWidget(
      MaterialApp(
        home: BiometricOnboardingScreen(
          repository: f.repository,
          onContinue: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'fictional-password');
    await tester.tap(find.text('Set Up Biometrics'));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pumpAndSettle();

    expect(f.functions.calls, ['issueStudentEnrollmentChallenge']);
    expect(find.text('Biometric confirmation cancelled.'), findsOneWidget);
    expect(find.text('Biometric Security Active'), findsNothing);

    // Retry succeeds when biometric proof completes.
    f.key.enrollFailure = null;
    await tester.tap(find.text('Set Up Biometrics'));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pumpAndSettle();

    expect(find.text('Biometric Security Active'), findsOneWidget);
    expect(f.functions.calls, [
      'issueStudentEnrollmentChallenge',
      'issueStudentEnrollmentChallenge',
      'enrollTier2Device',
    ]);
  });
}
