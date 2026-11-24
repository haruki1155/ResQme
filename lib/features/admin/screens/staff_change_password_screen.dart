import 'package:flutter/material.dart';
import '../services/staff_access_repository.dart';

class StaffChangePasswordScreen extends StatefulWidget {
  const StaffChangePasswordScreen({
    super.key,
    required this.accessRepository,
    this.isMandatoryFirstLogin = false,
    this.onCompleted,
  });

  final StaffAccessRepository accessRepository;
  final bool isMandatoryFirstLogin;
  final VoidCallback? onCompleted;

  @override
  State<StaffChangePasswordScreen> createState() =>
      _StaffChangePasswordScreenState();
}

class _StaffChangePasswordScreenState extends State<StaffChangePasswordScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? _validate(String next, String confirm) {
    if (next.length < 12) {
      return 'New password must be at least 12 characters.';
    }
    if (!RegExp(r'[A-Z]').hasMatch(next) ||
        !RegExp(r'[a-z]').hasMatch(next) ||
        !RegExp(r'[0-9]').hasMatch(next) ||
        !RegExp(r'[^A-Za-z0-9]').hasMatch(next)) {
      return 'Include uppercase, lowercase, a number, and a symbol.';
    }
    if (next != confirm) {
      return 'Passwords do not match.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_busy) return;
    final validationError = _validate(_next.text, _confirm.text);
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.accessRepository.changePassword(
        currentPassword: _current.text,
        newPassword: _next.text,
      );
      _current.clear();
      _next.clear();
      _confirm.clear();
      if (!mounted) return;
      if (widget.onCompleted != null) {
        widget.onCompleted!();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password updated.')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is StaffAccessDenied
            ? error.message
            : 'Unable to update password. Check your current password and try again.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isMandatoryFirstLogin ? 'Set New Password' : 'Change Password',
        ),
        automaticallyImplyLeading: !widget.isMandatoryFirstLogin,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  widget.isMandatoryFirstLogin
                      ? 'You must set a new strong password before accessing ResQMe emergency tools.'
                      : 'Re-enter your current password and choose a new strong password (at least 12 characters with uppercase, lowercase, number, and symbol).',
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _current,
                  enabled: !_busy,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Current password',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _next,
                  enabled: !_busy,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'New password',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _confirm,
                  enabled: !_busy,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm new password',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                if (_error != null) ...[
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 12),
                ],
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: Text(_busy ? 'Updating…' : 'Update Password'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
