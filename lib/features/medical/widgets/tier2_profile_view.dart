import 'package:flutter/material.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

class Tier2ProfileView extends StatefulWidget {
  const Tier2ProfileView({
    super.key,
    required this.record,
    required this.onLock,
    this.fullName,
    this.ageYears,
    this.personalPhone,
    this.qrPayload,
    this.qrStatusLabel,
    this.securityNotice,
    this.lockButtonLabel = 'Lock Tier 2 information',
    this.initialTab = 0,
  });

  final Map<String, dynamic> record;
  final VoidCallback onLock;
  final String? fullName;
  final int? ageYears;
  final String? personalPhone;
  final String? qrPayload;
  final String? qrStatusLabel;
  final String? securityNotice;
  final String lockButtonLabel;
  final int initialTab;

  @override
  State<Tier2ProfileView> createState() => _Tier2ProfileViewState();
}

class _Tier2ProfileViewState extends State<Tier2ProfileView> {
  static const _brandRed = Color(0xFFE92B32);
  static const _navySurface = Color(0xFF04081A);
  static const _mutedText = Color(0xFF7B879B);
  static const _verifiedBg = Color(0xFF0A2E2B);
  static const _verifiedFg = Color(0xFF10B981);
  static const _allergyPill = Color(0xFF881337);

  late int _selectedTab;
  final Set<String> _expandedAllergyCategories = {'Medicines'};

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab.clamp(0, 3);
  }

  String _answer(dynamic value) {
    if (value is! Map) return 'Not available';
    final state = value['state'];
    final detail = value['details'];
    if (state == 'listed' && detail is String && detail.trim().isNotEmpty) {
      return detail.trim();
    }
    return switch (state) {
      'unknown' => 'Unknown',
      'none_known' => 'None known',
      _ => 'Not available',
    };
  }

  List<String> _allergyItems(dynamic value) {
    if (value is! Map || value['state'] != 'listed') return const [];
    final detail = value['details'];
    if (detail is! String || detail.trim().isEmpty) return const [];
    return detail
        .split(RegExp(r'[,;\n]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  String _displayName() {
    final explicit = widget.fullName?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final fromRecord = widget.record['fullName']?.toString().trim();
    if (fromRecord != null && fromRecord.isNotEmpty) return fromRecord;
    final contact = widget.record['primaryContact'];
    if (contact is Map) {
      final contactName = contact['fullName']?.toString().trim();
      if (contactName != null && contactName.isNotEmpty) return contactName;
    }
    return 'Verified Student';
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'ST';
    if (parts.length == 1) {
      return parts.first
          .substring(0, parts.first.length >= 2 ? 2 : 1)
          .toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
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

  Widget _buildQrCard() {
    final payload = widget.qrPayload;
    if (payload == null || payload.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
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
                    'EMERGENCY RESQME QR',
                    style: TextStyle(
                      color: _mutedText,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                if (widget.qrStatusLabel != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.qrStatusLabel!,
                      style: const TextStyle(
                        color: Color(0xFF15803D),
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
                dimension: 184,
                child: PrettyQrView.data(data: payload),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Authorized school staff can scan this QR and confirm with their device fingerprint to open your Tier 2 emergency profile.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _mutedText, fontSize: 12, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoTab() {
    final contact = widget.record['primaryContact'] is Map
        ? widget.record['primaryContact'] as Map
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
        _buildQrCard(),
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
                widget.ageYears != null
                    ? '${widget.ageYears} years old'
                    : 'Verified account',
              ),
              _detailRow(
                'CONTACT NUMBER',
                widget.personalPhone?.trim().isNotEmpty == true
                    ? widget.personalPhone!.trim()
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
    final allergyAnswer = _answer(widget.record['allergies']);
    final items = _allergyItems(widget.record['allergies']);
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
    final bloodType = widget.record['bloodType']?.toString().trim();
    final medication = widget.record['currentMedication']?.toString().trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionLabel('CLINICAL OVERVIEW'),
        _clinicalCard(
          'MEDICAL CONDITIONS',
          _answer(widget.record['conditions']),
        ),
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
    final conditions = _answer(widget.record['conditions']);
    final allergies = _answer(widget.record['allergies']);
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

  @override
  Widget build(BuildContext context) {
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
              if (widget.securityNotice != null) ...[
                const SizedBox(height: 18),
                Text(
                  widget.securityNotice!,
                  style: const TextStyle(
                    color: _mutedText,
                    fontSize: 12,
                    height: 1.45,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: widget.onLock,
                icon: const Icon(Icons.lock_outline),
                label: Text(widget.lockButtonLabel),
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
}

class Tier2TopBar extends StatelessWidget {
  const Tier2TopBar({
    super.key,
    required this.unlocked,
    this.onLock,
    this.title = 'Tier 2 information',
  });

  final bool unlocked;
  final VoidCallback? onLock;
  final String title;

  @override
  Widget build(BuildContext context) {
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
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          IconButton(
            tooltip: unlocked ? 'Lock Tier 2 information' : 'Locked',
            onPressed: unlocked ? onLock : null,
            icon: Icon(
              unlocked ? Icons.lock_open_outlined : Icons.lock_outline,
              color: unlocked
                  ? const Color(0xFF10B981)
                  : const Color(0xFF7B879B),
            ),
          ),
        ],
      ),
    );
  }
}
