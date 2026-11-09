import 'package:flutter/material.dart';
import '../../../app/app_routes.dart';
import '../../medical/screens/synthetic_medical_screen.dart';
import '../../medical/services/synthetic_medical_repository.dart';
import '../../medical/services/medical_completion_repository.dart';
import '../../medical/screens/medical_completion_screen.dart';
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
    this.completion,
    this.onTier2,
  });
  final StudentRegistrationProfile profile;
  final SyntheticMedicalRepository medical;
  final Tier1QrRepository qr;
  final VoidCallback onPublicDashboard, onSignOut;
  final bool openMedical;
  final VoidCallback? onMedicalCompleted;
  final MedicalCompletionRepository? completion;
  final VoidCallback? onTier2;
  @override
  State<PilotAccountScreen> createState() => _PilotAccountScreenState();
}

class _PilotAccountScreenState extends State<PilotAccountScreen> {
  late String step;
  String _eligibleStep(StudentRegistrationProfile profile) =>
      profile.medicalStatus != 'complete'
      ? 'medical'
      : profile.schoolApprovalStatus == 'approved'
      ? 'qr'
      : 'approval';
  @override
  void initState() {
    super.initState();
    step = widget.completion == null
        ? (widget.openMedical ? 'medical' : 'qr')
        : _eligibleStep(widget.profile);
  }

  @override
  void didUpdateWidget(covariant PilotAccountScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.completion != null && oldWidget.profile != widget.profile) {
      step = _eligibleStep(widget.profile);
    }
  }

  @override
  Widget build(BuildContext context) => switch (step) {
    'medical' =>
      widget.completion != null
          ? MedicalCompletionScreen(
              repository: widget.completion!,
              onGuest: widget.onPublicDashboard,
              onComplete: () {
                widget.onMedicalCompleted?.call();
                setState(() => step = 'approval');
              },
            )
          : SyntheticMedicalScreen(
              repository: widget.medical,
              isMinor: widget.profile.ageYearsAtRegistration < 18,
              onContinue: () {
                widget.onMedicalCompleted?.call();
                setState(() => step = 'qr');
              },
            ),
    'approval' => Scaffold(
      appBar: AppBar(title: const Text('School approval')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.verified_user_outlined, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    widget.profile.schoolApprovalStatus == 'revoked'
                        ? 'QR access is unavailable'
                        : 'Waiting for school approval',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Your QR becomes available after your school confirms enrollment. Public emergency resources remain available as a guest.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton(
                    onPressed: widget.onMedicalCompleted,
                    child: const Text('Refresh status'),
                  ),
                  FilledButton(
                    onPressed: widget.onPublicDashboard,
                    child: const Text('Go to Dashboard'),
                  ),
                  TextButton(
                    onPressed: widget.onSignOut,
                    child: const Text('Log out'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
    'qr' => MyUnverifiedQrScreen(
      repository: widget.qr,
      onDashboard: widget.onPublicDashboard,
      onScan: () => Navigator.pushNamed(context, AppRoutes.scanner),
      onSignOut: widget.onSignOut,
      onTier2: widget.onTier2,
    ),
    _ => const SizedBox.shrink(),
  };
}
