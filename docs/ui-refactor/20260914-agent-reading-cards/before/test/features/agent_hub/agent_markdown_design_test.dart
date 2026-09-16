import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import '../../support/agent_markdown_scenarios.dart';
import '../../support/fake_video_player_platform.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);
  setUp(() => VideoPlayerPlatform.instance = FakeVideoPlayerPlatform());
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('markdown reading $width/$scale', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await verifyAgentMarkdown(
          tester,
          scale: scale,
          capture: (state) => expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              '../../goldens/design_system/agent-markdown-$state-${width.toInt()}-${scale.toInt()}x.png',
            ),
          ),
        );
      });
    }
  }
}
