import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/features/schedule/data/schedule_api_repository.dart';
import 'package:momcozy_flutter_app/features/schedule/presentation/schedule_dashboard_page.dart';

import '../../../support/fixture_api_transport.dart';
import '../../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);

  group('Schedule feature-first component parity goldens', () {
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

    testWidgets('agent card uses live plan context', (tester) async {
      await _pumpScheduleComponentApp(tester);

      final card = find.byKey(const ValueKey('schedule-agent-card'));
      expect(card, findsOneWidget);
      expect(find.textContaining('稳奶计划 · 产后第29周（离乳期）'), findsOneWidget);
      expect(find.text('提醒'), findsOneWidget);
      expect(find.text('对话'), findsOneWidget);
      await expectLater(
        card,
        matchesGoldenFile(
          '../../../goldens/component_parity/schedule_agent_card.png',
        ),
      );
    });

    testWidgets('empty task hero matches compact baseline', (tester) async {
      await _pumpScheduleComponentApp(tester);

      final card = find.byKey(const ValueKey('schedule-empty-task-card'));
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      expect(card, findsOneWidget);
      expect(find.text('今天还没有计划任务'), findsOneWidget);
      await expectLater(
        card,
        matchesGoldenFile(
          '../../../goldens/component_parity/schedule_empty_task_card.png',
        ),
      );
    });

    testWidgets('task toolbar matches compact baseline', (tester) async {
      await _pumpScheduleComponentApp(tester);

      final toolbar = find.byKey(const ValueKey('schedule-list-toolbar'));
      await tester.ensureVisible(toolbar);
      await tester.pumpAndSettle();
      expect(toolbar, findsOneWidget);
      expect(find.text('今日任务'), findsWidgets);
      expect(find.text('调整日程'), findsOneWidget);
      expect(find.text('添加任务'), findsOneWidget);
      await expectLater(
        toolbar,
        matchesGoldenFile(
          '../../../goldens/component_parity/schedule_list_toolbar.png',
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
  final transport = FixtureApiJsonTransportByPath({
    scheduleDayPlanEndpoint: const {'items': <Object?>[]},
    schedulePlansEndpoint: const {
      'items': [
        {
          'id': 'plan-1',
          'plan_type': 'milk_management',
          'title': '稳奶计划',
          'summary': '按当前阶段稳步执行',
          'status': 'active',
          'version': 3,
          'payload': {'postpartum_week': 29, 'phase': '离乳期'},
        },
      ],
    },
    scheduleFeedingRecordsEndpoint: const {'items': <Object?>[]},
    schedulePumpingRecordsEndpoint: const {'items': <Object?>[]},
  });

  await tester.pumpWidget(
    MaterialApp(
      theme: momCozyTheme(),
      home: Scaffold(
        body: ScheduleDashboardPage(
          repository: ScheduleApiRepository(transport: transport),
          now: () => DateTime.utc(2026, 7, 3, 10),
          onOpenAgent: () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
