abstract interface class FeedingRecordsRepository {
  Future<List<FeedingRecord>> fetchFeedingRecords({
    required DateTime date,
    required String babyId,
    int days = 1,
  });

  Future<List<FeedingRecord>> fetchFeedingRecordsRange({
    required DateTime start,
    required DateTime end,
    required String babyId,
  });

  Future<FeedingRecord> createFeedingRecord({
    required String babyId,
    required DateTime occurredAt,
    required String type,
    double? amountMl,
    int? durationSeconds,
    String? idempotencyKey,
  });
}

abstract interface class PumpMilkRecordsRepository {
  Future<List<PumpMilkRecord>> fetchPumpMilkRecords({required DateTime date});

  Future<List<PumpMilkRecord>> fetchPumpMilkRecordsRange({
    required DateTime start,
    required DateTime end,
  });

  Future<PumpMilkRecord> createPumpMilkRecord({
    required DateTime occurredAt,
    double? amountMl,
    BreastSide? breastSide,
    int? durationSeconds,
    String? idempotencyKey,
  });
}

abstract interface class WaterRecordsRepository {
  Future<List<WaterIntakeRecord>> fetchWaterRecords({required DateTime date});

  Future<WaterIntakeRecord> createWaterRecord({
    required DateTime occurredAt,
    required double amountMl,
    String? idempotencyKey,
  });
}

abstract interface class WaterTrendRepository {
  Future<List<WaterTrendDay>> fetchWaterTrends({
    required DateTime startDate,
    required int days,
    required int utcOffsetMinutes,
  });
}

abstract interface class VitalRecordsRepository {
  Future<List<VitalRecord>> fetchVitalRecords({DateTime? start, DateTime? end});

  Future<VitalRecord> createVitalRecord({
    required DateTime measuredAt,
    double? weightKg,
    int? systolicMmhg,
    int? diastolicMmhg,
    int? heartRateBpm,
    double? temperatureC,
    String? idempotencyKey,
  });
}

abstract interface class SleepRecordsRepository {
  Future<List<SleepRecord>> fetchSleepRecords({
    required String babyId,
    required DateTime start,
    required DateTime end,
  });

  Future<SleepRecord> createSleepRecord({
    required String babyId,
    required DateTime startedAt,
    DateTime? endedAt,
    required SleepKind kind,
    String? idempotencyKey,
  });
}

abstract interface class DiaperRecordsRepository {
  Future<List<DiaperRecord>> fetchDiaperRecords({
    required String babyId,
    required DateTime start,
    required DateTime end,
  });

  Future<DiaperRecord> createDiaperRecord({
    required String babyId,
    required DateTime changedAt,
    required DiaperKind kind,
    DiaperWetness? wetness,
    String? stoolColor,
    String? stoolConsistency,
    String notes = '',
    String? idempotencyKey,
  });
}

abstract interface class MilkTrendRepository {
  Future<List<MilkTrendDay>> fetchMilkTrends({
    required DateTime startDate,
    required int days,
    bool includeToday = true,
    int? utcOffsetMinutes,
  });
}

abstract interface class GrowthRecordsRepository {
  Future<List<GrowthRecord>> fetchGrowthRecords({required String babyId});

  Future<GrowthRecord> createGrowthRecord({
    required String babyId,
    required DateTime measuredAt,
    double? weightKg,
    double? heightCm,
    double? headCm,
    String? idempotencyKey,
  });

  Future<GrowthRecord> updateGrowthRecord({
    required String recordId,
    double? weightKg,
    double? heightCm,
    double? headCm,
  });
}

class FeedingRecord {
  const FeedingRecord({
    required this.id,
    required this.type,
    required this.amountMl,
    this.infantId,
    this.occurredAt,
  });

  final String id;
  final String? infantId;
  final String type;
  final int? amountMl;
  final DateTime? occurredAt;
}

class PumpMilkRecord {
  const PumpMilkRecord({
    required this.id,
    required this.title,
    this.pumpType,
    this.pumpSource,
    this.breastSide,
    this.amountMl,
    this.occurredAt,
  });

  final String id;
  final String title;
  final int? pumpType;
  final int? pumpSource;
  final BreastSide? breastSide;
  final int? amountMl;
  final DateTime? occurredAt;
}

enum BreastSide {
  left,
  right,
  both;

  String get apiValue => name;

  static BreastSide? tryParse(Object? value) {
    return switch (value) {
      'left' => BreastSide.left,
      'right' => BreastSide.right,
      'both' => BreastSide.both,
      _ => null,
    };
  }
}

class WaterIntakeRecord {
  const WaterIntakeRecord({
    required this.id,
    required this.amountMl,
    this.occurredAt,
  });

  final String id;
  final double amountMl;
  final DateTime? occurredAt;
}

class WaterTrendDay {
  const WaterTrendDay({
    required this.date,
    required this.totalWaterMl,
    required this.entryCount,
    this.measuredOnly = true,
  });

  final DateTime date;
  final double totalWaterMl;
  final int entryCount;
  final bool measuredOnly;
}

class VitalRecord {
  const VitalRecord({
    required this.id,
    this.measuredAt,
    this.weightKg,
    this.systolicMmhg,
    this.diastolicMmhg,
    this.heartRateBpm,
    this.temperatureC,
  });

  final String id;
  final DateTime? measuredAt;
  final double? weightKg;
  final int? systolicMmhg;
  final int? diastolicMmhg;
  final int? heartRateBpm;
  final double? temperatureC;
}

enum SleepKind {
  night,
  nap,
  other;

  String get apiValue => name;

  static SleepKind tryParse(Object? value) {
    return switch (value) {
      'night' => SleepKind.night,
      'nap' => SleepKind.nap,
      _ => SleepKind.other,
    };
  }
}

class SleepRecord {
  const SleepRecord({
    required this.id,
    required this.startedAt,
    required this.kind,
    this.infantId,
    this.endedAt,
    this.notes = '',
  });

  final String id;
  final String? infantId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final SleepKind kind;
  final String notes;

  Duration? get duration => endedAt?.difference(startedAt);
  int get durationSeconds => duration?.inSeconds ?? 0;
  String get type => kind.apiValue;

  Duration durationUntil(DateTime now) {
    final effectiveEnd = endedAt ?? now;
    if (!effectiveEnd.isAfter(startedAt)) return Duration.zero;
    return effectiveEnd.difference(startedAt);
  }
}

enum DiaperKind {
  wet,
  dirty,
  both;

  String get apiValue => name;

  static DiaperKind tryParse(Object? value) {
    return switch (value) {
      'dirty' => DiaperKind.dirty,
      'both' => DiaperKind.both,
      _ => DiaperKind.wet,
    };
  }
}

enum DiaperWetness {
  light,
  medium,
  heavy;

  String get apiValue => name;

  static DiaperWetness? tryParse(Object? value) {
    return switch (value) {
      'light' => DiaperWetness.light,
      'medium' => DiaperWetness.medium,
      'heavy' => DiaperWetness.heavy,
      _ => null,
    };
  }
}

class DiaperRecord {
  const DiaperRecord({
    required this.id,
    required this.changedAt,
    required this.kind,
    this.infantId,
    this.wetness,
    this.stoolColor,
    this.stoolConsistency,
    this.notes = '',
  });

  final String id;
  final String? infantId;
  final DateTime changedAt;
  final DiaperKind kind;
  final DiaperWetness? wetness;
  final String? stoolColor;
  final String? stoolConsistency;
  final String notes;

  String get type => kind == DiaperKind.both ? 'mixed' : kind.apiValue;

  bool get includesWet => kind == DiaperKind.wet || kind == DiaperKind.both;
  bool get includesDirty => kind == DiaperKind.dirty || kind == DiaperKind.both;
}

class MilkTrendDay {
  const MilkTrendDay({
    required this.date,
    required this.pumpedMilkVolumeMl,
    required this.pumpingCount,
    this.measuredOnly = true,
    this.estimatedMilkVolumeMl,
    this.referenceLowerMl,
    this.referenceUpperMl,
  });

  final DateTime date;
  final double pumpedMilkVolumeMl;
  final int pumpingCount;
  final bool measuredOnly;
  final double? estimatedMilkVolumeMl;
  final double? referenceLowerMl;
  final double? referenceUpperMl;
}

class GrowthRecord {
  const GrowthRecord({
    required this.id,
    this.weightGram,
    this.heightCm,
    this.headCm,
    this.measuredAt,
  });

  final String id;
  final int? weightGram;
  final double? heightCm;
  final double? headCm;
  final DateTime? measuredAt;

  double? get weightKg => weightGram == null ? null : weightGram! / 1000;
}
