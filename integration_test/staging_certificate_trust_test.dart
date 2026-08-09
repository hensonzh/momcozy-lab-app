import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/auth/flutter_secure_momcozy_session_store.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_auth_device_id.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/core/network/staging_certificate_trust.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('staging certificate reaches the live health endpoint', (
    tester,
  ) async {
    final enabled = await configureStagingCertificateTrust();
    expect(enabled, isTrue);

    final client = HttpClient();
    try {
      final request = await client.getUrl(
        Uri.parse('https://lute-momcozylab.luteos.cloud:8443/v1/health/live'),
      );
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      expect(response.statusCode, HttpStatus.ok);
      expect(jsonDecode(body), <String, Object?>{'status': 'ok'});
    } finally {
      client.close(force: true);
    }
  });

  testWidgets('invite login reaches the API after device ID bootstrap', (
    tester,
  ) async {
    final enabled = await configureStagingCertificateTrust();
    expect(enabled, isTrue);

    final runtime = await MomCozyApiRuntime.bootstrap();
    final deviceId = await const FlutterSecureMomCozyAuthDeviceIdStore()
        .readOrCreateDeviceId();
    expect(deviceId, startsWith('flutter-'));

    final repository = runtime.authRepository;

    await expectLater(
      repository.inviteLogin(
        inviteCode: 'MCZ-E2E-EXPECTED-INVALID',
        deviceId: deviceId,
      ),
      throwsA(
        isA<ApiHttpException>()
            .having((error) => error.statusCode, 'statusCode', 401)
            .having(
              (error) => error.errorCode,
              'errorCode',
              'authentication_required',
            ),
      ),
    );
  });

  testWidgets('Android secure storage persists and verifies one session', (
    tester,
  ) async {
    const store = FlutterSecureMomCozySessionStore(
      namespace: 'momcozy.integration_test.auth.session.v1',
    );
    await store.clearSession();
    addTearDown(store.clearSession);

    const issued = MomCozySession(
      status: MomCozySessionStatus.authenticated,
      userId: 'integration-user',
      babyId: 'integration-baby',
      locale: 'zh-CN',
      accessToken: 'integration-access',
      refreshToken: 'integration-refresh',
    );

    await store.writeSession(issued);
    final restored = await store.readSession();

    expect(restored?.status, MomCozySessionStatus.authenticated);
    expect(restored?.userId, 'integration-user');
    expect(restored?.babyId, 'integration-baby');
    expect(restored?.locale, 'zh-CN');
    expect(restored?.accessToken, 'integration-access');
    expect(restored?.refreshToken, 'integration-refresh');
  });
}
