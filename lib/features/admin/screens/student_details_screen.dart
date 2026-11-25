import 'dart:math';
import 'package:flutter/material.dart';
import '../services/portal_read_coordinator.dart';
import '../services/portal_student_repository.dart';
import '../services/staff_access_repository.dart';
import '../widgets/portal_widgets.dart';
import 'lost_qr_management_screen.dart';

class StudentDetailsScreen extends StatefulWidget {
  const StudentDetailsScreen({
    super.key,
    required this.studentUid,
    required this.initialName,
    required this.accessRepository,
    required this.portalStudentRepository,
  });

  final String studentUid;
  final String initialName;
  final StaffAccessRepository accessRepository;
  final PortalStudentRepository portalStudentRepository;

  @override
  State<StudentDetailsScreen> createState() => _StudentDetailsScreenState();
}

class _StudentDetailsScreenState extends State<StudentDetailsScreen> {
  SchoolStudentDetails? _details;
  PortalLoadStatus _status = PortalLoadStatus.initialLoading;
  bool _busy = false;
  int _requestSeq = 0;
  String? _error;
  String? _feedbackMessage;

  bool get _isInitialLoading =>
      _details == null && _status == PortalLoadStatus.initialLoading;
  bool get _isRefreshing => _status == PortalLoadStatus.refreshing;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant StudentDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.studentUid != widget.studentUid) {
      _requestSeq += 1;
      _details = null;
      _error = null;
      _feedbackMessage = null;
      _status = PortalLoadStatus.initialLoading;
      _load();
    }
  }

  Future<void> _load() async {
    final seq = ++_requestSeq;
    final targetUid = widget.studentUid;
    setState(() {
      _status = _details != null
          ? PortalLoadStatus.refreshing
          : PortalLoadStatus.initialLoading;
      _error = null;
    });
    try {
      final details = await widget.portalStudentRepository
          .getStudentDetails(targetUid);
      if (!mounted || seq != _requestSeq || widget.studentUid != targetUid) {
        return;
      }
      setState(() {
        _details = details;
        _error = null;
        _status = PortalLoadStatus.loaded;
      });
    } catch (error) {
      if (!mounted || seq != _requestSeq) return;
      if (PortalErrorClassifier.isSessionAuthorizationError(error) ||
          (error is PortalStudentException && error.isSessionAuthLoss)) {
        setState(() {
          _details = null;
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
            : 'Unable to load student account details.';
      });
    }
  }

  String _generateRequestId() {
    final rand = Random.secure();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final suffix = List.generate(16, (_) => chars[rand.nextInt(chars.length)]).join();
    return 'verify-$suffix';
  }

  Future<void> _confirmManualVerification(SchoolStudentDetails details) async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Verify Student Account'),
        content: Text(
          'Approve school enrollment verification for ${details.fullName} (LRN: ${details.maskedLrn ?? 'Not recorded'})?\n\n'
          'Confirm this student against official school enrollment evidence. '
          'QR credentials activate only when medical and guardian requirements are also complete.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Approve Verification'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _busy = true;
      _error = null;
      _feedbackMessage = null;
    });
    try {
      await widget.portalStudentRepository.verifyStudentAccount(
        studentUid: details.uid,
        requestId: _generateRequestId(),
      );
      if (mounted) {
        PortalScope.notifyMutation(context);
      }
      await _load();
      if (!mounted) return;
      setState(() {
        _feedbackMessage =
            'School verification approved via Manual Master Admin review.';
      });
    } catch (error) {
      if (!mounted) return;
      if (PortalErrorClassifier.isSessionAuthorizationError(error)) {
        PortalScope.reportIfSessionAuthorizationLost(context, error);
        return;
      }
      setState(() {
        _error = error is PortalStudentException
            ? error.message
            : 'Unable to approve student verification.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmStatusToggle(SchoolStudentDetails details) async {
    if (_busy) return;
    final disabling = !details.accountDisabled;

    final password = await showDialog<String>(
      context: context,
      builder: (_) => _StudentStatusReauthDialog(
        studentName: details.fullName,
        disabling: disabling,
      ),
    );
    if (password == null || password.isEmpty) return;

    setState(() {
      _busy = true;
      _error = null;
      _feedbackMessage = null;
    });
    try {
      await widget.accessRepository.reauthenticate(password);
      await widget.portalStudentRepository.setStudentAccountStatus(
        studentUid: details.uid,
        action: disabling ? 'disable' : 'enable',
      );
      if (mounted) {
        PortalScope.notifyMutation(context);
      }
      await _load();
      if (!mounted) return;
      setState(() {
        _feedbackMessage = disabling
            ? 'Student account disabled.'
            : 'Student account re-enabled.';
      });
    } catch (error) {
      if (!mounted) return;
      if (PortalErrorClassifier.isSessionAuthorizationError(error)) {
        PortalScope.reportIfSessionAuthorizationLost(context, error);
        return;
      }
      setState(() {
        _error = error is PortalStudentException
            ? error.message
            : error is StaffAccessDenied
                ? error.message
                : 'Unable to update student account status.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openQrReplacement(SchoolStudentDetails details) async {
    final result = await showQrReplacementDialog(
      context: context,
      repository: widget.portalStudentRepository,
      studentUid: details.uid,
      studentName: details.fullName,
      maskedLrn: details.maskedLrn,
      gradeLevel: details.gradeLevel,
      currentVersion: details.credentialVersion,
    );
    if (result == null || !mounted) return;
    PortalScope.notifyMutation(context);
    setState(() {
      _error = null;
      _feedbackMessage =
          'Replaced QR credential (v${result.credentialVersion}, reason: ${result.reason}). Previous QR is permanently revoked.';
    });
    await _load();
  }

  String _formatRegistrationStatus(String raw) => switch (raw) {
        'pending_guardian' => 'Registered (Minor Onboarding)',
        'pending_review' => 'Registered (Standard Onboarding)',
        _ => raw,
      };

  String _formatSchoolVerification(String raw) => switch (raw) {
        'approved' => 'Approved',
        'revoked' => 'Revoked',
        _ => 'Pending School Review',
      };

  String _formatVerificationMethod(String? raw) => switch (raw) {
        'roster' => 'Official School Roster (Automatic)',
        'manual_admin' => 'Manual Master Admin Review',
        _ => 'Not yet verified',
      };

  String _formatMedicalStatus(String raw) =>
      raw == 'complete' ? 'Complete' : 'Incomplete';

  String _formatGuardianStatus(String raw) => switch (raw) {
        'not_required_adult' => 'Not Required (Adult 18+)',
        'verified' => 'Verified',
        _ => 'Pending Guardian Verification',
      };

  String _formatQrStatus(String raw) => switch (raw) {
        'active' => 'Active',
        'pending' => 'Pending Eligibility',
        'revoked' => 'Revoked',
        _ => 'Not Issued',
      };

  String _formatBirthOrAge(SchoolStudentDetails d) {
    if (d.birthDate != null && d.ageYearsAtRegistration != null) {
      return '${d.birthDate} (Age ${d.ageYearsAtRegistration} at registration)';
    }
    if (d.birthDate != null) return d.birthDate!;
    if (d.ageYearsAtRegistration != null) {
      return 'Age ${d.ageYearsAtRegistration} at registration';
    }
    return 'Not available';
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 148,
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
    final details = _details;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Details'),
        actions: [
          IconButton(
            tooltip: 'Refresh details',
            onPressed: _isInitialLoading || _isRefreshing || _busy
                ? null
                : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: _isInitialLoading
            ? const Center(child: CircularProgressIndicator())
            : details == null
                ? PortalStateView(
                    icon: Icons.error_outline,
                    title: 'Student Details Unavailable',
                    message: _error ?? 'Unable to load student details.',
                    onRetry: _load,
                  )
                : Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          PortalRefreshStrip(refreshing: _isRefreshing),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          details.fullName,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: PortalColors.inkPrimary,
                                          ),
                                        ),
                                      ),
                                      PortalStatusBadge.forStudentCategory(
                                        details.accountCategory,
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 22),
                                  PortalProtectedLrnRow(
                                    maskedLrn: details.maskedLrn,
                                    hasLrn: details.hasLrn,
                                    targetType: 'student',
                                    targetId: details.uid,
                                    studentLabel: details.fullName,
                                    portalStudentRepository:
                                        widget.portalStudentRepository,
                                  ),
                                  _detailRow('Grade Level', details.gradeLevel),
                                  _detailRow(
                                    'Sex',
                                    details.sex ?? 'Not specified',
                                  ),
                                  _detailRow(
                                    'Birth / Age Info',
                                    _formatBirthOrAge(details),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Verification & Credential Readiness',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: PortalColors.inkPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Protected medical contents are restricted to biometric emergency scans and are never displayed here.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: PortalColors.inkSecondary,
                                    ),
                                  ),
                                  const Divider(height: 20),
                                  _detailRow(
                                    'Registration Status',
                                    _formatRegistrationStatus(
                                      details.registrationStatus,
                                    ),
                                  ),
                                  _detailRow(
                                    'School Verification',
                                    _formatSchoolVerification(
                                      details.schoolApprovalStatus,
                                    ),
                                  ),
                                  _detailRow(
                                    'Verification Method',
                                    _formatVerificationMethod(
                                      details.verificationMethod,
                                    ),
                                  ),
                                  _detailRow(
                                    'Medical Completion',
                                    _formatMedicalStatus(
                                      details.medicalCompletionStatus,
                                    ),
                                  ),
                                  _detailRow(
                                    'Guardian Auth',
                                    _formatGuardianStatus(
                                      details.guardianAuthorizationStatus,
                                    ),
                                  ),
                                  _detailRow(
                                    'QR Credential Status',
                                    _formatQrStatus(details.qrStatus),
                                  ),
                                  _detailRow(
                                    'Credential Version',
                                    details.credentialVersion > 0
                                        ? 'v${details.credentialVersion}'
                                        : 'Not Issued',
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (details.verificationOutcome == 'conflict' &&
                              details.schoolApprovalStatus != 'approved') ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: PortalColors.alertBg,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Manual verification is unavailable while an unresolved LRN or roster claim conflict exists on this account.',
                                style: TextStyle(
                                  color: PortalColors.alertFg,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                          if (_feedbackMessage != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: PortalColors.verifiedBg,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _feedbackMessage!,
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
                          const SizedBox(height: 16),
                          if (details.canVerifyManually) ...[
                            FilledButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () => _confirmManualVerification(details),
                              icon: const Icon(Icons.verified_user_outlined),
                              label: const Text('Verify Student Account'),
                            ),
                            const SizedBox(height: 10),
                          ],
                          if (!details.accountDisabled &&
                              details.schoolApprovalStatus == 'approved' &&
                              details.medicalCompletionStatus == 'complete' &&
                              (details.guardianAuthorizationStatus ==
                                      'verified' ||
                                  details.guardianAuthorizationStatus ==
                                      'not_required_adult')) ...[
                            OutlinedButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () => _openQrReplacement(details),
                              icon: const Icon(Icons.qr_code_2_outlined),
                              label: const Text('Replace QR Code'),
                            ),
                            const SizedBox(height: 10),
                          ],
                          if (details.accountDisabled)
                            FilledButton.tonalIcon(
                              onPressed: _busy
                                  ? null
                                  : () => _confirmStatusToggle(details),
                              icon: const Icon(Icons.check_circle_outline),
                              label: const Text('Enable Student Account'),
                            )
                          else
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: PortalColors.alertFg,
                              ),
                              onPressed: _busy
                                  ? null
                                  : () => _confirmStatusToggle(details),
                              icon: const Icon(Icons.person_off_outlined),
                              label: const Text('Disable Student Account'),
                            ),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }
}

class _StudentStatusReauthDialog extends StatefulWidget {
  const _StudentStatusReauthDialog({
    required this.studentName,
    required this.disabling,
  });

  final String studentName;
  final bool disabling;

  @override
  State<_StudentStatusReauthDialog> createState() =>
      _StudentStatusReauthDialogState();
}

class _StudentStatusReauthDialogState
    extends State<_StudentStatusReauthDialog> {
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.disabling ? 'Disable Student Account' : 'Enable Student Account',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.disabling
                  ? 'Disabling ${widget.studentName} immediately blocks protected student profile, QR, and Tier 2 operations while preserving audit records.'
                  : 'Re-enabling ${widget.studentName} restores student account access. Any previously revoked QR credential remains revoked.',
            ),
            const SizedBox(height: 14),
            TextField(
              key: const Key('student-status-reauth-password'),
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm Master Admin password',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_passwordController.text),
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
