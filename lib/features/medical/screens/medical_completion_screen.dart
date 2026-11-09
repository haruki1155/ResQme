import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../registration/registration_validators.dart';
import '../services/medical_completion_repository.dart';

String _requestId() => base64Url
    .encode(List<int>.generate(18, (_) => Random.secure().nextInt(256)))
    .replaceAll('=', '');

class MedicalCompletionScreen extends StatefulWidget {
  const MedicalCompletionScreen({
    super.key,
    required this.repository,
    required this.onComplete,
    required this.onGuest,
  });
  final MedicalCompletionRepository repository;
  final VoidCallback onComplete;
  final VoidCallback onGuest;
  @override
  State<MedicalCompletionScreen> createState() =>
      _MedicalCompletionScreenState();
}

class _MedicalCompletionScreenState extends State<MedicalCompletionScreen> {
  final _form = GlobalKey<FormState>();
  final _conditions = TextEditingController(),
      _allergies = TextEditingController();
  final _contactName = TextEditingController(),
      _relationship = TextEditingController(),
      _phone = TextEditingController();
  String? _conditionsState, _allergiesState, _uid, _request;
  int _revision = 0;
  bool _confirmed = false, _loading = true, _saving = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    for (final controller in [
      _conditions,
      _allergies,
      _contactName,
      _relationship,
      _phone,
    ]) {
      controller.addListener(() => _request = null);
    }
    _load();
  }

  @override
  void dispose() {
    _conditions.dispose();
    _allergies.dispose();
    _contactName.dispose();
    _relationship.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final profile = await widget.repository.loadEligibility();
      if (!mounted) return;
      if (profile['medicalStatus'] == 'complete') {
        widget.onComplete();
        return;
      }
      setState(() {
        _uid = widget.repository.client.uid;
        _revision = profile['medicalRevision'] as int;
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _message = error is MedicalCompletionFailure
              ? error.message
              : 'Medical form status is unavailable. Retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _answer(
    String label,
    String? value,
    ValueChanged<String?> onChanged,
    TextEditingController details,
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
        items: const [
          DropdownMenuItem(value: 'unknown', child: Text('Unknown')),
          DropdownMenuItem(value: 'none_known', child: Text('None known')),
          DropdownMenuItem(
            value: 'listed',
            child: Text('Listed (add details)'),
          ),
        ],
        onChanged: _saving
            ? null
            : (next) {
                onChanged(next);
                _request = null;
                setState(() {});
              },
        validator: (answer) => answer == null ? 'Choose an answer.' : null,
      ),
      if (value == 'listed') ...[
        const SizedBox(height: 12),
        TextFormField(
          controller: details,
          enabled: !_saving,
          maxLength: 2000,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Details',
            border: OutlineInputBorder(),
          ),
          validator: (text) => text == null || text.trim().isEmpty
              ? 'Add the listed details.'
              : null,
        ),
      ],
    ],
  );

  Future<void> _save() async {
    if (_saving ||
        _uid == null ||
        !_form.currentState!.validate() ||
        !_confirmed) {
      return;
    }
    setState(() {
      _saving = true;
      _message = null;
    });
    _request ??= _requestId();
    try {
      String? clean(String value) => value.trim().isEmpty ? null : value.trim();
      await widget.repository.complete(
        expectedRevision: _revision,
        requestId: _request!,
        expectedUid: _uid!,
        conditions: {
          'state': _conditionsState,
          'details': _conditionsState == 'listed'
              ? clean(_conditions.text)
              : null,
        },
        allergies: {
          'state': _allergiesState,
          'details': _allergiesState == 'listed'
              ? clean(_allergies.text)
              : null,
        },
        primaryContact: {
          'fullName': clean(_contactName.text),
          'relationship': clean(_relationship.text),
          'phoneNumber': clean(_phone.text)?.replaceAll(RegExp(r'[ -]'), ''),
        },
      );
      if (mounted) widget.onComplete();
    } catch (error) {
      if (mounted) {
        setState(() {
          _message = error is MedicalCompletionFailure
              ? error.message
              : 'Unable to save. Retry.';
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Medical information')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : SafeArea(
            child: Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    'Required before QR activation',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Enter what you know. This is self-reported information, not a medical diagnosis. Choose Unknown or None known when appropriate.',
                  ),
                  const SizedBox(height: 24),
                  _answer(
                    'Medical conditions',
                    _conditionsState,
                    (value) => _conditionsState = value,
                    _conditions,
                  ),
                  const SizedBox(height: 18),
                  _answer(
                    'Allergies',
                    _allergiesState,
                    (value) => _allergiesState = value,
                    _allergies,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Primary emergency contact',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _contactName,
                    enabled: !_saving,
                    decoration: const InputDecoration(
                      labelText: 'Full name',
                      border: OutlineInputBorder(),
                    ),
                    validator: validateFullName,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _relationship,
                    enabled: !_saving,
                    decoration: const InputDecoration(
                      labelText: 'Relationship',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value == null ||
                            value.trim().isEmpty ||
                            value.trim().length > 40
                        ? 'Enter the relationship.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phone,
                    enabled: !_saving,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Mobile number',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter a contact number.'
                        : validatePhone(value),
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    value: _confirmed,
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _confirmed = value == true),
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'I confirm this information is accurate to the best of my knowledge and self-reported.',
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  if (!_confirmed && _message == null)
                    const Text(
                      'Confirm the self-reported information to continue.',
                      style: TextStyle(color: Colors.red),
                    ),
                  if (_message != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _message!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'Saving…' : 'Save and continue'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _saving ? null : widget.onGuest,
                    child: const Text('Continue as guest to public resources'),
                  ),
                ],
              ),
            ),
          ),
  );
}
