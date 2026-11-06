import 'package:flutter/material.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import '../services/tier1_qr_repository.dart';

class MyUnverifiedQrScreen extends StatefulWidget {
  const MyUnverifiedQrScreen({
    super.key,
    required this.repository,
    required this.onDashboard,
    this.onMedical,
    this.onStatus,
    this.onSignOut,
  });
  final Tier1QrRepository repository;
  final VoidCallback onDashboard;
  final VoidCallback? onMedical, onStatus, onSignOut;
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('My unverified QR')),
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
                  'TEST MODE — Synthetic pilot',
                  style: TextStyle(
                    color: Color(0xFFE92B32),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'UNVERIFIED — not proof of school enrollment',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                const Text(
                  'This QR is not a login credential, a medical-data key, or permission to access Tier 2. Public emergency resources do not require it.',
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
                if (failed) ...[
                  const Text(
                    'Unable to load your unverified QR. Please retry.',
                  ),
                  FilledButton(onPressed: load, child: const Text('Retry QR')),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: widget.onDashboard,
                  child: const Text('Go to Dashboard'),
                ),
                if (widget.onMedical != null)
                  TextButton(
                    onPressed: widget.onMedical,
                    child: const Text('View/Update Medical Record'),
                  ),
                if (widget.onStatus != null)
                  TextButton(
                    onPressed: widget.onStatus,
                    child: const Text('Registration status'),
                  ),
                if (widget.onSignOut != null)
                  OutlinedButton(
                    onPressed: widget.onSignOut,
                    child: const Text('Sign out'),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
