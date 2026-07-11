abstract interface class BirthJourneyPlanRepository {
  Future<BirthJourneyPlan?> fetchActivePlan();

  Future<void> updateTodoCompletion({
    required String taskId,
    required bool completed,
  });

  Future<void> deletePlan({required String planId});
}

class BirthJourneyPlan {
  const BirthJourneyPlan({
    required this.id,
    required this.title,
    required this.summary,
    required this.status,
    required this.periods,
    this.nextActionText = '',
  });

  final String id;
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
    this.timeframe = '',
  });

  final String id;
  final String title;
  final String priorityLabel;
  final String reason;
  final List<String> steps;
  final bool completed;
  final String timeframe;

  BirthJourneyTodo copyWith({bool? completed}) {
    return BirthJourneyTodo(
      id: id,
      title: title,
      priorityLabel: priorityLabel,
      reason: reason,
      steps: steps,
      completed: completed ?? this.completed,
      timeframe: timeframe,
    );
  }

  String get agentCompletionPrompt {
    final effectiveTitle = title.trim().isEmpty ? '孕期计划事项' : title.trim();
    return '我已完成【$effectiveTitle】，请基于这个事项继续追问需要补充的执行细节，并在需要时同步更新我的孕期日记';
  }
}
