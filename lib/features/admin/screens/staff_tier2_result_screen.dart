import 'dart:async';
import 'package:flutter/material.dart';
import '../services/staff_tier2_repository.dart';

class StaffTier2ResultScreen extends StatefulWidget {
  const StaffTier2ResultScreen({
    super.key,
    required this.record,
    required this.client,
    this.displayTtl = const Duration(seconds: 120),
  });

  final Map<String, dynamic> record;
  final StaffTier2Client client;
  final Duration displayTtl;

  @override
  State<StaffTier2ResultScreen> createState() => _StaffTier2ResultScreenState();
}

class _StaffTier2ResultScreenState extends State<StaffTier2ResultScreen>
    with WidgetsBindingObserver {
  Map<String, dynamic>? _record;
  Timer? _ttlTimer;
  StreamSubscription<String?>? _uidSub;
  String? _ownerUid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _record = Map<String, dynamic>.from(widget.record);
    _ownerUid = widget.client.currentUid;
    widget.client.setSecureScreen(true);
    _ttlTimer = Timer(widget.displayTtl, _clearProtected);
    _uidSub = widget.client.uidChanges.listen((uid) {
      if (uid != _ownerUid) {
        _clearProtected();
      }
    });
  }

  void _clearProtected() {
    _ttlTimer?.cancel();
    _ttlTimer = null;
    if (!mounted) return;
    if (_record != null) {
      setState(() => _record = null);
    }
    widget.client.setSecureScreen(false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _clearProtected();
    }
  }

  @override
  void dispose() {
    _ttlTimer?.cancel();
    _uidSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    widget.client.setSecureScreen(false);
    super.dispose();
  }

  String _formatAnswer(Object? raw) {
    if (raw is! Map) return 'Unavailable';
    final state = raw['state'];
    final details = raw['details'];
    if (state == 'listed' && details is String && details.trim().isNotEmpty) {
      return details.trim();
    }
    if (state == 'none_known') return 'None known';
    if (state == 'unknown') return 'Unknown';
    return 'Unavailable';
  }

  @override
  Widget build(BuildContext context) {
    final record = _record;
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency Medical Information')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: record == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_outline, size: 48),
                      const SizedBox(height: 12),
                      const Text(
                        'Protected medical display locked and cleared.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        child: const Text('Return to Scanner'),
                      ),
                    ],
                  ),
                )
              : ListView(
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Medical Conditions',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(_formatAnswer(record['conditions'])),
                            const SizedBox(height: 16),
                            Text(
                              'Allergies',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(_formatAnswer(record['allergies'])),
                            const SizedBox(height: 16),
                            Text(
                              'Primary Emergency Contact',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            if (record['primaryContact'] is Map) ...[
                              Text(
                                (record['primaryContact'] as Map)['fullName']
                                        ?.toString() ??
                                    'Unavailable',
                              ),
                              Text(
                                (record['primaryContact']
                                            as Map)['relationship']
                                        ?.toString() ??
                                    '',
                              ),
                              Text(
                                (record['primaryContact'] as Map)['phoneNumber']
                                        ?.toString() ??
                                    '',
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'This screen automatically locks after 2 minutes, on backgrounding, or on sign-out. Screenshots are suppressed and no medical data is cached offline.',
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _clearProtected,
                      icon: const Icon(Icons.lock),
                      label: const Text('Lock and clear'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
