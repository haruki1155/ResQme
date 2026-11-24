import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:resqme/core/config/app_environment.dart';
import 'package:resqme/core/config/firebase_environment.dart';
import 'package:resqme/core/data/account_operation_lock.dart';
import 'package:resqme/features/admin/admin_app.dart';
import 'package:resqme/features/admin/screens/staff_device_setup_screen.dart';
import 'package:resqme/features/admin/screens/staff_tier2_scanner_screen.dart';
import 'package:resqme/features/admin/services/staff_access_repository.dart';
import 'package:resqme/features/admin/services/staff_tier2_repository.dart';
import 'package:resqme/features/medical/services/platform_tier2_key.dart';
import 'package:resqme/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final backend = BackendSelection.resolve(
    const String.fromEnvironment('RESQME_BACKEND'),
    isDebugBuild: kDebugMode,
  );
  if (backend == null) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('ResQMe Admin requires an approved backend mode.'),
          ),
        ),
      ),
    );
    return;
  }
  try {
    final app = await Firebase.initializeApp(
      name: 'resqme-admin-${backend.mode}',
      options: backend.isEmulator
          ? const FirebaseOptions(
              apiKey: 'AIzaSyDemoResqmeLocalOnly000000000000000',
              appId: '1:1234567890:android:0000000000000000000000',
              messagingSenderId: '1234567890',
              projectId: 'demo-resqme',
            )
          : DefaultFirebaseOptions.currentPlatform,
    );
    if (app.options.projectId != backend.projectId) {
      throw StateError('Unexpected Firebase project.');
    }
    final auth = FirebaseAuth.instanceFor(app: app);
    final firestore = FirebaseFirestore.instanceFor(app: app);
    final functions = FirebaseFunctions.instanceFor(
      app: app,
      region: 'us-central1',
    );
    firestore.settings = const Settings(persistenceEnabled: false);
    if (backend.isEmulator) {
      await configureFirebaseForDebug(
        _AdminFirebaseConnector(auth, firestore, functions),
        defaultTargetPlatform,
        loopbackOnly: true,
      );
    }
    final lock = AccountOperationLock();
    final accessRepository = FirebaseStaffAccessRepository(
      auth: auth,
      functions: functions,
      operationLock: lock,
      expectedProjectId: backend.projectId,
    );
    final tier2Client = StaffTier2Repository(
      auth: auth,
      functions: functions,
      keyProvider: PlatformTier2Key(),
      expectedProjectId: backend.projectId,
    );
    runApp(
      AdminApp(
        accessRepository: accessRepository,
        scannerBuilder: (_, _) => StaffTier2ScannerScreen(client: tier2Client),
        deviceSetupBuilder: (_, _) =>
            StaffDeviceSetupScreen(client: tier2Client),
      ),
    );
  } catch (_) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('ResQMe Admin is unavailable.')),
        ),
      ),
    );
  }
}

class _AdminFirebaseConnector implements FirebaseConnector {
  _AdminFirebaseConnector(this.auth, this.firestore, this.functions);
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;

  @override
  Future<void> configureAuth(String host, int port) =>
      auth.useAuthEmulator(host, port);

  @override
  Future<void> configureFirestore(String host, int port) async {
    firestore.useFirestoreEmulator(host, port);
  }

  @override
  Future<void> configureFunctions(String host, int port) async {
    functions.useFunctionsEmulator(host, port);
  }
}
