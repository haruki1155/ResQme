import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqme/features/medical/services/medical_completion_repository.dart';
import 'package:resqme/features/medical/services/synthetic_medical_repository.dart';
import 'package:resqme/features/qr/screens/my_unverified_qr_screen.dart';
import 'package:resqme/features/qr/services/tier1_qr_repository.dart';
import 'package:resqme/features/registration/models/registration_draft.dart';
import 'package:resqme/features/registration/models/student_registration_profile.dart';
import 'package:resqme/features/registration/presentation/pilot_account_screen.dart';
import 'package:resqme/features/registration/registration_validators.dart';
import 'package:resqme/features/registration/screens/create_student_account_screen.dart';
import 'package:resqme/features/registration/screens/registration_pending_screen.dart';
import 'package:resqme/features/registration/services/firebase_student_registration_repository.dart';
import '../medical/synthetic_medical_test.dart' show FakePilotClient;
import 'firebase_student_registration_repository_test.dart'
    show FakeRegistrationClient;

class _RecoveringRegistrationClient extends FakeRegistrationClient
    implements RosterClaimRegistrationClient {
  int claimCalls = 0;
  @override
  Future<Map<String, dynamic>> claimMyRosterVerification({
    required String fullName,
    required String birthDate,
    required String lrn,
    required String enrollmentCode,
  }) async {
    claimCalls++;
    profile = {
      ...profile!,
      'fullName': fullName,
      'ageYearsAtRegistration': 21,
      'status': 'pending_review',
      'schoolApprovalStatus': 'approved',
      'schoolAssignmentStatus': 'assigned',
      'schoolVerificationOutcome': 'verified',
    };
    return {
      'verified': true,
      'schoolApprovalStatus': 'approved',
      'schoolVerificationOutcome': 'verified',
    };
  }
}

void main() {
  test('validateBirthDate accepts strict YYYY-MM-DD and computes accurate age', () {
    expect(validateBirthDate('2008-05-10', required: true), isNull);
    expect(validateBirthDate('2010-02-29', required: true), isNotNull);
    expect(validateBirthDate('2099-01-01', required: true), isNotNull);
    expect(validateBirthDate('05/10/2008', required: true), isNotNull);
    expect(computeAgeYearsFromBirthDate('2006-01-15', now: DateTime.utc(2026, 11, 25)), 20);
    expect(computeAgeYearsFromBirthDate('2010-12-30', now: DateTime.utc(2026, 11, 25)), 15);

    const draft = RegistrationDraft(
      fullName: 'Juan Santos Dela Cruz',
      ageYears: 16,
      birthDate: '2010-05-10',
      email: 'juan@example.test',
      password: 'secret-password',
      lrn: '009987654321',
      enrollmentCode: 'enroll-minor-code-0001',
    );
    final payload = draft.toProfilePayload();
    expect(payload['birthDate'], '2010-05-10');
    expect(payload['lrn'], '009987654321');
    expect(payload['enrollmentCode'], 'ENROLL-MINOR-CODE-0001');
  });

  testWidgets(
      'CreateStudentAccountScreen auto-calculates age from Birth date (YYYY-MM-DD) and submits birthDate to backend',
      (tester) async {
    final client = FakeRegistrationClient();
    client.profile = {
      'schemaVersion': 1,
      'fullName': 'Juan Santos Dela Cruz',
      'ageYearsAtRegistration': 19,
      'status': 'pending_review',
      'schoolApprovalStatus': 'approved',
      'schoolAssignmentStatus': 'assigned',
      'schoolVerificationOutcome': 'verified',
      'medicalStatus': 'not_started',
      'medicalRevision': 0,
    };

    var registered = false;
    await tester.pumpWidget(
      MaterialApp(
        home: CreateStudentAccountScreen(
          repository: FirebaseStudentRegistrationRepository(client),
          onRegistered: () => registered = true,
        ),
      ),
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Full name'),
      'Juan Santos Dela Cruz',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Birth date (YYYY-MM-DD)'),
      '2007-05-10',
    );
    await tester.pump();

    await tester.enterText(
      find.widgetWithText(TextFormField, '12-digit LRN'),
      '009987654321',
    );
    await tester.enterText(
      find.widgetWithText(
        TextFormField,
        'Enrollment code (optional for manual review)',
      ),
      'ENROLL-ADULT-CODE-0001',
    );

    for (final entry in {
      'Email': 'juan@example.test',
      'Password': 'secret-password',
      'Confirm password': 'secret-password',
    }.entries) {
      final f = find.widgetWithText(TextFormField, entry.key);
      await tester.ensureVisible(f);
      await tester.enterText(f, entry.value);
    }

    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Create account').last);
    await tester.tap(find.text('Create account').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agree & Create Account'));
    await tester.pumpAndSettle();

    expect(registered, isTrue);
    expect(client.payload!['birthDate'], '2007-05-10');
    expect(client.payload!['lrn'], '009987654321');
    expect(client.payload!['enrollmentCode'], 'ENROLL-ADULT-CODE-0001');
  });

  testWidgets(
      'RegistrationPendingScreen reflects automatic school verification for adult and minor students',
      (tester) async {
    final verifiedMinor = StudentRegistrationProfile.fromFirestore({
      'schemaVersion': 1,
      'fullName': 'Juan Santos Dela Cruz',
      'ageYearsAtRegistration': 15,
      'status': 'pending_guardian',
      'schoolApprovalStatus': 'approved',
      'schoolAssignmentStatus': 'assigned',
      'schoolVerificationOutcome': 'verified',
    });

    await tester.pumpWidget(
      MaterialApp(
        home: RegistrationPendingScreen(
          profile: verifiedMinor,
          onRefreshStatus: () {},
          onPublicDashboard: () {},
          onSignOut: () {},
        ),
      ),
    );
    expect(
      find.textContaining('School enrollment verified'),
      findsOneWidget,
    );
    expect(find.textContaining('guardian authorization'), findsWidgets);
  });

  testWidgets(
      'PilotAccountScreen clearly surfaces School Enrollment Verified when approved before medical completion',
      (tester) async {
    final pilot = FakePilotClient();
    final verifiedAdult = StudentRegistrationProfile.fromFirestore({
      'schemaVersion': 1,
      'fullName': 'Mara Cruz Reyes',
      'ageYearsAtRegistration': 21,
      'status': 'pending_review',
      'schoolApprovalStatus': 'approved',
      'schoolAssignmentStatus': 'assigned',
      'schoolVerificationOutcome': 'verified',
      'medicalStatus': 'not_started',
      'medicalRevision': 0,
    });
    await tester.pumpWidget(
      MaterialApp(
        home: PilotAccountScreen(
          profile: verifiedAdult,
          medical: SyntheticMedicalRepository(pilot),
          completion: MedicalCompletionRepository(pilot),
          qr: Tier1QrRepository(pilot),
          onPublicDashboard: () {},
          onSignOut: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('School Enrollment Verified'), findsOneWidget);
    expect(find.textContaining('while school review is pending'), findsNothing);
    expect(find.text('Complete Medical Information'), findsOneWidget);
  });

  testWidgets(
      'CreateStudentAccountScreen offers Fix & Retry Verification when submitted enrollmentCode did not auto-approve',
      (tester) async {
    final client = _RecoveringRegistrationClient();
    var registered = false;
    await tester.pumpWidget(
      MaterialApp(
        home: CreateStudentAccountScreen(
          repository: FirebaseStudentRegistrationRepository(client),
          onRegistered: () => registered = true,
        ),
      ),
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Full name'),
      'Mara Cruz Reyes',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Birth date (YYYY-MM-DD)'),
      '2010-03-10',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '12-digit LRN'),
      '109900112233',
    );
    await tester.enterText(
      find.widgetWithText(
        TextFormField,
        'Enrollment code (optional for manual review)',
      ),
      'ENROLL-RECOVERY-CODE1',
    );
    for (final entry in {
      'Email': 'mara@example.test',
      'Password': 'secret-password',
      'Confirm password': 'secret-password',
    }.entries) {
      final f = find.widgetWithText(TextFormField, entry.key);
      await tester.ensureVisible(f);
      await tester.enterText(f, entry.value);
    }
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Create account').last);
    await tester.tap(find.text('Create account').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agree & Create Account'));
    await tester.pumpAndSettle();

    expect(find.text('Automatic Verification Did Not Match'), findsOneWidget);
    await tester.tap(find.text('Fix & Retry Verification'));
    await tester.pumpAndSettle();

    expect(find.text('Verify with Enrollment Code'), findsOneWidget);
    await tester.tap(find.text('Verify Enrollment'));
    await tester.pumpAndSettle();

    expect(client.claimCalls, 1);
    expect(registered, isTrue);
  });

  testWidgets(
      'MyUnverifiedQrScreen surfaces Verify with Enrollment Code button when pending',
      (tester) async {
    final pilot = FakePilotClient();
    var verifyTapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: MyUnverifiedQrScreen(
          repository: Tier1QrRepository(pilot),
          schoolApprovalStatus: 'pending',
          onDashboard: () {},
          onVerifyWithEnrollmentCode: () async {
            verifyTapped = true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pending School Verification'), findsOneWidget);
    await tester.tap(find.text('Verify with Enrollment Code'));
    await tester.pumpAndSettle();
    expect(verifyTapped, isTrue);
  });
}
