import 'dart:convert';
import 'package:flutter/material.dart';
import '../../registration/registration_validators.dart';
import '../models/synthetic_medical_draft.dart';
import '../services/synthetic_medical_repository.dart';

const syntheticMedicalNotice =
    "TEST MODE — Synthetic information only. This version of ResQMe saves fictional medical information to our staging database for testing. Do not enter any real person's conditions, allergies, name, or phone number. In a future real-use version, you must enter only conditions and allergies you actually know you have and keep the information accurate. Entries in this pilot are self-reported, have not been checked by a health professional, and are not sent to the clinic or emergency responders. You can skip this step and return later.";
const syntheticAcknowledgment =
    "I confirm that the information I am submitting is fictional test data, not a real person's medical information.";
const minorSyntheticAcknowledgment =
    "I understand that guardian authorization is not verified in this pilot. Checking this box does not provide or establish my parent or guardian's consent for real medical-data processing.";

class SyntheticMedicalScreen extends StatefulWidget {
  const SyntheticMedicalScreen({
    super.key,
    required this.repository,
    required this.isMinor,
    required this.onContinue,
  });
  final SyntheticMedicalRepository repository;
  final bool isMinor;
  final VoidCallback onContinue;
  @override
  State<SyntheticMedicalScreen> createState() => _SyntheticMedicalScreenState();
}

class _SyntheticMedicalScreenState extends State<SyntheticMedicalScreen> {
  final form = GlobalKey<FormState>();
  final conditions = TextEditingController(),
      allergies = TextEditingController(),
      name = TextEditingController(),
      relationship = TextEditingController(),
      phone = TextEditingController();
  MedicalSnapshot? record;
  String? conditionsState, allergiesState, message, requestId, clearRequestId;
  bool confirmed = false, minorConfirmed = false, busy = false, loading = true;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    for (final controller in [
      conditions,
      allergies,
      name,
      relationship,
      phone,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      message = null;
      record = null;
      confirmed = false;
      minorConfirmed = false;
      requestId = null;
      clearRequestId = null;
    });
    try {
      final result = await widget.repository.loadMine();
      if (!mounted) return;
      setState(() {
        record = result;
        conditionsState = result.conditions?['state'] as String?;
        allergiesState = result.allergies?['state'] as String?;
        conditions.text = result.conditions?['details'] as String? ?? '';
        allergies.text = result.allergies?['details'] as String? ?? '';
        name.text = result.primaryContact['fullName'] as String? ?? '';
        relationship.text =
            result.primaryContact['relationship'] as String? ?? '';
        phone.text = result.primaryContact['phoneNumber'] as String? ?? '';
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => message = error is MedicalFailure
              ? error.message
              : 'Test record unavailable. Retry or Skip for now.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> save({bool clear = false}) async {
    if (busy || record == null || (!clear && !form.currentState!.validate())) {
      return;
    }
    final snapshot = record!;
    setState(() => busy = true);
    try {
      if (clear) {
        clearRequestId ??= newPilotRequestId();
        await widget.repository.clearMine(
          expectedRevision: snapshot.revision,
          requestId: clearRequestId!,
          expectedUid: snapshot.ownerUid,
        );
      } else {
        requestId ??= newPilotRequestId();
        String? clean(String value) =>
            value.trim().isEmpty ? null : value.trim();
        final contact = {
          'fullName': clean(name.text),
          'relationship': clean(relationship.text),
          'phoneNumber': clean(phone.text)?.replaceAll(RegExp(r'[ -]'), ''),
        };
        final changed =
            jsonEncode(contact) != jsonEncode(snapshot.primaryContact);
        await widget.repository.save(
          SyntheticMedicalDraft(
            conditionsState: conditionsState!,
            allergiesState: allergiesState!,
            conditionsDetails: conditions.text,
            allergiesDetails: allergies.text,
            syntheticConfirmed: confirmed,
            minorAcknowledged: minorConfirmed,
            emergencyContact: changed ? contact : null,
            expectedContact: changed ? snapshot.primaryContact : null,
          ),
          expectedRevision: snapshot.revision,
          requestId: requestId!,
          expectedUid: snapshot.ownerUid,
        );
      }
      if (!mounted) return;
      if (clear) {
        await load();
      } else {
        widget.onContinue();
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => message = error is MedicalFailure
              ? error.message
              : 'Unable to save. Retry or Skip for now.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Widget answer(
    String label,
    String? value,
    TextEditingController controller,
    ValueChanged<String?> update,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DropdownButtonFormField<String>(
        key: ValueKey('$label-$value'),
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: [
          for (final state in ['unknown', 'none_known', 'listed'])
            DropdownMenuItem(
              value: state,
              child: Text(
                {
                  'unknown': 'Unknown',
                  'none_known': 'None known',
                  'listed': 'Listed (add details)',
                }[state]!,
              ),
            ),
        ],
        onChanged: busy
            ? null
            : (next) => setState(() {
                update(next);
                requestId = null;
              }),
        validator: (value) => value == null ? 'Choose a status.' : null,
      ),
      if (value == 'listed')
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: TextFormField(
            controller: controller,
            enabled: !busy,
            maxLength: 2000,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: '$label details',
              border: const OutlineInputBorder(),
            ),
            validator: (text) => (text ?? '').trim().isEmpty
                ? 'Enter fictional test details.'
                : null,
          ),
        ),
      const SizedBox(height: 20),
    ],
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Medical Information (Optional)')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Form(
              key: form,
              onChanged: () {
                requestId = null;
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(syntheticMedicalNotice),
                  const SizedBox(height: 24),
                  if (loading) const LinearProgressIndicator(),
                  if (record != null) ...[
                    answer(
                      'Medical conditions',
                      conditionsState,
                      conditions,
                      (value) => conditionsState = value,
                    ),
                    answer(
                      'Allergies',
                      allergiesState,
                      allergies,
                      (value) => allergiesState = value,
                    ),
                    const Text(
                      'Emergency contact (optional; updates your private primary contact)',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: name,
                      enabled: !busy,
                      maxLength: 120,
                      decoration: const InputDecoration(
                        labelText: 'Fictional contact name',
                      ),
                      validator: (value) => (value ?? '').trim().isEmpty
                          ? null
                          : validateFullName(value),
                    ),
                    TextFormField(
                      controller: relationship,
                      enabled: !busy,
                      maxLength: 40,
                      decoration: const InputDecoration(
                        labelText: 'Relationship',
                      ),
                    ),
                    TextFormField(
                      controller: phone,
                      enabled: !busy,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Fictional contact number',
                      ),
                      validator: validatePhone,
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: confirmed,
                      onChanged: busy
                          ? null
                          : (value) => setState(() {
                              confirmed = value ?? false;
                              requestId = null;
                            }),
                      title: const Text(syntheticAcknowledgment),
                    ),
                    if (widget.isMinor)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: minorConfirmed,
                        onChanged: busy
                            ? null
                            : (value) => setState(() {
                                minorConfirmed = value ?? false;
                                requestId = null;
                              }),
                        title: const Text(minorSyntheticAcknowledgment),
                      ),
                  ],
                  if (message != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(message!),
                    ),
                  FilledButton(
                    onPressed:
                        record != null &&
                            !busy &&
                            confirmed &&
                            (!widget.isMinor || minorConfirmed) &&
                            conditionsState != null &&
                            allergiesState != null
                        ? () => save()
                        : null,
                    child: Text(busy ? 'Saving…' : 'Save Test Record'),
                  ),
                  if (record?.completed == true)
                    OutlinedButton(
                      onPressed: busy ? null : () => save(clear: true),
                      child: const Text('Clear Test Record'),
                    ),
                  TextButton(
                    onPressed: busy || loading ? null : load,
                    child: const Text('Reload test record'),
                  ),
                  TextButton(
                    onPressed: widget.onContinue,
                    child: const Text('Skip for now'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
