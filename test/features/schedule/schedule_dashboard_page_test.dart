import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/app/momcozy_design_system.dart';
import 'package:app/core/agent_stream/agent_stream_event.dart';
import 'package:app/core/preferences/volume_unit_preference.dart';
import 'package:app/features/schedule/data/schedule_api_repository.dart';
import 'package:app/features/schedule/domain/schedule_plan.dart';
import 'package:app/features/schedule/domain/milk_plan_change_store.dart';
import 'package:app/features/schedule/domain/schedule_image_recognition.dart';
import 'package:app/features/schedule/domain/schedule_reminder.dart';
import 'package:app/features/schedule/presentation/schedule_dashboard_page.dart';

import '../../support/fixture_api_transport.dart';

void main() {
  testWidgets('renders dynamic context and a deduplicated mixed timeline', (
    tester,
  ) async {
    final transport = _transport();
    await _pumpPage(tester, transport);

    expect(
      find.byKey(const ValueKey('schedule-fixed-date-area')),
      findsOneWidget,
    );
    expect(find.text('稳奶计划执行中'), findsOneWidget);
    expect(find.text('产后第29周（离乳期）'), findsOneWidget);
    expect(find.text('2/2'), findsOneWidget);
    expect(find.byKey(const ValueKey('schedule-agent-card')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('schedule-context-progress')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('schedule-quick-actions')),
      250,
      scrollable: _scheduleScrollable(),
    );
    expect(
      find.byKey(const ValueKey('schedule-quick-actions')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('schedule-timeline-task-task-feed')),
      250,
      scrollable: _scheduleScrollable(),
    );
    expect(find.text('80 mL · 22:00 完成'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('schedule-timeline-task-task-feed')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('schedule-timeline-record-feed-1')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('schedule-timeline-task-task-feed')),
        matching: find.byType(Checkbox),
      ),
      findsNothing,
    );
    expect(find.byTooltip('已有执行记录，请先删除关联记录'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('schedule-task-source-task-pump')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('schedule-task-source-task-feed')),
      findsOneWidget,
    );
    expect(find.text('稳奶计划'), findsOneWidget);
    expect(find.text('手动添加'), findsOneWidget);
    expect(find.text('private-agent-action-id'), findsNothing);
  });

  testWidgets(
    'uses the actual delivery date and selected day instead of stale plan stage',
    (tester) async {
      await _pumpPage(
        tester,
        _transport(),
        deliveryDateLoader: () async => DateTime(2026, 6, 30),
      );

      expect(find.text('产后第1周（初乳期）'), findsOneWidget);
      expect(find.text('产后第29周（离乳期）'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('schedule-date-2026-07-04')));
      await tester.pumpAndSettle();

      expect(find.text('产后第1周（建立期）'), findsOneWidget);
    },
  );

  testWidgets('keeps the plan payload stage when no actual date exists', (
    tester,
  ) async {
    await _pumpPage(tester, _transport(), deliveryDateLoader: () async => null);

    expect(find.text('产后第29周（离乳期）'), findsOneWidget);
  });

  testWidgets('displays schedule quantities in the account volume unit', (
    tester,
  ) async {
    await _pumpPage(
      tester,
      _transport(),
      volumeUnitPreferenceStore: _FakeVolumeUnitPreferenceStore(
        MomCozyVolumeUnit.ounces,
      ),
    );

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('schedule-timeline-task-task-feed')),
      250,
      scrollable: _scheduleScrollable(),
    );
    expect(find.text('2.7 oz · 22:00 完成'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('schedule-timeline-record-pump-1')),
      250,
      scrollable: _scheduleScrollable(),
    );
    expect(find.textContaining('4.1 oz'), findsOneWidget);
    expect(
      tester
          .getSemantics(
            find.byKey(const ValueKey('schedule-timeline-record-pump-1')),
          )
          .label,
      contains('4.1 oz'),
    );
  });

  testWidgets(
    'ounce record inputs send canonical mL for pumping sides and feeding',
    (tester) async {
      final transport = _transport(
        tasks: const [],
        feedingRecords: const [],
        pumpingRecords: const [],
        writeResponsesByPath: const {
          schedulePumpingRecordsEndpoint: {
            'id': 'pump-created',
            'plan_task_id': null,
            'pump_start_time': '2026-07-03T10:00:00Z',
            'milk_volume_ml': 98,
            'title': '吸奶补录',
          },
          scheduleFeedingRecordsEndpoint: {
            'id': 'feed-created',
            'plan_task_id': null,
            'feed_time': '2026-07-03T10:00:00Z',
            'feed_type': 'formula',
            'volume_ml': 80,
            'title': '喂养记录',
          },
        },
      );
      await _pumpPage(
        tester,
        transport,
        volumeUnitPreferenceStore: _FakeVolumeUnitPreferenceStore(
          MomCozyVolumeUnit.ounces,
        ),
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('schedule-quick-actions')),
        200,
        scrollable: _scheduleScrollable(),
      );

      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('schedule-quick-actions')),
          matching: find.text('吸奶补录'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('schedule-pumping-record-sheet')),
        findsOneWidget,
      );
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('吸奶量（左侧）'), findsOneWidget);
      expect(find.text('吸奶量（右侧）'), findsOneWidget);
      expect(find.text('oz'), findsNWidgets(2));
      await tester.enterText(
        find.byKey(const ValueKey('schedule-record-left-amount-input')),
        '1.1',
      );
      await tester.enterText(
        find.byKey(const ValueKey('schedule-record-right-amount-input')),
        '2.2',
      );
      await tester.enterText(
        find.byKey(const ValueKey('schedule-record-duration-input')),
        '15',
      );
      await tester.pump();
      expect(find.text('总奶量：3.3 oz'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('schedule-record-submit')));
      await tester.pumpAndSettle();

      expect(transport.lastPath, schedulePumpingRecordsEndpoint);
      expect(transport.lastBody?['milk_volume_ml'], 98);
      expect(transport.lastBody?['duration_seconds'], 900);

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('schedule-quick-actions')),
        200,
        scrollable: _scheduleScrollable(),
      );
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('schedule-quick-actions')),
          matching: find.text('喂养记录'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('schedule-feeding-record-sheet')),
        findsOneWidget,
      );
      expect(find.text('配方奶量 (oz)'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('schedule-record-amount-input')),
        '2.7',
      );
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('schedule-record-submit')),
            )
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.byKey(const ValueKey('schedule-record-submit')));
      await tester.pumpAndSettle();

      expect(transport.lastPath, scheduleFeedingRecordsEndpoint);
      expect(transport.lastBody?['volume_ml'], 80);
    },
  );

  testWidgets('feeding sheet exposes all three legacy recording modes', (
    tester,
  ) async {
    final transport = _transport(
      tasks: const [],
      feedingRecords: const [],
      pumpingRecords: const [],
      writeResponsesByPath: const {
        scheduleFeedingRecordsEndpoint: {
          'id': 'bottle-created',
          'plan_task_id': null,
          'feed_time': '2026-07-03T10:00:00Z',
          'feed_type': 'bottle',
          'volume_ml': 90,
          'title': '喂养记录',
        },
      },
    );
    await _pumpPage(tester, transport);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('schedule-quick-actions')),
      200,
      scrollable: _scheduleScrollable(),
    );
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('schedule-quick-actions')),
        matching: find.text('喂养记录'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('🧪 配方奶'), findsOneWidget);
    expect(find.text('🤱 亲喂'), findsOneWidget);
    expect(find.text('🍼 瓶喂母乳'), findsOneWidget);
    expect(find.text('配方奶量 (mL)'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('schedule-feed-type-breast')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('schedule-record-amount-input')),
      findsNothing,
    );
    expect(find.textContaining('不作为精确依据'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('schedule-feed-type-bottle')));
    await tester.pump();
    expect(find.text('瓶喂奶量 (mL)'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('schedule-record-duration-input')),
      findsNothing,
    );
    await tester.enterText(
      find.byKey(const ValueKey('schedule-record-amount-input')),
      '90',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('schedule-record-submit')));
    await tester.pumpAndSettle();

    expect(transport.lastPath, scheduleFeedingRecordsEndpoint);
    expect(transport.lastBody?['feed_type'], 'bottle');
    expect(transport.lastBody?['volume_ml'], 90);
    expect(transport.lastBody, isNot(contains('duration_seconds')));
  });

  testWidgets('breastfeeding converts fractional minutes to whole seconds', (
    tester,
  ) async {
    final transport = _transport(
      tasks: const [],
      feedingRecords: const [],
      pumpingRecords: const [],
      writeResponsesByPath: const {
        scheduleFeedingRecordsEndpoint: {
          'id': 'breast-created',
          'plan_task_id': null,
          'feed_time': '2026-07-03T10:00:00Z',
          'feed_type': 'breast',
          'volume_ml': null,
          'duration_seconds': 750,
          'title': '喂养记录',
        },
      },
    );
    await _pumpPage(tester, transport);
    final quickActions = find.byKey(const ValueKey('schedule-quick-actions'));
    await tester.scrollUntilVisible(
      quickActions,
      200,
      scrollable: _scheduleScrollable(),
    );
    await tester.tap(
      find.descendant(of: quickActions, matching: find.text('喂养记录')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('schedule-feed-type-breast')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('schedule-record-duration-input')),
      '12.5',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('schedule-record-submit')));
    await tester.pumpAndSettle();

    expect(transport.lastBody?['feed_type'], 'breast');
    expect(transport.lastBody?['duration_seconds'], 750);
    expect(transport.lastBody, isNot(contains('volume_ml')));
  });

  testWidgets('keeps the usable timeline when one resource returns 503', (
    tester,
  ) async {
    final transport = FixtureApiJsonTransportByPath({
      scheduleDayPlanEndpoint: const {
        'items': [
          {
            'id': 'task-available',
            'plan_id': 'plan-1',
            'task_date': '2026-07-03',
            'task_time': '10:30',
            'title': '可用任务',
            'description': '',
            'status': 'pending',
            'payload': {'task_type': 'pumping'},
          },
        ],
      },
      schedulePlansEndpoint: const {
        'items': [
          {
            'id': 'plan-1',
            'plan_type': 'milk_management',
            'title': '稳奶计划',
            'summary': '',
            'status': 'active',
            'version': 1,
            'payload': {'postpartum_week': 29},
          },
        ],
      },
      scheduleFeedingRecordsEndpoint: const {
        'http_status': 503,
        'status_text': 'Service Unavailable',
      },
      schedulePumpingRecordsEndpoint: const {
        'items': [
          {
            'id': 'pump-available',
            'plan_task_id': null,
            'pump_start_time': '2026-07-03T02:00:00Z',
            'milk_volume_ml': 90,
            'title': '可用吸奶记录',
          },
        ],
      },
    });
    await _pumpPage(tester, transport);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('schedule-feedback-banner')),
      200,
      scrollable: _scheduleScrollable(),
    );
    expect(find.text('喂养记录同步暂时不可用'), findsOneWidget);
    final banner = tester.widget<Semantics>(
      find.byKey(const ValueKey('schedule-feedback-banner')),
    );
    expect(banner.properties.liveRegion, isTrue);

    await tester.drag(_scheduleScrollable(), const Offset(0, -350));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('schedule-timeline-task-task-available')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('schedule-timeline-record-pump-available')),
      findsOneWidget,
    );
  });

  testWidgets('renders the legacy information hierarchy from live plan data', (
    tester,
  ) async {
    await _pumpPage(
      tester,
      _transport(
        tasks: const [
          {
            'id': 'next-pump',
            'plan_id': 'plan-1',
            'task_date': '2026-07-03',
            'task_time': '14:00',
            'title': '下午吸奶',
            'description': '',
            'status': 'pending',
            'payload': {'task_type': 'pumping'},
          },
        ],
      ),
    );

    expect(
      find.byKey(const ValueKey('schedule-context-progress')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('schedule-agent-reminder-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('schedule-agent-chat-button')),
      findsOneWidget,
    );
    expect(find.text('已经根据你今天的会议日程，对吸乳排期做了调整哦，记得按时吸奶，有问题随时找我'), findsOneWidget);
    expect(find.text('提醒开关'), findsOneWidget);
    expect(find.text('系统提醒已开启'), findsNothing);
    expect(find.text('系统提醒未开启'), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('schedule-next-countdown-badge')),
      200,
      scrollable: _scheduleScrollable(),
    );
    final time = tester.widget<Text>(
      find.byKey(const ValueKey('schedule-next-task-time')),
    );
    expect(time.data, '14:00');
    expect(time.style?.fontSize, 32);
    expect(
      find.byKey(const ValueKey('schedule-next-countdown-badge')),
      findsOneWidget,
    );
    expect(
      find.textContaining('秒', skipOffstage: false),
      findsAtLeastNWidgets(1),
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('schedule-quick-actions')),
      200,
      scrollable: _scheduleScrollable(),
    );
    expect(
      find.byKey(const ValueKey('schedule-quick-actions')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('schedule-next-task-badge-next-pump')),
      findsNothing,
    );

    final toolbar = find.byKey(const ValueKey('schedule-list-toolbar'));
    await tester.scrollUntilVisible(
      toolbar,
      200,
      scrollable: _scheduleScrollable(),
    );
    final toolbarTitle = find.descendant(
      of: toolbar,
      matching: find.text('今日任务'),
    );
    final adjustButton = find.byKey(const ValueKey('schedule-adjust-button'));
    expect(
      (tester.getCenter(toolbarTitle).dy - tester.getCenter(adjustButton).dy)
          .abs(),
      lessThan(12),
    );
  });

  testWidgets('timeline rows keep the legacy compact single-line hierarchy', (
    tester,
  ) async {
    await _pumpPage(tester, _transport());
    final taskRow = find.byKey(
      const ValueKey('schedule-timeline-task-task-pump'),
    );
    await tester.scrollUntilVisible(
      taskRow,
      200,
      scrollable: _scheduleScrollable(),
    );
    final sourceBadge = find.byKey(
      const ValueKey('schedule-task-source-task-pump'),
    );

    expect(tester.getSize(taskRow).height, lessThanOrEqualTo(58));
    expect(
      tester.getTopLeft(sourceBadge).dy,
      lessThanOrEqualTo(tester.getTopLeft(taskRow).dy + 6),
    );

    final recordRow = find.byKey(
      const ValueKey('schedule-timeline-record-pump-1'),
    );
    await tester.scrollUntilVisible(
      recordRow,
      200,
      scrollable: _scheduleScrollable(),
    );
    expect(tester.getSize(recordRow).height, lessThanOrEqualTo(58));
    expect(find.text('120 mL'), findsOneWidget);

    final linkedRecord = find.byKey(
      const ValueKey('schedule-linked-record-feed-1'),
    );
    await tester.scrollUntilVisible(
      linkedRecord,
      200,
      scrollable: _scheduleScrollable(),
    );
    expect(linkedRecord, findsOneWidget);
    expect(find.text('80 mL · 22:00 完成'), findsOneWidget);
    expect(find.byTooltip('删除关联记录'), findsOneWidget);
  });

  testWidgets('places quick records after the timeline', (tester) async {
    await _pumpPage(
      tester,
      _transport(
        tasks: const [],
        feedingRecords: const [],
        pumpingRecords: const [],
      ),
    );

    final emptyNotice = find.byKey(
      const ValueKey('schedule-empty-timeline-notice'),
    );
    final quickActions = find.byKey(const ValueKey('schedule-quick-actions'));
    await tester.scrollUntilVisible(
      quickActions,
      200,
      scrollable: _scheduleScrollable(),
    );

    expect(emptyNotice, findsOneWidget);
    expect(
      tester.getTopLeft(quickActions).dy,
      greaterThan(tester.getTopLeft(emptyNotice).dy),
    );
  });

  testWidgets(
    'planned future days use the legacy summary instead of next task',
    (tester) async {
      await _pumpPage(
        tester,
        _transport(
          tasks: const [
            {
              'id': 'future-pump',
              'plan_id': 'plan-1',
              'task_date': '2026-07-10',
              'task_time': '14:00',
              'title': '下午吸奶',
              'description': '',
              'status': 'pending',
              'payload': {'task_type': 'pumping'},
            },
          ],
          feedingRecords: const [],
          pumpingRecords: const [],
        ),
        initialDay: DateTime.utc(2026, 7, 10),
      );

      expect(find.text('未来的计划'), findsOneWidget);
      expect(find.text('系统已为你提前规划了当天的吸乳和喂养日程'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('schedule-empty-task-card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('schedule-next-task-card')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('schedule-context-reminder-button')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'linked feeding completion prefills time and supports breastfeed',
    (tester) async {
      final transport = _transport(
        tasks: const [
          {
            'id': 'feed-pending',
            'plan_id': 'plan-1',
            'task_date': '2026-07-03',
            'task_time': '14:00',
            'title': '下午喂养',
            'description': '',
            'status': 'pending',
            'payload': {'task_type': 'feeding'},
          },
        ],
        feedingRecords: const [],
        pumpingRecords: const [],
        writeResponsesByPath: const {
          scheduleFeedingRecordsEndpoint: {
            'id': 'feed-created',
            'plan_task_id': 'feed-pending',
            'feed_time': '2026-07-03T06:00:00.000Z',
            'feed_type': 'breast',
            'volume_ml': null,
            'duration_seconds': null,
            'title': '喂养记录',
          },
        },
      );
      await _pumpPage(tester, transport);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('schedule-next-complete-button')),
        200,
        scrollable: _scheduleScrollable(),
      );
      await tester.tap(
        find.byKey(const ValueKey('schedule-next-complete-button')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('schedule-record-entry-dialog')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('schedule-feeding-record-sheet')),
        findsOneWidget,
      );

      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('schedule-record-time-input')),
            )
            .controller
            ?.text,
        '14:00',
      );
      await tester.tap(find.byKey(const ValueKey('schedule-feed-type-breast')));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('schedule-record-amount-input')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('schedule-record-duration-input')),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('schedule-record-duration-input')),
        '',
      );
      await tester.tap(find.byKey(const ValueKey('schedule-record-submit')));
      await tester.pumpAndSettle();

      expect(transport.lastBody?['feed_type'], 'breast');
      expect(transport.lastBody, isNot(contains('volume_ml')));
      expect(transport.lastBody, isNot(contains('duration_seconds')));
      expect(transport.lastBody?['plan_task_id'], 'feed-pending');
      expect(
        tester
            .getSemantics(
              find.byKey(const ValueKey('schedule-timeline-task-feed-pending')),
            )
            .label,
        contains('已完成'),
      );
    },
  );

  testWidgets('pump completion cancellation never changes the task', (
    tester,
  ) async {
    final transport = _transport(
      tasks: const [
        {
          'id': 'pump-pending',
          'plan_id': 'plan-1',
          'task_date': '2026-07-03',
          'task_time': '14:00',
          'title': '下午吸奶',
          'description': '',
          'status': 'pending',
          'payload': {'task_type': 'pumping'},
        },
      ],
      feedingRecords: const [],
      pumpingRecords: const [],
    );
    await _pumpPage(tester, transport);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('schedule-next-complete-button')),
      200,
      scrollable: _scheduleScrollable(),
    );
    await tester.tap(
      find.byKey(const ValueKey('schedule-next-complete-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('schedule-record-complete-only')),
      findsNothing,
    );
    expect(find.text('仅标记完成'), findsNothing);
    expect(
      find.byKey(const ValueKey('schedule-record-entry-dialog')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('schedule-pumping-record-sheet')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('schedule-record-sheet-close')));
    await tester.pumpAndSettle();

    expect(transport.lastBody, isNull);
    expect(
      tester
          .getSemantics(
            find.byKey(const ValueKey('schedule-timeline-task-pump-pending')),
          )
          .label,
      contains('待执行'),
    );
  });

  testWidgets('other task completion patches state directly', (tester) async {
    const taskId = 'other-pending';
    final transport = _transport(
      tasks: const [
        {
          'id': taskId,
          'plan_id': 'plan-1',
          'task_date': '2026-07-03',
          'task_time': '14:00',
          'title': '补充维生素',
          'description': '',
          'status': 'pending',
          'payload': {'task_type': 'other'},
        },
      ],
      feedingRecords: const [],
      pumpingRecords: const [],
      writeResponsesByPath: const {
        '$scheduleTasksEndpoint/$taskId/state': {
          'id': taskId,
          'plan_id': 'plan-1',
          'task_date': '2026-07-03',
          'task_time': '14:00',
          'title': '补充维生素',
          'description': '',
          'status': 'completed',
          'payload': {'task_type': 'other'},
        },
      },
    );
    await _pumpPage(tester, transport);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('schedule-next-complete-button')),
      200,
      scrollable: _scheduleScrollable(),
    );
    await tester.tap(
      find.byKey(const ValueKey('schedule-next-complete-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('schedule-record-entry-dialog')),
      findsNothing,
    );
    expect(transport.lastMethod, 'PATCH');
    expect(transport.lastBody, {'state': 'completed'});
    expect(
      tester
          .getSemantics(
            find.byKey(const ValueKey('schedule-timeline-task-$taskId')),
          )
          .label,
      contains('已完成'),
    );
  });

  testWidgets('mutation in flight disables every schedule write entry point', (
    tester,
  ) async {
    final transport = _DeferredTaskMutationTransport();
    await _pumpPage(tester, transport);
    final completeButton = find.byKey(
      const ValueKey('schedule-next-complete-button'),
    );
    await tester.scrollUntilVisible(
      completeButton,
      200,
      scrollable: _scheduleScrollable(),
    );
    await tester.tap(completeButton);
    await tester.pump();

    expect(transport.mutationStarted, isTrue);
    expect(tester.widget<FilledButton>(completeButton).onPressed, isNull);
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('schedule-add-task-button')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('schedule-quick-pumping-button')),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(
      find.byKey(const ValueKey('schedule-timeline-task-deferred-task')),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('schedule-inline-task-title-deferred-task')),
      findsNothing,
    );

    transport.completeMutation();
    await tester.pumpAndSettle();

    expect(
      tester
          .getSemantics(
            find.byKey(const ValueKey('schedule-timeline-task-deferred-task')),
          )
          .label,
      contains('已完成'),
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('schedule-quick-pumping-button')),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('feeding retry keys are stable until feed type changes', (
    tester,
  ) async {
    final transport = _RecordIntentTransport();
    await _pumpPage(tester, transport);

    Future<void> submitFeeding({required bool breast}) async {
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('schedule-quick-actions')),
        200,
        scrollable: _scheduleScrollable(),
      );
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('schedule-quick-actions')),
          matching: find.text('喂养记录'),
        ),
      );
      await tester.pumpAndSettle();
      if (breast) {
        await tester.tap(
          find.byKey(const ValueKey('schedule-feed-type-breast')),
        );
        await tester.pump();
      } else {
        await tester.enterText(
          find.byKey(const ValueKey('schedule-record-amount-input')),
          '80',
        );
        await tester.pump();
      }
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('schedule-record-submit')),
            )
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.byKey(const ValueKey('schedule-record-submit')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('schedule-feeding-record-sheet')),
        findsNothing,
      );
      tester.testTextInput.hide();
      await tester.pump();
    }

    await submitFeeding(breast: false);
    await submitFeeding(breast: false);
    await submitFeeding(breast: true);

    expect(transport.idempotencyKeys, hasLength(3));
    expect(transport.idempotencyKeys[1], transport.idempotencyKeys[0]);
    expect(transport.idempotencyKeys[2], isNot(transport.idempotencyKeys[0]));
    expect(transport.feedTypes, ['formula', 'formula', 'breast']);
  });

  testWidgets('week arrows only browse while date pills select and refetch', (
    tester,
  ) async {
    final transport = _transport();
    await _pumpPage(tester, transport);
    expect(transport.getPaths, hasLength(4));

    await tester.tap(find.byKey(const ValueKey('schedule-week-next-button')));
    await tester.pump();

    expect(transport.getPaths, hasLength(4));
    expect(
      find.byKey(const ValueKey('schedule-date-2026-07-10')),
      findsOneWidget,
    );
    expect(find.text('稳奶计划执行中'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('schedule-date-2026-07-10')));
    await tester.pumpAndSettle();
    expect(transport.getPaths, hasLength(8));
    expect(find.text('7月10日 稳奶计划'), findsOneWidget);
    expect(find.text('产后第30周（离乳期）'), findsOneWidget);
    expect(find.byKey(const ValueKey('schedule-agent-card')), findsNothing);
    expect(
      find.byKey(const ValueKey('schedule-add-task-button')),
      findsNothing,
    );
  });

  testWidgets(
    'narrow date strip keeps seven days visible and floats back to today',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final transport = _transport();
      await _pumpPage(tester, transport);

      final dateStrip = find.byKey(const ValueKey('schedule-date-strip'));
      expect(dateStrip, findsOneWidget);
      expect(
        find.descendant(
          of: dateStrip,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is SingleChildScrollView &&
                widget.scrollDirection == Axis.horizontal,
          ),
        ),
        findsNothing,
      );
      for (final date in <String>[
        '2026-06-30',
        '2026-07-01',
        '2026-07-02',
        '2026-07-03',
        '2026-07-04',
        '2026-07-05',
        '2026-07-06',
      ]) {
        expect(
          find.byKey(ValueKey('schedule-date-$date')).hitTestable(),
          findsOneWidget,
        );
      }
      expect(
        find.byKey(const ValueKey('schedule-back-to-today-button')),
        findsNothing,
      );

      await tester.tap(find.byKey(const ValueKey('schedule-week-next-button')));
      await tester.pumpAndSettle();

      final todayButton = find.byKey(
        const ValueKey('schedule-back-to-today-button'),
      );
      expect(todayButton, findsOneWidget);
      expect(
        tester.getTopLeft(todayButton).dy,
        greaterThan(tester.getTopLeft(dateStrip).dy),
      );
      expect(transport.getPaths, hasLength(4));

      await tester.tap(todayButton);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('schedule-date-2026-07-03')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('schedule-back-to-today-button')),
        findsNothing,
      );
      expect(transport.getPaths, hasLength(4));
    },
  );

  testWidgets('renders backend failure as retryable error, not empty success', (
    tester,
  ) async {
    final transport = FixtureApiJsonTransportByPath({
      scheduleDayPlanEndpoint: const {
        'http_status': 503,
        'status_text': 'Service Unavailable',
      },
      schedulePlansEndpoint: const {
        'http_status': 503,
        'status_text': 'Service Unavailable',
      },
      scheduleFeedingRecordsEndpoint: const {
        'http_status': 503,
        'status_text': 'Service Unavailable',
      },
      schedulePumpingRecordsEndpoint: const {
        'http_status': 503,
        'status_text': 'Service Unavailable',
      },
    });
    await _pumpPage(tester, transport);

    expect(find.text('计划同步失败'), findsOneWidget);
    expect(find.byKey(const ValueKey('schedule-retry-button')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('schedule-context-placeholder')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('schedule-unavailable-timeline')),
      findsOneWidget,
    );
    expect(find.text('执行内容暂不可用'), findsOneWidget);
    expect(find.text('当天暂无执行内容'), findsNothing);
  });

  testWidgets('initial loading preserves the legacy page hierarchy', (
    tester,
  ) async {
    final transport = _DeferredScheduleTransport();
    await _pumpPage(tester, transport, settle: false);
    await tester.pump();

    expect(
      find.byKey(const ValueKey('schedule-fixed-date-area')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('schedule-loading-state')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('schedule-loading-context-skeleton')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('schedule-loading-hero-skeleton')),
      findsOneWidget,
    );
    expect(find.text('任务加载中…'), findsOneWidget);
    expect(find.text('记录加载中…'), findsOneWidget);
    expect(find.text('计划同步失败'), findsNothing);

    transport.complete();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('schedule-loading-state')), findsNothing);
    expect(find.text('今天还没有计划任务'), findsOneWidget);
  });

  testWidgets('cached refresh keeps useful content visible while syncing', (
    tester,
  ) async {
    final transport = _GateableScheduleTransport();
    await _pumpPage(tester, transport);
    expect(find.text('稳奶计划执行中'), findsOneWidget);
    expect(find.text('待执行任务'), findsOneWidget);

    transport.deferRequests();
    final refresh = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );
    final refreshFuture = refresh.onRefresh();
    await tester.pump();

    expect(
      find.byKey(const ValueKey('schedule-inline-loading-notice')),
      findsOneWidget,
    );
    expect(find.text('稳奶计划执行中'), findsOneWidget);
    expect(find.text('待执行任务'), findsOneWidget);
    expect(find.byKey(const ValueKey('schedule-loading-state')), findsNothing);

    transport.completeRequests();
    await refreshFuture;
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('schedule-inline-loading-notice')),
      findsNothing,
    );
    expect(find.text('稳奶计划执行中'), findsOneWidget);
  });

  testWidgets(
    'task creation only reports success after an authoritative response',
    (tester) async {
      final transport = _transport(
        writeResponsesByPath: const {
          scheduleTasksEndpoint: {
            'id': 'created-task',
            'plan_id': 'plan-1',
            'task_date': '2026-07-03',
            'task_time': '10:15',
            'title': '睡前吸奶',
            'description': '',
            'status': 'pending',
            'payload': {'task_type': 'pumping'},
          },
        },
      );
      await _pumpPage(tester, transport);

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('schedule-add-task-button')),
        250,
        scrollable: _scheduleScrollable(),
      );
      await tester.drag(_scheduleScrollable(), const Offset(0, -100));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('schedule-add-task-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('schedule-add-task-title-input')),
        '睡前吸奶',
      );
      await tester.tap(find.byKey(const ValueKey('schedule-add-task-submit')));
      await tester.pumpAndSettle();

      expect(transport.lastMethod, 'POST');
      expect(transport.lastPath, scheduleTasksEndpoint);
      expect(transport.lastBody?['task_time'], '10:15');
      expect(transport.lastBody?['payload'], {'task_type': 'pumping'});
      expect(find.text('任务已添加'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('schedule-timeline-task-created-task')),
        250,
        scrollable: _scheduleScrollable(),
      );
      expect(
        find.byKey(const ValueKey('schedule-timeline-task-created-task')),
        findsOneWidget,
      );
    },
  );

  testWidgets('add task uses the legacy bottom sheet and wheel time picker', (
    tester,
  ) async {
    final transport = _transport();
    await _pumpPage(tester, transport);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('schedule-add-task-button')),
      250,
      scrollable: _scheduleScrollable(),
    );

    await tester.tap(find.byKey(const ValueKey('schedule-add-task-button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('schedule-add-task-sheet')),
      findsOneWidget,
    );
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('手动添加一项'), findsOneWidget);
    expect(find.text('确认添加 (1项)'), findsOneWidget);
    final timeButton = find.byKey(const ValueKey('schedule-task-time-input'));
    expect(
      find.descendant(of: timeButton, matching: find.text('10:15')),
      findsOneWidget,
    );

    await tester.tap(timeButton);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('schedule-time-picker-sheet')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('schedule-time-hour-wheel')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('schedule-time-minute-wheel')),
      findsOneWidget,
    );
    expect(find.text('10:15'), findsWidgets);

    await tester.tap(
      find.byKey(const ValueKey('schedule-time-picker-confirm')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('schedule-time-picker-sheet')),
      findsNothing,
    );
    expect(
      find.descendant(of: timeButton, matching: find.text('10:15')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('schedule-task-sheet-close')));
    await tester.pumpAndSettle();
    expect(transport.lastBody, isNull);
  });

  testWidgets('retrying the same failed create intent reuses idempotency key', (
    tester,
  ) async {
    final transport = _LostResponseCreateTransport();
    await _pumpPage(tester, transport);

    Future<void> submitSameTask() async {
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('schedule-add-task-button')),
        250,
        scrollable: _scheduleScrollable(),
      );
      await tester.tap(find.byKey(const ValueKey('schedule-add-task-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('schedule-add-task-title-input')),
        '响应丢失任务',
      );
      await tester.tap(find.byKey(const ValueKey('schedule-add-task-submit')));
      await tester.pumpAndSettle();
    }

    await submitSameTask();
    expect(find.textContaining('response lost'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('schedule-timeline-task-server-created')),
      250,
      scrollable: _scheduleScrollable(),
    );
    expect(
      find.byKey(const ValueKey('schedule-timeline-task-server-created')),
      findsOneWidget,
    );

    await submitSameTask();
    expect(transport.idempotencyKeys, hasLength(2));
    expect(transport.idempotencyKeys.toSet(), hasLength(1));
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('schedule-timeline-task-server-created')),
      250,
      scrollable: _scheduleScrollable(),
    );
    expect(
      find.byKey(const ValueKey('schedule-timeline-task-server-created')),
      findsOneWidget,
    );
    expect(find.text('任务已添加'), findsOneWidget);
  });

  testWidgets('multi-add sends independently edited rows with +15m defaults', (
    tester,
  ) async {
    final transport = _MultiCreateTransport();
    await _pumpPage(tester, transport);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('schedule-add-task-button')),
      250,
      scrollable: _scheduleScrollable(),
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('schedule-add-task-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('schedule-add-task-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('schedule-add-task-title-input')),
      '第一项吸奶',
    );
    await tester.tap(
      find.byKey(const ValueKey('schedule-add-task-row-button')),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('schedule-task-time-input-1')),
        matching: find.text('10:30'),
      ),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const ValueKey('schedule-add-task-title-input-1')),
      '第二项喂养',
    );
    final secondFeedingKind = find.descendant(
      of: find.byKey(const ValueKey('schedule-task-kind-1')),
      matching: find.text('喂养'),
    );
    await tester.ensureVisible(secondFeedingKind);
    await tester.pumpAndSettle();
    await tester.tap(secondFeedingKind);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('schedule-add-task-submit')));
    await tester.pumpAndSettle();

    expect(transport.postedBodies, hasLength(2));
    expect(transport.postedBodies[0]['title'], '第一项吸奶');
    expect(transport.postedBodies[0]['task_time'], '10:15');
    expect(transport.postedBodies[0]['payload'], {'task_type': 'pumping'});
    expect(transport.postedBodies[1]['title'], '第二项喂养');
    expect(transport.postedBodies[1]['task_time'], '10:30');
    expect(transport.postedBodies[1]['payload'], {'task_type': 'feeding'});
    expect(transport.idempotencyKeys.toSet(), hasLength(2));
  });

  testWidgets('task rows preserve legacy defaults without overwriting edits', (
    tester,
  ) async {
    await _pumpPage(tester, _transport());
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('schedule-add-task-button')),
      250,
      scrollable: _scheduleScrollable(),
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('schedule-add-task-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('schedule-add-task-button')));
    await tester.pumpAndSettle();

    final firstTitle = find.byKey(
      const ValueKey('schedule-add-task-title-input'),
    );
    String titleText(Finder finder) =>
        tester.widget<TextField>(finder).controller!.text;
    Finder kindChoice(int index, String label) => find.descendant(
      of: find.byKey(ValueKey('schedule-task-kind-$index')),
      matching: find.text(label),
    );

    expect(titleText(firstTitle), '吸奶');
    await tester.tap(kindChoice(0, '喂养'));
    await tester.pump();
    expect(titleText(firstTitle), '喂养');
    await tester.tap(kindChoice(0, '其他'));
    await tester.pump();
    expect(titleText(firstTitle), isEmpty);

    await tester.enterText(firstTitle, '夜间自定义事项');
    await tester.tap(kindChoice(0, '吸奶'));
    await tester.pump();
    expect(titleText(firstTitle), '夜间自定义事项');

    await tester.tap(
      find.byKey(const ValueKey('schedule-add-task-row-button')),
    );
    await tester.pumpAndSettle();
    expect(
      titleText(find.byKey(const ValueKey('schedule-add-task-title-input-1'))),
      '吸奶',
    );
  });

  testWidgets(
    'pending today tasks edit inline and only patch after explicit save',
    (tester) async {
      const taskId = 'editable-task';
      final transport = _transport(
        tasks: const [
          {
            'id': taskId,
            'plan_id': 'plan-1',
            'task_date': '2026-07-03',
            'task_time': '14:00',
            'title': '下午吸奶',
            'description': '原任务说明',
            'status': 'pending',
            'payload': {'task_type': 'pumping'},
          },
        ],
        feedingRecords: const [],
        pumpingRecords: const [],
        writeResponsesByPath: const {
          '$scheduleTasksEndpoint/$taskId': {
            'id': taskId,
            'plan_id': 'plan-1',
            'task_date': '2026-07-03',
            'task_time': '14:00',
            'title': '调整后的吸奶',
            'description': '原任务说明',
            'status': 'pending',
            'payload': {'task_type': 'pumping'},
          },
        },
      );
      await _pumpPage(tester, transport);

      final taskRow = find.byKey(
        const ValueKey('schedule-timeline-task-$taskId'),
      );
      await tester.scrollUntilVisible(
        taskRow,
        200,
        scrollable: _scheduleScrollable(),
      );
      await tester.tap(taskRow);
      await tester.pumpAndSettle();

      final titleInput = find.byKey(
        const ValueKey('schedule-inline-task-title-$taskId'),
      );
      final timeButton = find.byKey(
        const ValueKey('schedule-inline-task-time-$taskId'),
      );
      expect(titleInput, findsOneWidget);
      expect(timeButton, findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.byKey(const ValueKey('schedule-add-task-sheet')),
        findsNothing,
      );

      await tester.enterText(titleInput, '未保存的吸奶');
      await tester.tap(timeButton);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('schedule-time-picker-sheet')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('schedule-time-picker-confirm')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('schedule-inline-task-cancel-$taskId')),
      );
      await tester.pumpAndSettle();

      expect(titleInput, findsNothing);
      expect(transport.lastBody, isNull);
      expect(
        find.descendant(of: taskRow, matching: find.text('下午吸奶')),
        findsOneWidget,
      );

      await tester.tap(taskRow);
      await tester.pumpAndSettle();
      await tester.enterText(titleInput, '调整后的吸奶');
      await tester.tap(
        find.byKey(const ValueKey('schedule-inline-task-save-$taskId')),
      );
      await tester.pumpAndSettle();

      expect(transport.lastMethod, 'PATCH');
      expect(transport.lastPath, '$scheduleTasksEndpoint/$taskId');
      expect(transport.lastBody, {
        'task_date': '2026-07-03',
        'task_time': '14:00',
        'title': '调整后的吸奶',
        'description': '原任务说明',
      });
      expect(titleInput, findsNothing);
      expect(
        find.descendant(of: taskRow, matching: find.text('调整后的吸奶')),
        findsOneWidget,
      );
      expect(find.text('任务已更新'), findsOneWidget);
    },
  );

  testWidgets('quick records use current time and disable empty submissions', (
    tester,
  ) async {
    final transport = _transport();
    await _pumpPage(tester, transport, now: DateTime.utc(2026, 7, 3, 10, 37));
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('schedule-quick-actions')),
      200,
      scrollable: _scheduleScrollable(),
    );
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('schedule-quick-actions')),
        matching: find.text('吸奶补录'),
      ),
    );
    await tester.pumpAndSettle();

    String fieldText(String key) =>
        tester.widget<TextField>(find.byKey(ValueKey(key))).controller!.text;
    expect(fieldText('schedule-record-time-input'), '10:37');
    expect(fieldText('schedule-record-left-amount-input'), isEmpty);
    expect(fieldText('schedule-record-right-amount-input'), isEmpty);
    expect(fieldText('schedule-record-duration-input'), isEmpty);

    final submit = tester.widget<FilledButton>(
      find.byKey(const ValueKey('schedule-record-submit')),
    );
    expect(submit.onPressed, isNull);
    expect(transport.lastBody, isNull);
  });

  testWidgets('uses a neutral context while no milk plan is confirmed', (
    tester,
  ) async {
    final transport = FixtureApiJsonTransportByPath({
      scheduleDayPlanEndpoint: const {'items': <Object?>[]},
      schedulePlansEndpoint: const {'items': <Object?>[]},
      scheduleFeedingRecordsEndpoint: const {'items': <Object?>[]},
      schedulePumpingRecordsEndpoint: const {'items': <Object?>[]},
    });
    await _pumpPage(tester, transport);

    expect(find.text('计划待同步'), findsOneWidget);
    expect(find.text('稳奶计划执行中'), findsNothing);
    expect(find.byKey(const ValueKey('schedule-agent-card')), findsNothing);
    expect(
      find.byKey(const ValueKey('schedule-context-reminder-button')),
      findsNothing,
    );
  });

  testWidgets('distinguishes handled today tasks and past summaries', (
    tester,
  ) async {
    final handled = _transport(
      tasks: const [
        {
          'id': 'done',
          'plan_id': 'plan-1',
          'task_date': '2026-07-03',
          'task_time': '10:30',
          'title': '吸奶',
          'description': '',
          'status': 'completed',
          'payload': {'task_type': 'pumping'},
        },
        {
          'id': 'skip',
          'plan_id': 'plan-1',
          'task_date': '2026-07-03',
          'task_time': '14:00',
          'title': '喂养',
          'description': '',
          'status': 'skipped',
          'payload': {'task_type': 'feeding'},
        },
      ],
    );
    await _pumpPage(tester, handled);
    expect(find.text('今天的计划尚未全部完成哦'), findsOneWidget);
    expect(find.text('顺利完成1个任务，有1个任务被跳过'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpPage(tester, _transport(), initialDay: DateTime.utc(2026, 7, 2));
    expect(find.text('这天的计划已结束'), findsOneWidget);
    expect(find.text('执行记录'), findsOneWidget);
    expect(find.textContaining('共完成 2 项任务，母乳产出 120 mL'), findsOneWidget);
    expect(find.textContaining('还有'), findsNothing);
  });

  testWidgets(
    'restores and persists reminder state through injected account store',
    (tester) async {
      final store = _FakeReminderStore(enabled: true);
      await _pumpPage(
        tester,
        _transport(),
        reminderGateway: _SuccessfulReminderGateway(),
        reminderPreferenceStore: store,
      );

      expect(find.byTooltip('关闭计划提醒'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('schedule-context-reminder-button')),
      );
      await tester.pumpAndSettle();
      expect(find.text('关闭提醒？'), findsOneWidget);
      expect(find.text('保持开启'), findsOneWidget);
      expect(find.text('仍要关闭'), findsOneWidget);
      expect(find.textContaining('系统级后台提醒'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('schedule-reminder-confirm')));
      await tester.pumpAndSettle();

      expect(store.enabled, isFalse);
      expect(find.byTooltip('开启计划提醒'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('系统提醒已关闭'),
        250,
        scrollable: _scheduleScrollable(),
      );
      expect(find.text('系统提醒已关闭'), findsOneWidget);
    },
  );

  testWidgets('reminder warning cancellation keeps the preference enabled', (
    tester,
  ) async {
    final store = _FakeReminderStore(enabled: true);
    await _pumpPage(
      tester,
      _transport(),
      reminderGateway: _SuccessfulReminderGateway(),
      reminderPreferenceStore: store,
    );

    await tester.tap(
      find.byKey(const ValueKey('schedule-context-reminder-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('schedule-reminder-confirm-dialog')),
      findsOneWidget,
    );
    expect(find.byType(AlertDialog), findsNothing);
    await tester.tap(find.byKey(const ValueKey('schedule-reminder-cancel')));
    await tester.pumpAndSettle();

    expect(store.enabled, isTrue);
    expect(
      find.byKey(const ValueKey('schedule-reminder-confirm-dialog')),
      findsNothing,
    );
    expect(find.byTooltip('关闭计划提醒'), findsOneWidget);
  });

  testWidgets(
    'reminder synchronization is single-flight in both card entry points',
    (tester) async {
      final store = _FakeReminderStore(enabled: false);
      final gateway = _DeferredReminderGateway();
      await _pumpPage(
        tester,
        _transport(),
        reminderGateway: gateway,
        reminderPreferenceStore: store,
      );

      final contextButton = find.byKey(
        const ValueKey('schedule-context-reminder-button'),
      );
      await tester.tap(contextButton);
      for (var index = 0; index < 30 && gateway.calls == 0; index += 1) {
        await tester.pump();
      }

      expect(gateway.calls, 1);
      expect(tester.widget<IconButton>(contextButton).onPressed, isNull);
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('schedule-agent-reminder-button')),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(contextButton);
      await tester.pump();
      expect(gateway.calls, 1);

      gateway.complete(true);
      await tester.pumpAndSettle();

      expect(store.enabled, isTrue);
      expect(tester.widget<IconButton>(contextButton).onPressed, isNotNull);
      expect(find.byTooltip('关闭计划提醒'), findsOneWidget);
    },
  );

  testWidgets('reminder gateway failures restore enabled controls honestly', (
    tester,
  ) async {
    final store = _FakeReminderStore(enabled: false);
    await _pumpPage(
      tester,
      _transport(),
      reminderGateway: _ThrowingReminderGateway(),
      reminderPreferenceStore: store,
    );

    final contextButton = find.byKey(
      const ValueKey('schedule-context-reminder-button'),
    );
    await tester.tap(contextButton);
    await tester.pumpAndSettle();

    expect(store.enabled, isFalse);
    expect(tester.widget<IconButton>(contextButton).onPressed, isNotNull);
    expect(find.byTooltip('开启计划提醒'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('系统提醒同步失败，未修改提醒状态'),
      250,
      scrollable: _scheduleScrollable(),
    );
    expect(find.text('系统提醒同步失败，未修改提醒状态'), findsOneWidget);
  });

  testWidgets('task explanation uses the lightweight legacy dialog', (
    tester,
  ) async {
    await _pumpPage(tester, _transport());
    final helpButton = find.byKey(const ValueKey('schedule-task-help-button'));
    await tester.scrollUntilVisible(
      helpButton,
      200,
      scrollable: _scheduleScrollable(),
    );
    await tester.tap(helpButton);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('schedule-task-explanation-dialog')),
      findsOneWidget,
    );
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('知道了'), findsNothing);
    expect(
      find.text(
        '稳奶计划依据上次制定前读取到的产后阶段、奶量/喂养记录和原有任务节奏。'
        '今天完成2/2项，新增记录只用于看执行反馈；'
        '稳奶重点是稳定关键排乳窗口，避免过度加任务或过早减少。',
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('schedule-task-explanation-close')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('schedule-task-explanation-dialog')),
      findsNothing,
    );
  });

  testWidgets('task explanation follows the legacy plan-specific semantics', (
    tester,
  ) async {
    await _pumpPage(
      tester,
      _transport(
        plans: const [
          {
            'id': 'plan-1',
            'plan_type': 'milk_management',
            'title': '追奶计划',
            'summary': '增加有效移出',
            'status': 'active',
            'version': 4,
            'payload': {'goal_type': 'chase'},
          },
        ],
        tasks: const [
          {
            'id': 'done-task',
            'plan_id': 'plan-1',
            'task_date': '2026-07-03',
            'task_time': '08:00',
            'title': '晨间吸奶',
            'status': 'completed',
            'payload': {'task_type': 'pumping'},
          },
          {
            'id': 'skipped-task',
            'plan_id': 'plan-1',
            'task_date': '2026-07-03',
            'task_time': '12:00',
            'title': '午间吸奶',
            'status': 'skipped',
            'payload': {'task_type': 'pumping'},
          },
          {
            'id': 'pending-task',
            'plan_id': 'plan-1',
            'task_date': '2026-07-03',
            'task_time': '16:00',
            'title': '下午吸奶',
            'status': 'pending',
            'payload': {'task_type': 'pumping'},
          },
        ],
        feedingRecords: const [
          {
            'id': 'feedback-record',
            'plan_task_id': null,
            'feed_time': '2026-07-03T09:00:00Z',
            'feed_type': 'bottle',
            'volume_ml': 60,
            'title': '喂养记录',
          },
        ],
        pumpingRecords: const [],
      ),
    );
    final helpButton = find.byKey(const ValueKey('schedule-task-help-button'));
    await tester.scrollUntilVisible(
      helpButton,
      200,
      scrollable: _scheduleScrollable(),
    );
    await tester.tap(helpButton);
    await tester.pumpAndSettle();

    expect(
      find.text(
        '追奶计划依据上次制定前读取到的产后阶段、奶量/喂养记录和原有任务节奏。'
        '今天完成1/3项，跳过1项，新增记录只用于看执行反馈；'
        '追奶重点是增加有效移出机会，放在更容易坚持的时段。',
      ),
      findsOneWidget,
    );
  });

  testWidgets('unsupported reminders never report a fake success', (
    tester,
  ) async {
    final store = _FakeReminderStore(enabled: true);
    await _pumpPage(tester, _transport(), reminderPreferenceStore: store);

    await tester.tap(
      find.byKey(const ValueKey('schedule-context-reminder-button')),
    );
    await tester.pumpAndSettle();

    expect(store.enabled, isTrue);
    expect(find.byTooltip('开启计划提醒'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('当前设备尚未接入系统计划提醒，未修改提醒状态'),
      250,
      scrollable: _scheduleScrollable(),
    );
    expect(find.text('当前设备尚未接入系统计划提醒，未修改提醒状态'), findsOneWidget);
    expect(find.text('系统提醒已同步'), findsNothing);
  });

  testWidgets('exposes date and timeline semantics and honors reduced motion', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pumpPage(tester, _transport(), disableAnimations: true);

    expect(find.bySemanticsLabel(RegExp('2026年7月3日，今天，已选择')), findsOneWidget);
    expect(find.byTooltip('上一周'), findsOneWidget);
    expect(find.byTooltip('下一周'), findsOneWidget);
    final dateHitbox = tester.getSize(
      find.byKey(const ValueKey('schedule-date-2026-07-03')),
    );
    expect(dateHitbox.width, greaterThanOrEqualTo(44));
    expect(dateHitbox.height, greaterThanOrEqualTo(48));
    final helpHitbox = tester.getSize(
      find.byKey(const ValueKey('schedule-task-help-button')),
    );
    expect(helpHitbox.width, greaterThanOrEqualTo(48));
    expect(helpHitbox.height, greaterThanOrEqualTo(48));
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('schedule-timeline-task-task-pump')),
      250,
      scrollable: _scheduleScrollable(),
    );
    expect(find.bySemanticsLabel(RegExp('10:30 泵奶，已完成')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('schedule-timeline-task-task-feed')),
      250,
      scrollable: _scheduleScrollable(),
    );
    final linkedTaskSemantics = tester.getSemantics(
      find.byKey(const ValueKey('schedule-timeline-task-task-feed')),
    );
    expect(
      linkedTaskSemantics.label,
      contains('14:00 喂养，已完成，手动添加，80 mL · 22:00 完成'),
    );

    final datePill = find.byKey(const ValueKey('schedule-date-2026-07-03'));
    final animated = tester.widget<AnimatedContainer>(
      find.descendant(of: datePill, matching: find.byType(AnimatedContainer)),
    );
    expect(animated.duration, Duration.zero);
    semantics.dispose();
  });

  testWidgets('future empty days use neutral copy without reminder promises', (
    tester,
  ) async {
    final transport = _transport(
      tasks: const [],
      feedingRecords: const [],
      pumpingRecords: const [],
    );
    await _pumpPage(tester, transport, initialDay: DateTime.utc(2026, 7, 10));

    expect(find.text('7月10日 待规划'), findsOneWidget);
    expect(find.text('7月10日 稳奶计划'), findsNothing);
    expect(
      find.byKey(const ValueKey('schedule-context-progress')),
      findsNothing,
    );
    expect(find.text('这天还没有计划'), findsOneWidget);
    expect(find.textContaining('按时提醒'), findsNothing);
  });

  testWidgets('same-route notification revisions refocus and reset highlight', (
    tester,
  ) async {
    final tasks = <Map<String, Object?>>[
      for (var index = 0; index < 18; index += 1)
        {
          'id': 'long-task-$index',
          'plan_id': 'plan-1',
          'task_date': '2026-07-03',
          'task_time': '${(index + 1).toString().padLeft(2, '0')}:00',
          'title': '长列表任务 $index',
          'description': '',
          'status': 'pending',
          'payload': {'task_type': 'other'},
        },
    ];
    final transport = _transport(tasks: tasks);
    await _pumpPage(
      tester,
      transport,
      routeUri: Uri.parse('/schedule?date=2026-07-03&taskId=long-task-0'),
    );
    await tester.pump(const Duration(seconds: 1));
    final initialTask = find.byKey(
      const ValueKey('schedule-timeline-task-long-task-0'),
    );
    await tester.tap(initialTask);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('schedule-inline-task-title-long-task-0')),
      findsOneWidget,
    );

    await _pumpPage(
      tester,
      transport,
      routeUri: Uri.parse('/schedule?date=2026-07-04&taskId=long-task-17'),
    );

    expect(
      find.byKey(const ValueKey('schedule-inline-task-title-long-task-0')),
      findsNothing,
    );
    expect(transport.lastBody, isNull);
    expect(
      find.byKey(const ValueKey('schedule-highlighted-date-2026-07-04')),
      findsOneWidget,
    );
    final target = find.byKey(
      const ValueKey('schedule-timeline-task-long-task-17'),
    );
    expect(target, findsOneWidget);
    expect(tester.getCenter(target).dy, inInclusiveRange(120, 800));
    final card = tester.widget<DecoratedBox>(target);
    expect(
      (card.decoration as BoxDecoration).border?.top.color,
      MomCozyColors.primary.withValues(alpha: 0.72),
    );

    await tester.pump(const Duration(milliseconds: 5600));
    expect(
      find.byKey(const ValueKey('schedule-highlighted-date-2026-07-04')),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 1));
    expect(
      find.byKey(const ValueKey('schedule-highlighted-date-2026-07-04')),
      findsNothing,
    );
  });

  testWidgets(
    'milk plan notices refetch, fallback from the injected clock, and replay',
    (tester) async {
      final store = MilkPlanChangeStore();
      store.record(
        MilkPlanChange.tryFromEvent(
          _milkPlanChangedEvent(
            eventId: 'milk-empty-dates',
            affectedDates: const ['2026-07-02', 'invalid'],
          ),
        )!,
      );
      store.transferNavigationNoticeToPage();
      final transport = _transport();

      await _pumpPage(tester, transport, milkPlanChangeStore: store);

      expect(store.hasUnread, isFalse);
      expect(store.hasPageNotice, isFalse);
      final selectedToday = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byKey(const ValueKey('schedule-date-2026-07-03')),
          matching: find.byType(AnimatedContainer),
        ),
      );
      expect(
        (selectedToday.decoration as BoxDecoration).color,
        MomCozyColors.primary,
      );
      expect(transport.getPaths, hasLength(8));
      for (final date in const ['2026-07-04', '2026-07-05', '2026-07-06']) {
        expect(
          find.byKey(ValueKey('schedule-highlighted-date-$date')),
          findsOneWidget,
        );
      }
      expect(
        store.record(
          MilkPlanChange.tryFromEvent(
            _milkPlanChangedEvent(
              eventId: 'milk-empty-dates',
              affectedDates: const ['2026-07-07'],
            ),
          )!,
        ),
        isFalse,
      );
      store.record(
        MilkPlanChange.tryFromEvent(
          _milkPlanChangedEvent(
            eventId: 'milk-newer',
            affectedDates: const ['2026-07-06', '2026-07-05'],
          ),
        )!,
      );
      store.transferNavigationNoticeToPage();
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('schedule-highlighted-date-2026-07-05')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('schedule-highlighted-date-2026-07-06')),
        findsOneWidget,
      );
      expect(store.revision, 2);
      await tester.pump(const Duration(milliseconds: 6600));
      expect(
        find.byKey(const ValueKey('schedule-highlighted-date-2026-07-05')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'rescheduled milk plan refetches every affected date and highlights each day',
    (tester) async {
      final store = MilkPlanChangeStore();
      store.record(
        MilkPlanChange.tryFromEvent(
          _milkPlanChangedEvent(
            eventId: 'milk-rescheduled',
            operation: 'rescheduled',
            reason: 'schedule_adjustment',
            affectedDates: const ['2026-07-04', '2026-07-05', '2026-07-06'],
          ),
        )!,
      );
      store.transferNavigationNoticeToPage();
      final transport = _transport();

      await _pumpPage(tester, transport, milkPlanChangeStore: store);

      for (final date in const ['2026-07-04', '2026-07-05', '2026-07-06']) {
        expect(
          find.byKey(ValueKey('schedule-highlighted-date-$date')),
          findsOneWidget,
        );
        expect(
          transport.getPaths.where((path) => path == scheduleDayPlanEndpoint),
          hasLength(4),
        );
      }
      expect(store.hasPageNotice, isFalse);
    },
  );

  testWidgets('failed milk plan authority refresh restores the unread notice', (
    tester,
  ) async {
    final store = MilkPlanChangeStore();
    store.record(
      MilkPlanChange.tryFromEvent(
        _milkPlanChangedEvent(
          eventId: 'milk-refresh-failed',
          affectedDates: const ['2026-07-04'],
        ),
      )!,
    );
    store.transferNavigationNoticeToPage();
    final transport = FixtureApiJsonTransportByPath({
      scheduleDayPlanEndpoint: const {
        'http_status': 503,
        'status_text': 'Service Unavailable',
      },
      schedulePlansEndpoint: const {
        'http_status': 503,
        'status_text': 'Service Unavailable',
      },
      scheduleFeedingRecordsEndpoint: const {
        'http_status': 503,
        'status_text': 'Service Unavailable',
      },
      schedulePumpingRecordsEndpoint: const {
        'http_status': 503,
        'status_text': 'Service Unavailable',
      },
    });

    await _pumpPage(tester, transport, milkPlanChangeStore: store);

    expect(store.hasUnread, isTrue);
    expect(store.hasPageNotice, isFalse);
    expect(find.text('计划同步失败'), findsOneWidget);
  });

  testWidgets('route intent selects its date and focuses the linked task', (
    tester,
  ) async {
    await _pumpPage(
      tester,
      _transport(),
      routeUri: Uri.parse('/schedule?date=2026-07-04&taskId=task-pump'),
    );

    expect(
      find.byKey(const ValueKey('schedule-highlighted-date-2026-07-04')),
      findsOneWidget,
    );
    final focusedTask = find.byKey(
      const ValueKey('schedule-timeline-task-task-pump'),
    );
    expect(focusedTask, findsOneWidget);
    expect(tester.getCenter(focusedTask).dy, inInclusiveRange(120, 800));
    final card = tester.widget<DecoratedBox>(focusedTask);
    final decoration = card.decoration as BoxDecoration;
    expect(
      decoration.border?.top.color,
      MomCozyColors.primary.withValues(alpha: 0.72),
    );
  });

  testWidgets('missing notification tasks keep the date and report honestly', (
    tester,
  ) async {
    await _pumpPage(
      tester,
      _transport(),
      routeUri: Uri.parse('/schedule?date=2026-07-04&taskId=missing-task'),
    );

    expect(
      find.byKey(const ValueKey('schedule-highlighted-date-2026-07-04')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('未找到通知关联的任务，已定位到对应日期'),
      250,
      scrollable: _scheduleScrollable(),
    );
    expect(find.text('未找到通知关联的任务，已定位到对应日期'), findsOneWidget);
  });

  testWidgets(
    'screenshot button opens editable preview and writes only on save',
    (tester) async {
      final transport = _RecognizedCreateTransport();
      final gateway = _FakeImageRecognitionGateway(
        ScheduleImageRecognitionResult.preview(const [
          ScheduleImageTaskPreview(
            time: '08:30',
            title: '识别吸奶',
            kind: ScheduleImageTaskKind.pumping,
          ),
          ScheduleImageTaskPreview(
            time: '11:45',
            title: '识别散步',
            kind: ScheduleImageTaskKind.other,
          ),
        ]),
      );
      await _pumpPage(tester, transport, imageRecognitionGateway: gateway);

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('schedule-adjust-button')),
        250,
        scrollable: _scheduleScrollable(),
      );
      await tester.tap(find.byKey(const ValueKey('schedule-adjust-button')));
      await tester.pumpAndSettle();

      expect(gateway.calls, 1);
      expect(
        find.byKey(const ValueKey('schedule-adjust-upload-dialog')),
        findsNothing,
      );
      expect(find.text('确认识别结果'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('schedule-recognition-preview-notice')),
        findsOneWidget,
      );
      expect(transport.createdBodies, isEmpty);
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('schedule-add-task-title-input')),
            )
            .controller
            ?.text,
        '识别吸奶',
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('schedule-task-time-input-1')),
          matching: find.text('11:45'),
        ),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const ValueKey('schedule-add-task-title-input')),
        '核对后的吸奶',
      );
      await tester.tap(
        find.byKey(const ValueKey('schedule-remove-task-row-1')),
      );
      await tester.tap(find.byKey(const ValueKey('schedule-add-task-submit')));
      await tester.pumpAndSettle();

      expect(transport.createdBodies, hasLength(1));
      expect(transport.createdBodies.single['task_time'], '08:30');
      expect(transport.createdBodies.single['title'], '核对后的吸奶');
      expect(transport.createdBodies.single['payload'], {
        'task_type': 'pumping',
      });
      expect(find.text('任务已添加'), findsOneWidget);
    },
  );

  testWidgets('screenshot cancellation and empty result never create tasks', (
    tester,
  ) async {
    final transport = _RecognizedCreateTransport();
    final gateway = _SequenceImageRecognitionGateway([
      const ScheduleImageRecognitionResult.cancelled(),
      ScheduleImageRecognitionResult.preview(const []),
    ]);
    await _pumpPage(tester, transport, imageRecognitionGateway: gateway);
    final button = find.byKey(const ValueKey('schedule-adjust-button'));
    await tester.scrollUntilVisible(
      button,
      250,
      scrollable: _scheduleScrollable(),
    );
    await tester.drag(_scheduleScrollable(), const Offset(0, -80));
    await tester.pumpAndSettle();

    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('已取消选择截图'), findsNothing);
    expect(find.text('正在识别截图，结果不会自动写入计划…'), findsNothing);
    expect(transport.createdBodies, isEmpty);

    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('未识别到带有明确时间的日程任务'), findsOneWidget);
    expect(transport.createdBodies, isEmpty);
  });

  testWidgets(
    'screenshot recognition failure is shown as an honest live error',
    (tester) async {
      final gateway = _FailingImageRecognitionGateway();
      await _pumpPage(tester, _transport(), imageRecognitionGateway: gateway);
      final button = find.byKey(const ValueKey('schedule-adjust-button'));
      await tester.scrollUntilVisible(
        button,
        250,
        scrollable: _scheduleScrollable(),
      );
      await tester.drag(_scheduleScrollable(), const Offset(0, -80));
      await tester.pumpAndSettle();

      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(find.text('识别服务正在维护，请稍后重试'), findsOneWidget);
      final feedback = tester.widget<Semantics>(
        find.byKey(const ValueKey('schedule-feedback-banner')),
      );
      expect(feedback.properties.liveRegion, isTrue);
    },
  );
}

FixtureApiJsonTransportByPath _transport({
  Map<String, Map<String, Object?>> writeResponsesByPath = const {},
  List<Map<String, Object?>>? tasks,
  List<Map<String, Object?>>? feedingRecords,
  List<Map<String, Object?>>? pumpingRecords,
  List<Map<String, Object?>>? plans,
}) {
  return FixtureApiJsonTransportByPath({
    scheduleDayPlanEndpoint: {
      'items':
          tasks ??
          const [
            {
              'id': 'task-pump',
              'plan_id': 'plan-1',
              'task_date': '2026-07-03',
              'task_time': '10:30',
              'title': '泵奶',
              'description': '',
              'status': 'completed',
              'payload': {
                'task_type': 'pumping',
                'source': 'agent_action',
                'agent_action_id': 'private-agent-action-id',
              },
            },
            {
              'id': 'task-feed',
              'plan_id': 'plan-1',
              'task_date': '2026-07-03',
              'task_time': '14:00',
              'title': '喂养',
              'description': '',
              'status': 'completed',
              'payload': {'task_type': 'feeding'},
            },
          ],
    },
    schedulePlansEndpoint: {
      'items':
          plans ??
          const [
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
    scheduleFeedingRecordsEndpoint: {
      'items':
          feedingRecords ??
          const [
            {
              'id': 'feed-1',
              'plan_task_id': 'task-feed',
              'feed_time': '2026-07-03T14:00:00Z',
              'feed_type': 'bottle',
              'volume_ml': 80,
              'title': '喂养记录',
            },
          ],
    },
    schedulePumpingRecordsEndpoint: {
      'items':
          pumpingRecords ??
          const [
            {
              'id': 'pump-1',
              'plan_task_id': null,
              'pump_start_time': '2026-07-03T08:00:00Z',
              'milk_volume_ml': 120,
              'duration_seconds': 900,
              'title': '吸奶记录',
            },
          ],
    },
  }, writeResponsesByPath: writeResponsesByPath);
}

Future<void> _pumpPage(
  WidgetTester tester,
  FixtureApiJsonTransportByPath transport, {
  DateTime? initialDay,
  ScheduleReminderGateway reminderGateway =
      const UnsupportedScheduleReminderGateway(),
  ScheduleReminderPreferenceStore reminderPreferenceStore =
      const DisabledScheduleReminderPreferenceStore(),
  Uri? routeUri,
  Object? routeExtra,
  bool disableAnimations = false,
  MilkPlanChangeStore? milkPlanChangeStore,
  VolumeUnitPreferenceStore? volumeUnitPreferenceStore,
  ScheduleImageRecognitionGateway? imageRecognitionGateway,
  DateTime? now,
  Future<DateTime?> Function()? deliveryDateLoader,
  bool settle = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(disableAnimations: disableAnimations),
        child: child!,
      ),
      home: Scaffold(
        body: ScheduleDashboardPage(
          repository: ScheduleApiRepository(transport: transport),
          now: () => now ?? DateTime.utc(2026, 7, 3, 10),
          initialDay: initialDay,
          routeUri: routeUri,
          routeExtra: routeExtra,
          onOpenAgent: () {},
          reminderGateway: reminderGateway,
          reminderPreferenceStore: reminderPreferenceStore,
          milkPlanChangeStore: milkPlanChangeStore,
          deliveryDateLoader: deliveryDateLoader,
          volumeUnitPreferenceStore: volumeUnitPreferenceStore,
          imageRecognitionGateway: imageRecognitionGateway,
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

class _DeferredScheduleTransport extends FixtureApiJsonTransportByPath {
  _DeferredScheduleTransport() : super(const <String, Map<String, Object?>>{});

  final Completer<Map<String, Object?>> _response =
      Completer<Map<String, Object?>>();

  void complete() {
    if (!_response.isCompleted) {
      _response.complete(const {'items': <Object?>[]});
    }
  }

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) {
    lastMethod = 'GET';
    lastPath = path;
    lastQuery = Map<String, Object?>.from(query);
    getPaths.add(path);
    return _response.future;
  }
}

class _GateableScheduleTransport extends FixtureApiJsonTransportByPath {
  _GateableScheduleTransport()
    : super({
        scheduleDayPlanEndpoint: const {
          'items': [
            {
              'id': 'refresh-task',
              'plan_id': 'plan-1',
              'task_date': '2026-07-03',
              'task_time': '14:00',
              'title': '下午吸奶',
              'status': 'pending',
              'payload': {'task_type': 'pumping'},
            },
          ],
        },
        schedulePlansEndpoint: const {
          'items': [
            {
              'id': 'plan-1',
              'plan_type': 'milk_management',
              'title': '稳奶计划',
              'summary': '按当前阶段稳步执行',
              'status': 'active',
              'version': 1,
              'payload': {'postpartum_week': 29, 'phase': '离乳期'},
            },
          ],
        },
        scheduleFeedingRecordsEndpoint: const {'items': <Object?>[]},
        schedulePumpingRecordsEndpoint: const {'items': <Object?>[]},
      });

  Completer<void>? _gate;

  void deferRequests() {
    _gate = Completer<void>();
  }

  void completeRequests() {
    final gate = _gate;
    _gate = null;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) async {
    final gate = _gate;
    if (gate != null) await gate.future;
    return super.getJson(path, query: query);
  }
}

class _DeferredTaskMutationTransport extends FixtureApiJsonTransportByPath {
  _DeferredTaskMutationTransport()
    : super({
        scheduleDayPlanEndpoint: const {
          'items': [
            {
              'id': 'deferred-task',
              'plan_id': 'plan-1',
              'task_date': '2026-07-03',
              'task_time': '14:00',
              'title': '补充维生素',
              'status': 'pending',
              'payload': {'task_type': 'other'},
            },
          ],
        },
        schedulePlansEndpoint: const {
          'items': [
            {
              'id': 'plan-1',
              'plan_type': 'milk_management',
              'title': '稳奶计划',
              'summary': '按当前阶段稳步执行',
              'status': 'active',
              'version': 1,
              'payload': {'postpartum_week': 29, 'phase': '离乳期'},
            },
          ],
        },
        scheduleFeedingRecordsEndpoint: const {'items': <Object?>[]},
        schedulePumpingRecordsEndpoint: const {'items': <Object?>[]},
      });

  final Completer<Map<String, Object?>> _mutation =
      Completer<Map<String, Object?>>();
  bool mutationStarted = false;

  void completeMutation() {
    if (_mutation.isCompleted) return;
    _mutation.complete(const {
      'id': 'deferred-task',
      'plan_id': 'plan-1',
      'task_date': '2026-07-03',
      'task_time': '14:00',
      'title': '补充维生素',
      'status': 'completed',
      'payload': {'task_type': 'other'},
    });
  }

  @override
  Future<Map<String, Object?>> patchJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) {
    mutationStarted = true;
    lastMethod = 'PATCH';
    lastPath = path;
    lastBody = Map<String, Object?>.from(body);
    lastHeaders = Map<String, String>.from(headers);
    postedBodies.add(lastBody!);
    return _mutation.future;
  }
}

class _FakeImageRecognitionGateway implements ScheduleImageRecognitionGateway {
  _FakeImageRecognitionGateway(this.result);

  final ScheduleImageRecognitionResult result;
  int calls = 0;

  @override
  Future<ScheduleImageRecognitionResult> pickAndRecognize() async {
    calls += 1;
    return result;
  }
}

class _SequenceImageRecognitionGateway
    implements ScheduleImageRecognitionGateway {
  _SequenceImageRecognitionGateway(this.results);

  final List<ScheduleImageRecognitionResult> results;
  int _index = 0;

  @override
  Future<ScheduleImageRecognitionResult> pickAndRecognize() async {
    return results[_index++];
  }
}

class _FailingImageRecognitionGateway
    implements ScheduleImageRecognitionGateway {
  @override
  Future<ScheduleImageRecognitionResult> pickAndRecognize() {
    throw const ScheduleImageRecognitionException(
      'maintenance',
      '识别服务正在维护，请稍后重试',
    );
  }
}

class _RecognizedCreateTransport extends FixtureApiJsonTransportByPath {
  _RecognizedCreateTransport()
    : super({
        scheduleDayPlanEndpoint: const {'items': <Object?>[]},
        schedulePlansEndpoint: const {'items': <Object?>[]},
        scheduleFeedingRecordsEndpoint: const {'items': <Object?>[]},
        schedulePumpingRecordsEndpoint: const {'items': <Object?>[]},
      });

  final List<Map<String, Object?>> createdBodies = [];

  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    createdBodies.add(Map<String, Object?>.from(body));
    return {
      'id': 'recognized-${createdBodies.length}',
      'plan_id': body['plan_id'],
      'task_date': body['task_date'],
      'task_time': body['task_time'],
      'title': body['title'],
      'description': body['description'],
      'status': 'pending',
      'payload': body['payload'],
    };
  }
}

class _SuccessfulReminderGateway implements ScheduleReminderGateway {
  @override
  bool get isSupported => true;

  @override
  Future<bool> setEnabled({
    required bool enabled,
    required List<ScheduleTask> tasks,
  }) async => true;
}

class _DeferredReminderGateway implements ScheduleReminderGateway {
  final Completer<bool> _result = Completer<bool>();
  int calls = 0;

  @override
  bool get isSupported => true;

  void complete(bool value) {
    if (!_result.isCompleted) _result.complete(value);
  }

  @override
  Future<bool> setEnabled({
    required bool enabled,
    required List<ScheduleTask> tasks,
  }) {
    calls += 1;
    return _result.future;
  }
}

class _ThrowingReminderGateway implements ScheduleReminderGateway {
  @override
  bool get isSupported => true;

  @override
  Future<bool> setEnabled({
    required bool enabled,
    required List<ScheduleTask> tasks,
  }) {
    throw StateError('reminder gateway unavailable');
  }
}

class _FakeReminderStore implements ScheduleReminderPreferenceStore {
  _FakeReminderStore({required this.enabled});

  bool enabled;

  @override
  Future<bool> readEnabled() async => enabled;

  @override
  Future<void> writeEnabled(bool enabled) async {
    this.enabled = enabled;
  }
}

class _FakeVolumeUnitPreferenceStore implements VolumeUnitPreferenceStore {
  _FakeVolumeUnitPreferenceStore(this.unit);

  final MomCozyVolumeUnit unit;

  @override
  Future<MomCozyVolumeUnit?> read() async => unit;

  @override
  Future<void> write(MomCozyVolumeUnit unit) async {}
}

class _LostResponseCreateTransport extends FixtureApiJsonTransportByPath {
  _LostResponseCreateTransport()
    : super({
        schedulePlansEndpoint: const {'items': <Object?>[]},
        scheduleFeedingRecordsEndpoint: const {'items': <Object?>[]},
        schedulePumpingRecordsEndpoint: const {'items': <Object?>[]},
      });

  static const _createdTask = <String, Object?>{
    'id': 'server-created',
    'plan_id': null,
    'task_date': '2026-07-03',
    'task_time': '21:30',
    'title': '响应丢失任务',
    'description': '',
    'status': 'pending',
    'payload': {'task_type': 'pumping'},
  };

  bool _committed = false;
  int _postCount = 0;
  final List<String?> idempotencyKeys = [];

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) async {
    if (path != scheduleDayPlanEndpoint) {
      return super.getJson(path, query: query);
    }
    lastMethod = 'GET';
    lastPath = path;
    lastQuery = Map<String, Object?>.from(query);
    getPaths.add(path);
    return {
      'items': _committed ? [_createdTask] : <Object?>[],
    };
  }

  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    lastMethod = 'POST';
    lastPath = path;
    lastBody = Map<String, Object?>.from(body);
    lastHeaders = Map<String, String>.from(headers);
    postedBodies.add(lastBody!);
    idempotencyKeys.add(headers['Idempotency-Key']);
    _postCount += 1;
    _committed = true;
    if (_postCount == 1) throw StateError('response lost');
    return _createdTask;
  }
}

class _MultiCreateTransport extends FixtureApiJsonTransportByPath {
  _MultiCreateTransport()
    : super({
        scheduleDayPlanEndpoint: const {'items': <Object?>[]},
        schedulePlansEndpoint: const {'items': <Object?>[]},
        scheduleFeedingRecordsEndpoint: const {'items': <Object?>[]},
        schedulePumpingRecordsEndpoint: const {'items': <Object?>[]},
      });

  final List<String?> idempotencyKeys = [];
  int _sequence = 0;

  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    _sequence += 1;
    lastMethod = 'POST';
    lastPath = path;
    lastBody = Map<String, Object?>.from(body);
    lastHeaders = Map<String, String>.from(headers);
    postedBodies.add(lastBody!);
    idempotencyKeys.add(headers['Idempotency-Key']);
    return {
      'id': 'multi-created-$_sequence',
      'plan_id': body['plan_id'],
      'task_date': body['task_date'],
      'task_time': body['task_time'],
      'title': body['title'],
      'description': body['description'],
      'status': 'pending',
      'payload': body['payload'],
    };
  }
}

class _RecordIntentTransport extends FixtureApiJsonTransportByPath {
  _RecordIntentTransport()
    : super({
        scheduleDayPlanEndpoint: const {'items': <Object?>[]},
        schedulePlansEndpoint: const {'items': <Object?>[]},
        scheduleFeedingRecordsEndpoint: const {'items': <Object?>[]},
        schedulePumpingRecordsEndpoint: const {'items': <Object?>[]},
      });

  final List<String?> idempotencyKeys = [];
  final List<Object?> feedTypes = [];

  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    lastMethod = 'POST';
    lastPath = path;
    lastBody = Map<String, Object?>.from(body);
    lastHeaders = Map<String, String>.from(headers);
    postedBodies.add(lastBody!);
    idempotencyKeys.add(headers['Idempotency-Key']);
    feedTypes.add(body['feed_type']);
    if (idempotencyKeys.length < 3) throw StateError('response lost');
    return {
      'id': 'feed-intent-created',
      'plan_task_id': body['plan_task_id'],
      'feed_time': body['feed_time'],
      'feed_type': body['feed_type'],
      'volume_ml': body['volume_ml'],
      'duration_seconds': body['duration_seconds'],
      'title': '喂养记录',
    };
  }
}

AgentStreamEvent _milkPlanChangedEvent({
  required String eventId,
  required List<String> affectedDates,
  String operation = 'updated',
  String reason = 'plan_metadata_updated',
}) {
  return AgentStreamEvent({
    'event_id': eventId,
    'sequence': 1,
    'type': 'milk_plan.changed',
    'thread_id': 'thread-milk',
    'run_id': 'run-milk',
    'payload': {
      'operation': operation,
      'reason': reason,
      'plan_id': 'private-plan-id',
      'plan_type': 'milk_management',
      'source': 'agent_action',
      'affected_dates': affectedDates,
    },
  });
}

Finder _scheduleScrollable() => find
    .descendant(
      of: find.byKey(const ValueKey('schedule-scroll-content')),
      matching: find.byType(Scrollable),
    )
    .first;
