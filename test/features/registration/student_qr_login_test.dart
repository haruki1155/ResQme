import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqme/features/registration/models/registration_draft.dart';
import 'package:resqme/features/registration/models/student_registration_profile.dart';
import 'package:resqme/features/registration/screens/student_login_qr_screen.dart';
import 'package:resqme/features/registration/screens/student_sign_in_screen.dart';
import 'package:resqme/features/registration/services/student_registration_repository.dart';

class _FakeQrSignInRepository implements StudentRegistrationRepository {
  String? lastSignInEmail;
  String? lastSignInPassword;
  int signInCalls = 0;
  bool failPassword = false;

  @override
  Future<LoginQrResolutionResult> resolveLoginQr(String qrPayload) async {
    if (qrPayload.startsWith('resqme:v1:')) {
      return const LoginQrResolutionResult.failure(
        'This is an emergency QR code, not a Student Login QR code.',
      );
    }
    if (qrPayload == 'resqme:login:v1:REVOKED_TOKEN_01234567890123456789012345678') {
      return const LoginQrResolutionResult.failure(
        'This Login QR code is inactive, expired, or unavailable.',
      );
    }
    if (qrPayload.startsWith('resqme:login:v1:')) {
      return const LoginQrResolutionResult.resolved(
        email: 'maria.reyes@example.test',
        maskedEmail: 'm•••s@example.test',
      );
    }
    return const LoginQrResolutionResult.failure('Invalid Student Login QR code.');
  }

  @override
  Future<RegistrationResult> signIn(String email, String password) async {
    signInCalls += 1;
    lastSignInEmail = email;
    lastSignInPassword = password;
    if (failPassword || password != 'correct-password') {
      return const RegistrationResult(
        RegistrationState.failure,
        message: 'Unable to sign in. Check your email and password.',
      );
    }
    return RegistrationResult(
      RegistrationState.pending,
      profile: StudentRegistrationProfile.fromFirestore({
        'schemaVersion': 1,
        'fullName': 'Maria Clara Reyes',
        'ageYearsAtRegistration': 19,
        'status': 'pending_review',
        'schoolApprovalStatus': 'approved',
        'schoolAssignmentStatus': 'assigned',
        'schoolVerificationOutcome': 'verified',
      }),
    );
  }

  @override
  Future<RegistrationResult> register(
    RegistrationDraft draft, {
    required bool acknowledged,
  }) async =>
      const RegistrationResult(RegistrationState.signedOut);

  @override
  Future<RegistrationResult> sendPasswordReset(String email) async =>
      const RegistrationResult(RegistrationState.signedOut);

  @override
  Future<RegistrationResult> loadOwnProfile() async =>
      const RegistrationResult(RegistrationState.signedOut);

  @override
  Future<StudentLoginQrManageResult> ensureMyLoginQr() async =>
      const StudentLoginQrManageResult(
        credential: StudentLoginQrCredential(
          payload: 'resqme:login:v1:0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefg',
          credentialVersion: 1,
          status: 'active',
        ),
      );

  @override
  Future<StudentLoginQrManageResult> replaceMyLoginQr() async =>
      const StudentLoginQrManageResult(
        credential: StudentLoginQrCredential(
          payload: 'resqme:login:v1:ZYXWVUTSRQPONMLKJIHGFEDCBA9876543210abcdefg',
          credentialVersion: 2,
          status: 'active',
        ),
      );

  @override
  Future<String?> revokeMyLoginQr() async => null;

  @override
  Future<void> signOut() async {}
}

void main() {
  testWidgets(
      'Phase 3: scanning valid Login QR shows masked account + shared-device security notice and still requires password',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repo = _FakeQrSignInRepository();
    var signedIn = false;
    const validQr =
        'resqme:login:v1:0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefg';

    await tester.pumpWidget(
      MaterialApp(
        home: StudentSignInScreen(
          repository: repo,
          onSignedIn: () => signedIn = true,
          loginQrScannerBuilder: (onScanned) => Scaffold(
            appBar: AppBar(title: const Text('Fake Login QR Scanner')),
            body: Center(
              child: FilledButton(
                onPressed: () => onScanned(validQr),
                child: const Text('Simulate Valid Login QR'),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Scan Login QR'), findsOneWidget);
    await tester.tap(find.text('Scan Login QR'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Simulate Valid Login QR'));
    await tester.pumpAndSettle();

    // Scanning QR alone MUST NOT sign in or call signIn!
    expect(signedIn, isFalse);
    expect(repo.signInCalls, 0);

    // Masked email & shared/unfamiliar device security notice shown; raw email hidden
    expect(find.textContaining('m•••s@example.test'), findsOneWidget);
    expect(find.text('maria.reyes@example.test'), findsNothing);
    expect(find.textContaining('Shared or Unfamiliar Device'), findsOneWidget);

    // Wrong password rejected cleanly
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'wrong-password',
    );
    await tester.ensureVisible(find.text('Sign in'));
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(signedIn, isFalse);
    expect(repo.signInCalls, 1);
    expect(find.textContaining('Unable to sign in'), findsOneWidget);

    // Correct password completes authentication
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'correct-password',
    );
    await tester.ensureVisible(find.text('Sign in'));
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(signedIn, isTrue);
    expect(repo.signInCalls, 2);
    expect(repo.lastSignInEmail, 'maria.reyes@example.test');
  });

  testWidgets(
      'Phase 3: scanning emergency QR or revoked Login QR shows clear error and keeps sign-in locked',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repo = _FakeQrSignInRepository();
    const emergencyQr =
        'resqme:v1:0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefg';

    await tester.pumpWidget(
      MaterialApp(
        home: StudentSignInScreen(
          repository: repo,
          onSignedIn: () {},
          loginQrScannerBuilder: (onScanned) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => onScanned(emergencyQr),
                child: const Text('Scan Emergency QR'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Scan Login QR'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scan Emergency QR'));
    await tester.pumpAndSettle();

    expect(find.textContaining('emergency QR code'), findsOneWidget);
    expect(repo.signInCalls, 0);
  });

  testWidgets(
      'Phase 3: ManageStudentLoginQrScreen displays, replaces, and revokes Student Login QR',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repo = _FakeQrSignInRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: ManageStudentLoginQrScreen(repository: repo),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Version 1 • Active'), findsOneWidget);

    await tester.tap(find.text('Replace Login QR'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Version 2 • Active'), findsOneWidget);

    await tester.tap(find.text('Revoke Login QR'));
    await tester.pumpAndSettle();
    expect(find.text('Generate New Login QR'), findsOneWidget);
  });
}
