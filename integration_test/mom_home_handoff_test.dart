import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import '../test/support/mom_home_handoff_scenarios.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.shouldPropagateDevicePointerEvents = true;
  testWidgets(
    'Android Mom handoff three states and navigation callbacks',
    (tester) async {
      var converted = false;
      for (final scale in [1.0, 2.0]) {
        for (final state in ['initial', 'recorded', 'purchased']) {
          await verifyMomHandoff(
            tester,
            scenario: HandoffScenario(
              recorded: state != 'initial',
              purchased: state == 'purchased',
            ),
            scale: scale,
            capture: (part) async {
              await tester.pump(const Duration(milliseconds: 100));
              if (!converted) {
                await binding.convertFlutterSurfaceToImage();
                converted = true;
                await tester.pump();
              }
              final name = 'native-mom-handoff-$state-$part-${scale.toInt()}x';
              final bytes = await binding.takeScreenshot(name);
              final directory = await getApplicationDocumentsDirectory();
              await File('${directory.path}/$name.png').writeAsBytes(bytes);
            },
          );
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
