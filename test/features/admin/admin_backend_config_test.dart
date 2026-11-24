import 'package:flutter_test/flutter_test.dart';
import 'package:resqme/features/admin/config/admin_backend_config.dart';

void main() {
  test('emulator mode resolves to demo-resqme only in debug builds', () {
    final ok = AdminBackendConfig.resolve(mode: 'emulator', isDebugBuild: true);
    expect(ok, isNotNull);
    expect(ok!.projectId, 'demo-resqme');
    expect(ok.isEmulator, true);

    expect(
      AdminBackendConfig.resolve(mode: 'emulator', isDebugBuild: false),
      isNull,
    );
  });

  test('staging mode fails closed when Admin Firebase config is missing, malformed, or reuses Student appId', () {
    expect(
      AdminBackendConfig.resolve(mode: 'staging', isDebugBuild: true),
      isNull,
    );
    expect(
      AdminBackendConfig.resolve(
        mode: 'staging',
        isDebugBuild: true,
        stagingAppId: AdminBackendConfig.studentStagingAndroidAppId,
        stagingApiKey: 'AIzaSyFictionalAdminKey00000000000000000',
      ),
      isNull,
    );
    expect(
      AdminBackendConfig.resolve(
        mode: 'staging',
        isDebugBuild: true,
        stagingAppId: 'not-a-valid-app-id',
        stagingApiKey: 'AIzaSyFictionalAdminKey00000000000000000',
      ),
      isNull,
    );
    expect(
      AdminBackendConfig.resolve(
        mode: 'staging',
        isDebugBuild: true,
        stagingAppId: '1:519076598217:android:abcdef0123456789000001',
        stagingApiKey: 'AIzaSyFictionalAdminKey00000000000000000',
        stagingProjectId: 'wrong-project',
      ),
      isNull,
    );
  });

  test('staging mode succeeds only with explicit distinct Admin Firebase app for resqme-943ee', () {
    final ok = AdminBackendConfig.resolve(
      mode: 'staging',
      isDebugBuild: true,
      stagingAppId: '1:519076598217:android:abcdef0123456789000001',
      stagingApiKey: 'AIzaSyFictionalAdminKey00000000000000000',
    );
    expect(ok, isNotNull);
    expect(ok!.projectId, 'resqme-943ee');
    expect(ok.isEmulator, false);
    expect(ok.options.appId, '1:519076598217:android:abcdef0123456789000001');
  });
}
