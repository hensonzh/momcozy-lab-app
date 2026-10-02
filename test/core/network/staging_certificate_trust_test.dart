import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/network/staging_certificate_trust.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('staging certificate trust', () {
    test('only enables the two exact staging HTTPS endpoints', () {
      for (final host in stagingCertificateHosts) {
        expect(
          shouldEnableStagingCertificateTrust(
            environment: 'staging',
            apiBaseUri: Uri.parse('https://$host:8443'),
          ),
          isTrue,
          reason: host,
        );
      }

      for (final host in <String>[
        'backend-us-dev.lute-momcozylab.luteos.cloud',
        'agent-us-dev.lute-momcozylab.luteos.cloud',
      ]) {
        expect(
          shouldEnableStagingCertificateTrust(
            environment: 'staging',
            apiBaseUri: Uri.parse('https://$host'),
          ),
          isFalse,
          reason: 'B public CA endpoint must not load A private CA: $host',
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
          environment: 'staging',
          apiBaseUrl: 'https://lute-momcozylab.luteos.cloud:8443',
        ),
        (environment: 'staging', apiBaseUrl: 'https://api.example.test:8443'),
        (
          environment: 'staging',
          apiBaseUrl: 'https://backend-test.lute-momcozylab.luteos.cloud',
        ),
        (
          environment: 'staging',
          apiBaseUrl: 'http://backend-test.lute-momcozylab.luteos.cloud:8443',
        ),
      ]) {
        expect(
          shouldEnableStagingCertificateTrust(
            environment: candidate.environment,
            apiBaseUri: Uri.parse(candidate.apiBaseUrl),
          ),
          isFalse,
          reason: '${candidate.environment}: ${candidate.apiBaseUrl}',
        );
      }
    });

    test('does not load or install trust outside the staging target', () async {
      var loaderCalled = false;
      var installerCalled = false;

      final enabled = await configureStagingCertificateTrust(
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

        final enabled = await configureStagingCertificateTrust(
          environment: 'staging',
          apiBaseUrl: 'https://backend-test.lute-momcozylab.luteos.cloud:8443',
          securityContextInstaller: (context) => installedContext = context,
        );

        expect(enabled, isTrue);
        expect(installedContext, isNotNull);
      },
    );
  });
}
