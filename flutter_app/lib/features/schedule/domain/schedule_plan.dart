abstract interface class ScheduleRepository {
  Future<ScheduleDayPlan> fetchDayPlan({required DateTime day});

  Future<ScheduleTask> createTask({
    String? planId,
    required DateTime day,
    required String time,
    required String title,
    String description = '',
    ScheduleTaskKind kind = ScheduleTaskKind.other,
    String? idempotencyKey,
  });

  Future<ScheduleTask> updateTask({
    required String taskId,
    required DateTime day,
    required String time,
    required String title,
    String? description,
  });

  Future<ScheduleTask> setTaskState({
    required String taskId,
    required ScheduleTaskState state,
  });

  Future<void> deleteTask({required String taskId});

  Future<ScheduleRecord> createPumpingRecord({
    required DateTime occurredAt,
    required int amountMl,
    int? durationSeconds,
    String? linkedTaskId,
    String? idempotencyKey,
  });

  Future<ScheduleRecord> createFeedingRecord({
    required DateTime occurredAt,
    int? amountMl,
    int? durationSeconds,
    String feedType = 'bottle',
    String? linkedTaskId,
    String? idempotencyKey,
  });

  Future<void> deleteRecord({required ScheduleRecord record});
}

enum ScheduleTaskState { pending, completed, skipped }

extension ScheduleTaskStateWire on ScheduleTaskState {
  String get wireValue => name;
}

enum ScheduleTaskKind { pumping, feeding, other }

extension ScheduleTaskKindWire on ScheduleTaskKind {
  String get wireValue => switch (this) {
    ScheduleTaskKind.pumping => 'pumping',
    ScheduleTaskKind.feeding => 'feeding',
    ScheduleTaskKind.other => 'other',
  };
}

enum ScheduleRecordKind { pumping, feeding }

class ScheduleDayPlan {
  const ScheduleDayPlan({
    this.day,
    this.tasks = const <ScheduleTask>[],
    this.records = const <ScheduleRecord>[],
    this.context,
    this.syncWarnings = const <String>[],
  });

  final DateTime? day;
  final List<ScheduleTask> tasks;
  final List<ScheduleRecord> records;
  final SchedulePlanContext? context;
  final List<String> syncWarnings;

  bool get isEmpty => tasks.isEmpty && records.isEmpty;

  int get completedTaskCount =>
      tasks.where((task) => task.state == ScheduleTaskState.completed).length;

  int get skippedTaskCount =>
      tasks.where((task) => task.state == ScheduleTaskState.skipped).length;

  int get pendingTaskCount =>
      tasks.where((task) => task.state == ScheduleTaskState.pending).length;

  List<ScheduleTimelineEntry> get timeline {
    final taskIds = tasks.map((task) => task.id).toSet();
    final linkedRecords = <String, List<ScheduleRecord>>{};
    for (final record in records) {
      final linkedTaskId = record.linkedTaskId;
      if (linkedTaskId != null && taskIds.contains(linkedTaskId)) {
        linkedRecords.putIfAbsent(linkedTaskId, () => []).add(record);
      }
    }
    final entries = <ScheduleTimelineEntry>[
      for (final task in tasks)
        ScheduleTimelineEntry.task(
          task,
          fallbackDay: day,
          linkedRecords: linkedRecords[task.id] ?? const [],
        ),
      for (final record in records)
        if (record.linkedTaskId == null ||
            !taskIds.contains(record.linkedTaskId))
          ScheduleTimelineEntry.record(record),
    ];
    entries.sort((left, right) {
      final timeOrder = left.occurredAt.compareTo(right.occurredAt);
      if (timeOrder != 0) return timeOrder;
      if (left.isTask == right.isTask) return left.id.compareTo(right.id);
      return left.isTask ? -1 : 1;
    });
    return List<ScheduleTimelineEntry>.unmodifiable(entries);
  }

  ScheduleDayPlan copyWith({
    DateTime? day,
    List<ScheduleTask>? tasks,
    List<ScheduleRecord>? records,
    SchedulePlanContext? context,
    List<String>? syncWarnings,
  }) {
    return ScheduleDayPlan(
      day: day ?? this.day,
      tasks: tasks ?? this.tasks,
      records: records ?? this.records,
      context: context ?? this.context,
      syncWarnings: syncWarnings ?? this.syncWarnings,
    );
  }
}

class SchedulePlanContext {
  const SchedulePlanContext({
    required this.id,
    required this.planType,
    required this.title,
    required this.summary,
    required this.status,
    required this.version,
    this.payload = const <String, Object?>{},
  });

  final String id;
  final String planType;
  final String title;
  final String summary;
  final String status;
  final int version;
  final Map<String, Object?> payload;

  String get stageLabel {
    final explicit = _nonEmptyString(
      payload['stage_label'] ?? payload['stageLabel'],
    );
    if (explicit != null) return explicit;

    final phase = _nonEmptyString(
      payload['phase'] ?? payload['stage'] ?? payload['care_phase'],
    );
    final postpartumWeek = _integer(
      payload['postpartum_week'] ?? payload['postpartumWeek'],
    );
    if (postpartumWeek != null && phase != null) {
      return '产后第$postpartumWeek周（$phase）';
    }
    if (postpartumWeek != null) return '产后第$postpartumWeek周';

    final pregnancyWeek = _integer(
      payload['pregnancy_week'] ?? payload['pregnancyWeek'],
    );
    if (pregnancyWeek != null && phase != null) {
      return '孕$pregnancyWeek周（$phase）';
    }
    if (pregnancyWeek != null) return '孕$pregnancyWeek周';
    return phase ?? summary;
  }
}

class ScheduleTask {
  const ScheduleTask({
    required this.id,
    required this.title,
    this.planId,
    this.description = '',
    this.kind = ScheduleTaskKind.other,
    ScheduleTaskState? state,
    bool completed = false,
    this.remindAt,
    this.payload = const <String, Object?>{},
  }) : state =
           state ??
           (completed
               ? ScheduleTaskState.completed
               : ScheduleTaskState.pending);

  final String id;
  final String? planId;
  final String title;
  final String description;
  final ScheduleTaskKind kind;
  final ScheduleTaskState state;
  final DateTime? remindAt;
  final Map<String, Object?> payload;

  bool get completed => state == ScheduleTaskState.completed;
  bool get skipped => state == ScheduleTaskState.skipped;

  ScheduleTask copyWith({
    String? id,
    String? planId,
    String? title,
    String? description,
    ScheduleTaskKind? kind,
    ScheduleTaskState? state,
    DateTime? remindAt,
    Map<String, Object?>? payload,
  }) {
    return ScheduleTask(
      id: id ?? this.id,
      planId: planId ?? this.planId,
      title: title ?? this.title,
      description: description ?? this.description,
      kind: kind ?? this.kind,
      state: state ?? this.state,
      remindAt: remindAt ?? this.remindAt,
      payload: payload ?? this.payload,
    );
  }
}

class ScheduleRecord {
  const ScheduleRecord({
    required this.id,
    required this.kind,
    required this.occurredAt,
    this.title = '',
    this.amountMl,
    this.durationSeconds,
    this.linkedTaskId,
    this.feedType,
  });

  final String id;
  final ScheduleRecordKind kind;
  final DateTime occurredAt;
  final String title;
  final int? amountMl;
  final int? durationSeconds;
  final String? linkedTaskId;
  final String? feedType;

  String get displayTitle {
    final normalizedTitle = title.trim();
    if (normalizedTitle.isNotEmpty) return normalizedTitle;
    return kind == ScheduleRecordKind.pumping ? '吸奶记录' : '喂养记录';
  }
}

class ScheduleTimelineEntry {
  const ScheduleTimelineEntry._({
    required this.id,
    required this.title,
    required this.occurredAt,
    required this.isTask,
    this.task,
    this.record,
    this.linkedRecords = const <ScheduleRecord>[],
    this.linkedTaskId,
  });

  factory ScheduleTimelineEntry.task(
    ScheduleTask task, {
    DateTime? fallbackDay,
    List<ScheduleRecord> linkedRecords = const <ScheduleRecord>[],
  }) {
    return ScheduleTimelineEntry._(
      id: task.id,
      title: task.title,
      occurredAt:
          task.remindAt ??
          fallbackDay ??
          DateTime.fromMillisecondsSinceEpoch(0),
      isTask: true,
      task: task,
      linkedRecords: List<ScheduleRecord>.unmodifiable(linkedRecords),
      linkedTaskId: task.id,
    );
  }

  factory ScheduleTimelineEntry.record(ScheduleRecord record) {
    return ScheduleTimelineEntry._(
      id: record.id,
      title: record.displayTitle,
      occurredAt: record.occurredAt,
      isTask: false,
      record: record,
      linkedTaskId: record.linkedTaskId,
    );
  }

  final String id;
  final String title;
  final DateTime occurredAt;
  final bool isTask;
  final ScheduleTask? task;
  final ScheduleRecord? record;
  final List<ScheduleRecord> linkedRecords;
  final String? linkedTaskId;
}

String? _nonEmptyString(Object? value) {
  if (value is! String) return null;
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

int? _integer(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value);
  return null;
}
