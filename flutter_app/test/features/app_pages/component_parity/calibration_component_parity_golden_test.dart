import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/native/p0_platform_interfaces.dart';

import '../../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);

  group('Calibration component parity goldens', () {
    testWidgets('intro step card matches compact baseline', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final routeIntentPlatform = FakeRouteIntentPlatform();
      addTearDown(routeIntentPlatform.dispose);

      await tester.pumpWidget(
        RepaintBoundary(
          child: MomCozyFlutterApp(
            router: createMomCozyRouter(initialLocation: '/calibration'),
            routeIntentPlatform: routeIntentPlatform,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final introCard = find.byKey(
        const ValueKey('calibration-intro-step-card'),
      );
      expect(introCard, findsOneWidget);
      expect(find.text('动作确认 1'), findsOneWidget);
      expect(find.text('请先正确穿戴吸奶器'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, '我已穿戴好'), findsOneWidget);

      await expectLater(
        introCard,
        matchesGoldenFile(
          '../../../goldens/component_parity/calibration_intro_step_card.png',
        ),
      );
    });
  });
}
