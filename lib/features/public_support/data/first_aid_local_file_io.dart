import 'dart:io';

/// Reads [relativePath] synchronously when running directly from a local
/// workspace filesystem (such as `flutter test`), returning `null` on mobile
/// APK/IPA bundles where assets are read via `rootBundle`.
String? tryReadLocalAssetFileSync(String relativePath) {
  try {
    final file = File(relativePath);
    if (file.existsSync()) {
      return file.readAsStringSync();
    }
  } catch (_) {
    // Packaged mobile sandboxes do not expose flutter_assets as CWD files;
    // callers fall back to rootBundle.loadString.
  }
  return null;
}
