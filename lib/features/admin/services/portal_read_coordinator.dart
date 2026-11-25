import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Explicit Portal screen loading and failure states.
enum PortalLoadStatus {
  initialLoading,
  refreshing,
  loaded,
  empty,
  transientError,
  authorizationError,
}

/// Sanitized classification for Portal read and mutation failures.
enum PortalErrorKind {
  transient,
  authorization,
  operation,
}

/// Obfuscation-safe marker interface implemented by Portal/Staff exceptions
/// that carry session-level authorization loss semantics.
abstract interface class PortalSessionAuthError {
  bool get isSessionAuthLoss;
}

/// Thrown when staff session verification cannot complete due to a temporary
/// network, timeout, or Cloud Functions cold-start failure rather than an
/// actual authorization denial.
class StaffAccessTransientError implements Exception {
  const StaffAccessTransientError(this.message, {this.firebaseCode});

  final String message;
  final String? firebaseCode;

  @override
  String toString() => message;
}

abstract final class PortalErrorClassifier {
  static const Set<String> _transientFunctionCodes = {
    'unavailable',
    'deadline-exceeded',
    'aborted',
  };

  static const Set<String> _transientAuthCodes = {
    'network-request-failed',
  };

  static const Set<String> _sessionInvalidAuthCodes = {
    'unauthenticated',
    'user-disabled',
    'user-token-expired',
    'invalid-user-token',
    'user-not-found',
  };

  static bool isTransientError(Object error) {
    if (error is StaffAccessTransientError || error is TimeoutException) {
      return true;
    }
    if (error is FirebaseFunctionsException) {
      return _transientFunctionCodes.contains(error.code.toLowerCase());
    }
    if (error is FirebaseAuthException) {
      return _transientAuthCodes.contains(error.code.toLowerCase());
    }
    return false;
  }

  /// Returns true when the error indicates that the signed-in staff session
  /// itself is unauthenticated, disabled, suspended, revoked, or no longer
  /// authorized for Portal access (as opposed to a target-student precondition).
  static bool isSessionAuthorizationError(Object error) {
    if (error is PortalSessionAuthError) {
      return error.isSessionAuthLoss;
    }
    if (error is FirebaseAuthException) {
      return _sessionInvalidAuthCodes.contains(error.code.toLowerCase());
    }
    if (error is FirebaseFunctionsException) {
      final code = error.code.toLowerCase();
      if (code == 'unauthenticated') return true;
      final msg = (error.message ?? '').toLowerCase();
      if (code == 'permission-denied') {
        if (msg.contains('staff access is unavailable') ||
            msg.contains('master admin access is required') ||
            msg.contains('sign in is required')) {
          return true;
        }
      }
      if (code == 'failed-precondition') {
        if (msg.contains('password setup is required') ||
            msg.contains('email verification is required')) {
          return true;
        }
      }
    }
    return false;
  }

  static PortalErrorKind classify(Object error) {
    if (isSessionAuthorizationError(error)) {
      return PortalErrorKind.authorization;
    }
    if (error is FirebaseFunctionsException &&
        error.code.toLowerCase() == 'permission-denied') {
      return PortalErrorKind.authorization;
    }
    if (isTransientError(error)) {
      return PortalErrorKind.transient;
    }
    return PortalErrorKind.operation;
  }

  static String sanitizedCode(Object error) {
    if (error is StaffAccessTransientError) {
      return error.firebaseCode ?? 'transient';
    }
    if (error is TimeoutException) {
      return 'timeout';
    }
    if (error is FirebaseFunctionsException) {
      return error.code.toLowerCase();
    }
    if (error is FirebaseAuthException) {
      return error.code.toLowerCase();
    }
    return 'error';
  }
}

/// Coordinates Portal read operations outside [AccountOperationLock] so
/// concurrent screen reads never fail-fast, identical in-flight reads
/// deduplicate, transient read errors retry with bounded backoff, valid
/// snapshots stay scoped to `uid + schoolId + role`, and logout or
/// authorization loss purges all cached data immediately.
class PortalReadCoordinator extends ChangeNotifier {
  PortalReadCoordinator({
    required this.currentUidProvider,
    this.maxReadAttempts = 3,
    this.initialBackoff = const Duration(milliseconds: 250),
    this.requireBoundScope = false,
    Future<void> Function(Duration)? delayFn,
    this.onSessionAuthorizationLost,
  }) : _delayFn = delayFn ?? Future<void>.delayed {
    assert(maxReadAttempts >= 1);
  }

  final String? Function() currentUidProvider;
  final int maxReadAttempts;
  final Duration initialBackoff;
  final bool requireBoundScope;
  final Future<void> Function(Duration) _delayFn;
  void Function(Object error)? onSessionAuthorizationLost;

  String? _activeScopeKey;
  int _epoch = 0;
  int _mutationVersion = 0;
  final Map<String, Future<Object?>> _inFlight = <String, Future<Object?>>{};
  final Map<String, Object?> _cache = <String, Object?>{};

  String? get activeScopeKey => _activeScopeKey;
  int get epoch => _epoch;
  int get mutationVersion => _mutationVersion;
  int get cachedEntryCount => _cache.length;

  void bindScope({
    required String uid,
    required String schoolId,
    required String role,
  }) {
    final next = '$uid|$schoolId|$role';
    if (_activeScopeKey == next) return;
    _epoch += 1;
    _activeScopeKey = next;
    _inFlight.clear();
    _cache.clear();
    notifyListeners();
  }

  void clearScope() {
    final hadData =
        _activeScopeKey != null || _inFlight.isNotEmpty || _cache.isNotEmpty;
    _epoch += 1;
    _activeScopeKey = null;
    _inFlight.clear();
    _cache.clear();
    if (hadData) {
      notifyListeners();
    }
  }

  /// Notifies the coordinator when an external operation (such as a mutation
  /// or step-up challenge) encounters session-level authorization loss.
  void reportExternalError(Object error) {
    if (PortalErrorClassifier.isSessionAuthorizationError(error)) {
      clearScope();
      onSessionAuthorizationLost?.call(error);
    }
  }

  /// Marks cached read results dirty and drops pre-mutation in-flight futures
  /// after an authorized mutation without wiping mounted UI widgets.
  void notifyMutation() {
    _mutationVersion += 1;
    _inFlight.clear();
    _cache.clear();
    notifyListeners();
  }

  T? peekCached<T>(String key) {
    final uid = currentUidProvider();
    final scope = _activeScopeKey;
    if (uid == null || scope == null || !scope.startsWith('$uid|')) {
      return null;
    }
    final val = _cache['$scope::$key'];
    return val is T ? val : null;
  }

  Future<T> runRead<T>({
    required String key,
    required Future<T> Function() action,
    bool cacheResult = true,
  }) {
    final uid = currentUidProvider();
    if (uid == null || uid.isEmpty) {
      return Future<T>.error(StateError('unauthenticated'));
    }
    if (_activeScopeKey != null && !_activeScopeKey!.startsWith('$uid|')) {
      clearScope();
    }
    if (requireBoundScope && _activeScopeKey == null) {
      return Future<T>.error(StateError('scope_invalidated'));
    }
    final scopePrefix = _activeScopeKey ?? uid;
    final scopedKey = '$scopePrefix::$key';
    final existing = _inFlight[scopedKey];
    if (existing != null) {
      return existing.then((value) => value as T);
    }

    final startEpoch = _epoch;
    final startMutationVersion = _mutationVersion;
    final future = _executeRead<T>(
      uid: uid,
      scopedKey: scopedKey,
      startEpoch: startEpoch,
      startMutationVersion: startMutationVersion,
      cacheResult: cacheResult,
      action: action,
    );
    _inFlight[scopedKey] = future;
    future.whenComplete(() {
      if (identical(_inFlight[scopedKey], future)) {
        _inFlight.remove(scopedKey);
      }
    }).ignore();
    return future;
  }

  Future<T> _executeRead<T>({
    required String uid,
    required String scopedKey,
    required int startEpoch,
    required int startMutationVersion,
    required bool cacheResult,
    required Future<T> Function() action,
  }) async {
    var attempt = 0;
    while (true) {
      attempt += 1;
      if (_epoch != startEpoch || currentUidProvider() != uid) {
        throw StateError('scope_invalidated');
      }
      try {
        final value = await action();
        if (_epoch != startEpoch || currentUidProvider() != uid) {
          throw StateError('scope_invalidated');
        }
        if (cacheResult && _mutationVersion == startMutationVersion) {
          _cache[scopedKey] = value;
        }
        return value;
      } catch (error) {
        if (_epoch == startEpoch &&
            PortalErrorClassifier.isSessionAuthorizationError(error)) {
          clearScope();
          onSessionAuthorizationLost?.call(error);
          rethrow;
        }
        final canRetry = attempt < maxReadAttempts &&
            _epoch == startEpoch &&
            currentUidProvider() == uid &&
            PortalErrorClassifier.isTransientError(error);
        if (!canRetry) {
          rethrow;
        }
        final backoff = Duration(
          milliseconds: initialBackoff.inMilliseconds * (1 << (attempt - 1)),
        );
        await _delayFn(backoff);
      }
    }
  }
}
