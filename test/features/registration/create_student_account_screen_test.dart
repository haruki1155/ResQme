import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqme/features/registration/screens/create_student_account_screen.dart';
import 'package:resqme/features/registration/widgets/registration_privacy_dialog.dart';
import 'package:resqme/features/registration/services/firebase_student_registration_repository.dart';
import 'firebase_student_registration_repository_test.dart'
    show FakeRegistrationClient;

void main() {
  for (final accept in [false, true]) {
    testWidgets(
      'valid form ${accept ? 'accepts once' : 'declines without writes'}',
      (tester) async {
        final client = FakeRegistrationClient();
        var completed = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: CreateStudentAccountScreen(
              repository: FirebaseStudentRegistrationRepository(client),
              onRegistered: () {
                completed++;
              },
            ),
          ),
        );
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
        expect(client.creates, 0);
        if (accept) {
          await tester.ensureVisible(find.byType(CheckboxListTile));
          await tester.tap(find.byType(CheckboxListTile));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Agree & Create Account'));
        } else {
          await tester.tap(find.text('Decline'));
        }
        await tester.pumpAndSettle();
        expect(client.creates, accept ? 1 : 0);
        expect(completed, accept ? 1 : 0);
      },
    );
  }
  testWidgets('privacy checkbox is unchecked and decline never registers', (
    tester,
  ) async {
    var accepted = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RegistrationPrivacyDialog(
            ageYears: 17,
            onAccept: () {
              accepted = true;
            },
            onDecline: () {},
          ),
        ),
      ),
    );
    expect(
      find.text('Data Privacy & Registration Authorization'),
      findsOneWidget,
    );
    expect(
      find.text(registrationPendingExplanation),
      findsOneWidget,
    );
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      false,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Agree & Create Account'),
          )
          .onPressed,
      null,
    );
    await tester.ensureVisible(find.text('Review Privacy Notice'));
    await tester.tap(find.text('Review Privacy Notice'));
    await tester.pumpAndSettle();
    expect(find.text('ResQMe Privacy Notice'), findsOneWidget);
    expect(find.textContaining('tier1-registration-v1'), findsWidgets);
    expect(accepted, false);
  });
  testWidgets(
    'form has approved groups, inline validation and no restricted inputs',
    (tester) async {
      final client = FakeRegistrationClient();
      await tester.pumpWidget(
        MaterialApp(
          home: CreateStudentAccountScreen(
            repository: FirebaseStudentRegistrationRepository(client),
            onRegistered: () {},
          ),
        ),
      );
      expect(find.text('Personal information'), findsOneWidget);
      expect(find.text('Emergency contacts (optional)'), findsOneWidget);
      expect(find.text('Account credentials'), findsOneWidget);
      expect(find.text('LRN'), findsNothing);
      expect(find.text('Student ID'), findsNothing);
      await tester.ensureVisible(find.text('Create account').last);
      await tester.tap(find.text('Create account').last);
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid email.'), findsOneWidget);
      expect(client.creates, 0);
    },
  );
  for (final width in [320.0, 900.0]) {
    testWidgets('registration scrolls without overflow at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 800),
              textScaler: const TextScaler.linear(1.3),
            ),
            child: CreateStudentAccountScreen(
              repository: FirebaseStudentRegistrationRepository(
                FakeRegistrationClient(),
              ),
              onRegistered: () {},
            ),
          ),
        ),
      );
      await tester.ensureVisible(find.text('Create account').last);
      expect(tester.takeException(), null);
    });
  }
}
