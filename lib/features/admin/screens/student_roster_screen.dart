import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool _rosterAvailable = false;
  List<String> _availableGrades = const [];
  List<SchoolRosterEntry> _entries = const [];
  String? _nextCursor;
  int _totalMatched = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _importing = false;
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

  Future<void> _startSf1Import() async {
    if (_importing) return;
    setState(() => _importing = true);
    try {
      final picked = await widget.portalStudentRepository.pickSf1ExcelFile();
      if (picked == null || !mounted) return;

      final gradeController = TextEditingController();
      final confirmedGrade = await showDialog<String?>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirm SF1 Grade Level'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'File: ${picked.fileName}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: PortalColors.inkPrimary,
                ),
              ),
              const SizedBox(height: 8),
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

      final preview = await widget.portalStudentRepository.previewRosterImport(
        fileName: picked.fileName,
        fileBase64: picked.fileBase64,
        confirmedGradeLevel:
            (confirmedGrade == null || confirmedGrade.isEmpty)
                ? null
                : confirmedGrade,
      );
      if (!mounted) return;

      final shouldCommit = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _RosterPreviewDialog(preview: preview),
      );
      if (shouldCommit != true || !mounted) return;

      final requestId =
          'sf1_imp_${DateTime.now().microsecondsSinceEpoch}';
      final commitResult =
          await widget.portalStudentRepository.commitRosterImport(
        previewId: preview.previewId,
        requestId: requestId,
      );
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (ctx) => _RosterCommitResultDialog(result: commitResult),
      );
      await _loadInitial();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is PortalStudentException
                ? error.message
                : 'Unable to import SF1 spreadsheet.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _importing = false);
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

    final visibleEntries = _registrationFilter == 'all'
        ? _entries
        : _entries
            .where((e) => e.registrationState == _registrationFilter)
            .toList();

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
                    trailing: IconButton(
                      tooltip: 'Refresh roster',
                      onPressed: _loading ? null : _loadInitial,
                      icon: const Icon(Icons.refresh),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed:
                            _loading || _importing ? null : _startSf1Import,
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
                        onPressed:
                            _loading || _importing ? null : _showImportHistory,
                        icon: const Icon(Icons.history_outlined, size: 18),
                        label: const Text('Import History'),
                      ),
                    ],
                  ),
                ],
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
                      'Use Import Student Roster to upload a DepEd SF1 (.xls or .xlsx) file.',
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
                            setState(() => _registrationFilter = f.id);
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

class _RosterPreviewDialog extends StatelessWidget {
  const _RosterPreviewDialog({required this.preview});
  final RosterImportPreview preview;

  @override
  Widget build(BuildContext context) {
    final canCommit = preview.newCount + preview.proposedUpdateCount > 0;
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
            'Confirm & Import (${preview.newCount + preview.proposedUpdateCount})',
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
