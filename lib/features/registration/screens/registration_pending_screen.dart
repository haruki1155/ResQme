import 'package:flutter/material.dart';
import '../models/student_registration_profile.dart';

class RegistrationPendingScreen extends StatelessWidget {
  const RegistrationPendingScreen({
    super.key,
    required this.profile,
    required this.onRefreshStatus,
    required this.onPublicDashboard,
    required this.onSignOut,
  });
  final StudentRegistrationProfile profile;
  final VoidCallback onRefreshStatus, onPublicDashboard, onSignOut;
  @override
  Widget build(BuildContext context) {
    final minor = profile.status == 'pending_guardian';
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
                  const Icon(
                    Icons.pending_actions,
                    size: 64,
                    color: Color(0xFFE92B32),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    minor
                        ? 'Registration received — guardian authorization pending'
                        : 'Registration received — pending school review',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    minor
                        ? 'Guardian verification and school review are not active in this milestone. Your privacy acknowledgment is not guardian authorization.'
                        : 'Registration does not confirm student status. School review is not active in this milestone.',
                  ),
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
