import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:resqme/app/resqme_app.dart';
import 'package:resqme/core/config/app_environment.dart';
import 'package:resqme/core/config/firebase_environment.dart';
import 'package:resqme/features/welcome/data/shared_preferences_consent_repository.dart';
import 'package:resqme/features/registration/services/student_registration_repository.dart';
import 'package:resqme/features/registration/services/firebase_student_registration_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  StudentRegistrationRepository? registrationRepository;
  Stream<void>? authChanges;
  if (AppEnvironment.allowsFirebaseInitialization(isDebugBuild: kDebugMode)) {
    try {
      final app = await Firebase.initializeApp(
        name: 'resqme-local',
        options: const FirebaseOptions(
          apiKey: 'AIzaSyDemoResqmeLocalOnly000000000000000',
          appId: '1:1234567890:android:0000000000000000000000',
          messagingSenderId: '1234567890',
          projectId: 'demo-resqme',
        ),
      );
      final auth = FirebaseAuth.instanceFor(app: app);
      final firestore = FirebaseFirestore.instanceFor(app: app);
      final functions = FirebaseFunctions.instanceFor(
        app: app,
        region: 'us-central1',
      );
      firestore.settings = const Settings(persistenceEnabled: false);
      await configureFirebaseForDebug(
        _FlutterFireConnector(auth, firestore, functions),
        defaultTargetPlatform,
        loopbackOnly: true,
      );
      registrationRepository = FirebaseStudentRegistrationRepository(
        FlutterFireRegistrationClient(
          auth: auth,
          firestore: firestore,
          functions: functions,
        ),
      );
      authChanges = auth.authStateChanges().map<void>((_) {});
    } catch (_) {
      // Keep public emergency resources available when local setup is unavailable.
    }
  }

  runApp(
    ResQMeApp(
      registrationRepository: registrationRepository,
      authChanges: authChanges,
      consentRepository: SharedPreferencesConsentRepository(
        SharedPreferencesBooleanStore(),
      ),
    ),
  );
}

class _FlutterFireConnector implements FirebaseConnector {
  _FlutterFireConnector(this.auth, this.firestore, this.functions);
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;
  @override
  Future<void> configureAuth(String host, int port) {
    return auth.useAuthEmulator(host, port, automaticHostMapping: false);
  }

  @override
  Future<void> configureFirestore(String host, int port) async {
    firestore.useFirestoreEmulator(host, port, automaticHostMapping: false);
  }

  @override
  Future<void> configureFunctions(String host, int port) async {
    functions.useFunctionsEmulator(host, port, automaticHostMapping: false);
  }
}
