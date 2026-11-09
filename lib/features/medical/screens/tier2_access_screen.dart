import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/tier2_authorization_repository.dart';

class Tier2AccessScreen extends StatefulWidget {
  const Tier2AccessScreen({super.key, required this.repository});
  final Tier2AuthorizationRepository repository;
  @override
  State<Tier2AccessScreen> createState() => _Tier2AccessScreenState();
}

class _Tier2AccessScreenState extends State<Tier2AccessScreen>
    with WidgetsBindingObserver {
  final _password = TextEditingController();
  StreamSubscription<User?>? _authSubscription;
  Map<String, dynamic>? _record;
  String? _message, _loadedUid;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _loadedUid = widget.repository.currentUid;
    WidgetsBinding.instance.addObserver(this);
    _authSubscription = widget.repository.auth.userChanges().listen((user) {
      if (user?.uid != _loadedUid && mounted) {
        setState(() {
          _record = null;
          _loadedUid = user?.uid;
          _message = null;
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ((state == AppLifecycleState.paused ||
            state == AppLifecycleState.hidden) &&
        mounted) {
      setState(() {
        _record = null;
        _loadedUid = null;
        _password.clear();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    _password.dispose();
    _record = null;
    super.dispose();
  }

  Future<void> _run(Future<Map<String, dynamic>> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
      _record = null;
    });
    final uid = widget.repository.currentUid;
    try {
      final result = await action();
      if (!mounted || uid == null || widget.repository.currentUid != uid) {
        return;
      }
      setState(() {
        _record = result;
        _loadedUid = uid;
        _password.clear();
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _message = error is Tier2AuthorizationFailure
              ? error.message
              : 'Tier 2 access could not be verified.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disableBiometrics() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
      _record = null;
    });
    try {
      await widget.repository.revokeDeviceWithPassword(_password.text);
      if (mounted) {
        setState(() {
          _password.clear();
          _loadedUid = null;
          _message =
              'Biometric access disabled for this account. Use your password or enroll this device again.';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _message = error is Tier2AuthorizationFailure
              ? error.message
              : 'Unable to disable biometric access.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _answer(dynamic value) {
    if (value is! Map) return 'Not available';
    final state = value['state'];
    final detail = value['details'];
    if (state == 'listed' && detail is String && detail.isNotEmpty) {
      return detail;
    }
    return switch (state) {
      'unknown' => 'Unknown',
      'none_known' => 'None known',
      _ => 'Not available',
    };
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tier 2 information')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Private medical and emergency-contact information is released only after fresh account verification.',
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _busy
                ? null
                : () => _run(widget.repository.readWithBiometrics),
            icon: const Icon(Icons.fingerprint),
            label: const Text('Unlock with biometrics'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _password,
            enabled: !_busy,
            obscureText: true,
            autofillHints: const [AutofillHints.password],
            decoration: const InputDecoration(
              labelText: 'ResQMe account password',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: _busy
                ? null
                : () => _run(
                    () => widget.repository.readWithPassword(_password.text),
                  ),
            child: const Text('Use password once'),
          ),
          TextButton(
            onPressed: _busy
                ? null
                : () => _run(
                    () => widget.repository.enrollWithPassword(_password.text),
                  ),
            child: const Text('Set up biometrics with password'),
          ),
          TextButton(
            onPressed: _busy ? null : _disableBiometrics,
            child: const Text('Disable biometric access'),
          ),
          if (_busy)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_message!, style: const TextStyle(color: Colors.red)),
            ),
          if (_record != null) ...[
            const Divider(height: 32),
            Text('Conditions', style: Theme.of(context).textTheme.titleMedium),
            Text(_answer(_record!['conditions'])),
            const SizedBox(height: 12),
            Text('Allergies', style: Theme.of(context).textTheme.titleMedium),
            Text(_answer(_record!['allergies'])),
            const SizedBox(height: 12),
            Text(
              'Primary emergency contact',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (_record!['primaryContact'] is Map) ...[
              Text(
                (_record!['primaryContact'] as Map)['fullName']?.toString() ??
                    '',
              ),
              Text(
                (_record!['primaryContact'] as Map)['relationship']
                        ?.toString() ??
                    '',
              ),
              Text(
                (_record!['primaryContact'] as Map)['phoneNumber']
                        ?.toString() ??
                    '',
              ),
            ],
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => setState(() {
                _record = null;
                _loadedUid = null;
              }),
              child: const Text('Lock Tier 2 information'),
            ),
          ],
        ],
      ),
    ),
  );
}
