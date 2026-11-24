import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqme/features/admin/screens/staff_device_setup_screen.dart';
import 'package:resqme/features/admin/screens/staff_tier2_result_screen.dart';
import 'package:resqme/features/admin/screens/staff_tier2_scanner_screen.dart';
import 'package:resqme/features/admin/services/staff_tier2_repository.dart';

class FakeStaffTier2Client implements StaffTier2Client {
  String? uid = 'staff-uid-1';
  final StreamController<String?> _uids = StreamController<String?>.broadcast();
  final List<bool> secureScreenCalls = [];
  int readCalls = 0;
  int enrollCalls = 0;
  Completer<Map<String, dynamic>>? pendingRead;
  Object? readError;
  Object? enrollError;

  @override
  String? get currentUid => uid;

  @override
  Stream<String?> get uidChanges => _uids.stream;

  void switchUid(String? next) {
    uid = next;
    _uids.add(next);
  }

  @override
  Future<void> enrollDeviceWithPassword(String password) async {
    enrollCalls++;
    if (enrollError != null) throw enrollError!;
  }

  @override
  Future<void> revokeDeviceWithPassword(String password) async {}

  @override
  Future<Map<String, dynamic>> readStudentTier2({
    required String qrPayload,
    required String purpose,
  }) async {
    readCalls++;
    if (readError != null) throw readError!;
    if (pendingRead != null) return pendingRead!.future;
    return {
      'conditions': {'state': 'listed', 'details': 'Fictional asthma'},
      'allergies': {'state': 'none_known', 'details': null},
      'primaryContact': {
        'fullName': 'Fictional Guardian',
        'relationship': 'Parent',
        'phoneNumber': '09170000001',
      },
    };
  }

  @override
  Future<void> setSecureScreen(bool enabled) async {
    secureScreenCalls.add(enabled);
  }

  Future<void> close() => _uids.close();
}

const _sampleRecord = <String, dynamic>{
  'conditions': {'state': 'listed', 'details': 'Fictional asthma'},
  'allergies': {'state': 'none_known', 'details': null},
  'primaryContact': {
    'fullName': 'Fictional Guardian',
    'relationship': 'Parent',
    'phoneNumber': '09170000001',
  },
};

void main() {
  testWidgets('one scan triggers one challenge and shows no record before biometric proof', (tester) async {
    final client = FakeStaffTier2Client()..pendingRead = Completer<Map<String, dynamic>>();
    addTearDown(client.close);
    ValueChanged<String>? triggerScan;

    await tester.pumpWidget(
      MaterialApp(
        home: StaffTier2ScannerScreen(
          client: client,
          scannerBuilder: (onValidQr) {
            triggerScan = onValidQr;
            return const SizedBox(height: 120, child: Text('Test scanner'));
          },
        ),
      ),
    );

    triggerScan!('resqme:v1:${'A' * 43}');
    triggerScan!('resqme:v1:${'A' * 43}');
    await tester.pump();

    expect(client.readCalls, 1);
    expect(find.text('Fictional asthma'), findsNothing);

    client.pendingRead!.complete(_sampleRecord);
    await tester.pumpAndSettle();

    expect(find.text('Fictional asthma'), findsOneWidget);
    expect(find.text('Fictional Guardian'), findsOneWidget);
    expect(client.secureScreenCalls, contains(true));
  });

  testWidgets('biometric cancel or lockout never displays medical data and has no password fallback', (tester) async {
    final client = FakeStaffTier2Client()
      ..readError = const StaffTier2Failure('Biometric confirmation cancelled.');
    addTearDown(client.close);
    ValueChanged<String>? triggerScan;

    await tester.pumpWidget(
      MaterialApp(
        home: StaffTier2ScannerScreen(
          client: client,
          scannerBuilder: (onValidQr) {
            triggerScan = onValidQr;
            return const SizedBox(height: 120, child: Text('Test scanner'));
          },
        ),
      ),
    );

    triggerScan!('resqme:v1:${'B' * 43}');
    await tester.pumpAndSettle();

    expect(find.text('Fictional asthma'), findsNothing);
    expect(find.textContaining('Biometric confirmation cancelled'), findsOneWidget);
    expect(find.textContaining('password'), findsNothing);

    // Subsequent scan after failure must be allowed (scanner resets cleanly)
    client.readError = null;
    triggerScan!('resqme:v1:${'B' * 43}');
    await tester.pumpAndSettle();
    expect(client.readCalls, 2);
    expect(find.text('Fictional asthma'), findsOneWidget);
  });

  testWidgets('late response after background or account switch is ignored', (tester) async {
    final client = FakeStaffTier2Client()..pendingRead = Completer<Map<String, dynamic>>();
    addTearDown(client.close);
    ValueChanged<String>? triggerScan;

    await tester.pumpWidget(
      MaterialApp(
        home: StaffTier2ScannerScreen(
          client: client,
          scannerBuilder: (onValidQr) {
            triggerScan = onValidQr;
            return const SizedBox(height: 120, child: Text('Test scanner'));
          },
        ),
      ),
    );

    triggerScan!('resqme:v1:${'C' * 43}');
    await tester.pump();
    client.switchUid('other-staff');
    await tester.pump();

    client.pendingRead!.complete(_sampleRecord);
    await tester.pumpAndSettle();
    expect(find.text('Fictional asthma'), findsNothing);
  });

  testWidgets('protected result clears on TTL expiry, background, account switch, and lock', (tester) async {
    final client = FakeStaffTier2Client();
    addTearDown(client.close);

    // 1. TTL expiry
    await tester.pumpWidget(
      MaterialApp(
        home: StaffTier2ResultScreen(
          record: _sampleRecord,
          client: client,
          displayTtl: const Duration(seconds: 2),
        ),
      ),
    );
    expect(find.text('Fictional asthma'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Fictional asthma'), findsNothing);
    expect(find.textContaining('locked'), findsOneWidget);

    // 2. App background
    await tester.pumpWidget(
      MaterialApp(
        key: const ValueKey('bg'),
        home: StaffTier2ResultScreen(
          record: _sampleRecord,
          client: client,
          displayTtl: const Duration(seconds: 120),
        ),
      ),
    );
    expect(find.text('Fictional asthma'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    expect(find.text('Fictional asthma'), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    // 3. Account switch
    await tester.pumpWidget(
      MaterialApp(
        key: const ValueKey('acct'),
        home: StaffTier2ResultScreen(
          record: _sampleRecord,
          client: client,
          displayTtl: const Duration(seconds: 120),
        ),
      ),
    );
    expect(find.text('Fictional asthma'), findsOneWidget);
    client.switchUid(null);
    await tester.pump();
    expect(find.text('Fictional asthma'), findsNothing);
    expect(client.secureScreenCalls, contains(false));
  });

  test('mapStaffTier2Error produces actionable errors for biometric hardware, missing enrollment, key invalidation, and v2 re-enrollment', () {
    expect(
      mapStaffTier2Error(PlatformException(code: 'biometric_not_enrolled')).message,
      contains('Enroll a fingerprint in Android Settings'),
    );
    expect(
      mapStaffTier2Error(PlatformException(code: 'biometric_unsupported')).message,
      contains('Strong hardware-backed biometrics are unavailable'),
    );
    expect(
      mapStaffTier2Error(PlatformException(code: 'key_invalidated')).message,
      contains('Biometric enrollment changed'),
    );
    expect(
      mapStaffTier2Error(
        FirebaseFunctionsException(
          code: 'failed-precondition',
          message: 'Biometric device re-enrollment is required.',
        ),
      ).message,
      contains('Re-enroll this device'),
    );
  });

  testWidgets('StaffDeviceSetupScreen never shows success when biometric prompt is cancelled or hardware is unsupported', (tester) async {
    final client = FakeStaffTier2Client()
      ..enrollError = const StaffTier2Failure('Biometric confirmation cancelled.');
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(home: StaffDeviceSetupScreen(client: client)),
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Confirm staff account password'),
      'Strong!Pass2026',
    );
    await tester.tap(find.text('Enroll this device'));
    await tester.pumpAndSettle();

    expect(find.text('Trusted staff device enrolled.'), findsNothing);
    expect(find.textContaining('Biometric confirmation cancelled'), findsOneWidget);

    client.enrollError = const StaffTier2Failure(
      'Strong hardware-backed biometrics are unavailable on this device.',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Confirm staff account password'),
      'Strong!Pass2026',
    );
    await tester.tap(find.text('Enroll this device'));
    await tester.pumpAndSettle();

    expect(find.text('Trusted staff device enrolled.'), findsNothing);
    expect(
      find.textContaining('Strong hardware-backed biometrics are unavailable'),
      findsOneWidget,
    );
  });
}
