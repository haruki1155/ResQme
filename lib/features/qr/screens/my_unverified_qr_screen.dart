import 'package:flutter/material.dart';
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
  });
  final Tier1QrRepository repository;
  final VoidCallback onDashboard;
  final VoidCallback? onScan, onSignOut;
  final VoidCallback? onTier2;
  @override
  State<MyUnverifiedQrScreen> createState() => _MyUnverifiedQrScreenState();
}

class _MyUnverifiedQrScreenState extends State<MyUnverifiedQrScreen> {
  String? payload;
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
      payload = null;
    });
    try {
      final result = await widget.repository.ensureMine();
      if (mounted) {
        setState(() => payload = result);
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
      payload = null;
    });
    try {
      final result = await widget.repository.replaceMine();
      if (mounted) setState(() => payload = result);
    } catch (_) {
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('My ResQMe QR')),
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
                  'Active after school approval',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Scanning confirms this QR is active for Tier 1 public emergency resources. It does not sign the holder into the student account or reveal private student information.',
                ),
                const SizedBox(height: 24),
                if (loading) const Center(child: CircularProgressIndicator()),
                if (payload != null)
                  Center(
                    child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(24),
                      child: SizedBox.square(
                        dimension: 240,
                        child: PrettyQrView.data(data: payload!),
                      ),
                    ),
                  ),
                if (payload != null)
                  OutlinedButton(
                    onPressed: loading ? null : replace,
                    child: const Text('Replace QR'),
                  ),
                if (failed) ...[
                  const Text(
                    'Your QR is not available yet. Complete required information and wait for school approval, then retry.',
                  ),
                  FilledButton(onPressed: load, child: const Text('Retry QR')),
                  OutlinedButton(onPressed: loading ? null : replace, child: const Text('Generate a new QR')),
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
