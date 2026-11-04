import 'package:flutter/material.dart';
import 'package:resqme/app/app_routes.dart';
import 'package:resqme/app/resqme_theme.dart';
import 'package:resqme/features/emergency/presentation/emergency_dashboard_screen.dart';
import 'package:resqme/features/medical_boundary/presentation/medical_access_boundary_screen.dart';
import 'package:resqme/features/tier1_shell/presentation/tier1_pending_screen.dart';
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
        AppRoutes.scanner: (_) => const Tier1PendingScreen(
          title: 'Scan QR',
          message:
              'Secure QR scanning will be added after server-issued credentials are ready.',
          icon: Icons.qr_code_scanner,
        ),
        AppRoutes.firstAid: (_) => const Tier1PendingScreen(
          title: 'First-aid instructions',
          message:
              'Reviewed offline first-aid guidance will be added in the next Tier 1 milestone.',
          icon: Icons.add_circle_outline,
        ),
        AppRoutes.hotlines: (_) => const Tier1PendingScreen(
          title: 'Emergency hotlines',
          message:
              'An approved public hotline directory will be added when its regional contacts are supplied.',
          icon: Icons.call_outlined,
        ),
        AppRoutes.drrm: (_) => const Tier1PendingScreen(
          title: 'DRRM instructions',
          message:
              'Reviewed offline disaster-preparedness guidance will be added in the next Tier 1 milestone.',
          icon: Icons.shield_outlined,
        ),
        AppRoutes.profile: (_) => const Tier1PendingScreen(
          title: 'Student profile',
          message:
              'Synthetic Tier 1 enrollment will be added after the consent fields are approved.',
          icon: Icons.person_outline,
        ),
        AppRoutes.medicalBoundary: (_) => const MedicalAccessBoundaryScreen(),
      },
    );
  }
}
