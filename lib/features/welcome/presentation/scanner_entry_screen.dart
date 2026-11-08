import 'package:flutter/material.dart';
import '../../../app/app_routes.dart';

/// Public entry point. Opening this screen never starts the camera or signs in.
class ScannerEntryScreen extends StatelessWidget {
  const ScannerEntryScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('ResQMe')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),
                const Icon(
                  Icons.qr_code_scanner,
                  size: 80,
                  color: Color(0xFFE92B32),
                ),
                const SizedBox(height: 24),
                Text(
                  'Ready when it matters',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Scan a ResQMe QR or continue as a guest for public emergency resources. Scanning does not sign you in or reveal student information.',
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.scanner),
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan QR'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.dashboard),
                  child: const Text('Continue as Guest'),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Your account',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Create an account to get your unverified QR, or sign in to view your own QR.',
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.register),
                  child: const Text('Register'),
                ),
                TextButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.profile),
                  child: const Text('Sign In'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
