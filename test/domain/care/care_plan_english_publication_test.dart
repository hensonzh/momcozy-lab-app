import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/care/care_plan.dart';

void main() {
  final original = CarePlanContent(
    title: 'Care plan',
    summary: 'Try one small change today.',
    goals: ['Check in at your next consultation'],
    tasks: [
      const CarePlanTaskContent(
        sourceKey: 'record-observation',
        title: 'Record a feeding observation',
        description: 'Note the time and what you notice.',
        category: 'Observation',
        dueLabel: 'Today',
      ),
    ],
  );

  test(
    'legacy task metadata has English display labels without rewriting source',
    () {
      const task = CarePlanTaskContent(
        sourceKey: 'legacy',
        category: '观察',
        dueLabel: '今天',
      );
      expect(task.displayCategory, 'Observation');
      expect(task.displayDueLabel, 'Originally marked “Today”');
      expect(task.category, '观察');
      expect(task.dueLabel, '今天');

      const unknown = CarePlanTaskContent(
        sourceKey: 'unknown',
        category: 'Категория',
        dueLabel: '다음 주',
      );
      expect(unknown.displayCategory, 'Care task');
      expect(unknown.displayDueLabel, 'Ask your consultant about timing');
      expect(unknown.category, 'Категория');

      const branded = CarePlanTaskContent(
        sourceKey: 'branded',
        category: 'Cozymate check-in',
        dueLabel: 'Cozy Mate follow-up',
      );
      expect(branded.displayCategory, 'Momcozy AI check-in');
      expect(branded.displayDueLabel, 'Momcozy AI follow-up');
    },
  );

  test(
    'complete English plan is ready while source identifiers are unchanged',
    () {
      expect(original.complete, isTrue);
      expect(original.englishClientCopy, isTrue);
      expect(original.tasks.single.sourceKey, 'record-observation');
    },
  );

  test(
    'legacy content stays editable but requires English review before publishing',
    () {
      for (final unreviewed in [
        original.copyWith(title: '喂养计划'),
        original.copyWith(summary: 'Cozymate will help you.'),
        original.copyWith(goals: ['수유 기록']),
        original.copyWith(
          tasks: [
            original.tasks.first.copyWith(description: 'Запишите кормление.'),
          ],
        ),
        original.copyWith(
          tasks: [original.tasks.first.copyWith(dueLabel: 'مرحبا')],
        ),
      ]) {
        expect(unreviewed.complete, isTrue);
        expect(unreviewed.englishClientCopy, isFalse);
        expect(
          unreviewed.tasks.single.sourceKey,
          original.tasks.single.sourceKey,
        );
      }
    },
  );
}
