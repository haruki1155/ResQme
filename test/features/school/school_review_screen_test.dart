import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqme/features/school/screens/school_review_screen.dart';
import 'package:resqme/features/school/services/school_review_repository.dart';

class _ReviewRepository implements SchoolReviewRepository {
  String? uid;
  int searches = 0, approvals = 0;
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
  Future<void> approve(String studentUid, String requestId) async {
    approvals++;
  }

  @override
  Future<void> signOut() async {
    uid = null;
  }
}

void main() {
  testWidgets(
    'reviewer sign-in gates candidate lookup and approval confirmation',
    (tester) async {
      final repository = _ReviewRepository();
      await tester.pumpWidget(
        MaterialApp(home: SchoolReviewScreen(repository: repository)),
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
      expect(find.text('Student review reference'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Student review reference'),
        'synthetic-student-uid',
      );
      await tester.tap(find.text('Find pending student'));
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
      expect(find.text('School approval recorded.'), findsOneWidget);
    },
  );
}
