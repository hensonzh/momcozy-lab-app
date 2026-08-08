import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/body_profile/domain/body_profile.dart';

const bodyProfileMeEndpoint = '/v1/body-profile/me';

class BodyProfileApiRepository implements BodyProfileRepository {
  const BodyProfileApiRepository({required this.transport});

  final ApiJsonTransport transport;

  @override
  Future<BodyProfile> fetchProfile() async {
    return _bodyProfile(await transport.getJson(bodyProfileMeEndpoint));
  }

  @override
  Future<BodyProfile> saveProfile(BodyProfile profile) async {
    final mutationTransport = transport;
    if (mutationTransport is! ApiJsonMutationTransport) {
      throw UnsupportedError('Body profile updates require JSON mutations.');
    }
    final body =
        <String, Object?>{
          'urine_leakage': profile.urineLeakage?.apiValue,
          'lower_abdominal_pain': profile.lowerAbdominalPain?.apiValue,
          'pelvic_floor_strength': profile.pelvicFloorStrength,
          'diastasis_severity': profile.diastasisSeverity?.apiValue,
          'daily_impact_description': profile.dailyImpactDescription.trim(),
          'delivery_type': profile.deliveryType?.apiValue,
          'wound_status': profile.woundStatus.trim(),
          'bleeding_status': profile.bleedingStatus.trim(),
          'bowel_status': profile.bowelStatus.trim(),
          'pain_areas': [
            for (final area in profile.painAreas)
              {
                'zone': area.zone.apiValue,
                'intensity': area.intensity,
                'sensation': area.sensation.trim(),
                'pattern': area.pattern.trim(),
              }..removeWhere((_, value) => value == null),
          ],
        }..removeWhere(
          (_, value) =>
              value == null ||
              (value is String && value.isEmpty) ||
              (value is List && value.isEmpty),
        );
    final response = await (mutationTransport as ApiJsonMutationTransport)
        .putJson(bodyProfileMeEndpoint, body: body);
    return _bodyProfile(response);
  }
}

BodyProfile _bodyProfile(Map<String, Object?> data) {
  final painAreas = data['pain_areas'];
  return BodyProfile(
    urineLeakage: RecoveryFrequency.tryParse(data['urine_leakage']),
    lowerAbdominalPain: RecoveryFrequency.tryParse(
      data['lower_abdominal_pain'],
    ),
    pelvicFloorStrength: _int(data['pelvic_floor_strength']),
    diastasisSeverity: DiastasisSeverity.tryParse(data['diastasis_severity']),
    dailyImpactDescription: _string(data['daily_impact_description']) ?? '',
    deliveryType: DeliveryType.tryParse(data['delivery_type']),
    woundStatus: _string(data['wound_status']) ?? '',
    bleedingStatus: _string(data['bleeding_status']) ?? '',
    bowelStatus: _string(data['bowel_status']) ?? '',
    painAreas: painAreas is List
        ? painAreas
              .whereType<Map>()
              .map((area) => _painArea(Map<String, Object?>.from(area)))
              .whereType<BodyPainArea>()
              .toList(growable: false)
        : const [],
    updatedAt: _dateTime(data['updated_at']),
    hasConfirmedData: data['has_confirmed_data'] == true,
    recoveryScore: _int(data['recovery_score']),
  );
}

BodyPainArea? _painArea(Map<String, Object?> data) {
  final zone = PainZone.tryParse(data['zone']);
  if (zone == null) return null;
  return BodyPainArea(
    id: _string(data['id']) ?? '',
    zone: zone,
    intensity: _int(data['intensity']),
    sensation: _string(data['sensation']) ?? '',
    pattern: _string(data['pattern']) ?? '',
  );
}

String? _string(Object? value) => value is String ? value : null;

int? _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '');
}

DateTime? _dateTime(Object? value) {
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
