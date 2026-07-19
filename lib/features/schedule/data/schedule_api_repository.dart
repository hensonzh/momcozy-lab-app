import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/schedule/domain/schedule_plan.dart';

const schedulePlansEndpoint = '/v1/plans';
const scheduleTasksEndpoint = '/v1/plans/tasks';
const scheduleDayPlanEndpoint = '$scheduleTasksEndpoint/list';
const scheduleFeedingRecordsEndpoint = '/v1/records/feeding';
const schedulePumpingRecordsEndpoint = '/v1/records/pumping';

class ScheduleApiRepository implements ScheduleRepository {
  const ScheduleApiRepository({required this.transport});

  final ApiJsonTransport transport;

  @override
  Future<ScheduleDayPlan> fetchDayPlan({required DateTime day}) async {
    final range = _dayRange(day);
    final resources = await Future.wait<_ScheduleResourceResponse>([
      _loadResource(
        warning: '任务同步暂时不可用',
        load: () => transport.getJson(
          scheduleDayPlanEndpoint,
          query: {'task_date': _apiDate(day), 'limit': 100},
        ),
      ),
      _loadResource(
        warning: '计划上下文同步暂时不可用',
        load: () => transport.getJson(
          schedulePlansEndpoint,
          query: {
            'plan_type': 'milk_management',
            'status': 'active',
            'limit': 20,
          },
        ),
      ),
      _loadResource(
        warning: '喂养记录同步暂时不可用',
        load: () => transport.getJson(
          scheduleFeedingRecordsEndpoint,
          query: {
            'start_at': range.start.toIso8601String(),
            'end_at': range.end.toIso8601String(),
            'limit': 100,
          },
        ),
      ),
      _loadResource(
        warning: '吸奶记录同步暂时不可用',
        load: () => transport.getJson(
          schedulePumpingRecordsEndpoint,
          query: {
            'start_at': range.start.toIso8601String(),
            'end_at': range.end.toIso8601String(),
            'limit': 100,
          },
        ),
      ),
    ]);
    final successfulResources = resources.where(
      (resource) => resource.response != null,
    );
    if (successfulResources.isEmpty) {
      throw resources.first.error!;
    }
    final tasks = _items(
      resources[0].response ?? const {'items': <Object?>[]},
      endpoint: scheduleDayPlanEndpoint,
    ).map(_task).toList(growable: false);
    final contexts = _items(
      resources[1].response ?? const {'items': <Object?>[]},
      endpoint: schedulePlansEndpoint,
      allowMissing: true,
    ).map(_context).toList(growable: false);
    final feedings = _items(
      resources[2].response ?? const {'items': <Object?>[]},
      endpoint: scheduleFeedingRecordsEndpoint,
      allowMissing: true,
    ).map(_feedingRecord);
    final pumpings = _items(
      resources[3].response ?? const {'items': <Object?>[]},
      endpoint: schedulePumpingRecordsEndpoint,
      allowMissing: true,
    ).map(_pumpingRecord);

    return ScheduleDayPlan(
      day: _dateOnly(day),
      tasks: tasks,
      records: [...feedings, ...pumpings],
      context: _selectContext(contexts, tasks),
      syncWarnings: [
        for (final resource in resources)
          if (resource.response == null) resource.warning,
      ],
    );
  }

  Future<_ScheduleResourceResponse> _loadResource({
    required String warning,
    required Future<Map<String, Object?>> Function() load,
  }) async {
    try {
      return _ScheduleResourceResponse.success(
        warning: warning,
        response: await load(),
      );
    } on ApiHttpException catch (error) {
      if (error.statusCode < 500 || error.statusCode > 599) rethrow;
      return _ScheduleResourceResponse.failure(warning: warning, error: error);
    }
  }

  @override
  Future<ScheduleTask> createTask({
    String? planId,
    required DateTime day,
    required String time,
    required String title,
    String description = '',
    ScheduleTaskKind kind = ScheduleTaskKind.other,
    String? idempotencyKey,
  }) async {
    final response = await transport.postJson(
      scheduleTasksEndpoint,
      body: {
        if (_notBlank(planId)) 'plan_id': planId!.trim(),
        'task_date': _apiDate(day),
        'task_time': _requireTime(time),
        'title': _requireText(title, field: 'title'),
        'description': description.trim(),
        'payload': {'task_type': kind.wireValue},
      },
      headers: _idempotencyHeaders(idempotencyKey),
    );
    return _task(response);
  }

  @override
  Future<ScheduleTask> updateTask({
    required String taskId,
    required DateTime day,
    required String time,
    required String title,
    String? description,
  }) async {
    final mutations = _mutations();
    final response = await mutations.patchJson(
      '$scheduleTasksEndpoint/${Uri.encodeComponent(_requireId(taskId))}',
      body: {
        'task_date': _apiDate(day),
        'task_time': _requireTime(time),
        'title': _requireText(title, field: 'title'),
        if (description != null) 'description': description.trim(),
      },
    );
    return _task(response);
  }

  @override
  Future<ScheduleTask> setTaskState({
    required String taskId,
    required ScheduleTaskState state,
  }) async {
    final response = await _mutations().patchJson(
      '$scheduleTasksEndpoint/${Uri.encodeComponent(_requireId(taskId))}/state',
      body: {'state': state.wireValue},
    );
    return _task(response);
  }

  @override
  Future<void> deleteTask({required String taskId}) async {
    await _mutations().deleteJson(
      '$scheduleTasksEndpoint/${Uri.encodeComponent(_requireId(taskId))}',
    );
  }

  @override
  Future<ScheduleRecord> createPumpingRecord({
    required DateTime occurredAt,
    required int amountMl,
    int? durationSeconds,
    String? linkedTaskId,
    String? idempotencyKey,
  }) async {
    final response = await transport.postJson(
      schedulePumpingRecordsEndpoint,
      body: {
        'pump_start_time': occurredAt.toUtc().toIso8601String(),
        'milk_volume_ml': _requireAmount(amountMl),
        'duration_seconds': ?durationSeconds,
        if (_notBlank(linkedTaskId)) 'plan_task_id': linkedTaskId!.trim(),
        'source': 'manual',
        'title': '吸奶补录',
      },
      headers: _idempotencyHeaders(idempotencyKey),
    );
    return _pumpingRecord(response);
  }

  @override
  Future<ScheduleRecord> createFeedingRecord({
    required DateTime occurredAt,
    int? amountMl,
    int? durationSeconds,
    String feedType = 'bottle',
    String? linkedTaskId,
    String? idempotencyKey,
  }) async {
    final response = await transport.postJson(
      scheduleFeedingRecordsEndpoint,
      body: {
        'feed_time': occurredAt.toUtc().toIso8601String(),
        'feed_type': _requireText(feedType, field: 'feed_type'),
        if (amountMl != null) 'volume_ml': _requireAmount(amountMl),
        'duration_seconds': ?durationSeconds,
        if (_notBlank(linkedTaskId)) 'plan_task_id': linkedTaskId!.trim(),
        'title': '喂养记录',
      },
      headers: _idempotencyHeaders(idempotencyKey),
    );
    return _feedingRecord(response);
  }

  @override
  Future<void> deleteRecord({required ScheduleRecord record}) async {
    final endpoint = record.kind == ScheduleRecordKind.pumping
        ? schedulePumpingRecordsEndpoint
        : scheduleFeedingRecordsEndpoint;
    await _mutations().deleteJson(
      '$endpoint/${Uri.encodeComponent(_requireId(record.id))}',
    );
  }

  ApiJsonMutationTransport _mutations() {
    final mutations = transport;
    if (mutations is! ApiJsonMutationTransport) {
      throw UnsupportedError(
        'Schedule mutations require JSON mutation support.',
      );
    }
    return mutations as ApiJsonMutationTransport;
  }
}

class _ScheduleResourceResponse {
  const _ScheduleResourceResponse.success({
    required this.warning,
    required Map<String, Object?> this.response,
  }) : error = null;

  const _ScheduleResourceResponse.failure({
    required this.warning,
    required Object this.error,
  }) : response = null;

  final String warning;
  final Map<String, Object?>? response;
  final Object? error;
}

List<Map<String, Object?>> _items(
  Map<String, Object?> response, {
  required String endpoint,
  bool allowMissing = false,
}) {
  final rawItems = response['items'];
  if (rawItems == null && allowMissing) return const [];
  if (rawItems is! List) {
    throw FormatException('$endpoint response must contain an items list.');
  }
  return rawItems
      .map((item) {
        if (item is! Map) {
          throw FormatException('$endpoint items must be JSON objects.');
        }
        return Map<String, Object?>.from(item);
      })
      .toList(growable: false);
}

ScheduleTask _task(Map<String, Object?> data) {
  final id = _requiredString(data, 'id');
  final title = _requiredString(data, 'title');
  final payload = _objectMap(data['payload']);
  final taskDate = _optionalString(data['task_date']);
  final taskTime = _optionalString(data['task_time']);
  return ScheduleTask(
    id: id,
    planId: _optionalString(data['plan_id']),
    title: title,
    description: _optionalString(data['description']) ?? '',
    state: _taskState(_requiredString(data, 'status')),
    kind: _taskKind(payload, title),
    remindAt: _localDateTime(taskDate, taskTime),
    payload: payload,
  );
}

SchedulePlanContext _context(Map<String, Object?> data) {
  return SchedulePlanContext(
    id: _requiredString(data, 'id'),
    planType: _requiredString(data, 'plan_type'),
    title: _requiredString(data, 'title'),
    summary: _optionalString(data['summary']) ?? '',
    status: _requiredString(data, 'status'),
    version: _integer(data['version']) ?? 1,
    payload: _objectMap(data['payload']),
  );
}

SchedulePlanContext? _selectContext(
  List<SchedulePlanContext> contexts,
  List<ScheduleTask> tasks,
) {
  final milkContexts = contexts
      .where((context) => context.planType == 'milk_management')
      .toList(growable: false);
  if (milkContexts.isEmpty) return null;
  final linkedPlanIds = tasks
      .map((task) => task.planId)
      .whereType<String>()
      .toSet();
  for (final context in milkContexts) {
    if (linkedPlanIds.contains(context.id)) return context;
  }
  if (linkedPlanIds.isNotEmpty) return null;
  return milkContexts.first;
}

ScheduleRecord _feedingRecord(Map<String, Object?> data) {
  return ScheduleRecord(
    id: _requiredString(data, 'id'),
    kind: ScheduleRecordKind.feeding,
    occurredAt: _requiredDateTime(data, 'feed_time'),
    title: _optionalString(data['title']) ?? '',
    amountMl: _integer(data['volume_ml']),
    durationSeconds: _integer(data['duration_seconds']),
    linkedTaskId: _optionalString(data['plan_task_id']),
    feedType: _optionalString(data['feed_type']),
  );
}

ScheduleRecord _pumpingRecord(Map<String, Object?> data) {
  return ScheduleRecord(
    id: _requiredString(data, 'id'),
    kind: ScheduleRecordKind.pumping,
    occurredAt: _requiredDateTime(data, 'pump_start_time'),
    title: _optionalString(data['title']) ?? '',
    amountMl: _integer(data['milk_volume_ml']),
    durationSeconds: _integer(data['duration_seconds']),
    linkedTaskId: _optionalString(data['plan_task_id']),
  );
}

ScheduleTaskState _taskState(String value) {
  return switch (value.trim().toLowerCase()) {
    'pending' => ScheduleTaskState.pending,
    'completed' || 'done' => ScheduleTaskState.completed,
    'skipped' => ScheduleTaskState.skipped,
    _ => throw FormatException('Unsupported schedule task state: $value'),
  };
}

ScheduleTaskKind _taskKind(Map<String, Object?> payload, String title) {
  final explicit = _optionalString(
    payload['task_type'] ??
        payload['record_type'] ??
        payload['type'] ??
        payload['kind'],
  )?.trim().toLowerCase();
  if (<String>{
    'pump',
    'pumping',
    'breast_pump',
    '吸奶',
    '泵奶',
  }.contains(explicit)) {
    return ScheduleTaskKind.pumping;
  }
  if (<String>{
    'feed',
    'feeding',
    'breastfeed',
    '喂养',
    '喂奶',
  }.contains(explicit)) {
    return ScheduleTaskKind.feeding;
  }
  if (title.contains('吸奶') || title.contains('泵奶')) {
    return ScheduleTaskKind.pumping;
  }
  if (title.contains('喂养') || title.contains('喂奶')) {
    return ScheduleTaskKind.feeding;
  }
  return ScheduleTaskKind.other;
}

({DateTime start, DateTime end}) _dayRange(DateTime day) {
  if (day.isUtc) {
    final start = DateTime.utc(day.year, day.month, day.day);
    return (start: start, end: start.add(const Duration(days: 1)));
  }
  final localStart = DateTime(day.year, day.month, day.day);
  return (
    start: localStart.toUtc(),
    end: DateTime(day.year, day.month, day.day + 1).toUtc(),
  );
}

DateTime _dateOnly(DateTime day) => day.isUtc
    ? DateTime.utc(day.year, day.month, day.day)
    : DateTime(day.year, day.month, day.day);

DateTime? _localDateTime(String? date, String? time) {
  if (date == null || time == null) return null;
  final parsed = DateTime.tryParse('${date}T$time');
  if (parsed == null) {
    throw FormatException('Invalid task date/time: $date $time');
  }
  return parsed;
}

DateTime _requiredDateTime(Map<String, Object?> data, String field) {
  final raw = _requiredString(data, field);
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) {
    throw FormatException('$field must be an ISO-8601 date-time.');
  }
  return parsed.toLocal();
}

Map<String, Object?> _objectMap(Object? value) {
  if (value == null) return const <String, Object?>{};
  if (value is! Map) throw const FormatException('Expected a JSON object.');
  return Map<String, Object?>.from(value);
}

String _requiredString(Map<String, Object?> data, String field) {
  return _requireText(_optionalString(data[field]) ?? '', field: field);
}

String? _optionalString(Object? value) => value is String ? value : null;

String _requireText(String value, {required String field}) {
  final normalized = value.trim();
  if (normalized.isEmpty) throw FormatException('$field must not be empty.');
  return normalized;
}

String _requireId(String value) => _requireText(value, field: 'id');

String _requireTime(String value) {
  final normalized = value.trim();
  final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(normalized);
  final hour = match == null ? null : int.tryParse(match.group(1)!);
  final minute = match == null ? null : int.tryParse(match.group(2)!);
  if (hour == null || minute == null || hour > 23 || minute > 59) {
    throw const FormatException('time must use HH:mm.');
  }
  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

int _requireAmount(int amountMl) {
  if (amountMl <= 0) {
    throw const FormatException('amountMl must be greater than zero.');
  }
  return amountMl;
}

int? _integer(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return double.tryParse(value)?.round();
  return null;
}

bool _notBlank(String? value) => value?.trim().isNotEmpty == true;

Map<String, String> _idempotencyHeaders(String? key) {
  return {if (_notBlank(key)) 'Idempotency-Key': key!.trim()};
}

String _apiDate(DateTime day) {
  return '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';
}
