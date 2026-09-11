import '../../domain/baby/baby_record.dart';
import '../../domain/shared/local_date.dart';
import '../shared/json_value.dart';

const babyRecordKindWire = EnumWire({
  BabyRecordKind.feeding: 'feeding',
  BabyRecordKind.sleep: 'sleep',
  BabyRecordKind.diaper: 'diaper',
  BabyRecordKind.growth: 'growth',
  BabyRecordKind.development: 'development',
});
const babyFeedingMethodWire = EnumWire({
  BabyFeedingMethod.breastfeeding: 'breastfeeding',
  BabyFeedingMethod.expressedMilk: 'expressed_milk',
  BabyFeedingMethod.formula: 'formula',
});
const feedingSideWire = EnumWire({
  FeedingSide.left: 'left',
  FeedingSide.right: 'right',
  FeedingSide.both: 'both',
});
const diaperKindWire = EnumWire({
  DiaperKind.wet: 'wet',
  DiaperKind.dirty: 'dirty',
  DiaperKind.both: 'both',
});
const stoolColorWire = EnumWire({
  StoolColor.yellow: 'yellow',
  StoolColor.yellowBrown: 'yellow_brown',
  StoolColor.green: 'green',
  StoolColor.brown: 'brown',
  StoolColor.black: 'black',
  StoolColor.red: 'red',
  StoolColor.pale: 'pale',
  StoolColor.unsure: 'unsure',
});
const stoolConsistencyWire = EnumWire({
  StoolConsistency.watery: 'watery',
  StoolConsistency.loose: 'loose',
  StoolConsistency.pasty: 'pasty',
  StoolConsistency.formed: 'formed',
  StoolConsistency.hard: 'hard',
  StoolConsistency.unsure: 'unsure',
});
const stoolSignWire = EnumWire({
  StoolSign.blood: 'blood',
  StoolSign.mucus: 'mucus',
});
const growthMetricWire = EnumWire({
  GrowthMetric.weight: 'weight',
  GrowthMetric.length: 'length',
  GrowthMetric.headCircumference: 'head_circumference',
});
const developmentStatusWire = EnumWire({
  DevelopmentStatus.observed: 'observed',
  DevelopmentStatus.notObserved: 'not_observed',
  DevelopmentStatus.unsure: 'unsure',
});

T _required<T extends Enum>(EnumWire<T> wire, Object? value) =>
    wire.read(value) ??
    (throw const FormatException('Record field is missing.'));

BabyRecord readBabyRecord(Map<String, Object?> json) {
  final data = jsonObject(json['observation']);
  final kind = _required(babyRecordKindWire, data['kind']);
  final id = jsonString(json['id']), babyId = jsonString(json['baby_id']);
  final version = jsonInt(json['version']);
  if (id.isEmpty ||
      babyId.isEmpty ||
      version < 1 ||
      json['deleted_at'] != null) {
    throw const FormatException('Expected a current baby record.');
  }
  final allowed = switch (kind) {
    BabyRecordKind.feeding => {
      'method',
      'side',
      'volume_ml',
      'duration_minutes',
    },
    BabyRecordKind.sleep => {'ended_at'},
    BabyRecordKind.diaper => {'diaper_kind', 'color', 'consistency', 'signs'},
    BabyRecordKind.growth => {'metric', 'value', 'unit'},
    BabyRecordKind.development => {'item_id', 'status', 'label'},
  };
  final dated =
      kind == BabyRecordKind.growth || kind == BabyRecordKind.development;
  requireOnlyKeys(data, {
    'kind',
    ...allowed,
    if (dated) ...{'recorded_on', 'timezone'} else ...{'occurred_at', 'note'},
  });
  final record = switch (kind) {
    BabyRecordKind.feeding => BabyFeedingRecord(
      id: id,
      babyId: babyId,
      version: version,
      occurredAt: jsonInstant(data['occurred_at']),
      method: _required(babyFeedingMethodWire, data['method']),
      side: feedingSideWire.read(data['side']),
      volumeMl: data['volume_ml'] == null
          ? null
          : jsonDouble(data['volume_ml']),
      durationMinutes: data['duration_minutes'] == null
          ? null
          : jsonInt(data['duration_minutes']),
      note: jsonString(data['note']),
    ),
    BabyRecordKind.sleep => BabySleepRecord(
      id: id,
      babyId: babyId,
      version: version,
      occurredAt: jsonInstant(data['occurred_at']),
      endedAt: data['ended_at'] == null ? null : jsonInstant(data['ended_at']),
      note: jsonString(data['note']),
    ),
    BabyRecordKind.diaper => BabyDiaperRecord(
      id: id,
      babyId: babyId,
      version: version,
      occurredAt: jsonInstant(data['occurred_at']),
      kind: _required(diaperKindWire, data['diaper_kind']),
      color: stoolColorWire.read(data['color']),
      consistency: stoolConsistencyWire.read(data['consistency']),
      signs: stoolSignWire.readSet(data['signs']),
      note: jsonString(data['note']),
    ),
    BabyRecordKind.growth => BabyGrowthRecord(
      id: id,
      babyId: babyId,
      version: version,
      recordedOn: LocalDate.parse(jsonString(data['recorded_on'])),
      timezone: jsonString(data['timezone']),
      metric: _required(growthMetricWire, data['metric']),
      value: jsonDouble(data['value']),
    ),
    BabyRecordKind.development => BabyDevelopmentRecord(
      id: id,
      babyId: babyId,
      version: version,
      recordedOn: LocalDate.parse(jsonString(data['recorded_on'])),
      timezone: jsonString(data['timezone']),
      itemId: jsonString(data['item_id']),
      status: _required(developmentStatusWire, data['status']),
    ),
  };
  // Validate shape/ranges without treating a skewed device clock as a server error.
  if (record.validate(DateTime.utc(9999, 12, 31)).isNotEmpty ||
      (record is BabyGrowthRecord && data['unit'] != record.unit) ||
      (record is BabyDevelopmentRecord && data['label'] != record.label)) {
    throw const FormatException('Invalid baby observation.');
  }
  return record;
}

Map<String, Object?> writeBabyObservation(BabyRecord record) => {
  'kind': babyRecordKindWire.write(record.recordKind),
  if (record is TimedBabyRecord) ...{
    'occurred_at': record.occurredAt.toUtc().toIso8601String(),
    'note': record.note.trim(),
  },
  if (record is DatedBabyRecord) ...{
    'recorded_on': record.recordedOn.toString(),
    'timezone': record.timezone,
  },
  ...switch (record) {
    BabyFeedingRecord() => {
      'method': babyFeedingMethodWire.write(record.method),
      'side': feedingSideWire.write(record.side),
      'volume_ml': record.volumeMl,
      'duration_minutes': record.durationMinutes,
    },
    BabySleepRecord() => {
      'ended_at': record.endedAt?.toUtc().toIso8601String(),
    },
    BabyDiaperRecord() => {
      'diaper_kind': diaperKindWire.write(record.kind),
      'color': stoolColorWire.write(record.color),
      'consistency': stoolConsistencyWire.write(record.consistency),
      'signs': stoolSignWire.writeSet(record.signs),
    },
    BabyGrowthRecord() => {
      'metric': growthMetricWire.write(record.metric),
      'value': record.value,
    },
    BabyDevelopmentRecord() => {
      'item_id': record.itemId,
      'status': developmentStatusWire.write(record.status),
    },
  },
};
