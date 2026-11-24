import 'package:flutter/material.dart';
import '../../app/resqme_theme.dart';
import 'services/staff_access_repository.dart';

class AdminApp extends StatelessWidget {
  const AdminApp({
    super.key,
    required this.accessRepository,
    this.scannerBuilder,
    this.deviceSetupBuilder,
  });

  final StaffAccessRepository accessRepository;
  final Widget Function(BuildContext context, StaffAccess access)? scannerBuilder;
  final Widget Function(BuildContext context, StaffAccess access)?
      deviceSetupBuilder;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ResQMe Admin',
      debugShowCheckedModeBanner: false,
      theme: ResQMeTheme.light,
      home: _StaffAccessShell(
        accessRepository: accessRepository,
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
    this.scannerBuilder,
    this.deviceSetupBuilder,
  });

  final StaffAccessRepository accessRepository;
  final Widget Function(BuildContext context, StaffAccess access)? scannerBuilder;
  final Widget Function(BuildContext context, StaffAccess access)?
      deviceSetupBuilder;

  @override
  State<_StaffAccessShell> createState() => _StaffAccessShellState();
}

class _StaffAccessShellState extends State<_StaffAccessShell> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  StaffAccess? _access;
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    if (widget.accessRepository.currentUid != null) {
      _verifyExistingSession();
    }
  }

  @override
  void dispose() {
    _email.dispose();
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
    });
    try {
      await widget.accessRepository.signIn(_email.text, _password.text);
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

  Future<void> _signOut() async {
    if (_busy) return;
    setState(() => _busy = true);
    await _safeSignOut();
    if (!mounted) return;
    setState(() {
      _access = null;
      _message = null;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final access = _access;
    if (access == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('ResQMe Staff Sign In')),
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
                      'Institution-provisioned Admin and Authorized staff sign in here. Student accounts cannot access staff emergency Tier 2 tools.',
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _email,
                      enabled: !_busy,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Staff email',
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
                    FilledButton(
                      onPressed: _busy ? null : _signIn,
                      child: Text(_busy ? 'Signing in…' : 'Sign in'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final roleLabel = access.isAdmin ? 'Admin' : 'Authorized';
    return Scaffold(
      appBar: AppBar(
        title: Text('ResQMe $roleLabel'),
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
                          'Role: $roleLabel',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text('Assigned school: ${access.schoolId}'),
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
                  label: const Text('Trusted Device Biometrics'),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Emergency Tier 2 reads require a scanned active student QR and fresh biometric proof from your enrolled device.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
