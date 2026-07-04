import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/features/schedule/data/schedule_api_repository.dart';
import 'package:momcozy_flutter_app/native/p0_platform_interfaces.dart';

import '../../../support/fixture_api_transport.dart';
import '../../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);

  group('Schedule component parity goldens', () {
    testWidgets('date strip matches compact baseline', (tester) async {
      await _pumpScheduleComponentApp(tester);

      final dateStrip = find.byKey(const ValueKey('schedule-date-strip'));
      expect(dateStrip, findsOneWidget);
      expect(find.text('2026年7月'), findsOneWidget);
      expect(find.text('今'), findsOneWidget);

      await expectLater(
        dateStrip,
        matchesGoldenFile(
          '../../../goldens/component_parity/schedule_date_strip.png',
        ),
      );
    });

    testWidgets('agent card matches compact baseline', (tester) async {
      await _pumpScheduleComponentApp(tester);

      final card = find.byKey(const ValueKey('schedule-agent-card'));
      expect(card, findsOneWidget);
      expect(find.text('提醒开关'), findsOneWidget);
      expect(find.text('对话'), findsOneWidget);

      await expectLater(
        card,
        matchesGoldenFile(
          '../../../goldens/component_parity/schedule_agent_card.png',
        ),
      );
    });

    testWidgets('empty task card matches compact baseline', (tester) async {
      await _pumpScheduleComponentApp(tester);

      final emptyCard = find.byKey(const ValueKey('schedule-empty-task-card'));
      expect(emptyCard, findsOneWidget);
      expect(find.text('今天还没有计划任务'), findsOneWidget);
      expect(find.text('可以先从对话里生成计划并同步到日历，或手动添加任务。'), findsOneWidget);

      await expectLater(
        emptyCard,
        matchesGoldenFile(
          '../../../goldens/component_parity/schedule_empty_task_card.png',
        ),
      );
    });
  });
}

Future<void> _pumpScheduleComponentApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final routeIntentPlatform = FakeRouteIntentPlatform();
  addTearDown(routeIntentPlatform.dispose);

  await tester.pumpWidget(
    RepaintBoundary(
      child: MomCozyFlutterApp(
        router: createMomCozyRouter(initialLocation: '/schedule'),
        routeIntentPlatform: routeIntentPlatform,
        apiRuntime: MomCozyApiRuntime(
          jsonTransport: FixtureApiJsonTransportByPath({
            scheduleDayPlanEndpoint: const <String, Object?>{
              'status': 200,
              'data': <String, Object?>{'tasks': <Object?>[]},
            },
          }),
          blePlatform: FakeBlePlatform(
            initialPermission: BlePermissionState.granted,
          ),
          userId: 'demo-user-schedule-component-parity',
          babyId: 'demo-baby-schedule-component-parity',
          locale: 'zh-CN',
          now: () => DateTime.utc(2026, 7, 3),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
