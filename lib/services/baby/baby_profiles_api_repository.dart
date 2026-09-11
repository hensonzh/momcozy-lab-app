import '../../core/network/api_json_transport.dart';
import '../../domain/baby/baby_profile.dart';
import '../shared/json_value.dart';
import '../shared/product_failure_mapper.dart';
import 'baby_profile_codec.dart';

class BabyProfilesApiRepository implements BabyProfileRepository {
  const BabyProfilesApiRepository({required this.transport});
  final ApiJsonTransport transport;

  @override
  Future<List<BabyProfile>> list() => withProductFailure(() async {
    final json = await transport.getJson('/v1/babies');
    final items = jsonList(json['items'], readBabyProfile);
    if (items.map((value) => value.id).toSet().length != items.length) {
      throw const FormatException('Duplicate baby profiles.');
    }
    return items;
  });

  @override
  Future<BabyProfile> save(
    BabyProfile profile, {
    required String timezone,
    required String idempotencyKey,
  }) => withProductFailure(() async {
    if (profile.id.isNotEmpty &&
        (profile.version == null || profile.version! < 1)) {
      throw const FormatException('Reload the current profile before editing.');
    }
    final body = {...writeBabyProfile(profile), 'timezone': timezone};
    final json = profile.id.isEmpty
        ? await transport.postJson(
            '/v1/babies',
            body: body,
            headers: {'Idempotency-Key': idempotencyKey},
          )
        : await (transport as ApiJsonMutationTransport).putJson(
            '/v1/babies/${Uri.encodeComponent(profile.id)}',
            body: {...body, 'expected_version': profile.version},
          );
    final value = readBabyProfile(json);
    if (profile.id.isNotEmpty && value.id != profile.id) {
      throw const FormatException('Baby profile scope mismatch.');
    }
    return value;
  });
}
