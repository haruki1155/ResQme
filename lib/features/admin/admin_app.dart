import 'package:flutter/material.dart';
import 'screens/active_students_screen.dart';
import 'screens/authorized_personnel_screen.dart';
import 'screens/master_admin_email_screen.dart';
import 'screens/lost_qr_management_screen.dart';
import 'screens/portal_dashboard_screen.dart';
import 'screens/staff_account_setup_screen.dart';
import 'screens/staff_change_password_screen.dart';
import 'screens/student_roster_screen.dart';
import 'services/portal_student_repository.dart';
import 'services/staff_access_repository.dart';
import 'services/staff_management_repository.dart';
import 'widgets/portal_widgets.dart';

class AdminApp extends StatelessWidget {
  const AdminApp({
    super.key,
    required this.accessRepository,
    this.managementRepository,
    this.portalStudentRepository,
    this.scannerBuilder,
    this.deviceSetupBuilder,
  });

  final StaffAccessRepository accessRepository;
  final StaffManagementRepository? managementRepository;
  final PortalStudentRepository? portalStudentRepository;
  final Widget Function(BuildContext context, StaffAccess access)? scannerBuilder;
  final Widget Function(BuildContext context, StaffAccess access)?
      deviceSetupBuilder;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ResQMe Portal',
      debugShowCheckedModeBanner: false,
      theme: buildResQMePortalTheme(),
      home: _StaffAccessShell(
        accessRepository: accessRepository,
        managementRepository: managementRepository,
        portalStudentRepository: portalStudentRepository,
        scannerBuilder: scannerBuilder,
        deviceSetupBuilder: deviceSetupBuilder,
      ),
      onUnknownRoute: (_) => MaterialPageRoute<void>(
        builder: (_) => const Scaffold(
          body: Center(child: Text('Route unavailable.')),
        ),
      ),
    );
  }
}

enum _PortalAccountAction {
  biometricSetup,
  changePassword,
  emailVerification,
  signOut,
}

class _StaffAccessShell extends StatefulWidget {
  const _StaffAccessShell({
    required this.accessRepository,
    this.managementRepository,
    this.portalStudentRepository,
    this.scannerBuilder,
    this.deviceSetupBuilder,
  });

  final StaffAccessRepository accessRepository;
  final StaffManagementRepository? managementRepository;
  final PortalStudentRepository? portalStudentRepository;
  final Widget Function(BuildContext context, StaffAccess access)? scannerBuilder;
  final Widget Function(BuildContext context, StaffAccess access)?
      deviceSetupBuilder;

  @override
  State<_StaffAccessShell> createState() => _StaffAccessShellState();
}

class _StaffAccessShellState extends State<_StaffAccessShell> {
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  StaffAccess? _access;
  int _selectedTab = 0;
  bool _busy = false;
  String? _message;
  String? _infoMessage;

  @override
  void initState() {
    super.initState();
    if (widget.accessRepository.currentUid != null) {
      _verifyExistingSession();
    }
  }

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _verifyExistingSession() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final access = await widget.accessRepository.loadAccess();
      if (!mounted) return;
      setState(() {
        _access = access;
        _selectedTab = 0;
      });
    } catch (error) {
      await _safeSignOut();
      if (!mounted) return;
      setState(() {
        _access = null;
        _message = error is StaffAccessDenied
            ? error.message
            : 'Staff access is unavailable for this account.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _safeSignOut() async {
    try {
      await widget.accessRepository.signOut();
    } catch (_) {}
  }

  Future<void> _signIn() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
      _infoMessage = null;
    });
    try {
      await widget.accessRepository.signIn(_identifier.text, _password.text);
      _password.clear();
      final access = await widget.accessRepository.loadAccess();
      if (!mounted) return;
      setState(() {
        _access = access;
        _selectedTab = 0;
      });
    } catch (error) {
      _password.clear();
      await _safeSignOut();
      if (!mounted) return;
      setState(() {
        _access = null;
        _message = error is StaffAccessDenied
            ? error.message
            : 'Unable to sign in with this staff account.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendPasswordRecovery() async {
    if (_busy) return;
    final raw = _identifier.text.trim();
    if (!raw.contains('@')) {
      setState(() {
        _message =
            'Enter your Master Admin email address to receive a password recovery link. Authorized staff should request a temporary password reset from their Admin.';
        _infoMessage = null;
      });
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
      _infoMessage = null;
    });
    try {
      await widget.accessRepository.sendPasswordResetEmail(raw);
      if (!mounted) return;
      setState(() {
        _infoMessage =
            'Password recovery email sent if the Admin account exists.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = error is StaffAccessDenied
            ? error.message
            : 'Unable to send password recovery email.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    if (_busy) return;
    setState(() => _busy = true);
    await _safeSignOut();
    if (!mounted) return;
    setState(() {
      _access = null;
      _selectedTab = 0;
      _message = null;
      _infoMessage = null;
      _busy = false;
    });
  }

  void _openScanner(StaffAccess access) {
    final builder = widget.scannerBuilder;
    if (builder == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (ctx) => builder(ctx, access)),
    );
  }

  void _openDeviceSetup(StaffAccess access) {
    final builder = widget.deviceSetupBuilder;
    if (builder == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (ctx) => builder(ctx, access)),
    );
  }

  void _onAccountMenuSelected(_PortalAccountAction action, StaffAccess access) {
    switch (action) {
      case _PortalAccountAction.biometricSetup:
        _openDeviceSetup(access);
      case _PortalAccountAction.changePassword:
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => StaffChangePasswordScreen(
              accessRepository: widget.accessRepository,
            ),
          ),
        );
      case _PortalAccountAction.emailVerification:
        if (!access.isMasterAdmin) return;
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => MasterAdminEmailScreen(
              accessRepository: widget.accessRepository,
              access: access,
              onAccessUpdated: (updated) {
                if (!mounted) return;
                setState(() => _access = updated);
              },
            ),
          ),
        );
      case _PortalAccountAction.signOut:
        _signOut();
    }
  }

  PreferredSizeWidget _buildPortalAppBar(StaffAccess access) {
    return AppBar(
      title: Row(
        children: [
          const PortalBrandMark(size: 28),
          const SizedBox(width: 10),
          const Flexible(
            child: Text(
              'ResQMe Portal',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: PortalColors.border),
      ),
      actions: [
        PopupMenuButton<_PortalAccountAction>(
          tooltip: 'Account & Security',
          enabled: !_busy,
          icon: const Icon(Icons.account_circle_outlined),
          onSelected: (action) => _onAccountMenuSelected(action, access),
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: _PortalAccountAction.biometricSetup,
              child: Row(
                children: [
                  Icon(Icons.fingerprint, size: 20),
                  SizedBox(width: 10),
                  Expanded(child: Text('Biometric Device Setup')),
                ],
              ),
            ),
            const PopupMenuItem(
              value: _PortalAccountAction.changePassword,
              child: Row(
                children: [
                  Icon(Icons.password_outlined, size: 20),
                  SizedBox(width: 10),
                  Expanded(child: Text('Change Password')),
                ],
              ),
            ),
            if (access.isMasterAdmin)
              const PopupMenuItem(
                value: _PortalAccountAction.emailVerification,
                child: Row(
                  children: [
                    Icon(Icons.mark_email_read_outlined, size: 20),
                    SizedBox(width: 10),
                    Expanded(child: Text('Email Verification & Recovery')),
                  ],
                ),
              ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: _PortalAccountAction.signOut,
              child: Row(
                children: [
                  Icon(Icons.logout, size: 20, color: PortalColors.alertFg),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Sign Out',
                      style: TextStyle(color: PortalColors.alertFg),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSignInScreen() {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      PortalBrandMark(size: 40),
                      SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          'ResQMe Portal',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: PortalColors.inkPrimary,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'School Administration & Emergency Response',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: PortalColors.inkSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Staff Sign In',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: PortalColors.inkPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Sign in with your Master Admin email or school-issued Authorized Login ID.',
                            style: TextStyle(
                              fontSize: 13,
                              color: PortalColors.inkSecondary,
                            ),
                          ),
                          const SizedBox(height: 18),
                          TextField(
                            controller: _identifier,
                            enabled: !_busy,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email or Login ID',
                              hintText: 'admin@school.edu or AUTH-XXXXXXXX',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _password,
                            enabled: !_busy,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Password',
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_message != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: PortalColors.alertBg,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                _message!,
                                style: const TextStyle(
                                  color: PortalColors.alertFg,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (_infoMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: PortalColors.verifiedBg,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                _infoMessage!,
                                style: const TextStyle(
                                  color: PortalColors.verifiedFg,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          FilledButton(
                            onPressed: _busy ? null : _signIn,
                            child: Text(_busy ? 'Signing in…' : 'Sign in'),
                          ),
                          const SizedBox(height: 6),
                          TextButton(
                            onPressed: _busy ? null : _sendPasswordRecovery,
                            child: const Text('Forgot Admin Password?'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRestrictedAuthorizedShell(StaffAccess access) {
    return Scaffold(
      appBar: _buildPortalAppBar(access),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                PortalSectionHeader(
                  title: 'Emergency Responder Workspace',
                  subtitle: 'Assigned school: ${access.schoolId}',
                ),
                const SizedBox(height: 14),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                access.fullName ?? 'Authorized Staff',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: PortalColors.inkPrimary,
                                ),
                              ),
                            ),
                            const PortalStatusBadge(
                              label: 'Authorized',
                              tone: PortalBadgeTone.verified,
                            ),
                          ],
                        ),
                        if (access.position != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            access.position!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: PortalColors.inkSecondary,
                            ),
                          ),
                        ],
                        if (access.loginId != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Login ID: ${access.loginId}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: PortalColors.inkSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(
                      color: PortalColors.brandRed,
                      width: 1.2,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Tier 2 Emergency Medical Scan',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: PortalColors.inkPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Scan an active student QR code and authenticate with your enrolled biometric device.',
                          style: TextStyle(
                            fontSize: 13,
                            color: PortalColors.inkSecondary,
                          ),
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: _busy ? null : () => _openScanner(access),
                          icon: const Icon(Icons.qr_code_scanner),
                          label: const Text('Scan Student QR'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _openDeviceSetup(access),
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Biometric Device Setup'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMasterAdminTabBody(StaffAccess access) {
    switch (_selectedTab) {
      case 0:
        final studentRepo = widget.portalStudentRepository;
        return PortalDashboardScreen(
          access: access,
          portalStudentRepository: studentRepo,
          onScanStudentQr: _busy ? null : () => _openScanner(access),
          onOpenLostQrManagement: studentRepo == null
              ? null
              : () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          LostQrManagementScreen(repository: studentRepo),
                    ),
                  ),
        );
      case 1:
        final studentRepo = widget.portalStudentRepository;
        if (studentRepo == null) {
          return const PortalStateView(
            icon: Icons.people_outline,
            title: 'Student Repository Unavailable',
            message: 'Student administration service is not configured.',
          );
        }
        return ActiveStudentsScreen(
          accessRepository: widget.accessRepository,
          portalStudentRepository: studentRepo,
        );
      case 2:
        final studentRepo = widget.portalStudentRepository;
        if (studentRepo == null) {
          return const PortalStateView(
            icon: Icons.fact_check_outlined,
            title: 'Roster Service Unavailable',
            message: 'School roster service is not configured.',
          );
        }
        return StudentRosterScreen(portalStudentRepository: studentRepo);
      case 3:
        final mgmtRepo = widget.managementRepository;
        if (mgmtRepo == null) {
          return const PortalStateView(
            icon: Icons.manage_accounts_outlined,
            title: 'Personnel Service Unavailable',
            message: 'Authorized personnel service is not configured.',
          );
        }
        return AuthorizedPersonnelScreen(
          embedded: true,
          accessRepository: widget.accessRepository,
          managementRepository: mgmtRepo,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final access = _access;
    if (access == null) {
      return _buildSignInScreen();
    }

    if (!access.isSetupComplete) {
      return StaffAccountSetupScreen(
        accessRepository: widget.accessRepository,
        access: access,
        onSetupUpdated: (updated) {
          if (!mounted) return;
          setState(() => _access = updated);
        },
        onSignOut: _signOut,
      );
    }

    if (!access.isAdmin || !access.isMasterAdmin) {
      return _buildRestrictedAuthorizedShell(access);
    }

    return Scaffold(
      appBar: _buildPortalAppBar(access),
      body: SafeArea(child: _buildMasterAdminTabBody(access)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: _busy
            ? null
            : (index) {
                setState(() => _selectedTab = index);
              },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Active Students',
          ),
          NavigationDestination(
            icon: Icon(Icons.fact_check_outlined),
            selectedIcon: Icon(Icons.fact_check),
            label: 'Student Roster',
          ),
          NavigationDestination(
            icon: Icon(Icons.manage_accounts_outlined),
            selectedIcon: Icon(Icons.manage_accounts),
            label: 'Authorized Personnel',
          ),
        ],
      ),
    );
  }
}
