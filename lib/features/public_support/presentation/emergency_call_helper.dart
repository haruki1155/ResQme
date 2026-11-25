import 'package:flutter/material.dart';
import 'package:resqme/app/app_routes.dart';
import 'package:resqme/features/public_support/presentation/emergency_hotlines_screen.dart';
import 'package:url_launcher/url_launcher.dart';

typedef EmergencyDialerOpener = Future<bool> Function(Uri uri);

/// Shared, confirmation-gated emergency calling and hotlines navigation helper.
///
/// Reuses the verified Philippine National Emergency Hotline (`911`) and never
/// places a phone call automatically without user confirmation.
class EmergencyCallHelper {
  const EmergencyCallHelper._();

  static const String nationalEmergencyName = 'National Emergency Hotline';
  static const String nationalEmergencyNumber = '911';

  static Future<void> confirmAndOpen911(
    BuildContext context, {
    EmergencyDialerOpener? openDialer,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Open Phone?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(nationalEmergencyName),
              const SizedBox(height: 12),
              Text(
                nationalEmergencyNumber,
                style: Theme.of(dialogContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              const Text(
                'No call is placed automatically. The number will be filled in the Phone app. Tap Call there only when you intend to call.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Open Phone'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    final uri = Uri(scheme: 'tel', path: nationalEmergencyNumber);
    var opened = false;
    try {
      opened =
          await (openDialer?.call(uri) ??
              launchUrl(uri, mode: LaunchMode.externalApplication));
    } catch (_) {
      opened = false;
    }
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to open the Phone app. You can dial 911 or Red Cross 143 manually.',
          ),
        ),
      );
    }
  }

  static void openHotlinesDirectory(
    BuildContext context, {
    EmergencyDialerOpener? openDialer,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: AppRoutes.hotlines),
        builder: (_) => EmergencyHotlinesScreen(openDialer: openDialer),
      ),
    );
  }
}
