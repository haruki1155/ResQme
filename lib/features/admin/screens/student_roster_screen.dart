import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/widgets/feature_guide.dart';
import '../services/portal_read_coordinator.dart';
import '../services/portal_student_repository.dart';
import '../widgets/portal_widgets.dart';

class StudentRosterScreen extends StatefulWidget {
  const StudentRosterScreen({
    super.key,
    required this.portalStudentRepository,
  });

  final PortalStudentRepository portalStudentRepository;

  @override
  State<StudentRosterScreen> createState() => _StudentRosterScreenState();
}

class _StudentRosterScreenState extends State<StudentRosterScreen> {
  final _searchController = TextEditingController();
  String _gradeFilter = 'all';
  String _registrationFilter = 'all';
  String _appliedSearch = '';
  String? _appliedGradeFilter;
  String _appliedRegistrationFilter = 'all';
  bool _rosterAvailable = false;
  List<String> _availableGrades = const [];
  List<SchoolRosterEntry> _entries = const [];
  String? _nextCursor;
  int _totalMatched = 0;
  PortalLoadStatus _status = PortalLoadStatus.initialLoading;
  bool _hasLoadedOnce = false;
  bool _loadingMore = false;
  bool _importing = false;
  String? _importStageLabel;
  int _requestSeq = 0;
  int? _lastObservedMutationVersion;
  String? _error;

  bool get _isInitialLoading =>
      !_hasLoadedOnce && _status == PortalLoadStatus.initialLoading;
  bool get _isRefreshing => _status == PortalLoadStatus.refreshing;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final coordinator = PortalScope.maybeOf(context)?.notifier;
    if (coordinator != null) {
      if (!_hasLoadedOnce) {
        final cached = coordinator.peekCached<SchoolRosterPage>(
          'listSchoolRoster:s=${_searchController.text.trim()}|g=${_gradeFilter == 'all' ? '' : _gradeFilter}|rf=$_registrationFilter|l=20|c=',
        );
        if (cached != null) {
          _hasLoadedOnce = true;
          _rosterAvailable = cached.rosterAvailable;
          _entries = cached.entries;
          _nextCursor = cached.nextCursor;
          _totalMatched = cached.totalMatched;
          _availableGrades = cached.availableGrades;
          _status = (!cached.rosterAvailable || cached.entries.isEmpty)
              ? PortalLoadStatus.empty
              : PortalLoadStatus.loaded;
        }
      }
      final currentMutation = coordinator.mutationVersion;
      if (_lastObservedMutationVersion != null &&
          _lastObservedMutationVersion != currentMutation) {
        _lastObservedMutationVersion = currentMutation;
        _loadInitial();
      } else {
        _lastObservedMutationVersion = currentMutation;
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<SchoolRosterPage> _fetchRoster({
    required String search,
    required String? gradeFilter,
    required String registrationFilter,
    required int limit,
    String? cursor,
  }) async {
    final repo = widget.portalStudentRepository;
    if (repo is RegistrationFilterableRosterRepository) {
      return repo.listRosterFiltered(
        search: search,
        gradeFilter: gradeFilter,
        registrationFilter: registrationFilter,
        limit: limit,
        cursor: cursor,
      );
    }
    final raw = await repo.listRoster(
      search: search,
      gradeFilter: gradeFilter,
      limit: limit,
      cursor: cursor,
    );
    if (registrationFilter == 'all') return raw;
    final filtered = raw.entries
        .where((e) => e.registrationState == registrationFilter)
        .toList();
    return SchoolRosterPage(
      rosterAvailable: raw.rosterAvailable,
      entries: filtered,
      nextCursor: raw.nextCursor,
      totalMatched: filtered.length,
      availableGrades: raw.availableGrades,
    );
  }

  Future<void> _loadInitial() async {
    final seq = ++_requestSeq;
    final searchSnapshot = _searchController.text;
    final gradeSnapshot = _gradeFilter == 'all' ? null : _gradeFilter;
    final regSnapshot = _registrationFilter;
    _appliedSearch = searchSnapshot;
    _appliedGradeFilter = gradeSnapshot;
    _appliedRegistrationFilter = regSnapshot;
    setState(() {
      _loadingMore = false;
      _status = _hasLoadedOnce
          ? PortalLoadStatus.refreshing
          : PortalLoadStatus.initialLoading;
      _error = null;
    });
    try {
      final page = await _fetchRoster(
        search: searchSnapshot,
        gradeFilter: gradeSnapshot,
        registrationFilter: regSnapshot,
        limit: 20,
      );
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _hasLoadedOnce = true;
        _rosterAvailable = page.rosterAvailable;
        _entries = page.entries;
        _nextCursor = page.nextCursor;
        _totalMatched = page.totalMatched;
        _availableGrades = page.availableGrades;
        if (_gradeFilter != 'all' && !_availableGrades.contains(_gradeFilter)) {
          _gradeFilter = 'all';
        }
        _error = null;
        _status = (!page.rosterAvailable || page.entries.isEmpty)
            ? PortalLoadStatus.empty
            : PortalLoadStatus.loaded;
      });
    } catch (error) {
      if (!mounted || seq != _requestSeq) return;
      if (PortalErrorClassifier.isSessionAuthorizationError(error) ||
          (error is PortalStudentException && error.isSessionAuthLoss)) {
        setState(() {
          _hasLoadedOnce = false;
          _rosterAvailable = false;
          _entries = const [];
          _nextCursor = null;
          _totalMatched = 0;
          _status = PortalLoadStatus.authorizationError;
          _error = error is PortalStudentException
              ? error.message
              : 'Session authorization expired. Sign in again.';
        });
        PortalScope.reportIfSessionAuthorizationLost(context, error);
        return;
      }
      setState(() {
        _status = PortalLoadStatus.transientError;
        _error = error is PortalStudentException
            ? error.message
            : 'Unable to load official school roster.';
      });
    }
  }

  Future<void> _loadMore() async {
    final cursor = _nextCursor;
    if (cursor == null || _loadingMore || _isInitialLoading || _isRefreshing) {
      return;
    }
    final seq = _requestSeq;
    setState(() => _loadingMore = true);
    try {
      final page = await _fetchRoster(
        search: _appliedSearch,
        gradeFilter: _appliedGradeFilter,
        registrationFilter: _appliedRegistrationFilter,
        limit: 20,
        cursor: cursor,
      );
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _entries = [..._entries, ...page.entries];
        _nextCursor = page.nextCursor;
        _totalMatched = page.totalMatched;
        _status =
            _entries.isEmpty ? PortalLoadStatus.empty : PortalLoadStatus.loaded;
      });
    } catch (error) {
      if (!mounted || seq != _requestSeq) return;
      if (PortalErrorClassifier.isSessionAuthorizationError(error) ||
          (error is PortalStudentException && error.isSessionAuthLoss)) {
        PortalScope.reportIfSessionAuthorizationLost(context, error);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is PortalStudentException
                ? error.message
                : 'Unable to load more roster records.',
          ),
        ),
      );
    } finally {
      if (mounted && seq == _requestSeq) {
        setState(() => _loadingMore = false);
      }
    }
  }

  Future<void> _startSf1Import() async {
    if (_importing) return;
    setState(() {
      _importing = true;
      _importStageLabel = 'Selecting SF1 spreadsheet (.xls / .xlsx)…';
    });
    try {
      final picked = await widget.portalStudentRepository.pickSf1ExcelFile();
      if (picked == null || !mounted) return;

      final gradeController = TextEditingController();
      final confirmedGrade = await showDialog<String?>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirm SF1 Grade Level'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'File: ${picked.fileName}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: PortalColors.inkPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: PortalColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: PortalColors.border),
                  ),
                  child: const Text(
                    'SF1 Import Requirements:\n'
                    '• Supported formats: genuine .xls or .xlsx (max 2 MB, no macros)\n'
                    '• Required columns: LRN (12 digits), NAME, BIRTH DATE, Grade Level',
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.4,
                      color: PortalColors.inkSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Enter a Grade Level to override or confirm the SF1 worksheet header (leave blank to use the sheet metadata).',
                  style: TextStyle(fontSize: 12, color: PortalColors.inkSecondary),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: gradeController,
                  decoration: const InputDecoration(
                    labelText: 'Grade Level (optional if in sheet)',
                    hintText: 'e.g. Grade 10',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('__CANCEL__'),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(ctx).pop(gradeController.text.trim()),
              child: const Text('Preview Import'),
            ),
          ],
        ),
      );
      gradeController.dispose();
      if (confirmedGrade == '__CANCEL__' || !mounted) return;

      setState(() {
        _importStageLabel = 'Parsing and validating SF1 worksheet rows…';
      });
      final preview = await widget.portalStudentRepository.previewRosterImport(
        fileName: picked.fileName,
        fileBase64: picked.fileBase64,
        confirmedGradeLevel:
            (confirmedGrade == null || confirmedGrade.isEmpty)
                ? null
                : confirmedGrade,
      );
      if (!mounted) return;
      setState(() => _importStageLabel = null);

      final shouldCommit = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _RosterPreviewDialog(preview: preview),
      );
      if (shouldCommit != true || !mounted) return;

      setState(() {
        _importStageLabel =
            'Committing ${preview.newCount + preview.proposedUpdateCount} verified student roster records…';
      });
      final requestId =
          'sf1_imp_${DateTime.now().microsecondsSinceEpoch}';
      final repo = widget.portalStudentRepository;
      final commitResult = repo is IntegrityBoundRosterImportRepository
          ? await repo.commitBoundRosterImport(
              previewId: preview.previewId,
              requestId: requestId,
              expectedFileSha256: preview.fileSha256,
              privacyNoticeAcknowledged: true,
            )
          : await repo.commitRosterImport(
              previewId: preview.previewId,
              requestId: requestId,
            );
      if (!mounted) return;
      setState(() => _importStageLabel = null);
      PortalScope.notifyMutation(context);

      await showDialog<void>(
        context: context,
        builder: (ctx) => _RosterCommitResultDialog(result: commitResult),
      );
      if (mounted) {
        await _loadInitial();
      }
    } catch (error) {
      if (!mounted) return;
      if (PortalErrorClassifier.isSessionAuthorizationError(error)) {
        PortalScope.reportIfSessionAuthorizationLost(context, error);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is PortalStudentException
                ? error.message
                : 'Unable to import SF1 spreadsheet.',
          ),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: _startSf1Import,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _importing = false;
          _importStageLabel = null;
        });
      }
    }
  }

  Future<void> _showImportHistory() async {
    try {
      final items = await widget.portalStudentRepository.listRosterImports();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('SF1 Import History'),
          content: SizedBox(
            width: 440,
            child: items.isEmpty
                ? const Text('No SF1 roster imports recorded yet.')
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(height: 14),
                    itemBuilder: (_, i) {
                      final item = items[i];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.fileName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${item.confirmedGradeLevel} • ${item.committedCount} committed (${item.newCount} new, ${item.updatedCount} updated)',
                            style: const TextStyle(
                              fontSize: 12,
                              color: PortalColors.inkSecondary,
                            ),
                          ),
                          Text(
                            '${item.status.toUpperCase()} • ${item.timestamp}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: PortalColors.inkSecondary,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      if (PortalErrorClassifier.isSessionAuthorizationError(error)) {
        PortalScope.reportIfSessionAuthorizationLost(context, error);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is PortalStudentException
                ? error.message
                : 'Unable to load import history.',
          ),
        ),
      );
    }
  }

  void _showRosterDetails(SchoolRosterEntry entry) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: PortalColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.displayName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: PortalColors.inkPrimary,
                      ),
                    ),
                  ),
                  PortalStatusBadge.forRosterState(entry.registrationState),
                ],
              ),
              const Divider(height: 22),
              PortalProtectedLrnRow(
                maskedLrn: entry.maskedLrn ?? 'Protected HMAC Claim Record',
                hasLrn: entry.hasLrn,
                targetType: 'roster',
                targetId: entry.rosterId,
                studentLabel: entry.displayName,
                portalStudentRepository: widget.portalStudentRepository,
                labelWidth: 120,
              ),
              _rosterRow('Grade Level', entry.gradeLevel),
              if (entry.sex != null) _rosterRow('Sex', entry.sex!),
              if (entry.birthDate != null)
                _rosterRow('Birth Date', entry.birthDate!),
              _rosterRow(
                'Account Status',
                switch (entry.registrationState) {
                  'verified' => 'Registered & School Verified',
                  'registered' => 'Registered (Pending Verification)',
                  _ => 'Not Registered in Student App',
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rosterRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: PortalColors.inkSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: PortalColors.inkPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gradeItems = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: 'all', child: Text('All Grade Levels')),
      for (final grade in _availableGrades)
        DropdownMenuItem(value: grade, child: Text(grade)),
    ];

    final visibleEntries = _entries;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PortalSectionHeader(
                    title: 'Student Roster',
                    subtitle:
                        'Official school enrollment baseline including unregistered and registered students.',
                    guide: ResQMeFeatureGuides.portalStudentRoster,
                    trailing: IconButton(
                      tooltip: 'Refresh roster',
                      onPressed: _isInitialLoading || _isRefreshing
                          ? null
                          : _loadInitial,
                      icon: const Icon(Icons.refresh),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: _isInitialLoading || _importing
                            ? null
                            : _startSf1Import,
                        icon: _importing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.upload_file_outlined, size: 18),
                        label: const Text('Import Student Roster'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _isInitialLoading || _importing
                            ? null
                            : _showImportHistory,
                        icon: const Icon(Icons.history_outlined, size: 18),
                        label: const Text('Import History'),
                      ),
                    ],
                  ),
                  if (_importing && _importStageLabel != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: PortalColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: PortalColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _importStageLabel!,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: PortalColors.inkPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const LinearProgressIndicator(minHeight: 3),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (_isInitialLoading)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (!_hasLoadedOnce && _error != null)
              Expanded(
                child: PortalStateView(
                  icon: Icons.error_outline,
                  title: 'Unable to Load Roster',
                  message: _error!,
                  onRetry: _loadInitial,
                ),
              )
            else if (!_rosterAvailable)
              Expanded(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PortalRefreshStrip(refreshing: _isRefreshing),
                          if (_error != null)
                            PortalInlineErrorBanner(
                              message: _error!,
                              onRetry: _loadInitial,
                            ),
                        ],
                      ),
                    ),
                    const Expanded(
                      child: PortalStateView(
                        icon: Icons.fact_check_outlined,
                        title: 'No Official Roster Records Yet',
                        message:
                            'No official school roster records are on file for this school yet. '
                            'Use Import Student Roster to upload a DepEd SF1 (.xls or .xlsx) file.',
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PortalRefreshStrip(refreshing: _isRefreshing),
                    if (_error != null)
                      PortalInlineErrorBanner(
                        message: _error!,
                        onRetry: _loadInitial,
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  key: const Key('student-roster-search'),
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _loadInitial(),
                  decoration: InputDecoration(
                    hintText: 'Search roster by name or 12-digit LRN',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: IconButton(
                      tooltip: 'Search roster',
                      onPressed: _loadInitial,
                      icon: const Icon(Icons.arrow_forward, size: 18),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        key: ValueKey('roster-grade-dropdown-$_gradeFilter'),
                        initialValue: _gradeFilter,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Grade Level',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        items: gradeItems,
                        onChanged: (next) {
                          if (next == null || next == _gradeFilter) return;
                          setState(() => _gradeFilter = next);
                          _loadInitial();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '$_totalMatched ${_totalMatched == 1 ? 'student' : 'students'}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: PortalColors.inkSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    for (final f in const [
                      (id: 'all', label: 'All'),
                      (id: 'not_registered', label: 'Not Registered'),
                      (id: 'registered', label: 'Registered'),
                      (id: 'verified', label: 'Verified'),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(f.label),
                          selected: _registrationFilter == f.id,
                          onSelected: (_) {
                            if (_registrationFilter == f.id) return;
                            setState(() => _registrationFilter = f.id);
                            _loadInitial();
                          },
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: visibleEntries.isEmpty
                    ? const PortalStateView(
                        icon: Icons.search_off_outlined,
                        title: 'No Matching Roster Entries',
                        message:
                            'No official roster entries match the current search, grade, or registration filter.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount:
                            visibleEntries.length + (_nextCursor != null ? 1 : 0),
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (ctx, index) {
                          if (index == visibleEntries.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: OutlinedButton(
                                onPressed: _loadingMore ? null : _loadMore,
                                child: Text(
                                  _loadingMore
                                      ? 'Loading…'
                                      : 'Load More Roster Entries',
                                ),
                              ),
                            );
                          }
                          final entry = visibleEntries[index];
                          return Card(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => _showRosterDetails(entry),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            entry.displayName,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: PortalColors.inkPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${entry.maskedLrn != null ? 'LRN: ${entry.maskedLrn}' : 'Official Roster Claim'} • ${entry.gradeLevel}',
                                            style: const TextStyle(
                                              fontSize: 12.5,
                                              color: PortalColors.inkSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    PortalStatusBadge.forRosterState(
                                      entry.registrationState,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RosterPreviewDialog extends StatefulWidget {
  const _RosterPreviewDialog({required this.preview});
  final RosterImportPreview preview;

  @override
  State<_RosterPreviewDialog> createState() => _RosterPreviewDialogState();
}

class _RosterPreviewDialogState extends State<_RosterPreviewDialog> {
  bool _privacyAcknowledged = false;

  @override
  Widget build(BuildContext context) {
    final preview = widget.preview;
    final committableCount = preview.newCount + preview.proposedUpdateCount;
    final canCommit = committableCount > 0 && _privacyAcknowledged;
    return AlertDialog(
      title: const Text('SF1 Import Preview'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${preview.fileName} • ${preview.confirmedGradeLevel}',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (preview.detectedGradeLevel != null &&
                  preview.detectedGradeLevel!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'Sheet Grade: ${preview.detectedGradeLevel} • Applied Grade: ${preview.confirmedGradeLevel}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: PortalColors.inkSecondary,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _chip('New: ${preview.newCount}', PortalColors.verifiedBg, PortalColors.verifiedFg),
                  _chip('Updates: ${preview.proposedUpdateCount}', PortalColors.registeredBg, PortalColors.registeredFg),
                  _chip('Unchanged: ${preview.unchangedCount}', PortalColors.background, PortalColors.inkSecondary),
                  _chip('Duplicates: ${preview.duplicateCount}', PortalColors.alertBg, PortalColors.alertFg),
                  _chip('Conflicts: ${preview.conflictCount}', PortalColors.alertBg, PortalColors.alertFg),
                  _chip('Invalid: ${preview.invalidCount}', PortalColors.alertBg, PortalColors.alertFg),
                ],
              ),
              const SizedBox(height: 12),
              for (final row in preview.rows.take(15))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: PortalColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: PortalColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Row ${row.rowNumber}: ${row.fullName}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                            Text(
                              row.status.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: PortalColors.inkSecondary,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'LRN: ${row.maskedLrn ?? 'Invalid'} • ${row.gradeLevel}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: PortalColors.inkSecondary,
                          ),
                        ),
                        if (row.reason != null)
                          Text(
                            row.reason!,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: PortalColors.alertFg,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFCD34D)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Data Privacy Act Notice (RA 10173)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF92400E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Upload official DepEd SF1 records only with school authorization for student verification and emergency readiness. Raw Excel files are never retained after processing.',
                      style: TextStyle(fontSize: 11.5, height: 1.35),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: CheckboxListTile(
                        key: const Key('sf1-privacy-ack-checkbox'),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: _privacyAcknowledged,
                        onChanged: (next) =>
                            setState(() => _privacyAcknowledged = next == true),
                        title: const Text(
                          'I confirm authorization and Data Privacy compliance for this SF1 import.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: canCommit ? () => Navigator.of(context).pop(true) : null,
          child: Text(
            'Confirm & Import ($committableCount)',
          ),
        ),
      ],
    );
  }

  Widget _chip(String label, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: fg,
          ),
        ),
      );
}

class _RosterCommitResultDialog extends StatelessWidget {
  const _RosterCommitResultDialog({required this.result});
  final RosterImportCommitResult result;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('SF1 Import Complete'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${result.committedCount} student records processed (${result.newCount} new, ${result.updatedCount} updated).',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (result.generatedCredentials.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Text(
                  'One-Time Enrollment Credentials (share securely with students):',
                  style: TextStyle(
                    fontSize: 12,
                    color: PortalColors.inkSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                for (final c in result.generatedCredentials.take(15))
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text('${c.fullName} (${c.maskedLrn})'),
                    subtitle: Text('Code: ${c.enrollmentCode}'),
                    trailing: IconButton(
                      tooltip: 'Copy enrollment code',
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: () => Clipboard.setData(
                        ClipboardData(text: c.enrollmentCode),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
