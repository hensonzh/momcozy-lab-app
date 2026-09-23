import '../../../domain/baby/baby_record.dart';
import '../domain/me_experience.dart';

List<MeObservation> meObservationsFromBaby(Iterable<BabyRecord> records) => [
  for (final record in records)
    if (record is BabyGrowthRecord &&
        record.metric == GrowthMetric.weight &&
        record.savedAt != null)
      MeObservation(
        id: record.id,
        kind: MeMetric.weight,
        occurredAt: record.savedAt!.toLocal(),
        value: '${record.value} kg',
      )
    else if (record is BabyDiaperRecord)
      MeObservation(
        id: record.id,
        kind: MeMetric.diaper,
        occurredAt: record.occurredAt.toLocal(),
        value: '1 次',
        fields: {
          'count': 1,
          'wet': record.kind != DiaperKind.dirty ? 1 : 0,
          'stool': record.kind != DiaperKind.wet ? 1 : 0,
        },
      )
    else if (record is BabyFeedingRecord) ...[
      MeObservation(
        id: record.id,
        kind: MeMetric.feed,
        occurredAt: record.occurredAt.toLocal(),
        fields: {'feeding_method': record.method.name},
        value: record.method == BabyFeedingMethod.breastfeeding
            ? '${record.durationMinutes ?? '—'} 分钟'
            : '${record.volumeMl?.toStringAsFixed(0) ?? '—'} ml',
      ),
    ] else if (record is BabyDailyStatusRecord &&
        (record.wetCount != null || record.stoolCount != null))
      MeObservation(
        id: record.id,
        kind: MeMetric.diaper,
        occurredAt: record.savedAt.toLocal(),
        value: '${(record.wetCount ?? 0) + (record.stoolCount ?? 0)} 次',
        fields: {
          'daily_summary': true,
          'wet': record.wetCount,
          'stool': record.stoolCount,
        },
      ),
];
