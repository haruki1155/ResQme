import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FeatureGuideContent {
  const FeatureGuideContent({
    required this.featureId,
    required this.title,
    required this.summary,
    required this.steps,
    this.securityNote,
    this.version = 1,
  });

  final String featureId;
  final int version;
  final String title;
  final String summary;
  final List<String> steps;
  final String? securityNote;
}

abstract final class FeatureGuidePolicy {
  /// Enabled in production/staging app entrypoints (`main.dart`, `main_admin.dart`)
  /// so first-time screens auto-present instructions once per account+feature+version
  /// while keeping isolated widget tests deterministic unless explicitly enabled.
  static bool enableAutoShowFirstVisit = false;

  static final Set<String> _sessionCheckedKeys = <String>{};

  static void resetSessionCacheForTesting() {
    _sessionCheckedKeys.clear();
  }

  static String _digestScope(String rawScope) {
    final trimmed = rawScope.trim();
    if (trimmed.isEmpty || trimmed == 'guest') return 'guest';
    // 64-bit FNV-1a non-reversible digest so raw emails/UIDs/PII are never stored in prefs keys.
    var h1 = 0xcbf29ce4;
    var h2 = 0x84222325;
    for (final unit in trimmed.codeUnits) {
      h1 ^= unit;
      h1 = (h1 * 0x01000193) & 0xffffffff;
      h2 ^= (unit * 31) & 0xffffffff;
      h2 = (h2 * 0x01000193) & 0xffffffff;
    }
    return '${h1.toRadixString(16).padLeft(8, '0')}${h2.toRadixString(16).padLeft(8, '0')}';
  }

  static String storageKey(FeatureGuideContent guide, String accountScope) {
    final scope = _digestScope(accountScope);
    final safeFeature =
        guide.featureId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return 'resqme_guide_seen_v${guide.version}_${scope}_$safeFeature';
  }

  static Future<bool> shouldAutoOpen(
    FeatureGuideContent guide,
    String accountScope,
  ) async {
    final key = storageKey(guide, accountScope);
    if (_sessionCheckedKeys.contains(key)) return false;
    _sessionCheckedKeys.add(key);
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) != true;
  }

  static Future<void> markSeen(
    FeatureGuideContent guide,
    String accountScope,
  ) async {
    final key = storageKey(guide, accountScope);
    _sessionCheckedKeys.add(key);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, true);
  }
}

Future<void> showFeatureGuideModal(
  BuildContext context, {
  required FeatureGuideContent guide,
}) {
  const brandRed = Color(0xFFE92B32);
  const inkPrimary = Color(0xFF0F172A);
  const inkSecondary = Color(0xFF475569);

  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 14, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.info_outline,
                      color: brandRed,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'FEATURE GUIDE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: brandRed,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close guide',
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      guide.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: inkPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      guide.summary,
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.45,
                        color: inkSecondary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    for (var i = 0; i < guide.steps.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${i + 1}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: inkPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                guide.steps[i],
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.4,
                                  color: inkPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (guide.securityNote != null) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.shield_outlined,
                              size: 18,
                              color: brandRed,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                guide.securityNote!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.4,
                                  color: inkSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: brandRed,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Got it'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class FeatureGuideIconButton extends StatefulWidget {
  const FeatureGuideIconButton({
    super.key,
    required this.guide,
    this.accountScope = 'guest',
    this.autoOpenOnFirstVisit,
    this.iconColor,
  });

  final FeatureGuideContent guide;
  final String accountScope;
  final bool? autoOpenOnFirstVisit;
  final Color? iconColor;

  @override
  State<FeatureGuideIconButton> createState() => _FeatureGuideIconButtonState();
}

class _FeatureGuideIconButtonState extends State<FeatureGuideIconButton> {
  bool _checkedFirstVisit = false;

  @override
  void initState() {
    super.initState();
    _maybeAutoPresent();
  }

  @override
  void didUpdateWidget(covariant FeatureGuideIconButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accountScope != widget.accountScope ||
        oldWidget.guide.featureId != widget.guide.featureId) {
      _checkedFirstVisit = false;
      _maybeAutoPresent();
    }
  }

  void _maybeAutoPresent() {
    if (_checkedFirstVisit) return;
    _checkedFirstVisit = true;
    final shouldAuto =
        widget.autoOpenOnFirstVisit ?? FeatureGuidePolicy.enableAutoShowFirstVisit;
    if (!shouldAuto) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final unseen = await FeatureGuidePolicy.shouldAutoOpen(
        widget.guide,
        widget.accountScope,
      );
      if (!unseen || !mounted) return;
      await FeatureGuidePolicy.markSeen(widget.guide, widget.accountScope);
      if (!mounted) return;
      await showFeatureGuideModal(context, guide: widget.guide);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.hideCurrentSnackBar();
      messenger?.showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 4),
          content: Text(
            'Tip: Tap the info icon (ⓘ) beside the screen title anytime to view instructions again.',
          ),
        ),
      );
    });
  }

  Future<void> _openManually() async {
    await FeatureGuidePolicy.markSeen(widget.guide, widget.accountScope);
    if (!mounted) return;
    await showFeatureGuideModal(context, guide: widget.guide);
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Feature Guide: ${widget.guide.title}',
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      color: widget.iconColor,
      onPressed: _openManually,
      icon: const Icon(Icons.info_outline),
    );
  }
}

abstract final class ResQMeFeatureGuides {
  static const studentDashboard = FeatureGuideContent(
    featureId: 'student_dashboard',
    title: 'Emergency Readiness Dashboard',
    summary:
        'Access immediate offline emergency support or manage your verified ResQMe student credential.',
    steps: [
      'Use First Aid Instructions and Emergency Hotlines anytime — even offline or without signing in.',
      'Sign in or register your student account to set up your emergency QR and medical record.',
      'Open My ResQMe QR or Tier 2 QR when school verification and medical details are complete.',
    ],
    securityNote:
        'Public emergency tools never expose private medical or student identity data.',
  );

  static const studentRegistration = FeatureGuideContent(
    featureId: 'student_registration',
    title: 'Student Registration & Roster Verification',
    summary:
        'Create your ResQMe student account using your official school enrollment details.',
    steps: [
      'Enter your full name, exact birth date (YYYY-MM-DD), and 12-digit LRN carefully.',
      'Include your school-issued one-time Enrollment Code for automatic roster verification.',
      'If you do not have an enrollment code, submit registration for manual school review.',
    ],
    securityNote:
        'Students under 18 require verified parent/guardian authorization before QR activation.',
  );

  static const studentQrLogin = FeatureGuideContent(
    featureId: 'student_qr_login',
    title: 'Student Sign-In & Login QR',
    summary:
        'Sign in with your email and password, or scan your personal Login QR to identify your account faster.',
    steps: [
      'Tap Scan Login QR to identify your account without typing your email address.',
      'Always enter your account password to finish signing in.',
      'Replace or revoke your Login QR anytime from your Student Account QR screen.',
    ],
    securityNote:
        'Password login on another phone never transfers your personal biometric Tier 2 device keys.',
  );

  static const studentBiometrics = FeatureGuideContent(
    featureId: 'student_biometrics',
    title: 'Personal-Device Biometric Security',
    summary:
        'Bind hardware-backed fingerprint protection on your personal phone for Tier 2 emergency access.',
    steps: [
      'Enroll at least one fingerprint in Android Settings on your personal phone.',
      'Confirm your ResQMe password and scan your fingerprint to bind this trusted device.',
      'If switching phones, generate a transfer code on your old device or request school recovery.',
    ],
    securityNote:
        'Your fingerprint data stays inside Android hardware keystore and never leaves your phone.',
  );

  static const studentTier1Qr = FeatureGuideContent(
    featureId: 'student_tier1_qr',
    title: 'My ResQMe Emergency QR (Tier 1)',
    summary:
        'Manage your permanent emergency QR credential and view your protected student identity.',
    steps: [
      'Present your active QR during school emergencies so authorized responders can assist you.',
      'Tap Replace QR immediately if your printed card or tag is lost or compromised.',
      'Use Student Login QR if you want a separate revocable QR for account sign-in.',
    ],
    securityNote:
        'Your QR contains only a random opaque identifier — never raw medical details or your LRN.',
  );

  static const studentTier2Qr = FeatureGuideContent(
    featureId: 'student_tier2_qr',
    title: 'Protected Tier 2 Emergency QR',
    summary:
        'Present a short-lived, biometric-unlocked QR on your personal device for authorized medical triage.',
    steps: [
      'Tap Unlock Protected Tier 2 QR and confirm with your fingerprint when a responder is ready.',
      'Show the screen to the responder before the 90-second single-use timer expires.',
      'Tap Lock QR Now when finished; switching apps locks and clears the QR automatically.',
    ],
    securityNote:
        'Screenshots are blocked while unlocked, and staff must still verify their own biometrics.',
  );

  static const studentMedicalRecord = FeatureGuideContent(
    featureId: 'student_medical_record',
    title: 'Emergency Medical Information',
    summary:
        'Provide accurate allergies, conditions, and primary emergency contact details for responders.',
    steps: [
      'Select Unknown, None known, or Listed with clear details for conditions and allergies.',
      'Enter a reachable primary parent, guardian, or emergency contact phone number.',
      'Review and confirm your entries to complete medical readiness for your QR.',
    ],
    securityNote:
        'Medical records are encrypted in transit and released only to verified biometric emergency scans.',
  );

  static const studentFirstAid = FeatureGuideContent(
    featureId: 'student_first_aid',
    title: 'Offline First Aid Instructions',
    summary:
        'Follow step-by-step emergency procedures offline and call 911 immediately for life-threatening signs.',
    steps: [
      'Search or pick an emergency topic to view immediate step-by-step actions.',
      'Check red warning indicators first and tap Call 911 whenever emergency help is needed.',
      'All first-aid instructions remain available offline without an internet connection.',
    ],
  );

  static const portalDashboard = FeatureGuideContent(
    featureId: 'portal_dashboard',
    title: 'School Administration Dashboard',
    summary:
        'Monitor school enrollment readiness, launch emergency Tier 2 scans, and access supervision tools.',
    steps: [
      'Review live counts for Roster, Registered, Verified, Disabled, and Authorized Personnel.',
      'Use Scan Student Emergency QR with your enrolled staff biometrics during incidents.',
      'Open Lost QR Management or Activity Logs for Master Admin credential and audit oversight.',
    ],
  );

  static const portalActiveStudents = FeatureGuideContent(
    featureId: 'portal_active_students',
    title: 'Active Students & Verification',
    summary:
        'Search, filter, manually verify, or manage student accounts assigned to your school.',
    steps: [
      'Filter students by Registered, Verified, Disabled, or Grade Level, or search by name/LRN.',
      'Open a student card to review readiness, verify pending accounts, or reset a lost biometric device.',
      'LRNs remain masked by default and require step-up verification with audit logging to reveal.',
    ],
  );

  static const portalStudentRoster = FeatureGuideContent(
    featureId: 'portal_student_roster',
    title: 'Official Student Roster & SF1 Import',
    summary:
        'Maintain your school enrollment baseline by importing official DepEd SF1 (.xls / .xlsx) workbooks.',
    steps: [
      'Tap Import Student Roster and select a genuine .xls or .xlsx SF1 file (max 2 MB).',
      'Review New, Updated, Duplicate, Conflict, and Invalid rows in the masked-LRN preview.',
      'Acknowledge the Data Privacy Act notice before confirming commit, then distribute enrollment codes securely.',
    ],
    securityNote:
        'Raw SF1 Excel files are never retained after roster claims are generated.',
  );

  static const portalAuthorizedPersonnel = FeatureGuideContent(
    featureId: 'portal_authorized_personnel',
    title: 'Authorized Personnel Management',
    summary:
        'Provision and supervise school clinic or responder staff accounts authorized for emergency scans.',
    steps: [
      'Create Authorized Personnel accounts scoped strictly to your school.',
      'Have each staff member change their temporary password and enroll hardware biometrics on their device.',
      'Suspend, revoke, or reset staff passwords or devices immediately when roles change.',
    ],
  );

  static const portalLostQr = FeatureGuideContent(
    featureId: 'portal_lost_qr',
    title: 'Lost or Compromised QR Replacement',
    summary:
        'Immediately rotate a student emergency QR credential when a badge is lost, damaged, or copied.',
    steps: [
      'Search and select the verified student whose QR needs replacement.',
      'Choose the replacement reason (Lost, Damaged, or Compromised) and confirm with step-up auth.',
      'The previous QR is permanently revoked at once and recorded in Activity Logs.',
    ],
  );

  static const portalActivityLogs = FeatureGuideContent(
    featureId: 'portal_activity_logs',
    title: 'Security & Supervision Activity Logs',
    summary:
        'Audit chronological security, administrative, and biometric Tier 2 events in Asia/Manila time.',
    steps: [
      'Filter events by Category (Security, Management, Tier 2), Outcome, or Manila date range.',
      'Tap any log card to inspect the actor, role, verification method, and audit source.',
      'Sensitive medical details, raw QR payloads, and full LRNs are automatically redacted.',
    ],
  );

  static const portalStaffBiometrics = FeatureGuideContent(
    featureId: 'portal_staff_biometrics',
    title: 'Staff Biometric Device & Emergency Scanner',
    summary:
        'Enroll hardware-backed fingerprint keys and scan student emergency QRs with mandatory audit logging.',
    steps: [
      'Confirm your staff password and fingerprint in Trusted Device Biometrics to enroll this phone.',
      'Select the emergency access purpose before scanning a student Tier 1 or Tier 2 QR code.',
      'Protected medical records auto-hide on timeout, app switching, or manual lock.',
    ],
  );
}
