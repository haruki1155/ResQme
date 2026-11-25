import 'dart:async';
import 'package:flutter/material.dart';
import '../../../app/resqme_theme.dart';
import '../services/portal_read_coordinator.dart';
import '../services/portal_student_repository.dart';

/// Inherited scope exposing the active [PortalReadCoordinator], cross-screen
/// mutation invalidation, and immediate authorization-loss handling to all
/// Portal screens without breaking standalone screen instantiation in tests.
class PortalScope extends InheritedNotifier<PortalReadCoordinator> {
  const PortalScope({
    super.key,
    required PortalReadCoordinator super.notifier,
    required this.onAuthorizationLost,
    required super.child,
  });

  final void Function(Object error) onAuthorizationLost;

  static PortalScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<PortalScope>();
  }

  static void notifyMutation(BuildContext context) {
    context
        .getInheritedWidgetOfExactType<PortalScope>()
        ?.notifier
        ?.notifyMutation();
  }

  static void reportIfSessionAuthorizationLost(
    BuildContext context,
    Object error,
  ) {
    if (PortalErrorClassifier.isSessionAuthorizationError(error)) {
      context
          .getInheritedWidgetOfExactType<PortalScope>()
          ?.onAuthorizationLost(error);
    }
  }
}

/// Non-blocking refresh indicator rendered above preserved Portal data.
class PortalRefreshStrip extends StatelessWidget {
  const PortalRefreshStrip({super.key, required this.refreshing});

  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    if (!refreshing) return const SizedBox.shrink();
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: LinearProgressIndicator(
          minHeight: 3,
          value: disableAnimations ? 0.5 : null,
          color: PortalColors.brandRed,
          backgroundColor: PortalColors.brandRedSoft,
        ),
      ),
    );
  }
}

/// Non-destructive inline error banner displayed above retained valid data
/// when a background refresh encounters a transient or operational error.
class PortalInlineErrorBanner extends StatelessWidget {
  const PortalInlineErrorBanner({
    super.key,
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: PortalColors.alertBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PortalColors.brandRed.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 18,
            color: PortalColors.alertFg,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: PortalColors.alertFg,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ],
      ),
    );
  }
}

abstract final class PortalColors {
  static const brandRed = Color(0xFFE92B32);
  static const brandRedDark = Color(0xFFB91C22);
  static const brandRedSoft = Color(0xFFFDEBED);
  static const background = Color(0xFFF1F3F7);
  static const surface = Colors.white;
  static const border = Color(0xFFE2E6EE);
  static const inkPrimary = Color(0xFF15181E);
  static const inkSecondary = Color(0xFF4B5262);
  static const verifiedBg = Color(0xFFE8F6EE);
  static const verifiedFg = Color(0xFF146C43);
  static const registeredBg = Color(0xFFFFF4E5);
  static const registeredFg = Color(0xFF9A5B00);
  static const disabledBg = Color(0xFFECEFF4);
  static const disabledFg = Color(0xFF475061);
  static const alertBg = Color(0xFFFDEBED);
  static const alertFg = Color(0xFFB42318);
}

ThemeData buildResQMePortalTheme() {
  final base = ResQMeTheme.light;
  final scheme = base.colorScheme.copyWith(
    primary: PortalColors.brandRed,
    onPrimary: Colors.white,
    primaryContainer: PortalColors.brandRedSoft,
    onPrimaryContainer: PortalColors.brandRedDark,
    secondary: PortalColors.inkPrimary,
    onSecondary: Colors.white,
    secondaryContainer: PortalColors.brandRedSoft,
    onSecondaryContainer: PortalColors.brandRedDark,
    surface: PortalColors.surface,
    onSurface: PortalColors.inkPrimary,
    surfaceContainerLow: PortalColors.surface,
    surfaceContainerHighest: PortalColors.background,
    outline: PortalColors.border,
    outlineVariant: PortalColors.border,
  );

  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: PortalColors.background,
    dividerColor: PortalColors.border,
    appBarTheme: AppBarTheme(
      backgroundColor: PortalColors.surface,
      foregroundColor: PortalColors.inkPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: false,
      titleTextStyle: base.textTheme.titleMedium?.copyWith(
        color: PortalColors.inkPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
    ),
    cardTheme: CardThemeData(
      color: PortalColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: PortalColors.border),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: PortalColors.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: PortalColors.brandRedSoft,
      elevation: 2,
      height: 74,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: PortalColors.brandRed, size: 22);
        }
        return const IconThemeData(color: PortalColors.inkSecondary, size: 22);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return base.textTheme.labelSmall?.copyWith(
            color: PortalColors.brandRed,
            fontSize: 11,
            height: 1.15,
            fontWeight: FontWeight.w700,
          );
        }
        return base.textTheme.labelSmall?.copyWith(
          color: PortalColors.inkSecondary,
          fontSize: 11,
          height: 1.15,
          fontWeight: FontWeight.w500,
        );
      }),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: PortalColors.brandRed,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: base.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 14.5,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: PortalColors.inkPrimary,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        side: const BorderSide(color: PortalColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: base.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: PortalColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: PortalColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: PortalColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: PortalColors.brandRed, width: 1.5),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: PortalColors.surface,
      selectedColor: PortalColors.brandRedSoft,
      side: const BorderSide(color: PortalColors.border),
      labelStyle: base.textTheme.labelMedium?.copyWith(
        color: PortalColors.inkPrimary,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}

class PortalSectionHeader extends StatelessWidget {
  const PortalSectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: PortalColors.inkPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: PortalColors.inkSecondary,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing!,
        ],
      ],
    );
  }
}

class PortalStatCard extends StatelessWidget {
  const PortalStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
    this.accentRed = false,
  });

  final String label;
  final String value;
  final String caption;
  final IconData icon;
  final bool accentRed;

  @override
  Widget build(BuildContext context) {
    final accent = accentRed ? PortalColors.brandRed : PortalColors.inkPrimary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: accentRed
                        ? PortalColors.brandRedSoft
                        : PortalColors.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: accentRed
                        ? PortalColors.brandRed
                        : PortalColors.inkSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      color: PortalColors.inkSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: accent,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              caption,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                color: PortalColors.inkSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum PortalBadgeTone { verified, registered, neutral, alert }

class PortalStatusBadge extends StatelessWidget {
  const PortalStatusBadge({
    super.key,
    required this.label,
    required this.tone,
  });

  factory PortalStatusBadge.forStudentCategory(String category) {
    return switch (category) {
      'verified' => const PortalStatusBadge(
          label: 'Verified',
          tone: PortalBadgeTone.verified,
        ),
      'disabled' => const PortalStatusBadge(
          label: 'Disabled',
          tone: PortalBadgeTone.neutral,
        ),
      _ => const PortalStatusBadge(
          label: 'Registered',
          tone: PortalBadgeTone.registered,
        ),
    };
  }

  factory PortalStatusBadge.forRosterState(String state) {
    return switch (state) {
      'verified' => const PortalStatusBadge(
          label: 'Verified',
          tone: PortalBadgeTone.verified,
        ),
      'registered' => const PortalStatusBadge(
          label: 'Registered',
          tone: PortalBadgeTone.registered,
        ),
      _ => const PortalStatusBadge(
          label: 'Not Registered',
          tone: PortalBadgeTone.neutral,
        ),
    };
  }

  final String label;
  final PortalBadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      PortalBadgeTone.verified => (
          PortalColors.verifiedBg,
          PortalColors.verifiedFg,
        ),
      PortalBadgeTone.registered => (
          PortalColors.registeredBg,
          PortalColors.registeredFg,
        ),
      PortalBadgeTone.alert => (
          PortalColors.alertBg,
          PortalColors.alertFg,
        ),
      PortalBadgeTone.neutral => (
          PortalColors.disabledBg,
          PortalColors.disabledFg,
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class PortalStateView extends StatelessWidget {
  const PortalStateView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.retryLabel,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? retryLabel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: PortalColors.brandRedSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: PortalColors.brandRed, size: 24),
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: PortalColors.inkPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: PortalColors.inkSecondary,
                    height: 1.4,
                  ),
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: Text(retryLabel ?? 'Retry'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PortalBrandMark extends StatelessWidget {
  const PortalBrandMark({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: PortalColors.brandRed,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.health_and_safety,
        color: Colors.white,
        size: size * 0.62,
      ),
    );
  }
}

/// Protected LRN display row implementing 2-layer security:
/// - Layer 1: Displays only the server-masked LRN (`XXXX••••XXXX`) by default.
/// - Layer 2: Requires step-up verification (Hardware Biometrics OR Master Admin
///   Password) to temporarily reveal the full 12-digit LRN, enables FLAG_SECURE
///   against screenshots while revealed, and auto-hides after 30 seconds or when
///   backgrounded.
class PortalProtectedLrnRow extends StatefulWidget {
  const PortalProtectedLrnRow({
    super.key,
    required this.maskedLrn,
    required this.hasLrn,
    required this.targetType,
    required this.targetId,
    required this.studentLabel,
    required this.portalStudentRepository,
    this.labelWidth = 148,
  });

  final String? maskedLrn;
  final bool hasLrn;
  final String targetType; // 'student' | 'roster'
  final String targetId;
  final String studentLabel;
  final PortalStudentRepository portalStudentRepository;
  final double labelWidth;

  @override
  State<PortalProtectedLrnRow> createState() => _PortalProtectedLrnRowState();
}

class _PortalProtectedLrnRowState extends State<PortalProtectedLrnRow>
    with WidgetsBindingObserver {
  String? _revealedLrn;
  Timer? _autoHideTimer;
  int _revealGeneration = 0;
  bool _isBackgrounded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant PortalProtectedLrnRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetId != widget.targetId ||
        oldWidget.targetType != widget.targetType) {
      _revealGeneration++;
      _hideLrn();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _isBackgrounded = false;
    } else {
      _isBackgrounded = true;
      _revealGeneration++;
      if (_revealedLrn != null) {
        _hideLrn();
      }
    }
  }

  @override
  void dispose() {
    _revealGeneration++;
    _autoHideTimer?.cancel();
    if (_revealedLrn != null) {
      widget.portalStudentRepository.setSecureScreen(false);
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _hideLrn() {
    _revealGeneration++;
    _autoHideTimer?.cancel();
    _autoHideTimer = null;
    widget.portalStudentRepository.setSecureScreen(false);
    if (mounted) {
      setState(() => _revealedLrn = null);
    } else {
      _revealedLrn = null;
    }
  }

  Future<void> _promptReveal() async {
    final gen = ++_revealGeneration;
    final startUid = widget.portalStudentRepository.currentAdminUid;
    final revealed = await showDialog<String>(
      context: context,
      builder: (_) => _PortalLrnStepUpDialog(
        studentLabel: widget.studentLabel,
        maskedLrn: widget.maskedLrn ?? '••••',
        targetType: widget.targetType,
        targetId: widget.targetId,
        portalStudentRepository: widget.portalStudentRepository,
      ),
    );
    if (revealed == null ||
        !mounted ||
        _isBackgrounded ||
        gen != _revealGeneration ||
        widget.portalStudentRepository.currentAdminUid != startUid) {
      return;
    }
    await widget.portalStudentRepository.setSecureScreen(true);
    if (!mounted ||
        _isBackgrounded ||
        gen != _revealGeneration ||
        widget.portalStudentRepository.currentAdminUid != startUid) {
      await widget.portalStudentRepository.setSecureScreen(false);
      return;
    }
    _autoHideTimer?.cancel();
    setState(() => _revealedLrn = revealed);
    _autoHideTimer = Timer(const Duration(seconds: 30), _hideLrn);
  }

  @override
  Widget build(BuildContext context) {
    final isRevealed = _revealedLrn != null;
    final displayValue = isRevealed
        ? _revealedLrn!
        : (widget.maskedLrn ?? 'Not recorded');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: widget.labelWidth,
            child: const Text(
              'LRN',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: PortalColors.inkSecondary,
              ),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  displayValue,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: isRevealed ? 0.5 : 0.3,
                    color: PortalColors.inkPrimary,
                  ),
                ),
                if (widget.hasLrn)
                  isRevealed
                      ? InkWell(
                          key: const Key('hide-lrn-button'),
                          borderRadius: BorderRadius.circular(8),
                          onTap: _hideLrn,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: PortalColors.brandRedSoft,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.visibility_off_outlined,
                                  size: 14,
                                  color: PortalColors.brandRed,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Hide (30s)',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: PortalColors.brandRed,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : InkWell(
                          key: const Key('reveal-lrn-button'),
                          borderRadius: BorderRadius.circular(8),
                          onTap: _promptReveal,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: PortalColors.background,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: PortalColors.border),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.lock_outline,
                                  size: 14,
                                  color: PortalColors.inkPrimary,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Reveal',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: PortalColors.inkPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PortalLrnStepUpDialog extends StatefulWidget {
  const _PortalLrnStepUpDialog({
    required this.studentLabel,
    required this.maskedLrn,
    required this.targetType,
    required this.targetId,
    required this.portalStudentRepository,
  });

  final String studentLabel;
  final String maskedLrn;
  final String targetType;
  final String targetId;
  final PortalStudentRepository portalStudentRepository;

  @override
  State<_PortalLrnStepUpDialog> createState() => _PortalLrnStepUpDialogState();
}

class _PortalLrnStepUpDialogState extends State<_PortalLrnStepUpDialog> {
  final _passwordController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _verifyWithBiometrics() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final lrn = await widget.portalStudentRepository.revealLrnWithBiometric(
        targetType: widget.targetType,
        targetId: widget.targetId,
      );
      if (!mounted) return;
      Navigator.of(context).pop(lrn);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is PortalStudentException
            ? error.message
            : 'Biometric verification could not complete.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyWithPassword() async {
    if (_busy) return;
    final pw = _passwordController.text;
    if (pw.isEmpty) {
      setState(() => _error = 'Enter your Master Admin password.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final lrn = await widget.portalStudentRepository.revealLrnWithPassword(
        targetType: widget.targetType,
        targetId: widget.targetId,
        password: pw,
      );
      if (!mounted) return;
      Navigator.of(context).pop(lrn);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is PortalStudentException
            ? error.message
            : 'Admin password verification failed.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Verify Admin Identity'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Full LRNs are protected with 2-layer security to prevent unauthorized viewing or data theft.\n\n'
              'Student: ${widget.studentLabel} (${widget.maskedLrn})',
              style: const TextStyle(
                fontSize: 13,
                color: PortalColors.inkSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('reveal-lrn-biometric-button'),
              onPressed: _busy ? null : _verifyWithBiometrics,
              icon: const Icon(Icons.fingerprint),
              label: const Text('Verify with Biometrics'),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'OR USE PASSWORD',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: PortalColors.inkSecondary,
                      ),
                    ),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
            ),
            TextField(
              key: const Key('reveal-lrn-password-input'),
              controller: _passwordController,
              enabled: !_busy,
              obscureText: true,
              onSubmitted: (_) => _verifyWithPassword(),
              decoration: const InputDecoration(
                labelText: 'Master Admin password',
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              key: const Key('reveal-lrn-password-button'),
              onPressed: _busy ? null : _verifyWithPassword,
              icon: const Icon(Icons.lock_open_outlined, size: 18),
              label: const Text('Verify with Password'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: PortalColors.alertBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: PortalColors.alertFg,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
