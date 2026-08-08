import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/records/domain/records.dart';

const feedingRecordsEndpoint = '/v1/records/feeding';
const pumpMilkRecordsEndpoint = '/v1/records/pumping';
const milkTrendsEndpoint = '/v1/records/milk-trends';
const growthRecordsEndpoint = '/v1/records/growth';
const waterRecordsEndpoint = '/v1/records/water';
const waterTrendsEndpoint = '/v1/records/water-trends';
const vitalRecordsEndpoint = '/v1/records/vitals';
const sleepRecordsEndpoint = '/v1/records/sleep';
const diaperRecordsEndpoint = '/v1/records/diaper';

class RecordsApiRepository
    implements
        FeedingRecordsRepository,
        PumpMilkRecordsRepository,
        MilkTrendRepository,
        GrowthRecordsRepository,
        WaterRecordsRepository,
        WaterTrendRepository,
        VitalRecordsRepository,
        SleepRecordsRepository,
        DiaperRecordsRepository {
  const RecordsApiRepository({required this.transport});

  final ApiJsonTransport transport;

  @override
  Future<List<FeedingRecord>> fetchFeedingRecords({
    required DateTime date,
    required String babyId,
    int days = 1,
  }) {
    if (days < 1 || days > 7) {
      throw ArgumentError.value(days, 'days', 'Must be between 1 and 7.');
    }
    final range = _dayRange(date);
    return _fetchFeedingRecordsRange(
      start: range.start.subtract(Duration(days: days - 1)),
      end: range.end,
      babyId: babyId,
      limit: days == 1 ? 50 : 100,
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
    final selectedBabyId = _requiredBabyId(babyId);
    final response = await transport.getJson(
      feedingRecordsEndpoint,
      query: {
        'start_at': start.toUtc().toIso8601String(),
        'end_at': end.toUtc().toIso8601String(),
        'infant_id': selectedBabyId,
        'limit': limit,
      },
    );
    final records = response['items'];
    return records is List
        ? records
              .whereType<Map>()
              .map(
                (record) => _feedingRecord(Map<String, Object?>.from(record)),
              )
              .where((record) => record.infantId == selectedBabyId)
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
    final selectedBabyId = _requiredBabyId(babyId);
    final normalizedType = type.trim().toLowerCase();
    final body = <String, Object?>{
      'infant_id': selectedBabyId,
      'feed_time': occurredAt.toUtc().toIso8601String(),
      'feed_type': normalizedType == 'formula' ? 'bottle' : normalizedType,
      'feed_action': switch (normalizedType) {
        'formula' => 'formula',
        'bottle' => 'expressed_milk',
        'breast' || 'breastfeeding' => 'direct',
        _ => normalizedType,
      },
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
    BreastSide? breastSide,
    int? durationSeconds,
    String? idempotencyKey,
  }) async {
    final body = <String, Object?>{
      'pump_start_time': occurredAt.toUtc().toIso8601String(),
      'milk_volume_ml': amountMl,
      'duration_seconds': durationSeconds,
      'pump_type': 'manual',
      'breast_side': breastSide?.apiValue,
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

  @override
  Future<List<WaterIntakeRecord>> fetchWaterRecords({
    required DateTime date,
  }) async {
    final range = _dayRange(date);
    final response = await transport.getJson(
      waterRecordsEndpoint,
      query: {
        'start_at': range.start.toIso8601String(),
        'end_at': range.end.toIso8601String(),
        'limit': 100,
      },
    );
    final records = response['items'];
    return records is List
        ? records
              .whereType<Map>()
              .map((record) => _waterRecord(Map<String, Object?>.from(record)))
              .toList(growable: false)
        : const <WaterIntakeRecord>[];
  }

  @override
  Future<WaterIntakeRecord> createWaterRecord({
    required DateTime occurredAt,
    required double amountMl,
    String? idempotencyKey,
  }) async {
    final response = await transport.postJson(
      waterRecordsEndpoint,
      body: {
        'occurred_at': occurredAt.toUtc().toIso8601String(),
        'amount_ml': amountMl,
        'source': 'manual',
      },
      headers: {
        if (idempotencyKey?.trim().isNotEmpty == true)
          'Idempotency-Key': idempotencyKey!.trim(),
      },
    );
    return _waterRecord(response);
  }

  @override
  Future<List<WaterTrendDay>> fetchWaterTrends({
    required DateTime startDate,
    required int days,
    required int utcOffsetMinutes,
  }) async {
    final response = await transport.getJson(
      waterTrendsEndpoint,
      query: {
        'start_date': _dateKey(startDate),
        'days': days,
        'utc_offset_minutes': utcOffsetMinutes,
      },
    );
    final records = response['items'];
    if (records is! List) return const <WaterTrendDay>[];
    return records
        .whereType<Map>()
        .map((record) => _waterTrendDay(Map<String, Object?>.from(record)))
        .whereType<WaterTrendDay>()
        .toList(growable: false);
  }

  @override
  Future<List<VitalRecord>> fetchVitalRecords({
    DateTime? start,
    DateTime? end,
  }) async {
    final response = await transport.getJson(
      vitalRecordsEndpoint,
      query: {
        if (start != null) 'start_at': start.toUtc().toIso8601String(),
        if (end != null) 'end_at': end.toUtc().toIso8601String(),
        'limit': 100,
      },
    );
    final records = response['items'];
    return records is List
        ? records
              .whereType<Map>()
              .map((record) => _vitalRecord(Map<String, Object?>.from(record)))
              .toList(growable: false)
        : const <VitalRecord>[];
  }

  @override
  Future<VitalRecord> createVitalRecord({
    required DateTime measuredAt,
    double? weightKg,
    int? systolicMmhg,
    int? diastolicMmhg,
    int? heartRateBpm,
    double? temperatureC,
    String? idempotencyKey,
  }) async {
    final body = <String, Object?>{
      'measured_at': measuredAt.toUtc().toIso8601String(),
      'weight_kg': weightKg,
      'systolic_mmhg': systolicMmhg,
      'diastolic_mmhg': diastolicMmhg,
      'heart_rate_bpm': heartRateBpm,
      'temperature_c': temperatureC,
      'source': 'manual',
    }..removeWhere((_, value) => value == null);
    final response = await transport.postJson(
      vitalRecordsEndpoint,
      body: body,
      headers: {
        if (idempotencyKey?.trim().isNotEmpty == true)
          'Idempotency-Key': idempotencyKey!.trim(),
      },
    );
    return _vitalRecord(response);
  }

  @override
  Future<List<SleepRecord>> fetchSleepRecords({
    required String babyId,
    required DateTime start,
    required DateTime end,
  }) async {
    final selectedBabyId = _requiredBabyId(babyId);
    final response = await transport.getJson(
      sleepRecordsEndpoint,
      query: {
        'infant_id': selectedBabyId,
        'start_at': start.toUtc().toIso8601String(),
        'end_at': end.toUtc().toIso8601String(),
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
    DateTime? endedAt,
    required SleepKind kind,
    String? idempotencyKey,
  }) async {
    final selectedBabyId = _requiredBabyId(babyId);
    final body = <String, Object?>{
      'infant_id': selectedBabyId,
      'started_at': startedAt.toUtc().toIso8601String(),
      'ended_at': endedAt?.toUtc().toIso8601String(),
      'sleep_kind': kind.apiValue,
      'source': 'manual',
    }..removeWhere((_, value) => value == null);
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
  Future<List<DiaperRecord>> fetchDiaperRecords({
    required String babyId,
    required DateTime start,
    required DateTime end,
  }) async {
    final selectedBabyId = _requiredBabyId(babyId);
    final response = await transport.getJson(
      diaperRecordsEndpoint,
      query: {
        'infant_id': selectedBabyId,
        'start_at': start.toUtc().toIso8601String(),
        'end_at': end.toUtc().toIso8601String(),
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
    required DiaperKind kind,
    DiaperWetness? wetness,
    String? stoolColor,
    String? stoolConsistency,
    String notes = '',
    String? idempotencyKey,
  }) async {
    final selectedBabyId = _requiredBabyId(babyId);
    final body =
        <String, Object?>{
          'infant_id': selectedBabyId,
          'changed_at': changedAt.toUtc().toIso8601String(),
          'diaper_kind': kind.apiValue,
          'wetness': wetness?.apiValue,
          'stool_color': stoolColor?.trim(),
          'stool_consistency': stoolConsistency?.trim(),
          'notes': notes.trim(),
          'source': 'manual',
        }..removeWhere(
          (_, value) => value == null || (value is String && value.isEmpty),
        );
    body['notes'] = notes.trim();
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
    int? utcOffsetMinutes,
  }) async {
    final response = await transport.getJson(
      milkTrendsEndpoint,
      query: {
        'start_date': _dateKey(startDate),
        'days': days,
        'include_today': includeToday,
        'utc_offset_minutes': ?utcOffsetMinutes,
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
    final selectedBabyId = _requiredBabyId(babyId);
    final response = await transport.getJson(
      growthRecordsEndpoint,
      query: {'infant_id': selectedBabyId, 'limit': 50},
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
    final selectedBabyId = _requiredBabyId(babyId);
    final body = <String, Object?>{
      'infant_id': selectedBabyId,
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
    action: _string(data['feed_action'] ?? data['feedAction']) ?? '',
    amountMl: _int(data['volume_ml'] ?? data['amount_ml'] ?? data['amountMl']),
    durationSeconds: _int(data['duration_seconds'] ?? data['durationSeconds']),
    occurredAt: _dateTime(
      data['feed_time'] ?? data['occurred_at'] ?? data['occurredAt'],
    ),
  );
}

PumpMilkRecord _pumpMilkRecord(Map<String, Object?> data) {
  return PumpMilkRecord(
    id: _id(data['pump_id'] ?? data['pumpId'] ?? data['id']),
    pumpType: _string(data['pump_type'] ?? data['pumpType']) ?? '',
    breastSide: BreastSide.tryParse(data['breast_side'] ?? data['breastSide']),
    amountMl: _int(
      data['milk_volume_ml'] ??
          data['pump_milk_volum'] ??
          data['pumpMilkVolum'] ??
          data['amount_ml'] ??
          data['amountMl'],
    ),
    durationSeconds: _int(data['duration_seconds'] ?? data['durationSeconds']),
    occurredAt: _dateTime(
      data['pump_start_time'] ??
          data['pump_time'] ??
          data['pumpTime'] ??
          data['occurred_at'] ??
          data['occurredAt'],
    ),
  );
}

WaterIntakeRecord _waterRecord(Map<String, Object?> data) {
  return WaterIntakeRecord(
    id: _id(data['id'] ?? data['recordId']),
    amountMl: _double(data['amount_ml'] ?? data['amountMl']) ?? 0,
    occurredAt: _dateTime(data['occurred_at'] ?? data['occurredAt']),
  );
}

WaterTrendDay? _waterTrendDay(Map<String, Object?> data) {
  final date = _dateTime(data['date']);
  if (date == null) return null;
  return WaterTrendDay(
    date: DateTime(date.year, date.month, date.day),
    totalWaterMl: _double(data['total_water_ml'] ?? data['totalWaterMl']) ?? 0,
    entryCount: _int(data['entry_count'] ?? data['entryCount']) ?? 0,
  );
}

VitalRecord _vitalRecord(Map<String, Object?> data) {
  return VitalRecord(
    id: _id(data['id'] ?? data['recordId']),
    measuredAt: _dateTime(data['measured_at'] ?? data['measuredAt']),
    weightKg: _double(data['weight_kg'] ?? data['weightKg']),
    systolicMmhg: _int(data['systolic_mmhg'] ?? data['systolicMmhg']),
    diastolicMmhg: _int(data['diastolic_mmhg'] ?? data['diastolicMmhg']),
    heartRateBpm: _int(data['heart_rate_bpm'] ?? data['heartRateBpm']),
    temperatureC: _double(data['temperature_c'] ?? data['temperatureC']),
  );
}

SleepRecord _sleepRecord(Map<String, Object?> data) {
  final startedAt = _dateTime(data['started_at'] ?? data['startedAt']);
  if (startedAt == null) {
    throw const FormatException('Sleep record started_at is missing.');
  }
  return SleepRecord(
    id: _id(data['id'] ?? data['recordId']),
    infantId: _string(data['infant_id'] ?? data['infantId'])?.trim(),
    startedAt: startedAt,
    endedAt: _dateTime(data['ended_at'] ?? data['endedAt']),
    kind: SleepKind.tryParse(data['sleep_kind'] ?? data['sleepKind']),
  );
}

DiaperRecord _diaperRecord(Map<String, Object?> data) {
  final changedAt = _dateTime(data['changed_at'] ?? data['changedAt']);
  if (changedAt == null) {
    throw const FormatException('Diaper record changed_at is missing.');
  }
  return DiaperRecord(
    id: _id(data['id'] ?? data['recordId']),
    infantId: _string(data['infant_id'] ?? data['infantId'])?.trim(),
    changedAt: changedAt,
    kind: DiaperKind.tryParse(data['diaper_kind'] ?? data['diaperKind']),
    wetness: DiaperWetness.tryParse(data['wetness']),
    stoolColor: _string(data['stool_color'] ?? data['stoolColor']),
    stoolConsistency: _string(
      data['stool_consistency'] ?? data['stoolConsistency'],
    ),
    notes: _string(data['notes']) ?? '',
  );
}

MilkTrendDay? _milkTrendDay(Map<String, Object?> data) {
  final date = _dateTime(data['date']);
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

String _requiredBabyId(String value) {
  final babyId = value.trim();
  if (babyId.isEmpty) {
    throw ArgumentError.value(value, 'babyId', 'Baby ID is required.');
  }
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
