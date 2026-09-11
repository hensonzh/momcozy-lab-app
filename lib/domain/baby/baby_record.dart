import '../shared/local_date.dart';
import '../shared/record_deletion.dart';

enum BabyRecordKind { feeding, sleep, diaper, growth, development }

const babyDevelopmentItems = {
  'looks-at-face': '看向靠近的脸',
  'responds-to-sound': '听到声音后有动作或表情反应',
  'lifts-head': '俯卧时短暂抬起头',
};

enum BabyFeedingMethod { breastfeeding, expressedMilk, formula }

enum FeedingSide { left, right, both }

enum DiaperKind { wet, dirty, both }

enum StoolColor { yellow, yellowBrown, green, brown, black, red, pale, unsure }

enum StoolConsistency { watery, loose, pasty, formed, hard, unsure }

enum StoolSign { blood, mucus }

enum GrowthMetric { weight, length, headCircumference }

enum DevelopmentStatus { observed, notObserved, unsure }

sealed class BabyRecord {
  const BabyRecord({required this.id, required this.babyId, this.version = 1});
  final String id;
  final String babyId;
  final int version;
  BabyRecordKind get recordKind => switch (this) {
    BabyFeedingRecord() => BabyRecordKind.feeding,
    BabySleepRecord() => BabyRecordKind.sleep,
    BabyDiaperRecord() => BabyRecordKind.diaper,
    BabyGrowthRecord() => BabyRecordKind.growth,
    BabyDevelopmentRecord() => BabyRecordKind.development,
  };

  Map<String, String> validate(DateTime now) => {
    if (babyId.trim().isEmpty) 'baby_id': 'required',
  };
}

sealed class TimedBabyRecord extends BabyRecord {
  const TimedBabyRecord({
    required super.id,
    required super.babyId,
    required this.occurredAt,
    super.version,
    this.note = '',
  });
  final DateTime occurredAt;
  final String note;
  @override
  Map<String, String> validate(DateTime now) => {
    ...super.validate(now),
    if (occurredAt.isAfter(now)) 'occurred_at': 'future_time',
    if (note.runes.length > 2000) 'note': 'too_long',
  };
}

/// Measurement/observation dates stay on their recorded calendar day.
sealed class DatedBabyRecord extends BabyRecord {
  const DatedBabyRecord({
    required super.id,
    required super.babyId,
    required this.recordedOn,
    required this.timezone,
    super.version,
  });
  final LocalDate recordedOn;
  final String timezone;
  @override
  Map<String, String> validate(DateTime now) => {
    ...super.validate(now),
    if (recordedOn.compareTo(LocalDate.fromDateTime(now)) > 0)
      'recorded_on': 'future_date',
    if (timezone.trim().isEmpty) 'timezone': 'required',
  };
}

final class BabyFeedingRecord extends TimedBabyRecord {
  const BabyFeedingRecord({
    required super.id,
    required super.babyId,
    required super.occurredAt,
    required this.method,
    this.side,
    this.volumeMl,
    this.durationMinutes,
    super.version,
    super.note,
  });
  final BabyFeedingMethod method;
  final FeedingSide? side;
  final double? volumeMl;
  final int? durationMinutes;

  @override
  Map<String, String> validate(DateTime now) => {
    ...super.validate(now),
    if (method == BabyFeedingMethod.breastfeeding && volumeMl != null)
      'volume_ml': 'nursing_has_no_measured_volume',
    if (method == BabyFeedingMethod.breastfeeding && side == null)
      'side': 'required',
    if (method != BabyFeedingMethod.breastfeeding && durationMinutes != null)
      'duration_minutes': 'bottle_has_no_nursing_duration',
    if (method != BabyFeedingMethod.breastfeeding && side != null)
      'side': 'bottle_has_no_breast_side',
    if (volumeMl != null &&
        (!volumeMl!.isFinite || volumeMl! <= 0 || volumeMl! > 1000))
      'volume_ml': 'out_of_range',
    if (durationMinutes != null &&
        (durationMinutes! <= 0 || durationMinutes! > 240))
      'duration_minutes': 'out_of_range',
  };
}

final class BabyDiaperRecord extends TimedBabyRecord {
  const BabyDiaperRecord({
    required super.id,
    required super.babyId,
    required super.occurredAt,
    required this.kind,
    this.color,
    this.consistency,
    this.signs = const {},
    super.version,
    super.note,
  });
  final DiaperKind kind;
  final StoolColor? color;
  final StoolConsistency? consistency;
  final Set<StoolSign> signs;
  @override
  Map<String, String> validate(DateTime now) => {
    ...super.validate(now),
    if (kind == DiaperKind.wet &&
        (color != null || consistency != null || signs.isNotEmpty))
      'stool': 'wet_diaper_has_no_stool_fields',
  };
}

final class BabySleepRecord extends TimedBabyRecord {
  const BabySleepRecord({
    required super.id,
    required super.babyId,
    required super.occurredAt,
    this.endedAt,
    super.version,
    super.note,
  });
  final DateTime? endedAt;
  @override
  Map<String, String> validate(DateTime now) => {
    ...super.validate(now),
    if (endedAt != null && !endedAt!.isAfter(occurredAt))
      'ended_at': 'end_before_start',
    if (endedAt?.isAfter(now) == true) 'ended_at': 'future_time',
  };
}

/// A single measured metric; units follow the metric (kg for weight, cm otherwise).
final class BabyGrowthRecord extends DatedBabyRecord {
  const BabyGrowthRecord({
    required super.id,
    required super.babyId,
    required super.recordedOn,
    required super.timezone,
    required this.metric,
    required this.value,
    super.version,
  });
  final GrowthMetric metric;
  final double value;
  String get unit => metric == GrowthMetric.weight ? 'kg' : 'cm';
  @override
  Map<String, String> validate(DateTime now) => {
    ...super.validate(now),
    if (!value.isFinite || value <= 0) 'value': 'positive_measurement_required',
    if (value > (metric == GrowthMetric.weight ? 50 : 150))
      'value': 'out_of_range',
  };
}

final class BabyDevelopmentRecord extends DatedBabyRecord {
  const BabyDevelopmentRecord({
    required super.id,
    required super.babyId,
    required super.recordedOn,
    required super.timezone,
    required this.itemId,
    required this.status,
    super.version,
  });
  final String itemId;
  String get label => babyDevelopmentItems[itemId] ?? '';
  final DevelopmentStatus status;
  @override
  Map<String, String> validate(DateTime now) => {
    ...super.validate(now),
    if (!babyDevelopmentItems.containsKey(itemId)) 'item_id': 'unknown_item',
  };
}

final class BabyDaySummary {
  const BabyDaySummary._({
    required this.feedingCount,
    required this.measuredIntakeMl,
    required this.wetCount,
    required this.dirtyCount,
    required this.sleepDuration,
    required this.sleepCount,
    required this.longestSleep,
    required this.nursingMinutes,
    this.latestFeeding,
    this.activeSleep,
  });

  factory BabyDaySummary.fromRecords(
    Iterable<BabyRecord> records, {
    required String babyId,
    required DayWindow window,
    required DateTime now,
  }) {
    var feedings = 0;
    double? intake;
    int? nursingMinutes;
    BabyFeedingRecord? latestFeeding;
    var wet = 0;
    var dirty = 0;
    final sleepIntervals = <(DateTime, DateTime)>[];
    BabySleepRecord? active;
    for (final record in records) {
      if (record is! TimedBabyRecord ||
          record.babyId != babyId ||
          record.occurredAt.isAfter(now)) {
        continue;
      }
      if (record is BabySleepRecord) {
        final start = record.occurredAt.isBefore(window.start)
            ? window.start
            : record.occurredAt;
        var end = record.endedAt ?? now;
        if (end.isAfter(now)) end = now;
        if (end.isAfter(window.end)) end = window.end;
        if (end.isAfter(start)) sleepIntervals.add((start, end));
        if (record.endedAt == null &&
            window.contains(now) &&
            (active == null || record.occurredAt.isAfter(active.occurredAt))) {
          active = record;
        }
        continue;
      }
      if (!window.contains(record.occurredAt)) continue;
      switch (record) {
        case BabyFeedingRecord(:final method, :final volumeMl):
          feedings++;
          if (latestFeeding == null ||
              record.occurredAt.isAfter(latestFeeding.occurredAt)) {
            latestFeeding = record;
          }
          if (method != BabyFeedingMethod.breastfeeding && volumeMl != null) {
            intake = (intake ?? 0) + volumeMl;
          }
          if (method == BabyFeedingMethod.breastfeeding &&
              record.durationMinutes != null) {
            nursingMinutes = (nursingMinutes ?? 0) + record.durationMinutes!;
          }
        case BabyDiaperRecord(:final kind):
          if (kind != DiaperKind.dirty) wet++;
          if (kind != DiaperKind.wet) dirty++;
        default:
          break;
      }
    }
    // Imported or edited records may overlap. The displayed total is elapsed sleep.
    sleepIntervals.sort((a, b) => a.$1.compareTo(b.$1));
    var duration = Duration.zero;
    DateTime? coveredUntil;
    for (final interval in sleepIntervals) {
      final start = coveredUntil != null && coveredUntil.isAfter(interval.$1)
          ? coveredUntil
          : interval.$1;
      if (interval.$2.isAfter(start)) duration += interval.$2.difference(start);
      if (coveredUntil == null || interval.$2.isAfter(coveredUntil)) {
        coveredUntil = interval.$2;
      }
    }
    return BabyDaySummary._(
      feedingCount: feedings,
      measuredIntakeMl: intake,
      wetCount: wet,
      dirtyCount: dirty,
      sleepDuration: duration,
      sleepCount: sleepIntervals.length,
      longestSleep: sleepIntervals.fold(Duration.zero, (longest, interval) {
        final elapsed = interval.$2.difference(interval.$1);
        return elapsed > longest ? elapsed : longest;
      }),
      nursingMinutes: nursingMinutes,
      latestFeeding: latestFeeding,
      activeSleep: active,
    );
  }

  final int feedingCount;
  final double? measuredIntakeMl;
  final int wetCount;
  final int dirtyCount;
  final Duration sleepDuration;
  final int sleepCount;
  final Duration longestSleep;
  final int? nursingMinutes;
  final BabyFeedingRecord? latestFeeding;
  final BabySleepRecord? activeSleep;
}

final class BabyRecordPage {
  const BabyRecordPage({
    required this.items,
    required this.total,
    required this.offset,
    required this.limit,
    required this.serverTime,
  });
  final List<BabyRecord> items;
  final int total, offset, limit;
  final DateTime serverTime;
}

abstract interface class BabyRecordRepository {
  Future<List<BabyGrowthRecord>> latestGrowth(String babyId);
  Future<List<BabyRecord>> saveBatch(
    List<DatedBabyRecord> records, {
    required String idempotencyKey,
  });
  Future<BabyRecordPage> list({
    required String babyId,
    required LocalDate startDate,
    required LocalDate endDate,
    required String timezone,
    BabyRecordKind? kind,
    int offset = 0,
    int limit = 100,
  });
  Future<BabyRecord> save(BabyRecord record, {required String idempotencyKey});
  Future<RecordDeletion> delete(
    String id, {
    required String babyId,
    required int expectedVersion,
  });
  Future<BabyRecord> restore(
    String id, {
    required String babyId,
    required int expectedVersion,
  });
}
