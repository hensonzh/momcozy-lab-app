import '../../domain/lactation/lactation_record.dart';
import '../shared/json_value.dart';

const breastSideWire = EnumWire<BreastSide>({
  BreastSide.left: 'left',
  BreastSide.right: 'right',
});
const breastComfortWire = EnumWire<BreastComfort>({
  BreastComfort.comfortable: 'comfortable',
  BreastComfort.full: 'full',
  BreastComfort.painful: 'painful',
  BreastComfort.uncertain: 'uncertain',
});

Map<String, Object?> writeLactationObservation(LactationObservation value) => {
  'occurred_at': value.occurredAt.toUtc().toIso8601String(),
  'side': breastSideWire.write(value.side),
  'feeling': breastComfortWire.write(value.feeling),
  'note': value.note.trim(),
  ...switch (value) {
    PumpObservation(:final volumeMl) => {
      'method': 'pump',
      'volume_ml': volumeMl,
    },
    NursingObservation(:final durationMinutes) => {
      'method': 'nurse',
      'duration_minutes': durationMinutes,
    },
  },
};

LactationRecord readLactationRecord(Map<String, Object?> json) {
  final data = jsonObject(json['observation']);
  final method = jsonString(data['method']);
  requireOnlyKeys(data, {
    'method',
    'occurred_at',
    'side',
    'feeling',
    'note',
    if (method == 'pump') 'volume_ml' else 'duration_minutes',
  });
  final occurredAt = DateTime.parse(jsonString(data['occurred_at']));
  if (!occurredAt.isUtc) {
    throw const FormatException('Record time requires a timezone.');
  }
  final side =
      breastSideWire.read(data['side']) ??
      (throw const FormatException('Record side is missing.'));
  final feeling = breastComfortWire.read(data['feeling']);
  final note = jsonString(data['note'] ?? '');
  final observation = switch (method) {
    'pump' => PumpObservation(
      occurredAt: occurredAt,
      side: side,
      feeling: feeling,
      note: note,
      volumeMl: data['volume_ml'] == null
          ? null
          : jsonDouble(data['volume_ml']),
    ),
    'nurse' => NursingObservation(
      occurredAt: occurredAt,
      side: side,
      feeling: feeling,
      note: note,
      durationMinutes: data['duration_minutes'] == null
          ? null
          : jsonInt(data['duration_minutes']),
    ),
    _ => throw const FormatException('Unknown lactation method.'),
  };
  return LactationRecord(
    id: jsonString(json['id']),
    ownerUserId: jsonString(json['owner_user_id']),
    version: jsonInt(json['version']),
    observation: observation,
  );
}
