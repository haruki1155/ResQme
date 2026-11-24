import 'package:flutter/material.dart';
import '../services/staff_access_repository.dart';
import 'master_admin_email_screen.dart';
import 'staff_change_password_screen.dart';

class StaffAccountSetupScreen extends StatefulWidget {
  const StaffAccountSetupScreen({
    super.key,
    required this.accessRepository,
    required this.access,
    required this.onSetupUpdated,
    required this.onSignOut,
  });

  final StaffAccessRepository accessRepository;
  final StaffAccess access;
  final ValueChanged<StaffAccess> onSetupUpdated;
  final VoidCallback onSignOut;

  @override
  State<StaffAccountSetupScreen> createState() =>
      _StaffAccountSetupScreenState();
}

class _StaffAccountSetupScreenState extends State<StaffAccountSetupScreen> {
  bool _busy = false;
  String? _message;

  Future<void> _refresh() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final updated = widget.access.requiresEmailVerification
          ? await widget.accessRepository.reloadAndSyncEmail()
          : await widget.accessRepository.loadAccess();
      if (!mounted) return;
      widget.onSetupUpdated(updated);
    } catch (_) {
      if (!mounted) return;
      setState(() => _message = 'Unable to refresh account setup status.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final access = widget.access;
    final title = access.isMasterAdmin
        ? 'Master Admin Account Setup'
        : 'Account Password Setup';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: _busy ? null : widget.onSignOut,
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
                Text(
                  access.isMasterAdmin
                      ? 'Complete the required security setup steps before managing Authorized personnel or accessing Tier 2 emergency tools.'
                      : 'Set a personal strong password before enrolling your biometric device or accessing Tier 2 emergency tools.',
                ),
                const SizedBox(height: 20),
                Card(
                  child: ListTile(
                    leading: Icon(
                      access.mustChangePassword
                          ? Icons.lock_outline
                          : Icons.check_circle,
                      color: access.mustChangePassword
                          ? Colors.orange
                          : Colors.green,
                    ),
                    title: const Text('1. Set New Password'),
                    subtitle: Text(
                      access.mustChangePassword
                          ? 'Required before continuing'
                          : 'Completed',
                    ),
                    trailing: access.mustChangePassword
                        ? FilledButton(
                            onPressed: _busy
                                ? null
                                : () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) =>
                                            StaffChangePasswordScreen(
                                          accessRepository:
                                              widget.accessRepository,
                                          isMandatoryFirstLogin: true,
                                          onCompleted: () {
                                            Navigator.of(context).pop();
                                          },
                                        ),
                                      ),
                                    );
                                    await _refresh();
                                  },
                            child: const Text('Set Password'),
                          )
                        : null,
                  ),
                ),
                if (access.requiresEmailVerification) ...[
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      leading: Icon(
                        access.emailVerified
                            ? Icons.check_circle
                            : Icons.mark_email_unread_outlined,
                        color:
                            access.emailVerified ? Colors.green : Colors.orange,
                      ),
                      title: const Text('2. Verify Master Admin Email'),
                      subtitle: Text(
                        access.emailVerified
                            ? 'Verified'
                            : 'Required via Firebase Authentication link',
                      ),
                      trailing: !access.emailVerified
                          ? FilledButton(
                              onPressed: _busy
                                  ? null
                                  : () async {
                                      await Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) =>
                                              MasterAdminEmailScreen(
                                            accessRepository:
                                                widget.accessRepository,
                                            access: access,
                                            onAccessUpdated:
                                                widget.onSetupUpdated,
                                          ),
                                        ),
                                      );
                                      await _refresh();
                                    },
                              child: const Text('Verify Email'),
                            )
                          : null,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _refresh,
                  icon: const Icon(Icons.refresh),
                  label: Text(_busy ? 'Checking…' : 'Refresh Setup Status'),
                ),
                if (_message != null) ...[
                  const SizedBox(height: 12),
                  Text(_message!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
