import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqme/features/admin/admin_app.dart';
import 'package:resqme/features/admin/services/staff_access_repository.dart';

class FakeStaffAccessRepository implements StaffAccessRepository {
  FakeStaffAccessRepository({this.access, this.signInError});

  String? _uid;
  StaffAccess? access;
  Object? signInError;

  @override
  String? get currentUid => _uid;

  @override
  Future<void> signIn(String email, String password) async {
    if (signInError != null) throw signInError!;
    _uid = 'staff-uid-1';
  }

  @override
  Future<StaffAccess> loadAccess() async {
    if (_uid == null || access == null || !access!.active) {
      throw const StaffAccessDenied('Staff access is unavailable for this account.');
    }
    return access!;
  }

  @override
  Future<void> signOut() async {
    _uid = null;
  }
}

void main() {
  testWidgets('unauthenticated user sees staff sign-in and cannot reach scan shell', (tester) async {
    final repo = FakeStaffAccessRepository();
    await tester.pumpWidget(AdminApp(accessRepository: repo));
    await tester.pumpAndSettle();

    expect(find.text('ResQMe Staff Sign In'), findsOneWidget);
    expect(find.text('Scan Student QR'), findsNothing);
  });

  testWidgets('ordinary student or inactive staff is denied access after sign-in', (tester) async {
    final repo = FakeStaffAccessRepository(access: null);
    await tester.pumpWidget(AdminApp(accessRepository: repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Staff email'), 'student@example.test');
    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'fictional-password');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Staff access is unavailable'), findsOneWidget);
    expect(find.text('Scan Student QR'), findsNothing);
    expect(repo.currentUid, isNull);
  });

  testWidgets('active Authorized and Admin roles see role-gated scan shell within school scope', (tester) async {
    for (final role in ['authorized', 'admin']) {
      final repo = FakeStaffAccessRepository(
        access: StaffAccess(
          uid: 'staff-uid-1',
          role: role,
          schoolId: 'pilot-school-1',
          active: true,
        ),
      );
      await tester.pumpWidget(
        AdminApp(key: ValueKey(role), accessRepository: repo),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Staff email'), '$role@example.test');
      await tester.enterText(find.widgetWithText(TextField, 'Password'), 'fictional-password');
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('Scan Student QR'), findsOneWidget);
      expect(find.textContaining('pilot-school-1'), findsOneWidget);
      expect(find.textContaining(role == 'admin' ? 'Admin' : 'Authorized'), findsWidgets);
    }
  });
}
