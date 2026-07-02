import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/records/domain/records.dart';

const feedingRecordsEndpoint = '/v1/records/feeding';
const pumpMilkRecordsEndpoint = '/v1/records/pumping';
const growthRecordsEndpoint = '/v1/records/growth';

class RecordsApiRepository
    implements
        FeedingRecordsRepository,
        PumpMilkRecordsRepository,
        GrowthRecordsRepository {
  const RecordsApiRepository({required this.transport});

  final ApiJsonTransport transport;

  @override
  Future<List<FeedingRecord>> fetchFeedingRecords({
    required String userId,
    required DateTime date,
  }) async {
    final range = _dayRange(date);
    final response = await transport.getJson(
      feedingRecordsEndpoint,
      query: {
        'start_at': range.start.toIso8601String(),
        'end_at': range.end.toIso8601String(),
        'limit': 50,
      },
    );
    final records = response['items'];
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
  Future<List<PumpMilkRecord>> fetchPumpMilkRecords({
    required String userId,
    required DateTime date,
  }) async {
    final range = _dayRange(date);
    final response = await transport.getJson(
      pumpMilkRecordsEndpoint,
      query: {
        'start_at': range.start.toIso8601String(),
        'end_at': range.end.toIso8601String(),
        'limit': 50,
      },
    );
    final records = response['items'];
    return records is List
        ? records
              .whereType<Map>()
              .map(
                (record) => _pumpMilkRecord(Map<String, Object?>.from(record)),
              )
              .toList(growable: false)
        : const <PumpMilkRecord>[];
  }

  @override
  Future<List<GrowthRecord>> fetchGrowthRecords({
    required String userId,
    required String babyId,
  }) async {
    final response = await transport.getJson(
      growthRecordsEndpoint,
      query: {
        if (babyId.trim().isNotEmpty) 'infant_id': babyId.trim(),
        'limit': 50,
      },
    );
    final records = response['items'];
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
    type:
        _string(data['feed_type'] ?? data['type'] ?? data['feedingType']) ??
        '',
    amountMl: _int(data['volume_ml'] ?? data['amount_ml'] ?? data['amountMl']),
    occurredAt: _dateTime(
      data['feed_time'] ?? data['occurred_at'] ?? data['occurredAt'],
    ),
  );
}

PumpMilkRecord _pumpMilkRecord(Map<String, Object?> data) {
  return PumpMilkRecord(
    id: _id(data['pump_id'] ?? data['pumpId'] ?? data['id']),
    title:
        _string(data['pump_title'] ?? data['pumpTitle'] ?? data['title']) ?? '',
    pumpType: _int(data['pump_type'] ?? data['pumpType']),
    pumpSource: _int(data['pump_source'] ?? data['pumpSource']),
    amountMl: _int(
      data['milk_volume_ml'] ??
          data['pump_milk_volum'] ??
          data['pumpMilkVolum'] ??
          data['amount_ml'] ??
          data['amountMl'],
    ),
    occurredAt: _dateTime(
      data['pump_start_time'] ??
          data['pump_time'] ??
          data['pumpTime'] ??
          data['occurred_at'] ??
          data['occurredAt'],
    ),
  );
}

GrowthRecord _growthRecord(Map<String, Object?> data) {
  return GrowthRecord(
    id: _string(data['id'] ?? data['recordId']) ?? '',
    weightGram:
        _int(data['weight_g'] ?? data['weightGram']) ??
        _kgToGram(data['weight_kg']),
    heightCm: _double(data['height_cm'] ?? data['heightCm']),
    measuredAt: _dateTime(data['measured_at'] ?? data['measuredAt']),
  );
}

({DateTime start, DateTime end}) _dayRange(DateTime date) {
  final utc = date.toUtc();
  final start = DateTime.utc(utc.year, utc.month, utc.day);
  return (start: start, end: start.add(const Duration(days: 1)));
}

String _id(Object? value) {
  if (value is int) return value.toString();
  return value is String ? value : '';
}

String? _string(Object? value) => value is String ? value : null;

int? _int(Object? value) {
  if (value is int) return value;
  if (value is double) return value.round();
  return null;
}

int? _kgToGram(Object? value) {
  if (value is int) return value * 1000;
  if (value is double) return (value * 1000).round();
  return null;
}

double? _double(Object? value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  return null;
}

DateTime? _dateTime(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}
