import 'package:flutter/material.dart';
import '../services/school_review_repository.dart';

class SchoolReviewScreen extends StatefulWidget {
  const SchoolReviewScreen({super.key, required this.repository});
  final SchoolReviewRepository repository;
  @override
  State<SchoolReviewScreen> createState() => _SchoolReviewScreenState();
}

class _SchoolReviewScreenState extends State<SchoolReviewScreen> {
  final email = TextEditingController(),
      password = TextEditingController(),
      studentUid = TextEditingController();
  SchoolReviewCandidate? candidate;
  bool busy = false;
  String? message;
  @override
  void dispose() {
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
        () => message = 'Signed in. Enter the student review reference.',
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
    setState(() => busy = true);
    try {
      final result = await widget.repository.loadCandidate(studentUid.text);
      if (mounted) setState(() => candidate = result);
    } catch (_) {
      if (mounted) setState(() => candidate = null);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> approve() async {
    final selected = candidate;
    if (selected == null) return;
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
    if (confirmed != true || !mounted) return;
    setState(() => busy = true);
    try {
      await widget.repository.approve(
        selected.studentUid,
        FirebaseSchoolReviewRepository.createRequestId(),
      );
      if (mounted) {
        setState(() => candidate = null);
        message = 'School approval recorded.';
        studentUid.clear();
      }
    } catch (_) {
      if (mounted) {
        message = 'Approval could not be recorded. Refresh status and retry.';
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> signOut() async {
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
                    TextField(
                      controller: studentUid,
                      decoration: const InputDecoration(
                        labelText: 'Student review reference',
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: busy ? null : findCandidate,
                      child: const Text('Find pending student'),
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
                      onPressed: busy ? null : signOut,
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
