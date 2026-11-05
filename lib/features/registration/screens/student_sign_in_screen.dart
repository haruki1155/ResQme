import 'package:flutter/material.dart';
import '../services/student_registration_repository.dart';
import 'create_student_account_screen.dart';

class StudentSignInScreen extends StatefulWidget {
  const StudentSignInScreen({
    super.key,
    required this.repository,
    required this.onSignedIn,
  });
  final StudentRegistrationRepository repository;
  final VoidCallback onSignedIn;
  @override
  State<StudentSignInScreen> createState() => _StudentSignInScreenState();
}

class _StudentSignInScreenState extends State<StudentSignInScreen> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController(), password = TextEditingController();
  bool busy = false;
  String? message;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  bool get validEmail =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email.text.trim());
  Future<void> signIn() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      message = null;
    });
    final result = await widget.repository.signIn(email.text, password.text);
    if (!mounted) return;
    setState(() {
      busy = false;
      message = result.message;
    });
    if ([
      RegistrationState.pending,
      RegistrationState.authCreatedProfileIncomplete,
    ].contains(result.state)) {
      password.clear();
      widget.onSignedIn();
    }
  }

  Future<void> reset() async {
    if (busy) return;
    if (!validEmail) {
      setState(() => message = 'Enter your recovery email first.');
      return;
    }
    setState(() => busy = true);
    final result = await widget.repository.sendPasswordReset(email.text);
    if (mounted) {
      setState(() {
        busy = false;
        message = result.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Student Account')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Form(
              key: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  const Icon(
                    Icons.health_and_safety_outlined,
                    size: 64,
                    color: Color(0xFFE92B32),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Welcome to ResQMe',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sign in to view your pending registration. Public emergency resources remain available without an account.',
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: email,
                    enabled: !busy,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    validator: (_) =>
                        validEmail ? null : 'Enter a valid email.',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: password,
                    enabled: !busy,
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        (value ?? '').isEmpty ? 'Enter your password.' : null,
                  ),
                  const SizedBox(height: 16),
                  if (message != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(message!),
                    ),
                  FilledButton(
                    onPressed: busy ? null : signIn,
                    child: Text(busy ? 'Please wait…' : 'Sign in'),
                  ),
                  TextButton(
                    onPressed: busy ? null : reset,
                    child: const Text('Forgot password'),
                  ),
                  OutlinedButton(
                    onPressed: busy
                        ? null
                        : () => Navigator.push<void>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CreateStudentAccountScreen(
                                repository: widget.repository,
                                onRegistered: () {
                                  Navigator.pop(context);
                                  widget.onSignedIn();
                                },
                              ),
                            ),
                          ),
                    child: const Text('Create account'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Return to public dashboard'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
