import 'package:flutter/material.dart';
import 'package:resqme/features/welcome/data/consent_repository.dart';

class TermsPrivacyScreen extends StatelessWidget {
  const TermsPrivacyScreen({
    super.key,
    required this.consentRepository,
    required this.onAccepted,
  });

  final ConsentRepository consentRepository;
  final Future<void> Function() onAccepted;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terms & Privacy')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Before you continue',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              const Text(
                'ResQMe provides emergency support information and QR-based student identification. '
                'Do not enter medical information in this app during the Tier 1 pilot.',
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: onAccepted,
                child: const Text('I Agree'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
