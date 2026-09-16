import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import '../test/support/agent_form_scenarios.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.shouldPropagateDevicePointerEvents = true;
  testWidgets(
    'Android form validation, draft, retry and submission',
    (tester) async {
      var converted = false;
      for (final scale in [1.0, 2.0]) {
        await verifyAgentForm(
          tester,
          scale: scale,
          capture: (state) async {
            await tester.pump(const Duration(milliseconds: 100));
            if (!converted) {
              await binding.convertFlutterSurfaceToImage();
              converted = true;
              await tester.pump();
            }
            final name = 'native-agent-form-$state-${scale.toInt()}x';
            final bytes = await binding.takeScreenshot(name);
            final directory = await getApplicationDocumentsDirectory();
            await File('${directory.path}/$name.png').writeAsBytes(bytes);
          },
        );
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
