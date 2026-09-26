import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/baby/baby_profile.dart';
import 'package:momcozy_flutter_app/domain/baby/baby_record.dart';
import 'package:momcozy_flutter_app/domain/baby/growth_reference.dart';
import 'package:momcozy_flutter_app/domain/shared/local_date.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_labels.dart';

void main() {
  test(
    'WHO weekly and monthly points use actual calendar months through leap day',
    () {
      final birth = LocalDate(2024, 1, 31);
      expect(birth.addMonths(1), LocalDate(2024, 2, 29));
      final points = whoReferencePoints(
        GrowthMetric.weight,
        BabySex.female,
        birth,
      );
      expect(points, hasLength(17));
      expect(points[13].ageDays, 91);
      expect(points.last.ageDays, LocalDate(2024, 7, 31).daysSince(birth));
      expect(points.last.lower, 5.7);
      expect(points.last.upper, 9.3);
      expect(
        whoReferencePoints(GrowthMetric.weight, BabySex.unspecified, birth),
        isEmpty,
      );
      expect(
        whoReferencePoints(GrowthMetric.weight, BabySex.female, null),
        isEmpty,
      );
    },
  );
  test(
    'age uses completed calendar months and a missing date stays unknown',
    () {
      final baby = BabyProfile(
        id: 'baby',
        name: 'Baby',
        birthDate: LocalDate(2026, 1, 31),
      );
      expect(babyAgeLabel(baby, LocalDate(2026, 4, 30)), '3 months');
      final newborn = BabyProfile(
        id: 'newborn',
        name: 'Luna',
        birthDate: LocalDate(2026, 8, 18),
      );
      expect(babyAgeLabel(newborn, LocalDate(2026, 8, 19)), '1 day');
      expect(babyAgeLabel(newborn, LocalDate(2026, 9, 8)), '3 weeks');
      expect(babyAgeLabel(newborn, LocalDate(2026, 9, 9)), '3 weeks 1 day');
      expect(babyAgeLabel(baby, LocalDate(2028, 2, 29)), '2 years 1 month');
      expect(
        babyAgeLabel(
          const BabyProfile(id: 'baby', name: 'Baby'),
          LocalDate(2026, 4, 30),
        ),
        'Age not set',
      );
    },
  );
  test('record values outside the default chart range remain visible', () {
    final record = BabyGrowthRecord(
      id: 'record',
      babyId: 'baby',
      metric: GrowthMetric.weight,
      value: 12,
      recordedOn: LocalDate(2026, 9, 1),
      timezone: 'Asia/Shanghai',
    );
    final scale = GrowthChartScale.forRecords(GrowthMetric.weight, [record]);
    expect(scale.maximum, greaterThan(12));
    expect(scale.minimum, lessThan(2));
  });
}
