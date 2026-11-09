import 'package:flutter/material.dart';
import 'package:resqme/app/app_routes.dart';
import 'package:resqme/app/resqme_theme.dart';
import 'package:resqme/features/emergency/presentation/emergency_dashboard_screen.dart';
import 'package:resqme/features/medical_boundary/presentation/medical_access_boundary_screen.dart';
import 'package:resqme/features/public_support/presentation/first_aid_screens.dart';
import 'package:resqme/features/public_support/presentation/drrm_screen.dart';
import 'package:resqme/features/public_support/presentation/emergency_hotlines_screen.dart';
import 'package:resqme/features/tier1_shell/presentation/tier1_pending_screen.dart';
import 'package:resqme/features/welcome/data/consent_repository.dart';
import 'package:resqme/features/welcome/presentation/splash_screen.dart';
import 'package:resqme/features/welcome/presentation/terms_privacy_screen.dart';
import 'package:resqme/features/registration/services/student_registration_repository.dart';
import 'package:resqme/features/registration/widgets/student_access_gate.dart';
import 'package:resqme/features/registration/presentation/pilot_account_screen.dart';
import 'package:resqme/features/medical/services/synthetic_medical_repository.dart';
import 'package:resqme/features/medical/services/medical_completion_repository.dart';
import 'package:resqme/features/medical/services/tier2_authorization_repository.dart';
import 'package:resqme/features/medical/screens/tier2_access_screen.dart';
import 'package:resqme/features/welcome/presentation/scanner_entry_screen.dart';
import 'package:resqme/features/qr/presentation/qr_scanner_screen.dart';
import 'package:resqme/features/qr/services/tier1_qr_repository.dart';

class ResQMeApp extends StatelessWidget {
  const ResQMeApp({
    super.key,
    required this.consentRepository,
    this.registrationRepository,
    this.authChanges,
    this.medicalRepository,
    this.qrRepository,
    this.medicalCompletionRepository,
    this.tier2Repository,
  });

  final ConsentRepository consentRepository;
  final StudentRegistrationRepository? registrationRepository;
  final Stream<void>? authChanges;
  final SyntheticMedicalRepository? medicalRepository;
  final Tier1QrRepository? qrRepository;
  final MedicalCompletionRepository? medicalCompletionRepository;
  final Tier2AuthorizationRepository? tier2Repository;

  Widget account(BuildContext context, {bool register = false}) =>
      registrationRepository == null
      ? const Tier1PendingScreen(
          title: 'Student Account',
          message:
              'Registration services are unavailable. Return to Scanner Entry to continue as a guest.',
          icon: Icons.person_outline,
        )
      : StudentAccessGate(
          repository: registrationRepository!,
          authChanges: authChanges,
          startWithRegistration: register,
          pendingBuilder:
              medicalRepository != null &&
                  qrRepository != null &&
                  medicalCompletionRepository != null
              ? (
                  profile,
                  onPublic,
                  onSignOut,
                  onRefresh,
                  registered,
                  onOnboarded,
                ) => PilotAccountScreen(
                  profile: profile,
                  medical: medicalRepository!,
                  completion: medicalCompletionRepository!,
                  qr: qrRepository!,
                  onPublicDashboard: onPublic,
                  onSignOut: onSignOut,
                  openMedical: registered,
                  onMedicalCompleted: onOnboarded,
                  onTier2: () =>
                      Navigator.of(context).pushNamed(AppRoutes.tier2),
                )
              : null,
        );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ResQme',
      debugShowCheckedModeBanner: false,
      theme: ResQMeTheme.light,
      builder: (context, child) => registrationRepository == null
          ? child!
          : Banner(
              message: 'TEST MODE',
              location: BannerLocation.topEnd,
              child: child!,
            ),
      home: SplashScreen(consentRepository: consentRepository),
      routes: {
        AppRoutes.terms: (routeContext) => TermsPrivacyScreen(
          consentRepository: consentRepository,
          onAccepted: () async {
            await consentRepository.acceptTerms();
            if (!routeContext.mounted) return;
            Navigator.of(routeContext).pushReplacementNamed(AppRoutes.entry);
          },
        ),
        AppRoutes.entry: (_) =>
            ScannerEntryScreen(onResolveQr: qrRepository?.resolveScanned),
        AppRoutes.dashboard: (_) => const EmergencyDashboardScreen(),
        AppRoutes.scanner: (context) => QrScannerScreen(
          onResolveQr: qrRepository?.resolveScanned,
          onDashboard: () => Navigator.of(
            context,
          ).pushNamedAndRemoveUntil(AppRoutes.dashboard, (_) => false),
        ),
        AppRoutes.firstAid: (_) => const FirstAidLibraryScreen(),
        AppRoutes.hotlines: (_) => const EmergencyHotlinesScreen(),
        AppRoutes.drrm: (_) => const DrrmScreen(),
        AppRoutes.profile: (context) => account(context),
        AppRoutes.register: (context) => account(context, register: true),
        AppRoutes.medicalBoundary: (_) => const MedicalAccessBoundaryScreen(),
        AppRoutes.tier2: (_) => tier2Repository == null
            ? const MedicalAccessBoundaryScreen()
            : Tier2AccessScreen(repository: tier2Repository!),
      },
    );
  }
}
