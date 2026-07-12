import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/pregnancy_plan/domain/pregnancy_plan.dart';
import 'package:momcozy_flutter_app/features/status/domain/birth_journey_plan.dart';

void main() {
  group('projectBirthJourneyPlan', () {
    test('maps the canonical nested card into the Status view model', () {
      final projected = projectBirthJourneyPlan(
        _plan(
          cardJson: {
            'title': '我的孕期计划',
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
                      'id': 'confirm_ogtt',
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
        ),
      );

      expect(projected.id, 'plan-pregnancy-1');
      expect(projected.version, 3);
      expect(projected.periods, hasLength(2));
      expect(projected.periods.first.isCurrent, isTrue);
      expect(projected.periods.first.items.single.id, 'confirm_ogtt');
      expect(projected.periods.first.items.single.canMutate, isFalse);
      expect(projected.periods.first.items.single.priorityLabel, '重要');
      expect(projected.periods.first.items.single.reason, '这几周是关键检查窗口。');
      expect(projected.periods.first.items.single.steps, ['提前预约', '按要求禁食']);
      expect(projected.periods.first.items.single.completed, isTrue);
      expect(projected.nextActionText, '继续完善孕期计划');
    });

    test('rejects a malformed card instead of projecting an empty plan', () {
      expect(
        () => projectBirthJourneyPlan(_plan(cardJson: const {})),
        throwsFormatException,
      );
    });

    test('keeps valid periods when adjacent legacy payload entries are invalid', () {
      final projected = projectBirthJourneyPlan(
        _plan(
          cardJson: {
            'todo_plan': {
              'periods': [
                {
                  'title': '损坏阶段',
                  'items': <Object?>[],
                },
                {
                  'id': 'current',
                  'title': '当前阶段',
                  'status': 'current',
                  'items': [
                    {'title': ''},
                    {
                      'item_id': 'stable-item-1',
                      'title': '有效事项',
                    },
                  ],
                },
              ],
            },
          },
        ),
      );

      expect(projected.periods, hasLength(1));
      expect(projected.periods.single.items, hasLength(1));
      expect(projected.periods.single.items.single.id, 'stable-item-1');
      expect(projected.periods.single.items.single.canMutate, isTrue);
    });
  });
}

PregnancyPlan _plan({required Map<String, Object?> cardJson}) {
  return PregnancyPlan(
    id: 'plan-pregnancy-1',
    version: 3,
    planType: 'pregnancy',
    title: '孕期计划',
    summary: '当前阶段重点',
    status: 'active',
    source: 'agent_action',
    payload: {
      'card': {
        'card_type': 'birth_journey_plan_card',
        'schema_version': '1.0',
        'card_json': cardJson,
      },
    },
  );
}
