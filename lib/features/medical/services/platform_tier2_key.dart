import 'package:flutter/services.dart';

class StaffKeyEnrollment {
  const StaffKeyEnrollment({
    required this.publicKey,
    required this.attestationChain,
    required this.signature,
  });

  final String publicKey;
  final List<String> attestationChain;
  final String signature;
}

class PlatformTier2Key {
  static const _channel = MethodChannel('resqme/tier2_key');
  Future<String> createKey(String deviceId) async =>
      await _channel.invokeMethod<String>('createKey', {
        'deviceId': deviceId,
      }) ??
      (throw PlatformException(code: 'key_unavailable'));
  Future<String> sign(String deviceId, String message) async =>
      await _channel.invokeMethod<String>('sign', {
        'deviceId': deviceId,
        'message': message,
      }) ??
      (throw PlatformException(code: 'sign_failed'));
  Future<void> deleteKey(String deviceId) =>
      _channel.invokeMethod<void>('deleteKey', {'deviceId': deviceId});

  Future<StaffKeyEnrollment> createStaffKey({
    required String deviceId,
    required String challenge,
    required String message,
  }) async {
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'createStaffKey',
      {
        'deviceId': deviceId,
        'challenge': challenge,
        'message': message,
      },
    );
    final publicKey = result?['publicKey'];
    final chain = result?['attestationChain'];
    final signature = result?['signature'];
    if (publicKey is! String ||
        publicKey.isEmpty ||
        chain is! List ||
        chain.length < 2 ||
        chain.any((e) => e is! String || e.isEmpty) ||
        signature is! String ||
        signature.isEmpty) {
      throw PlatformException(code: 'sign_failed');
    }
    return StaffKeyEnrollment(
      publicKey: publicKey,
      attestationChain: List<String>.from(chain),
      signature: signature,
    );
  }

  Future<String> signStaff(String deviceId, String message) async =>
      await _channel.invokeMethod<String>('signStaff', {
        'deviceId': deviceId,
        'message': message,
      }) ??
      (throw PlatformException(code: 'sign_failed'));

  Future<void> deleteStaffKey(String deviceId) =>
      _channel.invokeMethod<void>('deleteStaffKey', {'deviceId': deviceId});

  Future<void> setSecureScreen(bool enabled) async {
    try {
      await _channel.invokeMethod<void>('setSecureScreen', {
        'enabled': enabled,
      });
    } catch (_) {
      // Ignore on unsupported platforms/tests where channel handler is absent.
    }
  }
}
