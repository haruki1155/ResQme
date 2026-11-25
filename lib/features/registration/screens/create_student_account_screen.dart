import 'package:flutter/material.dart';
import '../../../core/widgets/feature_guide.dart';
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
      'birthDate',
      'age',
      'lrn',
      'enrollmentCode',
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

  void _syncAgeFromBirthDate(String rawBirthDate) {
    final computed = computeAgeYearsFromBirthDate(rawBirthDate);
    if (computed != null) {
      fields['age']!.text = '$computed';
    }
  }

  Future<void> _pickBirthDate() async {
    if (busy) return;
    final now = DateTime.now();
    final existingAge = computeAgeYearsFromBirthDate(fields['birthDate']!.text);
    final initialDate = existingAge != null
        ? DateTime.tryParse(fields['birthDate']!.text.trim()) ??
            DateTime(now.year - 16, now.month, now.day)
        : DateTime(now.year - 16, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isAfter(now) ? now : initialDate,
      firstDate: DateTime(1900, 1, 1),
      lastDate: now,
      helpText: 'Select Student Birth Date',
    );
    if (picked == null || !mounted) return;
    final formatted =
        '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    setState(() {
      fields['birthDate']!.text = formatted;
      _syncAgeFromBirthDate(formatted);
    });
  }

  Widget field(
    String key,
    String label, {
    String? Function(String?)? validator,
    TextInputType? keyboard,
    bool secret = false,
    String? hintText,
    Widget? suffixIcon,
    ValueChanged<String>? onChanged,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: fields[key],
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        suffixIcon: suffixIcon,
        border: const OutlineInputBorder(),
      ),
      validator: validator,
      onChanged: onChanged,
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
    _syncAgeFromBirthDate(fields['birthDate']!.text);
    if (busy || !form.currentState!.validate()) return;
    final computedAge =
        computeAgeYearsFromBirthDate(fields['birthDate']!.text) ??
        int.parse(fields['age']!.text.trim());
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => RegistrationPrivacyDialog(
        ageYears: computedAge,
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
        ageYears: computedAge,
        birthDate: fields['birthDate']!.text,
        email: fields['email']!.text,
        password: fields['password']!.text,
        lrn: fields['lrn']!.text.trim(),
        enrollmentCode: fields['enrollmentCode']!.text,
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
      fields['lrn']!.clear();
      fields['enrollmentCode']!.clear();
      widget.onRegistered();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Create student account'),
      actions: const [
        FeatureGuideIconButton(guide: ResQMeFeatureGuides.studentRegistration),
      ],
    ),
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
                    'Enter your official 12-digit LRN, full name, birth date, and school-issued enrollment code for automatic school verification, or continue for manual school review.',
                  ),
                  heading('Personal information'),
                  field('name', 'Full name', validator: validateFullName),
                  field(
                    'birthDate',
                    'Birth date (YYYY-MM-DD)',
                    hintText: 'e.g. 2010-05-10',
                    keyboard: TextInputType.datetime,
                    onChanged: _syncAgeFromBirthDate,
                    suffixIcon: IconButton(
                      tooltip: 'Select birth date',
                      onPressed: busy ? null : _pickBirthDate,
                      icon: const Icon(Icons.calendar_today_outlined, size: 20),
                    ),
                    validator: (value) => validateBirthDate(
                      value,
                      required: fields['age']!.text.trim().isEmpty,
                    ),
                  ),
                  field(
                    'age',
                    'Age (years)',
                    keyboard: TextInputType.number,
                    validator: (value) {
                      final fromBirth = computeAgeYearsFromBirthDate(
                        fields['birthDate']!.text,
                      );
                      if (fromBirth != null) return null;
                      return validateAge(int.tryParse(value ?? ''));
                    },
                  ),
                  field(
                    'lrn',
                    '12-digit LRN',
                    keyboard: TextInputType.number,
                    validator: validateLrn,
                  ),
                  field(
                    'enrollmentCode',
                    'Enrollment code (optional for manual review)',
                    secret: true,
                    validator: validateEnrollmentCode,
                  ),
                  const Text(
                    'A valid school-issued enrollment code paired with an exact roster match (LRN, full name, and birth date) activates school verification automatically. If omitted or unmatched, registration continues safely for manual school review.',
                  ),
                  const SizedBox(height: 16),
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
