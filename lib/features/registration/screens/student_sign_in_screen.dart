import 'package:flutter/material.dart';
import '../services/student_registration_repository.dart';
import 'create_student_account_screen.dart';
import 'student_login_qr_screen.dart';

class StudentSignInScreen extends StatefulWidget {
  const StudentSignInScreen({
    super.key,
    required this.repository,
    required this.onSignedIn,
    this.onRegistered,
    this.loginQrScannerBuilder,
  });
  final StudentRegistrationRepository repository;
  final VoidCallback onSignedIn;
  final VoidCallback? onRegistered;
  final Widget Function(ValueChanged<String> onScanned)? loginQrScannerBuilder;
  @override
  State<StudentSignInScreen> createState() => _StudentSignInScreenState();
}

class _StudentSignInScreenState extends State<StudentSignInScreen> {
  void createAccount() {
    final navigator = Navigator.of(context);
    final onSignedIn = widget.onRegistered ?? widget.onSignedIn;
    navigator.push<void>(
      MaterialPageRoute(
        builder: (_) => CreateStudentAccountScreen(
          repository: widget.repository,
          onRegistered: () {
            if (navigator.mounted) {
              navigator.pop();
              onSignedIn();
            }
          },
        ),
      ),
    );
  }

  final form = GlobalKey<FormState>();
  final email = TextEditingController(), password = TextEditingController();
  bool busy = false;
  String? message;
  String? _qrResolvedEmail;
  String? _qrMaskedEmail;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  bool get validEmail =>
      _qrResolvedEmail != null ||
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email.text.trim());

  Future<void> _scanLoginQr() async {
    if (busy) return;
    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (routeContext) => widget.loginQrScannerBuilder != null
            ? widget.loginQrScannerBuilder!(
                (raw) => Navigator.of(routeContext).pop(raw),
              )
            : StudentLoginQrScannerScreen(
                onScanned: (raw) => Navigator.of(routeContext).pop(raw),
              ),
      ),
    );
    if (scanned == null || scanned.trim().isEmpty || !mounted) return;
    setState(() {
      busy = true;
      message = null;
    });
    final res = await widget.repository.resolveLoginQr(scanned);
    if (!mounted) return;
    setState(() {
      busy = false;
      if (res.resolved && res.email != null && res.maskedEmail != null) {
        _qrResolvedEmail = res.email;
        _qrMaskedEmail = res.maskedEmail;
        email.clear();
        password.clear();
        message = null;
      } else {
        _qrResolvedEmail = null;
        _qrMaskedEmail = null;
        message = res.message;
      }
    });
  }

  void _clearQrAccount() {
    setState(() {
      _qrResolvedEmail = null;
      _qrMaskedEmail = null;
      password.clear();
      message = null;
    });
  }

  Future<void> signIn() async {
    if (busy || !form.currentState!.validate()) return;
    final targetEmail = _qrResolvedEmail ?? email.text;
    setState(() {
      busy = true;
      message = null;
    });
    final result = await widget.repository.signIn(targetEmail, password.text);
    if (!mounted) return;
    setState(() {
      busy = false;
      message = result.message;
    });
    if ([
      RegistrationState.pending,
      RegistrationState.authCreatedProfileIncomplete,
    ].contains(result.state)) {
      password.clear();
      _qrResolvedEmail = null;
      _qrMaskedEmail = null;
      widget.onSignedIn();
    }
  }

  Future<void> reset() async {
    if (busy) return;
    final targetEmail = _qrResolvedEmail ?? email.text;
    final okEmail = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
        .hasMatch(targetEmail.trim());
    if (!okEmail) {
      setState(() => message = 'Enter your recovery email first.');
      return;
    }
    setState(() => busy = true);
    final result = await widget.repository.sendPasswordReset(targetEmail);
    if (mounted) {
      setState(() {
        busy = false;
        message = result.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Student Account')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Form(
              key: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  const Icon(
                    Icons.health_and_safety_outlined,
                    size: 64,
                    color: Color(0xFFE92B32),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Welcome to ResQMe',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sign in to view your account and emergency readiness status. Public emergency resources remain available without an account.',
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: busy ? null : _scanLoginQr,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scan Login QR'),
                  ),
                  const SizedBox(height: 16),
                  if (_qrMaskedEmail != null) ...[
                    Card(
                      color: const Color(0xFFF8FAFC),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.verified_user_outlined,
                              color: Color(0xFFE92B32),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Account identified via Login QR',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(_qrMaskedEmail!),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: busy ? null : _clearQrAccount,
                              child: const Text('Change'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      color: const Color(0xFFFFF8E1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFFF59E0B)),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Color(0xFFB45309),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Shared or Unfamiliar Device Security Notice: Enter your password below to finish signing in. Password login on another device will not transfer your personal biometric Tier 2 device keys. Always sign out when finished on a shared device.',
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    TextFormField(
                      controller: email,
                      enabled: !busy,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      validator: (_) =>
                          validEmail ? null : 'Enter a valid email.',
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: password,
                    enabled: !busy,
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        (value ?? '').isEmpty ? 'Enter your password.' : null,
                  ),
                  const SizedBox(height: 16),
                  if (message != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(message!),
                    ),
                  FilledButton(
                    onPressed: busy ? null : signIn,
                    child: Text(busy ? 'Please wait…' : 'Sign in'),
                  ),
                  TextButton(
                    onPressed: busy ? null : reset,
                    child: const Text('Forgot password'),
                  ),
                  OutlinedButton(
                    onPressed: busy ? null : createAccount,
                    child: const Text('Create account'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Return to public dashboard'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
