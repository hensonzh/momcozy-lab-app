import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_event.dart';
import 'package:momcozy_flutter_app/core/preferences/volume_unit_preference.dart';
import 'package:momcozy_flutter_app/features/schedule/data/schedule_api_repository.dart';
import 'package:momcozy_flutter_app/features/schedule/domain/schedule_plan.dart';
import 'package:momcozy_flutter_app/features/schedule/domain/milk_plan_change_store.dart';
import 'package:momcozy_flutter_app/features/schedule/domain/schedule_reminder.dart';
import 'package:momcozy_flutter_app/features/schedule/presentation/schedule_dashboard_page.dart';

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
            'feed_type': 'bottle',
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
      await tester.pump();
      expect(find.text('总奶量：3.3 oz'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('schedule-record-submit')));
      await tester.pumpAndSettle();

      expect(transport.lastPath, schedulePumpingRecordsEndpoint);
      expect(transport.lastBody?['milk_volume_ml'], 98);

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
      expect(find.text('奶量'), findsOneWidget);
      expect(find.text('oz'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('schedule-record-amount-input')),
        '2.7',
      );
      await tester.tap(find.byKey(const ValueKey('schedule-record-submit')));
      await tester.pumpAndSettle();

      expect(transport.lastPath, scheduleFeedingRecordsEndpoint);
      expect(transport.lastBody?['volume_ml'], 80);
    },
  );

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

    await tester.drag(_scheduleScrollable(), const Offset(0, -350));
    await tester.pumpAndSettle();
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
    expect(find.textContaining('稳奶计划 · 产后第29周（离乳期）'), findsOneWidget);
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
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('schedule-next-task-badge-next-pump')),
      200,
      scrollable: _scheduleScrollable(),
    );
    expect(
      find.byKey(const ValueKey('schedule-next-task-badge-next-pump')),
      findsOneWidget,
    );
  });

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
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('schedule-record-entry-dialog')),
          matching: find.text('喂养记录'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('schedule-record-time-input')),
            )
            .controller
            ?.text,
        '14:00',
      );
      await tester.tap(find.text('亲喂'));
      await tester.pump();
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('schedule-record-amount-input')),
            )
            .enabled,
        isFalse,
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
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('schedule-record-entry-dialog')),
        matching: find.text('取消'),
      ),
    );
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
        await tester.tap(find.text('亲喂'));
        await tester.pump();
      } else {
        await tester.enterText(
          find.byKey(const ValueKey('schedule-record-amount-input')),
          '80',
        );
      }
      await tester.tap(find.byKey(const ValueKey('schedule-record-submit')));
      await tester.pumpAndSettle();
    }

    await submitFeeding(breast: false);
    await submitFeeding(breast: false);
    await submitFeeding(breast: true);

    expect(transport.idempotencyKeys, hasLength(3));
    expect(transport.idempotencyKeys[1], transport.idempotencyKeys[0]);
    expect(transport.idempotencyKeys[2], isNot(transport.idempotencyKeys[0]));
    expect(transport.feedTypes, ['bottle', 'bottle', 'breast']);
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
    expect(find.text('当天暂无执行内容'), findsNothing);
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
            'task_time': '21:30',
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
      expect(transport.lastBody?['task_time'], '21:30');
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
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('schedule-task-time-input-1')),
          )
          .controller
          ?.text,
      '21:45',
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
    expect(transport.postedBodies[0]['task_time'], '21:30');
    expect(transport.postedBodies[0]['payload'], {'task_type': 'pumping'});
    expect(transport.postedBodies[1]['title'], '第二项喂养');
    expect(transport.postedBodies[1]['task_time'], '21:45');
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

  testWidgets('quick records use current time and never invent measurements', (
    tester,
  ) async {
    await _pumpPage(
      tester,
      _transport(),
      now: DateTime.utc(2026, 7, 3, 10, 37),
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

    String fieldText(String key) =>
        tester.widget<TextField>(find.byKey(ValueKey(key))).controller!.text;
    expect(fieldText('schedule-record-time-input'), '10:37');
    expect(fieldText('schedule-record-left-amount-input'), isEmpty);
    expect(fieldText('schedule-record-right-amount-input'), isEmpty);
    expect(fieldText('schedule-record-duration-input'), isEmpty);

    await tester.tap(find.byKey(const ValueKey('schedule-record-submit')));
    await tester.pump();
    final error = tester.widget<Semantics>(
      find.byKey(const ValueKey('schedule-form-error')),
    );
    expect(error.properties.liveRegion, isTrue);
    expect(find.text('请填写有效的时间和奶量'), findsOneWidget);
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
    expect(find.text('完成 1 项，跳过 1 项。'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpPage(tester, _transport(), initialDay: DateTime.utc(2026, 7, 2));
    expect(find.text('这天的计划已结束'), findsOneWidget);
    expect(find.text('执行记录'), findsOneWidget);
    expect(find.textContaining('共完成 2 项，母乳产出 120 mL'), findsOneWidget);
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
      contains('14:00 喂养，已完成，80 mL · 22:00 完成'),
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
    expect(find.text('当天暂无任务或执行记录。'), findsOneWidget);
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

    await _pumpPage(
      tester,
      transport,
      routeUri: Uri.parse('/schedule?date=2026-07-04&taskId=long-task-17'),
    );

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
}

FixtureApiJsonTransportByPath _transport({
  Map<String, Map<String, Object?>> writeResponsesByPath = const {},
  List<Map<String, Object?>>? tasks,
  List<Map<String, Object?>>? feedingRecords,
  List<Map<String, Object?>>? pumpingRecords,
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
              'payload': {'task_type': 'pumping'},
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
  DateTime? now,
  Future<DateTime?> Function()? deliveryDateLoader,
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
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
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
}) {
  return AgentStreamEvent({
    'event_id': eventId,
    'sequence': 1,
    'type': 'milk_plan.changed',
    'thread_id': 'thread-milk',
    'run_id': 'run-milk',
    'payload': {
      'operation': 'created',
      'reason': 'created',
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
