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

    testWidgets('agent card matches the legacy guidance hierarchy', (
      tester,
    ) async {
      await _pumpScheduleComponentApp(tester);

      final card = find.byKey(const ValueKey('schedule-agent-card'));
      expect(card, findsOneWidget);
      expect(
        find.text('已经根据你今天的会议日程，对吸乳排期做了调整哦，记得按时吸奶，有问题随时找我'),
        findsOneWidget,
      );
      expect(find.text('提醒开关'), findsOneWidget);
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

    testWidgets('task row matches the compact legacy timeline baseline', (
      tester,
    ) async {
      await _pumpScheduleComponentApp(
        tester,
        tasks: const [
          {
            'id': 'golden-task',
            'plan_id': 'plan-1',
            'task_date': '2026-07-03',
            'task_time': '14:00',
            'title': '下午吸奶',
            'status': 'pending',
            'payload': {'task_type': 'pumping', 'source': 'agent_action'},
          },
        ],
      );

      final row = find.byKey(
        const ValueKey('schedule-timeline-task-golden-task'),
      );
      await tester.scrollUntilVisible(row, 200);
      await tester.pumpAndSettle();
      expect(row, findsOneWidget);
      await expectLater(
        row,
        matchesGoldenFile(
          '../../../goldens/component_parity/schedule_task_row.png',
        ),
      );
    });

    testWidgets('record row matches the compact legacy timeline baseline', (
      tester,
    ) async {
      await _pumpScheduleComponentApp(
        tester,
        pumpingRecords: const [
          {
            'id': 'golden-record',
            'plan_task_id': null,
            'pump_start_time': '2026-07-03T08:00:00Z',
            'milk_volume_ml': 120,
            'duration_seconds': 900,
            'title': '吸奶补录',
          },
        ],
      );

      final row = find.byKey(
        const ValueKey('schedule-timeline-record-golden-record'),
      );
      await tester.scrollUntilVisible(row, 200);
      await tester.pumpAndSettle();
      expect(row, findsOneWidget);
      await expectLater(
        row,
        matchesGoldenFile(
          '../../../goldens/component_parity/schedule_record_row.png',
        ),
      );
    });

    testWidgets('add task sheet matches the mobile legacy baseline', (
      tester,
    ) async {
      await _pumpScheduleComponentApp(tester);
      final addButton = find.byKey(const ValueKey('schedule-add-task-button'));
      await tester.scrollUntilVisible(addButton, 200);
      await tester.tap(addButton);
      await tester.pumpAndSettle();

      final sheet = find.byKey(const ValueKey('schedule-add-task-sheet'));
      expect(sheet, findsOneWidget);
      await expectLater(
        sheet,
        matchesGoldenFile(
          '../../../goldens/component_parity/schedule_add_task_sheet.png',
        ),
      );
    });

    testWidgets('time wheel sheet matches the mobile legacy baseline', (
      tester,
    ) async {
      await _pumpScheduleComponentApp(tester);
      final addButton = find.byKey(const ValueKey('schedule-add-task-button'));
      await tester.scrollUntilVisible(addButton, 200);
      await tester.tap(addButton);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('schedule-task-time-input')));
      await tester.pumpAndSettle();

      final sheet = find.byKey(const ValueKey('schedule-time-picker-sheet'));
      expect(sheet, findsOneWidget);
      await expectLater(
        sheet,
        matchesGoldenFile(
          '../../../goldens/component_parity/schedule_time_picker_sheet.png',
        ),
      );
    });
  });
}

Future<void> _pumpScheduleComponentApp(
  WidgetTester tester, {
  List<Map<String, Object?>> tasks = const [],
  List<Map<String, Object?>> pumpingRecords = const [],
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final transport = FixtureApiJsonTransportByPath({
    scheduleDayPlanEndpoint: {'items': tasks},
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
    schedulePumpingRecordsEndpoint: {'items': pumpingRecords},
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
