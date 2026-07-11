import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/status/domain/birth_journey_plan.dart';

const statusPlansEndpoint = '/v1/plans';
const statusPlanTasksEndpoint = '/v1/plans/tasks';

class BirthJourneyPlanApiRepository implements BirthJourneyPlanRepository {
  const BirthJourneyPlanApiRepository({required this.transport});

  final ApiJsonTransport transport;

  @override
  Future<BirthJourneyPlan?> fetchActivePlan() async {
    final response = await transport.getJson(
      statusPlansEndpoint,
      query: const {'status': 'active', 'limit': 50},
    );
    final values = response['items'] ?? response['plan_list'];
    if (values is! List) return null;
    for (final raw in values.whereType<Map>()) {
      final map = Map<String, Object?>.from(raw);
      final type = _text(map['plan_type'] ?? map['planType']);
      if (type != 'birth_journey') continue;
      return _plan(map);
    }
    return null;
  }

  @override
  Future<void> updateTodoCompletion({
    required String taskId,
    required bool completed,
  }) async {
    final mutations = _mutations();
    await mutations.patchJson(
      '$statusPlanTasksEndpoint/${Uri.encodeComponent(taskId.trim())}/completion',
      body: {'completed': completed},
    );
  }

  @override
  Future<void> deletePlan({required String planId}) async {
    await _mutations().deleteJson(
      '$statusPlansEndpoint/${Uri.encodeComponent(planId.trim())}',
    );
  }

  ApiJsonMutationTransport _mutations() {
    final value = transport;
    if (value is! ApiJsonMutationTransport) {
      throw UnsupportedError('Birth journey plans require mutation support.');
    }
    return value as ApiJsonMutationTransport;
  }
}

BirthJourneyPlan _plan(Map<String, Object?> map) {
  final payload = _map(map['payload']);
  final todoPlan = _map(payload['todo_plan'] ?? payload['todoPlan']);
  final rawPeriods = todoPlan['periods'];
  final periods = <BirthJourneyPeriod>[];
  if (rawPeriods is List) {
    for (var index = 0; index < rawPeriods.length; index += 1) {
      final raw = rawPeriods[index];
      if (raw is! Map) continue;
      final period = _period(Map<String, Object?>.from(raw), index);
      if (period.items.isNotEmpty) periods.add(period);
    }
  }
  final nextAction = _map(payload['next_action'] ?? payload['nextAction']);
  return BirthJourneyPlan(
    id: _id(map['id'] ?? map['plan_id'] ?? map['planId']),
    title: _text(map['title']).isEmpty ? '孕期计划' : _text(map['title']),
    summary: _text(map['summary']),
    status: _text(map['status']),
    periods: List<BirthJourneyPeriod>.unmodifiable(periods),
    nextActionText: _text(nextAction['send_text'] ?? nextAction['sendText']),
  );
}

BirthJourneyPeriod _period(Map<String, Object?> map, int index) {
  final rawItems = map['items'];
  final items = <BirthJourneyTodo>[];
  if (rawItems is List) {
    for (var itemIndex = 0; itemIndex < rawItems.length; itemIndex += 1) {
      final item = _todo(rawItems[itemIndex], itemIndex);
      if (item != null) items.add(item);
    }
  }
  final displayMode = _text(map['display_mode'] ?? map['displayMode']);
  final status = _text(map['status']);
  return BirthJourneyPeriod(
    id: _text(map['id']).isEmpty
        ? 'todo-period-${index + 1}'
        : _text(map['id']),
    title: _text(map['title']).isEmpty
        ? '阶段 ${index + 1}'
        : _text(map['title']),
    subtitle: _text(map['subtitle']),
    displayMode: displayMode.isEmpty
        ? (index == 0 ? 'expanded' : 'collapsed')
        : displayMode,
    status: status.isEmpty ? (index == 0 ? 'current' : 'upcoming') : status,
    items: List<BirthJourneyTodo>.unmodifiable(items),
  );
}

BirthJourneyTodo? _todo(Object? value, int index) {
  if (value is String) {
    final title = _truncate(value, 22);
    if (title.isEmpty) return null;
    return BirthJourneyTodo(
      id: _fallbackTodoId(index),
      title: title,
      priorityLabel: '',
      reason: '',
      steps: const <String>[],
      completed: false,
    );
  }
  if (value is! Map) return null;
  final map = Map<String, Object?>.from(value);
  final title = _truncate(map['title'], 22);
  if (title.isEmpty) return null;
  final normalized = _priorityAndReason(
    map['reason'],
    map['priority_label'] ?? map['priorityLabel'],
  );
  return BirthJourneyTodo(
    id: _text(map['id'] ?? map['source_item_id'] ?? map['sourceItemId']).isEmpty
        ? _fallbackTodoId(index)
        : _text(map['id'] ?? map['source_item_id'] ?? map['sourceItemId']),
    title: title,
    priorityLabel: normalized.priority,
    reason: normalized.reason,
    steps: _steps(map['steps']),
    completed: _completed(map['completed']),
    timeframe: _text(map['timeframe']),
  );
}

({String priority, String reason}) _priorityAndReason(
  Object? reasonValue,
  Object? priorityValue,
) {
  final explicitPriority = _text(priorityValue);
  final rawReason = _text(reasonValue);
  final match = RegExp(r'^(重要|建议)[｜|]\s*(.+)$').firstMatch(rawReason);
  return (
    priority: explicitPriority.isNotEmpty
        ? explicitPriority
        : (match?.group(1) ?? ''),
    reason: match?.group(2)?.trim() ?? rawReason,
  );
}

List<String> _steps(Object? value) {
  if (value is! List) return const <String>[];
  final result = <String>[];
  final seen = <String>{};
  for (final raw in value) {
    final step = _truncate(raw, 88);
    if (step.isEmpty || !seen.add(step)) continue;
    result.add(step);
    if (result.length == 6) break;
  }
  return List<String>.unmodifiable(result);
}

bool _completed(Object? value) {
  if (value == true) return true;
  if (value is num) return value != 0;
  if (value is! String) return false;
  return const {
    'true',
    '1',
    'yes',
    'done',
    'completed',
    '完成',
    '已完成',
  }.contains(value.trim().toLowerCase());
}

String _truncate(Object? value, int maxChars) {
  final text = _text(value);
  if (text.length <= maxChars) return text;
  final prefix = text
      .substring(0, maxChars - 1)
      .replaceFirst(RegExp(r'[，。；、,.\s]+$'), '');
  return '$prefix…';
}

String _fallbackTodoId(int index) {
  return 'todo_${(index + 1).toString().padLeft(2, '0')}';
}

Map<String, Object?> _map(Object? value) {
  return value is Map ? Map<String, Object?>.from(value) : const {};
}

String _id(Object? value) => value?.toString() ?? '';

String _text(Object? value) => value is String ? value.trim() : '';
