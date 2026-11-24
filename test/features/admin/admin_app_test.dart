import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqme/features/admin/admin_app.dart';
import 'package:resqme/features/admin/services/staff_access_repository.dart';
import 'package:resqme/features/admin/services/staff_management_repository.dart';

class FakeStaffAccessRepository implements StaffAccessRepository {
  FakeStaffAccessRepository({
    this.access,
    this.signInError,
    this.email = 'master@school.edu.ph',
  });

  String? _uid;
  StaffAccess? access;
  Object? signInError;
  String? email;
  String? lastSignInIdentifier;
  int passwordChanges = 0;

  @override
  String? get currentUid => _uid;

  @override
  String? get currentEmail => email;

  @override
  Future<void> signIn(String identifier, String password) async {
    lastSignInIdentifier = identifier;
    if (signInError != null) throw signInError!;
    _uid = 'staff-uid-1';
  }

  @override
  Future<StaffAccess> loadAccess() async {
    if (_uid == null || access == null || !access!.active) {
      throw const StaffAccessDenied(
        'Staff access is unavailable for this account.',
      );
    }
    return access!;
  }

  @override
  Future<void> signOut() async {
    _uid = null;
  }

  @override
  Future<void> reauthenticate(String currentPassword) async {}

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    passwordChanges += 1;
    if (access != null) {
      access = StaffAccess(
        uid: access!.uid,
        role: access!.role,
        schoolId: access!.schoolId,
        active: access!.active,
        isMasterAdmin: access!.isMasterAdmin,
        mustChangePassword: false,
        requiresEmailVerification: access!.requiresEmailVerification,
        emailVerified: access!.emailVerified,
        fullName: access!.fullName,
        position: access!.position,
        loginId: access!.loginId,
      );
    }
  }

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<StaffAccess> reloadAndSyncEmail() async => loadAccess();

  @override
  Future<void> requestEmailUpdate({
    required String currentPassword,
    required String newEmail,
  }) async {}

  @override
  Future<void> sendPasswordResetEmail(String email) async {}
}

class FakeStaffManagementRepository implements StaffManagementRepository {
  final List<AuthorizedAccountSummary> accounts = [
    const AuthorizedAccountSummary(
      uid: 'auth-1',
      loginId: 'AUTH-1111AAAA',
      fullName: 'Nurse Clara',
      position: 'School Nurse',
      status: 'active',
      active: true,
      mustChangePassword: false,
      hasActiveDevice: true,
    ),
  ];

  @override
  Future<List<AuthorizedAccountSummary>> listAccounts({
    String search = '',
  }) async {
    final q = search.trim().toLowerCase();
    if (q.isEmpty) return List.of(accounts);
    return accounts
        .where((a) =>
            a.fullName.toLowerCase().contains(q) ||
            a.position.toLowerCase().contains(q) ||
            a.loginId.toLowerCase().contains(q))
        .toList();
  }

  @override
  Future<IssuedAuthorizedCredentials> createAccount({
    required String fullName,
    required String position,
  }) async {
    const creds = IssuedAuthorizedCredentials(
      uid: 'auth-2',
      loginId: 'AUTH-9999ZZZZ',
      temporaryPassword: 'Temp!Password2026',
      fullName: 'Guard Mario',
      position: 'Campus Security',
    );
    accounts.add(
      AuthorizedAccountSummary(
        uid: creds.uid,
        loginId: creds.loginId,
        fullName: fullName,
        position: position,
        status: 'active',
        active: true,
        mustChangePassword: true,
        hasActiveDevice: false,
      ),
    );
    return IssuedAuthorizedCredentials(
      uid: creds.uid,
      loginId: creds.loginId,
      temporaryPassword: creds.temporaryPassword,
      fullName: fullName,
      position: position,
    );
  }

  @override
  Future<void> updateAccount({
    required String targetUid,
    required String fullName,
    required String position,
  }) async {}

  @override
  Future<void> setAccountStatus({
    required String targetUid,
    required String action,
  }) async {}

  @override
  Future<IssuedAuthorizedCredentials> resetPassword({
    required String targetUid,
    required String fullName,
    required String position,
  }) async =>
      IssuedAuthorizedCredentials(
        uid: targetUid,
        loginId: 'AUTH-1111AAAA',
        temporaryPassword: 'Reset!Password2026',
        fullName: fullName,
        position: position,
      );

  @override
  Future<void> revokeDevice({required String targetUid}) async {}
}

void main() {
  test('normalizeStaffLoginIdentifier maps Authorized Login IDs and emails', () {
    expect(
      normalizeStaffLoginIdentifier('  AUTH-7K3M9Q2X '),
      'auth-7k3m9q2x@staff.resqme.internal',
    );
    expect(
      normalizeStaffLoginIdentifier('  Master@School.EDU.PH '),
      'master@school.edu.ph',
    );
  });

  testWidgets('unauthenticated user sees unified staff sign-in and cannot reach scan shell', (tester) async {
    final repo = FakeStaffAccessRepository();
    await tester.pumpWidget(AdminApp(accessRepository: repo));
    await tester.pumpAndSettle();

    expect(find.text('ResQMe Staff Sign In'), findsOneWidget);
    expect(find.text('Staff email or Login ID'), findsOneWidget);
    expect(find.text('Scan Student QR'), findsNothing);
  });

  testWidgets('ordinary student or inactive staff is denied access after sign-in', (tester) async {
    final repo = FakeStaffAccessRepository(access: null);
    await tester.pumpWidget(AdminApp(accessRepository: repo));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Staff email or Login ID'),
      'student@example.test',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      'fictional-password',
    );
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Staff access is unavailable'), findsOneWidget);
    expect(find.text('Scan Student QR'), findsNothing);
    expect(repo.currentUid, isNull);
  });

  testWidgets('unverified Master Admin is gated to Master Admin Account Setup', (tester) async {
    final repo = FakeStaffAccessRepository(
      access: const StaffAccess(
        uid: 'master-1',
        role: 'admin',
        schoolId: 'pilot-school-1',
        active: true,
        isMasterAdmin: true,
        mustChangePassword: true,
        requiresEmailVerification: true,
        emailVerified: false,
      ),
    );
    await tester.pumpWidget(
      AdminApp(
        accessRepository: repo,
        managementRepository: FakeStaffManagementRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Staff email or Login ID'),
      'master@school.edu.ph',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      'Initial!Password2026',
    );
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Master Admin Account Setup'), findsOneWidget);
    expect(find.text('Scan Student QR'), findsNothing);
    expect(find.text('Authorized Personnel'), findsNothing);
  });

  testWidgets('Authorized user never sees Authorized Personnel or Master Admin email controls', (tester) async {
    final repo = FakeStaffAccessRepository(
      access: const StaffAccess(
        uid: 'auth-1',
        role: 'authorized',
        schoolId: 'pilot-school-1',
        active: true,
        isMasterAdmin: false,
        mustChangePassword: false,
        requiresEmailVerification: false,
        loginId: 'AUTH-1111AAAA',
      ),
    );
    await tester.pumpWidget(
      AdminApp(
        accessRepository: repo,
        managementRepository: FakeStaffManagementRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Staff email or Login ID'),
      'AUTH-1111AAAA',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      'Strong!Password2026',
    );
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Scan Student QR'), findsOneWidget);
    expect(find.text('Authorized Personnel'), findsNothing);
    expect(find.text('Email Verification & Recovery'), findsNothing);
  });

  testWidgets('verified Master Admin can open Authorized Personnel and create an account with one-time credentials', (tester) async {
    final repo = FakeStaffAccessRepository(
      access: const StaffAccess(
        uid: 'master-1',
        role: 'admin',
        schoolId: 'pilot-school-1',
        active: true,
        isMasterAdmin: true,
        mustChangePassword: false,
        requiresEmailVerification: true,
        emailVerified: true,
      ),
    );
    final mgmt = FakeStaffManagementRepository();
    await tester.pumpWidget(
      AdminApp(
        accessRepository: repo,
        managementRepository: mgmt,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Staff email or Login ID'),
      'master@school.edu.ph',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      'Strong!Password2026',
    );
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Authorized Personnel'), findsOneWidget);
    await tester.tap(find.text('Authorized Personnel'));
    await tester.pumpAndSettle();

    expect(find.text('Nurse Clara'), findsOneWidget);
    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Full name'),
      'Guard Mario',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Position or designation'),
      'Campus Security',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create Authorized Account'));
    await tester.pumpAndSettle();

    expect(find.text('One-Time Initial Credentials'), findsOneWidget);
    expect(find.textContaining('AUTH-9999ZZZZ'), findsOneWidget);
    expect(find.textContaining('Temp!Password2026'), findsOneWidget);
  });
}
