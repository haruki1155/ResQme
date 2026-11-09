import 'package:flutter/services.dart';

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
}
