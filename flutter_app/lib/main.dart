import 'package:flutter/material.dart';

import 'app/momcozy_app.dart';
import 'app/momcozy_api_runtime.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final runtime = await MomCozyApiRuntime.bootstrap();
  runApp(MomCozyFlutterApp(apiRuntime: runtime));
}
