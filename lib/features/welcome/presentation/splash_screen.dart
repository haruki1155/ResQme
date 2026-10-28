import 'package:flutter/material.dart';
import 'package:resqme/app/app_routes.dart';
import 'package:resqme/features/welcome/data/consent_repository.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.consentRepository});

  final ConsentRepository consentRepository;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _openInitialRoute();
  }

  Future<void> _openInitialRoute() async {
    final accepted = await widget.consentRepository.hasAcceptedTerms();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacementNamed(accepted ? AppRoutes.dashboard : AppRoutes.terms);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.health_and_safety_outlined, size: 64),
            SizedBox(height: 16),
            Text(
              'ResQMe',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 8),
            Text('Emergency support, when it matters.'),
          ],
        ),
      ),
    );
  }
}
