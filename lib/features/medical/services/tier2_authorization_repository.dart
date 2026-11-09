import 'dart:convert';
import 'dart:math';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'platform_tier2_key.dart';

class Tier2AuthorizationFailure implements Exception {
  const Tier2AuthorizationFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class Tier2AuthorizationRepository {
  Tier2AuthorizationRepository({
    required this.auth,
    required this.functions,
    required this.keyProvider,
    required String expectedProjectId,
  }) {
    if (!['demo-resqme', 'resqme-943ee'].contains(expectedProjectId) ||
        auth.app.options.projectId != expectedProjectId ||
        functions.app.options.projectId != expectedProjectId ||
        auth.app.name != functions.app.name) {
      throw StateError('Unexpected Tier 2 Firebase app.');
    }
  }
  final FirebaseAuth auth;
  final FirebaseFunctions functions;
  final PlatformTier2Key keyProvider;
  String? get currentUid => auth.currentUser?.uid;

  String _newDeviceId() => base64Url
      .encode(List<int>.generate(24, (_) => Random.secure().nextInt(256)))
      .replaceAll('=', '');
  Future<String> _deviceId(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'resqme-tier2-device-$uid';
    var value = prefs.getString(key);
    if (value == null || !RegExp(r'^[A-Za-z0-9_-]{20,80}$').hasMatch(value)) {
      value = _newDeviceId();
      await prefs.setString(key, value);
    }
    return value;
  }

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> data,
  ) async {
    final user = auth.currentUser;
    if (user == null) {
      throw const Tier2AuthorizationFailure('Sign in to access Tier 2.');
    }
    final result = await functions
        .httpsCallable(
          name,
          options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
        )
        .call<dynamic>(data);
    if (auth.currentUser?.uid != user.uid || result.data is! Map) {
      throw const Tier2AuthorizationFailure('Account changed. Reopen Tier 2.');
    }
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<Map<String, dynamic>> _readWithDevice(
    String uid,
    String deviceId,
  ) async {
    final challenge = await _call('issueTier2Challenge', {
      'deviceId': deviceId,
      'operation': 'read_medical',
    });
    if (challenge['challengeId'] is! String ||
        challenge['nonce'] is! String ||
        challenge['deviceId'] != deviceId ||
        challenge['operation'] != 'read_medical') {
      throw const Tier2AuthorizationFailure('Tier 2 challenge is invalid.');
    }
    final message =
        '$uid\n$deviceId\nread_medical\n${challenge['challengeId']}\n${challenge['nonce']}';
    final signature = await keyProvider.sign(deviceId, message);
    return _call('readMyTier2Record', {
      'challengeId': challenge['challengeId'],
      'deviceId': deviceId,
      'signature': signature,
    });
  }

  Future<Map<String, dynamic>> readWithBiometrics() async {
    final uid = currentUid;
    if (uid == null) {
      throw const Tier2AuthorizationFailure('Sign in to access Tier 2.');
    }
    try {
      return await _readWithDevice(uid, await _deviceId(uid));
    } catch (_) {
      throw const Tier2AuthorizationFailure(
        'Biometric access is unavailable. Use your account password to continue.',
      );
    }
  }

  Future<Map<String, dynamic>> enrollWithPassword(String password) async {
    final user = auth.currentUser;
    if (user == null || user.email == null || password.isEmpty) {
      throw const Tier2AuthorizationFailure('Enter your account password.');
    }
    final uid = user.uid;
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: user.email!, password: password),
      );
      await user.getIdToken(true);
      final deviceId = await _deviceId(uid);
      await keyProvider.deleteKey(deviceId);
      final publicKey = await keyProvider.createKey(deviceId);
      await _call('enrollTier2Device', {
        'deviceId': deviceId,
        'publicKey': publicKey,
      });
      return await _readWithDevice(uid, deviceId);
    } catch (_) {
      throw const Tier2AuthorizationFailure(
        'Password or biometric verification failed. Check your password and try again.',
      );
    }
  }

  Future<Map<String, dynamic>> readWithPassword(String password) async {
    final user = auth.currentUser;
    if (user == null || user.email == null || password.isEmpty) {
      throw const Tier2AuthorizationFailure('Enter your account password.');
    }
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: user.email!, password: password),
      );
      await user.getIdToken(true);
      return await _call('readMyTier2WithPassword', {});
    } catch (error) {
      if (error is FirebaseFunctionsException &&
          error.code == 'resource-exhausted') {
        throw const Tier2AuthorizationFailure(
          'Too many Tier 2 attempts. Try again later.',
        );
      }
      throw const Tier2AuthorizationFailure(
        'Password verification failed. Check your password and try again.',
      );
    }
  }

  Future<void> revokeDeviceWithPassword(String password) async {
    final user = auth.currentUser;
    if (user == null || user.email == null || password.isEmpty) {
      throw const Tier2AuthorizationFailure('Enter your account password.');
    }
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: user.email!, password: password),
      );
      await user.getIdToken(true);
      await _call('revokeMyTier2Device', {});
      await deleteLocalDeviceKey();
    } catch (_) {
      throw const Tier2AuthorizationFailure(
        'Unable to disable biometric access. Check your account password and retry.',
      );
    }
  }

  Future<void> deleteLocalDeviceKey() async {
    final uid = currentUid;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    final key = 'resqme-tier2-device-$uid';
    final id = prefs.getString(key);
    if (id != null) await keyProvider.deleteKey(id);
    await prefs.remove(key);
  }
}
