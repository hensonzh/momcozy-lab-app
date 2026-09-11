import '../../core/network/api_json_transport.dart';
import '../../domain/baby/baby_record.dart';
import '../../domain/shared/local_date.dart';
import '../../domain/shared/record_deletion.dart';
import '../shared/json_value.dart';
import '../shared/product_failure_mapper.dart';
import 'baby_record_codec.dart';

class BabyRecordsApiRepository implements BabyRecordRepository {
  const BabyRecordsApiRepository({required this.transport});
  final ApiJsonTransport transport;
  ApiJsonMutationTransport get mutations =>
      transport as ApiJsonMutationTransport;
  String _path(String babyId) =>
      '/v1/babies/${Uri.encodeComponent(babyId)}/records';
  BabyRecord _read(Map<String, Object?> json, String babyId, {String? id}) {
    final value = readBabyRecord(json);
    if (value.babyId != babyId || (id != null && value.id != id)) {
      throw const FormatException('Baby record scope mismatch.');
    }
    return value;
  }

  @override
  Future<List<BabyGrowthRecord>> latestGrowth(String babyId) =>
      withProductFailure(() async {
        final json = await transport.getJson('${_path(babyId)}/latest-growth');
        final values = jsonList(json['items'], (value) => _read(value, babyId));
        if (values.any((value) => value is! BabyGrowthRecord)) {
          throw const FormatException('Unexpected growth record category.');
        }
        final growth = values.cast<BabyGrowthRecord>();
        if (growth.map((value) => value.metric).toSet().length !=
                growth.length ||
            growth.length > 3) {
          throw const FormatException('Duplicate latest growth metrics.');
        }
        return growth;
      });

  @override
  Future<List<BabyRecord>> saveBatch(
    List<DatedBabyRecord> records, {
    required String idempotencyKey,
  }) => withProductFailure(() async {
    if (records.isEmpty ||
        records.length > 3 ||
        records.any(
          (value) =>
              value.id.isNotEmpty || value.babyId != records.first.babyId,
        )) {
      throw const FormatException('Invalid baby record batch.');
    }
    final json = await transport.postJson(
      '${_path(records.first.babyId)}/batch',
      body: {'observations': records.map(writeBabyObservation).toList()},
      headers: {'Idempotency-Key': idempotencyKey},
    );
    final values = jsonList(
      json['items'],
      (value) => _read(value, records.first.babyId),
    );
    if (values.length != records.length ||
        values.map((value) => value.id).toSet().length != values.length) {
      throw const FormatException('Incomplete baby record batch.');
    }
    return values;
  });

  @override
  Future<BabyRecordPage> list({
    required String babyId,
    required LocalDate startDate,
    required LocalDate endDate,
    required String timezone,
    BabyRecordKind? kind,
    int offset = 0,
    int limit = 100,
  }) => withProductFailure(() async {
    final json = await transport.getJson(
      _path(babyId),
      query: {
        'start_date': startDate.toString(),
        'end_date': endDate.toString(),
        'timezone': timezone,
        if (kind != null) 'kind': babyRecordKindWire.write(kind),
        'offset': offset,
        'limit': limit,
      },
    );
    final items = jsonList(json['items'], (value) => _read(value, babyId));
    final total = jsonInt(json['total']);
    if (jsonInt(json['offset']) != offset ||
        jsonInt(json['limit']) != limit ||
        total < 0 ||
        items.isNotEmpty && total < offset + items.length ||
        items.length > limit ||
        items.map((value) => value.id).toSet().length != items.length ||
        kind != null && items.any((value) => value.recordKind != kind)) {
      throw const FormatException('Invalid baby record page.');
    }
    return BabyRecordPage(
      items: items,
      total: total,
      offset: offset,
      limit: limit,
      serverTime: jsonInstant(json['server_time']),
    );
  });

  @override
  Future<BabyRecord> save(
    BabyRecord record, {
    required String idempotencyKey,
  }) => withProductFailure(() async {
    final data = writeBabyObservation(record);
    final json = record.id.isEmpty
        ? await transport.postJson(
            _path(record.babyId),
            body: {'observation': data},
            headers: {'Idempotency-Key': idempotencyKey},
          )
        : await mutations.putJson(
            '${_path(record.babyId)}/${Uri.encodeComponent(record.id)}',
            body: {'expected_version': record.version, 'observation': data},
          );
    return _read(json, record.babyId, id: record.id.isEmpty ? null : record.id);
  });

  @override
  Future<RecordDeletion> delete(
    String id, {
    required String babyId,
    required int expectedVersion,
  }) => withProductFailure(() async {
    final json = await mutations.deleteJson(
      '${_path(babyId)}/${Uri.encodeComponent(id)}',
      headers: {'If-Match': '$expectedVersion'},
    );
    if (jsonString(json['id']) != id) {
      throw const FormatException('Deleted record scope mismatch.');
    }
    final version = jsonInt(json['version']);
    if (version < expectedVersion) {
      throw const FormatException('Invalid deletion version.');
    }
    return RecordDeletion(id: id, version: version);
  });

  @override
  Future<BabyRecord> restore(
    String id, {
    required String babyId,
    required int expectedVersion,
  }) => withProductFailure(
    () async => _read(
      await transport.postJson(
        '${_path(babyId)}/${Uri.encodeComponent(id)}/restore',
        body: {'expected_version': expectedVersion},
      ),
      babyId,
      id: id,
    ),
  );
}
