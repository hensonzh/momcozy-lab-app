import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/records/domain/records.dart';
import 'package:momcozy_flutter_app/features/status/domain/postpartum_mom.dart';

void main() {
  group('PostpartumMilkProjection', () {
    test('separates today summary from the prior seven chart days', () {
      final projection = PostpartumMilkProjection.fromTrendDays(
        now: DateTime(2026, 7, 11, 15),
        days: [
          MilkTrendDay(
            date: DateTime(2026, 7, 11),
            pumpedMilkVolumeMl: 240,
            pumpingCount: 3,
          ),
          MilkTrendDay(
            date: DateTime(2026, 7, 10),
            pumpedMilkVolumeMl: 180,
            pumpingCount: 2,
          ),
          MilkTrendDay(
            date: DateTime(2026, 7, 4),
            pumpedMilkVolumeMl: 90,
            pumpingCount: 1,
          ),
        ],
      );

      final window = projection.window(7);

      expect(projection.today?.pumpedMilkVolumeMl, 240);
      expect(projection.today?.pumpingCount, 3);
      expect(window.points, hasLength(7));
      expect(window.points.first.date, DateTime(2026, 7, 4));
      expect(window.points.first.actualMl, 90);
      expect(window.points.last.date, DateTime(2026, 7, 10));
      expect(window.points.last.actualMl, 180);
      expect(window.hasMeasurements, isTrue);
    });

    test(
      'fills missing dates without treating zero placeholders as records',
      () {
        final projection = PostpartumMilkProjection.fromTrendDays(
          now: DateTime(2026, 7, 11),
          days: [
            MilkTrendDay(
              date: DateTime(2026, 7, 9),
              pumpedMilkVolumeMl: 0,
              pumpingCount: 0,
            ),
          ],
        );

        final window = projection.window(7);

        expect(window.points, hasLength(7));
        expect(window.hasMeasurements, isFalse);
        expect(window.supportsEstimate, isFalse);
        expect(window.supportsReference, isFalse);
      },
    );

    test('normalizes optional estimate and reference analytics safely', () {
      final projection = PostpartumMilkProjection.fromTrendDays(
        now: DateTime(2026, 7, 11),
        days: [
          MilkTrendDay(
            date: DateTime(2026, 7, 10),
            pumpedMilkVolumeMl: -20,
            pumpingCount: -1,
            measuredOnly: false,
            estimatedMilkVolumeMl: 260,
            referenceLowerMl: 320,
            referenceUpperMl: 200,
          ),
        ],
      );

      final point = projection.window(7).points.last;

      expect(point.actualMl, 0);
      expect(point.pumpingCount, 0);
      expect(point.estimatedMl, 260);
      expect(point.referenceLowerMl, 320);
      expect(point.referenceUpperMl, 320);
      expect(point.hasMeasurement, isTrue);
    });
  });
}
