import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/plan/domain/plan_dashboard.dart';

const planListEndpoint = '/v1/plans';
const planSessionListEndpoint = '/v1/plans/tasks/list';

String planSessionEndpoint(String sessionId) =>
    '/v1/plans/tasks/${Uri.encodeComponent(sessionId.trim())}';

String planSessionStateEndpoint(String sessionId) =>
    '${planSessionEndpoint(sessionId)}/state';

class PlanApiRepository
    implements
        PlanRepository,
        PlanDashboardSnapshotProvider,
        PlanSessionMutationRepository {
  PlanApiRepository({required this.transport});

  final ApiJsonTransport transport;
  PlanDashboard? _snapshot;
  DateTime? _snapshotDay;
  Future<PlanDashboard>? _inFlight;
  DateTime? _inFlightDay;
  int _cacheRevision = 0;

  @override
  Future<PlanDashboard> fetchDashboard({required DateTime weekOf}) {
    final selectedDay = _dateOnly(weekOf);
    final inFlight = _inFlight;
    if (inFlight != null && _sameDay(_inFlightDay, selectedDay)) {
      return inFlight;
    }

    late final Future<PlanDashboard> request;
    final cacheRevision = _cacheRevision;
    request = _fetchDashboard(selectedDay)
        .then((dashboard) {
          if (_cacheRevision == cacheRevision) {
            _snapshot = dashboard;
            _snapshotDay = selectedDay;
          }
          return dashboard;
        })
        .whenComplete(() {
          if (identical(_inFlight, request)) {
            _inFlight = null;
            _inFlightDay = null;
          }
        });
    _inFlight = request;
    _inFlightDay = selectedDay;
    return request;
  }

  @override
  PlanDashboard? snapshotFor({required DateTime weekOf}) {
    return _sameDay(_snapshotDay, _dateOnly(weekOf)) ? _snapshot : null;
  }

  void invalidate() {
    _cacheRevision += 1;
    _snapshot = null;
    _snapshotDay = null;
    _inFlight = null;
    _inFlightDay = null;
  }

  @override
  Future<void> updateSession({
    required String sessionId,
    required String title,
    required DateTime scheduledAt,
  }) async {
    final normalizedSessionId = sessionId.trim();
    final normalizedTitle = title.trim();
    if (normalizedSessionId.isEmpty) {
      throw ArgumentError.value(sessionId, 'sessionId', 'must not be empty');
    }
    if (normalizedTitle.isEmpty) {
      throw ArgumentError.value(title, 'title', 'must not be empty');
    }
    if (transport is! ApiJsonMutationTransport) {
      throw UnsupportedError('Plan session editing requires PATCH support.');
    }
    final mutationTransport = transport as ApiJsonMutationTransport;

    await mutationTransport.patchJson(
      planSessionEndpoint(normalizedSessionId),
      body: {
        'title': normalizedTitle,
        'task_date': _apiDate(scheduledAt),
        'task_time': _apiTime(scheduledAt),
      },
    );
    invalidate();
  }

  @override
  Future<void> updateSessionState({
    required String sessionId,
    required PlanTaskState state,
  }) async {
    final normalizedSessionId = sessionId.trim();
    if (normalizedSessionId.isEmpty) {
      throw ArgumentError.value(sessionId, 'sessionId', 'must not be empty');
    }
    if (transport is! ApiJsonMutationTransport) {
      throw UnsupportedError('Plan task state updates require PATCH support.');
    }
    await (transport as ApiJsonMutationTransport).patchJson(
      planSessionStateEndpoint(normalizedSessionId),
      body: {'state': state.name},
    );
    invalidate();
  }

  Future<PlanDashboard> _fetchDashboard(DateTime selectedDay) async {
    final planRequest = transport.getJson(
      planListEndpoint,
      query: const {'status': 'active', 'limit': 20},
    );
    final sessionRequest = _fetchSessions(selectedDay);
    final planResponse = await planRequest;
    final plans = _items(
      planResponse,
      endpoint: planListEndpoint,
    ).map(_carePlan).toList(growable: false);
    if (plans.isEmpty) return PlanDashboard.empty(weekOf: selectedDay);

    final sessionResponse = (await sessionRequest).unwrap();
    final activePlans = {for (final plan in plans) plan.id: plan};
    final rawSessions =
        _items(sessionResponse, endpoint: planSessionListEndpoint)
            .map((session) => _rawSession(session, activePlans))
            .whereType<_RawPlanSession>()
            .toList(growable: false)
          ..sort(
            (left, right) => left.scheduledAt.compareTo(right.scheduledAt),
          );
    final plansWithNextSession = <String>{};
    final sessions = <PlanSession>[];
    for (final session in rawSessions) {
      final status = switch (session.state) {
        PlanTaskState.completed => PlanSessionStatus.completed,
        PlanTaskState.skipped => PlanSessionStatus.skipped,
        PlanTaskState.pending when plansWithNextSession.add(session.planId) =>
          PlanSessionStatus.next,
        PlanTaskState.pending => PlanSessionStatus.upcoming,
      };
      sessions.add(
        PlanSession(
          id: session.id,
          planId: session.planId,
          title: session.title,
          scheduledAt: session.scheduledAt,
          status: status,
          kind: session.kind,
          valueLabel: session.valueLabel,
        ),
      );
    }

    return PlanDashboard(
      weekOf: selectedDay,
      plans: plans,
      sessions: List<PlanSession>.unmodifiable(sessions),
    );
  }

  Future<_PlanSessionResponse> _fetchSessions(DateTime selectedDay) async {
    try {
      return _PlanSessionResponse.success(
        await transport.getJson(
          planSessionListEndpoint,
          query: {'task_date': _apiDate(selectedDay), 'limit': 100},
        ),
      );
    } catch (error, stackTrace) {
      return _PlanSessionResponse.failure(error, stackTrace);
    }
  }
}

bool _sameDay(DateTime? left, DateTime right) {
  return left != null &&
      left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

class _PlanSessionResponse {
  const _PlanSessionResponse.success(this.response)
    : error = null,
      stackTrace = null;

  const _PlanSessionResponse.failure(this.error, this.stackTrace)
    : response = null;

  final Map<String, Object?>? response;
  final Object? error;
  final StackTrace? stackTrace;

  Map<String, Object?> unwrap() {
    final error = this.error;
    if (error != null) {
      Error.throwWithStackTrace(error, stackTrace!);
    }
    return response!;
  }
}

CarePlan _carePlan(Map<String, Object?> data) {
  final payload = _objectMap(data['payload']);
  final basis = _objectMap(payload['basis']);
  final preferences = _objectMap(payload['preferences']);
  final targetDailyPattern = _objectMap(preferences['target_daily_pattern']);
  final category = _category(_requiredString(data, 'plan_type'));
  final rawTitle = _optionalString(data['title']);
  final pumpingSessions = _optionalNonNegativeInt(
    targetDailyPattern['pumping_sessions'],
  );
  final breastfeedingAnchors = _optionalNonNegativeInt(
    targetDailyPattern['breastfeeding_anchors'],
  );
  final explicitSessionsPerDay = _optionalPositiveInt(
    payload['sessions_per_day'],
  );
  final generatedSessionsPerDay =
      pumpingSessions != null || breastfeedingAnchors != null
      ? (pumpingSessions ?? 0) + (breastfeedingAnchors ?? 0)
      : null;
  return CarePlan(
    id: _requiredString(data, 'id'),
    category: category,
    title: rawTitle ?? _defaultTitle(category),
    summary: _optionalString(data['summary']) ?? '',
    weekNumber: _optionalPositiveInt(payload['week_number']),
    totalWeeks: _optionalPositiveInt(payload['total_weeks']),
    sessionsPerDay:
        explicitSessionsPerDay ??
        (generatedSessionsPerDay != null && generatedSessionsPerDay > 0
            ? generatedSessionsPerDay
            : null),
    dailyTargetVolumeMl: _optionalPositiveInt(
      payload['daily_target_volume_ml'],
    ),
    todayVolumeMl: _optionalNonNegativeInt(payload['today_volume_ml']),
    weeklyTargetVolumeMl: _optionalPositiveInt(
      payload['weekly_target_volume_ml'],
    ),
    weeklyVolumeMl: _optionalNonNegativeInt(payload['weekly_volume_ml']),
    weeklyCompletedSessions: _optionalNonNegativeInt(
      payload['weekly_completed_sessions'],
    ),
    weeklyTotalSessions: _optionalPositiveInt(payload['weekly_total_sessions']),
    startDate: _optionalApiDate(data['starts_on']),
    endDate: _optionalApiDate(data['ends_on']),
    durationDays: _planDurationDays(data, payload),
    goal: _optionalString(payload['goal']),
    basisMode: _optionalString(basis['mode']),
    pumpingSessionsPerDay: pumpingSessions,
    breastfeedingAnchorsPerDay: breastfeedingAnchors,
  );
}

int? _planDurationDays(
  Map<String, Object?> data,
  Map<String, Object?> payload,
) {
  final explicit = _optionalPositiveInt(payload['duration_days']);
  if (explicit != null) return explicit;
  final start = _optionalApiDate(data['starts_on']);
  final end = _optionalApiDate(data['ends_on']);
  if (start == null || end == null || end.isBefore(start)) return null;
  return end.difference(start).inDays + 1;
}

PlanTaskState _planTaskState(String value) {
  return switch (value.trim().toLowerCase()) {
    'pending' => PlanTaskState.pending,
    'completed' => PlanTaskState.completed,
    'skipped' => PlanTaskState.skipped,
    _ => throw FormatException('Unsupported plan task state: $value.'),
  };
}

PlanSessionKind _planSessionKind(
  Map<String, Object?> payload,
  PlanCategory category,
) {
  final value = _optionalString(
    payload['record_type'] ??
        payload['task_type'] ??
        payload['activity_type'] ??
        payload['kind'],
  )?.toLowerCase();
  final explicit = switch (value) {
    'pump' || 'pumping' || 'breast_pumping' => PlanSessionKind.pumping,
    'feed' ||
    'feeding' ||
    'breastfeeding' ||
    'bottle' => PlanSessionKind.feeding,
    'pregnancy' || 'prenatal' => PlanSessionKind.pregnancy,
    'yoga' || 'recovery_yoga' => PlanSessionKind.yoga,
    'pelvic_floor' || 'pelvic-floor' => PlanSessionKind.pelvicFloor,
    _ => null,
  };
  if (explicit != null) return explicit;
  return switch (category) {
    PlanCategory.pregnancy => PlanSessionKind.pregnancy,
    PlanCategory.lactation => PlanSessionKind.pumping,
    PlanCategory.yoga => PlanSessionKind.yoga,
    PlanCategory.pelvicFloor => PlanSessionKind.pelvicFloor,
    PlanCategory.other => PlanSessionKind.general,
  };
}

_RawPlanSession? _rawSession(
  Map<String, Object?> data,
  Map<String, CarePlan> activePlans,
) {
  final planId = _optionalString(data['plan_id']);
  final plan = planId == null ? null : activePlans[planId];
  if (plan == null) return null;
  final payload = _objectMap(data['payload']);
  final date = _requiredString(data, 'task_date');
  final time = _requiredString(data, 'task_time');
  final parsed = DateTime.tryParse('${date}T$time:00');
  if (parsed == null) {
    throw const FormatException('Plan session has an invalid date or time.');
  }
  final state = _planTaskState(_requiredString(data, 'status'));
  return _RawPlanSession(
    id: _requiredString(data, 'id'),
    planId: plan.id,
    title: _requiredString(data, 'title'),
    scheduledAt: parsed,
    state: state,
    kind: _planSessionKind(payload, plan.category),
    valueLabel: _optionalString(payload['value_label']),
  );
}

class _RawPlanSession {
  const _RawPlanSession({
    required this.id,
    required this.planId,
    required this.title,
    required this.scheduledAt,
    required this.state,
    required this.kind,
    this.valueLabel,
  });

  final String id;
  final String planId;
  final String title;
  final DateTime scheduledAt;
  final PlanTaskState state;
  final PlanSessionKind kind;
  final String? valueLabel;
}

PlanCategory _category(String wireValue) {
  return switch (wireValue.trim().toLowerCase()) {
    'pregnancy' || 'birth_journey' => PlanCategory.pregnancy,
    'lactation' ||
    'breast_pumping' ||
    'milk_management' => PlanCategory.lactation,
    'yoga' || 'recovery_yoga' => PlanCategory.yoga,
    'pelvic_floor' || 'pelvic-floor' => PlanCategory.pelvicFloor,
    _ => PlanCategory.other,
  };
}

String _defaultTitle(PlanCategory category) => switch (category) {
  PlanCategory.pregnancy => 'Pregnancy Plan',
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

int? _optionalPositiveInt(Object? value) {
  final parsed = _integer(value);
  return parsed == null || parsed <= 0 ? null : parsed;
}

int? _optionalNonNegativeInt(Object? value) {
  final parsed = _integer(value);
  return parsed == null || parsed < 0 ? null : parsed;
}

DateTime? _optionalApiDate(Object? value) {
  final raw = _optionalString(value);
  if (raw == null) return null;
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return null;
  return _dateOnly(parsed);
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String _apiDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

String _apiTime(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';
