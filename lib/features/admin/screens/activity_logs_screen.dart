import 'dart:async';
import 'package:flutter/material.dart';
import '../services/portal_read_coordinator.dart';
import '../services/portal_student_repository.dart';
import '../widgets/portal_widgets.dart';

class ActivityLogsScreen extends StatefulWidget {
  const ActivityLogsScreen({
    super.key,
    required this.repository,
  });

  final PortalStudentRepository repository;

  @override
  State<ActivityLogsScreen> createState() => _ActivityLogsScreenState();
}

class _ActivityLogsScreenState extends State<ActivityLogsScreen> {
  static const _monthNames = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  final _searchController = TextEditingController();
  Timer? _debounce;
  String _category = 'all';
  String _outcome = 'all';
  DateTimeRange? _dateRange;
  String _appliedCategory = 'all';
  String _appliedOutcome = 'all';
  String _appliedSearch = '';
  String? _appliedStartDate;
  String? _appliedEndDate;
  List<ActivityLogEntry> _entries = const [];
  String? _nextCursor;
  int _totalMatched = 0;
  PortalLoadStatus _status = PortalLoadStatus.initialLoading;
  bool _hasLoadedOnce = false;
  bool _loadingMore = false;
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
        final cached = coordinator.peekCached<ActivityLogPage>(
          'listSchoolActivityLogs:cat=$_category|out=$_outcome|act=|s=${_searchController.text.trim()}|sd=${_fmtDate(_dateRange?.start) ?? ''}|ed=${_fmtDate(_dateRange?.end) ?? ''}|l=25|c=',
        );
        if (cached != null) {
          _hasLoadedOnce = true;
          _entries = cached.entries;
          _nextCursor = cached.nextCursor;
          _totalMatched = cached.totalMatched;
          _status = cached.entries.isEmpty
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
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  String? _fmtDate(DateTime? d) => d == null
      ? null
      : '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Converts an entry timestamp into `Asia/Manila` (`UTC+08:00`) date and time.
  (String dateKey, String dateHeader, String timeLabel) _formatManila(
    ActivityLogEntry entry,
  ) {
    final parsed = DateTime.tryParse(entry.timestamp);
    if (parsed == null) {
      final fallbackDate = entry.manilaDate ?? 'Unknown Date';
      return (
        fallbackDate,
        fallbackDate,
        entry.manilaTimeLabel ?? entry.timestamp,
      );
    }
    final pht = parsed.toUtc().add(const Duration(hours: 8));
    final y = pht.year;
    final m = pht.month;
    final d = pht.day;
    final dateKey = entry.manilaDate ??
        '${y.toString().padLeft(4, '0')}-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
    final monthName = _monthNames[m - 1];
    final dateHeader = '$monthName $d, $y (Asia/Manila)';
    final rawHour = pht.hour;
    final min = pht.minute.toString().padLeft(2, '0');
    final ampm = rawHour >= 12 ? 'PM' : 'AM';
    final hour12 = rawHour % 12 == 0 ? 12 : rawHour % 12;
    return (dateKey, dateHeader, '$hour12:$min $ampm PHT');
  }

  String _actorLabel(ActivityLogEntry entry) {
    final name = entry.actorDisplayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return switch (entry.actorRole) {
      'admin' => 'Master Admin (${entry.actorUid})',
      'authorized' => 'Authorized Staff (${entry.actorUid})',
      'student' => 'Student Account',
      _ => entry.actorUid,
    };
  }

  String _roleBadgeLabel(String rawRole) => switch (rawRole) {
        'admin' => 'MASTER ADMIN',
        'authorized' => 'AUTHORIZED STAFF',
        'student' => 'STUDENT',
        _ => rawRole.toUpperCase(),
      };

  (String, PortalBadgeTone) _outcomePresentation(String rawOutcome) =>
      switch (rawOutcome) {
        'denied' => ('Denied', PortalBadgeTone.alert),
        'failed' => ('Failed', PortalBadgeTone.registered),
        _ => ('Allowed', PortalBadgeTone.verified),
      };

  Future<void> _loadInitial() async {
    final seq = ++_requestSeq;
    final categorySnapshot = _category;
    final outcomeSnapshot = _outcome;
    final searchSnapshot = _searchController.text;
    final startSnapshot = _fmtDate(_dateRange?.start);
    final endSnapshot = _fmtDate(_dateRange?.end);
    _appliedCategory = categorySnapshot;
    _appliedOutcome = outcomeSnapshot;
    _appliedSearch = searchSnapshot;
    _appliedStartDate = startSnapshot;
    _appliedEndDate = endSnapshot;
    setState(() {
      _loadingMore = false;
      _status = _hasLoadedOnce
          ? PortalLoadStatus.refreshing
          : PortalLoadStatus.initialLoading;
      _error = null;
    });
    try {
      final page = await widget.repository.listActivityLogs(
        category: categorySnapshot,
        outcome: outcomeSnapshot,
        search: searchSnapshot,
        startDate: startSnapshot,
        endDate: endSnapshot,
        limit: 25,
      );
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _hasLoadedOnce = true;
        _entries = page.entries;
        _nextCursor = page.nextCursor;
        _totalMatched = page.totalMatched;
        _error = null;
        _status = page.entries.isEmpty
            ? PortalLoadStatus.empty
            : PortalLoadStatus.loaded;
      });
    } catch (error) {
      if (!mounted || seq != _requestSeq) return;
      if (PortalErrorClassifier.isSessionAuthorizationError(error) ||
          (error is PortalStudentException && error.isSessionAuthLoss)) {
        setState(() {
          _hasLoadedOnce = false;
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
            : 'Unable to load school activity logs.';
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
      final page = await widget.repository.listActivityLogs(
        category: _appliedCategory,
        outcome: _appliedOutcome,
        search: _appliedSearch,
        startDate: _appliedStartDate,
        endDate: _appliedEndDate,
        limit: 25,
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
                : 'Unable to load more activity logs.',
          ),
        ),
      );
    } finally {
      if (mounted && seq == _requestSeq) {
        setState(() => _loadingMore = false);
      }
    }
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025, 1, 1),
      lastDate: now.add(const Duration(days: 1)),
      initialDateRange: _dateRange,
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
      await _loadInitial();
    }
  }

  void _showDetails(ActivityLogEntry entry) {
    final pht = _formatManila(entry);
    final outcomeInfo = _outcomePresentation(entry.outcome);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(entry.actionLabel),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailLine('Outcome', outcomeInfo.$1),
              _detailLine('Category', entry.category.toUpperCase()),
              _detailLine('Manila Time', '${pht.$2} • ${pht.$3}'),
              _detailLine('Actor', _actorLabel(entry)),
              _detailLine('Actor UID', entry.actorUid),
              _detailLine('Actor Role', _roleBadgeLabel(entry.actorRole)),
              if (entry.targetUid != null)
                _detailLine('Target ID', entry.targetUid!),
              if (entry.method != null) _detailLine('Method', entry.method!),
              if (entry.reasonCode != null)
                _detailLine('Reason', entry.reasonCode!),
              _detailLine('Source', entry.sourceCollection),
            ],
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
  }

  Widget _detailLine(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 96,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: PortalColors.inkSecondary,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: PortalColors.inkPrimary,
                ),
              ),
            ),
          ],
        ),
      );

  List<Widget> _buildGroupedEntries() {
    final widgets = <Widget>[];
    String? currentGroupKey;
    for (final entry in _entries) {
      final (dateKey, dateHeader, timeLabel) = _formatManila(entry);
      if (dateKey != currentGroupKey) {
        currentGroupKey = dateKey;
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Text(
              dateHeader,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: PortalColors.inkSecondary,
                letterSpacing: 0.3,
              ),
            ),
          ),
        );
      }
      final outcomeInfo = _outcomePresentation(entry.outcome);
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _showDetails(entry),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            entry.actionLabel,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: PortalColors.inkPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        PortalStatusBadge(
                          label: outcomeInfo.$1,
                          tone: outcomeInfo.$2,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          _actorLabel(entry),
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: PortalColors.inkPrimary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: PortalColors.background,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: PortalColors.border),
                          ),
                          child: Text(
                            _roleBadgeLabel(entry.actorRole),
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: PortalColors.inkSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      entry.summary,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: PortalColors.inkSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${entry.category.toUpperCase()} • $timeLabel',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: PortalColors.inkSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Logs'),
        actions: [
          IconButton(
            tooltip: 'Filter by date range (Asia/Manila)',
            onPressed: _isInitialLoading ? null : _pickDateRange,
            icon: const Icon(Icons.date_range_outlined),
          ),
          IconButton(
            tooltip: 'Refresh activity logs',
            onPressed:
                _isInitialLoading || _isRefreshing ? null : _loadInitial,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                PortalSectionHeader(
                  title: 'School Security & Supervision Logs',
                  subtitle: _isInitialLoading
                      ? 'Loading chronological audit trail...'
                      : '$_totalMatched recorded event${_totalMatched == 1 ? '' : 's'} (Asia/Manila PHT, redacted)',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  onChanged: (_) {
                    _debounce?.cancel();
                    _debounce = Timer(
                      const Duration(milliseconds: 300),
                      _loadInitial,
                    );
                  },
                  decoration: InputDecoration(
                    hintText: 'Search action, actor name/UID, or target ID',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              _searchController.clear();
                              _loadInitial();
                            },
                            icon: const Icon(Icons.clear),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final c in const [
                        (id: 'all', label: 'All Categories'),
                        (id: 'security', label: 'Security'),
                        (id: 'management', label: 'Management'),
                        (id: 'tier2', label: 'Tier 2 Access'),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(c.label),
                            selected: _category == c.id,
                            onSelected: (_) {
                              if (_category == c.id) return;
                              setState(() => _category = c.id);
                              _loadInitial();
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final o in const [
                      (id: 'all', label: 'All Outcomes'),
                      (id: 'allowed', label: 'Allowed'),
                      (id: 'denied', label: 'Denied'),
                      (id: 'failed', label: 'Failed'),
                    ])
                      FilterChip(
                        label: Text(o.label),
                        selected: _outcome == o.id,
                        onSelected: (_) {
                          if (_outcome == o.id) return;
                          setState(() => _outcome = o.id);
                          _loadInitial();
                        },
                      ),
                    if (_dateRange != null)
                      ActionChip(
                        avatar: const Icon(Icons.close, size: 16),
                        label: Text(
                          '${_fmtDate(_dateRange!.start)} – ${_fmtDate(_dateRange!.end)} (PHT)',
                        ),
                        onPressed: () {
                          setState(() => _dateRange = null);
                          _loadInitial();
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                PortalRefreshStrip(refreshing: _isRefreshing),
                if (_hasLoadedOnce && _error != null)
                  PortalInlineErrorBanner(
                    message: _error!,
                    onRetry: _loadInitial,
                  ),
                if (_isInitialLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 36),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (!_hasLoadedOnce && _error != null)
                  PortalStateView(
                    icon: Icons.error_outline,
                    title: 'Activity Logs Unavailable',
                    message: _error!,
                    onRetry: _loadInitial,
                  )
                else if (_entries.isEmpty)
                  const PortalStateView(
                    icon: Icons.history_toggle_off_outlined,
                    title: 'No Matching Activity Logs',
                    message:
                        'No security, management, or emergency Tier 2 events match the current filters.',
                  )
                else ...[
                  ..._buildGroupedEntries(),
                  if (_nextCursor != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: OutlinedButton(
                        onPressed: _loadingMore ? null : _loadMore,
                        child: _loadingMore
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Load More Logs'),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
