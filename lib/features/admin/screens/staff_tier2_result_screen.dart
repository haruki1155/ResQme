import 'dart:async';
import 'package:flutter/material.dart';
import '../../medical/widgets/tier2_profile_view.dart';
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

  @override
  Widget build(BuildContext context) {
    final record = _record;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: SafeArea(
        child: Column(
          children: [
            Tier2TopBar(
              unlocked: record != null,
              onLock: _clearProtected,
            ),
            Expanded(
              child: record == null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.lock_outline,
                              size: 48,
                              color: Color(0xFF04081A),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Protected medical display locked and cleared.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: () =>
                                  Navigator.of(context).maybePop(),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFE92B32),
                              ),
                              child: const Text('Return to Scanner'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Tier2ProfileView(
                      record: record,
                      onLock: _clearProtected,
                      lockButtonLabel: 'Lock and clear',
                      securityNotice:
                          'This screen automatically locks after 2 minutes, on backgrounding, or on sign-out. Screenshots are suppressed and no medical data is cached offline.',
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
