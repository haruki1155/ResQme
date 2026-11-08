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
    ).pushReplacementNamed(accepted ? AppRoutes.entry : AppRoutes.terms);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE92B32),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.health_and_safety_outlined,
              color: Colors.white,
              size: 72,
            ),
            SizedBox(height: 16),
            Text(
              'RESQME  |  QR ID',
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'EMERGENCY IDENTITY',
              style: TextStyle(
                color: Colors.white70,
                letterSpacing: 3,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
