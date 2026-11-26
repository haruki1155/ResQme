import 'package:flutter/material.dart';
import 'package:resqme/app/app_routes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqme/app/resqme_app.dart';
import 'package:resqme/features/school/screens/school_review_screen.dart';
import 'package:resqme/features/school/services/school_review_repository.dart';
import 'package:resqme/features/welcome/data/consent_repository.dart';

class _Consent implements ConsentRepository {
  @override
  Future<bool> hasAcceptedTerms() async => true;
  @override
  Future<void> acceptTerms() async {}
}

class _Reviewer implements SchoolReviewRepository {
  @override
  Stream<void> get sessionChanges => const Stream.empty();

  @override
  Future<SchoolReviewStatus> refreshStatus(String studentUid) async =>
      throw StateError('Not authorized');

  @override
  String? currentUid;
  int lookups = 0, approvals = 0;
  @override
  Future<void> signIn(String email, String password) async {
    currentUid = 'fictional-unauthorized';
  }

  @override
  Future<void> signOut() async {
    currentUid = null;
  }

  @override
  Future<SchoolReviewCandidate> loadCandidate(String studentUid) async {
    lookups++;
    throw StateError('Server denied reviewer access');
  }

  @override
  Future<SchoolReviewCandidate> loadCandidateByQr(String payload) =>
      loadCandidate('synthetic-student-uid');
  @override
  Future<void> approve(String studentUid, String requestId) async {
    approvals++;
  }
}

void main() {
  testWidgets(
    'student app has no reviewer route even with repository configured',
    (tester) async {
      final reviewer = _Reviewer()..currentUid = 'student-account';
      await tester.pumpWidget(
        ResQMeApp(
          consentRepository: _Consent(),
          schoolReviewRepository: reviewer,
        ),
      );
      await tester.pumpAndSettle();
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.routes!.containsKey(AppRoutes.schoolReview), isFalse);
      expect(find.byType(SchoolReviewScreen), findsNothing);
      expect(reviewer.lookups, 0);
      expect(reviewer.approvals, 0);
    },
  );

  for (final configured in [true, false]) {
    testWidgets(
      'student entry and dashboard expose no staff navigation, configured=$configured',
      (tester) async {
        final reviewer = _Reviewer();
        await tester.pumpWidget(
          ResQMeApp(
            consentRepository: _Consent(),
            schoolReviewRepository: configured ? reviewer : null,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Register'), findsOneWidget);
        expect(find.text('School Reviewer Sign In'), findsNothing);
        await tester.ensureVisible(find.text('Go to Dashboard as Guest'));
        await tester.tap(find.text('Go to Dashboard as Guest'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.byTooltip('Profile'), 250);
        await tester.drag(find.byType(ListView), const Offset(0, -400));
        await tester.pumpAndSettle();
        expect(find.text('School Reviewer Sign In'), findsNothing);
        expect(find.byTooltip('Profile'), findsOneWidget);
        expect(find.byTooltip('Scan QR'), findsOneWidget);
        expect(find.byType(SchoolReviewScreen), findsNothing);
        expect(reviewer.lookups, 0);
        expect(reviewer.approvals, 0);
        expect(find.text('Primary emergency contact'), findsNothing);
        expect(find.text('Unlock with biometrics'), findsNothing);
      },
    );
  }

  testWidgets(
    'denied reviewer lookup cannot expose a candidate or approval button',
    (tester) async {
      final reviewer = _Reviewer();
      await tester.pumpWidget(
        MaterialApp(
          home: SchoolReviewScreen(
            repository: reviewer,
            scanQr: (_) async => 'resqme:v1:fictional-fixture',
          ),
        ),
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Reviewer email'),
        'fictional@example.test',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Password'),
        'fictional-password',
      );
      await tester.tap(find.text('Sign in as reviewer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scan Student QR'));
      await tester.pumpAndSettle();
      expect(reviewer.lookups, 1);
      expect(reviewer.approvals, 0);
      expect(find.text('Review and approve'), findsNothing);
      expect(find.text('Primary emergency contact'), findsNothing);
    },
  );
}
