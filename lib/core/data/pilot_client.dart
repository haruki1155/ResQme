import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'account_operation_lock.dart';

abstract interface class PilotClient {
  String? get uid;
  Future<Map<String, dynamic>?> readMine(String collection);
  Future<Map<String, dynamic>> invoke(String name, Map<String, dynamic> data);
  Future<bool> resolveQr(String payload);
}

class FirebasePilotClient implements PilotClient {
  FirebasePilotClient({
    required this.auth,
    required this.firestore,
    required this.functions,
    required this.operationLock,
    required String expectedProjectId,
  }) {
    if (!['demo-resqme', 'resqme-943ee'].contains(expectedProjectId) ||
        [auth.app, firestore.app, functions.app].any(
          (app) =>
              app.options.projectId != expectedProjectId ||
              app.name != auth.app.name,
        )) {
      throw StateError('Unexpected pilot Firebase app.');
    }
  }
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;
  final AccountOperationLock operationLock;
  @override
  String? get uid => auth.currentUser?.uid;
  @override
  Future<Map<String, dynamic>?> readMine(String collection) async {
    if (![
      'studentProfiles',
      'studentMedicalRecords',
      'studentQrCredentials',
    ].contains(collection)) {
      throw StateError('Unsupported private collection.');
    }
    final owner = uid;
    if (owner == null) throw StateError('Sign in is required.');
    final result = await firestore
        .doc('$collection/$owner')
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 10));
    if (uid != owner) throw StateError('Account changed.');
    return result.data();
  }

  @override
  Future<Map<String, dynamic>> invoke(String name, Map<String, dynamic> data) =>
      operationLock.run(() async {
        if (![
          'saveMySyntheticMedicalRecord',
          'clearMySyntheticMedicalRecord',
          'ensureMyTier1Qr',
          'replaceMyTier1Qr',
          'completeMyMedicalRecord',
          'getMyStudentProfile',
        ].contains(name)) {
          throw StateError('Unsupported pilot operation.');
        }
        final owner = uid;
        if (owner == null) throw StateError('Sign in is required.');
        final result = await functions
            .httpsCallable(
              name,
              options: HttpsCallableOptions(
                timeout: const Duration(seconds: 10),
              ),
            )
            .call<dynamic>(data);
        if (uid != owner || result.data is! Map) {
          throw StateError('Account changed or invalid response.');
        }
        return Map<String, dynamic>.from(result.data as Map);
      });

  @override
  Future<bool> resolveQr(String payload) async {
    final result = await functions
        .httpsCallable(
          'resolveTier1Qr',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 10)),
        )
        .call<dynamic>({'payload': payload});
    if (result.data is! Map ||
        (result.data as Map).keys.any((key) => key != 'active')) {
      throw StateError('Invalid QR response.');
    }
    return (result.data as Map)['active'] == true;
  }
}
