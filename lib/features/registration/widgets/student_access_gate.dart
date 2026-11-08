import 'dart:async';
import 'package:flutter/material.dart';
import '../../../app/app_routes.dart';
import '../screens/create_student_account_screen.dart';
import '../screens/registration_pending_screen.dart';
import '../screens/student_sign_in_screen.dart';
import '../services/student_registration_repository.dart';
import '../models/student_registration_profile.dart';

class StudentAccessGate extends StatefulWidget {
  const StudentAccessGate({
    super.key,
    required this.repository,
    this.authChanges,
    this.pendingBuilder,
  });
  final StudentRegistrationRepository repository;
  final Stream<void>? authChanges;
  final Widget Function(
    StudentRegistrationProfile,
    VoidCallback,
    VoidCallback,
    VoidCallback,
  )?
  pendingBuilder;
  @override
  State<StudentAccessGate> createState() => _StudentAccessGateState();
}

class _StudentAccessGateState extends State<StudentAccessGate>
    with WidgetsBindingObserver {
  late Future<RegistrationResult> state;
  StreamSubscription<void>? subscription;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    state = widget.repository.loadOwnProfile();
    subscription = widget.authChanges?.listen((_) => reload());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    subscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState value) {
    if (value == AppLifecycleState.resumed) {
      reload();
    } else {
      setState(() {
        state = Future.value(
          const RegistrationResult(RegistrationState.failure),
        );
      });
    }
  }

  void reload() {
    if (mounted) {
      setState(() {
        state = widget.repository.loadOwnProfile();
      });
    }
  }

  void publicDashboard() => Navigator.of(
    context,
  ).pushNamedAndRemoveUntil(AppRoutes.dashboard, (_) => false);
  Future<void> signOut() async {
    setState(() {
      state = Future.value(const RegistrationResult(RegistrationState.failure));
    });
    try {
      await widget.repository.signOut();
      reload();
    } catch (_) {
      if (mounted) {
        setState(() {
          state = Future.value(
            const RegistrationResult(
              RegistrationState.failure,
              message: 'Unable to sign out. Please retry.',
            ),
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<RegistrationResult>(
    future: state,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return Scaffold(
          appBar: AppBar(title: const Text('Student Account')),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                TextButton(
                  onPressed: publicDashboard,
                  child: const Text('Return to public dashboard'),
                ),
              ],
            ),
          ),
        );
      }
      final result = snapshot.data;
      if (result?.state == RegistrationState.signedOut) {
        return StudentSignInScreen(
          repository: widget.repository,
          onSignedIn: reload,
        );
      }
      if (result?.state == RegistrationState.pending &&
          result?.profile != null) {
        if (widget.pendingBuilder != null) {
          return KeyedSubtree(
            key: ObjectKey(result!.profile),
            child: widget.pendingBuilder!(
              result.profile!,
              publicDashboard,
              signOut,
              reload,
            ),
          );
        }
        return RegistrationPendingScreen(
          key: ObjectKey(result!.profile),
          profile: result.profile!,
          onRefreshStatus: reload,
          onPublicDashboard: publicDashboard,
          onSignOut: signOut,
        );
      }
      return Scaffold(
        appBar: AppBar(title: const Text('Student Account')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Registration unavailable',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                Text(
                  result?.message.isNotEmpty == true
                      ? result!.message
                      : 'Your account remains restricted. Public emergency resources are available.',
                ),
                const SizedBox(height: 24),
                if (result?.state ==
                    RegistrationState.authCreatedProfileIncomplete)
                  FilledButton(
                    onPressed: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CreateStudentAccountScreen(
                          repository: widget.repository,
                          onRegistered: () {
                            Navigator.pop(context);
                            reload();
                          },
                        ),
                      ),
                    ),
                    child: const Text('Complete registration'),
                  ),
                OutlinedButton(
                  onPressed: reload,
                  child: const Text('Retry status'),
                ),
                TextButton(
                  onPressed: publicDashboard,
                  child: const Text('Return to public dashboard'),
                ),
                TextButton(onPressed: signOut, child: const Text('Sign out')),
              ],
            ),
          ),
        ),
      );
    },
  );
}
