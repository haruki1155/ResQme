import 'package:flutter/material.dart';
import '../services/staff_tier2_repository.dart';

class StaffDeviceSetupScreen extends StatefulWidget {
  const StaffDeviceSetupScreen({super.key, required this.client});

  final StaffTier2Client client;

  @override
  State<StaffDeviceSetupScreen> createState() => _StaffDeviceSetupScreenState();
}

class _StaffDeviceSetupScreenState extends State<StaffDeviceSetupScreen> {
  final _password = TextEditingController();
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function(String) action, String ok) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action(_password.text);
      _password.clear();
      if (mounted) setState(() => _message = ok);
    } catch (error) {
      _password.clear();
      if (mounted) {
        setState(() {
          _message = error is StaffTier2Failure
              ? error.message
              : 'Device operation could not complete.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trusted Device Biometrics')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text(
                  'Enroll this device with hardware-backed biometrics to authorize emergency Tier 2 QR reads. Re-enrolling automatically replaces any previous key.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _password,
                  enabled: !_busy,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm staff account password',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _run(
                            widget.client.enrollDeviceWithPassword,
                            'Trusted staff device enrolled.',
                          ),
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Enroll this device'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _run(
                            widget.client.revokeDeviceWithPassword,
                            'Trusted staff device revoked.',
                          ),
                  icon: const Icon(Icons.block),
                  label: const Text('Revoke enrolled device'),
                ),
                if (_message != null) ...[
                  const SizedBox(height: 16),
                  Text(_message!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
