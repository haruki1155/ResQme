import 'package:flutter/material.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import '../../qr/services/tier1_qr_repository.dart';
import '../widgets/tier2_profile_view.dart';

class StudentTier2QrScreen extends StatefulWidget {
  const StudentTier2QrScreen({
    super.key,
    required this.qrRepository,
  });

  final Tier1QrRepository qrRepository;

  @override
  State<StudentTier2QrScreen> createState() => _StudentTier2QrScreenState();
}

class _StudentTier2QrScreenState extends State<StudentTier2QrScreen> {
  static const _brandRed = Color(0xFFE92B32);
  static const _navySurface = Color(0xFF04081A);
  static const _bgSurface = Color(0xFFF4F6FA);
  static const _mutedText = Color(0xFF7B879B);

  Tier1QrCredential? _credential;
  bool _loading = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    final cached = widget.qrRepository.cachedCredential;
    if (cached != null) {
      _credential = cached;
    } else {
      _loadQr();
    }
  }

  Future<void> _loadQr({bool forceRefresh = false}) async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final result = await widget.qrRepository.ensureMineCredential(
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      setState(() => _credential = result);
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cred = _credential;
    final isActive = cred?.verificationStatus == 'active';

    return Scaffold(
      backgroundColor: _bgSurface,
      body: SafeArea(
        child: Column(
          children: [
            const Tier2TopBar(unlocked: false),
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
                                'TIER 2 EMERGENCY QR',
                                style: TextStyle(
                                  color: _mutedText,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            if (cred != null)
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
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        if (_loading && cred == null)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 48),
                            child: CircularProgressIndicator(),
                          )
                        else if (cred != null)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: const Color(0xFFE5EAF2),
                              ),
                            ),
                            child: SizedBox.square(
                              dimension: 228,
                              child: PrettyQrView.data(data: cred.payload),
                            ),
                          )
                        else if (_failed)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Column(
                              children: [
                                const Text(
                                  'Unable to load your QR right now.',
                                  style: TextStyle(color: _mutedText),
                                ),
                                const SizedBox(height: 12),
                                FilledButton(
                                  onPressed: () => _loadQr(forceRefresh: true),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _brandRed,
                                  ),
                                  child: const Text('Retry QR'),
                                ),
                              ],
                            ),
                          ),
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
                          Icons.medical_services_outlined,
                          color: _brandRed,
                          size: 30,
                        ),
                        SizedBox(height: 14),
                        Text(
                          'Emergency Medical QR Credential',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'This QR code is used during medical emergencies to securely retrieve your protected Tier 2 health details, allergies, medical conditions, and emergency contact information.',
                          style: TextStyle(
                            color: Color(0xFFD0D7E3),
                            height: 1.5,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'No medical or personal information is stored inside the QR code itself.',
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
