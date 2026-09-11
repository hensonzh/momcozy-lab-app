import '../../core/network/api_json_transport.dart';
import '../../domain/mother/mother_profile.dart';
import '../../domain/shared/local_date.dart';
import '../shared/json_value.dart';
import '../shared/product_failure_mapper.dart';

class MotherProfileApiRepository implements MotherProfileRepository {
  const MotherProfileApiRepository({
    required this.transport,
    required this.ownerUserId,
    required this.timezoneProvider,
  });
  final ApiJsonTransport transport;
  final String ownerUserId;
  final Future<String> Function() timezoneProvider;
  @override
  Future<MotherProfile> get() => withProductFailure(() async {
    final values = await Future.wait([
      transport.getJson('/v1/profile/me'),
      transport.getJson('/v1/profile/lactation'),
    ]);
    final profile = values[0], maternal = values[1];
    final birth = maternal['actual_delivery_date'];
    return MotherProfile(
      userId: ownerUserId,
      displayName: profile['preferred_name'] == null
          ? ''
          : jsonString(profile['preferred_name']),
      timezone: await timezoneProvider(),
      deliveryDate: birth == null ? null : LocalDate.parse(jsonString(birth)),
      deliveryMethod: _deliveryMethod.read(maternal['current_delivery_method']),
    );
  });
}

const _deliveryMethod = EnumWire<DeliveryMethod>({
  DeliveryMethod.vaginal: 'vaginal',
  DeliveryMethod.cesarean: 'cesarean',
  DeliveryMethod.assistedVaginal: 'assisted_vaginal',
  DeliveryMethod.other: 'other',
  DeliveryMethod.unknown: 'unknown',
});
