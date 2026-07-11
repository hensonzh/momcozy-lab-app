abstract interface class FeedingRecordsRepository {
  Future<List<FeedingRecord>> fetchFeedingRecords({required DateTime date});
}

abstract interface class PumpMilkRecordsRepository {
  Future<List<PumpMilkRecord>> fetchPumpMilkRecords({required DateTime date});

  Future<List<PumpMilkRecord>> fetchPumpMilkRecordsRange({
    required DateTime start,
    required DateTime end,
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
