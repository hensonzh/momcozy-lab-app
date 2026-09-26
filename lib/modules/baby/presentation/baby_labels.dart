import '../../../domain/baby/baby_age_label.dart';
import '../../../domain/baby/baby_profile.dart';
import '../../../domain/baby/baby_record.dart';
import '../../../domain/shared/local_date.dart';

String babySexLabel(BabySex sex) => switch (sex) {
  BabySex.female => 'Girl',
  BabySex.male => 'Boy',
  BabySex.unspecified => 'Sex not set',
};
String feedingModeLabel(FeedingMode value) => switch (value) {
  FeedingMode.breastfeeding => 'Exclusively nursing',
  FeedingMode.expressedMilk => 'Bottle-fed breast milk',
  FeedingMode.mixed => 'Combination feeding',
  FeedingMode.formula => 'Formula feeding',
  FeedingMode.unknown => 'Not decided yet',
};
String growthMetricLabel(GrowthMetric metric) => switch (metric) {
  GrowthMetric.weight => 'Weight',
  GrowthMetric.length => 'Length',
  GrowthMetric.headCircumference => 'Head circumference',
};
String babyAgeLabel(BabyProfile baby, LocalDate today) {
  if (baby.ageDays(today) == null) return 'Age not set';
  return formatBabyAge(baby.birthDate, today);
}

String babyDuration(Duration duration) {
  final minutes = duration.inMinutes;
  if (minutes == 0 && duration > Duration.zero) return 'Less than 1 min';
  if (minutes < 60) return '$minutes min';
  return '${minutes ~/ 60} hr${minutes % 60 == 0 ? '' : ' ${minutes % 60} min'}';
}

const babyRecordLabels = {
  BabyRecordKind.feeding: 'Feeding',
  BabyRecordKind.dailyStatus: 'Daily check-in',
  BabyRecordKind.sleep: 'Sleep',
  BabyRecordKind.diaper: 'Diapers',
  BabyRecordKind.growth: 'Growth',
  BabyRecordKind.development: 'Development',
};
const babyMentalLabels = {
  BabyMentalState.content: 'Calm and content',
  BabyMentalState.active: 'Alert and active',
  BabyMentalState.crying: 'Fussy or crying',
  BabyMentalState.drowsy: 'Drowsy',
};
const babyFeedingLabels = {
  BabyFeedingMethod.breastfeeding: 'Nursing',
  BabyFeedingMethod.expressedMilk: 'Bottle-fed breast milk',
  BabyFeedingMethod.formula: 'Formula feeding',
};
const feedingSideLabels = {
  FeedingSide.left: 'Left side',
  FeedingSide.right: 'Right side',
  FeedingSide.both: 'Both sides',
};
const diaperKindLabels = {
  DiaperKind.wet: 'Wet',
  DiaperKind.dirty: 'Dirty',
  DiaperKind.both: 'Wet and dirty',
};
const stoolColorLabels = {
  StoolColor.yellow: 'Yellow',
  StoolColor.yellowBrown: 'Yellow-brown',
  StoolColor.green: 'Green',
  StoolColor.brown: 'Brown',
  StoolColor.black: 'Black',
  StoolColor.red: 'Red',
  StoolColor.pale: 'Pale or chalky',
  StoolColor.unsure: 'Not sure',
};
const stoolConsistencyLabels = {
  StoolConsistency.watery: 'Watery',
  StoolConsistency.loose: 'Loose',
  StoolConsistency.pasty: 'Pasty',
  StoolConsistency.formed: 'Formed',
  StoolConsistency.hard: 'Hard',
  StoolConsistency.unsure: 'Not sure',
};
const stoolSignLabels = {
  StoolSign.blood: 'Visible blood',
  StoolSign.mucus: 'Visible mucus',
};
const developmentStatusLabels = {
  DevelopmentStatus.observed: 'Observed',
  DevelopmentStatus.notObserved: 'Not observed yet',
  DevelopmentStatus.unsure: 'Not sure',
};

String babyNumber(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString();

String babyRecordFacts(BabyRecord record) => switch (record) {
  BabyDailyStatusRecord() => [
    if (record.mentalState != null) babyMentalLabels[record.mentalState]!,
    if (record.wetCount != null) 'Wet diapers today: ${record.wetCount}',
    if (record.stoolCount != null) 'Dirty diapers today: ${record.stoolCount}',
  ].join(' · '),
  BabyFeedingRecord(
    :final method,
    :final side,
    :final volumeMl,
    :final durationMinutes,
  ) =>
    [
      babyFeedingLabels[method]!,
      if (side != null) feedingSideLabels[side]!,
      if (volumeMl != null) '${babyNumber(volumeMl)} ml',
      if (durationMinutes != null) '$durationMinutes min',
      if (volumeMl == null && durationMinutes == null)
        method == BabyFeedingMethod.breastfeeding
            ? 'Duration not recorded'
            : 'Amount not recorded',
    ].join(' · '),
  BabyDiaperRecord(
    :final kind,
    :final color,
    :final consistency,
    :final signs,
  ) =>
    [
      diaperKindLabels[kind]!,
      if (color != null) stoolColorLabels[color]!,
      if (consistency != null) stoolConsistencyLabels[consistency]!,
      for (final sign in signs) stoolSignLabels[sign]!,
    ].join(' · '),
  BabySleepRecord(:final occurredAt, :final endedAt) =>
    endedAt == null
        ? 'Sleeping now'
        : babyDuration(endedAt.difference(occurredAt)),
  BabyGrowthRecord(:final metric, :final value, :final unit) =>
    '${growthMetricLabel(metric)} ${babyNumber(value)} $unit',
  BabyDevelopmentRecord(:final label, :final status) =>
    '$label · ${developmentStatusLabels[status]}',
};
