abstract final class AppEnvironment {
  static bool allowsFirebaseInitialization({required bool isDebugBuild}) {
    return isDebugBuild;
  }
}

class BackendSelection {
  const BackendSelection._(this.mode, this.projectId);
  final String mode, projectId;
  bool get isEmulator => mode == 'emulator';
  static BackendSelection? resolve(String mode, {required bool isDebugBuild}) {
    if (!isDebugBuild) return null;
    return switch (mode) {
      'emulator' => const BackendSelection._('emulator', 'demo-resqme'),
      'staging' => const BackendSelection._('staging', 'resqme-943ee'),
      _ => null,
    };
  }
}
