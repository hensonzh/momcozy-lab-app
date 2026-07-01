import 'package:momcozy_flutter_app/core/network/api_envelope.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/records/domain/records.dart';

const feedingRecordsEndpoint = '/v1/feeding/record/query';
const growthRecordsEndpoint = '/v1/growth/history';

class RecordsApiRepository
    implements FeedingRecordsRepository, GrowthRecordsRepository {
  const RecordsApiRepository({required this.transport});

  final ApiJsonTransport transport;

  @override
  Future<List<FeedingRecord>> fetchFeedingRecords({
    required String userId,
    required DateTime date,
  }) async {
    final response = await transport.getJson(
      feedingRecordsEndpoint,
      query: {'user_id': userId, 'date': _apiDate(date)},
    );
    final data = _mapOrEmpty(unwrapApiEnvelope(response));
    final records = data['records'] ?? data['list'];
    return records is List
        ? records
              .whereType<Map>()
              .map(
                (record) => _feedingRecord(Map<String, Object?>.from(record)),
              )
              .toList(growable: false)
        : const <FeedingRecord>[];
  }

  @override
  Future<List<GrowthRecord>> fetchGrowthRecords({
    required String userId,
    required String babyId,
  }) async {
    final response = await transport.getJson(
      growthRecordsEndpoint,
      query: {'user_id': userId, 'baby_id': babyId},
    );
    final data = _mapOrEmpty(unwrapApiEnvelope(response));
    final records = data['records'] ?? data['growthList'];
    return records is List
        ? records
              .whereType<Map>()
              .map((record) => _growthRecord(Map<String, Object?>.from(record)))
              .toList(growable: false)
        : const <GrowthRecord>[];
  }
}

FeedingRecord _feedingRecord(Map<String, Object?> data) {
  return FeedingRecord(
    id: _string(data['id'] ?? data['recordId']) ?? '',
    type: _string(data['type'] ?? data['feedingType']) ?? '',
    amountMl: _int(data['amount_ml'] ?? data['amountMl']),
    occurredAt: _dateTime(data['occurred_at'] ?? data['occurredAt']),
  );
}

GrowthRecord _growthRecord(Map<String, Object?> data) {
  return GrowthRecord(
    id: _string(data['id'] ?? data['recordId']) ?? '',
    weightGram: _int(data['weight_g'] ?? data['weightGram']),
    heightCm: _double(data['height_cm'] ?? data['heightCm']),
    measuredAt: _dateTime(data['measured_at'] ?? data['measuredAt']),
  );
}

Map<String, Object?> _mapOrEmpty(Object? value) {
  return value is Map ? Map<String, Object?>.from(value) : const {};
}

String _apiDate(DateTime date) {
  final utc = date.toUtc();
  final month = utc.month.toString().padLeft(2, '0');
  final day = utc.day.toString().padLeft(2, '0');
  return '${utc.year}-$month-$day';
}

String? _string(Object? value) => value is String ? value : null;

int? _int(Object? value) => value is int ? value : null;

double? _double(Object? value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  return null;
}

DateTime? _dateTime(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}
