import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/plan/data/plan_api_repository.dart';
import 'package:momcozy_flutter_app/features/plan/domain/plan_dashboard.dart';

import '../../support/fixture_api_transport.dart';

void main() {
  test(
    'maps active plans and selected-day sessions into the new Plan domain',
    () async {
      final transport = FixtureApiJsonTransportByPath({
        planListEndpoint: const {
          'items': [
            {
              'id': 'milk-plan',
              'plan_type': 'milk_management',
              'title': 'Breast Pumping Plan',
              'summary': 'Five sessions every day',
              'status': 'active',
              'payload': {
                'week_number': 4,
                'total_weeks': 8,
                'sessions_per_day': 5,
                'daily_target_volume_ml': 600,
                'today_volume_ml': 473,
                'weekly_target_volume_ml': 4200,
                'weekly_volume_ml': 2850,
              },
            },
            {
              'id': 'yoga-plan',
              'plan_type': 'yoga',
              'title': 'Yoga',
              'summary': 'Recovery yoga',
              'status': 'active',
              'payload': <String, Object?>{},
            },
          ],
        },
        planSessionListEndpoint: const {
          'items': [
            {
              'id': 'session-1',
              'plan_id': 'milk-plan',
              'task_date': '2026-10-22',
              'task_time': '08:00',
              'title': 'Session 1',
              'status': 'completed',
              'payload': {'value_label': '120 ml'},
            },
            {
              'id': 'session-2',
              'plan_id': 'milk-plan',
              'task_date': '2026-10-22',
              'task_time': '11:00',
              'title': 'Session 2',
              'status': 'pending',
              'payload': <String, Object?>{},
            },
            {
              'id': 'legacy-standalone-task',
              'plan_id': null,
              'task_date': '2026-10-22',
              'task_time': '12:00',
              'title': 'Legacy standalone task',
              'status': 'pending',
              'payload': <String, Object?>{},
            },
          ],
        },
      });

      final dashboard = await PlanApiRepository(
        transport: transport,
      ).fetchDashboard(weekOf: DateTime(2026, 10, 22, 9, 41));

      expect(transport.getPaths, [planListEndpoint, planSessionListEndpoint]);
      expect(transport.lastQuery, {'task_date': '2026-10-22', 'limit': 100});
      expect(dashboard.plans, hasLength(2));
      expect(dashboard.plans.first.category, PlanCategory.lactation);
      expect(dashboard.plans.first.weekNumber, 4);
      expect(dashboard.plans.last.category, PlanCategory.yoga);
      expect(dashboard.sessions, hasLength(2));
      expect(dashboard.sessions.first.status, PlanSessionStatus.completed);
      expect(dashboard.sessions.first.valueLabel, '120 ml');
      expect(dashboard.sessions.last.status, PlanSessionStatus.next);
    },
  );

  test(
    'returns the supplied empty state when there are no active plans',
    () async {
      final transport = FixtureApiJsonTransportByPath({
        planListEndpoint: const {'items': <Object?>[]},
        planSessionListEndpoint: const {'items': <Object?>[]},
      });

      final dashboard = await PlanApiRepository(
        transport: transport,
      ).fetchDashboard(weekOf: DateTime(2026, 10, 22));

      expect(dashboard.isEmpty, isTrue);
      expect(transport.getPaths, [planListEndpoint]);
    },
  );

  test(
    'rejects malformed plan collections instead of showing false empty',
    () async {
      final transport = FixtureApiJsonTransportByPath({
        planListEndpoint: const {'items': 'invalid'},
      });

      await expectLater(
        PlanApiRepository(
          transport: transport,
        ).fetchDashboard(weekOf: DateTime(2026, 10, 22)),
        throwsA(isA<FormatException>()),
      );
    },
  );
}
