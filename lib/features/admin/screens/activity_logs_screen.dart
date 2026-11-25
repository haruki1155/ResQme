import 'dart:async';
import 'package:flutter/material.dart';
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
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _category = 'all';
  String _outcome = 'all';
  DateTimeRange? _dateRange;
  List<ActivityLogEntry> _entries = const [];
  String? _nextCursor;
  int _totalMatched = 0;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInitial();
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

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.repository.listActivityLogs(
        category: _category,
        outcome: _outcome,
        search: _searchController.text,
        startDate: _fmtDate(_dateRange?.start),
        endDate: _fmtDate(_dateRange?.end),
        limit: 25,
      );
      if (!mounted) return;
      setState(() {
        _entries = page.entries;
        _nextCursor = page.nextCursor;
        _totalMatched = page.totalMatched;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is PortalStudentException
            ? error.message
            : 'Unable to load school activity logs.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    final cursor = _nextCursor;
    if (cursor == null || _loadingMore || _loading) return;
    setState(() => _loadingMore = true);
    try {
      final page = await widget.repository.listActivityLogs(
        category: _category,
        outcome: _outcome,
        search: _searchController.text,
        startDate: _fmtDate(_dateRange?.start),
        endDate: _fmtDate(_dateRange?.end),
        limit: 25,
        cursor: cursor,
      );
      if (!mounted) return;
      setState(() {
        _entries = [..._entries, ...page.entries];
        _nextCursor = page.nextCursor;
        _totalMatched = page.totalMatched;
      });
    } catch (error) {
      if (!mounted) return;
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
      if (mounted) setState(() => _loadingMore = false);
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
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(entry.actionLabel),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailLine('Outcome', entry.outcome == 'denied' ? 'Denied' : 'Allowed'),
            _detailLine('Category', entry.category.toUpperCase()),
            _detailLine('Timestamp', entry.timestamp),
            _detailLine('Actor UID', entry.actorUid),
            _detailLine('Actor Role', entry.actorRole),
            if (entry.targetUid != null) _detailLine('Target ID', entry.targetUid!),
            if (entry.method != null) _detailLine('Method', entry.method!),
            if (entry.reasonCode != null) _detailLine('Reason', entry.reasonCode!),
            _detailLine('Source', entry.sourceCollection),
          ],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Logs'),
        actions: [
          IconButton(
            tooltip: 'Filter by date range',
            onPressed: _loading ? null : _pickDateRange,
            icon: const Icon(Icons.date_range_outlined),
          ),
          IconButton(
            tooltip: 'Refresh activity logs',
            onPressed: _loading ? null : _loadInitial,
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
                  subtitle: _loading
                      ? 'Loading chronological audit trail...'
                      : '$_totalMatched recorded event${_totalMatched == 1 ? '' : 's'} (newest first, redacted)',
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
                    hintText: 'Search action, actor UID, or target ID',
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
                          '${_fmtDate(_dateRange!.start)} – ${_fmtDate(_dateRange!.end)}',
                        ),
                        onPressed: () {
                          setState(() => _dateRange = null);
                          _loadInitial();
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 36),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null)
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
                  for (final entry in _entries)
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
                                      label: entry.outcome == 'denied'
                                          ? 'Denied'
                                          : 'Allowed',
                                      tone: entry.outcome == 'denied'
                                          ? PortalBadgeTone.alert
                                          : PortalBadgeTone.verified,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  entry.summary,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: PortalColors.inkSecondary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${entry.category.toUpperCase()} • ${entry.timestamp}',
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
