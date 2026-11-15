import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:resqme/features/medical/services/platform_tier2_key.dart';
import 'package:resqme/features/medical/services/tier2_authorization_repository.dart';

class TestApp implements FirebaseApp {
  @override
  String get name => 'tier2-test';
  @override
  FirebaseOptions get options => const FirebaseOptions(
    apiKey: 'fictional', appId: 'fictional', messagingSenderId: 'fictional', projectId: 'demo-resqme');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestUser implements User {
  TestUser(this.uid);
  @override
  final String uid;
  @override
  String get email => 'fictional@example.test';
  Object? reauthError;
  Future<void> Function()? onReauth, onToken;
  @override
  Future<UserCredential> reauthenticateWithCredential(AuthCredential credential) async {
    if (reauthError != null) throw reauthError!;
    await onReauth?.call();
    return TestCredential();
  }
  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async {
    await onToken?.call();
    return null;
  }
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
class TestCredential implements UserCredential {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
class TestAuth implements FirebaseAuth {
  @override
  FirebaseApp get app => TestApp();
  @override
  User? currentUser = TestUser('adult-a');
  final changes = StreamController<User?>.broadcast(sync: true);
  void switchUser(User? user) { currentUser = user; changes.add(user); }
  @override
  Stream<User?> userChanges() => changes.stream;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
class TestFunctions implements FirebaseFunctions {
  @override
  FirebaseApp get app => TestApp();
  final calls = <String>[];
  Future<dynamic> Function(String, dynamic)? onCall;
  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) => TestCallable((data) async {
    calls.add(name);
    if (onCall != null) return onCall!(name, data);
    if (name == 'issueTier2Challenge') return {
      'challengeId': 'fictional-challenge', 'nonce': 'fictional-nonce',
      'deviceId': (data as Map)['deviceId'], 'operation': 'read_medical',
    };
    return <String, dynamic>{};
  });
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
class TestCallable implements HttpsCallable {
  TestCallable(this.invoke);
  final Future<dynamic> Function(dynamic) invoke;
  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async => TestResult<T>((await invoke(parameters)) as T);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
class TestResult<T> implements HttpsCallableResult<T> {
  TestResult(this.data);
  @override
  final T data;
}
class TestKey extends PlatformTier2Key {
  Object? failure;
  Future<void> Function()? onSign, onCreate, onDelete;
  final calls = <String>[];
  @override
  Future<String> sign(String deviceId, String message) async {
    calls.add('sign'); await onSign?.call();
    if (failure != null) throw failure!;
    return 'fictional-proof';
  }
  @override
  Future<String> createKey(String deviceId) async { calls.add('create'); await onCreate?.call(); return 'fictional-key'; }
  @override
  Future<void> deleteKey(String deviceId) async { calls.add('delete'); await onDelete?.call(); }
}
class Tier2Fixture {
  final auth = TestAuth();
  final functions = TestFunctions();
  final key = TestKey();
  late final repository = Tier2AuthorizationRepository(auth: auth, functions: functions, keyProvider: key, expectedProjectId: 'demo-resqme');
}
