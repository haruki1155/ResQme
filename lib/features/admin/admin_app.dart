import 'package:flutter/material.dart';
import '../../app/resqme_theme.dart';
import 'screens/authorized_personnel_screen.dart';
import 'screens/master_admin_email_screen.dart';
import 'screens/staff_account_setup_screen.dart';
import 'screens/staff_change_password_screen.dart';
import 'services/staff_access_repository.dart';
import 'services/staff_management_repository.dart';

class AdminApp extends StatelessWidget {
  const AdminApp({
    super.key,
    required this.accessRepository,
    this.managementRepository,
    this.scannerBuilder,
    this.deviceSetupBuilder,
  });

  final StaffAccessRepository accessRepository;
  final StaffManagementRepository? managementRepository;
  final Widget Function(BuildContext context, StaffAccess access)? scannerBuilder;
  final Widget Function(BuildContext context, StaffAccess access)?
      deviceSetupBuilder;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ResQMe Portal',
      debugShowCheckedModeBanner: false,
      theme: ResQMeTheme.light,
      home: _StaffAccessShell(
        accessRepository: accessRepository,
        managementRepository: managementRepository,
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

class _StaffAccessShell extends StatefulWidget {
  const _StaffAccessShell({
    required this.accessRepository,
    this.managementRepository,
    this.scannerBuilder,
    this.deviceSetupBuilder,
  });

  final StaffAccessRepository accessRepository;
  final StaffManagementRepository? managementRepository;
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
      setState(() => _access = access);
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
      setState(() => _access = access);
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
        _infoMessage = 'Password recovery email sent if the Admin account exists.';
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
      _message = null;
      _infoMessage = null;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final access = _access;
    if (access == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('ResQMe Portal')),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Institution-provisioned Admin (email) and Authorized staff (Login ID) sign in here. Student accounts cannot access staff emergency Tier 2 tools.',
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _identifier,
                      enabled: !_busy,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Staff email or Login ID',
                        hintText: 'admin@school.edu or AUTH-XXXXXXXX',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _password,
                      enabled: !_busy,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_message != null) ...[
                      Text(
                        _message!,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_infoMessage != null) ...[
                      Text(
                        _infoMessage!,
                        style: TextStyle(color: Colors.green.shade800),
                      ),
                      const SizedBox(height: 12),
                    ],
                    FilledButton(
                      onPressed: _busy ? null : _signIn,
                      child: Text(_busy ? 'Signing in…' : 'Sign in'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _busy ? null : _sendPasswordRecovery,
                      child: const Text('Forgot Admin Password?'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
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

    final roleLabel = access.isAdmin ? 'Admin' : 'Authorized';
    return Scaffold(
      appBar: AppBar(
        title: const Text('ResQMe Portal'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: _busy ? null : _signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Role: $roleLabel${access.isMasterAdmin ? ' (Master)' : ''}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text('Assigned school: ${access.schoolId}'),
                        if (access.fullName != null) ...[
                          const SizedBox(height: 4),
                          Text('Name: ${access.fullName}'),
                        ],
                        if (access.loginId != null) ...[
                          const SizedBox(height: 4),
                          Text('Login ID: ${access.loginId}'),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : () {
                          final builder = widget.scannerBuilder;
                          if (builder == null) return;
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (ctx) => builder(ctx, access),
                            ),
                          );
                        },
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan Student QR'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () {
                          final builder = widget.deviceSetupBuilder;
                          if (builder == null) return;
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (ctx) => builder(ctx, access),
                            ),
                          );
                        },
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Biometric Device Setup'),
                ),
                if (access.isAdmin && widget.managementRepository != null) ...[
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: _busy
                        ? null
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => AuthorizedPersonnelScreen(
                                  accessRepository: widget.accessRepository,
                                  managementRepository:
                                      widget.managementRepository!,
                                ),
                              ),
                            );
                          },
                    icon: const Icon(Icons.manage_accounts_outlined),
                    label: const Text('Authorized Personnel'),
                  ),
                ],
                const Divider(height: 32),
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => StaffChangePasswordScreen(
                                accessRepository: widget.accessRepository,
                              ),
                            ),
                          );
                        },
                  icon: const Icon(Icons.password_outlined),
                  label: const Text('Change Password'),
                ),
                if (access.isMasterAdmin) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () {
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
                          },
                    icon: const Icon(Icons.mark_email_read_outlined),
                    label: const Text('Email Verification & Recovery'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
