import 'dart:io';

import 'package:flutter/services.dart';

const _configuredEnvironment = String.fromEnvironment(
  'MOMCOZY_ENV',
  defaultValue: 'local',
);
const _configuredApiBaseUrl = String.fromEnvironment(
  'MOMCOZY_API_BASE_URL',
  defaultValue: 'http://127.0.0.1:8769',
);

const testProductBackendHost = 'backend-test.lute-momcozylab.luteos.cloud';
const testAgentRuntimeHost = 'agent-test.lute-momcozylab.luteos.cloud';
const testCertificateHosts = <String>{
  testProductBackendHost,
  testAgentRuntimeHost,
};
const testCertificatePort = 8443;
const testCertificateAssetPath =
    'assets/certificates/momcozy-test-internal-ca.pem';

typedef CertificateAssetLoader = Future<Uint8List> Function(String assetPath);
typedef SecurityContextInstaller = void Function(SecurityContext context);

bool shouldEnableTestCertificateTrust({
  required String environment,
  required Uri apiBaseUri,
}) {
  return environment.trim().toLowerCase() == 'test' &&
      apiBaseUri.scheme.toLowerCase() == 'https' &&
      testCertificateHosts.contains(apiBaseUri.host.toLowerCase()) &&
      apiBaseUri.port == testCertificatePort;
}

/// Adds the internal test CA to Dart's trusted roots only when bootstrapping
/// one of the approved test endpoints. Hostname, validity, and chain checks
/// remain enabled for every request.
Future<bool> configureTestCertificateTrust({
  String environment = _configuredEnvironment,
  String apiBaseUrl = _configuredApiBaseUrl,
  CertificateAssetLoader? certificateLoader,
  SecurityContextInstaller? securityContextInstaller,
}) async {
  final apiBaseUri = Uri.tryParse(apiBaseUrl);
  if (apiBaseUri == null ||
      !shouldEnableTestCertificateTrust(
        environment: environment,
        apiBaseUri: apiBaseUri,
      )) {
    return false;
  }

  final certificateBytes = await (certificateLoader ?? _loadCertificateAsset)(
    testCertificateAssetPath,
  );
  final context = SecurityContext(withTrustedRoots: true)
    ..setTrustedCertificatesBytes(certificateBytes);
  (securityContextInstaller ?? _installGlobalSecurityContext)(context);
  return true;
}

Future<Uint8List> _loadCertificateAsset(String assetPath) async {
  final data = await rootBundle.load(assetPath);
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

void _installGlobalSecurityContext(SecurityContext context) {
  HttpOverrides.global = _TestCertificateHttpOverrides(context);
}

final class _TestCertificateHttpOverrides extends HttpOverrides {
  _TestCertificateHttpOverrides(this._securityContext);

  final SecurityContext _securityContext;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context ?? _securityContext);
  }
}
