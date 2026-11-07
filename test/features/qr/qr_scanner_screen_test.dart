import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:resqme/features/qr/presentation/qr_scanner_screen.dart';

void main() {
  group('QrScannerScreen', () {
    testWidgets('renders app bar, viewfinder, and instructional text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: QrScannerScreen(),
        ),
      );

      // Verify header and instructional prompt
      expect(find.text('Scan QR'), findsOneWidget);
      expect(
        find.text('Point camera at a ResQMe emergency QR code'),
        findsOneWidget,
      );

      // Verify action buttons
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.byIcon(Icons.flash_off), findsOneWidget);
    });

    testWidgets('back button pops current route', (tester) async {
      var didPop = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Navigator(
            onDidRemovePage: (page) => didPop = true,
            pages: const [
              MaterialPage<void>(child: Scaffold(body: Text('Dashboard'))),
              MaterialPage<void>(child: QrScannerScreen()),
            ],
          ),
        ),
      );

      expect(find.text('Scan QR'), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(didPop, isTrue);
    });

    testWidgets('barcode detection opens unverified modal and Scan Again resumes scanning', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: QrScannerScreen(),
        ),
      );

      final state = tester.state<QrScannerScreenState>(find.byType(QrScannerScreen));
      expect(state.isModalOpen, isFalse);

      // Simulate scanning a valid ResQMe QR
      const validPayload = 'resqme:v1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
      state.handleBarcodeDetected(
        const BarcodeCapture(
          barcodes: [Barcode(rawValue: validPayload)],
        ),
      );
      await tester.pumpAndSettle();

      expect(state.isModalOpen, isTrue);
      expect(find.text('RESQME QR FORMAT RECOGNIZED'), findsOneWidget);
      expect(find.text('UNVERIFIED — TEST PILOT ONLY'), findsOneWidget);

      // Simulate duplicate detection event while modal is open - should be ignored
      state.handleBarcodeDetected(
        const BarcodeCapture(
          barcodes: [Barcode(rawValue: validPayload)],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('RESQME QR FORMAT RECOGNIZED'), findsOneWidget);

      // Tap "Scan Again"
      await tester.tap(find.text('Scan Again'));
      await tester.pumpAndSettle();

      expect(state.isModalOpen, isFalse);
      expect(find.text('RESQME QR FORMAT RECOGNIZED'), findsNothing);

      // Now verify we can scan the exact same QR code again repeatedly
      state.handleBarcodeDetected(
        const BarcodeCapture(
          barcodes: [Barcode(rawValue: validPayload)],
        ),
      );
      await tester.pumpAndSettle();

      expect(state.isModalOpen, isTrue);
      expect(find.text('RESQME QR FORMAT RECOGNIZED'), findsOneWidget);
    });

    testWidgets('invalid barcode detection opens unrecognized modal', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: QrScannerScreen(),
        ),
      );

      final state = tester.state<QrScannerScreenState>(find.byType(QrScannerScreen));

      // Simulate scanning an invalid barcode
      state.handleBarcodeDetected(
        const BarcodeCapture(
          barcodes: [Barcode(rawValue: 'https://malicious.link/not-resqme')],
        ),
      );
      await tester.pumpAndSettle();

      expect(state.isModalOpen, isTrue);
      expect(find.text('UNRECOGNIZED QR CODE'), findsOneWidget);
      expect(find.text('Invalid format'), findsOneWidget);
      expect(find.text('This QR code does not match the ResQMe format.'), findsOneWidget);

      await tester.tap(find.text('Scan Again'));
      await tester.pumpAndSettle();

      expect(state.isModalOpen, isFalse);
    });

    testWidgets('pauses on background lifecycle transition and resumes on foreground', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: QrScannerScreen(),
        ),
      );

      final state = tester.state<QrScannerScreenState>(find.byType(QrScannerScreen));

      // Simulate background transition
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      // Simulate foreground return
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(state.isModalOpen, isFalse);
    });
  });
}
