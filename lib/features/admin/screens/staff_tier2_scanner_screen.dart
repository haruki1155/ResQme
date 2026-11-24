import 'dart:async';
import 'package:flutter/material.dart';
import '../../qr/presentation/qr_scanner_screen.dart';
import '../services/staff_tier2_repository.dart';
import 'staff_tier2_result_screen.dart';

class StaffTier2ScannerScreen extends StatefulWidget {
  const StaffTier2ScannerScreen({
    super.key,
    required this.client,
    this.scannerBuilder,
  });

  final StaffTier2Client client;
  final Widget Function(ValueChanged<String> onValidQr)? scannerBuilder;

  @override
  State<StaffTier2ScannerScreen> createState() =>
      _StaffTier2ScannerScreenState();
}

class _StaffTier2ScannerScreenState extends State<StaffTier2ScannerScreen>
    with WidgetsBindingObserver {
  String _purpose = staffTier2Purposes.first;
  bool _inFlight = false;
  bool _backgrounded = false;
  int _generation = 0;
  String? _statusMessage;
  String? _sessionUid;
  StreamSubscription<String?>? _uidSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sessionUid = widget.client.currentUid;
    _uidSub = widget.client.uidChanges.listen((uid) {
      if (uid != _sessionUid) {
        _generation++;
        _sessionUid = uid;
        if (mounted) {
          setState(() {
            _inFlight = false;
            _statusMessage = 'Staff session changed. Sign in again.';
          });
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _backgrounded = false;
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _backgrounded = true;
      _generation++;
      if (mounted) setState(() => _inFlight = false);
    }
  }

  @override
  void dispose() {
    _generation++;
    _uidSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _onScannedQr(String payload) async {
    if (_inFlight || _backgrounded || !mounted) return;
    final uid = widget.client.currentUid;
    if (uid == null) {
      setState(() => _statusMessage = 'Sign in with a staff account first.');
      return;
    }
    final gen = ++_generation;
    setState(() {
      _inFlight = true;
      _statusMessage = null;
    });
    try {
      final record = await widget.client.readStudentTier2(
        qrPayload: payload,
        purpose: _purpose,
      );
      if (!mounted ||
          _backgrounded ||
          gen != _generation ||
          widget.client.currentUid != uid) {
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              StaffTier2ResultScreen(record: record, client: widget.client),
        ),
      );
    } catch (error) {
      if (!mounted ||
          _backgrounded ||
          gen != _generation ||
          widget.client.currentUid != uid) {
        return;
      }
      setState(() {
        _statusMessage = error is StaffTier2Failure
            ? error.message
            : 'Emergency Tier 2 access is unavailable.';
      });
    } finally {
      if (mounted && gen == _generation) {
        setState(() => _inFlight = false);
      }
    }
  }

  String _purposeLabel(String purpose) => switch (purpose) {
    'emergency_response' => 'Emergency Response',
    'clinic_triage' => 'Clinic Triage',
    'incident_assistance' => 'Incident Assistance',
    _ => purpose,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Staff Tier 2 QR Scanner')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _purpose,
                decoration: const InputDecoration(
                  labelText: 'Access purpose',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final p in staffTier2Purposes)
                    DropdownMenuItem(value: p, child: Text(_purposeLabel(p))),
                ],
                onChanged: _inFlight
                    ? null
                    : (next) {
                        if (next != null) setState(() => _purpose = next);
                      },
              ),
              const SizedBox(height: 12),
              Expanded(
                child: widget.scannerBuilder != null
                    ? widget.scannerBuilder!(_onScannedQr)
                    : QrScannerScreen(
                        embedded: true,
                        onReviewerScan: _onScannedQr,
                      ),
              ),
              const SizedBox(height: 12),
              if (_inFlight)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(width: 12),
                      Text('Confirm with device biometrics…'),
                    ],
                  ),
                ),
              if (_statusMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    _statusMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              const Text(
                'Biometric verification on your enrolled staff device is required. Public emergency hotlines and first-aid guidance remain available if Tier 2 is unavailable.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
