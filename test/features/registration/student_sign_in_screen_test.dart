import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqme/features/registration/screens/student_sign_in_screen.dart';
import 'package:resqme/features/registration/services/firebase_student_registration_repository.dart';
import 'firebase_student_registration_repository_test.dart'
    show FakeRegistrationClient;

void main() {
  testWidgets(
    'sign-in validates credentials, supports recovery and create-account navigation',
    (tester) async {
      final client = FakeRegistrationClient()..authError = 'invalid-credential';
      var signedIn = false;
      await tester.pumpWidget(
        MaterialApp(
          home: StudentSignInScreen(
            repository: FirebaseStudentRegistrationRepository(client),
            onSignedIn: () {
              signedIn = true;
            },
          ),
        ),
      );
      await tester.tap(find.text('Sign in').last);
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid email.'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'synthetic@example.test',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'secret-password',
      );
      await tester.tap(find.text('Sign in').last);
      await tester.pumpAndSettle();
      expect(
        find.text('Unable to sign in. Check your email and password.'),
        findsOneWidget,
      );
      expect(signedIn, false);
      await tester.ensureVisible(find.text('Forgot password'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Forgot password'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('If an account can receive recovery email'),
        findsOneWidget,
      );
      client.authError = null;
      await tester.ensureVisible(find.text('Sign in').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign in').last);
      await tester.pumpAndSettle();
      expect(signedIn, true);
      await tester.ensureVisible(find.text('Create account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();
      expect(find.text('Personal information'), findsOneWidget);
    },
  );
}
