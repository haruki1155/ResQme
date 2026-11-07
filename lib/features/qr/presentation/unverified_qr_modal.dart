import 'package:flutter/material.dart';
import '../domain/qr_payload_parser.dart';

/// Modal bottom sheet presenting the local, offline result of a QR scan.
///
/// Invariant: Displays strictly unverified format-recognition results.
/// Under no circumstances displays student identity, medical data,
/// emergency contacts, Tier 2 records, raw tokens, or verification claims.
class UnverifiedQrModal extends StatelessWidget {
  const UnverifiedQrModal({
    super.key,
    required this.result,
    required this.onScanAgain,
    required this.onDashboard,
  });

  final QrScanResult result;
  final VoidCallback onScanAgain;
  final VoidCallback onDashboard;

  static Future<void> show({
    required BuildContext context,
    required QrScanResult result,
    required VoidCallback onScanAgain,
    required VoidCallback onDashboard,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => UnverifiedQrModal(
        result: result,
        onScanAgain: () {
          Navigator.of(modalContext).pop();
          onScanAgain();
        },
        onDashboard: () {
          Navigator.of(modalContext).pop();
          onDashboard();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isValid = result is ValidResQMeQr;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(
                  isValid ? Icons.qr_code_scanner : Icons.error_outline,
                  color: isValid ? const Color(0xFFE92B32) : Colors.orange.shade800,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isValid
                        ? 'RESQME QR FORMAT RECOGNIZED'
                        : 'UNRECOGNIZED QR CODE',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isValid ? const Color(0xFFFFF0F1) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isValid ? const Color(0xFFE92B32) : Colors.grey.shade400,
                  ),
                ),
                child: Text(
                  isValid
                      ? 'UNVERIFIED — TEST PILOT ONLY'
                      : 'Invalid format',
                  style: TextStyle(
                    color: isValid ? const Color(0xFFE92B32) : Colors.grey.shade800,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isValid
                  ? 'This QR code matches the ResQMe format, but its identity and status have not been verified.'
                  : 'This QR code does not match the ResQMe format.',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF2D3748),
                height: 1.4,
              ),
            ),
            if (isValid) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_outlined, size: 20, color: Color(0xFF718096)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'No personal identification, medical records, or Tier 2 emergency data are accessible offline.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF718096),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onScanAgain,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE92B32),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Scan Again',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: onDashboard,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Back to Dashboard',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
