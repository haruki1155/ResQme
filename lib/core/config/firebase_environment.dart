import 'package:flutter/foundation.dart';

abstract interface class FirebaseConnector {
  Future<void> configureAuth(String host, int port);
  Future<void> configureFirestore(String host, int port);
  Future<void> configureFunctions(String host, int port);
}

class FirebaseEmulatorEndpoints {
  const FirebaseEmulatorEndpoints._({required this.host});

  final String host;

  String get authHost => host;
  String get firestoreHost => host;
  String get functionsHost => host;

  int get authPort => 9099;
  int get firestorePort => 8080;
  int get functionsPort => 5001;

  factory FirebaseEmulatorEndpoints.forPlatform(TargetPlatform platform) {
    return FirebaseEmulatorEndpoints._(
      host: platform == TargetPlatform.android ? '10.0.2.2' : 'localhost',
    );
  }
}

Future<void> configureFirebaseForDebug(
  FirebaseConnector connector,
  TargetPlatform platform,
) async {
  final endpoints = FirebaseEmulatorEndpoints.forPlatform(platform);
  await connector.configureAuth(endpoints.authHost, endpoints.authPort);
  await connector.configureFirestore(
    endpoints.firestoreHost,
    endpoints.firestorePort,
  );
  await connector.configureFunctions(
    endpoints.functionsHost,
    endpoints.functionsPort,
  );
}
