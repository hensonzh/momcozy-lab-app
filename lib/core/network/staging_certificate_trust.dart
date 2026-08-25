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

const stagingProductBackendHost = 'backend-test.lute-momcozylab.luteos.cloud';
const stagingAgentRuntimeHost = 'agent-test.lute-momcozylab.luteos.cloud';
const stagingCertificateHosts = <String>{
  stagingProductBackendHost,
  stagingAgentRuntimeHost,
};
const stagingCertificatePort = 8443;
const stagingCertificateAssetPath =
    'assets/certificates/momcozy-staging-internal-ca.pem';

typedef CertificateAssetLoader = Future<Uint8List> Function(String assetPath);
typedef SecurityContextInstaller = void Function(SecurityContext context);

bool shouldEnableStagingCertificateTrust({
  required String environment,
  required Uri apiBaseUri,
}) {
  return environment.trim().toLowerCase() == 'staging' &&
      apiBaseUri.scheme.toLowerCase() == 'https' &&
      stagingCertificateHosts.contains(apiBaseUri.host.toLowerCase()) &&
      apiBaseUri.port == stagingCertificatePort;
}

/// Adds the internal staging CA to Dart's trusted roots only when bootstrapping
/// one of the approved staging endpoints. Hostname, validity, and chain checks
/// remain enabled for every request.
Future<bool> configureStagingCertificateTrust({
  String environment = _configuredEnvironment,
  String apiBaseUrl = _configuredApiBaseUrl,
  CertificateAssetLoader? certificateLoader,
  SecurityContextInstaller? securityContextInstaller,
}) async {
  final apiBaseUri = Uri.tryParse(apiBaseUrl);
  if (apiBaseUri == null ||
      !shouldEnableStagingCertificateTrust(
        environment: environment,
        apiBaseUri: apiBaseUri,
      )) {
    return false;
  }

  final certificateBytes = await (certificateLoader ?? _loadCertificateAsset)(
    stagingCertificateAssetPath,
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
  HttpOverrides.global = _StagingCertificateHttpOverrides(context);
}

final class _StagingCertificateHttpOverrides extends HttpOverrides {
  _StagingCertificateHttpOverrides(this._securityContext);

  final SecurityContext _securityContext;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context ?? _securityContext);
  }
}
