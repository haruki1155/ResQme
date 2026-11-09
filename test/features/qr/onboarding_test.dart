import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqme/features/qr/services/tier1_qr_repository.dart';
import 'package:resqme/features/qr/screens/my_unverified_qr_screen.dart';
import 'package:resqme/features/registration/presentation/pilot_account_screen.dart';
import 'package:resqme/features/registration/models/student_registration_profile.dart';
import 'package:resqme/features/medical/services/synthetic_medical_repository.dart';
import 'package:resqme/features/medical/services/medical_completion_repository.dart';
import '../medical/synthetic_medical_test.dart' show FakePilotClient;
import 'dart:async';
import 'package:resqme/app/resqme_app.dart';
import 'package:resqme/features/welcome/data/consent_repository.dart';
import 'package:resqme/features/registration/services/firebase_student_registration_repository.dart';
import '../registration/firebase_student_registration_repository_test.dart'
    show FakeRegistrationClient;

class _Consent implements ConsentRepository {
  @override
  Future<bool> hasAcceptedTerms() async => true;
  @override
  Future<void> acceptTerms() async {}
}

class _RegisteringClient extends FakeRegistrationClient {
  _RegisteringClient(this.pilot, this.changes);
  final FakePilotClient pilot;
  final StreamController<void> changes;
  int reads = 0;
  @override
  Future<Map<String, dynamic>?> readOwnProfile() async {
    reads++;
    return super.readOwnProfile();
  }

  @override
  Future<void> createAccount(String email, String password) async {
    await super.createAccount(email, password);
    pilot.uid = 'synthetic-uid';
    changes.add(null);
  }

  @override
  Future<void> signOut() async {
    await super.signOut();
    pilot.uid = null;
    changes.add(null);
  }
}

void main() {
  testWidgets('QA test save leads to the same QR on restart', (tester) async {
    final client = FakePilotClient();
    final profile = StudentRegistrationProfile.fromFirestore({
      'schemaVersion': 1,
      'fullName': 'Synthetic Student',
      'ageYearsAtRegistration': 17,
      'status': 'pending_guardian',
    });
    Widget app() => MaterialApp(
      home: PilotAccountScreen(
        profile: profile,
        openMedical: client.qr == null,
        medical: SyntheticMedicalRepository(client),
        qr: Tier1QrRepository(client),
        onPublicDashboard: () {},
        onSignOut: () {},
      ),
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    for (final label in ['Medical conditions', 'Allergies']) {
      await tester.ensureVisible(find.text(label));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Unknown').last);
      await tester.pumpAndSettle();
    }
    for (final finder in [
      find.byType(CheckboxListTile).at(0),
      find.byType(CheckboxListTile).at(1),
    ]) {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(find.text('Save Test Record'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Test Record'));
    await tester.pumpAndSettle();
    expect(client.medical!['medicalStatus'], 'completed_synthetic');
    expect(find.text('Active after school approval'), findsOneWidget);
    final qr = client.qr!['payload'];
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('Medical Information (Optional)'), findsNothing);
    expect(client.qr!['payload'], qr);
  });
  testWidgets(
    'new registration is routed to required medical completion before QR',
    (tester) async {
      final changes = StreamController<void>.broadcast();
      addTearDown(changes.close);
      final pilot = FakePilotClient()..uid = null;
      final registration = _RegisteringClient(pilot, changes);
      await tester.pumpWidget(
        ResQMeApp(
          consentRepository: _Consent(),
          registrationRepository: FirebaseStudentRegistrationRepository(
            registration,
          ),
          medicalRepository: SyntheticMedicalRepository(pilot),
          medicalCompletionRepository: MedicalCompletionRepository(pilot),
          qrRepository: Tier1QrRepository(pilot),
          authChanges: changes.stream,
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Register'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Register'));
      await tester.pumpAndSettle();
      for (final entry in {
        'Full name': 'Synthetic Student',
        'Age (years)': '17',
        'Email': 'synthetic@example.test',
        'Password': 'secret-password',
        'Confirm password': 'secret-password',
      }.entries) {
        final field = find.widgetWithText(TextFormField, entry.key);
        await tester.ensureVisible(field);
        await tester.enterText(field, entry.value);
      }
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Create account').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create account').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agree & Create Account'));
      await tester.pumpAndSettle();
      expect(find.text('Required before QR activation'), findsOneWidget);
      expect(find.text('Skip for now'), findsNothing);
      expect(find.text('My ResQMe QR'), findsNothing);
      expect(registration.creates, 1);
      expect(pilot.medical, null);
    },
  );
  test(
    'QR repository restores existing reference and rejects malformed payload',
    () async {
      final client = FakePilotClient();
      final repo = Tier1QrRepository(client);
      final payload = await repo.ensureMine();
      expect(payload, startsWith('resqme:v1:'));
      expect((await repo.ensureMine()), payload);
      expect(client.lastPayload, isEmpty);
      client.error = 'permission-denied';
      await expectLater(repo.loadMine(), throwsA(isA<QrFailure>()));
    },
  );
  testWidgets('pending account must complete medical before QR activation', (
    tester,
  ) async {
    final client = FakePilotClient();
    final profile = StudentRegistrationProfile.fromFirestore({
      'schemaVersion': 1,
      'fullName': 'Synthetic Student',
      'ageYearsAtRegistration': 17,
      'status': 'pending_guardian',
    });
    await tester.pumpWidget(
      MaterialApp(
        home: PilotAccountScreen(
          profile: profile,
          openMedical: true,
          medical: SyntheticMedicalRepository(client),
          completion: MedicalCompletionRepository(client),
          qr: Tier1QrRepository(client),
          onPublicDashboard: () {},
          onSignOut: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Required before QR activation'), findsOneWidget);
    expect(find.text('Skip for now'), findsNothing);
    expect(find.text('My ResQMe QR'), findsNothing);
  });
  testWidgets(
    'QR failure offers retry without registration or medical writes',
    (tester) async {
      final client = FakePilotClient()..error = 'unavailable';
      await tester.pumpWidget(
        MaterialApp(
          home: MyUnverifiedQrScreen(
            repository: Tier1QrRepository(client),
            onDashboard: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Retry QR'), findsOneWidget);
      expect(
        find.textContaining('Your QR is not available yet'),
        findsOneWidget,
      );
      client.error = null;
      await tester.tap(find.text('Retry QR'));
      await tester.pumpAndSettle();
      expect(find.text('Active after school approval'), findsOneWidget);
    },
  );
}
