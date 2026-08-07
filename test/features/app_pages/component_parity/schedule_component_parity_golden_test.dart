import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/features/schedule/data/schedule_api_repository.dart';
import 'package:momcozy_flutter_app/features/schedule/domain/schedule_plan.dart';
import 'package:momcozy_flutter_app/features/schedule/domain/schedule_reminder.dart';
import 'package:momcozy_flutter_app/features/schedule/presentation/schedule_dashboard_page.dart';

import '../../../support/fixture_api_transport.dart';
import '../../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);

  group('Schedule feature-first component parity goldens', () {
    testWidgets('plan week header matches the supplied mobile baseline', (
      tester,
    ) async {
      await _pumpScheduleComponentApp(tester);

      final dateStrip = find.byKey(const ValueKey('schedule-date-strip'));
      expect(dateStrip, findsOneWidget);
      expect(find.text('My Plans'), findsOneWidget);
      expect(find.text('This Week'), findsAtLeastNWidgets(1));
      expect(find.text('Week'), findsOneWidget);
      await expectLater(
        dateStrip,
        matchesGoldenFile(
          '../../../goldens/component_parity/schedule_date_strip.png',
        ),
      );
    });

    testWidgets('agent card keeps guidance actions in the new plan style', (
      tester,
    ) async {
      await _pumpScheduleComponentApp(tester);

      final card = find.byKey(const ValueKey('schedule-agent-card'));
      await tester.scrollUntilVisible(card, 200);
      await tester.pumpAndSettle();
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

    testWidgets('task toolbar matches the supplied plan style', (tester) async {
      await _pumpScheduleComponentApp(tester);

      final toolbar = find.byKey(const ValueKey('schedule-list-toolbar'));
      await tester.ensureVisible(toolbar);
      await tester.pumpAndSettle();
      expect(toolbar, findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.byTooltip('调整日程'), findsOneWidget);
      expect(find.byTooltip('添加任务'), findsOneWidget);
      await expectLater(
        toolbar,
        matchesGoldenFile(
          '../../../goldens/component_parity/schedule_list_toolbar.png',
        ),
      );
    });

    testWidgets('task row matches the supplied plan card baseline', (
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

    testWidgets('inline task editor matches the compact legacy baseline', (
      tester,
    ) async {
      await _pumpScheduleComponentApp(
        tester,
        tasks: const [
          {
            'id': 'golden-edit-task',
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
        const ValueKey('schedule-timeline-task-golden-edit-task'),
      );
      await tester.scrollUntilVisible(row, 200);
      await tester.tap(row);
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey('schedule-inline-task-title-golden-edit-task'),
        ),
        findsOneWidget,
      );
      await expectLater(
        row,
        matchesGoldenFile(
          '../../../goldens/component_parity/schedule_inline_task_editor.png',
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

    testWidgets('pumping record sheet matches the legacy bottom sheet', (
      tester,
    ) async {
      await _pumpScheduleComponentApp(tester);
      final quickActions = find.byKey(const ValueKey('schedule-quick-actions'));
      await tester.scrollUntilVisible(quickActions, 200);
      await tester.tap(
        find.descendant(of: quickActions, matching: find.text('吸奶补录')),
      );
      await tester.pumpAndSettle();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      final sheet = find.byKey(const ValueKey('schedule-pumping-record-sheet'));
      expect(sheet, findsOneWidget);
      expect(find.text('🤱 吸奶补录'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('schedule-pumping-record-description')),
        findsOneWidget,
      );
      await expectLater(
        sheet,
        matchesGoldenFile(
          '../../../goldens/component_parity/schedule_pumping_record_sheet.png',
        ),
      );
    });

    testWidgets('feeding record sheet matches the legacy bottom sheet', (
      tester,
    ) async {
      await _pumpScheduleComponentApp(tester);
      final quickActions = find.byKey(const ValueKey('schedule-quick-actions'));
      await tester.scrollUntilVisible(quickActions, 200);
      await tester.tap(
        find.descendant(of: quickActions, matching: find.text('喂养记录')),
      );
      await tester.pumpAndSettle();

      final sheet = find.byKey(const ValueKey('schedule-feeding-record-sheet'));
      expect(sheet, findsOneWidget);
      expect(find.text('+ 喂养记录'), findsOneWidget);
      expect(find.text('🧪 配方奶'), findsOneWidget);
      expect(find.text('🤱 亲喂'), findsOneWidget);
      expect(find.text('🍼 瓶喂母乳'), findsOneWidget);
      await expectLater(
        sheet,
        matchesGoldenFile(
          '../../../goldens/component_parity/schedule_feeding_record_sheet.png',
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

    testWidgets('task explanation dialog matches the legacy overlay', (
      tester,
    ) async {
      await _pumpScheduleComponentApp(tester);
      final helpButton = find.byKey(
        const ValueKey('schedule-task-help-button'),
      );
      await tester.scrollUntilVisible(helpButton, 200);
      await tester.tap(helpButton);
      await tester.pumpAndSettle();

      final dialog = find.byKey(
        const ValueKey('schedule-task-explanation-dialog'),
      );
      expect(dialog, findsOneWidget);
      await expectLater(
        dialog,
        matchesGoldenFile(
          '../../../goldens/component_parity/schedule_task_explanation_dialog.png',
        ),
      );
    });

    testWidgets('reminder warning matches the legacy confirmation overlay', (
      tester,
    ) async {
      await _pumpScheduleComponentApp(tester, reminderEnabled: true);
      await tester.tap(
        find.byKey(const ValueKey('schedule-context-reminder-button')),
      );
      await tester.pumpAndSettle();

      final dialog = find.byKey(
        const ValueKey('schedule-reminder-confirm-dialog'),
      );
      expect(dialog, findsOneWidget);
      await expectLater(
        dialog,
        matchesGoldenFile(
          '../../../goldens/component_parity/schedule_reminder_warning.png',
        ),
      );
    });
  });
}

Future<void> _pumpScheduleComponentApp(
  WidgetTester tester, {
  List<Map<String, Object?>> tasks = const [],
  List<Map<String, Object?>> pumpingRecords = const [],
  bool reminderEnabled = false,
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
          reminderGateway: const _GoldenReminderGateway(),
          reminderPreferenceStore: _GoldenReminderStore(reminderEnabled),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _GoldenReminderGateway implements ScheduleReminderGateway {
  const _GoldenReminderGateway();

  @override
  bool get isSupported => true;

  @override
  Future<bool> setEnabled({
    required bool enabled,
    required List<ScheduleTask> tasks,
  }) async => true;
}

class _GoldenReminderStore implements ScheduleReminderPreferenceStore {
  const _GoldenReminderStore(this.enabled);

  final bool enabled;

  @override
  Future<bool> readEnabled() async => enabled;

  @override
  Future<void> writeEnabled(bool enabled) async {}
}
