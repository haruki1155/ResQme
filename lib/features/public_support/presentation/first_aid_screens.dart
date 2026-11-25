import 'package:flutter/material.dart';
import 'package:resqme/core/config/first_aid_feature_flags.dart';
import 'package:resqme/features/public_support/data/first_aid_repository.dart';
import 'package:resqme/features/public_support/data/original_first_aid_guides.dart';
import 'package:resqme/features/public_support/domain/first_aid_models.dart';
import 'package:resqme/features/public_support/domain/first_aid_release_policy.dart';
import 'package:resqme/features/public_support/domain/first_aid_search_engine.dart';
import 'package:resqme/features/public_support/presentation/emergency_call_helper.dart';

export 'package:resqme/features/public_support/data/original_first_aid_guides.dart'
    show
        FirstAidGuide,
        allOriginalFirstAidGuides,
        eligibleOriginalFirstAidGuides,
        withheldOriginalFirstAidGuides;

const _brandRed = Color(0xFFE3222A);
const _darkSurface = Color(0xFF080B1D);
const _ink = Color(0xFF10131C);
const _bodyInk = Color(0xFF1D2433);
const _mutedInk = Color(0xFF526075);
const _pageBg = Color(0xFFF5F6F8);
const _borderSubtle = Color(0xFFDDE3EC);
const _warningRed = Color(0xFFB42318);
const _warningBg = Color(0xFFFEF3F2);
const _amberBorder = Color(0xFFB54708);
const _amberBg = Color(0xFFFFFAEB);

const List<String> _featuredEmergencyIds = <String>[
  'cpr-adult',
  'choking-adult',
  'severe-bleeding',
  'stroke',
  'cardiac-chest-pain',
  'anaphylaxis',
  'seizures',
  'drowning',
  'burns',
  'heatstroke',
];

class FirstAidLibraryScreen extends StatefulWidget {
  const FirstAidLibraryScreen({
    super.key,
    this.repository,
    this.releasePolicy,
    this.openDialer,
    @visibleForTesting this.debugEnableExpandedFirstAidOverride,
  });

  final FirstAidRepository? repository;
  final FirstAidReleasePolicy? releasePolicy;
  final EmergencyDialerOpener? openDialer;
  final bool? debugEnableExpandedFirstAidOverride;

  @override
  State<FirstAidLibraryScreen> createState() => _FirstAidLibraryScreenState();
}

class _FirstAidLibraryScreenState extends State<FirstAidLibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  FirstAidLibraryBundle? _syncBundle;
  Future<FirstAidLibraryBundle>? _bundleFuture;
  String _query = '';
  String _selectedCategory = 'All';

  bool get _isExpandedEnabled =>
      widget.debugEnableExpandedFirstAidOverride ??
      FirstAidFeatureFlags.enableExpandedFirstAid;

  FirstAidReleasePolicy get _effectivePolicy =>
      widget.releasePolicy ?? FirstAidReleasePolicy.fromEnvironment();

  @override
  void initState() {
    super.initState();
    _configureDataSource();
  }

  @override
  void didUpdateWidget(covariant FirstAidLibraryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository ||
        oldWidget.releasePolicy != widget.releasePolicy ||
        oldWidget.debugEnableExpandedFirstAidOverride !=
            widget.debugEnableExpandedFirstAidOverride) {
      _configureDataSource();
    }
  }

  void _configureDataSource() {
    if (!_isExpandedEnabled) {
      _syncBundle = null;
      _bundleFuture = null;
      return;
    }
    final repo = widget.repository ?? FirstAidRepository();
    _syncBundle = repo.tryLoadLibrarySync(policy: _effectivePolicy);
    _bundleFuture = repo.loadLibrary(policy: _effectivePolicy);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _submitSearch() {
    FocusScope.of(context).unfocus();
    setState(() => _query = _searchController.text);
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _selectedCategory = 'All';
    });
  }

  void _openQuickInstruction(
    FirstAidTopic topic,
    FirstAidLibraryBundle bundle,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FirstAidQuickInstructionScreen(
          topic: topic,
          bundle: bundle,
          openDialer: widget.openDialer,
          releasePolicy: _effectivePolicy,
          debugEnableExpandedFirstAidOverride:
              widget.debugEnableExpandedFirstAidOverride,
        ),
      ),
    );
  }

  void _openLearningLibrary(FirstAidLibraryBundle bundle) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FirstAidLearningLibraryScreen(
          bundle: bundle,
          openDialer: widget.openDialer,
          releasePolicy: _effectivePolicy,
          debugEnableExpandedFirstAidOverride:
              widget.debugEnableExpandedFirstAidOverride,
        ),
      ),
    );
  }

  Widget _buildEmergencyShortcutBar({
    Key callKey = const Key('first_aid_call_911_button'),
    Key hotlinesKey = const Key('first_aid_hotlines_button'),
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _darkSurface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(
                Icons.emergency_outlined,
                color: Color(0xFFFF6974),
                size: 20,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'LIFE-THREATENING EMERGENCY? CALL FOR HELP FIRST',
                  style: TextStyle(
                    color: Color(0xFFFF8A93),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 150, minHeight: 48),
                child: FilledButton.icon(
                  key: callKey,
                  onPressed: () => EmergencyCallHelper.confirmAndOpen911(
                    context,
                    openDialer: widget.openDialer,
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _brandRed,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(150, 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  icon: const Icon(Icons.phone_outlined, size: 20),
                  label: const Text('Call 911'),
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 150, minHeight: 48),
                child: OutlinedButton.icon(
                  key: hotlinesKey,
                  onPressed: () => EmergencyCallHelper.openHotlinesDirectory(
                    context,
                    openDialer: widget.openDialer,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF475467)),
                    minimumSize: const Size(150, 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  icon: const Icon(Icons.contact_phone_outlined, size: 20),
                  label: const Text('Hotlines (143)'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            key: const Key('first_aid_search_field'),
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onChanged: (value) => setState(() => _query = value),
            onSubmitted: (_) => _submitSearch(),
            style: const TextStyle(fontSize: 16, color: _ink),
            decoration: InputDecoration(
              hintText: 'Search injury, symptom, or Filipino term',
              hintStyle: const TextStyle(
                fontSize: 15,
                color: Color(0xFF667085),
              ),
              prefixIcon: const Icon(
                Icons.search,
                size: 22,
                color: Color(0xFF667085),
              ),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.close, size: 20),
                    ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 15,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _borderSubtle),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _borderSubtle),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _brandRed, width: 1.6),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          tooltip: 'Search guides',
          onPressed: _submitSearch,
          style: IconButton.styleFrom(
            backgroundColor: _brandRed,
            foregroundColor: Colors.white,
            minimumSize: const Size(52, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          icon: const Icon(Icons.search, size: 24),
        ),
      ],
    );
  }

  Widget _buildCommonEmergenciesSection(FirstAidLibraryBundle bundle) {
    final commonTopics = <FirstAidTopic>[];
    for (final id in _featuredEmergencyIds) {
      final found = bundle.topicById(id);
      if (found != null) {
        commonTopics.add(found);
      }
    }
    if (commonTopics.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'COMMON EMERGENCIES',
          style: TextStyle(
            color: _brandRed,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Tap any emergency for immediate step-by-step action.',
          style: TextStyle(color: _mutedInk, fontSize: 14, height: 1.4),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final topic in commonTopics)
              Semantics(
                button: true,
                label: 'Quick emergency guide: ${topic.shortTitle}',
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    key: Key('common_emergency_${topic.id}'),
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _openQuickInstruction(topic, bundle),
                    child: Container(
                      constraints: const BoxConstraints(
                        minHeight: 52,
                        minWidth: 140,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFECDCA)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(topic.iconData, color: _brandRed, size: 20),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              topic.shortTitle,
                              style: const TextStyle(
                                color: _ink,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                height: 1.25,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryChips(List<String> categories) {
    final allCategories = <String>['All', ...categories];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CATEGORIES',
          style: TextStyle(
            color: _mutedInk,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final cat in allCategories)
              ChoiceChip(
                key: Key('category_chip_$cat'),
                label: Text(cat),
                selected: _selectedCategory == cat,
                materialTapTargetSize: MaterialTapTargetSize.padded,
                selectedColor: const Color(0xFFFFE4E6),
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: _selectedCategory == cat ? _brandRed : _borderSubtle,
                ),
                labelStyle: TextStyle(
                  color: _selectedCategory == cat ? _brandRed : _ink,
                  fontSize: 14,
                  fontWeight: _selectedCategory == cat
                      ? FontWeight.w800
                      : FontWeight.w600,
                ),
                onSelected: (_) => setState(() => _selectedCategory = cat),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildProcedureCard(
    FirstAidTopic topic,
    FirstAidLibraryBundle bundle,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          key: Key('topic_card_${topic.id}'),
          borderRadius: BorderRadius.circular(18),
          onTap: () => _openQuickInstruction(topic, bundle),
          child: Container(
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: topic.isTrainedResponderOnly
                    ? _amberBorder
                    : const Color(0xFFE4E7EC),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: topic.isTrainedResponderOnly
                            ? _amberBg
                            : const Color(0xFFFFF1F2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        topic.iconData,
                        color: topic.isTrainedResponderOnly
                            ? _amberBorder
                            : _brandRed,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            topic.title,
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _StatusBadge(
                                icon: Icons.folder_outlined,
                                label: topic.category,
                                foreground: _mutedInk,
                                background: const Color(0xFFF2F4F7),
                                border: const Color(0xFFD0D5DD),
                              ),
                              if (topic.ageGroup != 'all_ages')
                                _StatusBadge(
                                  icon: Icons.person_outline,
                                  label: topic.ageGroupLabel,
                                  foreground: const Color(0xFF175CD3),
                                  background: const Color(0xFFEFF8FF),
                                  border: const Color(0xFFB2DDFF),
                                ),
                              if (topic.isTrainedResponderOnly)
                                const _StatusBadge(
                                  icon: Icons.health_and_safety_outlined,
                                  label: 'TRAINED RESPONDER ONLY',
                                  foreground: _amberBorder,
                                  background: _amberBg,
                                  border: _amberBorder,
                                )
                              else if (topic.isCriticalEmergency)
                                const _StatusBadge(
                                  icon: Icons.priority_high,
                                  label: 'CRITICAL EMERGENCY',
                                  foreground: _warningRed,
                                  background: _warningBg,
                                  border: Color(0xFFFDA29B),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.chevron_right,
                      color: _mutedInk,
                      size: 24,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  topic.quickInstructions.immediateAction,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _bodyInk,
                    fontSize: 16,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptySearchState(FirstAidLibraryBundle bundle) {
    final fallbackTopics = <FirstAidTopic>[];
    for (final id in const [
      'cpr-adult',
      'choking-adult',
      'severe-bleeding',
      'stroke',
      'burns',
    ]) {
      final t = bundle.topicById(id);
      if (t != null) fallbackTopics.add(t);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.search_off, color: _brandRed, size: 24),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'No guides found',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'No first-aid procedure matched your search or selected category. Clear filters or choose a common emergency below, or call 911 immediately if life is in danger.',
            style: TextStyle(color: _bodyInk, fontSize: 16, height: 1.45),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _clearFilters,
            style: OutlinedButton.styleFrom(
              foregroundColor: _brandRed,
              side: const BorderSide(color: _brandRed),
              minimumSize: const Size.fromHeight(48),
            ),
            icon: const Icon(Icons.refresh),
            label: const Text('Clear search & filters'),
          ),
          if (fallbackTopics.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'SUGGESTED COMMON EMERGENCIES',
              style: TextStyle(
                color: _mutedInk,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final topic in fallbackTopics)
                  ActionChip(
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    avatar: Icon(topic.iconData, size: 18, color: _brandRed),
                    label: Text(topic.shortTitle),
                    onPressed: () => _openQuickInstruction(topic, bundle),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Feature OFF: render the restored Original First Aid Instruction experience.
    if (!_isExpandedEnabled) {
      return _OriginalFirstAidLibraryScaffold(
        openDialer: widget.openDialer,
        fallbackBannerMessage: null,
      );
    }

    return FutureBuilder<FirstAidLibraryBundle>(
      initialData: _syncBundle,
      future: _bundleFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Scaffold(
            backgroundColor: _pageBg,
            appBar: _buildStandardFirstAidAppBar(context),
            body: SafeArea(
              top: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                    children: [
                      _buildEmergencyShortcutBar(),
                      const SizedBox(height: 24),
                      const Text(
                        'Loading offline first-aid procedures...',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _mutedInk, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        final bundle = snapshot.data!;

        // Task 4 Safe Fallback: when Feature ON is set, FirstAidReleasePolicy is
        // enforced, and NO expanded procedures are eligible for publication,
        // safely retain the eligible original library and emergency assistance.
        if (!bundle.hasLoadError &&
            bundle.topics.isEmpty &&
            bundle.excludedPendingApprovalCount > 0) {
          return _OriginalFirstAidLibraryScaffold(
            openDialer: widget.openDialer,
            fallbackBannerKey: const Key(
              'public_release_pending_approval_banner',
            ),
            fallbackBannerMessage:
                'Expanded IFRC 2025 procedures (${bundle.excludedPendingApprovalCount}) are awaiting clinical sign-off. Showing eligible baseline first-aid guides and emergency calling.',
          );
        }

        final filteredTopics = FirstAidSearchEngine.search(
          bundle.topics,
          query: _query,
          category: _selectedCategory,
        );
        final hasDraftTopics = bundle.topics.any(
          (t) => !t.review.isClinicallyApproved,
        );

        return Scaffold(
          backgroundColor: _pageBg,
          appBar: _buildStandardFirstAidAppBar(context),
          body: SafeArea(
            top: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                  children: [
                    const Text(
                      'IMMEDIATE CARE GUIDE',
                      style: TextStyle(
                        color: _brandRed,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Act first.\nLearn more when needed.',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        height: 1.18,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Offline emergency procedures adapted from IFRC 2025 Guidelines.',
                      style: TextStyle(
                        color: _mutedInk,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildEmergencyShortcutBar(),
                    if (hasDraftTopics) ...[
                      const SizedBox(height: 12),
                      const _ClinicalReviewDraftBanner(),
                    ],
                    if (bundle.hasLoadError) ...[
                      const SizedBox(height: 16),
                      _LoadErrorCard(message: bundle.loadError!),
                    ] else ...[
                      const SizedBox(height: 16),
                      _buildSearchField(),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        key: const Key('open_learning_library_button'),
                        onPressed: () => _openLearningLibrary(bundle),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: _ink,
                          side: const BorderSide(color: _borderSubtle),
                          minimumSize: const Size.fromHeight(52),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(
                          Icons.menu_book_outlined,
                          color: _brandRed,
                        ),
                        label: const Text(
                          'Learning Library — Learn More',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (_query.trim().isEmpty &&
                          _selectedCategory == 'All') ...[
                        const SizedBox(height: 22),
                        _buildCommonEmergenciesSection(bundle),
                      ],
                      const SizedBox(height: 22),
                      _buildCategoryChips(bundle.categories),
                      const SizedBox(height: 20),
                      Text(
                        '${filteredTopics.length} ${filteredTopics.length == 1 ? 'PROCEDURE' : 'PROCEDURES'}',
                        style: const TextStyle(
                          color: _mutedInk,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (filteredTopics.isEmpty)
                        _buildEmptySearchState(bundle)
                      else
                        for (final topic in filteredTopics)
                          _buildProcedureCard(topic, bundle),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

PreferredSizeWidget _buildStandardFirstAidAppBar(
  BuildContext context, {
  List<Widget>? actions,
}) {
  return AppBar(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    foregroundColor: _ink,
    centerTitle: true,
    toolbarHeight: 72,
    leadingWidth: 72,
    leading: Center(
      child: IconButton(
        tooltip: 'Back',
        onPressed: () => Navigator.of(context).maybePop(),
        style: IconButton.styleFrom(
          backgroundColor: const Color(0xFFF3F5F8),
          minimumSize: const Size(48, 48),
        ),
        icon: const Icon(Icons.chevron_left, size: 29),
      ),
    ),
    title: const Text(
      'First-aid instructions',
      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
    ),
    actions: actions,
  );
}

/// Restored Original First Aid Instruction experience (from `39957a7`),
/// displaying only safety-eligible original guides while preserving Call 911
/// and Emergency Hotlines.
class _OriginalFirstAidLibraryScaffold extends StatefulWidget {
  const _OriginalFirstAidLibraryScaffold({
    this.openDialer,
    this.fallbackBannerMessage,
    this.fallbackBannerKey,
  });

  final EmergencyDialerOpener? openDialer;
  final String? fallbackBannerMessage;
  final Key? fallbackBannerKey;

  @override
  State<_OriginalFirstAidLibraryScaffold> createState() =>
      _OriginalFirstAidLibraryScaffoldState();
}

class _OriginalFirstAidLibraryScaffoldState
    extends State<_OriginalFirstAidLibraryScaffold> {
  static const _muted = Color(0xFF697789);
  final TextEditingController _search = TextEditingController();
  String _query = '';
  String _category = 'All';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _submitSearch() {
    FocusScope.of(context).unfocus();
    setState(() => _query = _search.text);
  }

  void _clearFilters() {
    _search.clear();
    setState(() {
      _query = '';
      _category = 'All';
    });
  }

  Widget _guideCard(
    FirstAidGuide guide, {
    required bool initiallyExpanded,
  }) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFFF0F1F4)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0D101828),
          blurRadius: 5,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: ExpansionTile(
        key: PageStorageKey(guide.title),
        initiallyExpanded: initiallyExpanded,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: const Border(),
        collapsedShape: const Border(),
        iconColor: const Color(0xFFA4ADBA),
        collapsedIconColor: const Color(0xFFA4ADBA),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1F2),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(guide.icon, color: _brandRed, size: 23),
        ),
        title: Text(
          guide.title,
          style: const TextStyle(
            color: _ink,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            height: 1.3,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            guide.category,
            style: const TextStyle(color: _muted, fontSize: 12, height: 1.4),
          ),
        ),
        children: [
          const Divider(height: 1, color: Color(0xFFF0F1F4)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F8FA),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BEFORE YOU BEGIN',
                        style: TextStyle(
                          color: _muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Use professional emergency services for serious or life-threatening conditions.',
                        style: TextStyle(
                          color: Color(0xFF455165),
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'WHAT TO DO',
                  style: TextStyle(
                    color: _brandRed,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                for (final section in guide.details.split('\n\n'))
                  _instruction(section),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => FirstAidDetailScreen(
                        guide: guide,
                        openDialer: widget.openDialer,
                      ),
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: _brandRed,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Open full guide'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _instruction(String section) {
    final match = RegExp(r'^Step (\d+):\s*').firstMatch(section);
    final text = Text(
      match == null ? section : section.substring(match.end),
      style: const TextStyle(
        color: Color(0xFF455165),
        fontSize: 14,
        height: 1.55,
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: match == null
          ? text
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: _brandRed,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    match.group(1)!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: text),
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final eligibleGuides = eligibleOriginalFirstAidGuides;
    final categories = <String>[
      'All',
      ...{for (final guide in eligibleGuides) guide.category},
    ];
    final guides = eligibleGuides
        .where(
          (guide) =>
              (_category == 'All' || guide.category == _category) &&
              guide.title.toLowerCase().contains(_query.trim().toLowerCase()),
        )
        .toList(growable: false);

    return Scaffold(
      backgroundColor: _pageBg,
      appBar: _buildStandardFirstAidAppBar(
        context,
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 22),
            child: Icon(Icons.add_circle_outline, color: _brandRed, size: 25),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              children: [
                const Text(
                  'IMMEDIATE CARE GUIDE',
                  style: TextStyle(
                    color: _brandRed,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'What do you need\nhelp with?',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      key: const Key('first_aid_call_911_button'),
                      onPressed: () => EmergencyCallHelper.confirmAndOpen911(
                        context,
                        openDialer: widget.openDialer,
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: _brandRed,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(140, 48),
                      ),
                      icon: const Icon(Icons.phone_outlined, size: 19),
                      label: const Text('Call 911'),
                    ),
                    OutlinedButton.icon(
                      key: const Key('first_aid_hotlines_button'),
                      onPressed: () =>
                          EmergencyCallHelper.openHotlinesDirectory(
                            context,
                            openDialer: widget.openDialer,
                          ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _ink,
                        side: const BorderSide(color: _borderSubtle),
                        backgroundColor: Colors.white,
                        minimumSize: const Size(150, 48),
                      ),
                      icon: const Icon(
                        Icons.contact_phone_outlined,
                        size: 19,
                        color: _brandRed,
                      ),
                      label: const Text('Emergency hotlines'),
                    ),
                  ],
                ),
                if (widget.fallbackBannerMessage != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    key: widget.fallbackBannerKey,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _amberBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _amberBorder),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: _amberBorder,
                          size: 19,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.fallbackBannerMessage!,
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('original_first_aid_search_field'),
                        controller: _search,
                        textInputAction: TextInputAction.search,
                        onChanged: (value) => setState(() => _query = value),
                        onSubmitted: (_) => _submitSearch(),
                        style: const TextStyle(fontSize: 14, color: _ink),
                        decoration: InputDecoration(
                          hintText: 'Search injury or symptom',
                          hintStyle: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF7B889A),
                          ),
                          prefixIcon: const Icon(
                            Icons.search,
                            size: 21,
                            color: Color(0xFF8B98AA),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFFE1E5EB),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFFE1E5EB),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: _brandRed,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      tooltip: 'Search guides',
                      onPressed: _submitSearch,
                      style: IconButton.styleFrom(
                        backgroundColor: _brandRed,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(52, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.search, size: 25),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${guides.length} ${guides.length == 1 ? 'GUIDE' : 'GUIDES'}',
                        style: const TextStyle(
                          color: Color(0xFF7B889A),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .6,
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Filter guides',
                      initialValue: _category,
                      onSelected: (value) => setState(() => _category = value),
                      itemBuilder: (_) => [
                        for (final category in categories)
                          CheckedPopupMenuItem(
                            value: category,
                            checked: category == _category,
                            child: Text(category),
                          ),
                      ],
                      icon: Icon(
                        Icons.filter_list,
                        color: _category == 'All' ? _muted : _brandRed,
                        size: 21,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (guides.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'No guides found',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Try another search or clear the selected filters.',
                          textAlign: TextAlign.center,
                        ),
                        TextButton(
                          onPressed: _clearFilters,
                          child: const Text('Clear search & filters'),
                        ),
                      ],
                    ),
                  ),
                for (var i = 0; i < guides.length; i++)
                  _guideCard(
                    guides[i],
                    initiallyExpanded:
                        i == 0 && _query.isEmpty && _category == 'All',
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FirstAidDetailScreen extends StatelessWidget {
  const FirstAidDetailScreen({
    super.key,
    required this.guide,
    this.openDialer,
  });

  final FirstAidGuide guide;
  final EmergencyDialerOpener? openDialer;

  @override
  Widget build(BuildContext context) {
    if (!guide.isEligible) {
      return _RestrictedFirstAidGuardScreen(
        message:
            guide.withheldReason ??
            'This instruction is currently withheld pending clinical safety review.',
        openDialer: openDialer,
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(guide.title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.image_outlined,
                    size: 48,
                    color: Color(0xFFE92B32),
                  ),
                  SizedBox(height: 8),
                  Text('Instruction image'),
                  Text('Reserved for a reviewed visual guide'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              guide.category.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFFE92B32),
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Follow emergency professionals whenever available.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            for (final section in guide.details.split('\n\n'))
              _OriginalInstructionSection(section: section),
          ],
        ),
      ),
    );
  }
}

class _OriginalInstructionSection extends StatelessWidget {
  const _OriginalInstructionSection({required this.section});
  final String section;

  @override
  Widget build(BuildContext context) {
    final lines = section.split('\n');
    final expandable = lines.first == 'What if only 1 puff is available?';
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(lines.first, style: Theme.of(context).textTheme.titleMedium),
        for (final line in lines.skip(1))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(line, style: const TextStyle(height: 1.45)),
          ),
      ],
    );
    return Card(
      child: expandable
          ? ExpansionTile(
              title: Text(lines.first),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [body],
            )
          : Padding(padding: const EdgeInsets.all(16), child: body),
    );
  }
}

class FirstAidQuickInstructionScreen extends StatelessWidget {
  const FirstAidQuickInstructionScreen({
    super.key,
    required this.topic,
    required this.bundle,
    this.openedFromArticle = false,
    this.openDialer,
    this.releasePolicy,
    @visibleForTesting this.debugEnableExpandedFirstAidOverride,
  });

  final FirstAidTopic topic;
  final FirstAidLibraryBundle bundle;
  final bool openedFromArticle;
  final EmergencyDialerOpener? openDialer;
  final FirstAidReleasePolicy? releasePolicy;
  final bool? debugEnableExpandedFirstAidOverride;

  bool get _isExpandedEnabled =>
      debugEnableExpandedFirstAidOverride ??
      FirstAidFeatureFlags.enableExpandedFirstAid;

  FirstAidReleasePolicy get _effectivePolicy =>
      releasePolicy ?? FirstAidReleasePolicy.fromEnvironment();

  void _openLearnMore(BuildContext context) {
    if (openedFromArticle) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FirstAidArticleScreen(
          topic: topic,
          bundle: bundle,
          openedFromQuickInstruction: true,
          openDialer: openDialer,
          releasePolicy: _effectivePolicy,
          debugEnableExpandedFirstAidOverride:
              debugEnableExpandedFirstAidOverride,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isExpandedEnabled || !_effectivePolicy.allowsTopic(topic)) {
      return _RestrictedFirstAidGuardScreen(
        message: !_isExpandedEnabled
            ? 'Expanded First Aid procedures are currently disabled while awaiting clinical and publication review.'
            : 'This first-aid procedure is withheld pending qualified human clinical approval.',
        openDialer: openDialer,
      );
    }

    final qi = topic.quickInstructions;
    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: _ink,
        toolbarHeight: 68,
        leadingWidth: 68,
        leading: Center(
          child: IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).maybePop(),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFF3F5F8),
              minimumSize: const Size(48, 48),
            ),
            icon: const Icon(Icons.chevron_left, size: 28),
          ),
        ),
        title: const Text(
          'Quick First Aid',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                // 1. Topic Title & Qualification Metadata
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        topic.category.toUpperCase(),
                        style: const TextStyle(
                          color: _brandRed,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        topic.title,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _StatusBadge(
                            icon: Icons.person_outline,
                            label: topic.ageGroupLabel,
                            foreground: const Color(0xFF175CD3),
                            background: const Color(0xFFEFF8FF),
                            border: const Color(0xFFB2DDFF),
                          ),
                          _StatusBadge(
                            icon: topic.isTrainedResponderOnly
                                ? Icons.health_and_safety_outlined
                                : Icons.volunteer_activism_outlined,
                            label: topic.audienceLabel,
                            foreground: topic.isTrainedResponderOnly
                                ? _amberBorder
                                : const Color(0xFF067647),
                            background: topic.isTrainedResponderOnly
                                ? _amberBg
                                : const Color(0xFFECFDF3),
                            border: topic.isTrainedResponderOnly
                                ? _amberBorder
                                : const Color(0xFFABEFC6),
                          ),
                          if (!topic.review.isClinicallyApproved)
                            const _StatusBadge(
                              icon: Icons.fact_check_outlined,
                              label: 'Pending clinical review',
                              foreground: _amberBorder,
                              background: _amberBg,
                              border: _amberBorder,
                            ),
                        ],
                      ),
                      if (topic.isTrainedResponderOnly) ...[
                        const SizedBox(height: 14),
                        Container(
                          key: const Key('trained_responder_warning_banner'),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _amberBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _amberBorder, width: 1.5),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.health_and_safety,
                                color: _amberBorder,
                                size: 22,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'TRAINED RESPONDERS ONLY: Specialized equipment steps in this guide require formal training and authorization. Untrained bystanders should call 911 immediately and follow only standard bystander-safe steps.',
                                  style: TextStyle(
                                    color: _ink,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    height: 1.45,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // 2. Emergency Assistance Action
                if (topic.requiresEmergencyCall) ...[
                  const SizedBox(height: 14),
                  Container(
                    key: const Key('quick_instruction_emergency_banner'),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _darkSurface,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.phone_in_talk_outlined,
                              color: Color(0xFFFF6974),
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'EMERGENCY ASSISTANCE REQUIRED',
                                style: TextStyle(
                                  color: Color(0xFFFF8A93),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            ConstrainedBox(
                              constraints: const BoxConstraints(
                                minWidth: 150,
                                minHeight: 48,
                              ),
                              child: FilledButton.icon(
                                key: const Key('quick_call_911_button'),
                                onPressed: () =>
                                    EmergencyCallHelper.confirmAndOpen911(
                                      context,
                                      openDialer: openDialer,
                                    ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: _brandRed,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(150, 48),
                                  textStyle: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                icon: const Icon(Icons.phone_outlined),
                                label: const Text('Call 911'),
                              ),
                            ),
                            ConstrainedBox(
                              constraints: const BoxConstraints(
                                minWidth: 150,
                                minHeight: 48,
                              ),
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    EmergencyCallHelper.openHotlinesDirectory(
                                      context,
                                      openDialer: openDialer,
                                    ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(
                                    color: Color(0xFF475467),
                                  ),
                                  minimumSize: const Size(150, 48),
                                ),
                                icon: const Icon(Icons.contact_phone_outlined),
                                label: const Text('All Hotlines'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                // 3. Immediate Action Callout
                const SizedBox(height: 14),
                Container(
                  key: const Key('immediate_action_callout'),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _brandRed, width: 1.6),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.bolt, color: _brandRed, size: 22),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'IMMEDIATE ACTION — DO THIS FIRST',
                              style: TextStyle(
                                color: _brandRed,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        qi.immediateAction,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),

                // 4. Essential Recognition Criteria
                const SizedBox(height: 16),
                _SectionCard(
                  icon: Icons.visibility_outlined,
                  iconColor: _ink,
                  title: 'SIGNS TO RECOGNIZE',
                  child: _BulletItemList(items: qi.recognitionSigns),
                ),

                // 5. Numbered First-Aid Instructions & Conditional Actions
                const SizedBox(height: 16),
                _SectionCard(
                  icon: Icons.format_list_numbered,
                  iconColor: _brandRed,
                  title: 'FIRST-AID STEPS',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < qi.steps.length; i++)
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: i == qi.steps.length - 1 ? 0 : 16,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                alignment: Alignment.center,
                                decoration: const BoxDecoration(
                                  color: _brandRed,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '${i + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  qi.steps[i],
                                  key: Key('instruction_step_${i + 1}'),
                                  style: const TextStyle(
                                    color: _ink,
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w600,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (qi.conditionalActions.isNotEmpty) ...[
                        const Divider(height: 28, color: _borderSubtle),
                        const Row(
                          children: [
                            Icon(Icons.alt_route, size: 20, color: _ink),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'IF CONDITIONS CHANGE',
                                style: TextStyle(
                                  color: _ink,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        for (final ca in qi.conditionalActions)
                          Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: _borderSubtle),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ca.condition,
                                  style: const TextStyle(
                                    color: _ink,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  ca.action,
                                  style: const TextStyle(
                                    color: _bodyInk,
                                    fontSize: 16,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ],
                  ),
                ),

                // 6. Critical Warnings
                const SizedBox(height: 16),
                Container(
                  key: const Key('critical_warnings_section'),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: _warningBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _warningRed, width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: _warningRed,
                            size: 24,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'CRITICAL WARNINGS — DO NOT DO THIS',
                              style: TextStyle(
                                color: _warningRed,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.9,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _BulletItemList(
                        items: qi.warnings,
                        bulletColor: _warningRed,
                      ),
                    ],
                  ),
                ),

                // 7. Medical Escalation Guidance
                const SizedBox(height: 16),
                _SectionCard(
                  icon: Icons.local_hospital_outlined,
                  iconColor: _brandRed,
                  title: 'WHEN TO GET EMERGENCY MEDICAL HELP',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _BulletItemList(items: qi.emergencyEscalation),
                      if (!topic.requiresEmergencyCall) ...[
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          key: const Key('escalation_call_911_button'),
                          onPressed: () =>
                              EmergencyCallHelper.confirmAndOpen911(
                                context,
                                openDialer: openDialer,
                              ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _brandRed,
                            side: const BorderSide(color: _brandRed),
                            minimumSize: const Size.fromHeight(48),
                          ),
                          icon: const Icon(Icons.phone_outlined),
                          label: const Text('Call 911 if red flags appear'),
                        ),
                      ],
                    ],
                  ),
                ),

                // 8. Learn More Action
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  key: const Key('quick_instruction_learn_more_button'),
                  onPressed: () => _openLearnMore(context),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _ink,
                    side: const BorderSide(color: _ink, width: 1.4),
                    minimumSize: const Size.fromHeight(54),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.menu_book_outlined, color: _brandRed),
                  label: const Text(
                    'Learn More — Background, Prevention & IFRC Source',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FirstAidLearningLibraryScreen extends StatefulWidget {
  const FirstAidLearningLibraryScreen({
    super.key,
    required this.bundle,
    this.openDialer,
    this.releasePolicy,
    @visibleForTesting this.debugEnableExpandedFirstAidOverride,
  });

  final FirstAidLibraryBundle bundle;
  final EmergencyDialerOpener? openDialer;
  final FirstAidReleasePolicy? releasePolicy;
  final bool? debugEnableExpandedFirstAidOverride;

  @override
  State<FirstAidLearningLibraryScreen> createState() =>
      _FirstAidLearningLibraryScreenState();
}

class _FirstAidLearningLibraryScreenState
    extends State<FirstAidLearningLibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String _selectedCategory = 'All';
  FirstAidSortOrder _sortOrder = FirstAidSortOrder.logical;

  bool get _isExpandedEnabled =>
      widget.debugEnableExpandedFirstAidOverride ??
      FirstAidFeatureFlags.enableExpandedFirstAid;

  FirstAidReleasePolicy get _effectivePolicy =>
      widget.releasePolicy ?? FirstAidReleasePolicy.fromEnvironment();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openArticle(FirstAidTopic topic) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FirstAidArticleScreen(
          topic: topic,
          bundle: widget.bundle,
          openedFromQuickInstruction: false,
          openDialer: widget.openDialer,
          releasePolicy: _effectivePolicy,
          debugEnableExpandedFirstAidOverride:
              widget.debugEnableExpandedFirstAidOverride,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final eligibleTopics = widget.bundle.topics
        .where(_effectivePolicy.allowsTopic)
        .toList(growable: false);
    if (!_isExpandedEnabled || eligibleTopics.isEmpty) {
      return _RestrictedFirstAidGuardScreen(
        message: !_isExpandedEnabled
            ? 'The expanded Learning Library is currently disabled while awaiting clinical and publication review.'
            : 'No expanded Learning Library articles are currently approved for publication.',
        openDialer: widget.openDialer,
      );
    }

    final activeCategories = widget.bundle.categories
        .where((c) => eligibleTopics.any((t) => t.category == c))
        .toList(growable: false);

    final articles = FirstAidSearchEngine.search(
      eligibleTopics,
      query: _query,
      category: _selectedCategory,
      sortOrder: _sortOrder,
    );

    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: _ink,
        toolbarHeight: 68,
        leadingWidth: 68,
        leading: Center(
          child: IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).maybePop(),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFF3F5F8),
              minimumSize: const Size(48, 48),
            ),
            icon: const Icon(Icons.chevron_left, size: 28),
          ),
        ),
        title: const Text(
          'Learning Library',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              children: [
                const Text(
                  'EDUCATION & PREPAREDNESS',
                  style: TextStyle(
                    color: _brandRed,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Understand why first aid works and how to prevent emergencies.',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('learning_library_search_field'),
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v),
                  style: const TextStyle(fontSize: 16, color: _ink),
                  decoration: InputDecoration(
                    hintText: 'Search Learning Library topics',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            constraints: const BoxConstraints(
                              minWidth: 48,
                              minHeight: 48,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.close),
                          ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: _borderSubtle),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: _borderSubtle),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Sort:',
                      style: TextStyle(
                        color: _mutedInk,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    ChoiceChip(
                      label: const Text('Recommended Order'),
                      selected: _sortOrder == FirstAidSortOrder.logical,
                      materialTapTargetSize: MaterialTapTargetSize.padded,
                      onSelected: (_) => setState(
                        () => _sortOrder = FirstAidSortOrder.logical,
                      ),
                    ),
                    ChoiceChip(
                      key: const Key('sort_alphabetical_chip'),
                      label: const Text('A–Z'),
                      selected: _sortOrder == FirstAidSortOrder.alphabetical,
                      materialTapTargetSize: MaterialTapTargetSize.padded,
                      onSelected: (_) => setState(
                        () => _sortOrder = FirstAidSortOrder.alphabetical,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final cat in ['All', ...activeCategories])
                      ChoiceChip(
                        label: Text(cat),
                        selected: _selectedCategory == cat,
                        materialTapTargetSize: MaterialTapTargetSize.padded,
                        onSelected: (_) =>
                            setState(() => _selectedCategory = cat),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  '${articles.length} ${articles.length == 1 ? 'ARTICLE' : 'ARTICLES'}',
                  style: const TextStyle(
                    color: _mutedInk,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 10),
                for (final topic in articles)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      child: InkWell(
                        key: Key('learning_article_card_${topic.id}'),
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => _openArticle(topic),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: _borderSubtle),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    topic.iconData,
                                    color: _brandRed,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      topic.title,
                                      style: const TextStyle(
                                        color: _ink,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right,
                                    color: _mutedInk,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                topic.learnMore.overview,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _bodyInk,
                                  fontSize: 15.5,
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${topic.category} • IFRC 2025 (${topic.source.pageCitation})',
                                style: const TextStyle(
                                  color: _mutedInk,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FirstAidArticleScreen extends StatelessWidget {
  const FirstAidArticleScreen({
    super.key,
    required this.topic,
    required this.bundle,
    this.openedFromQuickInstruction = false,
    this.openDialer,
    this.releasePolicy,
    @visibleForTesting this.debugEnableExpandedFirstAidOverride,
  });

  final FirstAidTopic topic;
  final FirstAidLibraryBundle bundle;
  final bool openedFromQuickInstruction;
  final EmergencyDialerOpener? openDialer;
  final FirstAidReleasePolicy? releasePolicy;
  final bool? debugEnableExpandedFirstAidOverride;

  bool get _isExpandedEnabled =>
      debugEnableExpandedFirstAidOverride ??
      FirstAidFeatureFlags.enableExpandedFirstAid;

  FirstAidReleasePolicy get _effectivePolicy =>
      releasePolicy ?? FirstAidReleasePolicy.fromEnvironment();

  void _viewFirstAidInstructions(BuildContext context) {
    if (openedFromQuickInstruction) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FirstAidQuickInstructionScreen(
          topic: topic,
          bundle: bundle,
          openedFromArticle: true,
          openDialer: openDialer,
          releasePolicy: _effectivePolicy,
          debugEnableExpandedFirstAidOverride:
              debugEnableExpandedFirstAidOverride,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isExpandedEnabled || !_effectivePolicy.allowsTopic(topic)) {
      return _RestrictedFirstAidGuardScreen(
        message: !_isExpandedEnabled
            ? 'Expanded Learning Library articles are currently disabled while awaiting clinical and publication review.'
            : 'This article is withheld pending qualified human clinical approval.',
        openDialer: openDialer,
      );
    }

    final lm = topic.learnMore;
    final related = <FirstAidTopic>[
      for (final id in topic.relatedTopics)
        if (bundle.topicById(id) case final FirstAidTopic t
            when _effectivePolicy.allowsTopic(t))
          t,
    ];

    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: _ink,
        toolbarHeight: 68,
        leadingWidth: 68,
        leading: Center(
          child: IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).maybePop(),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFF3F5F8),
              minimumSize: const Size(48, 48),
            ),
            icon: const Icon(Icons.chevron_left, size: 28),
          ),
        ),
        title: const Text(
          'Learn More',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                FilledButton.icon(
                  key: const Key('article_view_quick_instructions_button'),
                  onPressed: () => _viewFirstAidInstructions(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: _brandRed,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  icon: const Icon(Icons.bolt),
                  label: const Text('View First Aid Instructions'),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        topic.category.toUpperCase(),
                        style: const TextStyle(
                          color: _brandRed,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        topic.title,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        lm.overview,
                        style: const TextStyle(
                          color: _bodyInk,
                          fontSize: 16,
                          height: 1.55,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  icon: Icons.help_outline,
                  iconColor: _ink,
                  title: 'CAUSES & RISK FACTORS',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Common Causes',
                        style: TextStyle(
                          color: _ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _BulletItemList(items: lm.causes),
                      const SizedBox(height: 12),
                      const Text(
                        'Risk Factors',
                        style: TextStyle(
                          color: _ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _BulletItemList(items: lm.riskFactors),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  icon: Icons.search,
                  iconColor: _ink,
                  title: 'DETAILED RECOGNITION',
                  child: _BulletItemList(items: lm.detailedRecognition),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  icon: Icons.science_outlined,
                  iconColor: _brandRed,
                  title: 'MEDICAL RATIONALE — WHY IT WORKS',
                  child: _BulletItemList(items: lm.explanations),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  icon: Icons.shield_outlined,
                  iconColor: const Color(0xFF067647),
                  title: 'PREVENTION & PREPARATION',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Prevention',
                        style: TextStyle(
                          color: _ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _BulletItemList(items: lm.prevention),
                      const SizedBox(height: 12),
                      const Text(
                        'Preparation',
                        style: TextStyle(
                          color: _ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _BulletItemList(items: lm.preparation),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  icon: Icons.healing_outlined,
                  iconColor: _ink,
                  title: 'PRECAUTIONS & FOLLOW-UP CARE',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _BulletItemList(items: lm.additionalPrecautions),
                      const SizedBox(height: 10),
                      _BulletItemList(items: lm.followUpCare),
                    ],
                  ),
                ),
                if (related.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _SectionCard(
                    icon: Icons.hub_outlined,
                    iconColor: _brandRed,
                    title: 'RELATED TOPICS',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final rel in related)
                          ActionChip(
                            key: Key('related_topic_chip_${rel.id}'),
                            materialTapTargetSize: MaterialTapTargetSize.padded,
                            avatar: Icon(
                              rel.iconData,
                              size: 18,
                              color: _brandRed,
                            ),
                            label: Text(rel.shortTitle),
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => FirstAidQuickInstructionScreen(
                                  topic: rel,
                                  bundle: bundle,
                                  openDialer: openDialer,
                                  releasePolicy: _effectivePolicy,
                                  debugEnableExpandedFirstAidOverride:
                                      debugEnableExpandedFirstAidOverride,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                _SectionCard(
                  icon: Icons.menu_book_outlined,
                  iconColor: _mutedInk,
                  title: 'SOURCE REFERENCE & ATTRIBUTION',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${topic.source.organization} International First Aid, Resuscitation and Education Guidelines (${topic.source.edition})',
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Section: ${topic.source.chapter} — "${topic.source.topicTitle}" (${topic.source.pageCitation}; PDF ${topic.source.pageCitation})',
                        style: const TextStyle(
                          color: _bodyInk,
                          fontSize: 15,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        bundle.nonEndorsementNotice,
                        style: const TextStyle(
                          color: _mutedInk,
                          fontSize: 14,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        bundle.medicalDisclaimer,
                        style: const TextStyle(
                          color: _mutedInk,
                          fontSize: 14,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RestrictedFirstAidGuardScreen extends StatelessWidget {
  const _RestrictedFirstAidGuardScreen({
    required this.message,
    this.openDialer,
  });

  final String message;
  final EmergencyDialerOpener? openDialer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      appBar: _buildStandardFirstAidAppBar(context),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  key: const Key('restricted_first_aid_guard_banner'),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _amberBorder, width: 1.4),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.lock_outline,
                            color: _amberBorder,
                            size: 24,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Instruction Unavailable',
                              style: TextStyle(
                                color: _ink,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        message,
                        style: const TextStyle(
                          color: _bodyInk,
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        key: const Key('guard_call_911_button'),
                        onPressed: () => EmergencyCallHelper.confirmAndOpen911(
                          context,
                          openDialer: openDialer,
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: _brandRed,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                        ),
                        icon: const Icon(Icons.phone_outlined),
                        label: const Text('Call 911'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        key: const Key('guard_hotlines_button'),
                        onPressed: () =>
                            EmergencyCallHelper.openHotlinesDirectory(
                              context,
                              openDialer: openDialer,
                            ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _ink,
                          minimumSize: const Size.fromHeight(48),
                        ),
                        icon: const Icon(
                          Icons.contact_phone_outlined,
                          color: _brandRed,
                        ),
                        label: const Text('Emergency Hotlines'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 21),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _BulletItemList extends StatelessWidget {
  const _BulletItemList({required this.items, this.bulletColor = _brandRed});

  final List<String> items;
  final Color bulletColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: bulletColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    items[i],
                    style: const TextStyle(
                      color: _bodyInk,
                      fontSize: 16,
                      height: 1.5,
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.icon,
    required this.label,
    required this.foreground,
    required this.background,
    required this.border,
  });

  final IconData icon;
  final String label;
  final Color foreground;
  final Color background;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: foreground,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClinicalReviewDraftBanner extends StatelessWidget {
  const _ClinicalReviewDraftBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('clinical_review_draft_banner'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _amberBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _amberBorder),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.fact_check_outlined, color: _amberBorder, size: 19),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Clinical review pending: Instructions are verified against IFRC 2025 Guidelines and awaiting qualified human clinical sign-off before public release.',
              style: TextStyle(
                color: _ink,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadErrorCard extends StatelessWidget {
  const _LoadErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('first_aid_load_error_card'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _warningBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _warningRed, width: 1.4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: _warningRed, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: _ink,
                fontSize: 16,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
