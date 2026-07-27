import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/records/domain/records.dart';
import 'package:app/features/status/domain/baby_status_projection.dart';

void main() {
  group('BabyFeedingProjection', () {
    test('counts every feeding and sums only measured nonnegative volume', () {
      final projection = BabyFeedingProjection.fromRecords(const [
        FeedingRecord(id: 'one', type: 'bottle', amountMl: 80),
        FeedingRecord(id: 'two', type: 'breast', amountMl: null),
        FeedingRecord(id: 'three', type: 'bottle', amountMl: -10),
      ]);

      expect(projection.feedingCount, 3);
      expect(projection.totalVolumeMl, 80);
      expect(BabyFeedingProjection.fromRecords(const []).totalVolumeMl, isNull);
    });
  });

  group('BabyGrowthProjection', () {
    test('deduplicates local days and matches legacy weekly interpolation', () {
      final projection = BabyGrowthProjection(
        birthDate: DateTime(2026, 7, 1),
        records: [
          _growth('latest', DateTime(2026, 7, 15, 10), 4, 54, 36),
          _growth('first-old', DateTime(2026, 7, 1, 8), 3.3, 49, 34),
          _growth('first-new', DateTime(2026, 7, 1, 18), 3.4, 50, 34.5),
        ],
      );

      expect(projection.records.map((record) => record.id), [
        'first-new',
        'latest',
      ]);
      expect(projection.latest?.id, 'latest');
      expect(projection.chartPoints, hasLength(3));
      expect(projection.chartPoints.map((point) => point.weekLabel), [
        'W0',
        'W1',
        'W2',
      ]);
      expect(projection.chartPoints[1].weightKg, 3.7);
      expect(projection.chartPoints[1].heightCm, 52);
      expect(projection.chartPoints[1].weightP25, 3.17);
      expect(projection.chartPoints[1].weightP75, 4.02);
      expect(projection.chartPoints[1].heightP25, 48.7);
      expect(projection.chartPoints[1].heightP75, 51.4);
    });

    test('falls back to first measurement and rejects incomplete rows', () {
      final projection = BabyGrowthProjection(
        birthDate: null,
        records: [
          GrowthRecord(
            id: 'incomplete',
            measuredAt: DateTime(2026, 7, 1),
            weightGram: 3400,
          ),
          _growth('first', DateTime(2026, 7, 8), 3.6, 51, 35),
          _growth('second', DateTime(2026, 7, 22), 4.2, 55, 36),
        ],
      );

      expect(projection.records.map((record) => record.id), [
        'first',
        'second',
      ]);
      expect(projection.chartPoints, hasLength(3));
      expect(projection.chartPoints.first.weightKg, 3.6);
      expect(projection.chartPoints.last.weightKg, 4.2);
    });

    test('selects stable week ticks without dropping endpoints', () {
      final ticks = pickBabyGrowthWeekTicks([
        for (var week = 0; week < 24; week += 1) 'W$week',
      ]);

      expect(ticks, hasLength(7));
      expect(ticks.first, 'W0');
      expect(ticks.last, 'W23');
    });
  });
}

GrowthRecord _growth(
  String id,
  DateTime measuredAt,
  double weightKg,
  double heightCm,
  double headCm,
) {
  return GrowthRecord(
    id: id,
    measuredAt: measuredAt,
    weightGram: (weightKg * 1000).round(),
    heightCm: heightCm,
    headCm: headCm,
  );
}
