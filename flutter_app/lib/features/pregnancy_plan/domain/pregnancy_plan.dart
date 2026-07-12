abstract interface class PregnancyPlanRepository {
  Future<PregnancyPlan?> fetchActivePlan();
}

class PregnancyPlan {
  const PregnancyPlan({
    required this.id,
    required this.planType,
    required this.title,
    required this.summary,
    required this.status,
    required this.source,
    required this.payload,
  });

  final String id;
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

  bool get hasRenderableCard {
    final persistedCard = card;
    final cardType = persistedCard['card_type'];
    final cardJson = persistedCard['card_json'];
    if (cardType != 'birth_journey_plan_card' || cardJson is! Map) {
      return false;
    }
    final todoPlan = cardJson['todo_plan'] ?? cardJson['todoPlan'];
    if (todoPlan is! Map) return false;
    final periods = todoPlan['periods'];
    if (periods is! List || periods.isEmpty) return false;
    return periods.every((rawPeriod) {
      if (rawPeriod is! Map || !_hasText(rawPeriod['title'])) return false;
      final items = rawPeriod['items'];
      return items is List &&
          items.isNotEmpty &&
          items.every(
            (rawItem) => rawItem is Map && _hasText(rawItem['title']),
          );
    });
  }
}

bool _hasText(Object? value) => value is String && value.trim().isNotEmpty;
