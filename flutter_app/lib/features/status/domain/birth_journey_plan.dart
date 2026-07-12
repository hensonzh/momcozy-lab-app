import 'package:momcozy_flutter_app/features/pregnancy_plan/domain/pregnancy_plan.dart';

BirthJourneyPlan projectBirthJourneyPlan(PregnancyPlan plan) {
  if (plan.planType != 'pregnancy' || plan.status != 'active') {
    throw const FormatException('Pregnancy plan identity is invalid.');
  }
  final card = plan.card;
  if (card['card_type'] != 'birth_journey_plan_card') {
    throw const FormatException('Pregnancy plan card type is invalid.');
  }
  final cardJson = _requiredMap(card['card_json'], 'card_json');
  final todoPlan = _requiredMap(
    cardJson['todo_plan'] ?? cardJson['todoPlan'],
    'todo_plan',
  );
  final rawPeriods = todoPlan['periods'];
  if (rawPeriods is! List || rawPeriods.isEmpty) {
    throw const FormatException('Pregnancy plan periods are invalid.');
  }
  final periods = <BirthJourneyPeriod>[];
  for (var index = 0; index < rawPeriods.length; index += 1) {
    final raw = rawPeriods[index];
    if (raw is! Map) continue;
    final period = _period(Map<String, Object?>.from(raw), index);
    if (period != null) periods.add(period);
  }
  if (periods.isEmpty) {
    throw const FormatException('Pregnancy plan has no renderable periods.');
  }
  final nextAction = _map(cardJson['next_action'] ?? cardJson['nextAction']);
  return BirthJourneyPlan(
    id: plan.id,
    version: plan.version,
    title: plan.title.trim().isEmpty ? '孕期计划' : plan.title.trim(),
    summary: plan.summary.trim(),
    status: plan.status,
    periods: List<BirthJourneyPeriod>.unmodifiable(periods),
    nextActionText: _text(nextAction['send_text'] ?? nextAction['sendText']),
  );
}

class BirthJourneyPlan {
  const BirthJourneyPlan({
    required this.id,
    this.version = 0,
    required this.title,
    required this.summary,
    required this.status,
    required this.periods,
    this.nextActionText = '',
  });

  final String id;
  final int version;
  final String title;
  final String summary;
  final String status;
  final List<BirthJourneyPeriod> periods;
  final String nextActionText;

  bool get hasStructuredContent =>
      periods.any((period) => period.items.isNotEmpty);

  BirthJourneyPlan withTodoCompletion(String taskId, bool completed) {
    return BirthJourneyPlan(
      id: id,
      version: version,
      title: title,
      summary: summary,
      status: status,
      nextActionText: nextActionText,
      periods: periods
          .map((period) => period.withTodoCompletion(taskId, completed))
          .toList(growable: false),
    );
  }
}

class BirthJourneyPeriod {
  const BirthJourneyPeriod({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.displayMode,
    required this.status,
    required this.items,
  });

  final String id;
  final String title;
  final String subtitle;
  final String displayMode;
  final String status;
  final List<BirthJourneyTodo> items;

  bool get isCurrent => status == 'current';
  bool get isTerminal => displayMode == 'terminal' || status == 'terminal';
  bool get initiallyExpanded => displayMode == 'expanded' || isCurrent;

  BirthJourneyPeriod withTodoCompletion(String taskId, bool completed) {
    return BirthJourneyPeriod(
      id: id,
      title: title,
      subtitle: subtitle,
      displayMode: displayMode,
      status: status,
      items: items
          .map(
            (item) =>
                item.id == taskId ? item.copyWith(completed: completed) : item,
          )
          .toList(growable: false),
    );
  }
}

class BirthJourneyTodo {
  const BirthJourneyTodo({
    required this.id,
    required this.title,
    required this.priorityLabel,
    required this.reason,
    required this.steps,
    required this.completed,
    this.authoritativeItemId = '',
    this.timeframe = '',
  });

  final String id;
  final String title;
  final String priorityLabel;
  final String reason;
  final List<String> steps;
  final bool completed;
  final String authoritativeItemId;
  final String timeframe;

  BirthJourneyTodo copyWith({bool? completed}) {
    return BirthJourneyTodo(
      id: id,
      title: title,
      priorityLabel: priorityLabel,
      reason: reason,
      steps: steps,
      completed: completed ?? this.completed,
      authoritativeItemId: authoritativeItemId,
      timeframe: timeframe,
    );
  }

  String get agentCompletionPrompt {
    final effectiveTitle = title.trim().isEmpty ? '孕期计划事项' : title.trim();
    return '我已完成【$effectiveTitle】，请基于这个事项继续追问需要补充的执行细节，并在需要时同步更新我的孕期日记';
  }

  bool get canMutate => authoritativeItemId.isNotEmpty;
}

BirthJourneyPeriod? _period(Map<String, Object?> map, int index) {
  final rawItems = map['items'];
  if (rawItems is! List || rawItems.isEmpty) return null;
  final items = <BirthJourneyTodo>[];
  for (var itemIndex = 0; itemIndex < rawItems.length; itemIndex += 1) {
    final item = _todo(rawItems[itemIndex], itemIndex);
    if (item != null) items.add(item);
  }
  if (items.isEmpty) return null;
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
    if (title.isEmpty) {
      return null;
    }
    return BirthJourneyTodo(
      id: _fallbackTodoId(index),
      title: title,
      priorityLabel: '',
      reason: '',
      steps: const <String>[],
      completed: false,
    );
  }
  if (value is! Map) {
    return null;
  }
  final map = Map<String, Object?>.from(value);
  final title = _truncate(map['title'], 22);
  if (title.isEmpty) {
    return null;
  }
  final normalized = _priorityAndReason(
    map['reason'],
    map['priority_label'] ?? map['priorityLabel'],
  );
  final authoritativeItemId = _text(map['item_id'] ?? map['itemId']);
  final rawId = authoritativeItemId.isNotEmpty
      ? authoritativeItemId
      : _text(map['id'] ?? map['source_item_id'] ?? map['sourceItemId']);
  return BirthJourneyTodo(
    id: rawId.isEmpty ? _fallbackTodoId(index) : rawId,
    title: title,
    priorityLabel: normalized.priority,
    reason: normalized.reason,
    steps: _steps(map['steps']),
    completed: _completed(map['completed']),
    authoritativeItemId: authoritativeItemId,
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

Map<String, Object?> _requiredMap(Object? value, String field) {
  if (value is! Map) {
    throw FormatException('Pregnancy plan $field is invalid.');
  }
  return Map<String, Object?>.from(value);
}

Map<String, Object?> _map(Object? value) {
  return value is Map ? Map<String, Object?>.from(value) : const {};
}

String _text(Object? value) => value is String ? value.trim() : '';
