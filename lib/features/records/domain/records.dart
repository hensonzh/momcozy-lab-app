abstract interface class FeedingRecordsRepository {
  Future<List<FeedingRecord>> fetchFeedingRecords({
    required DateTime date,
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
    int? durationSeconds,
    String? idempotencyKey,
  });
}

abstract interface class MilkTrendRepository {
  Future<List<MilkTrendDay>> fetchMilkTrends({
    required DateTime startDate,
    required int days,
    bool includeToday = true,
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
    this.occurredAt,
  });

  final String id;
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
    this.amountMl,
    this.occurredAt,
  });

  final String id;
  final String title;
  final int? pumpType;
  final int? pumpSource;
  final int? amountMl;
  final DateTime? occurredAt;
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
