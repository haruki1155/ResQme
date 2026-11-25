import 'package:flutter/material.dart';
import '../services/portal_read_coordinator.dart';
import '../services/portal_student_repository.dart';
import '../services/staff_access_repository.dart';
import '../widgets/portal_widgets.dart';
import 'student_details_screen.dart';

class ActiveStudentsScreen extends StatefulWidget {
  const ActiveStudentsScreen({
    super.key,
    required this.accessRepository,
    required this.portalStudentRepository,
  });

  final StaffAccessRepository accessRepository;
  final PortalStudentRepository portalStudentRepository;

  @override
  State<ActiveStudentsScreen> createState() => _ActiveStudentsScreenState();
}

class _ActiveStudentsScreenState extends State<ActiveStudentsScreen> {
  final _searchController = TextEditingController();
  String _statusFilter = 'all';
  String _gradeFilter = 'all';
  String _appliedSearch = '';
  String _appliedStatusFilter = 'all';
  String? _appliedGradeFilter;
  List<String> _availableGrades = const [];
  List<SchoolStudentSummary> _students = const [];
  String? _nextCursor;
  int _totalMatched = 0;
  PortalLoadStatus _status = PortalLoadStatus.initialLoading;
  bool _hasLoadedOnce = false;
  bool _loadingMore = false;
  int _requestSeq = 0;
  int? _lastObservedMutationVersion;
  String? _error;

  static const _statusFilters = <(String, String)>[
    ('all', 'All'),
    ('registered', 'Registered'),
    ('verified', 'Verified'),
    ('disabled', 'Disabled'),
  ];

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
        final cached = coordinator.peekCached<SchoolStudentPage>(
          'listSchoolStudents:s=${_searchController.text.trim()}|st=$_statusFilter|g=${_gradeFilter == 'all' ? '' : _gradeFilter}|l=20|c=',
        );
        if (cached != null) {
          _hasLoadedOnce = true;
          _students = cached.students;
          _nextCursor = cached.nextCursor;
          _totalMatched = cached.totalMatched;
          _availableGrades = cached.availableGrades;
          _status = cached.students.isEmpty
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

  Future<void> _loadInitial() async {
    final seq = ++_requestSeq;
    final searchSnapshot = _searchController.text;
    final statusSnapshot = _statusFilter;
    final gradeSnapshot = _gradeFilter == 'all' ? null : _gradeFilter;
    _appliedSearch = searchSnapshot;
    _appliedStatusFilter = statusSnapshot;
    _appliedGradeFilter = gradeSnapshot;
    setState(() {
      _loadingMore = false;
      _status = _hasLoadedOnce
          ? PortalLoadStatus.refreshing
          : PortalLoadStatus.initialLoading;
      _error = null;
    });
    try {
      final page = await widget.portalStudentRepository.listStudents(
        search: searchSnapshot,
        statusFilter: statusSnapshot,
        gradeFilter: gradeSnapshot,
        limit: 20,
      );
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _hasLoadedOnce = true;
        _students = page.students;
        _nextCursor = page.nextCursor;
        _totalMatched = page.totalMatched;
        _availableGrades = page.availableGrades;
        if (_gradeFilter != 'all' && !_availableGrades.contains(_gradeFilter)) {
          _gradeFilter = 'all';
        }
        _error = null;
        _status = page.students.isEmpty
            ? PortalLoadStatus.empty
            : PortalLoadStatus.loaded;
      });
    } catch (error) {
      if (!mounted || seq != _requestSeq) return;
      if (PortalErrorClassifier.isSessionAuthorizationError(error) ||
          (error is PortalStudentException && error.isSessionAuthLoss)) {
        setState(() {
          _hasLoadedOnce = false;
          _students = const [];
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
            : 'Unable to load school student accounts.';
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
      final page = await widget.portalStudentRepository.listStudents(
        search: _appliedSearch,
        statusFilter: _appliedStatusFilter,
        gradeFilter: _appliedGradeFilter,
        limit: 20,
        cursor: cursor,
      );
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _students = [..._students, ...page.students];
        _nextCursor = page.nextCursor;
        _totalMatched = page.totalMatched;
        _status = _students.isEmpty
            ? PortalLoadStatus.empty
            : PortalLoadStatus.loaded;
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
                : 'Unable to load additional student accounts.',
          ),
        ),
      );
    } finally {
      if (mounted && seq == _requestSeq) {
        setState(() => _loadingMore = false);
      }
    }
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
                title: 'Active Students',
                subtitle:
                    'Review registered student accounts, manual school verification, and account state.',
                trailing: IconButton(
                  tooltip: 'Refresh students',
                  onPressed:
                      _isInitialLoading || _isRefreshing ? null : _loadInitial,
                  icon: const Icon(Icons.refresh),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                key: const Key('active-students-search'),
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _loadInitial(),
                decoration: InputDecoration(
                  hintText: 'Search by name or exact 12-digit LRN',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: IconButton(
                    tooltip: 'Run search',
                    onPressed: _loadInitial,
                    icon: const Icon(Icons.arrow_forward, size: 18),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (value, label) in _statusFilters)
                    ChoiceChip(
                      label: Text(label),
                      selected: _statusFilter == value,
                      onSelected: (selected) {
                        if (!selected || _statusFilter == value) return;
                        setState(() => _statusFilter = value);
                        _loadInitial();
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: ValueKey('active-grade-dropdown-$_gradeFilter'),
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
                    '$_totalMatched ${_totalMatched == 1 ? 'account' : 'accounts'}',
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PortalRefreshStrip(refreshing: _isRefreshing),
                  if (_hasLoadedOnce && _error != null)
                    PortalInlineErrorBanner(
                      message: _error!,
                      onRetry: _loadInitial,
                    ),
                ],
              ),
            ),
            Expanded(
              child: _isInitialLoading
                  ? const Center(child: CircularProgressIndicator())
                  : !_hasLoadedOnce && _error != null
                      ? PortalStateView(
                          icon: Icons.error_outline,
                          title: 'Unable to Load Students',
                          message: _error!,
                          onRetry: _loadInitial,
                        )
                      : _students.isEmpty
                          ? const PortalStateView(
                              icon: Icons.person_search_outlined,
                              title: 'No Matching Student Accounts',
                              message:
                                  'No registered student accounts match the current search or filter criteria.',
                            )
                          : ListView.separated(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 4, 16, 24),
                              itemCount: _students.length +
                                  (_nextCursor != null ? 1 : 0),
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (ctx, index) {
                                if (index == _students.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: OutlinedButton(
                                      onPressed:
                                          _loadingMore ? null : _loadMore,
                                      child: Text(
                                        _loadingMore
                                            ? 'Loading…'
                                            : 'Load More Students',
                                      ),
                                    ),
                                  );
                                }
                                final student = _students[index];
                                return Card(
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: () async {
                                      final scope = PortalScope.maybeOf(ctx);
                                      final detailScreen = StudentDetailsScreen(
                                        studentUid: student.uid,
                                        initialName: student.fullName,
                                        accessRepository:
                                            widget.accessRepository,
                                        portalStudentRepository:
                                            widget.portalStudentRepository,
                                      );
                                      await Navigator.of(ctx).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) =>
                                              scope != null &&
                                                  scope.notifier != null
                                              ? PortalScope(
                                                  notifier: scope.notifier!,
                                                  onAuthorizationLost: scope
                                                      .onAuthorizationLost,
                                                  child: detailScreen,
                                                )
                                              : detailScreen,
                                        ),
                                      );
                                      if (mounted &&
                                          (scope?.notifier == null ||
                                              scope!.notifier!.activeScopeKey !=
                                                  null)) {
                                        await _loadInitial();
                                      }
                                    },
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
                                                  student.fullName,
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w700,
                                                    color:
                                                        PortalColors.inkPrimary,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'LRN: ${student.maskedLrn ?? 'Not recorded'} • ${student.gradeLevel}',
                                                  style: const TextStyle(
                                                    fontSize: 12.5,
                                                    color: PortalColors
                                                        .inkSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          PortalStatusBadge.forStudentCategory(
                                            student.accountCategory,
                                          ),
                                          const SizedBox(width: 4),
                                          const Icon(
                                            Icons.chevron_right,
                                            color: PortalColors.inkSecondary,
                                            size: 20,
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
        ),
      ),
    );
  }
}
