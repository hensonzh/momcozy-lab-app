import 'dart:math' as math;

import 'package:momcozy_flutter_app/features/records/domain/records.dart';

class BabyFeedingProjection {
  const BabyFeedingProjection({
    required this.feedingCount,
    required this.totalVolumeMl,
  });

  factory BabyFeedingProjection.fromRecords(List<FeedingRecord> records) {
    var total = 0;
    var hasMeasuredVolume = false;
    for (final record in records) {
      final amount = record.amountMl;
      if (amount == null) continue;
      total += math.max(0, amount);
      hasMeasuredVolume = true;
    }
    return BabyFeedingProjection(
      feedingCount: records.length,
      totalVolumeMl: hasMeasuredVolume ? total : null,
    );
  }

  final int feedingCount;
  final int? totalVolumeMl;
}

class BabyGrowthProjection {
  BabyGrowthProjection({
    required List<GrowthRecord> records,
    required DateTime? birthDate,
  }) : records = _normalizedRecords(records),
       latest = _latestRecord(records),
       chartPoints = _chartPoints(records, birthDate);

  final List<GrowthRecord> records;
  final GrowthRecord? latest;
  final List<BabyGrowthChartPoint> chartPoints;

  List<String> get weekTicks {
    return pickBabyGrowthWeekTicks(
      chartPoints.map((point) => point.weekLabel).toList(growable: false),
    );
  }
}

class BabyGrowthChartPoint {
  const BabyGrowthChartPoint({
    required this.week,
    required this.weightKg,
    required this.weightP25,
    required this.weightP75,
    required this.heightCm,
    required this.heightP25,
    required this.heightP75,
  });

  final int week;
  final double weightKg;
  final double weightP25;
  final double weightP75;
  final double heightCm;
  final double heightP25;
  final double heightP75;

  String get weekLabel => 'W$week';
}

List<String> pickBabyGrowthWeekTicks(List<String> labels) {
  final count = labels.length;
  if (count == 0) return const <String>[];
  if (count <= 11) return List<String>.unmodifiable(labels);
  final target = math.min(11, math.max(7, (count / 6).ceil()));
  final selected = <int>{};
  for (var index = 0; index < target; index += 1) {
    selected.add((index / (target - 1) * (count - 1)).round());
  }
  final indices = selected.toList()..sort();
  return List<String>.unmodifiable(indices.map((index) => labels[index]));
}

List<GrowthRecord> _normalizedRecords(List<GrowthRecord> records) {
  final byDay = <DateTime, GrowthRecord>{};
  for (final record in records) {
    final measuredAt = record.measuredAt;
    if (measuredAt == null ||
        !_positive(record.weightKg) ||
        !_positive(record.heightCm)) {
      continue;
    }
    final local = measuredAt.isUtc ? measuredAt.toLocal() : measuredAt;
    final day = DateTime(local.year, local.month, local.day);
    final previous = byDay[day];
    if (previous == null ||
        (previous.measuredAt?.isBefore(measuredAt) ?? true)) {
      byDay[day] = record;
    }
  }
  final days = byDay.keys.toList()..sort();
  return List<GrowthRecord>.unmodifiable(days.map((day) => byDay[day]!));
}

GrowthRecord? _latestRecord(List<GrowthRecord> records) {
  GrowthRecord? latest;
  for (final record in records) {
    if (record.measuredAt == null) continue;
    if (latest == null || latest.measuredAt!.isBefore(record.measuredAt!)) {
      latest = record;
    }
  }
  return latest;
}

List<BabyGrowthChartPoint> _chartPoints(
  List<GrowthRecord> source,
  DateTime? birthDate,
) {
  final records = _normalizedRecords(source);
  if (records.isEmpty) return const <BabyGrowthChartPoint>[];
  final firstDate = _localDay(records.first.measuredAt!);
  final requestedAnchor = birthDate == null ? null : _localDay(birthDate);
  final anchor = requestedAnchor == null || requestedAnchor.isAfter(firstDate)
      ? firstDate
      : requestedAnchor;
  final latestDate = _localDay(records.last.measuredAt!);
  final totalWeeks = (latestDate.difference(anchor).inDays / 7).ceil();
  final points = <BabyGrowthChartPoint>[];
  for (var week = 0; week <= totalWeeks; week += 1) {
    final target = anchor.add(Duration(days: week * 7));
    var before = records.first;
    var after = records.last;
    for (var index = 0; index < records.length - 1; index += 1) {
      final currentDate = _localDay(records[index].measuredAt!);
      final nextDate = _localDay(records[index + 1].measuredAt!);
      if (!target.isBefore(currentDate) && !target.isAfter(nextDate)) {
        before = records[index];
        after = records[index + 1];
        break;
      }
    }
    final beforeDate = _localDay(before.measuredAt!);
    final afterDate = _localDay(after.measuredAt!);
    final span = afterDate.difference(beforeDate).inMilliseconds;
    final rawRatio = span > 0
        ? target.difference(beforeDate).inMilliseconds / span
        : 0.0;
    final ratio = rawRatio.clamp(0.0, 1.0);
    final weight = _round(
      before.weightKg! + (after.weightKg! - before.weightKg!) * ratio,
      2,
    );
    final height = _round(
      before.heightCm! + (after.heightCm! - before.heightCm!) * ratio,
      1,
    );
    points.add(
      BabyGrowthChartPoint(
        week: week,
        weightKg: weight,
        weightP25: _round(3 + week * 0.17, 2),
        weightP75: _round(3.8 + week * 0.22, 2),
        heightCm: height,
        heightP25: _round(48 + week * 0.7, 1),
        heightP75: _round(50.5 + week * 0.85, 1),
      ),
    );
  }
  return List<BabyGrowthChartPoint>.unmodifiable(points);
}

DateTime _localDay(DateTime value) {
  final local = value.isUtc ? value.toLocal() : value;
  return DateTime(local.year, local.month, local.day);
}

bool _positive(double? value) {
  return value != null && value.isFinite && value > 0;
}

double _round(double value, int places) {
  final factor = math.pow(10, places).toDouble();
  return (value * factor).round() / factor;
}
