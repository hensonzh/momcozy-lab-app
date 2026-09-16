import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/momcozy_test_fonts.dart';
import '../../support/onboarding_reading_scenarios.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('onboarding reading $width/$scale', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await verifyOnboardingReading(
          tester,
          scale: scale,
          capture: (state) => expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              '../../goldens/design_system/onboarding-reading-$state-${width.toInt()}-${scale.toInt()}x.png',
            ),
          ),
        );
      });
    }
  }
}
