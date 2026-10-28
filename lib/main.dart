import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:resqme/app/resqme_app.dart';
import 'package:resqme/core/config/firebase_environment.dart';
import 'package:resqme/features/welcome/data/shared_preferences_consent_repository.dart';
import 'package:resqme/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (kDebugMode) {
    await configureFirebaseForDebug(
      _FlutterFireConnector(),
      defaultTargetPlatform,
    );
  }

  runApp(
    ResQMeApp(
      consentRepository: SharedPreferencesConsentRepository(
        SharedPreferencesBooleanStore(),
      ),
    ),
  );
}

class _FlutterFireConnector implements FirebaseConnector {
  @override
  Future<void> configureAuth(String host, int port) {
    return FirebaseAuth.instance.useAuthEmulator(host, port);
  }

  @override
  Future<void> configureFirestore(String host, int port) async {
    FirebaseFirestore.instance.useFirestoreEmulator(host, port);
  }

  @override
  Future<void> configureFunctions(String host, int port) async {
    FirebaseFunctions.instance.useFunctionsEmulator(host, port);
  }
}
