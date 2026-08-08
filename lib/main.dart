import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'app/momcozy_app.dart';
import 'app/momcozy_api_runtime.dart';
import 'core/network/staging_certificate_trust.dart';
import 'core/update/app_release_lifecycle.dart';
import 'features/agent_hub/data/card_export.dart';
import 'features/media/data/product_asset_file_cache.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureStagingCertificateTrust();
  final packageInfo = await PackageInfo.fromPlatform();
  final lifecycle = AppReleaseLifecycle(
    releaseId: _releaseId(packageInfo),
    clearFileCache: _clearAccountFileCaches,
  );
  await lifecycle.prepareForLaunch();
  final runtime = await MomCozyApiRuntime.bootstrap();
  runApp(
    MomCozyFlutterApp(apiRuntime: runtime, onboardingReleasePolicy: lifecycle),
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
