import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/schedule/data/schedule_api_repository.dart';
import 'package:momcozy_flutter_app/features/schedule/domain/schedule_plan.dart';

import '../../support/fixture_api_transport.dart';

void main() {
  group('ScheduleApiRepository', () {
    test(
      'loads plan context, typed tasks, and records as one day snapshot',
      () async {
        final transport = FixtureApiJsonTransportByPath({
          scheduleDayPlanEndpoint: const {
            'items': [
              {
                'id': 'task-feed',
                'plan_id': 'plan-1',
                'task_date': '2026-07-03',
                'task_time': '14:00',
                'title': '喂养',
                'description': '记录奶量',
                'status': 'skipped',
                'payload': {'task_type': 'feeding'},
              },
            ],
          },
          schedulePlansEndpoint: const {
            'items': [
              {
                'id': 'pregnancy-plan',
                'plan_type': 'pregnancy',
                'title': '孕期计划',
                'summary': '孕晚期事项',
                'status': 'active',
                'source': 'agent',
                'version': 4,
                'payload': {'pregnancy_week': 38},
              },
              {
                'id': 'plan-1',
                'plan_type': 'milk_management',
                'title': '稳奶计划',
                'summary': '按当前阶段稳步执行',
                'status': 'active',
                'source': 'agent',
                'version': 3,
                'payload': {'postpartum_week': 29, 'phase': '离乳期'},
              },
            ],
          },
          scheduleFeedingRecordsEndpoint: const {
            'items': [
              {
                'id': 'feed-1',
                'plan_task_id': 'task-feed',
                'feed_time': '2026-07-03T06:00:00Z',
                'feed_type': 'bottle',
                'volume_ml': 80,
                'title': '晨间喂养',
              },
            ],
          },
          schedulePumpingRecordsEndpoint: const {
            'items': [
              {
                'id': 'pump-1',
                'plan_task_id': null,
                'pump_start_time': '2026-07-03T02:30:00Z',
                'milk_volume_ml': 120,
                'duration_seconds': 900,
                'title': '晨间吸奶',
              },
            ],
          },
        });

        final snapshot = await ScheduleApiRepository(
          transport: transport,
        ).fetchDayPlan(day: DateTime.utc(2026, 7, 3));

        expect(
          transport.getPaths,
          containsAll(<String>[
            scheduleDayPlanEndpoint,
            schedulePlansEndpoint,
            scheduleFeedingRecordsEndpoint,
            schedulePumpingRecordsEndpoint,
          ]),
        );
        expect(snapshot.context?.title, '稳奶计划');
        expect(snapshot.context?.stageLabel, '产后第29周（离乳期）');
        expect(snapshot.tasks.single.state, ScheduleTaskState.skipped);
        expect(snapshot.tasks.single.completed, isFalse);
        expect(snapshot.tasks.single.kind, ScheduleTaskKind.feeding);
        expect(snapshot.records, hasLength(2));
        expect(snapshot.timeline, hasLength(2));
        expect(snapshot.timeline.first.id, 'pump-1');
        expect(snapshot.timeline.last.id, 'task-feed');
        expect(snapshot.timeline.last.linkedRecords.single.id, 'feed-1');
        expect(
          snapshot.timeline.map((entry) => entry.id),
          isNot(contains('feed-1')),
        );
        expect(snapshot.completedTaskCount, 0);
        expect(snapshot.skippedTaskCount, 1);
      },
    );

    test(
      'keeps request scoping server-owned and dates timezone-safe',
      () async {
        final transport = FixtureApiJsonTransportByPath({
          scheduleDayPlanEndpoint: const {'items': <Object?>[]},
          schedulePlansEndpoint: const {'items': <Object?>[]},
          scheduleFeedingRecordsEndpoint: const {'items': <Object?>[]},
          schedulePumpingRecordsEndpoint: const {'items': <Object?>[]},
        });

        await ScheduleApiRepository(
          transport: transport,
        ).fetchDayPlan(day: DateTime(2026, 7, 3));

        expect(transport.lastQuery, isNot(containsPair('user_id', anything)));
        expect(transport.getPaths, hasLength(4));
      },
    );

    test('does not use an unrelated active plan as schedule context', () async {
      final transport = FixtureApiJsonTransportByPath({
        scheduleDayPlanEndpoint: const {
          'items': [
            {
              'id': 'pregnancy-task',
              'plan_id': 'pregnancy-plan',
              'task_date': '2026-07-03',
              'task_time': '09:00',
              'title': '产检',
              'description': '',
              'status': 'pending',
              'payload': <String, Object?>{},
            },
          ],
        },
        schedulePlansEndpoint: const {
          'items': [
            {
              'id': 'pregnancy-plan',
              'plan_type': 'pregnancy',
              'title': '孕期计划',
              'summary': '',
              'status': 'active',
              'version': 2,
              'payload': {'pregnancy_week': 38},
            },
            {
              'id': 'milk-plan',
              'plan_type': 'milk_management',
              'title': '稳奶计划',
              'summary': '',
              'status': 'active',
              'version': 1,
              'payload': {'postpartum_week': 29},
            },
          ],
        },
        scheduleFeedingRecordsEndpoint: const {'items': <Object?>[]},
        schedulePumpingRecordsEndpoint: const {'items': <Object?>[]},
      });

      final snapshot = await ScheduleApiRepository(
        transport: transport,
      ).fetchDayPlan(day: DateTime.utc(2026, 7, 3));

      expect(snapshot.context, isNull);
    });

    test(
      'rejects malformed task collections instead of rendering empty',
      () async {
        final transport = FixtureApiJsonTransportByPath({
          scheduleDayPlanEndpoint: const {'items': 'not-a-list'},
          schedulePlansEndpoint: const {'items': <Object?>[]},
          scheduleFeedingRecordsEndpoint: const {'items': <Object?>[]},
          schedulePumpingRecordsEndpoint: const {'items': <Object?>[]},
        });

        await expectLater(
          ScheduleApiRepository(
            transport: transport,
          ).fetchDayPlan(day: DateTime.utc(2026, 7, 3)),
          throwsA(isA<FormatException>()),
        );
      },
    );

    test(
      'preserves available resources when one endpoint returns 503',
      () async {
        final transport = FixtureApiJsonTransportByPath({
          scheduleDayPlanEndpoint: const {
            'http_status': 503,
            'status_text': 'Service Unavailable',
          },
          schedulePlansEndpoint: const {'items': <Object?>[]},
          scheduleFeedingRecordsEndpoint: const {'items': <Object?>[]},
          schedulePumpingRecordsEndpoint: const {
            'items': [
              {
                'id': 'pump-available',
                'plan_task_id': null,
                'pump_start_time': '2026-07-03T02:30:00Z',
                'milk_volume_ml': 100,
                'title': '可用记录',
              },
            ],
          },
        });

        final snapshot = await ScheduleApiRepository(
          transport: transport,
        ).fetchDayPlan(day: DateTime.utc(2026, 7, 3));

        expect(snapshot.timeline.single.id, 'pump-available');
        expect(snapshot.syncWarnings, ['任务同步暂时不可用']);
      },
    );

    test('keeps an all-resource HTTP failure typed', () async {
      const unavailable = {
        'http_status': 503,
        'status_text': 'Service Unavailable',
      };
      final transport = FixtureApiJsonTransportByPath(const {
        scheduleDayPlanEndpoint: unavailable,
        schedulePlansEndpoint: unavailable,
        scheduleFeedingRecordsEndpoint: unavailable,
        schedulePumpingRecordsEndpoint: unavailable,
      });

      await expectLater(
        ScheduleApiRepository(
          transport: transport,
        ).fetchDayPlan(day: DateTime.utc(2026, 7, 3)),
        throwsA(isA<ApiHttpException>()),
      );
    });

    test('orders a task before a standalone record at the same time', () {
      final occurredAt = DateTime.utc(2026, 7, 3, 14);
      final snapshot = ScheduleDayPlan(
        day: DateTime.utc(2026, 7, 3),
        tasks: [
          ScheduleTask(
            id: 'task-same-time',
            title: '计划任务',
            remindAt: occurredAt,
          ),
        ],
        records: [
          ScheduleRecord(
            id: 'record-same-time',
            kind: ScheduleRecordKind.feeding,
            occurredAt: occurredAt,
          ),
        ],
      );

      expect(snapshot.timeline.map((entry) => entry.id), [
        'task-same-time',
        'record-same-time',
      ]);
    });

    test(
      'creates and edits tasks with authoritative response bodies',
      () async {
        final transport = FixtureApiJsonTransportByPath(
          const {},
          writeResponsesByPath: const {
            scheduleTasksEndpoint: {
              'id': 'task-new',
              'plan_id': 'plan-1',
              'task_date': '2026-07-03',
              'task_time': '21:30',
              'title': '晚间吸奶',
              'description': '',
              'status': 'pending',
              'payload': {'task_type': 'pumping'},
            },
            '$scheduleTasksEndpoint/task-new': {
              'id': 'task-new',
              'plan_id': 'plan-1',
              'task_date': '2026-07-03',
              'task_time': '22:00',
              'title': '睡前吸奶',
              'description': '',
              'status': 'pending',
              'payload': {'task_type': 'pumping'},
            },
            '$scheduleTasksEndpoint/task-new/state': {
              'id': 'task-new',
              'plan_id': 'plan-1',
              'task_date': '2026-07-03',
              'task_time': '22:00',
              'title': '睡前吸奶',
              'description': '',
              'status': 'completed',
              'payload': {'task_type': 'pumping'},
            },
          },
        );
        final repository = ScheduleApiRepository(transport: transport);

        final created = await repository.createTask(
          planId: 'plan-1',
          day: DateTime.utc(2026, 7, 3),
          time: '21:30',
          title: '晚间吸奶',
          kind: ScheduleTaskKind.pumping,
          idempotencyKey: 'create-task-1',
        );
        expect(created.id, 'task-new');
        expect(transport.lastHeaders, {'Idempotency-Key': 'create-task-1'});
        expect(transport.lastBody?['payload'], {'task_type': 'pumping'});

        final updated = await repository.updateTask(
          taskId: created.id,
          day: DateTime.utc(2026, 7, 3),
          time: '22:00',
          title: '睡前吸奶',
        );
        expect(updated.title, '睡前吸奶');

        final completed = await repository.setTaskState(
          taskId: created.id,
          state: ScheduleTaskState.completed,
        );
        expect(transport.lastPath, '$scheduleTasksEndpoint/task-new/state');
        expect(transport.lastBody, {'state': 'completed'});
        expect(completed.completed, isTrue);

        await repository.deleteTask(taskId: created.id);
        expect(transport.lastMethod, 'DELETE');
        expect(transport.lastPath, '$scheduleTasksEndpoint/task-new');
      },
    );

    test('creates linked pumping and feeding records idempotently', () async {
      final transport = FixtureApiJsonTransportByPath(
        const {},
        writeResponsesByPath: const {
          schedulePumpingRecordsEndpoint: {
            'id': 'pump-new',
            'plan_task_id': 'task-pump',
            'pump_start_time': '2026-07-03T10:30:00.000Z',
            'milk_volume_ml': 90,
            'duration_seconds': 1200,
            'title': '吸奶补录',
          },
          scheduleFeedingRecordsEndpoint: {
            'id': 'feed-new',
            'plan_task_id': 'task-feed',
            'feed_time': '2026-07-03T14:00:00.000Z',
            'feed_type': 'bottle',
            'volume_ml': 80,
            'title': '喂养记录',
          },
        },
      );
      final repository = ScheduleApiRepository(transport: transport);

      final pumping = await repository.createPumpingRecord(
        occurredAt: DateTime.utc(2026, 7, 3, 10, 30),
        amountMl: 90,
        durationSeconds: 1200,
        linkedTaskId: 'task-pump',
        idempotencyKey: 'pump-record-1',
      );
      expect(pumping.linkedTaskId, 'task-pump');
      expect(transport.lastHeaders, {'Idempotency-Key': 'pump-record-1'});

      final feeding = await repository.createFeedingRecord(
        occurredAt: DateTime.utc(2026, 7, 3, 14),
        amountMl: 80,
        linkedTaskId: 'task-feed',
        idempotencyKey: 'feed-record-1',
      );
      expect(feeding.kind, ScheduleRecordKind.feeding);
      expect(transport.lastBody?['plan_task_id'], 'task-feed');
      expect(transport.lastHeaders, {'Idempotency-Key': 'feed-record-1'});
    });
  });
}
