import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import '../test/support/motion_preference_scenarios.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android reduced motion selection, feedback and history',
    (tester) async {
      var converted = false;
      for (final scale in [1.0, 2.0]) {
        await verifyMotionPreference(
          tester,
          scale: scale,
          capture: (state) async {
            // State assertions above use unelapsed frames. Capture after layout
            // and the test tap indicators have settled so evidence shows content.
            await tester.pumpAndSettle();
            if (!converted) {
              await binding.convertFlutterSurfaceToImage();
              converted = true;
              await tester.pump();
            }
            final name = 'native-reduced-$state-${scale.toInt()}x';
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
