import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqme/features/qr/domain/qr_payload_parser.dart';
import 'package:resqme/features/qr/presentation/unverified_qr_modal.dart';

void main() {
  group('UnverifiedQrModal', () {
    testWidgets('displays exact required text for ValidResQMeQr without PII', (tester) async {
      var scanAgainTapped = false;
      var dashboardTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UnverifiedQrModal(
              result: const ValidResQMeQr(),
              onScanAgain: () => scanAgainTapped = true,
              onDashboard: () => dashboardTapped = true,
            ),
          ),
        ),
      );

      // Verify exact titles and required copy
      expect(find.text('RESQME QR FORMAT RECOGNIZED'), findsOneWidget);
      expect(find.text('UNVERIFIED — TEST PILOT ONLY'), findsOneWidget);
      expect(
        find.text(
          'This QR code matches the ResQMe format, but its identity and status have not been verified.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'No personal identification, medical records, or Tier 2 emergency data are accessible offline.',
        ),
        findsOneWidget,
      );

      // Verify no verification claims or PII
      expect(find.textContaining('Verified Student'), findsNothing);
      expect(find.textContaining('Medical Record'), findsNothing);
      expect(find.textContaining('resqme:v1'), findsNothing);

      // Verify buttons
      await tester.tap(find.text('Scan Again'));
      expect(scanAgainTapped, isTrue);

      await tester.tap(find.text('Back to Dashboard'));
      expect(dashboardTapped, isTrue);
    });

    testWidgets('displays unrecognized format copy for InvalidQr', (tester) async {
      var scanAgainTapped = false;
      var dashboardTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UnverifiedQrModal(
              result: const InvalidQr(reason: 'Malformed encoding.'),
              onScanAgain: () => scanAgainTapped = true,
              onDashboard: () => dashboardTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('UNRECOGNIZED QR CODE'), findsOneWidget);
      expect(find.text('Invalid format'), findsOneWidget);
      expect(
        find.text('This QR code does not match the ResQMe format.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Scan Again'));
      expect(scanAgainTapped, isTrue);

      await tester.tap(find.text('Back to Dashboard'));
      expect(dashboardTapped, isTrue);
    });
  });
}
