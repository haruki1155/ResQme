import 'package:flutter/material.dart';
import 'package:resqme/app/app_routes.dart';
import 'package:resqme/app/resqme_theme.dart';
import 'package:resqme/features/emergency/presentation/emergency_dashboard_screen.dart';
import 'package:resqme/features/welcome/data/consent_repository.dart';
import 'package:resqme/features/welcome/presentation/splash_screen.dart';
import 'package:resqme/features/welcome/presentation/terms_privacy_screen.dart';

class ResQMeApp extends StatelessWidget {
  const ResQMeApp({super.key, required this.consentRepository});

  final ConsentRepository consentRepository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ResQMe',
      theme: ResQMeTheme.light,
      home: SplashScreen(consentRepository: consentRepository),
      routes: {
        AppRoutes.terms: (routeContext) => TermsPrivacyScreen(
          consentRepository: consentRepository,
          onAccepted: () async {
            await consentRepository.acceptTerms();
            if (!routeContext.mounted) return;
            Navigator.of(
              routeContext,
            ).pushReplacementNamed(AppRoutes.dashboard);
          },
        ),
        AppRoutes.dashboard: (_) => const EmergencyDashboardScreen(),
      },
    );
  }
}
