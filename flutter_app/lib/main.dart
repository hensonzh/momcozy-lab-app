import 'package:flutter/material.dart';

import 'app/momcozy_app.dart';
import 'app/momcozy_api_runtime.dart';
import 'core/network/staging_certificate_trust.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureStagingCertificateTrust();
  final runtime = await MomCozyApiRuntime.bootstrap();
  runApp(MomCozyFlutterApp(apiRuntime: runtime));
}
