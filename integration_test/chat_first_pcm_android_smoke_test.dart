import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:momcozy_flutter_app/features/agent_hub/data/chat_first_voice.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native PCM16 playback accepts incremental frames and stops', (
    tester,
  ) async {
    const player = NativeChatFirstPcmPlayer();
    final pcm = Uint8List(24000 * 2 ~/ 5);
    final samples = ByteData.sublistView(pcm);
    for (var i = 0; i < pcm.length ~/ 2; i++) {
      samples.setInt16(
        i * 2,
        (math.sin(2 * math.pi * 440 * i / 24000) * 2500).round(),
        Endian.little,
      );
    }
    await player.start();
    await player.write(Uint8List.sublistView(pcm, 0, pcm.length ~/ 2));
    await player.write(Uint8List.sublistView(pcm, pcm.length ~/ 2));
    await player.finish();
    await player.stop();
  });
}
