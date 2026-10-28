abstract final class AppEnvironment {
  static bool allowsFirebaseInitialization({required bool isDebugBuild}) {
    return isDebugBuild;
  }
}
