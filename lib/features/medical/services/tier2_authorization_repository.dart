import 'dart:convert';
import 'dart:math';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
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

  Future<T> _withOwner<T>(
    Future<T> Function(String uid, void Function() check) action,
  ) async {
    final uid = currentUid;
    if (uid == null)
      throw const Tier2AuthorizationFailure('Sign in to access Tier 2.');
    var invalidated = false;
    final subscription = auth.userChanges().listen((user) {
      if (user?.uid != uid) invalidated = true;
    });
    void check() {
      if (invalidated || currentUid != uid) {
        throw const Tier2AuthorizationFailure(
          'Account changed. Reopen Tier 2.',
        );
      }
    }

    try {
      check();
      final result = await action(uid, check);
      check();
      return result;
    } catch (error) {
      check();
      throw _failure(error);
    } finally {
      await subscription.cancel();
    }
  }

  Tier2AuthorizationFailure _failure(Object error) {
    if (error is Tier2AuthorizationFailure) return error;
    if (error is PlatformException) {
      return Tier2AuthorizationFailure(switch (error.code) {
        'cancelled' => 'Biometric confirmation cancelled.',
        'biometric_lockout' =>
          'Biometrics are locked. Use your account password to continue.',
        'key_unavailable' =>
          'Set up biometrics again using your account password.',
        'sign_failed' =>
          'Biometric verification failed. Try again or use your account password.',
        _ =>
          'Biometric access is unavailable. Use your account password to continue.',
      });
    }
    if (error is FirebaseFunctionsException) {
      return Tier2AuthorizationFailure(switch (error.code) {
        'resource-exhausted' => 'Too many Tier 2 attempts. Try again later.',
        'failed-precondition' ||
        'unauthenticated' => 'Please reauthenticate to access Tier 2.',
        'permission-denied' => 'Tier 2 access is unavailable for this account.',
        _ => 'Tier 2 could not be reached. Try again later.',
      });
    }
    if (error is FirebaseAuthException) {
      return Tier2AuthorizationFailure(switch (error.code) {
        'wrong-password' ||
        'invalid-credential' ||
        'invalid-login-credentials' =>
          'Password verification failed. Check your password and try again.',
        'too-many-requests' => 'Too many Tier 2 attempts. Try again later.',
        'network-request-failed' =>
          'Tier 2 could not be reached. Try again later.',
        _ => 'Account verification failed. Sign in again to access Tier 2.',
      });
    }
    return const Tier2AuthorizationFailure(
      'Tier 2 access could not be verified.',
    );
  }

  String _newDeviceId() => base64Url
      .encode(List<int>.generate(24, (_) => Random.secure().nextInt(256)))
      .replaceAll('=', '');
  Future<String> _deviceId(String uid, void Function() check) async {
    final prefs = await SharedPreferences.getInstance();
    check();
    final key = 'resqme-tier2-device-$uid';
    var value = prefs.getString(key);
    if (value == null || !RegExp(r'^[A-Za-z0-9_-]{20,80}$').hasMatch(value)) {
      value = _newDeviceId();
      await prefs.setString(key, value);
      check();
    }
    return value;
  }

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> data,
    void Function() check,
  ) async {
    check();
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
    check();
    if (auth.currentUser?.uid != user.uid || result.data is! Map) {
      throw const Tier2AuthorizationFailure('Account changed. Reopen Tier 2.');
    }
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<Map<String, dynamic>> _readWithDevice(
    String uid,
    String deviceId,
    void Function() check,
  ) async {
    final challenge = await _call('issueTier2Challenge', {
      'deviceId': deviceId,
      'operation': 'read_medical',
    }, check);
    if (challenge['challengeId'] is! String ||
        challenge['nonce'] is! String ||
        challenge['deviceId'] != deviceId ||
        challenge['operation'] != 'read_medical') {
      throw const Tier2AuthorizationFailure('Tier 2 challenge is invalid.');
    }
    final message =
        '$uid\n$deviceId\nread_medical\n${challenge['challengeId']}\n${challenge['nonce']}';
    final signature = await keyProvider.sign(deviceId, message);
    check();
    return _call('readMyTier2Record', {
      'challengeId': challenge['challengeId'],
      'deviceId': deviceId,
      'signature': signature,
    }, check);
  }

  Future<Map<String, dynamic>> readWithBiometrics() =>
      _withOwner((uid, check) async {
        return _readWithDevice(uid, await _deviceId(uid, check), check);
      });

  Future<Map<String, dynamic>> enrollWithPassword(String password) =>
      _withOwner((uid, check) async {
        final user = auth.currentUser;
        if (user == null || user.email == null || password.isEmpty) {
          throw const Tier2AuthorizationFailure('Enter your account password.');
        }
        await user.reauthenticateWithCredential(
          EmailAuthProvider.credential(email: user.email!, password: password),
        );
        check();
        await user.getIdToken(true);
        check();
        final deviceId = await _deviceId(uid, check);
        await keyProvider.deleteKey(deviceId);
        check();
        final publicKey = await keyProvider.createKey(deviceId);
        check();
        await _call('enrollTier2Device', {
          'deviceId': deviceId,
          'publicKey': publicKey,
        }, check);
        return _readWithDevice(uid, deviceId, check);
      });

  Future<Map<String, dynamic>> readWithPassword(String password) =>
      _withOwner((uid, check) async {
        final user = auth.currentUser;
        if (user == null || user.email == null || password.isEmpty) {
          throw const Tier2AuthorizationFailure('Enter your account password.');
        }
        await user.reauthenticateWithCredential(
          EmailAuthProvider.credential(email: user.email!, password: password),
        );
        check();
        await user.getIdToken(true);
        check();
        return _call('readMyTier2WithPassword', {}, check);
      });

  Future<void> revokeDeviceWithPassword(String password) =>
      _withOwner((uid, check) async {
        final user = auth.currentUser;
        if (user == null || user.email == null || password.isEmpty) {
          throw const Tier2AuthorizationFailure('Enter your account password.');
        }
        await user.reauthenticateWithCredential(
          EmailAuthProvider.credential(email: user.email!, password: password),
        );
        check();
        await user.getIdToken(true);
        check();
        await _call('revokeMyTier2Device', {}, check);
        await _deleteLocalDeviceKey(uid, check);
      });

  Future<void> deleteLocalDeviceKey() async {
    if (currentUid == null) return;
    await _withOwner((uid, check) => _deleteLocalDeviceKey(uid, check));
  }

  Future<void> _deleteLocalDeviceKey(String uid, void Function() check) async {
    final prefs = await SharedPreferences.getInstance();
    check();
    final key = 'resqme-tier2-device-$uid';
    final id = prefs.getString(key);
    if (id != null) await keyProvider.deleteKey(id);
    check();
    await prefs.remove(key);
  }
}
