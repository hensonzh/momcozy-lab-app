import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/pregnancy_plan/data/pregnancy_plan_api_repository.dart';

import '../../../support/fixture_api_transport.dart';

void main() {
  group('PregnancyPlanApiRepository', () {
    test(
      'reads the newest active pregnancy plan with its persisted card',
      () async {
        final transport = FixtureApiJsonTransport({
          'items': [
            {
              'id': 'plan-pregnancy-1',
              'version': 7,
              'owner_user_id': 'user-1',
              'plan_type': 'pregnancy',
              'title': '孕期计划',
              'summary': '从现在到生产前后的阶段计划与待办',
              'status': 'active',
              'source': 'agent_action',
              'payload': {
                'card': {
                  'card_type': 'birth_journey_plan_card',
                  'schema_version': '1.0',
                  'card_json': {
                    'title': '我的孕期计划',
                    'todo_plan': {
                      'periods': [
                        {
                          'title': '当前阶段｜孕 32 周起',
                          'items': [
                            {'title': '确认复查节奏'},
                          ],
                        },
                      ],
                    },
                  },
                },
              },
            },
          ],
        });
        final repository = PregnancyPlanApiRepository(transport: transport);

        final plan = await repository.fetchActivePlan();

        expect(transport.lastPath, pregnancyPlansEndpoint);
        expect(transport.lastQuery, {
          'plan_type': 'pregnancy',
          'status': 'active',
          'limit': 1,
        });
        expect(plan, isNotNull);
        expect(plan!.id, 'plan-pregnancy-1');
        expect(plan.version, 7);
        expect(plan.planType, 'pregnancy');
        expect(plan.status, 'active');
        expect(plan.source, 'agent_action');
        expect(plan.card['card_type'], 'birth_journey_plan_card');
        expect((plan.card['card_json']! as Map)['title'], '我的孕期计划');
      },
    );

    test('returns empty only for an explicit empty items list', () async {
      final plan = await PregnancyPlanApiRepository(
        transport: FixtureApiJsonTransport(const {'items': <Object?>[]}),
      ).fetchActivePlan();

      expect(plan, isNull);
    });

    test('deletes the canonical pregnancy plan by plan id', () async {
      final transport = FixtureApiJsonTransport(const <String, Object?>{});
      final repository = PregnancyPlanApiRepository(transport: transport);

      await repository.deletePlan(planId: 'plan-pregnancy-1');

      expect(transport.lastMethod, 'DELETE');
      expect(transport.lastPath, '$pregnancyPlansEndpoint/plan-pregnancy-1');
    });

    test(
      'updates a stable plan todo with optimistic concurrency metadata',
      () async {
        final transport = FixtureApiJsonTransport({
          'id': 'plan-pregnancy-1',
          'version': 8,
          'plan_type': 'pregnancy',
          'title': '孕期计划',
          'summary': '',
          'status': 'active',
          'source': 'agent_action',
          'payload': {
            'card': {
              'card_type': 'birth_journey_plan_card',
              'card_json': {
                'todo_plan': {
                  'periods': [
                    {
                      'title': '当前阶段',
                      'status': 'current',
                      'items': [
                        {
                          'item_id': 'item-stable-1',
                          'title': '确认复查节奏',
                          'completed': true,
                        },
                      ],
                    },
                  ],
                },
              },
            },
          },
        });
        final repository = PregnancyPlanApiRepository(transport: transport);

        final plan = await repository.updateTodoCompletion(
          planId: 'plan-pregnancy-1',
          itemId: 'item-stable-1',
          completed: true,
          expectedVersion: 7,
          idempotencyKey: 'plan-todo-completion-1',
        );

        expect(transport.lastMethod, 'PATCH');
        expect(
          transport.lastPath,
          '$pregnancyPlansEndpoint/plan-pregnancy-1/todos/item-stable-1/completion',
        );
        expect(transport.lastBody, {'completed': true, 'expected_version': 7});
        expect(transport.lastHeaders, {
          'Idempotency-Key': 'plan-todo-completion-1',
        });
        expect(plan.version, 8);
      },
    );

    test('rejects non-empty responses without a valid active plan', () async {
      final transport = FixtureApiJsonTransport({
        'items': [
          {
            'id': 'milk-plan',
            'plan_type': 'milk_management',
            'title': '泌乳计划',
            'status': 'active',
            'source': 'agent_action',
            'payload': {},
          },
          {
            'id': 'deleted-pregnancy-plan',
            'plan_type': 'pregnancy',
            'title': '旧孕期计划',
            'status': 'deleted',
            'source': 'agent_action',
            'payload': {},
          },
          {
            'id': '',
            'plan_type': 'pregnancy',
            'title': '损坏的计划',
            'status': 'active',
            'source': 'agent_action',
            'payload': {},
          },
        ],
      });

      expect(
        () =>
            PregnancyPlanApiRepository(transport: transport).fetchActivePlan(),
        throwsFormatException,
      );
    });

    test('rejects responses without an items list', () async {
      expect(
        () => PregnancyPlanApiRepository(
          transport: FixtureApiJsonTransport(const <String, Object?>{}),
        ).fetchActivePlan(),
        throwsFormatException,
      );
    });
  });
}
