import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqme/features/registration/widgets/student_access_gate.dart';
import 'package:resqme/features/registration/services/firebase_student_registration_repository.dart';
import 'firebase_student_registration_repository_test.dart'
    show FakeRegistrationClient;

class _AuthEventClient extends FakeRegistrationClient {
  final changes = StreamController<void>.broadcast();
  final finishSubmit = Completer<void>();
  @override
  Future<void> createAccount(String email, String password) async {
    await super.createAccount(email, password);
    changes.add(null);
  }

  @override
  Future<void> submit(Map<String, dynamic> data) async {
    await super.submit(data);
    await finishSubmit.future;
  }
}

void main() {
  testWidgets('authentication change removes expanded private details', (
    tester,
  ) async {
    final changes = StreamController<void>.broadcast();
    addTearDown(changes.close);
    final client = FakeRegistrationClient()
      ..currentEmail = 'synthetic@example.test';
    await tester.pumpWidget(
      MaterialApp(
        home: StudentAccessGate(
          repository: FirebaseStudentRegistrationRepository(client),
          authChanges: changes.stream,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review submitted details'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Synthetic Student'), findsOneWidget);
    client.currentEmail = null;
    changes.add(null);
    await tester.pumpAndSettle();
    expect(find.textContaining('Synthetic Student'), findsNothing);
    expect(find.text('Sign in'), findsOneWidget);
  });
  testWidgets(
    'Auth creation can replace sign-in while registration route finishes',
    (tester) async {
      final client = _AuthEventClient();
      addTearDown(client.changes.close);
      await tester.pumpWidget(
        MaterialApp(
          home: StudentAccessGate(
            repository: FirebaseStudentRegistrationRepository(client),
            authChanges: client.changes.stream,
          ),
        ),
      );
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
      client.finishSubmit.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), null);
      expect(
        find.text('Registration received - pending school review'),
        findsOneWidget,
      );
    },
  );
  for (final status in [
    null,
    'pending_review',
    'pending_guardian',
    'approved',
    'rejected',
    'deactivated',
    'unknown',
  ]) {
    testWidgets('gate restricts $status and never offers QR or Tier 2', (
      tester,
    ) async {
      final client = FakeRegistrationClient();
      if (status != null) {
        client.currentEmail = 'synthetic@example.test';
        client.profile = {...client.profile!, 'status': status};
      }
      await tester.pumpWidget(
        MaterialApp(
          home: StudentAccessGate(
            repository: FirebaseStudentRegistrationRepository(client),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (status == null) {
        expect(find.text('Sign in'), findsOneWidget);
      } else if (status == 'pending_review') {
        expect(
          find.text('Registration received - pending school review'),
          findsOneWidget,
        );
      } else if (status == 'pending_guardian') {
        expect(
          find.text('Registration received - pending school review'),
          findsOneWidget,
        );
      } else {
        expect(find.text('Registration unavailable'), findsOneWidget);
      }
      expect(find.text('My QR'), findsNothing);
      expect(find.text('Tier 2'), findsNothing);
      expect(find.text('Synthetic Student'), findsNothing);
    });
  }
  testWidgets('missing profile exposes explicit recovery and sign out', (
    tester,
  ) async {
    final client = FakeRegistrationClient()
      ..currentEmail = 'synthetic@example.test'
      ..profile = null;
    await tester.pumpWidget(
      MaterialApp(
        routes: {'/entry': (_) => const Scaffold(body: Text('Scanner Entry'))},
        home: StudentAccessGate(
          repository: FirebaseStudentRegistrationRepository(client),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Complete registration'), findsOneWidget);
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Scanner Entry'), findsOneWidget);
  });
}
