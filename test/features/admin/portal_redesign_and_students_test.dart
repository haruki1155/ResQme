import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqme/features/admin/admin_app.dart';
import 'package:resqme/features/admin/services/portal_student_repository.dart';
import 'package:resqme/features/admin/services/staff_access_repository.dart';
import 'package:resqme/features/admin/services/staff_management_repository.dart';

class _FakeAccessRepo implements StaffAccessRepository {
  _FakeAccessRepo({required this.access});

  bool signedIn = true;
  StaffAccess access;
  int reauthCalls = 0;

  @override
  String? get currentUid => signedIn ? access.uid : null;

  @override
  String? get currentEmail => 'admin@pilot.edu.ph';

  @override
  Future<void> signIn(String identifier, String password) async {
    signedIn = true;
  }

  @override
  Future<StaffAccess> loadAccess() async => access;

  @override
  Future<void> signOut() async {
    signedIn = false;
  }

  @override
  Future<void> reauthenticate(String currentPassword) async {
    if (currentPassword.isEmpty) {
      throw const StaffAccessDenied('Password required.');
    }
    reauthCalls += 1;
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {}

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<StaffAccess> reloadAndSyncEmail() async => access;

  @override
  Future<void> requestEmailUpdate({
    required String currentPassword,
    required String newEmail,
  }) async {}

  @override
  Future<void> sendPasswordResetEmail(String email) async {}
}

class _FakeManagementRepo implements StaffManagementRepository {
  @override
  Future<List<AuthorizedAccountSummary>> listAccounts({String search = ''}) async =>
      const [
        AuthorizedAccountSummary(
          uid: 'auth-1',
          loginId: 'AUTH-1111AAAA',
          fullName: 'Clara Santos',
          position: 'School Nurse',
          status: 'active',
          active: true,
          mustChangePassword: false,
          hasActiveDevice: true,
        ),
      ];

  @override
  Future<IssuedAuthorizedCredentials> createAccount({
    required String fullName,
    required String position,
  }) =>
      throw UnimplementedError();

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
  }) =>
      throw UnimplementedError();

  @override
  Future<void> revokeDevice({required String targetUid}) async {}
}

class _FakePortalStudentRepo implements PortalStudentRepository {
  _FakePortalStudentRepo({this.emptyRoster = false});

  final bool emptyRoster;
  final Map<String, SchoolStudentDetails> records = {
    'stu-1': const SchoolStudentDetails(
      uid: 'stu-1',
      fullName: 'Ana Santos',
      lrn: '009876543210',
      gradeLevel: 'Grade 10',
      sex: 'Female',
      birthDate: '2010-04-12',
      ageYearsAtRegistration: 16,
      accountCategory: 'verified',
      accountDisabled: false,
      registrationStatus: 'pending_guardian',
      schoolApprovalStatus: 'approved',
      verificationMethod: 'roster',
      verificationOutcome: 'verified',
      medicalCompletionStatus: 'complete',
      guardianAuthorizationStatus: 'verified',
      qrStatus: 'active',
      canVerifyManually: false,
    ),
    'stu-2': const SchoolStudentDetails(
      uid: 'stu-2',
      fullName: 'Benito Reyes',
      lrn: '000000123456',
      gradeLevel: 'Unassigned Grade',
      sex: 'Male',
      birthDate: null,
      ageYearsAtRegistration: 18,
      accountCategory: 'registered',
      accountDisabled: false,
      registrationStatus: 'pending_review',
      schoolApprovalStatus: 'pending',
      verificationMethod: null,
      verificationOutcome: 'manual_review',
      medicalCompletionStatus: 'not_started',
      guardianAuthorizationStatus: 'not_required_adult',
      qrStatus: 'pending',
      canVerifyManually: true,
    ),
    'stu-3': const SchoolStudentDetails(
      uid: 'stu-3',
      fullName: 'Carlo Mendoza',
      lrn: '005555555555',
      gradeLevel: 'Grade 12',
      sex: 'Male',
      birthDate: '2007-11-03',
      ageYearsAtRegistration: 19,
      accountCategory: 'disabled',
      accountDisabled: true,
      registrationStatus: 'pending_review',
      schoolApprovalStatus: 'revoked',
      verificationMethod: 'manual_admin',
      verificationOutcome: 'verified',
      medicalCompletionStatus: 'complete',
      guardianAuthorizationStatus: 'not_required_adult',
      qrStatus: 'revoked',
      canVerifyManually: false,
    ),
  };

  late final List<SchoolRosterEntry> roster = emptyRoster
      ? []
      : [
          const SchoolRosterEntry(
            rosterId: 'r-1',
            displayName: 'Bautista, Zara',
            lrn: '002222222222',
            gradeLevel: 'Unassigned Grade',
            sex: 'Female',
            birthDate: '2009-09-01',
            registrationState: 'not_registered',
            claimedStudentUid: null,
          ),
          const SchoolRosterEntry(
            rosterId: 'r-2',
            displayName: 'Reyes, Benito',
            lrn: '000000123456',
            gradeLevel: 'Unassigned Grade',
            sex: 'Male',
            birthDate: null,
            registrationState: 'registered',
            claimedStudentUid: 'stu-2',
          ),
          const SchoolRosterEntry(
            rosterId: 'r-3',
            displayName: 'Santos, Ana',
            lrn: '009876543210',
            gradeLevel: 'Grade 10',
            sex: 'Female',
            birthDate: '2010-04-12',
            registrationState: 'verified',
            claimedStudentUid: 'stu-1',
          ),
        ];

  @override
  Future<PortalDashboardStats> loadDashboardStats() async {
    final values = records.values.toList();
    return PortalDashboardStats(
      schoolId: 'pilot-school-1',
      rosterAvailable: roster.isNotEmpty,
      importedRosterCount: roster.length,
      registeredStudentsCount: values.length,
      verifiedStudentsCount:
          values.where((s) => s.accountCategory == 'verified').length,
      disabledStudentsCount:
          values.where((s) => s.accountCategory == 'disabled').length,
      authorizedPersonnelCount: 1,
    );
  }

  @override
  Future<SchoolStudentPage> listStudents({
    String search = '',
    String statusFilter = 'all',
    String? gradeFilter,
    int limit = 20,
    String? cursor,
  }) async {
    final q = search.trim().toLowerCase();
    final exactLrn = RegExp(r'^\d{12}$').hasMatch(search.trim());
    var items = records.values.map((d) {
      return SchoolStudentSummary(
        uid: d.uid,
        fullName: d.fullName,
        lrn: d.lrn,
        gradeLevel: d.gradeLevel,
        accountCategory: d.accountCategory,
        schoolApprovalStatus: d.schoolApprovalStatus,
        verificationMethod: d.verificationMethod,
      );
    }).where((s) {
      if (statusFilter != 'all' && s.accountCategory != statusFilter) {
        return false;
      }
      if (gradeFilter != null &&
          gradeFilter.isNotEmpty &&
          gradeFilter != 'all' &&
          s.gradeLevel != gradeFilter) {
        return false;
      }
      if (q.isNotEmpty) {
        if (exactLrn) return s.lrn == search.trim();
        return s.fullName.toLowerCase().contains(q) || s.lrn == search.trim();
      }
      return true;
    }).toList();
    items.sort((a, b) => a.fullName.compareTo(b.fullName));
    return SchoolStudentPage(
      students: items,
      nextCursor: null,
      totalMatched: items.length,
      availableGrades: const ['Grade 10', 'Grade 12', 'Unassigned Grade'],
    );
  }

  @override
  Future<SchoolStudentDetails> getStudentDetails(String studentUid) async {
    return records[studentUid]!;
  }

  @override
  Future<void> verifyStudentAccount({
    required String studentUid,
    required String requestId,
  }) async {
    final cur = records[studentUid]!;
    records[studentUid] = SchoolStudentDetails(
      uid: cur.uid,
      fullName: cur.fullName,
      lrn: cur.lrn,
      gradeLevel: cur.gradeLevel,
      sex: cur.sex,
      birthDate: cur.birthDate,
      ageYearsAtRegistration: cur.ageYearsAtRegistration,
      accountCategory: 'verified',
      accountDisabled: false,
      registrationStatus: cur.registrationStatus,
      schoolApprovalStatus: 'approved',
      verificationMethod: 'manual_admin',
      verificationOutcome: 'verified',
      medicalCompletionStatus: cur.medicalCompletionStatus,
      guardianAuthorizationStatus: cur.guardianAuthorizationStatus,
      // Do not auto-activate pending QR when medical is incomplete!
      qrStatus: cur.qrStatus,
      canVerifyManually: false,
    );
  }

  @override
  Future<void> setStudentAccountStatus({
    required String studentUid,
    required String action,
  }) async {
    final cur = records[studentUid]!;
    final disable = action == 'disable';
    final nextCat = disable
        ? 'disabled'
        : (cur.schoolApprovalStatus == 'approved' ? 'verified' : 'registered');
    records[studentUid] = SchoolStudentDetails(
      uid: cur.uid,
      fullName: cur.fullName,
      lrn: cur.lrn,
      gradeLevel: cur.gradeLevel,
      sex: cur.sex,
      birthDate: cur.birthDate,
      ageYearsAtRegistration: cur.ageYearsAtRegistration,
      accountCategory: nextCat,
      accountDisabled: disable,
      registrationStatus: cur.registrationStatus,
      schoolApprovalStatus: cur.schoolApprovalStatus,
      verificationMethod: cur.verificationMethod,
      verificationOutcome: cur.verificationOutcome,
      medicalCompletionStatus: cur.medicalCompletionStatus,
      guardianAuthorizationStatus: cur.guardianAuthorizationStatus,
      // Never auto-restore revoked QR on reactivation!
      qrStatus: cur.qrStatus,
      canVerifyManually: !disable && cur.schoolApprovalStatus == 'pending',
    );
  }

  @override
  Future<SchoolRosterPage> listRoster({
    String search = '',
    String? gradeFilter,
    int limit = 20,
    String? cursor,
  }) async {
    if (roster.isEmpty) {
      return const SchoolRosterPage(
        rosterAvailable: false,
        entries: [],
        nextCursor: null,
        totalMatched: 0,
        availableGrades: [],
      );
    }
    final q = search.trim().toLowerCase();
    final filtered = roster.where((e) {
      if (gradeFilter != null &&
          gradeFilter.isNotEmpty &&
          gradeFilter != 'all' &&
          e.gradeLevel != gradeFilter) {
        return false;
      }
      if (q.isNotEmpty) {
        return e.displayName.toLowerCase().contains(q) ||
            e.lrn == search.trim();
      }
      return true;
    }).toList();
    return SchoolRosterPage(
      rosterAvailable: true,
      entries: filtered,
      nextCursor: null,
      totalMatched: filtered.length,
      availableGrades: const ['Grade 10', 'Unassigned Grade'],
    );
  }
}

void main() {
  const masterAccess = StaffAccess(
    uid: 'master-1',
    role: 'admin',
    schoolId: 'pilot-school-1',
    active: true,
    isMasterAdmin: true,
    mustChangePassword: false,
    requiresEmailVerification: true,
    emailVerified: true,
    fullName: 'Elena Cruz',
  );

  const authorizedAccess = StaffAccess(
    uid: 'auth-1',
    role: 'authorized',
    schoolId: 'pilot-school-1',
    active: true,
    isMasterAdmin: false,
    mustChangePassword: false,
    requiresEmailVerification: false,
    fullName: 'Clara Santos',
    loginId: 'AUTH-1111AAAA',
  );

  testWidgets('Master Admin navigation renders 4 primary tabs, Dashboard stats, and Account menu', (tester) async {
    for (final width in [360.0, 412.0]) {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = Size(width, 840);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final accessRepo = _FakeAccessRepo(access: masterAccess);
      final studentRepo = _FakePortalStudentRepo();
      await tester.pumpWidget(
        AdminApp(
          accessRepository: accessRepo,
          managementRepository: _FakeManagementRepo(),
          portalStudentRepository: studentRepo,
          scannerBuilder: (_, _) => const Scaffold(body: Text('Scanner Ready')),
          deviceSetupBuilder: (_, _) =>
              const Scaffold(body: Text('Biometric Setup Ready')),
        ),
      );
      await tester.pumpAndSettle();

      // Primary 4 destinations
      expect(find.text('Dashboard'), findsWidgets);
      expect(find.text('Active Students'), findsOneWidget);
      expect(find.text('Student Roster'), findsOneWidget);
      expect(find.text('Authorized Personnel'), findsOneWidget);

      // Prominent QR scan on Dashboard
      expect(find.text('Scan Student QR'), findsOneWidget);

      // Account menu contains Biometric Device Setup, Change Password, Email Verification
      await tester.tap(find.byTooltip('Account & Security'));
      await tester.pumpAndSettle();
      expect(find.text('Biometric Device Setup'), findsOneWidget);
      expect(find.text('Change Password'), findsOneWidget);
      expect(find.text('Email Verification & Recovery'), findsOneWidget);
      // Dismiss menu
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('Authorized personnel never sees Active Students, Student Roster, or Authorized Personnel routes', (tester) async {
    await tester.pumpWidget(
      AdminApp(
        accessRepository: _FakeAccessRepo(access: authorizedAccess),
        managementRepository: _FakeManagementRepo(),
        portalStudentRepository: _FakePortalStudentRepo(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Scan Student QR'), findsOneWidget);
    expect(find.text('Active Students'), findsNothing);
    expect(find.text('Student Roster'), findsNothing);
    expect(find.text('Authorized Personnel'), findsNothing);
  });

  testWidgets('Active Students supports status filters (no Pending/Revoked categories), exact LRN search, manual verification, and account disable/enable without restoring revoked QR', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(412, 915);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final accessRepo = _FakeAccessRepo(access: masterAccess);
    final studentRepo = _FakePortalStudentRepo();
    await tester.pumpWidget(
      AdminApp(
        accessRepository: accessRepo,
        managementRepository: _FakeManagementRepo(),
        portalStudentRepository: studentRepo,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Active Students'));
    await tester.pumpAndSettle();

    // Visible filter chips: All, Registered, Verified, Disabled — NO Pending or Revoked chip
    expect(find.widgetWithText(ChoiceChip, 'All'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Registered'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Verified'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Disabled'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Pending'), findsNothing);
    expect(find.widgetWithText(ChoiceChip, 'Revoked'), findsNothing);

    // Leading-zero LRN search
    await tester.enterText(
      find.byKey(const Key('active-students-search')),
      '000000123456',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('Benito Reyes'), findsOneWidget);
    expect(find.text('Ana Santos'), findsNothing);

    // Open Benito Reyes details -> manual verification
    await tester.tap(find.text('Benito Reyes'));
    await tester.pumpAndSettle();
    expect(find.text('000000123456'), findsOneWidget);
    expect(find.text('Unassigned Grade'), findsOneWidget);
    expect(find.text('Verify Student Account'), findsOneWidget);

    await tester.ensureVisible(find.text('Verify Student Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Verify Student Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approve Verification'));
    await tester.pumpAndSettle();

    expect(studentRepo.records['stu-2']!.accountCategory, 'verified');
    expect(studentRepo.records['stu-2']!.verificationMethod, 'manual_admin');
    // Pending QR was NOT auto-activated because medical record is incomplete
    expect(studentRepo.records['stu-2']!.qrStatus, 'pending');

    await tester.pageBack();
    await tester.pumpAndSettle();

    // Clear search and filter Disabled -> Carlo Mendoza (has revoked QR)
    await tester.enterText(find.byKey(const Key('active-students-search')), '');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Disabled'));
    await tester.pumpAndSettle();
    expect(find.text('Carlo Mendoza'), findsOneWidget);

    await tester.tap(find.text('Carlo Mendoza'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Enable Student Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enable Student Account'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('student-status-reauth-password')),
      'AdminStrong!2026',
    );
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(accessRepo.reauthCalls, 1);
    expect(studentRepo.records['stu-3']!.accountDisabled, isFalse);
    // Revoked QR remains revoked after reactivation!
    expect(studentRepo.records['stu-3']!.qrStatus, 'revoked');
  });

  testWidgets('Student Roster shows unregistered/registered/verified records and truthful empty state without fake Import button', (tester) async {
    // 1. Populated roster
    await tester.pumpWidget(
      AdminApp(
        accessRepository: _FakeAccessRepo(access: masterAccess),
        managementRepository: _FakeManagementRepo(),
        portalStudentRepository: _FakePortalStudentRepo(emptyRoster: false),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Student Roster'));
    await tester.pumpAndSettle();

    expect(find.text('Bautista, Zara'), findsOneWidget);
    expect(find.text('Not Registered'), findsOneWidget);
    expect(find.text('Santos, Ana'), findsOneWidget);
    expect(find.textContaining('Import'), findsNothing);

    // 2. Empty roster truthful state (no fake Import button)
    await tester.pumpWidget(
      AdminApp(
        key: const ValueKey('empty-roster-app'),
        accessRepository: _FakeAccessRepo(access: masterAccess),
        managementRepository: _FakeManagementRepo(),
        portalStudentRepository: _FakePortalStudentRepo(emptyRoster: true),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Student Roster'));
    await tester.pumpAndSettle();

    expect(find.textContaining('No official school roster records'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Import SF1'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'Import SF1'), findsNothing);
  });
}
