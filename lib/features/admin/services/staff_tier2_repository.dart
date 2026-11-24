import 'dart:convert';
import 'dart:math';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../medical/services/platform_tier2_key.dart';

class StaffTier2Failure implements Exception {
  const StaffTier2Failure(this.message);
  final String message;
  @override
  String toString() => message;
}

const staffTier2Purposes = <String>[
  'emergency_response',
  'clinic_triage',
  'incident_assistance',
];

StaffTier2Failure mapStaffTier2Error(Object error) {
  if (error is StaffTier2Failure) return error;
  if (error is PlatformException) {
    return StaffTier2Failure(switch (error.code) {
      'cancelled' => 'Biometric confirmation cancelled.',
      'biometric_busy' => 'Biometric confirmation is already in progress.',
      'biometric_lockout' =>
        'Biometrics are locked on this device. Unlock device biometrics before retrying.',
      'biometric_not_enrolled' =>
        'No strong biometric (fingerprint) is enrolled on this device. Enroll a fingerprint in Android Settings first.',
      'biometric_unsupported' || 'unsupported' =>
        'Strong hardware-backed biometrics are unavailable on this device.',
      'key_invalidated' =>
        'Biometric enrollment changed on this device. Re-enroll in Biometric Device Setup.',
      'key_unavailable' =>
        'Enroll this trusted staff device with biometrics first.',
      'sign_failed' => 'Biometric verification failed. Try again.',
      _ => 'Biometric verification is unavailable on this device.',
    });
  }
  if (error is FirebaseFunctionsException) {
    final serverMessage = error.message ?? '';
    if (error.code == 'failed-precondition' &&
        serverMessage.toLowerCase().contains('re-enrollment')) {
      return const StaffTier2Failure(
        'Re-enroll this device in Biometric Device Setup to verify your fingerprint.',
      );
    }
    return StaffTier2Failure(switch (error.code) {
      'resource-exhausted' => 'Too many Tier 2 requests. Try again shortly.',
      'failed-precondition' || 'unauthenticated' =>
        'Fresh staff authentication is required.',
      'permission-denied' =>
        'Emergency Tier 2 access is unavailable for this QR or staff account.',
      'invalid-argument' => 'Invalid QR code or request.',
      _ => 'Unable to reach emergency Tier 2 service.',
    });
  }
  if (error is FirebaseAuthException) {
    return StaffTier2Failure(switch (error.code) {
      'wrong-password' ||
      'invalid-credential' ||
      'invalid-login-credentials' =>
        'Password verification failed. Check your password and try again.',
      'too-many-requests' => 'Too many attempts. Try again later.',
      _ => 'Staff verification failed. Sign in again.',
    });
  }
  return const StaffTier2Failure('Staff Tier 2 operation could not complete.');
}

abstract interface class StaffTier2Client {
  String? get currentUid;
  Stream<String?> get uidChanges;
  Future<void> enrollDeviceWithPassword(String password);
  Future<void> revokeDeviceWithPassword(String password);
  Future<Map<String, dynamic>> readStudentTier2({
    required String qrPayload,
    required String purpose,
  });
  Future<void> setSecureScreen(bool enabled);
}

class StaffTier2Repository implements StaffTier2Client {
  StaffTier2Repository({
    required this.auth,
    required this.functions,
    required this.keyProvider,
    required String expectedProjectId,
  }) {
    if (!['demo-resqme', 'resqme-943ee'].contains(expectedProjectId) ||
        auth.app.options.projectId != expectedProjectId ||
        functions.app.options.projectId != expectedProjectId ||
        auth.app.name != functions.app.name) {
      throw StateError('Unexpected staff Tier 2 Firebase app.');
    }
  }

  final FirebaseAuth auth;
  final FirebaseFunctions functions;
  final PlatformTier2Key keyProvider;

  @override
  String? get currentUid => auth.currentUser?.uid;

  @override
  Stream<String?> get uidChanges => auth.userChanges().map((u) => u?.uid);

  @override
  Future<void> setSecureScreen(bool enabled) =>
      keyProvider.setSecureScreen(enabled);

  String _newDeviceId() => base64Url
      .encode(List<int>.generate(24, (_) => Random.secure().nextInt(256)))
      .replaceAll('=', '');

  String _prefsKey(String uid) => 'resqme_staff_tier2_device_$uid';

  Future<String?> _existingDeviceId(String uid, void Function() check) async {
    final prefs = await SharedPreferences.getInstance();
    check();
    final existing = prefs.getString(_prefsKey(uid));
    if (existing != null && existing.length >= 20) return existing;
    return null;
  }

  Future<T> _withStaff<T>(
    Future<T> Function(String uid, void Function() check) action,
  ) async {
    final uid = currentUid;
    if (uid == null) {
      throw const StaffTier2Failure('Sign in with a staff account first.');
    }
    var invalidated = false;
    final sub = auth.userChanges().listen((user) {
      if (user?.uid != uid) invalidated = true;
    });
    void check() {
      if (invalidated || currentUid != uid) {
        throw const StaffTier2Failure('Staff session changed. Sign in again.');
      }
    }

    try {
      check();
      final result = await action(uid, check);
      check();
      return result;
    } catch (error) {
      throw mapStaffTier2Error(error);
    } finally {
      await sub.cancel();
    }
  }

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> data,
    void Function() check,
  ) async {
    check();
    final result = await functions
        .httpsCallable(
          name,
          options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
        )
        .call<dynamic>(data);
    check();
    if (result.data is! Map) {
      throw const StaffTier2Failure(
        'Emergency Tier 2 service returned an invalid response.',
      );
    }
    return Map<String, dynamic>.from(result.data as Map);
  }

  @override
  Future<void> enrollDeviceWithPassword(String password) =>
      _withStaff((uid, check) async {
        final user = auth.currentUser;
        if (user == null || user.email == null || password.isEmpty) {
          throw const StaffTier2Failure('Enter your account password.');
        }
        await user.reauthenticateWithCredential(
          EmailAuthProvider.credential(email: user.email!, password: password),
        );
        check();
        await user.getIdToken(true);
        check();
        final challenge =
            await _call('issueStaffEnrollmentChallenge', {}, check);
        final challengeId = challenge['challengeId'];
        final nonce = challenge['nonce'];
        if (challengeId is! String || nonce is! String) {
          throw const StaffTier2Failure('Unable to start device enrollment.');
        }

        final prefs = await SharedPreferences.getInstance();
        check();
        final previousDeviceId = prefs.getString(_prefsKey(uid));
        final candidateDeviceId = _newDeviceId();
        final enrollmentMessage =
            'resqme:staff-enroll:v2\n$uid\n$candidateDeviceId\n$challengeId\n$nonce';

        final enrollment = await keyProvider.createStaffKey(
          deviceId: candidateDeviceId,
          challenge: nonce,
          message: enrollmentMessage,
        );
        check();

        try {
          await _call(
            'enrollStaffTier2Device',
            {
              'challengeId': challengeId,
              'deviceId': candidateDeviceId,
              'publicKey': enrollment.publicKey,
              'attestationChain': enrollment.attestationChain,
              'signature': enrollment.signature,
            },
            check,
          );
        } catch (error) {
          try {
            await keyProvider.deleteStaffKey(candidateDeviceId);
          } catch (_) {}
          rethrow;
        }

        await prefs.setString(_prefsKey(uid), candidateDeviceId);
        if (previousDeviceId != null &&
            previousDeviceId != candidateDeviceId) {
          try {
            await keyProvider.deleteStaffKey(previousDeviceId);
          } catch (_) {}
        }
      });

  @override
  Future<void> revokeDeviceWithPassword(String password) =>
      _withStaff((uid, check) async {
        final user = auth.currentUser;
        if (user == null || user.email == null || password.isEmpty) {
          throw const StaffTier2Failure('Enter your account password.');
        }
        await user.reauthenticateWithCredential(
          EmailAuthProvider.credential(email: user.email!, password: password),
        );
        check();
        await user.getIdToken(true);
        check();
        await _call('revokeStaffTier2Device', {}, check);
        final prefs = await SharedPreferences.getInstance();
        final existing = prefs.getString(_prefsKey(uid));
        if (existing != null) {
          try {
            await keyProvider.deleteStaffKey(existing);
          } catch (_) {}
          await prefs.remove(_prefsKey(uid));
        }
      });

  @override
  Future<Map<String, dynamic>> readStudentTier2({
    required String qrPayload,
    required String purpose,
  }) =>
      _withStaff((uid, check) async {
        if (!staffTier2Purposes.contains(purpose)) {
          throw const StaffTier2Failure(
            'Select a valid emergency access purpose.',
          );
        }
        final deviceId = await _existingDeviceId(uid, check);
        if (deviceId == null) {
          throw const StaffTier2Failure(
            'Enroll this trusted staff device with biometrics first.',
          );
        }
        final challenge = await _call(
          'issueStaffTier2Challenge',
          {
            'payload': qrPayload.trim(),
            'deviceId': deviceId,
            'purpose': purpose,
          },
          check,
        );
        final challengeId = challenge['challengeId'];
        final nonce = challenge['nonce'];
        final operation = challenge['operation'];
        if (challengeId is! String || nonce is! String || operation is! String) {
          throw const StaffTier2Failure('Emergency challenge is unavailable.');
        }
        final message =
            'resqme:staff-tier2:v1\n$uid\n$deviceId\n$operation\n$purpose\n$challengeId\n$nonce';
        final signature = await keyProvider.signStaff(deviceId, message);
        check();
        return _call(
          'readStudentTier2',
          {
            'challengeId': challengeId,
            'deviceId': deviceId,
            'signature': signature,
          },
          check,
        );
      });
}
