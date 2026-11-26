import 'dart:async';
import 'package:flutter/material.dart';
import '../services/school_review_repository.dart';
import '../../qr/presentation/qr_scanner_screen.dart';

class SchoolReviewScreen extends StatefulWidget {
  const SchoolReviewScreen({super.key, required this.repository, this.scanQr});
  final SchoolReviewRepository repository;
  final Future<String?> Function(BuildContext context)? scanQr;
  @override
  State<SchoolReviewScreen> createState() => _SchoolReviewScreenState();
}

class _SchoolReviewScreenState extends State<SchoolReviewScreen> {
  final email = TextEditingController(),
      password = TextEditingController(),
      studentUid = TextEditingController();
  SchoolReviewCandidate? candidate;
  bool busy = false;
  int generation = 0;
  StreamSubscription<void>? sessionSubscription;
  @override
  void initState() {
    super.initState();
    sessionSubscription = widget.repository.sessionChanges.listen((_) {
      if (!mounted) return;
      setState(() {
        generation++;
        candidate = null;
        message = null;
        busy = false;
      });
    });
  }

  @override
  void didUpdateWidget(covariant SchoolReviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      generation++;
      candidate = null;
      message = null;
      busy = false;
      sessionSubscription?.cancel();
      sessionSubscription = widget.repository.sessionChanges.listen((_) {
        if (mounted) {
          setState(() {
            generation++;
            candidate = null;
            message = null;
            busy = false;
          });
        }
      });
    }
  }

  String? message;
  @override
  void dispose() {
    generation++;
    sessionSubscription?.cancel();
    email.dispose();
    password.dispose();
    studentUid.dispose();
    super.dispose();
  }

  Future<void> signIn() async {
    setState(() => busy = true);
    try {
      await widget.repository.signIn(email.text, password.text);
      if (!mounted) return;
      password.clear();
      setState(
        () => message = 'Signed in. Scan a student QR for authorized review.',
      );
    } catch (_) {
      if (mounted) {
        setState(() => message = 'Unable to sign in with this account.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> findCandidate() async {
    if (busy) return;
    final ticket = ++generation;
    final repository = widget.repository;
    final owner = repository.currentUid;
    setState(() {
      candidate = null;
      message = null;
      busy = true;
    });
    final payload = widget.scanQr != null
        ? await widget.scanQr!(context)
        : await Navigator.of(context).push<String>(
            MaterialPageRoute(
              builder: (scannerContext) => QrScannerScreen(
                onReviewerScan: (value) =>
                    Navigator.of(scannerContext).pop(value),
              ),
            ),
          );
    if (payload == null ||
        !mounted ||
        ticket != generation ||
        owner != repository.currentUid) {
      if (mounted && ticket == generation) setState(() => busy = false);
      return;
    }
    setState(() => busy = true);
    try {
      final result = await repository.loadCandidateByQr(payload);
      if (!mounted || ticket != generation || owner != repository.currentUid) {
        return;
      }
      if (mounted) {
        setState(() {
          candidate = result;
          message =
              'Registration found. School verification is pending; QR is inactive.';
        });
      }
    } catch (_) {
      if (mounted && ticket == generation && owner == repository.currentUid) {
        setState(() {
          candidate = null;
          message =
              'Registration is unavailable for review. Check your access or scan again.';
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> approve() async {
    final selected = candidate;
    if (selected == null || busy) return;
    final ticket = generation;
    final owner = widget.repository.currentUid;
    bool valid() =>
        mounted &&
        ticket == generation &&
        owner == widget.repository.currentUid;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve school enrollment?'),
        content: Text(
          'Confirm that ${selected.fullName} is enrolled at your assigned school. Medical completion is reviewed separately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    if (confirmed != true || !valid()) return;
    setState(() => busy = true);
    try {
      await widget.repository.approve(
        selected.studentUid,
        FirebaseSchoolReviewRepository.createRequestId(),
      );
      if (!valid()) return;
      setState(() {
        candidate = null;
        message = 'School approval recorded. Confirming current status...';
      });
      try {
        final status = await widget.repository.refreshStatus(
          selected.studentUid,
        );
        if (!valid()) return;
        setState(
          () => message =
              'School verification: ${status.schoolStatus}\n${status.qrActive ? "QR ACTIVE" : "QR awaiting additional requirements"}',
        );
      } catch (_) {
        if (valid()) {
          setState(
            () => message =
                'School approval recorded. Status confirmation unavailable; QR activity is unknown.',
          );
        }
      }
    } catch (_) {
      if (valid()) {
        setState(
          () => message =
              'Approval could not be confirmed. Refresh status and retry.',
        );
      }
    } finally {
      if (valid()) setState(() => busy = false);
    }
  }

  Future<void> signOut() async {
    generation++;
    setState(() {
      candidate = null;
      message = null;
    });
    setState(() => busy = true);
    try {
      await widget.repository.signOut();
      if (mounted) {
        setState(() => candidate = null);
        message = null;
      }
    } catch (_) {
      if (mounted) setState(() => message = 'Unable to sign out.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = widget.repository.currentUid != null;
    return Scaffold(
      appBar: AppBar(title: const Text('School review')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'School reviewer access is limited to accounts provisioned by an authorized school operator.',
                  ),
                  const SizedBox(height: 20),
                  if (!signedIn) ...[
                    TextField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Reviewer email',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: password,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Password'),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: busy ? null : signIn,
                      child: const Text('Sign in as reviewer'),
                    ),
                  ] else ...[
                    Text(
                      'Signed in as ${widget.repository.currentUid}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    FilledButton(
                      onPressed: busy ? null : findCandidate,
                      child: const Text('Scan Student QR'),
                    ),
                    if (candidate != null)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                candidate!.fullName,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                'School status: ${candidate!.schoolApprovalStatus}',
                              ),
                              Text(
                                'Verification route: ${candidate!.schoolVerificationOutcome}',
                              ),
                              const SizedBox(height: 12),
                              FilledButton(
                                onPressed: busy ? null : approve,
                                child: const Text('Review and approve'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    OutlinedButton(
                      onPressed: signOut,
                      child: const Text('Sign out'),
                    ),
                  ],
                  if (busy)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (message != null) Text(message!),
                  if (signedIn && candidate == null && !busy)
                    const Text(
                      'Candidate details appear only after the server confirms an active same-school reviewer assignment.',
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
