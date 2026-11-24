import 'package:flutter/material.dart';
import '../services/staff_access_repository.dart';

class MasterAdminEmailScreen extends StatefulWidget {
  const MasterAdminEmailScreen({
    super.key,
    required this.accessRepository,
    required this.access,
    this.onAccessUpdated,
  });

  final StaffAccessRepository accessRepository;
  final StaffAccess access;
  final ValueChanged<StaffAccess>? onAccessUpdated;

  @override
  State<MasterAdminEmailScreen> createState() => _MasterAdminEmailScreenState();
}

class _MasterAdminEmailScreenState extends State<MasterAdminEmailScreen> {
  final _newEmail = TextEditingController();
  final _currentPassword = TextEditingController();
  bool _busy = false;
  String? _statusMessage;
  String? _error;
  late StaffAccess _access;

  @override
  void initState() {
    super.initState();
    _access = widget.access;
  }

  @override
  void dispose() {
    _newEmail.dispose();
    _currentPassword.dispose();
    super.dispose();
  }

  Future<void> _sendVerification() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _statusMessage = null;
    });
    try {
      await widget.accessRepository.sendEmailVerification();
      if (!mounted) return;
      setState(() {
        _statusMessage =
            'Verification email sent. Open the link in your inbox, then tap "Check Verification Status".';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Unable to send verification email.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refreshStatus() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _statusMessage = null;
    });
    try {
      final updated = await widget.accessRepository.reloadAndSyncEmail();
      if (!mounted) return;
      setState(() {
        _access = updated;
        _statusMessage = updated.emailVerified
            ? 'Email address is verified.'
            : 'Email is not verified yet. Please click the verification link sent to your inbox.';
      });
      widget.onAccessUpdated?.call(updated);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Unable to refresh verification status.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestEmailUpdate() async {
    if (_busy) return;
    final nextEmail = _newEmail.text.trim();
    if (!nextEmail.contains('@')) {
      setState(() => _error = 'Enter a valid new email address.');
      return;
    }
    if (_currentPassword.text.isEmpty) {
      setState(() => _error = 'Enter your current password to reauthenticate.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _statusMessage = null;
    });
    try {
      await widget.accessRepository.requestEmailUpdate(
        currentPassword: _currentPassword.text,
        newEmail: nextEmail,
      );
      _currentPassword.clear();
      _newEmail.clear();
      if (!mounted) return;
      setState(() {
        _statusMessage =
            'Verification link sent to $nextEmail. Your email will update only after you confirm it.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() =>
          _error = 'Unable to request email update. Verify your current password.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendRecovery() async {
    final email = widget.accessRepository.currentEmail;
    if (_busy || email == null || email.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _statusMessage = null;
    });
    try {
      await widget.accessRepository.sendPasswordResetEmail(email);
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Password recovery email sent to $email.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Unable to send password recovery email.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentEmail = widget.accessRepository.currentEmail ?? 'Not available';
    return Scaffold(
      appBar: AppBar(title: const Text('Email Verification & Recovery')),
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
                          'Current Email: $currentEmail',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _access.emailVerified
                              ? 'Status: Verified'
                              : 'Status: Verification Required',
                          style: TextStyle(
                            color: _access.emailVerified
                                ? Colors.green.shade800
                                : Colors.orange.shade900,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (!_access.emailVerified) ...[
                  FilledButton.icon(
                    onPressed: _busy ? null : _sendVerification,
                    icon: const Icon(Icons.mark_email_unread_outlined),
                    label: const Text('Send Verification Email'),
                  ),
                  const SizedBox(height: 12),
                ],
                OutlinedButton.icon(
                  onPressed: _busy ? null : _refreshStatus,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Check Verification Status'),
                ),
                const SizedBox(height: 24),
                Text(
                  'Update Verified Email',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _newEmail,
                  enabled: !_busy,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'New email address',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _currentPassword,
                  enabled: !_busy,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Current password (for reauthentication)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: _busy ? null : _requestEmailUpdate,
                  child: const Text('Send Email Update Verification'),
                ),
                const SizedBox(height: 24),
                Text(
                  'Password Recovery',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _sendRecovery,
                  icon: const Icon(Icons.lock_reset),
                  label: const Text('Send Password Recovery Email'),
                ),
                if (_statusMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _statusMessage!,
                    style: TextStyle(color: Colors.green.shade800),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
