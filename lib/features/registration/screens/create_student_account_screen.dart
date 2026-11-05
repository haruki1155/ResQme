import 'package:flutter/material.dart';
import '../models/registration_draft.dart';
import '../registration_validators.dart';
import '../services/student_registration_repository.dart';
import '../widgets/registration_privacy_dialog.dart';

class CreateStudentAccountScreen extends StatefulWidget {
  const CreateStudentAccountScreen({
    super.key,
    required this.repository,
    required this.onRegistered,
  });
  final StudentRegistrationRepository repository;
  final VoidCallback onRegistered;
  @override
  State<CreateStudentAccountScreen> createState() =>
      _CreateStudentAccountScreenState();
}

class _CreateStudentAccountScreenState
    extends State<CreateStudentAccountScreen> {
  final form = GlobalKey<FormState>();
  final fields = {
    for (final key in [
      'name',
      'age',
      'phone',
      'guardianName',
      'guardianPhone',
      'secondaryName',
      'secondaryPhone',
      'email',
      'password',
      'confirm',
    ])
      key: TextEditingController(),
  };
  String? gender, relationship;
  bool busy = false;
  String? message;
  @override
  void dispose() {
    for (final controller in fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget field(
    String key,
    String label, {
    String? Function(String?)? validator,
    TextInputType? keyboard,
    bool secret = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: fields[key],
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: validator,
      keyboardType: keyboard,
      obscureText: secret,
      autocorrect: !secret,
      enableSuggestions: !secret,
      enabled: !busy,
    ),
  );
  Widget heading(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Text(text, style: Theme.of(context).textTheme.titleLarge),
  );
  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => RegistrationPrivacyDialog(
        ageYears: int.parse(fields['age']!.text),
        onDecline: () => Navigator.pop(context, false),
        onAccept: () => Navigator.pop(context, true),
      ),
    );
    if (accepted != true || !mounted) return;
    setState(() {
      busy = true;
      message = null;
    });
    final result = await widget.repository.register(
      RegistrationDraft(
        fullName: fields['name']!.text,
        ageYears: int.parse(fields['age']!.text),
        email: fields['email']!.text,
        password: fields['password']!.text,
        gender: gender,
        personalPhone: fields['phone']!.text,
        guardianName: fields['guardianName']!.text,
        guardianRelationship: relationship,
        guardianPhone: fields['guardianPhone']!.text,
        secondaryName: fields['secondaryName']!.text,
        secondaryPhone: fields['secondaryPhone']!.text,
      ),
      acknowledged: true,
    );
    if (!mounted) return;
    setState(() {
      busy = false;
      message = result.message;
    });
    if (result.state == RegistrationState.pending) {
      fields['password']!.clear();
      fields['confirm']!.clear();
      widget.onRegistered();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Create student account')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Form(
              key: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'RESQME',
                    style: TextStyle(
                      color: Color(0xFFE92B32),
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Synthetic-data pilot only. Registration remains pending.',
                  ),
                  heading('Personal information'),
                  field('name', 'Full name', validator: validateFullName),
                  field(
                    'age',
                    'Age (years)',
                    keyboard: TextInputType.number,
                    validator: (value) =>
                        validateAge(int.tryParse(value ?? '')),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: gender,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Gender (optional)',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final value in [
                        'Female',
                        'Male',
                        'Other',
                        'Prefer not to say',
                      ])
                        DropdownMenuItem(value: value, child: Text(value)),
                    ],
                    onChanged: busy
                        ? null
                        : (value) => setState(() => gender = value),
                  ),
                  const SizedBox(height: 16),
                  field(
                    'phone',
                    'Personal contact number (optional)',
                    keyboard: TextInputType.phone,
                    validator: validatePhone,
                  ),
                  heading('Emergency contacts (optional)'),
                  field(
                    'guardianName',
                    'Parent/guardian full name (optional)',
                    validator: (value) => RegistrationDraft.clean(value) == null
                        ? null
                        : validateFullName(value),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: relationship,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Relationship (optional)',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final value in ['Parent', 'Guardian', 'Other'])
                        DropdownMenuItem(value: value, child: Text(value)),
                    ],
                    onChanged: busy
                        ? null
                        : (value) => setState(() => relationship = value),
                  ),
                  const SizedBox(height: 16),
                  field(
                    'guardianPhone',
                    'Parent/guardian contact number (optional)',
                    keyboard: TextInputType.phone,
                    validator: validatePhone,
                  ),
                  field(
                    'secondaryName',
                    'Secondary emergency-contact name (optional)',
                    validator: (value) =>
                        validateSecondaryContactPair(
                          value,
                          fields['secondaryPhone']!.text,
                        ) ??
                        (RegistrationDraft.clean(value) == null
                            ? null
                            : validateFullName(value)),
                  ),
                  field(
                    'secondaryPhone',
                    'Secondary emergency-contact number (optional)',
                    keyboard: TextInputType.phone,
                    validator: validatePhone,
                  ),
                  const Text(
                    'Listing a guardian is contact information only and does not provide guardian authorization.',
                  ),
                  heading('Account credentials'),
                  field(
                    'email',
                    'Email',
                    keyboard: TextInputType.emailAddress,
                    validator: (value) =>
                        RegExp(
                          r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                        ).hasMatch((value ?? '').trim())
                        ? null
                        : 'Enter a valid email.',
                  ),
                  field(
                    'password',
                    'Password',
                    secret: true,
                    validator: validatePassword,
                  ),
                  field(
                    'confirm',
                    'Confirm password',
                    secret: true,
                    validator: (value) =>
                        validateConfirmation(value, fields['password']!.text),
                  ),
                  if (message != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(message!),
                    ),
                  FilledButton(
                    onPressed: busy ? null : submit,
                    child: Text(
                      busy
                          ? 'Submitting…'
                          : message == null
                          ? 'Create account'
                          : 'Retry registration',
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
