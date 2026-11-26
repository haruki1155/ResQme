import 'package:flutter/material.dart';
import '../registration_validators.dart';
import '../services/student_registration_repository.dart';

/// Prompts a student to enter their official roster biographical fields and
/// one-time enrollment code using a year-first date picker to complete automatic
/// school verification without creating a duplicate account.
Future<RegistrationResult?> showRosterClaimVerificationDialog({
  required BuildContext context,
  required RosterClaimRegistrationRepository repository,
  String? initialFullName,
  String? initialBirthDate,
  String? initialLrn,
  String? initialEnrollmentCode,
  String? initialNotice,
}) {
  return showDialog<RegistrationResult>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _RosterClaimVerificationDialog(
      repository: repository,
      initialFullName: initialFullName,
      initialBirthDate: initialBirthDate,
      initialLrn: initialLrn,
      initialEnrollmentCode: initialEnrollmentCode,
      initialNotice: initialNotice,
    ),
  );
}

class _RosterClaimVerificationDialog extends StatefulWidget {
  const _RosterClaimVerificationDialog({
    required this.repository,
    this.initialFullName,
    this.initialBirthDate,
    this.initialLrn,
    this.initialEnrollmentCode,
    this.initialNotice,
  });

  final RosterClaimRegistrationRepository repository;
  final String? initialFullName;
  final String? initialBirthDate;
  final String? initialLrn;
  final String? initialEnrollmentCode;
  final String? initialNotice;

  @override
  State<_RosterClaimVerificationDialog> createState() =>
      _RosterClaimVerificationDialogState();
}

class _RosterClaimVerificationDialogState
    extends State<_RosterClaimVerificationDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(
    text: widget.initialFullName ?? '',
  );
  late final TextEditingController _birthDate = TextEditingController(
    text: widget.initialBirthDate ?? '',
  );
  late final TextEditingController _lrn = TextEditingController(
    text: widget.initialLrn ?? '',
  );
  late final TextEditingController _code = TextEditingController(
    text: widget.initialEnrollmentCode ?? '',
  );

  bool _hideCode = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _error = widget.initialNotice;
  }

  @override
  void dispose() {
    _name.dispose();
    _birthDate.dispose();
    _lrn.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    if (_busy) return;
    final now = DateTime.now();
    final existing = computeAgeYearsFromBirthDate(_birthDate.text) != null
        ? DateTime.tryParse(_birthDate.text.trim())
        : null;
    final initialDate = existing ?? DateTime(now.year - 16, now.month, now.day);
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
    setState(() => _birthDate.text = formatted);
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final res = await widget.repository.claimRosterVerification(
      fullName: _name.text.trim(),
      birthDate: _birthDate.text.trim(),
      lrn: _lrn.text.trim(),
      enrollmentCode: _code.text.trim().toUpperCase(),
    );
    if (!mounted) return;
    if (res.state == RegistrationState.pending &&
        res.profile?.schoolApprovalStatus == 'approved') {
      Navigator.of(context).pop(res);
      return;
    }
    setState(() {
      _busy = false;
      _error = res.message.isNotEmpty
          ? res.message
          : 'Unable to verify enrollment. Check your details and try again.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Verify with Enrollment Code'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Enter your exact official full name, birth date (YYYY-MM-DD), 12-digit LRN, and school-issued enrollment code.',
                  style: TextStyle(fontSize: 13),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: Color(0xFF991B1B),
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                TextFormField(
                  controller: _name,
                  enabled: !_busy,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    border: OutlineInputBorder(),
                  ),
                  validator: validateFullName,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _birthDate,
                  enabled: !_busy,
                  keyboardType: TextInputType.datetime,
                  decoration: InputDecoration(
                    labelText: 'Birth date (YYYY-MM-DD)',
                    hintText: 'YYYY-MM-DD (e.g. 2005-03-10)',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      tooltip: 'Select birth date',
                      onPressed: _busy ? null : _pickBirthDate,
                      icon: const Icon(Icons.calendar_today_outlined, size: 20),
                    ),
                  ),
                  validator: (v) => validateBirthDate(v, required: true),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _lrn,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '12-digit LRN',
                    border: OutlineInputBorder(),
                  ),
                  validator: validateLrn,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _code,
                  enabled: !_busy,
                  obscureText: _hideCode,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: 'Enrollment code',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      tooltip: _hideCode ? 'Show code' : 'Hide code',
                      onPressed: () => setState(() => _hideCode = !_hideCode),
                      icon: Icon(
                        _hideCode
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 20,
                      ),
                    ),
                  ),
                  validator: (v) {
                    final trimmed = v?.trim() ?? '';
                    if (!RegExp(r'^[A-Za-z0-9_-]{16,128}$').hasMatch(trimmed)) {
                      return 'Enter your valid school-issued enrollment code.';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(_busy ? 'Verifying…' : 'Verify Enrollment'),
        ),
      ],
    );
  }
}
