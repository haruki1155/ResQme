import 'package:flutter/material.dart';

const registrationNoticeVersion = 'tier1-registration-v1';
const registrationPrivacyBody =
    'To create your ResQMe student account, we will process your full name, age and email address. You may also provide your gender, personal contact number, and parent/guardian or secondary emergency-contact details. These details will be stored in your private basic profile for registration and future authorized school enrollment and emergency-contact procedures. Your password is handled by our authentication service and is not stored in your student profile. Contact numbers and registration details are not displayed in public QR results. No medical information is collected or made available by this acknowledgment.';
const registrationPrivacyCheckbox =
    'I have read and understood the ResQMe Privacy Notice and agree to the processing of my registration information for the purposes described above.';
const minorPrivacyExplanation =
    'Your enrollment will remain pending until the school confirms the required parent or guardian authorization. This checkbox does not provide that authorization.';

class RegistrationPrivacyDialog extends StatefulWidget {
  const RegistrationPrivacyDialog({
    super.key,
    required this.ageYears,
    required this.onDecline,
    required this.onAccept,
  });
  final int ageYears;
  final VoidCallback onDecline, onAccept;
  @override
  State<RegistrationPrivacyDialog> createState() =>
      _RegistrationPrivacyDialogState();
}

class _RegistrationPrivacyDialogState extends State<RegistrationPrivacyDialog> {
  bool checked = false;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Data Privacy & Registration Authorization'),
    scrollable: true,
    content: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(registrationPrivacyBody),
        const SizedBox(height: 16),
        if (widget.ageYears < 18)
          const Text(
            minorPrivacyExplanation,
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        const SizedBox(height: 12),
        const Text('Notice version: $registrationNoticeVersion'),
        TextButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('ResQMe Privacy Notice'),
              scrollable: true,
              content: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(registrationPrivacyBody),
                  SizedBox(height: 16),
                  Text(minorPrivacyExplanation),
                  SizedBox(height: 16),
                  Text(
                    'Synthetic-data pilot. School privacy-officer review is required before real student data is processed.',
                  ),
                  Text('Notice version: $registrationNoticeVersion'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
          child: const Text('Review Privacy Notice'),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: checked,
          onChanged: (value) => setState(() => checked = value ?? false),
          title: const Text(registrationPrivacyCheckbox),
          controlAffinity: ListTileControlAffinity.leading,
        ),
      ],
    ),
    actions: [
      TextButton(onPressed: widget.onDecline, child: const Text('Decline')),
      FilledButton(
        onPressed: checked ? widget.onAccept : null,
        child: const Text('Agree & Create Account'),
      ),
    ],
  );
}
