import 'package:flutter/material.dart';
import 'package:resqme/features/welcome/data/consent_repository.dart';

class TermsPrivacyScreen extends StatefulWidget {
  const TermsPrivacyScreen({
    super.key,
    required this.consentRepository,
    required this.onAccepted,
  });

  final ConsentRepository consentRepository;
  final Future<void> Function() onAccepted;

  @override
  State<TermsPrivacyScreen> createState() => _TermsPrivacyScreenState();
}

class _TermsPrivacyScreenState extends State<TermsPrivacyScreen> {
  var _agreed = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terms and Conditions')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'RESQME  |  QR ID',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.shield_outlined,
                          color: Color(0xFFE92B32),
                          size: 40,
                        ),
                        const SizedBox(height: 28),
                        const Text(
                          'BEFORE YOU BEGIN',
                          style: TextStyle(
                            color: Color(0xFFE92B32),
                            letterSpacing: 3,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Your safety.\nYour information.',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'ResQMe provides Tier 1 emergency support and QR-based identification. Protected medical information is not available in this pilot.',
                        ),
                        const Divider(height: 42),
                        const _ConsentPoint(
                          'Emergency responders may access Tier 1 safety information.',
                        ),
                        const _ConsentPoint(
                          'Tier 2 personal records are restricted and unavailable in this pilot.',
                        ),
                        const _ConsentPoint(
                          'This tool does not replace professional medical advice.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFDDE3EC)),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: CheckboxListTile(
                        value: _agreed,
                        onChanged: (value) =>
                            setState(() => _agreed = value ?? false),
                        title: const Text(
                          'I agree to the Terms of Use and Privacy Policy',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _agreed ? widget.onAccepted : null,
                    child: const Text('Accept & continue'),
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

class _ConsentPoint extends StatelessWidget {
  const _ConsentPoint(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.check_circle_outline,
          color: Color(0xFFE92B32),
          size: 20,
        ),
        const SizedBox(width: 14),
        Expanded(child: Text(text)),
      ],
    ),
  );
}
