import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqme/core/config/firebase_environment.dart';

class _RecordingConnector implements FirebaseConnector {
  final List<String> calls = [];

  @override
  Future<void> configureAuth(String host, int port) async {
    calls.add('auth:$host:$port');
  }

  @override
  Future<void> configureFirestore(String host, int port) async {
    calls.add('firestore:$host:$port');
  }

  @override
  Future<void> configureFunctions(String host, int port) async {
    calls.add('functions:$host:$port');
  }
}

void main() {
  test('uses Android emulator host and Firebase emulator ports', () {
    final endpoints = FirebaseEmulatorEndpoints.forPlatform(
      TargetPlatform.android,
    );

    expect(endpoints.authHost, '10.0.2.2');
    expect(endpoints.firestoreHost, '10.0.2.2');
    expect(endpoints.functionsHost, '10.0.2.2');
    expect(endpoints.authPort, 9099);
    expect(endpoints.firestorePort, 8080);
    expect(endpoints.functionsPort, 5001);
  });

  test('uses localhost for desktop targets', () {
    final endpoints = FirebaseEmulatorEndpoints.forPlatform(
      TargetPlatform.windows,
    );

    expect(endpoints.authHost, 'localhost');
    expect(endpoints.firestoreHost, 'localhost');
    expect(endpoints.functionsHost, 'localhost');
  });

  test('configures Auth, Firestore, then Functions', () async {
    final connector = _RecordingConnector();

    await configureFirebaseForDebug(connector, TargetPlatform.android);

    expect(connector.calls, [
      'auth:10.0.2.2:9099',
      'firestore:10.0.2.2:8080',
      'functions:10.0.2.2:5001',
    ]);
  });
}
