import 'package:flutter/material.dart';
import '../models/student_registration_profile.dart';

class RegistrationPendingScreen extends StatelessWidget {
  const RegistrationPendingScreen({
    super.key,
    required this.profile,
    required this.onRefreshStatus,
    required this.onPublicDashboard,
    required this.onSignOut,
    this.onVerifyWithCode,
  });

  final StudentRegistrationProfile profile;
  final VoidCallback onRefreshStatus, onPublicDashboard, onSignOut;
  final VoidCallback? onVerifyWithCode;

  @override
  Widget build(BuildContext context) {
    final isSchoolApproved = profile.schoolApprovalStatus == 'approved';
    final isMinor = profile.ageYearsAtRegistration < 18;

    final String headline;
    final String explanation;
    final IconData statusIcon;
    if (isSchoolApproved) {
      statusIcon = Icons.verified_outlined;
      headline = isMinor
          ? 'School enrollment verified - guardian authorization required'
          : 'Account activated - school enrollment verified';
      explanation = isMinor
          ? 'Your school enrollment was verified automatically. Because you are under 18, verified parent/guardian authorization and medical record completion are required before QR credentials activate.'
          : 'Your school enrollment is verified. Complete your emergency medical record to activate your ResQMe QR credential.';
    } else {
      statusIcon = Icons.pending_actions;
      headline = 'Registration received - pending school review';
      explanation =
          'Registration does not confirm student status. School approval is required before your QR can be activated.';
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Registration status')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    statusIcon,
                    size: 64,
                    color: const Color(0xFFE92B32),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    headline,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  Text(explanation),
                  const SizedBox(height: 24),
                  ExpansionTile(
                    title: const Text('Review submitted details'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Full name: ${profile.fullName}'),
                            Text(
                              'Age at registration: ${profile.ageYearsAtRegistration}',
                            ),
                            if (profile.gender != null)
                              Text('Gender: ${profile.gender}'),
                            if (profile.personalPhone != null)
                              Text(
                                'Personal contact number: ${profile.personalPhone}',
                              ),
                            if (profile.guardianName != null)
                              Text('Parent/guardian: ${profile.guardianName}'),
                            if (profile.guardianRelationship != null)
                              Text(
                                'Relationship: ${profile.guardianRelationship}',
                              ),
                            if (profile.guardianPhone != null)
                              Text(
                                'Parent/guardian contact: ${profile.guardianPhone}',
                              ),
                            if (profile.secondaryName != null)
                              Text(
                                'Secondary contact: ${profile.secondaryName}',
                              ),
                            if (profile.secondaryPhone != null)
                              Text(
                                'Secondary number: ${profile.secondaryPhone}',
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (!isSchoolApproved && onVerifyWithCode != null) ...[
                    FilledButton.icon(
                      onPressed: onVerifyWithCode,
                      icon: const Icon(Icons.verified_user_outlined),
                      label: const Text('Verify with Enrollment Code'),
                    ),
                    const SizedBox(height: 8),
                  ],
                  FilledButton(
                    onPressed: onRefreshStatus,
                    child: const Text('View registration status'),
                  ),
                  TextButton(
                    onPressed: onPublicDashboard,
                    child: const Text('Return to public dashboard'),
                  ),
                  OutlinedButton(
                    onPressed: onSignOut,
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
}
