import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/network/test_certificate_trust.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('test certificate trust', () {
    test('only enables the two exact test HTTPS endpoints', () {
      for (final host in testCertificateHosts) {
        expect(
          shouldEnableTestCertificateTrust(
            environment: 'test',
            apiBaseUri: Uri.parse('https://$host:8443'),
          ),
          isTrue,
          reason: host,
        );
      }

      for (final candidate in <({String environment, String apiBaseUrl})>[
        (
          environment: 'production',
          apiBaseUrl: 'https://backend-test.lute-momcozylab.luteos.cloud:8443',
        ),
        (
          environment: 'local',
          apiBaseUrl: 'https://agent-test.lute-momcozylab.luteos.cloud:8443',
        ),
        (
          environment: 'test',
          apiBaseUrl: 'https://lute-momcozylab.luteos.cloud:8443',
        ),
        (environment: 'test', apiBaseUrl: 'https://api.example.test:8443'),
        (
          environment: 'test',
          apiBaseUrl: 'https://backend-test.lute-momcozylab.luteos.cloud',
        ),
        (
          environment: 'test',
          apiBaseUrl: 'http://backend-test.lute-momcozylab.luteos.cloud:8443',
        ),
      ]) {
        expect(
          shouldEnableTestCertificateTrust(
            environment: candidate.environment,
            apiBaseUri: Uri.parse(candidate.apiBaseUrl),
          ),
          isFalse,
          reason: '${candidate.environment}: ${candidate.apiBaseUrl}',
        );
      }
    });

    test('does not load or install trust outside the test target', () async {
      var loaderCalled = false;
      var installerCalled = false;

      final enabled = await configureTestCertificateTrust(
        environment: 'production',
        apiBaseUrl: 'https://backend-test.lute-momcozylab.luteos.cloud:8443',
        certificateLoader: (_) async {
          loaderCalled = true;
          throw StateError('certificate must not be loaded');
        },
        securityContextInstaller: (_) => installerCalled = true,
      );

      expect(enabled, isFalse);
      expect(loaderCalled, isFalse);
      expect(installerCalled, isFalse);
    });

    test(
      'loads the bundled certificate and installs a trusted context',
      () async {
        SecurityContext? installedContext;

        final enabled = await configureTestCertificateTrust(
          environment: 'test',
          apiBaseUrl: 'https://backend-test.lute-momcozylab.luteos.cloud:8443',
          securityContextInstaller: (context) => installedContext = context,
        );

        expect(enabled, isTrue);
        expect(installedContext, isNotNull);
      },
    );
  });
}
