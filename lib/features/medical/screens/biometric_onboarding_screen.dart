import 'package:flutter/material.dart';
import '../services/tier2_authorization_repository.dart';

class BiometricOnboardingScreen extends StatefulWidget {
  const BiometricOnboardingScreen({
    super.key,
    required this.repository,
    required this.onContinue,
  });

  final Tier2AuthorizationRepository repository;
  final VoidCallback onContinue;

  @override
  State<BiometricOnboardingScreen> createState() =>
      _BiometricOnboardingScreenState();
}

class _BiometricOnboardingScreenState extends State<BiometricOnboardingScreen> {
  final _password = TextEditingController();
  String _availability = 'checking';
  bool _busy = false;
  bool _enrolled = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkAvailability();
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _checkAvailability() async {
    setState(() {
      _availability = 'checking';
      _error = null;
    });
    final status = await widget.repository.checkBiometricAvailability();
    if (!mounted) return;
    setState(() => _availability = status);
  }

  Future<void> _enroll() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.enrollBiometricDeviceWithPassword(_password.text);
      if (!mounted) return;
      setState(() {
        _enrolled = true;
        _password.clear();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is Tier2AuthorizationFailure
            ? error.message
            : 'Biometric security setup could not be completed.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Biometric Security Setup')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'BIOMETRIC SECURITY',
              style: TextStyle(
                color: Color(0xFFE92B32),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _enrolled
                  ? 'Biometric Security Active'
                  : 'Protect your private medical record',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 10),
            const Text(
              'ResQMe uses your device hardware keystore and Android BiometricPrompt to protect your Tier 2 medical information. Your fingerprint data never leaves your device.',
            ),
            const SizedBox(height: 20),
            if (_enrolled) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified_user, color: Color(0xFF15803D)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your trusted biometric key is verified and active for this account.',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: widget.onContinue,
                child: const Text('Continue to My QR'),
              ),
            ] else if (_availability == 'checking') ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
            ] else if (_availability == 'biometric_not_enrolled') ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFCD34D)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No strong biometric enrolled',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '1. Open Android Settings > Security > Fingerprint or Biometrics.\n'
                      '2. Enroll at least one fingerprint on this device.\n'
                      '3. Return to ResQMe and tap Check Again.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _checkAvailability,
                icon: const Icon(Icons.refresh),
                label: const Text('Check Again'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: widget.onContinue,
                child: const Text('Continue to My QR for now'),
              ),
            ] else if (_availability != 'ready') ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Biometric hardware unavailable',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Strong hardware-backed biometrics are not available on this device. You can still view your QR code and use password verification for Tier 2.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _checkAvailability,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry hardware check'),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: widget.onContinue,
                child: const Text('Continue to My QR'),
              ),
            ] else ...[
              TextField(
                controller: _password,
                enabled: !_busy,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                decoration: const InputDecoration(
                  labelText: 'Confirm your ResQMe account password',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _busy ? null : _enroll,
                icon: const Icon(Icons.fingerprint),
                label: Text(
                  _busy ? 'Waiting for biometric confirmation…' : 'Set Up Biometrics',
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _busy ? null : widget.onContinue,
                child: const Text('Skip for now and view My QR'),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
    );
  }
}
