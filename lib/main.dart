import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'app/momcozy_app.dart';
import 'app/momcozy_api_runtime.dart';
import 'core/config/momcozy_app_capabilities.dart';
import 'core/network/test_certificate_trust.dart';
import 'core/storage/legacy_prenatal_data_cleaner.dart';
import 'core/update/app_release_lifecycle.dart';
import 'features/agent_hub/data/card_export.dart';
import 'features/media/data/product_asset_file_cache.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureTestCertificateTrust();
  await const LegacyPrenatalDataCleaner().cleanBestEffort();
  const capabilities = MomCozyAppCapabilities.fromEnvironment();
  final releasePolicy = await prepareAppReleaseLifecycle(
    enabled: capabilities.releaseResetLifecycleEnabled,
    loadReleaseId: () async => _releaseId(await PackageInfo.fromPlatform()),
    clearFileCache: _clearAccountFileCaches,
  );
  final runtime = await MomCozyApiRuntime.bootstrap();
  runApp(
    MomCozyFlutterApp(
      apiRuntime: runtime,
      capabilities: capabilities,
      onboardingReleasePolicy: releasePolicy,
    ),
  );
}

String _releaseId(PackageInfo packageInfo) {
  final version = packageInfo.version.trim();
  final buildNumber = packageInfo.buildNumber.trim();
  return buildNumber.isEmpty ? version : '$version+$buildNumber';
}

Future<void> _clearAccountFileCaches() async {
  await Future.wait([
    ProductAssetFileCache().clear(),
    const PlatformAgentCardExportService().clear(),
  ]);
}
