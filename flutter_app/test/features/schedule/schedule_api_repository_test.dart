import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/network/api_envelope.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/schedule/data/schedule_api_repository.dart';

import '../../support/fixture_api_transport.dart';
import '../../support/fixture_reader.dart';

void main() {
  group('ScheduleApiRepository', () {
    test('maps task success response and request contract', () async {
      final transport = _transport('success');
      final repository = ScheduleApiRepository(transport: transport);

      final plan = await repository.fetchDayPlan(
        userId: 'demo-user-fixture',
        day: DateTime.utc(2026, 6, 29),
      );

      expect(transport.lastPath, scheduleDayPlanEndpoint);
      expect(transport.lastQuery, {
        'user_id': 'demo-user-fixture',
        'timestamp': '2026-06-29T00:00:00Z',
      });
      expect(plan.tasks, hasLength(1));
      expect(plan.tasks.single.id, 'task-001');
      expect(plan.tasks.single.title, 'Hydration check');
      expect(plan.tasks.single.completed, isFalse);
      expect(
        plan.tasks.single.remindAt,
        DateTime.parse('2026-06-29T10:00:00Z'),
      );
    });

    test('accepts legacy aliases and partial empty data', () async {
      final legacy =
          await ScheduleApiRepository(
            transport: _transport('legacy_alias'),
          ).fetchDayPlan(
            userId: 'demo-user-fixture',
            day: DateTime.utc(2026, 6, 29),
          );
      final empty = await ScheduleApiRepository(transport: _transport('empty'))
          .fetchDayPlan(
            userId: 'demo-user-fixture',
            day: DateTime.utc(2026, 6, 29),
          );
      final partial =
          await ScheduleApiRepository(
            transport: _transport('partial'),
          ).fetchDayPlan(
            userId: 'demo-user-fixture',
            day: DateTime.utc(2026, 6, 29),
          );

      expect(legacy.tasks.single.id, 'task-001');
      expect(legacy.tasks.single.title, 'Hydration check');
      expect(empty.isEmpty, isTrue);
      expect(partial.tasks.single.id, 'task-001');
      expect(partial.tasks.single.completed, isFalse);
      expect(partial.tasks.single.remindAt, isNull);
    });

    test('keeps business and HTTP failures distinct', () async {
      await expectLater(
        ScheduleApiRepository(
          transport: _transport('business_error'),
        ).fetchDayPlan(
          userId: 'demo-user-fixture',
          day: DateTime.utc(2026, 6, 29),
        ),
        throwsA(isA<ApiBusinessException>()),
      );
      await expectLater(
        ScheduleApiRepository(transport: _transport('http_error')).fetchDayPlan(
          userId: 'demo-user-fixture',
          day: DateTime.utc(2026, 6, 29),
        ),
        throwsA(isA<ApiHttpException>()),
      );
    });
  });
}

FixtureApiJsonTransport _transport(String variant) {
  final fixture = readFixtureMap('api/plan/$variant.json');
  return FixtureApiJsonTransport(
    Map<String, Object?>.from(fixture['response']! as Map),
  );
}
