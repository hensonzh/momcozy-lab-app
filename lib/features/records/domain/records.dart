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
    required FeedingMethod feedingMethod,
    double? volumeMl,
    int? durationSeconds,
    String? planTaskId,
    String? idempotencyKey,
  });

  Future<FeedingSummary> fetchFeedingSummary({
    required String babyId,
    required int days,
    required String timezone,
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
    DateTime? endedAt,
    double? milkVolumeMl,
    int? durationSeconds,
    String? planTaskId,
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
    int? wetDiaperCount,
    int? bowelMovementCount,
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
    required MeasurementPosition measurementPosition,
    required MeasurementContext measurementContext,
    String? idempotencyKey,
  });

  Future<GrowthRecord> updateGrowthRecord({
    required String recordId,
    double? weightKg,
    double? heightCm,
    double? headCm,
    MeasurementPosition? measurementPosition,
    MeasurementContext? measurementContext,
  });
}

class FeedingRecord {
  const FeedingRecord({
    required this.id,
    required this.feedingMethod,
    required this.milkComponents,
    this.durationSeconds,
    this.breastSide,
    this.infantId,
    this.occurredAt,
  });

  final String id;
  final String? infantId;
  final FeedingMethod feedingMethod;
  final List<FeedingMilkComponent> milkComponents;
  final int? durationSeconds;
  final FeedingBreastSide? breastSide;
  final DateTime? occurredAt;

  double? get measuredVolumeMl {
    final values = milkComponents
        .map((component) => component.volumeMl)
        .whereType<double>()
        .toList(growable: false);
    return values.isEmpty
        ? null
        : values.fold<double>(0, (sum, value) => sum + value);
  }
}

enum FeedingMethod {
  directBreastfeeding('direct_breastfeeding'),
  bottle('bottle'),
  cup('cup'),
  syringe('syringe'),
  tube('tube'),
  other('other');

  const FeedingMethod(this.apiValue);

  final String apiValue;

  static FeedingMethod? tryParse(Object? value) {
    final normalized = value is String ? value.trim() : '';
    for (final method in values) {
      if (method.apiValue == normalized) return method;
    }
    return null;
  }
}

enum MilkSource {
  breastMilk('breast_milk'),
  formula('formula'),
  donorMilk('donor_milk'),
  unknown('unknown');

  const MilkSource(this.apiValue);

  final String apiValue;

  static MilkSource? tryParse(Object? value) {
    final normalized = value is String ? value.trim() : '';
    for (final source in values) {
      if (source.apiValue == normalized) return source;
    }
    return null;
  }
}

enum FeedingBreastSide {
  left,
  right,
  both;

  String get apiValue => name;

  static FeedingBreastSide? tryParse(Object? value) {
    return switch (value) {
      'left' => FeedingBreastSide.left,
      'right' => FeedingBreastSide.right,
      'both' => FeedingBreastSide.both,
      _ => null,
    };
  }
}

class FeedingMilkComponent {
  const FeedingMilkComponent({required this.milkSource, this.volumeMl});

  final MilkSource milkSource;
  final double? volumeMl;
}

class PumpMilkRecord {
  const PumpMilkRecord({
    required this.id,
    this.pumpType = '',
    this.outputs = const <PumpingOutput>[],
    this.durationSeconds,
    this.occurredAt,
    this.endedAt,
  });

  final String id;
  final String pumpType;
  final List<PumpingOutput> outputs;
  final int? durationSeconds;
  final DateTime? occurredAt;
  final DateTime? endedAt;

  double? get measuredVolumeMl {
    final values = outputs
        .map((output) => output.volumeMl)
        .whereType<double>()
        .toList(growable: false);
    return values.isEmpty
        ? null
        : values.fold<double>(0, (sum, value) => sum + value);
  }
}

enum PumpingSide {
  left,
  right,
  unassigned;

  String get apiValue => name;

  static PumpingSide? tryParse(Object? value) {
    return switch (value) {
      'left' => PumpingSide.left,
      'right' => PumpingSide.right,
      'unassigned' => PumpingSide.unassigned,
      _ => null,
    };
  }
}

class PumpingOutput {
  const PumpingOutput({required this.breastSide, this.volumeMl});

  final PumpingSide breastSide;
  final double? volumeMl;
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
  });

  final DateTime date;
  final double totalWaterMl;
  final int entryCount;
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
  });

  final String id;
  final String? infantId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final SleepKind kind;

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
    this.wetDiaperCount,
    this.bowelMovementCount,
    this.notes = '',
  });

  final String id;
  final String? infantId;
  final DateTime changedAt;
  final DiaperKind kind;
  final DiaperWetness? wetness;
  final String? stoolColor;
  final String? stoolConsistency;
  final int? wetDiaperCount;
  final int? bowelMovementCount;
  final String notes;

  String get type => kind == DiaperKind.both ? 'mixed' : kind.apiValue;

  bool get includesWet => kind == DiaperKind.wet || kind == DiaperKind.both;
  bool get includesDirty => kind == DiaperKind.dirty || kind == DiaperKind.both;
}

class MilkTrendDay {
  const MilkTrendDay({
    required this.date,
    required this.measuredVolumeMl,
    required this.pumpingCount,
    required this.measuredPumpingCount,
  });

  final DateTime date;
  final double? measuredVolumeMl;
  final int pumpingCount;
  final int measuredPumpingCount;
}

class GrowthRecord {
  const GrowthRecord({
    required this.id,
    this.weightGram,
    this.heightCm,
    this.headCm,
    this.measuredAt,
    this.measurementPosition = MeasurementPosition.unknown,
    this.measurementContext = MeasurementContext.unknown,
  });

  final String id;
  final int? weightGram;
  final double? heightCm;
  final double? headCm;
  final DateTime? measuredAt;
  final MeasurementPosition measurementPosition;
  final MeasurementContext measurementContext;

  double? get weightKg => weightGram == null ? null : weightGram! / 1000;
}

enum MeasurementPosition {
  recumbent,
  standing,
  unknown;

  String get apiValue => name;

  static MeasurementPosition tryParse(Object? value) => switch (value) {
    'recumbent' => MeasurementPosition.recumbent,
    'standing' => MeasurementPosition.standing,
    _ => MeasurementPosition.unknown,
  };
}

enum MeasurementContext {
  birth,
  routine,
  unknown;

  String get apiValue => name;

  static MeasurementContext tryParse(Object? value) => switch (value) {
    'birth' => MeasurementContext.birth,
    'routine' => MeasurementContext.routine,
    _ => MeasurementContext.unknown,
  };
}

class FeedingSummary {
  const FeedingSummary({
    required this.days,
    required this.timezone,
    required this.feedingCount,
    required this.measuredVolumeCount,
    required this.measuredVolumeMl,
    required this.averageMeasuredVolumeMl,
    required this.feedingMethodCounts,
    required this.milkSourceVolumesMl,
    required this.latestFeedingAt,
    required this.completedDays,
    required this.comparison,
    required this.intakeEvaluationContext,
  });

  final int days;
  final String timezone;
  final int feedingCount;
  final int measuredVolumeCount;
  final double measuredVolumeMl;
  final double? averageMeasuredVolumeMl;
  final Map<FeedingMethod, int> feedingMethodCounts;
  final Map<MilkSource, double> milkSourceVolumesMl;
  final DateTime? latestFeedingAt;
  final CompletedFeedingDays completedDays;
  final MilkWindowComparison comparison;
  final IntakeEvaluationContext intakeEvaluationContext;
}

class CompletedFeedingDays {
  const CompletedFeedingDays({
    required this.windowDays,
    required this.recordedDays,
    required this.measuredDays,
    required this.averageVolumePerMeasuredDayMl,
    required this.averageFeedingsPerRecordedDay,
    required this.dailySeries,
  });

  final int windowDays;
  final int recordedDays;
  final int measuredDays;
  final double? averageVolumePerMeasuredDayMl;
  final double? averageFeedingsPerRecordedDay;
  final List<FeedingTrendDay> dailySeries;
}

class FeedingTrendDay {
  const FeedingTrendDay({
    required this.date,
    required this.measuredVolumeMl,
    required this.feedingCount,
    required this.measuredFeedingCount,
  });

  final DateTime date;
  final double? measuredVolumeMl;
  final int feedingCount;
  final int measuredFeedingCount;
}

class MilkWindowComparison {
  const MilkWindowComparison({
    required this.status,
    required this.currentAverageVolumePerMeasuredDayMl,
    required this.previousAverageVolumePerMeasuredDayMl,
    required this.changePercent,
    required this.currentMeasuredDays,
    required this.previousMeasuredDays,
    required this.minimumMeasuredDays,
  });

  final String status;
  final double? currentAverageVolumePerMeasuredDayMl;
  final double? previousAverageVolumePerMeasuredDayMl;
  final double? changePercent;
  final int currentMeasuredDays;
  final int previousMeasuredDays;
  final int minimumMeasuredDays;
}

enum IntakeEvaluationStatus {
  evidenceAvailable('evidence_available'),
  insufficientData('insufficient_data'),
  unsupported('unsupported'),
  dependencyUnavailable('dependency_unavailable');

  const IntakeEvaluationStatus(this.apiValue);

  final String apiValue;

  static IntakeEvaluationStatus tryParse(Object? value) {
    for (final status in values) {
      if (status.apiValue == value) return status;
    }
    return IntakeEvaluationStatus.insufficientData;
  }
}

class IntakeEvaluationContext {
  const IntakeEvaluationContext({
    required this.status,
    required this.reasonCode,
    required this.growthMeasurementDate,
    required this.chronologicalAgeDays,
  });

  final IntakeEvaluationStatus status;
  final String? reasonCode;
  final DateTime? growthMeasurementDate;
  final int? chronologicalAgeDays;
}
