abstract interface class FeedingRecordsRepository {
  Future<List<FeedingRecord>> fetchFeedingRecords({
    required String userId,
    required DateTime date,
  });
}

abstract interface class GrowthRecordsRepository {
  Future<List<GrowthRecord>> fetchGrowthRecords({
    required String userId,
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
