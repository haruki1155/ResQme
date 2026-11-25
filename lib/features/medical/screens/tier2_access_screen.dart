import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../registration/models/student_registration_profile.dart';
import '../../registration/services/student_registration_repository.dart';
import '../services/tier2_authorization_repository.dart';

class Tier2AccessScreen extends StatefulWidget {
  const Tier2AccessScreen({
    super.key,
    required this.repository,
    this.registrationRepository,
  });

  final Tier2AuthorizationRepository repository;
  final StudentRegistrationRepository? registrationRepository;

  @override
  State<Tier2AccessScreen> createState() => _Tier2AccessScreenState();
}

class _Tier2AccessScreenState extends State<Tier2AccessScreen>
    with WidgetsBindingObserver {
  static const _brandRed = Color(0xFFE92B32);
  static const _navySurface = Color(0xFF04081A);
  static const _bgSurface = Color(0xFFF4F6FA);
  static const _mutedText = Color(0xFF7B879B);
  static const _verifiedBg = Color(0xFF0A2E2B);
  static const _verifiedFg = Color(0xFF10B981);
  static const _allergyPill = Color(0xFF881337);

  final _password = TextEditingController();
  StreamSubscription<User?>? _authSubscription;
  Map<String, dynamic>? _record;
  StudentRegistrationProfile? _profile;
  String? _message, _loadedUid;
  bool _busy = false;
  int _generation = 0;
  bool _backgrounded = false;
  int _selectedTab = 0;
  final Set<String> _expandedAllergyCategories = {'Medicines'};

  void _clearProtectedState() {
    _generation++;
    _record = null;
    _profile = null;
    _message = null;
    _selectedTab = 0;
    _password.clear();
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
          _loadedUid = user?.uid;
          _message = null;
        });
      }
    });
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
        } catch (_) {
          // Keep unlocked Tier 2 medical data available even if profile lookup fails.
        }
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
        _selectedTab = 0;
        _password.clear();
      });
    } catch (error) {
      if (mounted &&
          !_backgrounded &&
          generation == _generation &&
          uid == widget.repository.currentUid) {
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

  List<String> _allergyItems(dynamic value) {
    if (value is! Map) return const [];
    if (value['state'] != 'listed') return const [];
    final detail = value['details'];
    if (detail is! String || detail.trim().isEmpty) return const [];
    return detail
        .split(RegExp(r'[,;\n]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'ST';
    if (parts.length == 1) {
      return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  String _displayName() {
    final profileName = _profile?.fullName.trim();
    if (profileName != null && profileName.isNotEmpty) return profileName;
    final contact = _record?['primaryContact'];
    if (contact is Map) {
      final fullName = contact['fullName']?.toString().trim();
      if (fullName != null && fullName.isNotEmpty) return fullName;
    }
    return 'Verified Student';
  }

  Widget _buildHeader(BuildContext context, {required bool unlocked}) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Material(
            color: const Color(0xFFF1F3F7),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => Navigator.of(context).maybePop(),
              child: const SizedBox(
                width: 40,
                height: 40,
                child: Icon(Icons.chevron_left, color: Color(0xFF111827)),
              ),
            ),
          ),
          const Expanded(
            child: Text(
              'Tier 2 information',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          IconButton(
            tooltip: unlocked ? 'Lock Tier 2 information' : 'Locked',
            onPressed: unlocked
                ? () => setState(() {
                    _clearProtectedState();
                  })
                : null,
            icon: Icon(
              unlocked ? Icons.lock_open_outlined : Icons.lock_outline,
              color: unlocked ? _verifiedFg : _mutedText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentityBanner() {
    final name = _displayName();
    return Container(
      width: double.infinity,
      color: _navySurface,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _brandRed,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              _initials(name),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Verified emergency profile',
                  style: TextStyle(color: _mutedText, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _verifiedBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'VERIFIED',
              style: TextStyle(
                color: _verifiedFg,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    const tabs = ['Basic info', 'Allergies', 'Medical', 'History'];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < tabs.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              ChoiceChip(
                label: Text(tabs[i]),
                selected: _selectedTab == i,
                showCheckmark: false,
                selectedColor: _brandRed,
                backgroundColor: const Color(0xFFF1F3F7),
                side: BorderSide.none,
                shape: const StadiumBorder(),
                labelStyle: TextStyle(
                  color: _selectedTab == i
                      ? Colors.white
                      : const Color(0xFF475569),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                onSelected: (_) => setState(() => _selectedTab = i),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 12),
    child: Text(
      text,
      style: const TextStyle(
        color: _mutedText,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.4,
      ),
    ),
  );

  Widget _detailRow(String label, String value, {bool showDivider = true}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: _mutedText,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          if (showDivider)
            const Divider(height: 1, thickness: 1, color: Color(0xFFF1F3F7)),
        ],
      );

  Widget _buildBasicInfoTab() {
    final contact = _record?['primaryContact'] is Map
        ? _record!['primaryContact'] as Map
        : const <String, dynamic>{};
    final guardianName = contact['fullName']?.toString().trim();
    final guardianRel = contact['relationship']?.toString().trim();
    final guardianPhone = contact['phoneNumber']?.toString().trim();
    final guardianDisplay = (guardianName != null && guardianName.isNotEmpty)
        ? (guardianRel != null && guardianRel.isNotEmpty
              ? '$guardianName ($guardianRel)'
              : guardianName)
        : 'Not provided';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionLabel('PERSONAL DETAILS'),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE5EAF2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _detailRow('FULL NAME', _displayName()),
              _detailRow(
                'AGE',
                _profile != null
                    ? '${_profile!.ageYearsAtRegistration} years old'
                    : 'Verified account',
              ),
              _detailRow(
                'CONTACT NUMBER',
                _profile?.personalPhone?.trim().isNotEmpty == true
                    ? _profile!.personalPhone!.trim()
                    : 'Not provided',
              ),
              _detailRow('PARENT / GUARDIAN', guardianDisplay),
              _detailRow(
                'GUARDIAN CONTACT',
                guardianPhone != null && guardianPhone.isNotEmpty
                    ? guardianPhone
                    : 'Not provided',
                showDivider: false,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAllergiesTab() {
    final allergyAnswer = _answer(_record?['allergies']);
    final items = _allergyItems(_record?['allergies']);
    const categories = [
      'Medicines',
      'Pollens',
      'Food',
      'Stinging insects',
      'Other',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionLabel('KNOWN ALLERGIES'),
        for (final category in categories) ...[
          _buildAllergyCategoryCard(
            category: category,
            pills: category == 'Medicines' ? items : const [],
            fallbackText: category == 'Medicines'
                ? allergyAnswer
                : 'No separate entries recorded',
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildAllergyCategoryCard({
    required String category,
    required List<String> pills,
    required String fallbackText,
  }) {
    final expanded = _expandedAllergyCategories.contains(category);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5EAF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => setState(() {
              if (expanded) {
                _expandedAllergyCategories.remove(category);
              } else {
                _expandedAllergyCategories.add(category);
              }
            }),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 14,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF1F5F9), _brandRed],
                        stops: [0.5, 0.5],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      category,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_down
                        : Icons.chevron_right,
                    color: _mutedText,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1, thickness: 1, color: Color(0xFFF1F3F7)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: pills.isNotEmpty
                  ? Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final item in pills)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: _allergyPill,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              item,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    )
                  : Text(
                      fallbackText,
                      style: const TextStyle(
                        color: _mutedText,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _clinicalCard(String label, String value) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE5EAF2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _mutedText,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.9,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );

  Widget _buildMedicalTab() {
    final bloodType = _record?['bloodType']?.toString().trim();
    final medication = _record?['currentMedication']?.toString().trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionLabel('CLINICAL OVERVIEW'),
        _clinicalCard('MEDICAL CONDITIONS', _answer(_record?['conditions'])),
        const SizedBox(height: 14),
        _clinicalCard(
          'BLOOD TYPE',
          bloodType != null && bloodType.isNotEmpty
              ? bloodType
              : 'Not recorded',
        ),
        const SizedBox(height: 14),
        _clinicalCard(
          'CURRENT MEDICATION',
          medication != null && medication.isNotEmpty
              ? medication
              : 'Not recorded',
        ),
      ],
    );
  }

  Widget _historyCard({
    required String category,
    required String title,
    required String subtitle,
  }) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE5EAF2)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF0F1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.add_circle_outline,
            color: _brandRed,
            size: 22,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category,
                style: const TextStyle(
                  color: _brandRed,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(color: _mutedText, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildHistoryTab() {
    final conditions = _answer(_record?['conditions']);
    final allergies = _answer(_record?['allergies']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionLabel('HEALTH RECORDS'),
        _historyCard(
          category: 'SELF-REPORTED PROFILE',
          title: 'Medical & Allergy Declaration',
          subtitle: 'Conditions: $conditions • Allergies: $allergies',
        ),
        const SizedBox(height: 14),
        _historyCard(
          category: 'HOSPITAL & IMMUNIZATION',
          title: 'No additional records on file',
          subtitle:
              'Hospital history and immunization entries are displayed here when recorded.',
        ),
      ],
    );
  }

  Widget _buildUnlockedBody() {
    return Column(
      children: [
        _buildIdentityBanner(),
        _buildTabBar(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            children: [
              switch (_selectedTab) {
                0 => _buildBasicInfoTab(),
                1 => _buildAllergiesTab(),
                2 => _buildMedicalTab(),
                _ => _buildHistoryTab(),
              },
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => setState(() {
                  _clearProtectedState();
                }),
                icon: const Icon(Icons.lock_outline),
                label: const Text('Lock Tier 2 information'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLockedBody() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
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
                'Private medical and emergency-contact information is released only after fresh biometric or password verification.',
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
                        ),
                      ),
                child: const Text('Set up biometrics with password'),
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
            _buildHeader(context, unlocked: unlocked),
            Expanded(
              child: unlocked ? _buildUnlockedBody() : _buildLockedBody(),
            ),
          ],
        ),
      ),
    );
  }
}
