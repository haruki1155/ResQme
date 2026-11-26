import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqme/features/school/screens/school_review_screen.dart';
import 'package:resqme/features/school/services/school_review_repository.dart';

class _ReviewRepository implements SchoolReviewRepository {
  final sessions = StreamController<void>.broadcast();
  @override
  Stream<void> get sessionChanges => sessions.stream;

  String? uid;
  int searches = 0, approvals = 0, refreshes = 0;
  Completer<void>? approvalGate;
  Completer<SchoolReviewStatus>? refreshGate;
  bool refreshFails = false;
  @override
  Future<SchoolReviewStatus> refreshStatus(String studentUid) async {
    refreshes++;
    if (refreshFails) throw StateError('Unavailable');
    return refreshGate?.future ??
        Future.value(
          const SchoolReviewStatus(schoolStatus: 'approved', qrActive: false),
        );
  }

  @override
  String? get currentUid => uid;
  @override
  Future<void> signIn(String email, String password) async {
    uid = 'synthetic-reviewer-uid';
  }

  @override
  Future<SchoolReviewCandidate> loadCandidate(String studentUid) async {
    searches++;
    return SchoolReviewCandidate(
      studentUid: studentUid,
      fullName: 'Synthetic Student',
      schoolApprovalStatus: 'pending',
      schoolVerificationOutcome: 'manual_review',
    );
  }

  @override
  Future<SchoolReviewCandidate> loadCandidateByQr(String payload) =>
      loadCandidate('synthetic-student-uid');
  @override
  Future<void> approve(String studentUid, String requestId) async {
    approvals++;
    await approvalGate?.future;
  }

  @override
  Future<void> signOut() async {
    uid = null;
  }
}

void main() {
  Future<void> openReview(
    WidgetTester tester,
    _ReviewRepository repository,
  ) async {
    repository.uid = 'reviewer-one';
    await tester.pumpWidget(
      MaterialApp(
        home: SchoolReviewScreen(
          repository: repository,
          scanQr: (_) async => 'fixture',
        ),
      ),
    );
    await tester.tap(find.text('Scan Student QR'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review and approve'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approve').last);
    await tester.pump();
  }

  testWidgets('approval refresh confirms school separately from inactive QR', (
    tester,
  ) async {
    final repository = _ReviewRepository();
    await openReview(tester, repository);
    await tester.pumpAndSettle();
    expect(repository.refreshes, 1);
    expect(
      find.textContaining('School verification: approved'),
      findsOneWidget,
    );
    expect(
      find.textContaining('QR awaiting additional requirements'),
      findsOneWidget,
    );
    expect(find.text('QR ACTIVE'), findsNothing);
  });
  testWidgets('refresh failure does not claim active QR', (tester) async {
    final repository = _ReviewRepository()..refreshFails = true;
    await openReview(tester, repository);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Status confirmation unavailable'),
      findsOneWidget,
    );
    expect(find.text('QR ACTIVE'), findsNothing);
  });
  for (final phase in ['approval', 'refresh']) {
    testWidgets(
      'late $phase response after signout cannot restore information',
      (tester) async {
        final repository = _ReviewRepository();
        if (phase == 'approval') {
          repository.approvalGate = Completer<void>();
        } else {
          repository.refreshGate = Completer<SchoolReviewStatus>();
        }
        await openReview(tester, repository);
        await tester.tap(find.text('Sign out'));
        await tester.pumpAndSettle();
        repository.approvalGate?.complete();
        repository.refreshGate?.complete(
          const SchoolReviewStatus(schoolStatus: 'approved', qrActive: true),
        );
        await tester.pumpAndSettle();
        expect(
          find.textContaining('School verification: approved'),
          findsNothing,
        );
        expect(find.text('Synthetic Student'), findsNothing);
        expect(find.text('QR ACTIVE'), findsNothing);
      },
    );
  }

  for (final phase in ['approval', 'refresh']) {
    for (final action in [
      'account switch',
      'navigate away',
      'another student',
    ]) {
      testWidgets('late $phase cannot restore data after $action', (
        tester,
      ) async {
        final repository = _ReviewRepository();
        if (phase == 'approval') {
          repository.approvalGate = Completer<void>();
        } else {
          repository.refreshGate = Completer<SchoolReviewStatus>();
        }
        await openReview(tester, repository);
        if (action == 'navigate away') {
          await tester.pumpWidget(
            const MaterialApp(home: Text('Other screen')),
          );
        } else {
          repository.uid = 'reviewer-two';
          repository.sessions.add(null);
          await tester.pump();
          if (action == 'another student') {
            await tester.tap(find.text('Scan Student QR'));
            await tester.pumpAndSettle();
          }
        }
        repository.approvalGate?.complete();
        repository.refreshGate?.complete(
          const SchoolReviewStatus(schoolStatus: 'approved', qrActive: true),
        );
        await tester.pumpAndSettle();
        expect(find.text('QR ACTIVE'), findsNothing);
        expect(
          find.textContaining('School verification: approved'),
          findsNothing,
        );
        if (action != 'another student') {
          expect(find.text('Synthetic Student'), findsNothing);
        } else {
          expect(find.text('Review and approve'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets(
    'scanner cancellation performs no lookup; repeated scans each lookup once',
    (tester) async {
      final repository = _ReviewRepository()..uid = 'synthetic-reviewer';
      var scans = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: SchoolReviewScreen(
            repository: repository,
            scanQr: (_) async =>
                ++scans == 1 ? null : 'resqme:v1:fictional-fixture',
          ),
        ),
      );
      await tester.tap(find.text('Scan Student QR'));
      await tester.pumpAndSettle();
      expect(repository.searches, 0);
      expect(repository.approvals, 0);
      for (var i = 1; i <= 2; i++) {
        await tester.tap(find.text('Scan Student QR'));
        await tester.pumpAndSettle();
        expect(repository.searches, i);
        expect(repository.approvals, 0);
      }
    },
  );
  testWidgets(
    'reviewer sign-in gates candidate lookup and approval confirmation',
    (tester) async {
      final repository = _ReviewRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: SchoolReviewScreen(
            repository: repository,
            scanQr: (_) async => 'resqme:v1:fictional-fixture',
          ),
        ),
      );
      expect(
        find.text(
          'School reviewer access is limited to accounts provisioned by an authorized school operator.',
        ),
        findsOneWidget,
      );
      expect(find.text('Student review reference'), findsNothing);
      await tester.enterText(
        find.widgetWithText(TextField, 'Reviewer email'),
        'reviewer@example.test',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Password'),
        'synthetic-password',
      );
      await tester.tap(find.text('Sign in as reviewer'));
      await tester.pumpAndSettle();
      expect(find.text('Student review reference'), findsNothing);
      expect(find.text('Scan Student QR'), findsOneWidget);
      await tester.tap(find.text('Scan Student QR'));
      await tester.pumpAndSettle();
      expect(repository.searches, 1);
      expect(find.text('Synthetic Student'), findsOneWidget);
      expect(find.text('Review and approve'), findsOneWidget);
      await tester.tap(find.text('Review and approve'));
      await tester.pumpAndSettle();
      expect(repository.approvals, 0);
      await tester.tap(find.text('Approve').last);
      await tester.pumpAndSettle();
      expect(repository.approvals, 1);
      expect(repository.refreshes, 1);
      expect(
        find.textContaining('School verification: approved'),
        findsOneWidget,
      );
      expect(
        find.textContaining('QR awaiting additional requirements'),
        findsOneWidget,
      );
    },
  );
}
