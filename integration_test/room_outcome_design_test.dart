import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import '../test/support/room_outcome_scenarios.dart';

// Controlled API-shaped data; no remote consultation or account mutation.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.shouldPropagateDevicePointerEvents = true;
  testWidgets(
    'Android unsuccessful consultation recovery destinations',
    (tester) async {
      final fixture = Map<String, Object?>.from(
        jsonDecode(
              utf8.decode(
                base64Decode(
                  const String.fromEnvironment('ROOM_FIXTURE_BASE64'),
                ),
              ),
            )
            as Map,
      );
      var converted = false;
      for (final scale in [1.0, 2.0]) {
        await verifyRoomOutcomes(
          tester,
          fixture: fixture,
          scale: scale,
          capture: (state) async {
            if (!converted) {
              await binding.convertFlutterSurfaceToImage();
              converted = true;
            }
            await tester.pump();
            final name = 'native-room-$state-${scale.toInt()}x';
            final bytes = await binding.takeScreenshot(name);
            final directory = await getApplicationDocumentsDirectory();
            await File('${directory.path}/$name.png').writeAsBytes(bytes);
          },
        );
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
