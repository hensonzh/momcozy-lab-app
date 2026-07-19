import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/app/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/features/status/data/status_api_repository.dart';
import 'package:momcozy_flutter_app/native/p0_platform_interfaces.dart';

import '../../../support/fixture_api_transport.dart';
import '../../../support/fake_agent_voice.dart';
import '../../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);

  group('Status component parity goldens', () {
    testWidgets('profile selector matches compact baseline', (tester) async {
      await _pumpStatusComponentApp(tester);

      final selector = find.byKey(const ValueKey('status-profile-selector'));
      expect(selector, findsOneWidget);
      expect(
        find.byKey(const ValueKey('status-care-stage-postpartum')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('status-identity-tab-mom')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('status-identity-tab-baby')),
        findsOneWidget,
      );

      await expectLater(
        selector,
        matchesGoldenFile(
          '../../../goldens/component_parity/status_profile_selector.png',
        ),
      );
    });

    testWidgets('postpartum mom module grid matches compact baseline', (
      tester,
    ) async {
      await _pumpStatusComponentApp(tester);

      final grid = find.byKey(
        const ValueKey('status-postpartum-mom-module-grid'),
      );
      expect(grid, findsOneWidget);
      expect(
        find.byKey(const ValueKey('status-module-milk-output')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('status-module-breast-health')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('status-module-postpartum-recovery')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('status-module-rest-nutrition')),
        findsOneWidget,
      );

      await expectLater(
        grid,
        matchesGoldenFile(
          '../../../goldens/component_parity/status_postpartum_mom_module_grid.png',
        ),
      );
    });

    testWidgets('breast health module card matches compact baseline', (
      tester,
    ) async {
      await _pumpStatusComponentApp(tester);

      final card = find.byKey(const ValueKey('status-module-breast-health'));
      expect(card, findsOneWidget);
      expect(find.text('乳房健康'), findsOneWidget);
      expect(find.text('查看《乳房健康日记》'), findsOneWidget);

      await expectLater(
        card,
        matchesGoldenFile(
          '../../../goldens/component_parity/status_breast_health_module_card.png',
        ),
      );
    });

    testWidgets('postpartum mom trend card matches compact baseline', (
      tester,
    ) async {
      await _pumpStatusComponentApp(tester);

      final trend = find.byKey(const ValueKey('status-milk-trend-preview'));
      expect(trend, findsOneWidget);
      expect(find.text('母乳趋势'), findsOneWidget);
      expect(find.text('周'), findsWidgets);

      await expectLater(
        trend,
        matchesGoldenFile(
          '../../../goldens/component_parity/status_milk_trend_preview.png',
        ),
      );
    });
  });
}

Future<void> _pumpStatusComponentApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final routeIntentPlatform = FakeRouteIntentPlatform();
  addTearDown(routeIntentPlatform.dispose);

  await tester.pumpWidget(
    RepaintBoundary(
      child: MomCozyFlutterApp(
        router: createMomCozyRouter(initialLocation: '/status'),
        routeIntentPlatform: routeIntentPlatform,
        apiRuntime: MomCozyApiRuntime(
          jsonTransport: FixtureApiJsonTransportByPath({
            statusOverviewEndpoint: const {
              'http_status': 503,
              'status_text': 'Service Unavailable',
            },
          }),
          agentVoicePlaybackPlayer: const ImmediateAgentVoicePlaybackPlayer(),
          blePlatform: FakeBlePlatform(
            initialPermission: BlePermissionState.granted,
          ),
          userId: 'demo-user-status-component-parity',
          babyId: 'demo-baby-status-component-parity',
          locale: 'zh-CN',
          now: () => DateTime.utc(2026, 7, 3),
        ),
      ),
    ),
  );
  await tester.pump();

  final appContext = tester.element(find.byType(MomCozyFlutterApp));
  await tester.runAsync(() async {
    await Future.wait([
      precacheImage(const AssetImage(MomCozyAssets.agentAvatar), appContext),
      precacheImage(const AssetImage(MomCozyAssets.momAvatar), appContext),
      precacheImage(const AssetImage(MomCozyAssets.babyAvatar), appContext),
    ]).timeout(const Duration(seconds: 5));
  });
  await tester.pumpAndSettle();
  await _settleVisibleStatusResources(tester);
}

Future<void> _settleVisibleStatusResources(WidgetTester tester) async {
  const loadingCopy = '正在加载最近一个月泌乳数据…';
  for (var frame = 0; frame < 30; frame += 1) {
    if (find.text(loadingCopy).evaluate().isEmpty) return;
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(find.text(loadingCopy), findsNothing);
}
