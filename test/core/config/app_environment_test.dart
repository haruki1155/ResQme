import 'package:flutter_test/flutter_test.dart';
import 'package:resqme/core/config/app_environment.dart';

void main() {
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
