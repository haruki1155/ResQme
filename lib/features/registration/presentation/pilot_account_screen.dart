import 'package:flutter/material.dart';
import '../../../app/app_routes.dart';
import '../../medical/screens/synthetic_medical_screen.dart';
import '../../medical/services/synthetic_medical_repository.dart';
import '../../qr/screens/my_unverified_qr_screen.dart';
import '../../qr/services/tier1_qr_repository.dart';
import '../models/student_registration_profile.dart';

class PilotAccountScreen extends StatefulWidget {
  const PilotAccountScreen({
    super.key,
    required this.profile,
    required this.medical,
    required this.qr,
    required this.onPublicDashboard,
    required this.onSignOut,
    this.openMedical = false,
    this.onMedicalCompleted,
  });
  final StudentRegistrationProfile profile;
  final SyntheticMedicalRepository medical;
  final Tier1QrRepository qr;
  final VoidCallback onPublicDashboard, onSignOut;
  final bool openMedical;
  final VoidCallback? onMedicalCompleted;
  @override
  State<PilotAccountScreen> createState() => _PilotAccountScreenState();
}

class _PilotAccountScreenState extends State<PilotAccountScreen> {
  late String step;
  @override
  void initState() {
    super.initState();
    step = widget.openMedical ? 'medical' : 'qr';
  }

  @override
  Widget build(BuildContext context) => switch (step) {
    'medical' => SyntheticMedicalScreen(
      repository: widget.medical,
      isMinor: widget.profile.ageYearsAtRegistration < 18,
      onContinue: () {
        widget.onMedicalCompleted?.call();
        setState(() => step = 'qr');
      },
    ),
    'qr' => MyUnverifiedQrScreen(
      repository: widget.qr,
      onDashboard: widget.onPublicDashboard,
      onScan: () => Navigator.pushNamed(context, AppRoutes.scanner),
      onSignOut: widget.onSignOut,
    ),
    _ => const SizedBox.shrink(),
  };
}
