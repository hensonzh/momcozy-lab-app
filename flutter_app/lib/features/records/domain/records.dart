abstract interface class FeedingRecordsRepository {
  Future<List<FeedingRecord>> fetchFeedingRecords({
    required DateTime date,
  });
}

abstract interface class PumpMilkRecordsRepository {
  Future<List<PumpMilkRecord>> fetchPumpMilkRecords({
    required DateTime date,
  });
}

abstract interface class GrowthRecordsRepository {
  Future<List<GrowthRecord>> fetchGrowthRecords({
    required String babyId,
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
    this.measuredAt,
  });

  final String id;
  final int? weightGram;
  final double? heightCm;
  final DateTime? measuredAt;
}
