import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/native/p0_platform_interfaces.dart';

import '../../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);

  group('Pump component parity goldens', () {
    testWidgets('calibration prompt matches compact baseline', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final routeIntentPlatform = FakeRouteIntentPlatform();
      addTearDown(routeIntentPlatform.dispose);

      await tester.pumpWidget(
        RepaintBoundary(
          child: MomCozyFlutterApp(
            router: createMomCozyRouter(initialLocation: '/pump'),
            routeIntentPlatform: routeIntentPlatform,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final prompt = find.byKey(const ValueKey('pump-calibration-prompt-card'));
      expect(prompt, findsOneWidget);
      expect(find.text('个性化舒适档位'), findsOneWidget);
      expect(find.text('先跳过'), findsOneWidget);
      expect(find.text('开始滴定'), findsOneWidget);

      await expectLater(
        prompt,
        matchesGoldenFile(
          '../../../goldens/component_parity/pump_calibration_prompt.png',
        ),
      );
    });

    testWidgets('metric console matches compact baseline', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final routeIntentPlatform = FakeRouteIntentPlatform();
      addTearDown(routeIntentPlatform.dispose);

      await tester.pumpWidget(
        RepaintBoundary(
          child: MomCozyFlutterApp(
            router: createMomCozyRouter(initialLocation: '/pump'),
            routeIntentPlatform: routeIntentPlatform,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final console = find.byKey(const ValueKey('pump-metric-console'));
      expect(console, findsOneWidget);
      expect(find.text('吸乳量'), findsOneWidget);
      expect(find.text('本次吸乳进度'), findsOneWidget);

      await expectLater(
        console,
        matchesGoldenFile(
          '../../../goldens/component_parity/pump_metric_console.png',
        ),
      );
    });

    testWidgets('control console matches compact baseline', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final routeIntentPlatform = FakeRouteIntentPlatform();
      addTearDown(routeIntentPlatform.dispose);

      await tester.pumpWidget(
        RepaintBoundary(
          child: MomCozyFlutterApp(
            router: createMomCozyRouter(initialLocation: '/pump'),
            routeIntentPlatform: routeIntentPlatform,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final console = find.byKey(const ValueKey('pump-control-console'));
      expect(console, findsOneWidget);
      expect(find.text('设备控制'), findsOneWidget);
      expect(find.text('自动托管'), findsOneWidget);
      expect(find.text('手动调整'), findsOneWidget);
      expect(find.text('刺激模式'), findsOneWidget);
      expect(find.text('吸乳模式'), findsOneWidget);

      await expectLater(
        console,
        matchesGoldenFile(
          '../../../goldens/component_parity/pump_control_console.png',
        ),
      );
    });
  });
}
