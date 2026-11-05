import 'package:flutter_test/flutter_test.dart';
import 'package:resqme/core/config/app_environment.dart';

void main() {
  test('backend selection is explicit, debug-only and project-bound', () {
    expect(BackendSelection.resolve('', isDebugBuild: true), null);
    expect(BackendSelection.resolve('production', isDebugBuild: true), null);
    expect(BackendSelection.resolve('staging', isDebugBuild: false), null);
    expect(
      BackendSelection.resolve('emulator', isDebugBuild: true)!.projectId,
      'demo-resqme',
    );
    expect(
      BackendSelection.resolve('staging', isDebugBuild: true)!.projectId,
      'resqme-943ee',
    );
  });
  test('permits Firebase initialization only for a debug build', () {
    expect(
      AppEnvironment.allowsFirebaseInitialization(isDebugBuild: true),
      isTrue,
    );
    expect(
      AppEnvironment.allowsFirebaseInitialization(isDebugBuild: false),
      isFalse,
    );
  });
}
