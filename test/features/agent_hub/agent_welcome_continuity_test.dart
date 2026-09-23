import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import '../../support/agent_conversation_scenarios.dart';
import '../../support/fake_video_player_platform.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);
  setUp(() => VideoPlayerPlatform.instance = FakeVideoPlayerPlatform());

  testWidgets(
    'welcome stays unchanged through replies, retries and follow-ups',
    (tester) async {
      const size = Size(393, 844);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await verifyAgentConversation(
        tester,
        scale: 1,
        capture: (state) async {
          final directory = Platform.environment['COZYMATE_CAPTURE_DIR'];
          if (directory == null) return;
          final layer =
              tester.binding.renderViews.first.debugLayer! as OffsetLayer;
          await tester.runAsync(() async {
            await Directory(directory).create(recursive: true);
            final image = await layer.toImage(Offset.zero & size);
            final png = await image.toByteData(format: ui.ImageByteFormat.png);
            await File(
              '$directory/$state.png',
            ).writeAsBytes(png!.buffer.asUint8List());
            image.dispose();
          });
        },
      );
    },
  );
}
