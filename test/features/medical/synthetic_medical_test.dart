import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqme/core/data/pilot_client.dart';
import 'package:resqme/features/medical/models/synthetic_medical_draft.dart';
import 'package:resqme/features/medical/services/synthetic_medical_repository.dart';
import 'package:resqme/features/medical/screens/synthetic_medical_screen.dart';
import 'package:resqme/features/medical/widgets/finish_medical_record_reminder.dart';
import 'package:resqme/features/medical/widgets/account_dashboard_panel.dart';
import 'package:resqme/features/registration/services/firebase_student_registration_repository.dart';
import '../registration/firebase_student_registration_repository_test.dart'
    show FakeRegistrationClient;

class FakePilotClient implements PilotClient {
  @override
  String? uid = 'synthetic-uid';
  int writes = 0;
  String? error;
  Map<String, dynamic>? medical;
  Map<String, dynamic>? qr;
  Map<String, dynamic> profile = {
    'emergencyContacts': {
      'primary': {'fullName': null, 'relationship': null, 'phoneNumber': null},
    },
  };
  Map<String, dynamic>? lastPayload;
  @override
  Future<Map<String, dynamic>?> readMine(String collection) async =>
      collection == 'studentProfiles'
      ? profile
      : collection == 'studentQrCredentials'
      ? qr
      : medical;
  @override
  Future<Map<String, dynamic>> invoke(
    String name,
    Map<String, dynamic> payload,
  ) async {
    writes++;
    lastPayload = payload;
    if (error != null) {
      throw FirebaseException(plugin: 'functions', code: error!);
    }
    if (name == 'getMyStudentProfile') {
      return {
        'medicalStatus': 'not_started',
        'medicalRevision': 0,
        'schoolApprovalStatus': 'pending',
      };
    }
    if (name == 'completeMyMedicalRecord') {
      return {'medicalStatus': 'complete', 'revision': 1};
    }
    if (name == 'ensureMyTier1Qr' || name == 'replaceMyTier1Qr') {
      qr = {'payload': 'resqme:v1:${'A' * 43}', 'verificationStatus': 'active'};
      return qr!;
    }
    medical = {
      'schemaVersion': 1,
      'syntheticOnly': true,
      'medicalStatus': name.startsWith('clear')
          ? 'not_started'
          : 'completed_synthetic',
      'guardianAuthorizationStatus': 'not_verified',
      'revision': (payload['expectedRevision'] as int? ?? 0) + 1,
      'conditions': payload['conditions'],
      'allergies': payload['allergies'],
    };
    return {'revision': medical!['revision']};
  }

  @override
  Future<bool> resolveQr(String payload) async => false;
}

void main() {
  testWidgets(
    'dashboard refreshes medical completion after returning from account route',
    (tester) async {
      final client = FakePilotClient();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccountDashboardPanel(
              registration: FirebaseStudentRegistrationRepository(
                FakeRegistrationClient()
                  ..currentEmail = 'synthetic@example.test',
              ),
              medical: SyntheticMedicalRepository(client),
            ),
          ),
          routes: {
            '/profile': (context) => Scaffold(
              body: TextButton(
                onPressed: () {
                  client.medical = {
                    'schemaVersion': 1,
                    'syntheticOnly': true,
                    'medicalStatus': 'completed_synthetic',
                    'guardianAuthorizationStatus': 'not_verified',
                    'revision': 1,
                    'conditions': {'state': 'unknown', 'details': null},
                    'allergies': {'state': 'unknown', 'details': null},
                  };
                  Navigator.pop(context);
                },
                child: const Text('Synthetic save and return'),
              ),
            ),
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Finish now'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Synthetic save and return'));
      await tester.pumpAndSettle();
      expect(find.text('Finish Medical Record'), findsNothing);
      expect(find.text('View/Update Medical Record'), findsOneWidget);
    },
  );
  test('reminder snooze belongs to the signed-in session', () {
    final client = FakePilotClient();
    final repo = SyntheticMedicalRepository(client);
    expect(repo.reminderSnoozed, false);
    repo.snoozeReminder();
    expect(repo.reminderSnoozed, true);
    client.uid = null;
    repo.syncSession();
    client.uid = 'synthetic-uid';
    expect(repo.reminderSnoozed, false);
  });
  testWidgets('listed details validate and QA denial preserves Skip', (
    tester,
  ) async {
    final client = FakePilotClient()..error = 'permission-denied';
    var skipped = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: SyntheticMedicalScreen(
          repository: SyntheticMedicalRepository(client),
          isMinor: false,
          onContinue: () {
            skipped++;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final label in ['Medical conditions', 'Allergies']) {
      await tester.ensureVisible(find.text(label));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Listed (add details)').last);
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(find.text(syntheticAcknowledgment));
    await tester.pumpAndSettle();
    await tester.tap(find.text(syntheticAcknowledgment));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save Test Record'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Test Record'));
    await tester.pumpAndSettle();
    expect(find.text('Enter fictional test details.'), findsNWidgets(2));
    expect(client.writes, 0);
    for (final label in ['Medical conditions details', 'Allergies details']) {
      final field = find.widgetWithText(TextFormField, label);
      await tester.ensureVisible(field);
      await tester.enterText(field, 'Fictional test entry');
    }
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save Test Record'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Test Record'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Test record saving is not enabled'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Skip for now'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip for now'));
    expect(skipped, 1);
  });
  test(
    'medical repository preserves revision/request and maps QA denial safely',
    () async {
      final client = FakePilotClient();
      final repo = SyntheticMedicalRepository(client);
      expect((await repo.loadMine()).completed, false);
      client.error = 'permission-denied';
      await expectLater(
        repo.save(
          const SyntheticMedicalDraft(
            conditionsState: 'unknown',
            allergiesState: 'none_known',
            syntheticConfirmed: true,
          ),
          expectedRevision: 0,
          requestId: 'request-0001',
        ),
        throwsA(
          isA<MedicalFailure>().having(
            (e) => e.message,
            'message',
            contains('not enabled'),
          ),
        ),
      );
      expect(client.lastPayload!['requestId'], 'request-0001');
      expect(client.lastPayload!.containsKey('uid'), false);
    },
  );
  for (final minor in [true, false]) {
    testWidgets(
      'synthetic medical form minor=$minor supports skip without write and unchecked acknowledgment',
      (tester) async {
        final client = FakePilotClient();
        var skipped = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: SyntheticMedicalScreen(
              repository: SyntheticMedicalRepository(client),
              isMinor: minor,
              onContinue: () {
                skipped++;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(syntheticMedicalNotice), findsOneWidget);
        expect(
          find.text(minorSyntheticAcknowledgment),
          minor ? findsOneWidget : findsNothing,
        );
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Save Test Record'),
              )
              .onPressed,
          null,
        );
        await tester.ensureVisible(find.text('Skip for now'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Skip for now'));
        expect(skipped, 1);
        expect(client.writes, 0);
      },
    );
  }
  testWidgets('reminder is dismissible and absent for completed records', (
    tester,
  ) async {
    var dismissed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FinishMedicalRecordReminder(
            completed: false,
            onOpen: () {},
            onDismiss: () {
              dismissed = true;
            },
          ),
        ),
      ),
    );
    expect(find.text('Finish Medical Record'), findsOneWidget);
    await tester.tap(find.text('Later'));
    expect(dismissed, true);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FinishMedicalRecordReminder(
            completed: true,
            onOpen: () {},
            onDismiss: () {},
          ),
        ),
      ),
    );
    expect(find.text('Finish Medical Record'), findsNothing);
    expect(find.text('View/Update Medical Record'), findsOneWidget);
  });
}
