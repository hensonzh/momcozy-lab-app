import '../../core/network/api_json_transport.dart';
import '../../domain/lactation/lactation_record.dart';
import '../../domain/shared/local_date.dart';
import '../../domain/shared/record_deletion.dart';
import '../shared/json_value.dart';
import '../shared/product_failure_mapper.dart';
import 'lactation_codec.dart';

class LactationApiRepository implements LactationRepository {
  const LactationApiRepository({required this.transport});
  final ApiJsonTransport transport;
  static const endpoint = '/v1/lactation/records';
  ApiJsonMutationTransport get mutations =>
      transport as ApiJsonMutationTransport;

  @override
  Future<List<LactationRecord>> list(DayWindow window) =>
      withProductFailure(() async {
        final response = await transport.getJson(
          endpoint,
          query: {
            'start': window.start.toUtc().toIso8601String(),
            'end': window.end.toUtc().toIso8601String(),
          },
        );
        final items = response['items'];
        if (items is! List) {
          throw const FormatException('Record list is missing.');
        }
        return List.unmodifiable(
          items.map((item) => readLactationRecord(jsonObject(item))),
        );
      });

  @override
  Future<LactationRecord> create(
    LactationObservation observation, {
    required String idempotencyKey,
  }) => withProductFailure(
    () async => readLactationRecord(
      await transport.postJson(
        endpoint,
        body: {'observation': writeLactationObservation(observation)},
        headers: {'Idempotency-Key': idempotencyKey},
      ),
    ),
  );

  @override
  Future<LactationRecord> update(
    String id,
    LactationObservation observation, {
    required int expectedVersion,
  }) => withProductFailure(
    () async => readLactationRecord(
      await mutations.putJson(
        '$endpoint/${Uri.encodeComponent(id)}',
        body: {
          'expected_version': expectedVersion,
          'observation': writeLactationObservation(observation),
        },
      ),
    ),
  );

  @override
  Future<RecordDeletion> delete(String id, {required int expectedVersion}) =>
      withProductFailure(() async {
        final result = await mutations.deleteJson(
          '$endpoint/${Uri.encodeComponent(id)}',
          headers: {'If-Match': '$expectedVersion'},
        );
        return RecordDeletion(
          id: jsonString(result['id']),
          version: jsonInt(result['version']),
        );
      });

  @override
  Future<LactationRecord> restore(String id, {required int expectedVersion}) =>
      withProductFailure(
        () async => readLactationRecord(
          await transport.postJson(
            '$endpoint/${Uri.encodeComponent(id)}/restore',
            body: {'expected_version': expectedVersion},
          ),
        ),
      );
}
