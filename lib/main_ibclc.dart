import 'package:flutter/material.dart';
import 'app/ibclc/workbench_app.dart';
import 'app/ibclc/workbench_runtime.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  const apiBaseUrl = String.fromEnvironment(
    'MOMCOZY_API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );
  runApp(
    MomCozyWorkbenchApp(
      runtime: WorkbenchRuntime(baseUri: Uri.parse(apiBaseUrl)),
    ),
  );
}
