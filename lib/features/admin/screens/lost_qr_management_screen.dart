import 'dart:async';
import 'package:flutter/material.dart';
import '../services/portal_read_coordinator.dart';
import '../services/portal_student_repository.dart';
import '../widgets/portal_widgets.dart';

const List<({String value, String label, String subtitle})>
    kQrReplacementReasons = [
  (
    value: 'lost',
    label: 'Lost QR code',
    subtitle: 'The printed or saved QR credential can no longer be found.',
  ),
  (
    value: 'damaged',
    label: 'Damaged QR code',
    subtitle: 'The QR card or tag is torn, faded, or unreadable by scanners.',
  ),
  (
    value: 'compromised',
    label: 'Compromised QR code',
    subtitle: 'An unauthorized party may have copied or photographed the QR.',
  ),
];

/// Reusable Master Admin QR replacement confirmation and step-up verification
/// dialog shared between Lost QR Management and Student Details.
Future<QrReplacementResult?> showQrReplacementDialog({
  required BuildContext context,
  required PortalStudentRepository repository,
  required String studentUid,
  required String studentName,
  required String? maskedLrn,
  required String gradeLevel,
  required int currentVersion,
}) {
  return showDialog<QrReplacementResult>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _QrReplacementDialog(
      repository: repository,
      studentUid: studentUid,
      studentName: studentName,
      maskedLrn: maskedLrn,
      gradeLevel: gradeLevel,
      currentVersion: currentVersion,
    ),
  );
}

class _QrReplacementDialog extends StatefulWidget {
  const _QrReplacementDialog({
    required this.repository,
    required this.studentUid,
    required this.studentName,
    required this.maskedLrn,
    required this.gradeLevel,
    required this.currentVersion,
  });

  final PortalStudentRepository repository;
  final String studentUid;
  final String studentName;
  final String? maskedLrn;
  final String gradeLevel;
  final int currentVersion;

  @override
  State<_QrReplacementDialog> createState() => _QrReplacementDialogState();
}

class _QrReplacementDialogState extends State<_QrReplacementDialog> {
  final _passwordController = TextEditingController();
  String _reason = 'lost';
  bool _usePassword = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  String _makeRequestId() =>
      'qr_rep_${DateTime.now().microsecondsSinceEpoch}_${widget.studentUid.hashCode.abs()}';

  Future<void> _submit() async {
    if (_submitting) return;
    if (_usePassword && _passwordController.text.isEmpty) {
      setState(() => _error = 'Enter your Master Admin password to continue.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final requestId = _makeRequestId();
    try {
      final result = _usePassword
          ? await widget.repository.replaceStudentQrWithPassword(
              studentUid: widget.studentUid,
              reason: _reason,
              requestId: requestId,
              password: _passwordController.text,
            )
          : await widget.repository.replaceStudentQrWithBiometric(
              studentUid: widget.studentUid,
              reason: _reason,
              requestId: requestId,
            );
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (error) {
      if (!mounted) return;
      if (PortalErrorClassifier.isSessionAuthorizationError(error)) {
        PortalScope.reportIfSessionAuthorizationLost(context, error);
        Navigator.of(context).pop();
        return;
      }
      setState(() {
        _error = error is PortalStudentException
            ? error.message
            : 'Unable to replace student QR credential.';
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Replace Student QR Code'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${widget.studentName} • ${widget.gradeLevel}',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: PortalColors.inkPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'LRN: ${widget.maskedLrn ?? 'Not available'} • Current QR v${widget.currentVersion}',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: PortalColors.inkSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: PortalColors.alertBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Permanent Invalidation Warning: Replacing this QR immediately and permanently revokes the previous QR code. The student’s account, school verification, medical record, and guardian authorization remain unchanged.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: PortalColors.alertFg,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Replacement Reason',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: PortalColors.inkPrimary,
                ),
              ),
              const SizedBox(height: 6),
              for (final item in kQrReplacementReasons)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: _submitting
                        ? null
                        : () => setState(() => _reason = item.value),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _reason == item.value
                            ? PortalColors.brandRedSoft
                            : PortalColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _reason == item.value
                              ? PortalColors.brandRed
                              : PortalColors.border,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _reason == item.value
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            size: 18,
                            color: _reason == item.value
                                ? PortalColors.brandRed
                                : PortalColors.inkSecondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.label,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: PortalColors.inkPrimary,
                                  ),
                                ),
                                Text(
                                  item.subtitle,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: PortalColors.inkSecondary,
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
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.fingerprint, size: 18),
                    label: Text('Biometric'),
                  ),
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.password_outlined, size: 18),
                    label: Text('Password'),
                  ),
                ],
                selected: {_usePassword},
                onSelectionChanged: _submitting
                    ? null
                    : (selection) => setState(() {
                          _usePassword = selection.first;
                          _error = null;
                        }),
              ),
              if (_usePassword) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  enabled: !_submitting,
                  decoration: const InputDecoration(
                    labelText: 'Master Admin Password',
                    hintText: 'Re-enter password to authorize',
                  ),
                ),
              ] else ...[
                const SizedBox(height: 8),
                const Text(
                  'Requires hardware-backed biometric confirmation on your enrolled staff device.',
                  style: TextStyle(
                    fontSize: 12,
                    color: PortalColors.inkSecondary,
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: PortalColors.alertBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: PortalColors.alertFg,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Confirm & Replace QR'),
        ),
      ],
    );
  }
}

class LostQrManagementScreen extends StatefulWidget {
  const LostQrManagementScreen({
    super.key,
    required this.repository,
  });

  final PortalStudentRepository repository;

  @override
  State<LostQrManagementScreen> createState() => _LostQrManagementScreenState();
}

class _LostQrManagementScreenState extends State<LostQrManagementScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  List<SchoolStudentSummary> _students = const [];
  PortalLoadStatus _status = PortalLoadStatus.initialLoading;
  bool _hasLoadedOnce = false;
  bool _startingReplacement = false;
  int _requestSeq = 0;
  String? _error;
  String? _successMessage;

  bool get _isInitialLoading =>
      !_hasLoadedOnce && _status == PortalLoadStatus.initialLoading;
  bool get _isRefreshing => _status == PortalLoadStatus.refreshing;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    final seq = ++_requestSeq;
    final searchSnapshot = _searchController.text.trim();
    setState(() {
      _status = _hasLoadedOnce
          ? PortalLoadStatus.refreshing
          : PortalLoadStatus.initialLoading;
      _error = null;
    });
    try {
      final page = await widget.repository.listStudents(
        search: searchSnapshot,
        statusFilter: 'verified',
        limit: 25,
      );
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _hasLoadedOnce = true;
        _students = page.students;
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
            : 'Unable to load verified students.';
      });
    }
  }

  Future<void> _startReplacement(SchoolStudentSummary student) async {
    if (_startingReplacement) return;
    setState(() {
      _startingReplacement = true;
      _error = null;
      _successMessage = null;
    });
    try {
      final details = await widget.repository.getStudentDetails(student.uid);
      if (!mounted) return;
      final eligible = !details.accountDisabled &&
          details.schoolApprovalStatus == 'approved' &&
          details.medicalCompletionStatus == 'complete' &&
          (details.guardianAuthorizationStatus == 'verified' ||
              details.guardianAuthorizationStatus == 'not_required_adult');
      if (!eligible) {
        setState(() {
          _error =
              '${details.fullName} is not eligible for QR replacement right now (requires active account, approved school verification, complete medical record, and guardian authorization if minor).';
        });
        return;
      }

      final result = await showQrReplacementDialog(
        context: context,
        repository: widget.repository,
        studentUid: details.uid,
        studentName: details.fullName,
        maskedLrn: details.maskedLrn,
        gradeLevel: details.gradeLevel,
        currentVersion: details.credentialVersion,
      );
      if (result == null || !mounted) return;
      PortalScope.notifyMutation(context);
      setState(() {
        _successMessage =
            'Replaced QR for ${details.fullName} (Credential v${result.credentialVersion}, reason: ${result.reason}). Previous QR is permanently revoked.';
      });
      await _loadStudents();
    } catch (error) {
      if (!mounted) return;
      if (PortalErrorClassifier.isSessionAuthorizationError(error)) {
        PortalScope.reportIfSessionAuthorizationLost(context, error);
        return;
      }
      setState(() {
        _error = error is PortalStudentException
            ? error.message
            : 'Unable to load student QR details.';
      });
    } finally {
      if (mounted) {
        setState(() => _startingReplacement = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lost QR Management'),
        actions: [
          IconButton(
            tooltip: 'Refresh students',
            onPressed:
                _isInitialLoading || _isRefreshing ? null : _loadStudents,
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
                const PortalSectionHeader(
                  title: 'Replace Lost, Damaged, or Compromised QR',
                  subtitle:
                      'Rotates the student’s Tier 1 QR credential and permanently revokes the previous QR without altering medical or verification records.',
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _searchController,
                  onChanged: (_) {
                    _debounce?.cancel();
                    _debounce = Timer(
                      const Duration(milliseconds: 300),
                      _loadStudents,
                    );
                  },
                  decoration: InputDecoration(
                    hintText: 'Search verified student by name or 12-digit LRN',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              _searchController.clear();
                              _loadStudents();
                            },
                            icon: const Icon(Icons.clear),
                          )
                        : null,
                  ),
                ),
                if (_successMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: PortalColors.verifiedBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _successMessage!,
                      style: const TextStyle(
                        color: PortalColors.verifiedFg,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: PortalColors.alertBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: PortalColors.alertFg,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                PortalRefreshStrip(refreshing: _isRefreshing),
                if (_isInitialLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 36),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (!_hasLoadedOnce && _error != null)
                  PortalStateView(
                    icon: Icons.error_outline,
                    title: 'Verified Students Unavailable',
                    message: _error!,
                    onRetry: _loadStudents,
                  )
                else if (_students.isEmpty)
                  const PortalStateView(
                    icon: Icons.qr_code_2_outlined,
                    title: 'No Verified Students Found',
                    message:
                        'Only active, school-verified students matching your search appear here.',
                  )
                else
                  for (final student in _students)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                            color: PortalColors.inkPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'LRN: ${student.maskedLrn ?? 'Not available'} • ${student.gradeLevel}',
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            color: PortalColors.inkSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const PortalStatusBadge(
                                    label: 'Verified Student',
                                    tone: PortalBadgeTone.verified,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerRight,
                                child: OutlinedButton.icon(
                                  onPressed: _startingReplacement
                                      ? null
                                      : () => _startReplacement(student),
                                  icon: const Icon(Icons.qr_code_2, size: 18),
                                  label: const Text('Replace QR'),
                                ),
                              ),
                            ],
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
