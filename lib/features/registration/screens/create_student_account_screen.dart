import 'package:flutter/material.dart';
import '../../../core/widgets/feature_guide.dart';
import '../models/registration_draft.dart';
import '../registration_validators.dart';
import '../services/student_registration_repository.dart';
import '../widgets/registration_privacy_dialog.dart';
import '../widgets/roster_claim_verification_dialog.dart';

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
  bool _hideEnrollmentCode = false;
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
      initialDatePickerMode: DatePickerMode.year,
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
      final submittedName = fields['name']!.text.trim();
      final submittedBirthDate = fields['birthDate']!.text.trim();
      final submittedLrn = fields['lrn']!.text.trim();
      final submittedCode = fields['enrollmentCode']!.text.trim();
      final approvalStatus = result.profile?.schoolApprovalStatus;
      final repo = widget.repository;

      if (submittedCode.isNotEmpty &&
          approvalStatus != 'approved' &&
          repo is RosterClaimRegistrationRepository) {
        final retry = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Automatic Verification Did Not Match'),
            content: const Text(
              'Your student account was created, but automatic school roster verification did not complete.\n\n'
              'Double-check your full name, birth date (YYYY-MM-DD), 12-digit LRN, and enrollment code to retry automatic verification now, or continue for manual school review.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Continue as Pending'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Fix & Retry Verification'),
              ),
            ],
          ),
        );
        if (!mounted) return;
        if (retry == true) {
          final verified = await showRosterClaimVerificationDialog(
            context: context,
            repository: repo,
            initialFullName: submittedName,
            initialBirthDate: submittedBirthDate,
            initialLrn: submittedLrn,
            initialEnrollmentCode: submittedCode,
            initialNotice:
                'Check each field carefully (especially Birth Date YYYY-MM-DD and Enrollment Code).',
          );
          if (!mounted) return;
          if (verified?.profile?.schoolApprovalStatus == 'approved') {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('School enrollment verified automatically!'),
              ),
            );
          }
        }
      } else if (approvalStatus == 'approved') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('School enrollment verified automatically!'),
          ),
        );
      }

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
                    hintText: 'YYYY-MM-DD (e.g. 2005-03-10)',
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
                    secret: _hideEnrollmentCode,
                    hintText: '20-character code from your school roster',
                    suffixIcon: IconButton(
                      tooltip: _hideEnrollmentCode
                          ? 'Show enrollment code'
                          : 'Hide enrollment code',
                      onPressed: () => setState(
                        () => _hideEnrollmentCode = !_hideEnrollmentCode,
                      ),
                      icon: Icon(
                        _hideEnrollmentCode
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 20,
                      ),
                    ),
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
