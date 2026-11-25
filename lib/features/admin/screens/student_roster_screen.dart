import 'package:flutter/material.dart';
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
  bool _rosterAvailable = false;
  List<String> _availableGrades = const [];
  List<SchoolRosterEntry> _entries = const [];
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
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.portalStudentRepository.listRoster(
        search: _searchController.text,
        gradeFilter: _gradeFilter == 'all' ? null : _gradeFilter,
        limit: 20,
      );
      if (!mounted) return;
      setState(() {
        _rosterAvailable = page.rosterAvailable;
        _entries = page.entries;
        _nextCursor = page.nextCursor;
        _totalMatched = page.totalMatched;
        _availableGrades = page.availableGrades;
        if (_gradeFilter != 'all' && !_availableGrades.contains(_gradeFilter)) {
          _gradeFilter = 'all';
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is PortalStudentException
            ? error.message
            : 'Unable to load official school roster.';
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
      final page = await widget.portalStudentRepository.listRoster(
        search: _searchController.text,
        gradeFilter: _gradeFilter == 'all' ? null : _gradeFilter,
        limit: 20,
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
                : 'Unable to load more roster records.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _loadingMore = false);
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

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: PortalSectionHeader(
                title: 'Student Roster',
                subtitle:
                    'Official school enrollment baseline including unregistered and registered students.',
                trailing: IconButton(
                  tooltip: 'Refresh roster',
                  onPressed: _loading ? null : _loadInitial,
                  icon: const Icon(Icons.refresh),
                ),
              ),
            ),
            if (_loading)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Expanded(
                child: PortalStateView(
                  icon: Icons.error_outline,
                  title: 'Unable to Load Roster',
                  message: _error!,
                  onRetry: _loadInitial,
                ),
              )
            else if (!_rosterAvailable)
              const Expanded(
                child: PortalStateView(
                  icon: Icons.fact_check_outlined,
                  title: 'No Official Roster Records Yet',
                  message:
                      'No official school roster records are on file for this school yet. '
                      'Registered student accounts can be reviewed and verified manually under Active Students.',
                ),
              )
            else ...[
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
              const SizedBox(height: 10),
              Expanded(
                child: _entries.isEmpty
                    ? const PortalStateView(
                        icon: Icons.search_off_outlined,
                        title: 'No Matching Roster Entries',
                        message:
                            'No official roster entries match the current search or grade filter.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount:
                            _entries.length + (_nextCursor != null ? 1 : 0),
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (ctx, index) {
                          if (index == _entries.length) {
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
                          final entry = _entries[index];
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
