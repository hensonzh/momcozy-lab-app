abstract interface class PregnancyPlanRepository {
  Future<PregnancyPlan?> fetchActivePlan();

  Future<PregnancyPlan> updateTodoCompletion({
    required String planId,
    required String itemId,
    required bool completed,
    required int expectedVersion,
    String? idempotencyKey,
  });

  Future<void> deletePlan({required String planId});
}

class PregnancyPlan {
  const PregnancyPlan({
    required this.id,
    this.version = 0,
    required this.planType,
    required this.title,
    required this.summary,
    required this.status,
    required this.source,
    required this.payload,
  });

  final String id;
  final int version;
  final String planType;
  final String title;
  final String summary;
  final String status;
  final String source;
  final Map<String, Object?> payload;

  Map<String, Object?> get card {
    final raw = payload['card'];
    return raw is Map
        ? Map<String, Object?>.unmodifiable(Map<String, Object?>.from(raw))
        : const <String, Object?>{};
  }
}
