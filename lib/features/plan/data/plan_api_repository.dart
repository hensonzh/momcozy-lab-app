import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/plan/domain/plan_dashboard.dart';

const planListEndpoint = '/v1/plans';
const planSessionListEndpoint = '/v1/plans/tasks/list';

class PlanApiRepository implements PlanRepository {
  const PlanApiRepository({required this.transport});

  final ApiJsonTransport transport;

  @override
  Future<PlanDashboard> fetchDashboard({required DateTime weekOf}) async {
    final selectedDay = _dateOnly(weekOf);
    final planResponse = await transport.getJson(
      planListEndpoint,
      query: const {'status': 'active', 'limit': 20},
    );
    final plans = _items(
      planResponse,
      endpoint: planListEndpoint,
    ).map(_carePlan).toList(growable: false);
    if (plans.isEmpty) return PlanDashboard.empty(weekOf: selectedDay);

    final sessionResponse = await transport.getJson(
      planSessionListEndpoint,
      query: {'task_date': _apiDate(selectedDay), 'limit': 100},
    );
    final activePlanIds = plans.map((plan) => plan.id).toSet();
    final rawSessions =
        _items(sessionResponse, endpoint: planSessionListEndpoint)
            .map((session) => _rawSession(session, activePlanIds))
            .whereType<_RawPlanSession>()
            .toList(growable: false)
          ..sort(
            (left, right) => left.scheduledAt.compareTo(right.scheduledAt),
          );
    var markedNext = false;
    final sessions = <PlanSession>[];
    for (final session in rawSessions) {
      final status = session.completed
          ? PlanSessionStatus.completed
          : !markedNext
          ? PlanSessionStatus.next
          : PlanSessionStatus.upcoming;
      if (status == PlanSessionStatus.next) markedNext = true;
      sessions.add(
        PlanSession(
          id: session.id,
          planId: session.planId,
          title: session.title,
          scheduledAt: session.scheduledAt,
          status: status,
          valueLabel: session.valueLabel,
        ),
      );
    }

    final primaryPayload = _items(
      planResponse,
      endpoint: planListEndpoint,
    ).firstOrNull?['payload'];
    final metrics = _objectMap(primaryPayload);
    return PlanDashboard(
      weekOf: selectedDay,
      plans: plans,
      sessions: List<PlanSession>.unmodifiable(sessions),
      weeklyCompletedSessions: _integer(metrics['weekly_completed_sessions']),
      weeklyTotalSessions: _integer(metrics['weekly_total_sessions']),
    );
  }
}

CarePlan _carePlan(Map<String, Object?> data) {
  final payload = _objectMap(data['payload']);
  final category = _category(_requiredString(data, 'plan_type'));
  final rawTitle = _optionalString(data['title']);
  return CarePlan(
    id: _requiredString(data, 'id'),
    category: category,
    title: rawTitle ?? _defaultTitle(category),
    summary: _optionalString(data['summary']) ?? '',
    weekNumber: _positiveInt(payload['week_number'], fallback: 1),
    totalWeeks: _positiveInt(payload['total_weeks'], fallback: 8),
    sessionsPerDay: _positiveInt(payload['sessions_per_day'], fallback: 5),
    dailyTargetVolumeMl: _positiveInt(
      payload['daily_target_volume_ml'],
      fallback: 600,
    ),
    todayVolumeMl: _nonNegativeInt(payload['today_volume_ml']),
    weeklyTargetVolumeMl: _positiveInt(
      payload['weekly_target_volume_ml'],
      fallback: 4200,
    ),
    weeklyVolumeMl: _nonNegativeInt(payload['weekly_volume_ml']),
  );
}

_RawPlanSession? _rawSession(
  Map<String, Object?> data,
  Set<String> activePlanIds,
) {
  final planId = _optionalString(data['plan_id']);
  if (planId == null || !activePlanIds.contains(planId)) return null;
  final payload = _objectMap(data['payload']);
  final date = _requiredString(data, 'task_date');
  final time = _requiredString(data, 'task_time');
  final parsed = DateTime.tryParse('${date}T$time:00');
  if (parsed == null) {
    throw const FormatException('Plan session has an invalid date or time.');
  }
  final status = _requiredString(data, 'status').toLowerCase();
  return _RawPlanSession(
    id: _requiredString(data, 'id'),
    planId: planId,
    title: _requiredString(data, 'title'),
    scheduledAt: parsed,
    completed: status == 'completed' || status == 'done',
    valueLabel: _optionalString(payload['value_label']),
  );
}

class _RawPlanSession {
  const _RawPlanSession({
    required this.id,
    required this.planId,
    required this.title,
    required this.scheduledAt,
    required this.completed,
    this.valueLabel,
  });

  final String id;
  final String planId;
  final String title;
  final DateTime scheduledAt;
  final bool completed;
  final String? valueLabel;
}

PlanCategory _category(String wireValue) {
  return switch (wireValue.trim().toLowerCase()) {
    'milk_management' ||
    'lactation' ||
    'breast_pumping' => PlanCategory.lactation,
    'yoga' || 'recovery_yoga' => PlanCategory.yoga,
    'pelvic_floor' || 'pelvic-floor' => PlanCategory.pelvicFloor,
    _ => PlanCategory.other,
  };
}

String _defaultTitle(PlanCategory category) => switch (category) {
  PlanCategory.lactation => 'Breast Pumping Plan',
  PlanCategory.yoga => 'Yoga',
  PlanCategory.pelvicFloor => 'Pelvic Floor',
  PlanCategory.other => 'Plan',
};

List<Map<String, Object?>> _items(
  Map<String, Object?> response, {
  required String endpoint,
}) {
  final raw = response['items'];
  if (raw is! List) {
    throw FormatException('$endpoint response must contain an items list.');
  }
  return raw
      .map((item) {
        if (item is! Map) {
          throw FormatException('$endpoint items must be JSON objects.');
        }
        return Map<String, Object?>.from(item);
      })
      .toList(growable: false);
}

Map<String, Object?> _objectMap(Object? value) {
  if (value is! Map) return const {};
  return Map<String, Object?>.from(value);
}

String _requiredString(Map<String, Object?> data, String key) {
  final value = _optionalString(data[key]);
  if (value == null) throw FormatException('$key is required.');
  return value;
}

String? _optionalString(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return value.trim();
}

int? _integer(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '');
}

int _positiveInt(Object? value, {required int fallback}) {
  final parsed = _integer(value);
  return parsed == null || parsed <= 0 ? fallback : parsed;
}

int _nonNegativeInt(Object? value) {
  final parsed = _integer(value) ?? 0;
  return parsed < 0 ? 0 : parsed;
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String _apiDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
