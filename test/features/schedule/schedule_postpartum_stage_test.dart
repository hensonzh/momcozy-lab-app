import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/schedule/domain/schedule_postpartum_stage.dart';

void main() {
  group('schedulePostpartumStageLabel', () {
    final deliveryDate = DateTime(2026, 6, 1, 23, 30);

    test('uses selected local calendar-day boundaries for every phase', () {
      expect(
        schedulePostpartumStageLabel(
          deliveryDate: deliveryDate,
          selectedDay: DateTime(2026, 6, 1, 1),
        ),
        '产后第1周（初乳期）',
      );
      expect(
        schedulePostpartumStageLabel(
          deliveryDate: deliveryDate,
          selectedDay: DateTime(2026, 6, 4),
        ),
        '产后第1周（初乳期）',
      );
      expect(
        schedulePostpartumStageLabel(
          deliveryDate: deliveryDate,
          selectedDay: DateTime(2026, 6, 5),
        ),
        '产后第1周（建立期）',
      );
      expect(
        schedulePostpartumStageLabel(
          deliveryDate: deliveryDate,
          selectedDay: DateTime(2026, 6, 29),
        ),
        '产后第5周（建立期）',
      );
      expect(
        schedulePostpartumStageLabel(
          deliveryDate: deliveryDate,
          selectedDay: DateTime(2026, 6, 30),
        ),
        '产后第5周（稳产期）',
      );
      expect(
        schedulePostpartumStageLabel(
          deliveryDate: deliveryDate,
          selectedDay: DateTime(2026, 11, 28),
        ),
        '产后第26周（稳产期）',
      );
      expect(
        schedulePostpartumStageLabel(
          deliveryDate: deliveryDate,
          selectedDay: DateTime(2026, 11, 29),
        ),
        '产后第26周（离乳期）',
      );
    });

    test('increments the postpartum week after each seven-day offset', () {
      expect(
        schedulePostpartumStageLabel(
          deliveryDate: deliveryDate,
          selectedDay: DateTime(2026, 6, 7),
        ),
        '产后第1周（建立期）',
      );
      expect(
        schedulePostpartumStageLabel(
          deliveryDate: deliveryDate,
          selectedDay: DateTime(2026, 6, 8),
        ),
        '产后第2周（建立期）',
      );
    });
  });
}
