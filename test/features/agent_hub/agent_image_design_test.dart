@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/agent_image_scenarios.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'image metadata, empty response, retry and zoom $width/$scale',
        (tester) async {
          tester.view.physicalSize = Size(width, 568);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          Future<void> capture(String state) async {
            expect(tester.takeException(), isNull);
            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile(
                '../../goldens/design_system/agent-image-$state-${width.toInt()}-${scale.toInt()}x.png',
              ),
            );
          }

          await verifyAgentImage(tester, scale: scale, capture: capture);
          await verifyUnavailableAgentImage(
            tester,
            scale: scale,
            capture: capture,
          );
        },
      );
    }
  }
}
