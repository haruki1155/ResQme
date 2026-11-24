import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/staff_management_repository.dart';

class CreateAuthorizedAccountScreen extends StatefulWidget {
  const CreateAuthorizedAccountScreen({
    super.key,
    required this.managementRepository,
  });

  final StaffManagementRepository managementRepository;

  @override
  State<CreateAuthorizedAccountScreen> createState() =>
      _CreateAuthorizedAccountScreenState();
}

class _CreateAuthorizedAccountScreenState
    extends State<CreateAuthorizedAccountScreen> {
  final _fullName = TextEditingController();
  final _position = TextEditingController();
  bool _busy = false;
  String? _error;
  IssuedAuthorizedCredentials? _issued;

  @override
  void dispose() {
    _fullName.dispose();
    _position.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final name = _fullName.text.trim();
    final pos = _position.text.trim();
    if (name.length < 2 || pos.length < 2) {
      setState(() => _error = 'Enter both full name and position/designation.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final creds = await widget.managementRepository.createAccount(
        fullName: name,
        position: pos,
      );
      if (!mounted) return;
      setState(() => _issued = creds);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Unable to create Authorized account.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy(String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied to clipboard.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final issued = _issued;
    return Scaffold(
      appBar: AppBar(title: const Text('Create Authorized Account')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (issued == null) ...[
                  const Text(
                    'Issue a school-scoped Authorized staff account. The backend generates a unique Login ID and one-time temporary password. No personal email or OTP is required.',
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _fullName,
                    enabled: !_busy,
                    decoration: const InputDecoration(
                      labelText: 'Full name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _position,
                    enabled: !_busy,
                    decoration: const InputDecoration(
                      labelText: 'Position or designation',
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
                    child: Text(
                      _busy ? 'Creating…' : 'Create Authorized Account',
                    ),
                  ),
                ] else ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'One-Time Initial Credentials',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text('Name: ${issued.fullName}'),
                          Text('Position: ${issued.position}'),
                          const Divider(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: SelectableText(
                                  'Login ID: ${issued.loginId}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Copy Login ID',
                                onPressed: () =>
                                    _copy('Login ID', issued.loginId),
                                icon: const Icon(Icons.copy),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: SelectableText(
                                  'Temporary Password: ${issued.temporaryPassword}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Copy Temporary Password',
                                onPressed: () => _copy(
                                  'Temporary password',
                                  issued.temporaryPassword,
                                ),
                                icon: const Icon(Icons.copy),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'This temporary password is shown only once and cannot be retrieved later. The user will be required to set a new password on first login.',
                            style: TextStyle(color: Colors.orange.shade900),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Done'),
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
