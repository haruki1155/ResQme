import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import '../../medical/services/tier2_authorization_repository.dart';
import '../services/tier1_qr_repository.dart';

class MyUnverifiedQrScreen extends StatefulWidget {
  const MyUnverifiedQrScreen({
    super.key,
    required this.repository,
    required this.onDashboard,
    this.onSignOut,
    this.onScan,
    this.onTier2,
    this.onSetupBiometrics,
    this.onCompleteMedical,
    this.medicalComplete = false,
    this.studentFullName,
    this.tier2Repository,
  });

  final Tier1QrRepository repository;
  final VoidCallback onDashboard;
  final VoidCallback? onScan, onSignOut;
  final VoidCallback? onTier2;
  final VoidCallback? onSetupBiometrics;
  final VoidCallback? onCompleteMedical;
  final bool medicalComplete;
  final String? studentFullName;
  final Tier2AuthorizationRepository? tier2Repository;

  @override
  State<MyUnverifiedQrScreen> createState() => _MyUnverifiedQrScreenState();
}

class _MyUnverifiedQrScreenState extends State<MyUnverifiedQrScreen>
    with WidgetsBindingObserver {
  Tier1QrCredential? credential;
  bool loading = true, failed = false;
  bool _biometricEnrolled = false;
  bool _revealingIdentity = false;
  String? _revealedSurname;
  String? _revealedLrn;
  String? _revealError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
    _checkBiometricStatus();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ((state == AppLifecycleState.paused ||
            state == AppLifecycleState.hidden) &&
        mounted) {
      setState(() {
        _revealedSurname = null;
        _revealedLrn = null;
        _revealError = null;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _revealedSurname = null;
    _revealedLrn = null;
    super.dispose();
  }

  Future<void> _checkBiometricStatus() async {
    final repo = widget.tier2Repository;
    if (repo == null) return;
    final enrolled = await repo.isBiometricEnrolled();
    if (mounted) {
      setState(() => _biometricEnrolled = enrolled);
    }
  }

  String _censoredSurname() {
    final raw = widget.studentFullName?.trim() ?? '';
    if (raw.isEmpty) return '••••••';
    final parts = raw.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '••••••';
    final surname = parts.last;
    if (surname.length <= 1) return '••••••';
    return '${surname[0]}${'•' * (surname.length - 1)}';
  }

  Future<void> _revealIdentity() async {
    final repo = widget.tier2Repository;
    if (repo == null || _revealingIdentity) return;
    setState(() {
      _revealingIdentity = true;
      _revealError = null;
    });
    try {
      final result = await repo.revealOwnIdentityWithBiometrics();
      if (!mounted) return;
      setState(() {
        _revealedSurname = result['surname'];
        _revealedLrn = result['lrn'];
        _biometricEnrolled = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _revealError = error is Tier2AuthorizationFailure
            ? error.message
            : 'Biometric verification is required to view surname and LRN.';
      });
    } finally {
      if (mounted) setState(() => _revealingIdentity = false);
    }
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      failed = false;
      credential = null;
    });
    try {
      final result = await widget.repository.ensureMineCredential();
      if (mounted) {
        setState(() => credential = result);
      }
    } catch (_) {
      if (mounted) {
        setState(() => failed = true);
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
    await _checkBiometricStatus();
  }

  Future<void> replace() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Replace this QR?'),
        content: const Text(
          'The current QR will stop working as soon as the new one is created.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Replace QR'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      loading = true;
      failed = false;
      credential = null;
    });
    try {
      final result = await widget.repository.replaceMineCredential();
      if (mounted) setState(() => credential = result);
    } catch (_) {
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Widget _buildCensoredIdentityCard() {
    final revealed = _revealedSurname != null || _revealedLrn != null;
    final surnameDisplay = revealed && (_revealedSurname?.isNotEmpty == true)
        ? _revealedSurname!
        : _censoredSurname();
    final lrnDisplay = revealed && (_revealedLrn?.isNotEmpty == true)
        ? _revealedLrn!
        : '•••• •••• ••••';

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5EAF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.badge_outlined,
                size: 18,
                color: Color(0xFFE92B32),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'PROTECTED STUDENT IDENTITY',
                  style: TextStyle(
                    color: Color(0xFF7B879B),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              if (revealed)
                TextButton(
                  onPressed: () => setState(() {
                    _revealedSurname = null;
                    _revealedLrn = null;
                  }),
                  child: const Text('Hide'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SURNAME',
                      style: TextStyle(
                        color: Color(0xFF7B879B),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      surnameDisplay,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'LRN',
                      style: TextStyle(
                        color: Color(0xFF7B879B),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lrnDisplay,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!revealed && widget.tier2Repository != null) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _revealingIdentity ? null : _revealIdentity,
              icon: const Icon(Icons.fingerprint),
              label: Text(
                _revealingIdentity
                    ? 'Verifying biometrics…'
                    : 'View with Biometrics',
              ),
            ),
          ],
          if (_revealError != null) ...[
            const SizedBox(height: 8),
            Text(
              _revealError!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('My ResQMe QR'),
      actions: [
        IconButton(
          tooltip: 'Refresh QR',
          onPressed: loading ? null : load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'RESQME QR CREDENTIAL',
                  style: TextStyle(
                    color: Color(0xFFE92B32),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  credential?.verificationStatus == 'pending'
                      ? 'Pending Verification'
                      : 'Active Tier 1 QR',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                Text(
                  credential?.verificationStatus == 'pending'
                      ? 'This QR is not active yet. It does not sign anyone in or reveal student information. Public Tier 1 emergency resources remain available while school review is pending.'
                      : 'Scanning confirms this QR is active for Tier 1 public emergency resources. It does not sign the holder into the student account or reveal private student information.',
                ),
                const SizedBox(height: 24),
                if (loading) const Center(child: CircularProgressIndicator()),
                if (credential != null)
                  Center(
                    child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(24),
                      child: SizedBox.square(
                        dimension: 240,
                        child: PrettyQrView.data(data: credential!.payload),
                      ),
                    ),
                  ),
                if (credential != null) _buildCensoredIdentityCard(),
                if (credential != null) ...[
                  const SizedBox(height: 14),
                  OutlinedButton(
                    onPressed: loading ? null : replace,
                    child: const Text('Replace QR'),
                  ),
                ],
                if (credential?.verificationStatus == 'pending' &&
                    widget.onCompleteMedical != null &&
                    !widget.medicalComplete)
                  OutlinedButton.icon(
                    onPressed: widget.onCompleteMedical,
                    icon: const Icon(Icons.medical_information_outlined),
                    label: const Text('Complete Medical Information'),
                  ),
                if (credential?.verificationStatus == 'pending' &&
                    widget.repository.ownerReference != null)
                  Card(
                    child: ListTile(
                      title: const Text('School review reference'),
                      subtitle: SelectableText(
                        widget.repository.ownerReference!,
                      ),
                      trailing: IconButton(
                        tooltip: 'Copy review reference',
                        icon: const Icon(Icons.copy),
                        onPressed: () => Clipboard.setData(
                          ClipboardData(
                            text: widget.repository.ownerReference!,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (failed) ...[
                  const Text(
                    'Your QR is not available yet. Complete required information and wait for school approval, then retry.',
                  ),
                  FilledButton(onPressed: load, child: const Text('Retry QR')),
                  OutlinedButton(
                    onPressed: loading ? null : replace,
                    child: const Text('Generate a new QR'),
                  ),
                ],
                const SizedBox(height: 24),
                if (widget.onSetupBiometrics != null && !_biometricEnrolled)
                  OutlinedButton.icon(
                    onPressed: widget.onSetupBiometrics,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Biometric Security Setup'),
                  ),
                if (widget.onScan != null)
                  TextButton(
                    onPressed: widget.onScan,
                    child: const Text('Scan another QR'),
                  ),
                if (widget.onSignOut != null)
                  OutlinedButton(
                    onPressed: widget.onSignOut,
                    child: const Text('Logout'),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
