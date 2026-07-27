import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:app/app/momcozy_api_runtime.dart';
import 'package:app/core/auth/momcozy_auth_device_id.dart';
import 'package:app/core/network/api_json_transport.dart';
import 'package:app/core/network/staging_certificate_trust.dart';

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
}
