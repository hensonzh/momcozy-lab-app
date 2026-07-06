import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/schedule/data/schedule_api_repository.dart';

import '../../support/fixture_api_transport.dart';

void main() {
  group('ScheduleApiRepository', () {
    test('maps production task list and request contract', () async {
      final transport = FixtureApiJsonTransport(const {
        'items': <Object?>[
          {
            'id': 'task-001',
            'owner_user_id': 'user-001',
            'task_date': '2026-06-29',
            'task_time': '10:00',
            'title': 'Hydration check',
            'description': '',
            'status': 'pending',
            'payload': <String, Object?>{},
          },
        ],
      });
      final repository = ScheduleApiRepository(transport: transport);

      final plan = await repository.fetchDayPlan(
        day: DateTime.utc(2026, 6, 29),
      );

      expect(transport.lastPath, scheduleDayPlanEndpoint);
      expect(transport.lastQuery, {'task_date': '2026-06-29', 'limit': 50});
      expect(transport.lastQuery, isNot(containsPair('user_id', anything)));
      expect(plan.tasks, hasLength(1));
      expect(plan.tasks.single.id, 'task-001');
      expect(plan.tasks.single.title, '10:00 Hydration check');
      expect(plan.tasks.single.completed, isFalse);
      expect(plan.tasks.single.remindAt, DateTime(2026, 6, 29, 10));
    });

    test('maps completed status and empty data', () async {
      final completed = await ScheduleApiRepository(
        transport: FixtureApiJsonTransport(const {
          'items': <Object?>[
            {
              'id': 'task-001',
              'owner_user_id': 'user-001',
              'task_date': '2026-06-29',
              'task_time': '10:00',
              'title': 'Hydration check',
              'description': '',
              'status': 'completed',
              'payload': <String, Object?>{},
            },
          ],
        }),
      ).fetchDayPlan(day: DateTime.utc(2026, 6, 29));
      final empty = await ScheduleApiRepository(
        transport: FixtureApiJsonTransport(const {'items': <Object?>[]}),
      ).fetchDayPlan(day: DateTime.utc(2026, 6, 29));

      expect(completed.tasks.single.id, 'task-001');
      expect(completed.tasks.single.title, '10:00 Hydration check');
      expect(completed.tasks.single.completed, isTrue);
      expect(empty.isEmpty, isTrue);
    });

    test('keeps HTTP failures typed', () async {
      await expectLater(
        ScheduleApiRepository(
          transport: FixtureApiJsonTransport(const {
            'http_status': 503,
            'status_text': 'Service Unavailable',
          }),
        ).fetchDayPlan(day: DateTime.utc(2026, 6, 29)),
        throwsA(isA<ApiHttpException>()),
      );
    });
  });
}
