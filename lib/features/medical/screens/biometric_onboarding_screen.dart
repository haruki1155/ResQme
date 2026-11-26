import 'package:flutter/material.dart';
import '../../../core/widgets/feature_guide.dart';
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
  final _transferCode = TextEditingController();
  String _availability = 'checking';
  bool _needsTransferCode = false;
  bool _busy = false;
  bool _enrolled = false;
  String? _generatedTransferCode;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkAvailability();
  }

  @override
  void dispose() {
    _password.dispose();
    _transferCode.dispose();
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
      await widget.repository.enrollBiometricDeviceWithPassword(
        _password.text,
        transferCode: _transferCode.text,
      );
      if (!mounted) return;
      setState(() {
        _enrolled = true;
        _needsTransferCode = false;
        _password.clear();
        _transferCode.clear();
      });
    } catch (error) {
      if (!mounted) return;
      final msg = error is Tier2AuthorizationFailure
          ? error.message
          : 'Biometric security setup could not be completed.';
      setState(() {
        if (msg.toLowerCase().contains('another personal device')) {
          _needsTransferCode = true;
        }
        _error = msg;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _generateTransferCode({String? passwordOverride}) async {
    if (_busy) return;
    var pwd = passwordOverride ?? _password.text;
    if (pwd.isEmpty) {
      final ctrl = TextEditingController();
      final entered = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirm Account Password'),
          content: TextField(
            controller: ctrl,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'ResQMe account password',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(ctrl.text),
              child: const Text('Verify with Biometrics'),
            ),
          ],
        ),
      );
      ctrl.dispose();
      if (entered == null || entered.isEmpty || !mounted) return;
      pwd = entered;
    }

    setState(() {
      _busy = true;
      _error = null;
      _generatedTransferCode = null;
    });
    try {
      final code = await widget.repository.approveTrustedDeviceTransfer(pwd);
      if (!mounted) return;
      setState(() {
        _password.clear();
        _generatedTransferCode = code;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is Tier2AuthorizationFailure
            ? error.message
            : 'Unable to generate device transfer code.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Biometric Security Setup'),
        actions: [
          FeatureGuideIconButton(
            guide: ResQMeFeatureGuides.studentBiometrics,
            accountScope: widget.repository.currentUid ?? 'guest',
          ),
        ],
      ),
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
                onPressed: _busy ? null : widget.onContinue,
                child: const Text('Continue to My QR'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _generateTransferCode(),
                icon: const Icon(Icons.phonelink_setup_outlined),
                label: const Text('Generate transfer code for new phone'),
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
              if (_needsTransferCode) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF59E0B)),
                  ),
                  child: const Text(
                    'Another personal device is currently enrolled for biometric Tier 2 access. Password login never silently replaces your trusted device. Enter a transfer code generated on your previous device, or ask your school Master Admin to reset your lost device first.',
                    style: TextStyle(fontSize: 13, height: 1.45),
                  ),
                ),
                TextField(
                  controller: _transferCode,
                  enabled: !_busy,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Trusted-device transfer code (TDX-...)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
              ],
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
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: _busy ? null : () => _generateTransferCode(),
                icon: const Icon(Icons.phonelink_setup_outlined, size: 18),
                label: const Text('Switching phones? Generate transfer code'),
              ),
            ],
            if (_generatedTransferCode != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: SelectableText(
                  'Transfer Code (valid 10 min): $_generatedTransferCode\nEnter this code on your replacement personal phone during Biometric Security Setup.',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
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
