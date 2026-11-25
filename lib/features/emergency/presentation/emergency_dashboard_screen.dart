import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:resqme/app/app_routes.dart';
import 'package:resqme/features/qr/services/tier1_qr_repository.dart';
import 'package:resqme/features/registration/models/student_registration_profile.dart';
import 'package:resqme/features/registration/services/student_registration_repository.dart';

class EmergencyDashboardScreen extends StatefulWidget {
  const EmergencyDashboardScreen({
    super.key,
    this.accountPanel,
    this.registrationRepository,
    this.qrRepository,
    this.authChanges,
  });

  final Widget? accountPanel;
  final StudentRegistrationRepository? registrationRepository;
  final Tier1QrRepository? qrRepository;
  final Stream<void>? authChanges;

  @override
  State<EmergencyDashboardScreen> createState() =>
      _EmergencyDashboardScreenState();
}

class _EmergencyDashboardScreenState extends State<EmergencyDashboardScreen>
    with WidgetsBindingObserver {
  StreamSubscription<void>? _authSub;
  StudentRegistrationProfile? _profile;
  Tier1QrCredential? _qrCredential;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authSub = widget.authChanges?.listen((_) => _loadStatus());
    _loadStatus();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadStatus();
    }
  }

  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    final reg = widget.registrationRepository;
    if (reg == null) return;
    final run = ++_generation;
    try {
      final result = await reg.loadOwnProfile();
      if (!mounted || run != _generation) return;
      if (result.state == RegistrationState.signedOut ||
          result.profile == null) {
        setState(() {
          _profile = null;
          _qrCredential = null;
        });
        return;
      }
      Tier1QrCredential? cred;
      if (widget.qrRepository != null) {
        try {
          cred = await widget.qrRepository!.ensureMineCredential();
        } catch (_) {}
      }
      if (!mounted || run != _generation) return;
      setState(() {
        _profile = result.profile;
        _qrCredential = cred;
      });
    } catch (_) {
      // Keep public emergency support available if status fetch fails.
    }
  }

  String _greetingText() {
    final name = _profile?.fullName.trim();
    if (name == null || name.isEmpty) return 'Good day,';
    return 'Good day, $name';
  }

  (String, Color) _resqmeStatus() {
    final profile = _profile;
    if (profile == null) {
      return (
        'Public emergency support is available',
        const Color(0xFF54E0B6),
      );
    }
    if (profile.schoolApprovalStatus == 'revoked') {
      return ('QR access unavailable', const Color(0xFFFCA5A5));
    }
    if (profile.schoolApprovalStatus == 'approved') {
      if (profile.medicalStatus != 'complete') {
        return ('Verified • Complete medical info', const Color(0xFFFBBF24));
      }
      if (_qrCredential?.verificationStatus == 'active') {
        return ('Verified • Active QR ready', const Color(0xFF54E0B6));
      }
      return ('Verified student account', const Color(0xFF54E0B6));
    }
    if (profile.status == 'pending_guardian') {
      return ('Pending guardian authorization', const Color(0xFFFBBF24));
    }
    return ('Pending school verification', const Color(0xFFFBBF24));
  }

  Future<void> _openQuickQrOrScanner() async {
    if (_profile == null || widget.qrRepository == null) {
      if (!mounted) return;
      await Navigator.of(context).pushNamed(AppRoutes.scanner);
      return;
    }
    var cred = _qrCredential;
    if (cred == null) {
      try {
        cred = await widget.qrRepository!.ensureMineCredential();
        if (mounted) setState(() => _qrCredential = cred);
      } catch (_) {}
    }
    if (!mounted) return;
    if (cred == null) {
      await Navigator.of(context).pushNamed(AppRoutes.profile);
      await _loadStatus();
      return;
    }
    final active = cred.verificationStatus == 'active';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'My ResQMe QR',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: active
                          ? const Color(0xFFECFDF3)
                          : const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      active ? 'ACTIVE' : 'PENDING',
                      style: TextStyle(
                        color: active
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
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE5EAF2)),
                ),
                child: SizedBox.square(
                  dimension: 220,
                  child: PrettyQrView.data(data: cred!.payload),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                active
                    ? 'Show this QR to authorized school staff for Tier 2 emergency access.'
                    : 'Your QR will activate once school verification and requirements are complete.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        Navigator.of(context).pushNamed(AppRoutes.scanner);
                      },
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Scan QR'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        Navigator.of(context).pushNamed(AppRoutes.profile);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFE92B32),
                      ),
                      child: const Text('My Account'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const destinations = [
      _EmergencyDestination(
        'Tier 2 information',
        'Restricted personal information',
        Icons.lock_outline,
        true,
        AppRoutes.medicalBoundary,
      ),
      _EmergencyDestination(
        'First-aid instructions',
        'Quick guidance for common injuries',
        Icons.add_circle_outline,
        false,
        AppRoutes.firstAid,
      ),
      _EmergencyDestination(
        'Emergency hotlines',
        'One-tap access to emergency services',
        Icons.call_outlined,
        false,
        AppRoutes.hotlines,
      ),
      _EmergencyDestination(
        'DRRM instructions',
        'Preparedness for disasters & hazards',
        Icons.shield_outlined,
        false,
        AppRoutes.drrm,
      ),
    ];

    final (statusText, statusColor) = _resqmeStatus();

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ListView(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE92B32),
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'RESQME  |  QR ID',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 42),
                            Text(
                              _greetingText(),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Ready when it matters.',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Material(
                              color: const Color(0x33FFFFFF),
                              borderRadius: const BorderRadius.all(
                                Radius.circular(20),
                              ),
                              child: InkWell(
                                borderRadius: const BorderRadius.all(
                                  Radius.circular(20),
                                ),
                                onTap: _profile != null
                                    ? _openQuickQrOrScanner
                                    : null,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.qr_code_2,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'RESQME STATUS',
                                              style: TextStyle(
                                                color: Colors.white70,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            Text(
                                              statusText,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.circle,
                                        color: statusColor,
                                        size: 16,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ?widget.accountPanel,
                      const SizedBox(height: 36),
                      const Text(
                        'PUBLIC ACCESS',
                        style: TextStyle(
                          color: Color(0xFFE92B32),
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const _SectionHeading(),
                      const SizedBox(height: 18),
                      ...destinations.map(_EmergencyDestinationCard.new),
                      const SizedBox(height: 34),
                      _BottomNavigationVisual(
                        onQrPressed: _openQuickQrOrScanner,
                        onProfilePressed: () async {
                          await Navigator.of(
                            context,
                          ).pushNamed(AppRoutes.profile);
                          await _loadStatus();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _EmergencyDestination {
  const _EmergencyDestination(
    this.label,
    this.description,
    this.icon,
    this.isRestricted,
    this.route,
  );

  final String label;
  final String description;
  final IconData icon;
  final bool isRestricted;
  final String route;
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading();

  @override
  Widget build(BuildContext context) {
    const title = Text(
      'Tier 1 information',
      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
    );
    const count = Text(
      '4 services',
      style: TextStyle(color: Color(0xFF8C9AB0), fontWeight: FontWeight.w700),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 460) {
          return const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [title, SizedBox(height: 4), count],
          );
        }

        return const Row(children: [title, Spacer(), count]);
      },
    );
  }
}

class _EmergencyDestinationCard extends StatelessWidget {
  const _EmergencyDestinationCard(this.destination);

  final _EmergencyDestination destination;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: destination.label,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.of(context).pushNamed(destination.route),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: destination.isRestricted
                          ? const Color(0xFF02061E)
                          : const Color(0xFFFFF0F1),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      destination.icon,
                      color: destination.isRestricted
                          ? Colors.white
                          : const Color(0xFFE92B32),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          destination.label,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          destination.description,
                          style: const TextStyle(color: Color(0xFF8C9AB0)),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Color(0xFFB6C0CE)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavigationVisual extends StatelessWidget {
  const _BottomNavigationVisual({
    required this.onQrPressed,
    required this.onProfilePressed,
  });

  final VoidCallback onQrPressed;
  final VoidCallback onProfilePressed;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 32),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Icon(Icons.home_outlined, color: Color(0xFFE92B32)),
        IconButton(
          tooltip: 'Scan QR',
          icon: const Icon(Icons.qr_code_2, size: 34),
          onPressed: onQrPressed,
        ),
        IconButton(
          tooltip: 'Profile',
          icon: const Icon(Icons.person_outline, color: Color(0xFF8C9AB0)),
          onPressed: onProfilePressed,
        ),
      ],
    ),
  );
}
