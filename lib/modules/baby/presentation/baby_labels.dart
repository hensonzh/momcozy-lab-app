import '../../../domain/baby/baby_profile.dart';
import '../../../domain/baby/baby_record.dart';
import '../../../domain/shared/local_date.dart';

String babySexLabel(BabySex sex) => switch (sex) {
  BabySex.female => '女宝宝',
  BabySex.male => '男宝宝',
  BabySex.unspecified => '性别待完善',
};
String feedingModeLabel(FeedingMode value) => switch (value) {
  FeedingMode.breastfeeding => '纯亲喂母乳',
  FeedingMode.expressedMilk => '瓶喂母乳',
  FeedingMode.mixed => '混合喂养',
  FeedingMode.formula => '配方奶',
  FeedingMode.unknown => '暂未确定',
};
String growthMetricLabel(GrowthMetric metric) => switch (metric) {
  GrowthMetric.weight => '体重',
  GrowthMetric.length => '身长',
  GrowthMetric.headCircumference => '头围',
};
String babyAgeLabel(BabyProfile baby, LocalDate today) {
  final birth = baby.birthDate;
  final days = baby.ageDays(today);
  if (birth == null || days == null) return '月龄待完善';
  if (days == 0) return '出生当天';
  var months = (today.year - birth.year) * 12 + today.month - birth.month;
  if (birth.addMonths(months).compareTo(today) > 0) months--;
  if (months >= 24) {
    return '${months ~/ 12} 岁${months % 12 == 0 ? '' : ' ${months % 12} 个月'}';
  }
  if (months >= 3) return '$months 个月';
  if (days < 14) return '$days 天';
  return '${days ~/ 7} 周${days % 7 == 0 ? '' : ' ${days % 7} 天'}';
}

String babyDuration(Duration duration) {
  final minutes = duration.inMinutes;
  if (minutes == 0 && duration > Duration.zero) return '不足 1 分钟';
  if (minutes < 60) return '$minutes 分钟';
  return '${minutes ~/ 60} 小时${minutes % 60 == 0 ? '' : ' ${minutes % 60} 分钟'}';
}

const babyRecordLabels = {
  BabyRecordKind.feeding: '喂养',
  BabyRecordKind.sleep: '睡眠',
  BabyRecordKind.diaper: '尿便',
  BabyRecordKind.growth: '生长',
  BabyRecordKind.development: '发育观察',
};
const babyFeedingLabels = {
  BabyFeedingMethod.breastfeeding: '亲喂',
  BabyFeedingMethod.expressedMilk: '瓶喂母乳',
  BabyFeedingMethod.formula: '配方奶',
};
const feedingSideLabels = {
  FeedingSide.left: '左侧',
  FeedingSide.right: '右侧',
  FeedingSide.both: '两侧',
};
const diaperKindLabels = {
  DiaperKind.wet: '尿湿',
  DiaperKind.dirty: '便便',
  DiaperKind.both: '尿湿和便便',
};
const stoolColorLabels = {
  StoolColor.yellow: '黄色',
  StoolColor.yellowBrown: '黄褐色',
  StoolColor.green: '绿色',
  StoolColor.brown: '棕色',
  StoolColor.black: '黑色',
  StoolColor.red: '红色',
  StoolColor.pale: '灰白 / 很浅',
  StoolColor.unsure: '不确定',
};
const stoolConsistencyLabels = {
  StoolConsistency.watery: '水样',
  StoolConsistency.loose: '稀软',
  StoolConsistency.pasty: '糊状',
  StoolConsistency.formed: '成形',
  StoolConsistency.hard: '干硬',
  StoolConsistency.unsure: '不确定',
};
const stoolSignLabels = {StoolSign.blood: '看到血丝 / 血迹', StoolSign.mucus: '看到黏液'};
const developmentStatusLabels = {
  DevelopmentStatus.observed: '观察到',
  DevelopmentStatus.notObserved: '暂未观察到',
  DevelopmentStatus.unsure: '不确定',
};

String babyNumber(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString();

String babyRecordFacts(BabyRecord record) => switch (record) {
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
      if (durationMinutes != null) '$durationMinutes 分钟',
      if (volumeMl == null && durationMinutes == null)
        method == BabyFeedingMethod.breastfeeding ? '时长未填写' : '奶量未填写',
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
    endedAt == null ? '正在睡' : babyDuration(endedAt.difference(occurredAt)),
  BabyGrowthRecord(:final metric, :final value, :final unit) =>
    '${growthMetricLabel(metric)} ${babyNumber(value)} $unit',
  BabyDevelopmentRecord(:final label, :final status) =>
    '$label · ${developmentStatusLabels[status]}',
};
