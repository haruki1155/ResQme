import 'package:flutter/material.dart';
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
  List<String> _availableGrades = const [];
  List<SchoolStudentSummary> _students = const [];
  String? _nextCursor;
  int _totalMatched = 0;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  static const _statusFilters = <(String, String)>[
    ('all', 'All'),
    ('registered', 'Registered'),
    ('verified', 'Verified'),
    ('disabled', 'Disabled'),
  ];

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
      final page = await widget.portalStudentRepository.listStudents(
        search: _searchController.text,
        statusFilter: _statusFilter,
        gradeFilter: _gradeFilter == 'all' ? null : _gradeFilter,
        limit: 20,
      );
      if (!mounted) return;
      setState(() {
        _students = page.students;
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
            : 'Unable to load school student accounts.';
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
      final page = await widget.portalStudentRepository.listStudents(
        search: _searchController.text,
        statusFilter: _statusFilter,
        gradeFilter: _gradeFilter == 'all' ? null : _gradeFilter,
        limit: 20,
        cursor: cursor,
      );
      if (!mounted) return;
      setState(() {
        _students = [..._students, ...page.students];
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
                : 'Unable to load additional student accounts.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _loadingMore = false);
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
                  onPressed: _loading ? null : _loadInitial,
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
                      onSelected: _loading
                          ? null
                          : (selected) {
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
                      onChanged: _loading
                          ? null
                          : (next) {
                              if (next == null || next == _gradeFilter) return;
                              setState(() => _gradeFilter = next);
                              _loadInitial();
                            },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '$_totalMatched ${ _totalMatched == 1 ? 'account' : 'accounts'}',
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
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
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
                                      await Navigator.of(ctx).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) => StudentDetailsScreen(
                                            studentUid: student.uid,
                                            initialName: student.fullName,
                                            accessRepository:
                                                widget.accessRepository,
                                            portalStudentRepository:
                                                widget.portalStudentRepository,
                                          ),
                                        ),
                                      );
                                      await _loadInitial();
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
