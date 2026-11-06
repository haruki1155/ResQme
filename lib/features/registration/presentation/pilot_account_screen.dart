import 'package:flutter/material.dart';
import '../../medical/screens/synthetic_medical_screen.dart';
import '../../medical/services/synthetic_medical_repository.dart';
import '../../qr/screens/my_unverified_qr_screen.dart';
import '../../qr/services/tier1_qr_repository.dart';
import '../models/student_registration_profile.dart';
import '../screens/registration_pending_screen.dart';

class PilotAccountScreen extends StatefulWidget {
  const PilotAccountScreen({
    super.key,
    required this.profile,
    required this.medical,
    required this.qr,
    required this.onPublicDashboard,
    required this.onSignOut,
    this.onRefreshStatus,
    this.openMedical = false,
  });
  final StudentRegistrationProfile profile;
  final SyntheticMedicalRepository medical;
  final Tier1QrRepository qr;
  final VoidCallback onPublicDashboard, onSignOut;
  final VoidCallback? onRefreshStatus;
  final bool openMedical;
  @override
  State<PilotAccountScreen> createState() => _PilotAccountScreenState();
}

class _PilotAccountScreenState extends State<PilotAccountScreen> {
  String step = 'loading';
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => step = 'loading');
    try {
      final existing = widget.openMedical ? null : await widget.qr.loadMine();
      if (mounted) {
        setState(() => step = existing == null ? 'medical' : 'qr');
      }
    } catch (_) {
      if (mounted) {
        setState(() => step = 'error');
      }
    }
  }

  @override
  Widget build(BuildContext context) => switch (step) {
    'medical' => SyntheticMedicalScreen(
      repository: widget.medical,
      isMinor: widget.profile.ageYearsAtRegistration < 18,
      onContinue: () => setState(() => step = 'qr'),
    ),
    'qr' => MyUnverifiedQrScreen(
      repository: widget.qr,
      onDashboard: widget.onPublicDashboard,
      onMedical: () => setState(() => step = 'medical'),
      onStatus: () => setState(() => step = 'status'),
      onSignOut: widget.onSignOut,
    ),
    'status' => RegistrationPendingScreen(
      profile: widget.profile,
      onRefreshStatus: widget.onRefreshStatus ?? load,
      onPublicDashboard: widget.onPublicDashboard,
      onSignOut: widget.onSignOut,
    ),
    _ => Scaffold(
      appBar: AppBar(title: const Text('Student Account')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (step == 'loading') const CircularProgressIndicator(),
            if (step == 'error') ...[
              const Text('Account state unavailable. Please retry.'),
              TextButton(onPressed: load, child: const Text('Retry account')),
            ],
            TextButton(
              onPressed: widget.onPublicDashboard,
              child: const Text('Return to public dashboard'),
            ),
          ],
        ),
      ),
    ),
  };
}
