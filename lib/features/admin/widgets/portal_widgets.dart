import 'package:flutter/material.dart';
import '../../../app/resqme_theme.dart';

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
