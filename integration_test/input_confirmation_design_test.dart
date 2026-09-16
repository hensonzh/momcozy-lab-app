import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import '../test/support/input_confirmation_scenarios.dart';

void main() {
  const reducedMotion = bool.fromEnvironment('MOMCOZY_TEST_REDUCED_MOTION');
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android input and discard flows at 1x and 2x',
    (tester) async {
      var converted = false;
      for (final scale in [1.0, 2.0]) {
        await verifyInputConfirmation(
          tester,
          scale: scale,
          reducedMotion: reducedMotion,
          capture: (state) async {
            if (!converted) {
              await binding.convertFlutterSurfaceToImage();
              converted = true;
              await tester.pump();
            }
            final name =
                'native-input-$state-${scale.toInt()}x${reducedMotion ? '-reduced' : ''}';
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
