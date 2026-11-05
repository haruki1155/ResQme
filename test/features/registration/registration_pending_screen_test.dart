import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqme/features/registration/models/student_registration_profile.dart';
import 'package:resqme/features/registration/screens/registration_pending_screen.dart';

void main() {
  for (final minor in [false, true]) {
    testWidgets(
      'pending ${minor ? 'minor' : 'adult'} is private, collapsed and restricted',
      (tester) async {
        final profile = StudentRegistrationProfile.fromFirestore({
          'schemaVersion': 1,
          'fullName': 'Synthetic Student',
          'ageYearsAtRegistration': minor ? 17 : 18,
          'status': minor ? 'pending_guardian' : 'pending_review',
        });
        var refresh = 0, public = 0, logout = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: RegistrationPendingScreen(
              profile: profile,
              onRefreshStatus: () {
                refresh++;
              },
              onPublicDashboard: () {
                public++;
              },
              onSignOut: () {
                logout++;
              },
            ),
          ),
        );
        expect(
          find.text(
            minor
                ? 'Registration received — guardian authorization pending'
                : 'Registration received — pending school review',
          ),
          findsOneWidget,
        );
        expect(find.text('Synthetic Student'), findsNothing);
        expect(find.text('My QR'), findsNothing);
        expect(find.text('Tier 2'), findsNothing);
        await tester.tap(find.text('Review submitted details'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Synthetic Student'), findsOneWidget);
        await tester.ensureVisible(find.text('View registration status'));
        await tester.tap(find.text('View registration status'));
        await tester.pumpAndSettle();
        expect(refresh, 1);
        await tester.ensureVisible(find.text('Return to public dashboard'));
        await tester.tap(find.text('Return to public dashboard'));
        await tester.pumpAndSettle();
        expect(public, 1);
        await tester.ensureVisible(find.text('Sign out'));
        await tester.tap(find.text('Sign out'));
        await tester.pumpAndSettle();
        expect(logout, 1);
      },
    );
  }
}
