import 'dart:math' as math;

import 'package:app/features/records/domain/records.dart';

class PostpartumMilkProjection {
  PostpartumMilkProjection._({
    required this.today,
    required this.historyByDate,
    required this.now,
  });

  factory PostpartumMilkProjection.fromTrendDays({
    required List<MilkTrendDay> days,
    required DateTime now,
  }) {
    final today = _dateOnly(now);
    final byDate = <int, MilkTrendDay>{};
    for (final day in days) {
      byDate[_dateKey(day.date)] = day;
    }
    return PostpartumMilkProjection._(
      today: byDate[_dateKey(today)],
      historyByDate: Map<int, MilkTrendDay>.unmodifiable(byDate),
      now: today,
    );
  }

  final MilkTrendDay? today;
  final Map<int, MilkTrendDay> historyByDate;
  final DateTime now;

  MilkTrendWindow window(int dayCount) {
    assert(dayCount > 0);
    final lastDay = now.subtract(const Duration(days: 1));
    final points = <MilkTrendPoint>[];
    for (var offset = dayCount - 1; offset >= 0; offset -= 1) {
      final date = lastDay.subtract(Duration(days: offset));
      final source = historyByDate[_dateKey(date)];
      final actual = math.max(0, source?.pumpedMilkVolumeMl ?? 0).toDouble();
      final estimate = source?.estimatedMilkVolumeMl;
      final referenceLower = source?.referenceLowerMl;
      final referenceUpper = source?.referenceUpperMl;
      double? safeLower;
      double? safeUpper;
      if (referenceLower != null && referenceUpper != null) {
        safeLower = math.max(0, referenceLower).toDouble();
        safeUpper = math.max(safeLower, math.max(0, referenceUpper)).toDouble();
      }
      points.add(
        MilkTrendPoint(
          date: date,
          actualMl: actual,
          pumpingCount: math.max(0, source?.pumpingCount ?? 0),
          estimatedMl: estimate == null
              ? null
              : math.max(0, estimate).toDouble(),
          referenceLowerMl: safeLower,
          referenceUpperMl: safeUpper,
          hasMeasurement:
              source != null &&
              (actual > 0 ||
                  source.pumpingCount > 0 ||
                  (estimate != null && estimate > 0)),
        ),
      );
    }
    return MilkTrendWindow(List<MilkTrendPoint>.unmodifiable(points));
  }
}

class MilkTrendWindow {
  const MilkTrendWindow(this.points);

  final List<MilkTrendPoint> points;

  bool get hasMeasurements => points.any((point) => point.hasMeasurement);
  bool get supportsEstimate => points.any((point) => point.estimatedMl != null);
  bool get supportsReference => points.any(
    (point) => point.referenceLowerMl != null && point.referenceUpperMl != null,
  );
}

class MilkTrendPoint {
  const MilkTrendPoint({
    required this.date,
    required this.actualMl,
    required this.pumpingCount,
    required this.hasMeasurement,
    this.estimatedMl,
    this.referenceLowerMl,
    this.referenceUpperMl,
  });

  final DateTime date;
  final double actualMl;
  final int pumpingCount;
  final bool hasMeasurement;
  final double? estimatedMl;
  final double? referenceLowerMl;
  final double? referenceUpperMl;
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

int _dateKey(DateTime value) {
  return value.year * 10000 + value.month * 100 + value.day;
}
