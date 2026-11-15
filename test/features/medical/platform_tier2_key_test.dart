import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqme/features/medical/services/platform_tier2_key.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel=MethodChannel('resqme/tier2_key');
  tearDown(()=>TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel,null));
  for(final code in ['cancelled','biometric_lockout','biometric_unavailable','key_unavailable','sign_failed']) {
    test('channel preserves $code and does not request password fallback',() async {
      final calls=<String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel,(call) async {
        calls.add(call.method); throw PlatformException(code:code);
      });
      await expectLater(PlatformTier2Key().sign('fictional-device','fictional-message'),throwsA(isA<PlatformException>().having((e)=>e.code,'code',code)));
      expect(calls,['sign']);
    });
  }
  test('channel requires a signing result',() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel,(_) async=>null);
    await expectLater(PlatformTier2Key().sign('fictional-device','fictional-message'),throwsA(isA<PlatformException>().having((e)=>e.code,'code','sign_failed')));
  });
}
