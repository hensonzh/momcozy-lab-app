import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/records/domain/records.dart';

const feedingRecordsEndpoint = '/v1/records/feeding';
const pumpMilkRecordsEndpoint = '/v1/records/pumping';
const milkTrendsEndpoint = '/v1/records/milk-trends';
const growthRecordsEndpoint = '/v1/records/growth';
const sleepRecordsEndpoint = '/v1/records/sleep';
const diaperRecordsEndpoint = '/v1/records/diaper';

class RecordsApiRepository
    implements
        FeedingRecordsRepository,
        BabyCareRecordsRepository,
        PumpMilkRecordsRepository,
        MilkTrendRepository,
        GrowthRecordsRepository {
  const RecordsApiRepository({required this.transport});

  final ApiJsonTransport transport;

  @override
  Future<List<FeedingRecord>> fetchFeedingRecords({
    required DateTime date,
    required String babyId,
  }) {
    final range = _dayRange(date);
    return _fetchFeedingRecordsRange(
      start: range.start,
      end: range.end,
      babyId: babyId,
      limit: 50,
    );
  }

  @override
  Future<List<FeedingRecord>> fetchFeedingRecordsRange({
    required DateTime start,
    required DateTime end,
    required String babyId,
  }) {
    return _fetchFeedingRecordsRange(
      start: start,
      end: end,
      babyId: babyId,
      limit: 100,
    );
  }

  Future<List<FeedingRecord>> _fetchFeedingRecordsRange({
    required DateTime start,
    required DateTime end,
    required String babyId,
    required int limit,
  }) async {
    final response = await transport.getJson(
      feedingRecordsEndpoint,
      query: {
        'start_at': start.toUtc().toIso8601String(),
        'end_at': end.toUtc().toIso8601String(),
        if (babyId.trim().isNotEmpty) 'infant_id': babyId.trim(),
        'limit': limit,
      },
    );
    final records = response['items'];
    final selectedBabyId = babyId.trim();
    return records is List
        ? records
              .whereType<Map>()
              .map(
                (record) => _feedingRecord(Map<String, Object?>.from(record)),
              )
              .where(
                (record) =>
                    selectedBabyId.isEmpty || record.infantId == selectedBabyId,
              )
              .toList(growable: false)
        : const <FeedingRecord>[];
  }

  @override
  Future<FeedingRecord> createFeedingRecord({
    required String babyId,
    required DateTime occurredAt,
    required String type,
    double? amountMl,
    int? durationSeconds,
    String? idempotencyKey,
  }) async {
    final body = <String, Object?>{
      if (babyId.trim().isNotEmpty) 'infant_id': babyId.trim(),
      'feed_time': occurredAt.toUtc().toIso8601String(),
      'feed_type': type.trim(),
      'volume_ml': amountMl,
      'duration_seconds': durationSeconds,
    }..removeWhere((_, value) => value == null);
    final response = await transport.postJson(
      feedingRecordsEndpoint,
      body: body,
      headers: {
        if (idempotencyKey?.trim().isNotEmpty == true)
          'Idempotency-Key': idempotencyKey!.trim(),
      },
    );
    return _feedingRecord(response);
  }

  @override
  Future<List<SleepRecord>> fetchSleepRecordsRange({
    required DateTime start,
    required DateTime end,
    required String babyId,
  }) async {
    final selectedBabyId = _requiredBabyId(babyId);
    final response = await transport.getJson(
      sleepRecordsEndpoint,
      query: {
        'start_at': start.toUtc().toIso8601String(),
        'end_at': end.toUtc().toIso8601String(),
        'infant_id': selectedBabyId,
        'limit': 100,
      },
    );
    final records = response['items'];
    return records is List
        ? records
              .whereType<Map>()
              .map((record) => _sleepRecord(Map<String, Object?>.from(record)))
              .where((record) => record.infantId == selectedBabyId)
              .toList(growable: false)
        : const <SleepRecord>[];
  }

  @override
  Future<SleepRecord> createSleepRecord({
    required String babyId,
    required DateTime startedAt,
    required DateTime endedAt,
    required String type,
    String notes = '',
    String? idempotencyKey,
  }) async {
    final body = <String, Object?>{
      'infant_id': _requiredBabyId(babyId),
      'started_at': startedAt.toUtc().toIso8601String(),
      'ended_at': endedAt.toUtc().toIso8601String(),
      'sleep_type': type.trim(),
      if (notes.trim().isNotEmpty) 'notes': notes.trim(),
    };
    final response = await transport.postJson(
      sleepRecordsEndpoint,
      body: body,
      headers: {
        if (idempotencyKey?.trim().isNotEmpty == true)
          'Idempotency-Key': idempotencyKey!.trim(),
      },
    );
    return _sleepRecord(response);
  }

  @override
  Future<List<DiaperRecord>> fetchDiaperRecordsRange({
    required DateTime start,
    required DateTime end,
    required String babyId,
  }) async {
    final selectedBabyId = _requiredBabyId(babyId);
    final response = await transport.getJson(
      diaperRecordsEndpoint,
      query: {
        'start_at': start.toUtc().toIso8601String(),
        'end_at': end.toUtc().toIso8601String(),
        'infant_id': selectedBabyId,
        'limit': 100,
      },
    );
    final records = response['items'];
    return records is List
        ? records
              .whereType<Map>()
              .map((record) => _diaperRecord(Map<String, Object?>.from(record)))
              .where((record) => record.infantId == selectedBabyId)
              .toList(growable: false)
        : const <DiaperRecord>[];
  }

  @override
  Future<DiaperRecord> createDiaperRecord({
    required String babyId,
    required DateTime changedAt,
    required String type,
    String notes = '',
    String? idempotencyKey,
  }) async {
    final body = <String, Object?>{
      'infant_id': _requiredBabyId(babyId),
      'changed_at': changedAt.toUtc().toIso8601String(),
      'diaper_type': type.trim(),
      if (notes.trim().isNotEmpty) 'notes': notes.trim(),
    };
    final response = await transport.postJson(
      diaperRecordsEndpoint,
      body: body,
      headers: {
        if (idempotencyKey?.trim().isNotEmpty == true)
          'Idempotency-Key': idempotencyKey!.trim(),
      },
    );
    return _diaperRecord(response);
  }

  @override
  Future<List<PumpMilkRecord>> fetchPumpMilkRecords({required DateTime date}) {
    final range = _dayRange(date);
    return _fetchPumpMilkRecordsRange(
      start: range.start,
      end: range.end,
      limit: 50,
    );
  }

  @override
  Future<List<PumpMilkRecord>> fetchPumpMilkRecordsRange({
    required DateTime start,
    required DateTime end,
  }) {
    return _fetchPumpMilkRecordsRange(start: start, end: end, limit: 100);
  }

  @override
  Future<PumpMilkRecord> createPumpMilkRecord({
    required DateTime occurredAt,
    double? amountMl,
    int? durationSeconds,
    String? idempotencyKey,
  }) async {
    final body = <String, Object?>{
      'pump_start_time': occurredAt.toUtc().toIso8601String(),
      'milk_volume_ml': amountMl,
      'duration_seconds': durationSeconds,
      'pump_type': 'manual',
      'source': 'manual',
    }..removeWhere((_, value) => value == null);
    final response = await transport.postJson(
      pumpMilkRecordsEndpoint,
      body: body,
      headers: {
        if (idempotencyKey?.trim().isNotEmpty == true)
          'Idempotency-Key': idempotencyKey!.trim(),
      },
    );
    return _pumpMilkRecord(response);
  }

  Future<List<PumpMilkRecord>> _fetchPumpMilkRecordsRange({
    required DateTime start,
    required DateTime end,
    required int limit,
  }) async {
    final response = await transport.getJson(
      pumpMilkRecordsEndpoint,
      query: {
        'start_at': start.toUtc().toIso8601String(),
        'end_at': end.toUtc().toIso8601String(),
        'limit': limit,
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
  Future<List<MilkTrendDay>> fetchMilkTrends({
    required DateTime startDate,
    required int days,
    bool includeToday = true,
  }) async {
    final response = await transport.getJson(
      milkTrendsEndpoint,
      query: {
        'start_date': _dateKey(startDate),
        'days': days,
        'include_today': includeToday,
      },
    );
    final records = response['items'];
    if (records is! List) return const <MilkTrendDay>[];
    return records
        .whereType<Map>()
        .map((record) => _milkTrendDay(Map<String, Object?>.from(record)))
        .whereType<MilkTrendDay>()
        .toList(growable: false);
  }

  @override
  Future<List<GrowthRecord>> fetchGrowthRecords({
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

  @override
  Future<GrowthRecord> createGrowthRecord({
    required String babyId,
    required DateTime measuredAt,
    double? weightKg,
    double? heightCm,
    double? headCm,
    String? idempotencyKey,
  }) async {
    final body = <String, Object?>{
      if (babyId.trim().isNotEmpty) 'infant_id': babyId.trim(),
      'measured_at': measuredAt.toUtc().toIso8601String(),
      'weight_kg': weightKg,
      'height_cm': heightCm,
      'head_cm': headCm,
    }..removeWhere((_, value) => value == null);
    final response = await transport.postJson(
      growthRecordsEndpoint,
      body: body,
      headers: {
        if (idempotencyKey?.trim().isNotEmpty == true)
          'Idempotency-Key': idempotencyKey!.trim(),
      },
    );
    return _growthRecord(response);
  }

  @override
  Future<GrowthRecord> updateGrowthRecord({
    required String recordId,
    double? weightKg,
    double? heightCm,
    double? headCm,
  }) async {
    final mutations = transport;
    if (mutations is! ApiJsonMutationTransport) {
      throw UnsupportedError('Growth updates require JSON mutation support.');
    }
    final body = <String, Object?>{
      'weight_kg': weightKg,
      'height_cm': heightCm,
      'head_cm': headCm,
    }..removeWhere((_, value) => value == null);
    final response = await (mutations as ApiJsonMutationTransport).patchJson(
      '$growthRecordsEndpoint/${Uri.encodeComponent(recordId.trim())}',
      body: body,
    );
    return _growthRecord(response);
  }
}

FeedingRecord _feedingRecord(Map<String, Object?> data) {
  return FeedingRecord(
    id: _string(data['id'] ?? data['recordId']) ?? '',
    infantId: _string(data['infant_id'] ?? data['infantId'])?.trim(),
    type:
        _string(data['feed_type'] ?? data['type'] ?? data['feedingType']) ?? '',
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

MilkTrendDay? _milkTrendDay(Map<String, Object?> data) {
  final date = _dateTime(data['date'] ?? data['delivery_date']);
  if (date == null) return null;
  return MilkTrendDay(
    date: DateTime(date.year, date.month, date.day),
    pumpedMilkVolumeMl:
        _double(
          data['pumped_milk_volume_ml'] ??
              data['total_milk'] ??
              data['actual_ml'],
        ) ??
        0,
    pumpingCount: _int(data['pumping_count'] ?? data['pump_count']) ?? 0,
    measuredOnly: data['measured_only'] != false,
    estimatedMilkVolumeMl: _double(
      data['estimated_milk_volume_ml'] ??
          data['total_milk_estimate'] ??
          data['totol_milk_estimate'],
    ),
    referenceLowerMl: _double(
      data['reference_lower_ml'] ?? data['reference_lower'],
    ),
    referenceUpperMl: _double(
      data['reference_upper_ml'] ?? data['reference_upper'],
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
    headCm: _double(data['head_cm'] ?? data['headCm']),
    measuredAt: _dateTime(data['measured_at'] ?? data['measuredAt']),
  );
}

SleepRecord _sleepRecord(Map<String, Object?> data) {
  return SleepRecord(
    id: _string(data['id']) ?? '',
    infantId: _string(data['infant_id'] ?? data['infantId']) ?? '',
    type: _string(data['sleep_type'] ?? data['type']) ?? '',
    durationSeconds: _int(data['duration_seconds']) ?? 0,
    startedAt: _dateTime(data['started_at'] ?? data['startedAt']),
    endedAt: _dateTime(data['ended_at'] ?? data['endedAt']),
    notes: _string(data['notes']) ?? '',
  );
}

DiaperRecord _diaperRecord(Map<String, Object?> data) {
  return DiaperRecord(
    id: _string(data['id']) ?? '',
    infantId: _string(data['infant_id'] ?? data['infantId']) ?? '',
    type: _string(data['diaper_type'] ?? data['type']) ?? '',
    changedAt: _dateTime(data['changed_at'] ?? data['changedAt']),
    notes: _string(data['notes']) ?? '',
  );
}

String _requiredBabyId(String value) {
  final babyId = value.trim();
  if (babyId.isEmpty) throw ArgumentError.value(value, 'babyId');
  return babyId;
}

({DateTime start, DateTime end}) _dayRange(DateTime date) {
  if (date.isUtc) {
    final start = DateTime.utc(date.year, date.month, date.day);
    return (start: start, end: start.add(const Duration(days: 1)));
  }
  final localStart = DateTime(date.year, date.month, date.day);
  final localEnd = DateTime(date.year, date.month, date.day + 1);
  return (start: localStart.toUtc(), end: localEnd.toUtc());
}

String _id(Object? value) {
  if (value is int) return value.toString();
  return value is String ? value : '';
}

String? _string(Object? value) => value is String ? value : null;

int? _int(Object? value) {
  if (value is int) return value;
  if (value is double) return value.round();
  if (value is String) return double.tryParse(value)?.round();
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
  if (value is String) return double.tryParse(value);
  return null;
}

DateTime? _dateTime(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}

String _dateKey(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}
