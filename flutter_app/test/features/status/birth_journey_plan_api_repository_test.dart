import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/status/data/birth_journey_plan_api_repository.dart';

import '../../support/fixture_api_transport.dart';

void main() {
  group('BirthJourneyPlanApiRepository', () {
    test('selects and normalizes the active birth journey plan', () async {
      final transport = FixtureApiJsonTransport({
        'items': [
          {
            'id': 'other-plan',
            'plan_type': 'milk_plan',
            'title': '吸乳计划',
            'summary': '',
            'status': 'active',
            'payload': {},
          },
          {
            'id': 'birth-plan-001',
            'plan_type': 'birth_journey',
            'title': '孕期计划',
            'summary': '当前阶段重点',
            'status': 'active',
            'payload': {
              'next_action': {'send_text': '继续完善孕期计划'},
              'todo_plan': {
                'periods': [
                  {
                    'id': 'period-current',
                    'title': '孕 25-27 周',
                    'subtitle': '完成重点检查',
                    'display_mode': 'expanded',
                    'status': 'current',
                    'items': [
                      {
                        'id': 'task-001',
                        'title': '做糖耐检查（OGTT）',
                        'reason': '重要｜这几周是关键检查窗口。',
                        'steps': ['提前预约', '提前预约', '按要求禁食'],
                        'completed': 'done',
                      },
                    ],
                  },
                  {
                    'title': '孕 28-29 周',
                    'items': ['固定观察胎动'],
                  },
                ],
              },
            },
          },
        ],
      });
      final repository = BirthJourneyPlanApiRepository(transport: transport);

      final plan = await repository.fetchActivePlan();

      expect(transport.lastQuery, {'status': 'active', 'limit': 50});
      expect(plan?.id, 'birth-plan-001');
      expect(plan?.periods, hasLength(2));
      expect(plan?.periods.first.isCurrent, isTrue);
      expect(plan?.periods.first.items.single.priorityLabel, '重要');
      expect(plan?.periods.first.items.single.reason, '这几周是关键检查窗口。');
      expect(plan?.periods.first.items.single.steps, ['提前预约', '按要求禁食']);
      expect(plan?.periods.first.items.single.completed, isTrue);
      expect(plan?.periods.last.displayMode, 'collapsed');
      expect(plan?.nextActionText, '继续完善孕期计划');
    });

    test('updates todo completion and deletes a plan', () async {
      final transport = FixtureApiJsonTransport(const {});
      final repository = BirthJourneyPlanApiRepository(transport: transport);

      await repository.updateTodoCompletion(
        taskId: 'task-001',
        completed: true,
      );

      expect(transport.lastMethod, 'PATCH');
      expect(
        transport.lastPath,
        '$statusPlanTasksEndpoint/task-001/completion',
      );
      expect(transport.lastBody, {'completed': true});

      await repository.deletePlan(planId: 'plan-001');
      expect(transport.lastMethod, 'DELETE');
      expect(transport.lastPath, '$statusPlansEndpoint/plan-001');
    });

    test('returns null when no active birth journey exists', () async {
      final repository = BirthJourneyPlanApiRepository(
        transport: FixtureApiJsonTransport({
          'items': [
            {'id': 'milk-plan', 'plan_type': 'milk_plan'},
          ],
        }),
      );

      expect(await repository.fetchActivePlan(), isNull);
    });
  });
}
