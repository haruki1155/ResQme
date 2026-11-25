import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/staff_access_repository.dart';
import '../services/staff_management_repository.dart';

class AuthorizedAccountDetailsScreen extends StatefulWidget {
  const AuthorizedAccountDetailsScreen({
    super.key,
    required this.account,
    required this.accessRepository,
    required this.managementRepository,
  });

  final AuthorizedAccountSummary account;
  final StaffAccessRepository accessRepository;
  final StaffManagementRepository managementRepository;

  @override
  State<AuthorizedAccountDetailsScreen> createState() =>
      _AuthorizedAccountDetailsScreenState();
}

class _AuthorizedAccountDetailsScreenState
    extends State<AuthorizedAccountDetailsScreen> {
  late final TextEditingController _fullName;
  late final TextEditingController _position;
  late AuthorizedAccountSummary _account;
  bool _busy = false;
  String? _message;
  String? _error;

  @override
  void initState() {
    super.initState();
    _account = widget.account;
    _fullName = TextEditingController(text: _account.fullName);
    _position = TextEditingController(text: _account.position);
  }

  @override
  void dispose() {
    _fullName.dispose();
    _position.dispose();
    super.dispose();
  }

  Future<bool> _promptReauth(String reason) async {
    final password = await showDialog<String>(
      context: context,
      builder: (_) => _AdminReauthDialog(reason: reason),
    );
    if (password == null || password.isEmpty) return false;
    await widget.accessRepository.reauthenticate(password);
    return true;
  }

  Future<void> _saveDetails() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      await widget.managementRepository.updateAccount(
        targetUid: _account.uid,
        fullName: _fullName.text,
        position: _position.text,
      );
      if (!mounted) return;
      setState(() {
        _account = AuthorizedAccountSummary(
          uid: _account.uid,
          loginId: _account.loginId,
          fullName: _fullName.text.trim(),
          position: _position.text.trim(),
          status: _account.status,
          active: _account.active,
          mustChangePassword: _account.mustChangePassword,
          hasActiveDevice: _account.hasActiveDevice,
        );
        _message = 'Account details updated.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Unable to update account details.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeStatus(String action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      if (action == 'revoke') {
        final confirmed = await _promptReauth(
          'Re-enter your password to permanently revoke access for ${_account.fullName}. This cannot be undone.',
        );
        if (!confirmed) return;
      }
      await widget.managementRepository.setAccountStatus(
        targetUid: _account.uid,
        action: action,
      );
      if (!mounted) return;
      final nextStatus = action == 'reactivate'
          ? 'active'
          : action == 'suspend'
              ? 'suspended'
              : 'revoked';
      setState(() {
        _account = AuthorizedAccountSummary(
          uid: _account.uid,
          loginId: _account.loginId,
          fullName: _account.fullName,
          position: _account.position,
          status: nextStatus,
          active: nextStatus == 'active',
          mustChangePassword: _account.mustChangePassword,
          hasActiveDevice:
              nextStatus == 'active' ? _account.hasActiveDevice : false,
        );
        _message = 'Account status set to $nextStatus.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Unable to update account status.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      final confirmed = await _promptReauth(
        'Re-enter your password to issue a new temporary password for ${_account.fullName}.',
      );
      if (!confirmed) return;
      final creds = await widget.managementRepository.resetPassword(
        targetUid: _account.uid,
        fullName: _account.fullName,
        position: _account.position,
      );
      if (!mounted) return;
      setState(() {
        _account = AuthorizedAccountSummary(
          uid: _account.uid,
          loginId: _account.loginId,
          fullName: _account.fullName,
          position: _account.position,
          status: _account.status,
          active: _account.active,
          mustChangePassword: true,
          hasActiveDevice: _account.hasActiveDevice,
        );
      });
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('One-Time Temporary Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText('Login ID: ${creds.loginId}'),
              const SizedBox(height: 8),
              SelectableText('Temporary Password: ${creds.temporaryPassword}'),
              const SizedBox(height: 12),
              const Text(
                'This password is shown only once. Existing sessions and challenges have been invalidated.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: creds.temporaryPassword));
              },
              child: const Text('Copy Password'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Unable to reset temporary password.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revokeDevice() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      await widget.managementRepository.revokeDevice(targetUid: _account.uid);
      if (!mounted) return;
      setState(() {
        _account = AuthorizedAccountSummary(
          uid: _account.uid,
          loginId: _account.loginId,
          fullName: _account.fullName,
          position: _account.position,
          status: _account.status,
          active: _account.active,
          mustChangePassword: _account.mustChangePassword,
          hasActiveDevice: false,
        );
        _message = 'Enrolled biometric device revoked.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Unable to revoke enrolled device.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Authorized Account Details')),
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
                          'Login ID: ${_account.loginId}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text('Status: ${_account.status.toUpperCase()}'),
                        Text(
                          'Password Setup: ${_account.mustChangePassword ? 'Pending first-login change' : 'Complete'}',
                        ),
                        Text(
                          'Biometric Device: ${_account.hasActiveDevice ? 'Enrolled' : 'None / Revoked'}',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _fullName,
                  enabled: !_busy && !_account.isRevoked,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _position,
                  enabled: !_busy && !_account.isRevoked,
                  decoration: const InputDecoration(
                    labelText: 'Position or designation',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed:
                      _busy || _account.isRevoked ? null : _saveDetails,
                  child: const Text('Save Account Details'),
                ),
                const Divider(height: 32),
                if (!_account.isRevoked) ...[
                  if (_account.active)
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _changeStatus('suspend'),
                      icon: const Icon(Icons.pause_circle_outline),
                      label: const Text('Suspend Account'),
                    )
                  else
                    FilledButton.tonalIcon(
                      onPressed:
                          _busy ? null : () => _changeStatus('reactivate'),
                      icon: const Icon(Icons.play_circle_outline),
                      label: const Text('Reactivate Account'),
                    ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _resetPassword,
                    icon: const Icon(Icons.key_outlined),
                    label: const Text('Reset Temporary Password'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _revokeDevice,
                    icon: const Icon(Icons.phonelink_erase_outlined),
                    label: const Text('Revoke Enrolled Device'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                    ),
                    onPressed: _busy ? null : () => _changeStatus('revoke'),
                    icon: const Icon(Icons.block),
                    label: const Text('Permanently Revoke Access'),
                  ),
                ],
                if (_message != null) ...[
                  const SizedBox(height: 16),
                  Text(_message!,
                      style: TextStyle(color: Colors.green.shade800)),
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

class _AdminReauthDialog extends StatefulWidget {
  const _AdminReauthDialog({required this.reason});

  final String reason;

  @override
  State<_AdminReauthDialog> createState() => _AdminReauthDialogState();
}

class _AdminReauthDialogState extends State<_AdminReauthDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirm Admin Password'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.reason),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Admin password',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
