import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import '../test/support/agent_message_menu_scenarios.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Navigator cancels the active long press when it pushes the popup route.
  // Live tests otherwise drop that framework-generated device-source event.
  binding.shouldPropagateDevicePointerEvents = true;
  testWidgets(
    'Android message copy, retry and return',
    (tester) async {
      var converted = false;
      for (final scale in [1.0, 2.0]) {
        await verifyAgentMessageMenu(
          tester,
          scale: scale,
          capture: (state) async {
            if (!converted) {
              await binding.convertFlutterSurfaceToImage();
              converted = true;
              await tester.pump();
            }
            final name = 'native-agent-menu-$state-${scale.toInt()}x';
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
