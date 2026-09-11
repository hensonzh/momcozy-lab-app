import 'dart:math' as math;
import '../shared/local_date.dart';
import 'baby_profile.dart';
import 'baby_record.dart';
import 'who_growth_values.dart';

const whoGrowthMaxMonths = 6;

enum GrowthReferenceInterval { weekly, monthly }

class GrowthReferencePoint {
  const GrowthReferencePoint(
    this.ageDays,
    this.lower,
    this.upper,
    this.interval,
  );
  final int ageDays;
  final double lower;
  final double upper;
  final GrowthReferenceInterval interval;
}

List<GrowthReferencePoint> whoReferencePoints(
  GrowthMetric metric,
  BabySex sex,
  LocalDate? birthDate,
) {
  if (sex == BabySex.unspecified || birthDate == null) return const [];
  final series = whoGrowthValues[metric]![sex]!;
  return List.unmodifiable([
    for (var week = 0; week < series.weeklyLower.length; week++)
      GrowthReferencePoint(
        week * 7,
        series.weeklyLower[week],
        series.weeklyUpper[week],
        GrowthReferenceInterval.weekly,
      ),
    for (var month = 4; month <= whoGrowthMaxMonths; month++)
      GrowthReferencePoint(
        birthDate.addMonths(month).daysSince(birthDate),
        series.monthlyLower[month],
        series.monthlyUpper[month],
        GrowthReferenceInterval.monthly,
      ),
  ]);
}

class GrowthChartScale {
  const GrowthChartScale(this.minimum, this.maximum);
  final double minimum;
  final double maximum;

  factory GrowthChartScale.forRecords(
    GrowthMetric metric,
    Iterable<BabyGrowthRecord> visibleRecords,
  ) {
    var (low, high) = switch (metric) {
      GrowthMetric.weight => (2.0, 10.0),
      GrowthMetric.length => (44.0, 74.0),
      GrowthMetric.headCircumference => (30.0, 46.0),
    };
    for (final record in visibleRecords.where(
      (value) => value.metric == metric,
    )) {
      low = math.min(low, record.value);
      high = math.max(high, record.value);
    }
    final padding = (high - low) * .04;
    return GrowthChartScale(math.max(0, low - padding), high + padding);
  }
}
