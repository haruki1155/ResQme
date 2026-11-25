import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import '../../../core/widgets/feature_guide.dart';
import '../../qr/services/tier1_qr_repository.dart';
import '../services/tier2_authorization_repository.dart';
import '../widgets/tier2_profile_view.dart';

class StudentTier2QrScreen extends StatefulWidget {
  const StudentTier2QrScreen({
    super.key,
    required this.qrRepository,
    this.presentationClient,
  });

  final Tier1QrRepository qrRepository;
  final Tier2PresentationClient? presentationClient;

  @override
  State<StudentTier2QrScreen> createState() => _StudentTier2QrScreenState();
}

class _StudentTier2QrScreenState extends State<StudentTier2QrScreen>
    with WidgetsBindingObserver {
  static const _brandRed = Color(0xFFE92B32);
  static const _navySurface = Color(0xFF04081A);
  static const _bgSurface = Color(0xFFF4F6FA);
  static const _mutedText = Color(0xFF7B879B);

  TrustedDeviceStatus? _deviceStatus;
  Tier2PresentationToken? _presentationToken;
  Timer? _countdownTimer;
  int _secondsRemaining = 0;
  bool _checkingDevice = false;
  bool _unlocking = false;
  bool _secureEnabled = false;
  String? _sessionUid;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sessionUid = widget.presentationClient?.currentUid;
    _loadDeviceStatus();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Ignore transient inactive when Android BiometricPrompt is overlaid;
    // immediately lock & clear token on actual backgrounding.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _lockPresentation(clearError: true);
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    if (_secureEnabled) {
      widget.presentationClient?.setSecureScreen(false);
    }
    _presentationToken = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _setSecure(bool enabled) async {
    if (_secureEnabled == enabled) return;
    _secureEnabled = enabled;
    await widget.presentationClient?.setSecureScreen(enabled);
  }

  void _lockPresentation({bool clearError = false, String? expiredNotice}) {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _setSecure(false);
    if (!mounted) {
      _presentationToken = null;
      _secondsRemaining = 0;
      return;
    }
    setState(() {
      _presentationToken = null;
      _secondsRemaining = 0;
      if (clearError) {
        _error = null;
      } else if (expiredNotice != null) {
        _error = expiredNotice;
      }
    });
  }

  Future<void> _loadDeviceStatus() async {
    final client = widget.presentationClient;
    if (client == null) return;
    setState(() {
      _checkingDevice = true;
      _error = null;
    });
    try {
      final status = await client.getTrustedDeviceStatus();
      if (!mounted) return;
      setState(() => _deviceStatus = status);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is Tier2AuthorizationFailure
            ? error.message
            : 'Unable to verify trusted device status.';
      });
    } finally {
      if (mounted) setState(() => _checkingDevice = false);
    }
  }

  void _startCountdown(DateTime expiresAt) {
    _countdownTimer?.cancel();
    void tick() {
      final remaining = expiresAt.difference(DateTime.now()).inSeconds;
      if (remaining <= 0) {
        _lockPresentation(
          expiredNotice:
              'Protected Tier 2 QR expired. Unlock with biometrics again when ready.',
        );
        return;
      }
      if (mounted) {
        setState(() => _secondsRemaining = remaining);
      }
    }

    tick();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  Future<void> _unlockQr() async {
    final client = widget.presentationClient;
    if (client == null || _unlocking) return;
    final uid = client.currentUid;
    if (uid == null || (_sessionUid != null && uid != _sessionUid)) {
      _lockPresentation();
      setState(() => _error = 'Session changed. Sign in again.');
      return;
    }
    setState(() {
      _unlocking = true;
      _error = null;
    });
    try {
      final token = await client.unlockTier2PresentationQr();
      if (!mounted || client.currentUid != uid) return;
      await _setSecure(true);
      if (!mounted) return;
      setState(() {
        _presentationToken = token;
        _deviceStatus = const TrustedDeviceStatus(
          hasActiveTrustedDevice: true,
          isCurrentDeviceTrusted: true,
        );
      });
      _startCountdown(token.expiresAt);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is Tier2AuthorizationFailure
            ? error.message
            : 'Biometric verification is required to unlock your Tier 2 QR.';
      });
    } finally {
      if (mounted) setState(() => _unlocking = false);
    }
  }

  String _formatCountdown(int totalSeconds) {
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Widget _buildPresentationArea() {
    final client = widget.presentationClient;
    final status = _deviceStatus;
    final token = _presentationToken;

    if (_checkingDevice && status == null && token == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (token != null) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Expires in ${_formatCountdown(_secondsRemaining)}',
              style: const TextStyle(
                color: Color(0xFF15803D),
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE5EAF2)),
            ),
            child: SizedBox.square(
              dimension: 228,
              child: PrettyQrView.data(data: token.payload),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _lockPresentation(clearError: true),
            icon: const Icon(Icons.lock_outline),
            label: const Text('Lock QR Now'),
          ),
        ],
      );
    }

    if (status != null &&
        status.hasActiveTrustedDevice &&
        !status.isCurrentDeviceTrusted) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF59E0B)),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.phonelink_lock, color: Color(0xFFB45309)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Restricted to Enrolled Personal Device',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Another personal device is enrolled for biometric Tier 2 access. Protected Tier 2 QR presentation is available only on your enrolled personal device. To move biometric protection to this phone, approve a transfer code on your previous device or request school-verified recovery.',
              style: TextStyle(fontSize: 13, height: 1.45),
            ),
          ],
        ),
      );
    }

    if (status != null && !status.hasActiveTrustedDevice) {
      return Column(
        children: [
          const Icon(Icons.fingerprint, size: 48, color: _mutedText),
          const SizedBox(height: 12),
          const Text(
            'Set up Biometric Security on your personal device first before unlocking a protected Tier 2 QR.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _mutedText, height: 1.45),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _loadDeviceStatus,
            child: const Text('Refresh Device Status'),
          ),
        ],
      );
    }

    if (client == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Text(
          'Biometric Tier 2 presentation requires an authenticated personal device session.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _mutedText),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.fingerprint, size: 52, color: _brandRed),
        const SizedBox(height: 12),
        const Text(
          'Biometric verification is required each time you unlock your protected Tier 2 QR.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _mutedText, height: 1.45),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _unlocking ? null : _unlockQr,
          style: FilledButton.styleFrom(
            backgroundColor: _brandRed,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
          ),
          icon: const Icon(Icons.fingerprint),
          label: Text(
            _unlocking ? 'Verifying biometrics…' : 'Unlock Protected Tier 2 QR',
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = _presentationToken != null;
    return Scaffold(
      backgroundColor: _bgSurface,
      body: SafeArea(
        child: Column(
          children: [
            Tier2TopBar(
              unlocked: unlocked,
              onLock: unlocked ? () => _lockPresentation(clearError: true) : null,
              guide: ResQMeFeatureGuides.studentTier2Qr,
              guideAccountScope: widget.presentationClient?.currentUid ?? 'guest',
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFFE5EAF2)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.qr_code_2,
                              color: _brandRed,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'PROTECTED TIER 2 QR',
                                style: TextStyle(
                                  color: _mutedText,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: unlocked
                                    ? const Color(0xFFECFDF3)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                unlocked ? 'UNLOCKED' : 'LOCKED',
                                style: TextStyle(
                                  color: unlocked
                                      ? const Color(0xFF15803D)
                                      : _mutedText,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _buildPresentationArea(),
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          Text(
                            _error!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: _navySurface,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          color: _brandRed,
                          size: 30,
                        ),
                        SizedBox(height: 14),
                        Text(
                          'How to Present Your Tier 2 QR',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '1. Unlock with your fingerprint only when an authorized school responder is ready to scan.\n'
                          '2. This single-use token expires automatically after 90 seconds and hides immediately if you switch apps.\n'
                          '3. The responder must also confirm their own enrolled staff biometrics before medical details are released.',
                          style: TextStyle(
                            color: Color(0xFFD0D7E3),
                            height: 1.5,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'No medical conditions, allergies, LRN, or contact numbers are embedded in or shown on this screen.',
                          style: TextStyle(
                            color: Color(0xFF8C9AB0),
                            height: 1.45,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
