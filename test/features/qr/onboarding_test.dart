import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqme/features/qr/services/tier1_qr_repository.dart';
import 'package:resqme/features/qr/screens/my_unverified_qr_screen.dart';
import 'package:resqme/features/registration/presentation/pilot_account_screen.dart';
import 'package:resqme/features/registration/models/student_registration_profile.dart';
import 'package:resqme/features/medical/services/synthetic_medical_repository.dart';
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
  int reads=0;
  @override Future<Map<String,dynamic>?> readOwnProfile() async {reads++;return super.readOwnProfile();}
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
  testWidgets('registration status action reloads trusted profile', (tester)async{
    final changes=StreamController<void>.broadcast();addTearDown(changes.close);
    final pilot=FakePilotClient()..qr={'payload':'resqme:v1:${'A'*43}','verificationStatus':'unverified'};
    final registration=_RegisteringClient(pilot,changes)..currentEmail='synthetic@example.test';
    await tester.pumpWidget(ResQMeApp(consentRepository:_Consent(),registrationRepository:FirebaseStudentRegistrationRepository(registration),medicalRepository:SyntheticMedicalRepository(pilot),qrRepository:Tier1QrRepository(pilot),authChanges:changes.stream));
    await tester.pumpAndSettle();await tester.ensureVisible(find.text('My Account / My QR'));await tester.pumpAndSettle();await tester.tap(find.text('My Account / My QR'));await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Registration status'));await tester.pumpAndSettle();await tester.tap(find.text('Registration status'));await tester.pumpAndSettle();
    final before=registration.reads;
    await tester.ensureVisible(find.text('View registration status'));await tester.pumpAndSettle();await tester.tap(find.text('View registration status'));await tester.pumpAndSettle();
    expect(registration.reads,greaterThan(before));
  });
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
    expect(
      find.text('UNVERIFIED — not proof of school enrollment'),
      findsOneWidget,
    );
    final qr = client.qr!['payload'];
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('Medical Information (Optional)'), findsNothing);
    expect(client.qr!['payload'], qr);
  });
  testWidgets(
    'guest registers, skips, views QR and returns to public dashboard',
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
          qrRepository: Tier1QrRepository(pilot),
          authChanges: changes.stream,
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.text('Student Account — Sign in / Register'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Student Account — Sign in / Register'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Create account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create account'));
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
      expect(find.text('Medical Information (Optional)'), findsOneWidget);
      await tester.ensureVisible(find.text('Skip for now'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skip for now'));
      await tester.pumpAndSettle();
      expect(
        find.text('UNVERIFIED — not proof of school enrollment'),
        findsOneWidget,
      );
      expect(registration.creates, 1);
      expect(pilot.medical, null);
      await tester.ensureVisible(find.text('Go to Dashboard'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Go to Dashboard'));
      await tester.pumpAndSettle();
      expect(find.text('Ready when it matters.'), findsOneWidget);
      expect(find.text('Finish Medical Record'), findsOneWidget);
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
      client.qr = {
        'payload': 'uid-private',
        'verificationStatus': 'unverified',
      };
      await expectLater(repo.loadMine(), throwsA(isA<QrFailure>()));
    },
  );
  testWidgets(
    'pending account skips medical without writes then sees QR and dashboard action',
    (tester) async {
      final client = FakePilotClient();
      var dashboard = 0;
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
            medical: SyntheticMedicalRepository(client),
            qr: Tier1QrRepository(client),
            onPublicDashboard: () {
              dashboard++;
            },
            onSignOut: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Medical Information (Optional)'), findsOneWidget);
      await tester.ensureVisible(find.text('Skip for now'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skip for now'));
      await tester.pumpAndSettle();
      expect(
        find.text('UNVERIFIED — not proof of school enrollment'),
        findsOneWidget,
      );
      expect(client.medical, null);
      expect(client.writes, 1);
      await tester.ensureVisible(find.text('Go to Dashboard'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Go to Dashboard'));
      expect(dashboard, 1);
    },
  );
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
      expect(find.textContaining('Unable to load'), findsOneWidget);
      client.error = null;
      await tester.tap(find.text('Retry QR'));
      await tester.pumpAndSettle();
      expect(
        find.text('UNVERIFIED — not proof of school enrollment'),
        findsOneWidget,
      );
    },
  );
}
