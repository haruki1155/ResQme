import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:resqme/app/resqme_app.dart';
import 'package:resqme/features/medical/services/synthetic_medical_repository.dart';
import 'package:resqme/features/medical/services/medical_completion_repository.dart';
import 'package:resqme/features/qr/presentation/qr_scanner_screen.dart';
import 'package:resqme/features/qr/services/tier1_qr_repository.dart';
import 'package:resqme/features/registration/services/firebase_student_registration_repository.dart';
import 'package:resqme/features/welcome/data/consent_repository.dart';
import '../features/medical/synthetic_medical_test.dart' show FakePilotClient;
import '../features/registration/firebase_student_registration_repository_test.dart'
    show FakeRegistrationClient;

class Consent implements ConsentRepository {
  Consent({this.accepted = true});
  bool accepted;
  @override
  Future<bool> hasAcceptedTerms() async => accepted;
  @override
  Future<void> acceptTerms() async {
    accepted = true;
  }
}

class AccountClient extends FakeRegistrationClient {
  AccountClient(this.pilot);
  final FakePilotClient pilot;
  bool failSignOut = false;
  @override
  Future<void> signIn(String email, String password) async {
    await super.signIn(email, password);
    pilot.uid = 'synthetic-uid';
  }

  @override
  Future<void> signOut() async {
    if (failSignOut) throw StateError('synthetic failure');
    await super.signOut();
    pilot.uid = null;
  }
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      disableAnimations: true,
    );
  });
  tearDown(
    () => TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher
        .clearAccessibilityFeaturesTestValue(),
  );

  Future<void> open(
    WidgetTester tester, {
    bool accepted = true,
    AccountClient? account,
    FakePilotClient? pilot,
  }) async {
    await tester.pumpWidget(
      ResQMeApp(
        consentRepository: Consent(accepted: accepted),
        registrationRepository: account == null
            ? null
            : FirebaseStudentRegistrationRepository(account),
        medicalRepository: pilot == null
            ? null
            : SyntheticMedicalRepository(pilot),
        medicalCompletionRepository: pilot == null
            ? null
            : MedicalCompletionRepository(pilot),
        qrRepository: pilot == null ? null : Tier1QrRepository(pilot),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('entry actions remain usable with narrow screen and large text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    await open(tester);
    await tester.ensureVisible(find.text('Register'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Go to Dashboard as Guest'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Go to Dashboard as Guest'));
    await tester.pumpAndSettle();
    expect(find.text('Ready when it matters.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Scan another QR preserves signed-in account and own credential',
    (tester) async {
      final pilot = FakePilotClient();
      final account = AccountClient(pilot)
        ..currentEmail = 'synthetic@example.test';
      account.profile = {
        ...account.profile!,
        'medicalStatus': 'complete',
        'schoolApprovalStatus': 'approved',
      };
      await open(tester, account: account, pilot: pilot);
      await tester.ensureVisible(find.text('Go to Dashboard as Guest'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Go to Dashboard as Guest'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Go to Dashboard as Guest'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.byTooltip('Profile'), 250);
      await tester.tap(find.byTooltip('Profile'));
      await tester.pumpAndSettle();
      final ownQr = pilot.qr!['payload'];
      await tester.ensureVisible(find.text('Scan another QR'));
      await tester.tap(find.text('Scan another QR'));
      await tester.pumpAndSettle();
      tester
          .state<QrScannerScreenState>(find.byType(QrScannerScreen))
          .handleBarcodeDetected(
            const BarcodeCapture(
              barcodes: [
                Barcode(
                  rawValue:
                      'resqme:v1:BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBA',
                ),
              ],
            ),
          );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Back to Dashboard'));
      await tester.pumpAndSettle();
      expect(account.currentEmail, 'synthetic@example.test');
      expect(pilot.qr!['payload'], ownQr);
      expect(find.text('Ready when it matters.'), findsOneWidget);
    },
  );

  testWidgets(
    'accepted terms open three entry actions without starting camera',
    (tester) async {
      await open(tester);
      for (final label in [
        'Enable Camera',
        'Go to Dashboard as Guest',
        'Register',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('Sign In'), findsNothing);
      expect(find.byType(MobileScanner), findsNothing);
      await tester.ensureVisible(find.text('Go to Dashboard as Guest'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Go to Dashboard as Guest'));
      await tester.pumpAndSettle();
      expect(find.text('Ready when it matters.'), findsOneWidget);
    },
  );

  testWidgets('terms acceptance opens scanner entry instead of dashboard', (
    tester,
  ) async {
    await open(tester, accepted: false);
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text('Accept & continue'));
    await tester.pumpAndSettle();
    expect(find.text('Go to Dashboard as Guest'), findsOneWidget);
    expect(find.text('Ready when it matters.'), findsNothing);
  });

  testWidgets(
    'Register opens registration directly; dashboard Profile opens credentials',
    (tester) async {
      final pilot = FakePilotClient()..uid = null;
      final account = AccountClient(pilot);
      await open(tester, account: account, pilot: pilot);
      await tester.ensureVisible(find.text('Register'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Register'));
      await tester.pumpAndSettle();
      expect(find.text('Create student account'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Go to Dashboard as Guest'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Go to Dashboard as Guest'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Go to Dashboard as Guest'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.byTooltip('Profile'), 250);
      await tester.tap(find.byTooltip('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome to ResQMe'), findsOneWidget);
      expect(find.text('Forgot password'), findsOneWidget);
    },
  );

  testWidgets('pending sign-in requires medical and school approval before QR', (
    tester,
  ) async {
    final pilot = FakePilotClient()..uid = null;
    await open(tester, account: AccountClient(pilot), pilot: pilot);
    await tester.ensureVisible(find.text('Go to Dashboard as Guest'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Go to Dashboard as Guest'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byTooltip('Profile'), 250);
    await tester.tap(find.byTooltip('Profile'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'synthetic@example.test',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'synthetic-password',
    );
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Medical information'), findsOneWidget);
    expect(find.text('Required before QR activation'), findsOneWidget);
    expect(find.text('Scan another QR'), findsNothing);
    expect(find.text('Logout'), findsNothing);
    expect(find.text('Registration status'), findsNothing);
    expect(find.text('Synthetic Student'), findsNothing);
    expect(pilot.qr, isNull);
  });

  for (final fails in [false, true]) {
    testWidgets('Profile shows own QR and logout failure=$fails is handled', (
      tester,
    ) async {
      final pilot = FakePilotClient();
      final account = AccountClient(pilot)
        ..currentEmail = 'synthetic@example.test'
        ..failSignOut = fails;
      account.profile = {
        ...account.profile!,
        'medicalStatus': 'complete',
        'schoolApprovalStatus': 'approved',
      };
      await open(tester, account: account, pilot: pilot);
      await tester.ensureVisible(find.text('Go to Dashboard as Guest'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Go to Dashboard as Guest'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.byTooltip('Profile'), 250);
      await tester.tap(find.byTooltip('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Medical Information (Optional)'), findsNothing);
      await tester.ensureVisible(find.text('Logout'));
      await tester.tap(find.text('Logout'));
      await tester.pumpAndSettle();
      expect(
        find.text('Go to Dashboard as Guest'),
        fails ? findsNothing : findsOneWidget,
      );
      if (fails) {
        expect(find.text('Unable to sign out. Please retry.'), findsOneWidget);
      }
      expect(account.currentEmail == null, !fails);
    });
  }

  testWidgets('camera runs in entry frame and stops before guest navigation', (
    tester,
  ) async {
    await open(tester);
    expect(find.byType(MobileScanner), findsNothing);
    await tester.tap(find.text('Enable Camera'));
    await tester.pumpAndSettle();
    expect(find.text('RESQME | QR ID'), findsOneWidget);
    expect(find.text('Disable Camera'), findsOneWidget);
    expect(find.byType(MobileScanner), findsOneWidget);
    expect(find.text('Scan QR'), findsNothing);
    await tester.ensureVisible(find.text('Go to Dashboard as Guest'));
    await tester.tap(find.text('Go to Dashboard as Guest'));
    await tester.pumpAndSettle();
    expect(find.byType(MobileScanner, skipOffstage: false), findsNothing);
    Navigator.of(tester.element(find.text('Ready when it matters.'))).pop();
    await tester.pumpAndSettle();
    expect(find.text('Enable Camera'), findsOneWidget);
    expect(find.byType(MobileScanner), findsNothing);
  });

  testWidgets('scan sweep animates only while camera is enabled', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: false);
    await open(tester);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.tap(find.text('Enable Camera'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.tap(find.text('Disable Camera'));
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('camera can be disabled without leaving entry', (tester) async {
    await open(tester);
    await tester.tap(find.text('Enable Camera'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Disable Camera'));
    await tester.pumpAndSettle();
    expect(find.text('RESQME | QR ID'), findsOneWidget);
    expect(find.byType(MobileScanner), findsNothing);
  });

  testWidgets('offline scan dashboard action reaches dashboard from entry', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Enable Camera'));
    await tester.pumpAndSettle();
    tester
        .state<QrScannerScreenState>(find.byType(QrScannerScreen))
        .handleBarcodeDetected(
          const BarcodeCapture(
            barcodes: [
              Barcode(
                rawValue:
                    'resqme:v1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
              ),
            ],
          ),
        );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Back to Dashboard'));
    await tester.pumpAndSettle();
    expect(find.text('Ready when it matters.'), findsOneWidget);
  });
}
