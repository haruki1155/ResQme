import 'package:firebase_core/firebase_core.dart';
import '../../../core/config/app_environment.dart';

class AdminBackendConfig {
  const AdminBackendConfig._({
    required this.mode,
    required this.projectId,
    required this.options,
  });

  final String mode;
  final String projectId;
  final FirebaseOptions options;

  bool get isEmulator => mode == 'emulator';

  static const String adminApplicationId = 'com.example.resqme.admin';
  static const String studentStagingAndroidAppId =
      '1:519076598217:android:cda85c2178c92d16621818';

  static AdminBackendConfig? resolve({
    required String mode,
    required bool isDebugBuild,
    String stagingAppId = '',
    String stagingApiKey = '',
    String stagingProjectId = 'resqme-943ee',
    String stagingMessagingSenderId = '519076598217',
  }) {
    final base = BackendSelection.resolve(mode, isDebugBuild: isDebugBuild);
    if (base == null) return null;

    if (base.isEmulator) {
      return const AdminBackendConfig._(
        mode: 'emulator',
        projectId: 'demo-resqme',
        options: FirebaseOptions(
          apiKey: 'AIzaSyDemoResqmeLocalOnly000000000000000',
          appId: '1:1234567890:android:0000000000000000000001',
          messagingSenderId: '1234567890',
          projectId: 'demo-resqme',
        ),
      );
    }

    // Staging mode fails closed unless an explicit Admin Android Firebase app
    // distinct from the Student app is provided for resqme-943ee.
    final appId = stagingAppId.trim();
    final apiKey = stagingApiKey.trim();
    final project = stagingProjectId.trim();
    final sender = stagingMessagingSenderId.trim();
    if (project != 'resqme-943ee' ||
        appId.isEmpty ||
        apiKey.isEmpty ||
        sender.isEmpty ||
        appId == studentStagingAndroidAppId ||
        !RegExp(r'^1:\d+:android:[a-fA-F0-9]{16,}$').hasMatch(appId)) {
      return null;
    }

    return AdminBackendConfig._(
      mode: 'staging',
      projectId: project,
      options: FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: sender,
        projectId: project,
        storageBucket: 'resqme-943ee.firebasestorage.app',
      ),
    );
  }
}
