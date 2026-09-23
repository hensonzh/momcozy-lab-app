import 'package:timezone/timezone.dart' as tz;
import '../../../domain/baby/baby_record.dart';
import '../../../domain/shared/local_date.dart';
import '../../../shared/zoned_time.dart';
import 'baby_knowledge_content.dart';

BabyKnowledgeTopic selectBabyKnowledge({
  required DateTime now,
  required String timezone,
  required String babyId,
  required Iterable<BabyRecord> records,
}) {
  final local = inTimezone(now, timezone);
  var release = tz.TZDateTime(
    local.location,
    local.year,
    local.month,
    local.day,
    8,
  );
  if (release.isAfter(now)) {
    release = tz.TZDateTime(
      local.location,
      local.year,
      local.month,
      local.day - 1,
      8,
    );
  }
  final start = release.subtract(const Duration(hours: 24));
  final previousDay = LocalDate.fromDateTime(release).addDays(-1);
  final timed =
      records
          .whereType<TimedBabyRecord>()
          .where(
            (value) =>
                value.babyId == babyId &&
                value.occurredAt.isAfter(start) &&
                !value.occurredAt.isAfter(release),
          )
          .toList()
        ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
  if (timed.isNotEmpty) {
    return switch (timed.first) {
      BabyFeedingRecord() => BabyKnowledgeTopic.feeding,
      BabySleepRecord() => BabyKnowledgeTopic.feedingCues,
      BabyDiaperRecord() => BabyKnowledgeTopic.diaper,
    };
  }
  // Calendar observations have no time of day. Use completed dates, without inventing an instant.
  final dated =
      records
          .whereType<DatedBabyRecord>()
          .where(
            (value) =>
                value.babyId == babyId && value.recordedOn == previousDay,
          )
          .toList()
        ..sort((a, b) => a.recordKind.index.compareTo(b.recordKind.index));
  if (dated.isNotEmpty) {
    return switch (dated.first) {
      BabyGrowthRecord() => BabyKnowledgeTopic.growth,
      BabyDailyStatusRecord(:final wetCount, :final stoolCount) =>
        wetCount != null || stoolCount != null
            ? BabyKnowledgeTopic.diaper
            : BabyKnowledgeTopic.feedingCues,
      _ => BabyKnowledgeTopic.feedingCues,
    };
  }
  const fallback = [
    BabyKnowledgeTopic.feedingCues,
    BabyKnowledgeTopic.feeding,
    BabyKnowledgeTopic.diaper,
  ];
  final seed = '$babyId-${LocalDate.fromDateTime(release)}'.runes.fold<int>(
    0,
    (value, char) => value + char,
  );
  return fallback[seed % fallback.length];
}
