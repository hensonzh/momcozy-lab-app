import '../../domain/baby/baby_profile.dart';
import '../../domain/shared/local_date.dart';
import '../shared/json_value.dart';

const babySexWire = EnumWire<BabySex>({
  BabySex.female: 'female',
  BabySex.male: 'male',
  BabySex.unspecified: 'unspecified',
});
const feedingModeWire = EnumWire<FeedingMode>({
  FeedingMode.breastfeeding: 'exclusive_breastfeeding',
  FeedingMode.expressedMilk: 'expressed_milk_feeding',
  FeedingMode.mixed: 'mixed_feeding',
  FeedingMode.formula: 'formula_feeding',
  FeedingMode.unknown: 'unknown',
});

BabyProfile readBabyProfile(Map<String, Object?> json) {
  requireOnlyKeys(json, {
    'id',
    'name',
    'birth_date',
    'sex',
    'feeding_mode',
    'version',
    'created_at',
    'updated_at',
  });
  final id = jsonString(json['id']);
  final name = jsonString(json['name']);
  final version = jsonInt(json['version']);
  if (id.isEmpty || name.trim().isEmpty || version < 1) {
    throw const FormatException('Invalid baby profile.');
  }
  jsonInstant(json['created_at']);
  jsonInstant(json['updated_at']);
  return BabyProfile(
    id: id,
    name: name,
    version: version,
    birthDate: json['birth_date'] == null
        ? null
        : LocalDate.parse(jsonString(json['birth_date'])),
    sex:
        babySexWire.read(json['sex']) ??
        (throw const FormatException('Missing baby sex.')),
    feedingMode:
        feedingModeWire.read(json['feeding_mode']) ??
        (throw const FormatException('Missing feeding mode.')),
  );
}

Map<String, Object?> writeBabyProfile(BabyProfile value) => {
  'name': value.name.trim(),
  'birth_date': value.birthDate?.toString(),
  'sex': babySexWire.write(value.sex),
  'feeding_mode': feedingModeWire.write(value.feedingMode),
};
