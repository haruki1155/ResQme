import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import '../../qr/services/tier1_qr_repository.dart';
import '../../registration/models/student_registration_profile.dart';
import '../../registration/services/student_registration_repository.dart';
import '../services/tier2_authorization_repository.dart';
import '../widgets/tier2_profile_view.dart';

class Tier2AccessScreen extends StatefulWidget {
  const Tier2AccessScreen({
    super.key,
    required this.repository,
    this.registrationRepository,
    this.qrRepository,
  });

  final Tier2AuthorizationRepository repository;
  final StudentRegistrationRepository? registrationRepository;
  final Tier1QrRepository? qrRepository;

  @override
  State<Tier2AccessScreen> createState() => _Tier2AccessScreenState();
}

class _Tier2AccessScreenState extends State<Tier2AccessScreen>
    with WidgetsBindingObserver {
  static const _brandRed = Color(0xFFE92B32);
  static const _navySurface = Color(0xFF04081A);
  static const _bgSurface = Color(0xFFF4F6FA);
  static const _mutedText = Color(0xFF7B879B);

  final _password = TextEditingController();
  final _transferCode = TextEditingController();
  StreamSubscription<User?>? _authSubscription;
  Map<String, dynamic>? _record;
  StudentRegistrationProfile? _profile;
  Tier1QrCredential? _qrCredential;
  String? _generatedTransferCode;
  bool _showTransferCodeInput = false;
  bool _loadingQr = false;
  String? _message, _loadedUid;
  bool _busy = false;
  int _generation = 0;
  bool _backgrounded = false;

  void _clearProtectedState() {
    _generation++;
    _record = null;
    _profile = null;
    _generatedTransferCode = null;
    _showTransferCodeInput = false;
    _message = null;
    _password.clear();
    _transferCode.clear();
  }

  @override
  void initState() {
    super.initState();
    _loadedUid = widget.repository.currentUid;
    WidgetsBinding.instance.addObserver(this);
    _authSubscription = widget.repository.auth.userChanges().listen((user) {
      if (user?.uid != _loadedUid && mounted) {
        setState(() {
          _clearProtectedState();
          _qrCredential = null;
          _loadedUid = user?.uid;
          _message = null;
        });
        if (user != null) {
          _loadQrCredential();
        }
      }
    });
    _loadQrCredential();
  }

  Future<void> _loadQrCredential() async {
    final qrRepo = widget.qrRepository;
    final uid = widget.repository.currentUid;
    if (qrRepo == null || uid == null) return;
    setState(() => _loadingQr = true);
    try {
      final cred = await qrRepo.ensureMineCredential();
      if (!mounted || widget.repository.currentUid != uid) return;
      setState(() => _qrCredential = cred);
    } catch (_) {
      // QR card remains hidden if account is not yet QR-eligible.
    } finally {
      if (mounted) setState(() => _loadingQr = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _backgrounded = false;
    if ((state == AppLifecycleState.paused ||
            state == AppLifecycleState.hidden) &&
        mounted) {
      setState(() {
        _backgrounded = true;
        _clearProtectedState();
      });
    }
  }

  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    _password.dispose();
    _transferCode.dispose();
    _record = null;
    _profile = null;
    super.dispose();
  }

  Future<void> _run(Future<Map<String, dynamic>> Function() action) async {
    if (_busy || _backgrounded) return;
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _message = null;
      _record = null;
      _profile = null;
    });
    final uid = widget.repository.currentUid;
    try {
      final result = await action();
      StudentRegistrationProfile? profile;
      if (widget.registrationRepository != null) {
        try {
          final loaded = await widget.registrationRepository!.loadOwnProfile();
          profile = loaded.profile;
        } catch (_) {}
      }
      if (_qrCredential == null && widget.qrRepository != null) {
        try {
          _qrCredential = await widget.qrRepository!.ensureMineCredential();
        } catch (_) {}
      }
      if (!mounted ||
          _backgrounded ||
          generation != _generation ||
          uid == null ||
          widget.repository.currentUid != uid) {
        return;
      }
      setState(() {
        _record = result;
        _profile = profile;
        _loadedUid = uid;
        _password.clear();
      });
    } catch (error) {
      if (mounted &&
          !_backgrounded &&
          generation == _generation &&
          uid == widget.repository.currentUid) {
        final msg = error is Tier2AuthorizationFailure
            ? error.message
            : 'Tier 2 access could not be verified.';
        setState(() {
          if (msg.toLowerCase().contains('another personal device')) {
            _showTransferCodeInput = true;
          }
          _message = msg;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _generateTransferCode() async {
    if (_busy || _backgrounded) return;
    final generation = ++_generation;
    final uid = widget.repository.currentUid;
    setState(() {
      _busy = true;
      _message = null;
      _generatedTransferCode = null;
    });
    try {
      final code = await widget.repository.approveTrustedDeviceTransfer(
        _password.text,
      );
      if (mounted &&
          !_backgrounded &&
          generation == _generation &&
          uid == widget.repository.currentUid) {
        setState(() {
          _password.clear();
          _generatedTransferCode = code;
        });
      }
    } catch (error) {
      if (mounted &&
          !_backgrounded &&
          generation == _generation &&
          uid == widget.repository.currentUid) {
        setState(
          () => _message = error is Tier2AuthorizationFailure
              ? error.message
              : 'Unable to generate device transfer code.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disableBiometrics() async {
    if (_busy || _backgrounded) return;
    final generation = ++_generation;
    final uid = widget.repository.currentUid;
    setState(() {
      _busy = true;
      _message = null;
      _record = null;
      _profile = null;
    });
    try {
      await widget.repository.revokeDeviceWithPassword(_password.text);
      if (mounted &&
          !_backgrounded &&
          generation == _generation &&
          uid == widget.repository.currentUid) {
        setState(() {
          _password.clear();
          _loadedUid = null;
          _message =
              'Biometric access disabled for this account. Use your password or enroll this device again.';
        });
      }
    } catch (error) {
      if (mounted &&
          !_backgrounded &&
          generation == _generation &&
          uid == widget.repository.currentUid) {
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

  Widget _buildLockedQrSection() {
    if (widget.qrRepository == null) return const SizedBox.shrink();
    if (_loadingQr && _qrCredential == null) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 18),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final cred = _qrCredential;
    if (cred == null) return const SizedBox.shrink();
    final isActive = cred.verificationStatus == 'active';
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE5EAF2)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.qr_code_2, color: _brandRed, size: 22),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'YOUR EMERGENCY QR CODE',
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
                    color: isActive
                        ? const Color(0xFFECFDF3)
                        : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isActive ? 'ACTIVE' : 'PENDING',
                    style: TextStyle(
                      color: isActive
                          ? const Color(0xFF15803D)
                          : const Color(0xFFB45309),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5EAF2)),
              ),
              child: SizedBox.square(
                dimension: 200,
                child: PrettyQrView.data(data: cred.payload),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Staff or authorized personnel can scan this QR and confirm with their fingerprint to access your Tier 2 emergency profile.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _mutedText, fontSize: 12, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLockedBody() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildLockedQrSection(),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: _navySurface,
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.fingerprint, color: _brandRed, size: 36),
              SizedBox(height: 14),
              Text(
                'Protected Emergency Profile',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Unlock with biometrics or your password to view your full Tier 2 profile and emergency QR.',
                style: TextStyle(color: Color(0xFFB6C0CE), height: 1.45),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _busy
              ? null
              : () => _run(widget.repository.readWithBiometrics),
          icon: const Icon(Icons.fingerprint),
          label: const Text('Unlock with biometrics'),
          style: FilledButton.styleFrom(
            backgroundColor: _brandRed,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE5EAF2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'PASSWORD & BIOMETRIC MANAGEMENT',
                style: TextStyle(
                  color: _mutedText,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 12),
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
              if (_showTransferCodeInput) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _transferCode,
                  enabled: !_busy,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Replacement transfer code (TDX-...)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _run(
                        () => widget.repository.readWithPassword(
                          _password.text,
                        ),
                      ),
                child: const Text('Use password once'),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => _run(
                        () => widget.repository.enrollWithPassword(
                          _password.text,
                          transferCode: _transferCode.text,
                        ),
                      ),
                child: const Text('Set up biometrics with password'),
              ),
              TextButton(
                onPressed: _busy ? null : _generateTransferCode,
                child: const Text('Generate transfer code for new device'),
              ),
              if (_generatedTransferCode != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: SelectableText(
                    'Transfer Code (valid 10 min): $_generatedTransferCode',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              TextButton(
                onPressed: _busy ? null : _disableBiometrics,
                child: const Text('Disable biometric access'),
              ),
            ],
          ),
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
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = _record != null;
    return Scaffold(
      backgroundColor: _bgSurface,
      body: SafeArea(
        child: Column(
          children: [
            Tier2TopBar(
              unlocked: unlocked,
              onLock: () => setState(_clearProtectedState),
            ),
            Expanded(
              child: unlocked
                  ? Tier2ProfileView(
                      record: _record!,
                      fullName: _profile?.fullName,
                      ageYears: _profile?.ageYearsAtRegistration,
                      personalPhone: _profile?.personalPhone,
                      qrPayload: _qrCredential?.payload,
                      qrStatusLabel:
                          _qrCredential?.verificationStatus == 'active'
                          ? 'ACTIVE'
                          : _qrCredential != null
                          ? 'PENDING'
                          : null,
                      onLock: () => setState(_clearProtectedState),
                    )
                  : _buildLockedBody(),
            ),
          ],
        ),
      ),
    );
  }
}
