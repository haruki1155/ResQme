import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqme/features/medical/screens/student_tier2_qr_screen.dart';
import 'package:resqme/features/medical/services/tier2_authorization_repository.dart';
import 'package:resqme/features/qr/domain/qr_payload_parser.dart';
import 'package:resqme/features/qr/services/tier1_qr_repository.dart';

class _FakeTier1QrRepo implements Tier1QrRepository {
  @override
  Tier1QrCredential? get cachedCredential => const Tier1QrCredential(
        payload: 'resqme:v1:0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefg',
        verificationStatus: 'active',
      );

  @override
  String? get ownerReference => 'owner-ref-1';

  @override
  Future<Tier1QrCredential> ensureMineCredential({bool forceRefresh = false}) async =>
      cachedCredential!;

  @override
  Future<Tier1QrCredential> replaceMineCredential() async => cachedCredential!;

  @override
  Future<bool> resolveScanned(String payload) async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeTier2PresentationController implements Tier2PresentationClient {
  _FakeTier2PresentationController({
    this.status = const TrustedDeviceStatus(
      hasActiveTrustedDevice: true,
      isCurrentDeviceTrusted: true,
    ),
  });

  TrustedDeviceStatus status;
  int unlockCalls = 0;
  final List<bool> secureScreenCalls = <bool>[];
  String? currentUidValue = 'student-p4-1';

  @override
  String? get currentUid => currentUidValue;

  @override
  Future<TrustedDeviceStatus> getTrustedDeviceStatus() async => status;

  @override
  Future<Tier2PresentationToken> unlockTier2PresentationQr() async {
    unlockCalls += 1;
    return Tier2PresentationToken(
      payload: 'resqme:tier2:v1:9876543210ZYXWVUTSRQPONMLKJIHGFEDCBAabcdefg',
      expiresAt: DateTime.now().add(const Duration(seconds: 90)),
      ttlSeconds: 90,
    );
  }

  @override
  Future<void> setSecureScreen(bool enabled) async {
    secureScreenCalls.add(enabled);
  }
}

void main() {
  test(
      'Phase 4: QrPayloadParser keeps Tier 1 public parser strict while allowing Staff scanner to accept both permanent and Tier 2 presentation tokens',
      () {
    const tier1 = 'resqme:v1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
    const tier2 = 'resqme:tier2:v1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
    const login = 'resqme:login:v1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';

    expect(QrPayloadParser.parse(tier1), isA<ValidResQMeQr>());
    expect(QrPayloadParser.parse(tier2), isA<InvalidQr>());
    expect(QrPayloadParser.parse(login), isA<InvalidQr>());

    expect(QrPayloadParser.isValidStaffTier2Payload(tier1), isTrue);
    expect(QrPayloadParser.isValidStaffTier2Payload(tier2), isTrue);
    expect(QrPayloadParser.isValidStaffTier2Payload(login), isFalse);
  });

  testWidgets(
      'Phase 4: StudentTier2QrScreen starts locked, requires biometric unlock, enables FLAG_SECURE, shows zero medical text, and hides immediately on background',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final qrRepo = _FakeTier1QrRepo();
    final controller = _FakeTier2PresentationController();

    await tester.pumpWidget(
      MaterialApp(
        home: StudentTier2QrScreen(
          qrRepository: qrRepo,
          presentationClient: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Starts locked: requires biometric unlock
    expect(find.text('Unlock Protected Tier 2 QR'), findsOneWidget);
    expect(controller.unlockCalls, 0);

    await tester.tap(find.text('Unlock Protected Tier 2 QR'));
    await tester.pumpAndSettle();

    expect(controller.unlockCalls, 1);
    expect(controller.secureScreenCalls.last, isTrue);
    expect(find.textContaining('Expires in'), findsOneWidget);
    expect(find.text('Lock QR Now'), findsOneWidget);
    // Must NEVER display raw medical details or LRN
    expect(find.textContaining('asthma'), findsNothing);
    expect(find.textContaining('109876543210'), findsNothing);

    // Backgrounding immediately hides protected QR and disables FLAG_SECURE;
    // resuming keeps it locked until fresh biometric verification!
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(controller.secureScreenCalls.last, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Unlock Protected Tier 2 QR'), findsOneWidget);
    expect(find.text('Lock QR Now'), findsNothing);
  });

  testWidgets(
      'Phase 4: secondary untrusted device restricts Tier 2 QR presentation with clear guidance',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final qrRepo = _FakeTier1QrRepo();
    final secondaryController = _FakeTier2PresentationController(
      status: const TrustedDeviceStatus(
        hasActiveTrustedDevice: true,
        isCurrentDeviceTrusted: false,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StudentTier2QrScreen(
          qrRepository: qrRepo,
          presentationClient: secondaryController,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Another personal device is enrolled'),
      findsOneWidget,
    );
    expect(find.text('Unlock Protected Tier 2 QR'), findsNothing);
  });
}
