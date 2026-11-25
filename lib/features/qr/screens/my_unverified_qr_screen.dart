import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import '../services/tier1_qr_repository.dart';

class MyUnverifiedQrScreen extends StatefulWidget {
  const MyUnverifiedQrScreen({
    super.key,
    required this.repository,
    required this.onDashboard,
    this.onSignOut,
    this.onScan,
    this.onTier2,
    this.onCompleteMedical,
    this.medicalComplete = false,
  });
  final Tier1QrRepository repository;
  final VoidCallback onDashboard;
  final VoidCallback? onScan, onSignOut;
  final VoidCallback? onTier2;
  final VoidCallback? onCompleteMedical;
  final bool medicalComplete;
  @override
  State<MyUnverifiedQrScreen> createState() => _MyUnverifiedQrScreenState();
}

class _MyUnverifiedQrScreenState extends State<MyUnverifiedQrScreen> {
  Tier1QrCredential? credential;
  bool loading = true, failed = false;
  @override
  void initState() {
    super.initState();
    load();
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
                if (credential != null)
                  OutlinedButton(
                    onPressed: loading ? null : replace,
                    child: const Text('Replace QR'),
                  ),
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
                FilledButton(
                  onPressed: widget.onDashboard,
                  child: const Text('Go to Dashboard'),
                ),
                if (widget.onTier2 != null)
                  OutlinedButton(
                    onPressed: widget.onTier2,
                    child: const Text('Access Tier 2'),
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
