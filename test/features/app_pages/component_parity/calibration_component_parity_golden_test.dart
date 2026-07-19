import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/native/p0_platform_interfaces.dart';

import '../../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);

  group('Calibration component parity goldens', () {
    testWidgets('top bar matches compact baseline', (tester) async {
      await _pumpCalibrationComponentApp(tester);

      final topBar = find.byKey(const ValueKey('calibration-top-bar'));
      expect(topBar, findsOneWidget);
      expect(find.text('舒适负压调节'), findsOneWidget);
      expect(find.text('1/7'), findsOneWidget);

      await expectLater(
        topBar,
        matchesGoldenFile(
          '../../../goldens/component_parity/calibration_top_bar.png',
        ),
      );
    });

    testWidgets('intro step card matches compact baseline', (tester) async {
      await _pumpCalibrationComponentApp(tester);

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

Future<void> _pumpCalibrationComponentApp(WidgetTester tester) async {
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
}
