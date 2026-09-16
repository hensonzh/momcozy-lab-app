import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import '../test/support/agent_attachment_scenarios.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android attachment layout and local draft actions',
    (tester) async {
      var converted = false;
      for (final scale in [1.0, 2.0]) {
        Future<void> capture(String state) async {
          await tester.pump(const Duration(milliseconds: 100));
          if (!converted) {
            await binding.convertFlutterSurfaceToImage();
            converted = true;
            await tester.pump();
          }
          final name = 'native-attachment-$state-${scale.toInt()}x';
          final bytes = await binding.takeScreenshot(name);
          final directory = await getApplicationDocumentsDirectory();
          await File('${directory.path}/$name.png').writeAsBytes(bytes);
        }

        await verifyAgentAttachments(tester, scale: scale, capture: capture);
        await verifyAgentSentFiles(tester, scale: scale, capture: capture);
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
