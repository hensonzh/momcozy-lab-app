import 'package:flutter/foundation.dart';
import 'package:app/core/network/api_json_transport.dart';
import 'package:app/features/schedule/domain/schedule_plan.dart';

enum ScheduleLoadPhase { loading, success, empty, error }

class ScheduleDashboardState {
  const ScheduleDashboardState({
    required this.phase,
    required this.selectedDay,
    required this.displayAnchor,
    this.snapshot,
    this.loadError,
    this.mutationError,
    this.isMutating = false,
  });

  final ScheduleLoadPhase phase;
  final DateTime selectedDay;
  final DateTime displayAnchor;
  final ScheduleDayPlan? snapshot;
  final String? loadError;
  final String? mutationError;
  final bool isMutating;

  ScheduleTask? get nextPendingTask {
    final pending = snapshot?.tasks
        .where((task) => task.state == ScheduleTaskState.pending)
        .toList(growable: false);
    if (pending == null || pending.isEmpty) return null;
    final sorted = [...pending]
      ..sort((left, right) {
        final leftTime = left.remindAt;
        final rightTime = right.remindAt;
        if (leftTime == null && rightTime == null) {
          return left.id.compareTo(right.id);
        }
        if (leftTime == null) return 1;
        if (rightTime == null) return -1;
        return leftTime.compareTo(rightTime);
      });
    return sorted.first;
  }
}

class ScheduleDashboardController extends ChangeNotifier {
  ScheduleDashboardController({
    required this.repository,
    required DateTime initialDay,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now,
       _state = ScheduleDashboardState(
         phase: ScheduleLoadPhase.loading,
         selectedDay: _dateOnly(initialDay),
         displayAnchor: _dateOnly(initialDay),
       );

  final ScheduleRepository repository;
  final DateTime Function() now;
  ScheduleDashboardState _state;
  int _loadGeneration = 0;
  int _mutationGeneration = 0;
  bool _mutationInFlight = false;
  final Map<String, ScheduleDayPlan> _dayCache = <String, ScheduleDayPlan>{};
  final Map<String, int> _dayFetchGenerations = <String, int>{};

  ScheduleDashboardState get state => _state;
  DateTime get today => _dateOnly(now());

  List<ScheduleTask> get reminderTasks {
    final current = now();
    final unique = <String, ScheduleTask>{};
    for (final snapshot in _dayCache.values) {
      for (final task in snapshot.tasks) {
        final remindAt = task.remindAt;
        if (task.state != ScheduleTaskState.pending ||
            remindAt == null ||
            !remindAt.isAfter(current)) {
          continue;
        }
        unique[task.id] = task;
      }
    }
    final tasks = unique.values.toList(growable: false)
      ..sort((left, right) {
        final timeOrder = left.remindAt!.compareTo(right.remindAt!);
        return timeOrder != 0 ? timeOrder : left.id.compareTo(right.id);
      });
    return List<ScheduleTask>.unmodifiable(tasks);
  }

  Future<bool> warmReminderWindow({int days = 7}) async {
    final boundedDays = days.clamp(1, 30);
    var succeeded = true;
    for (var offset = 0; offset < boundedDays; offset += 1) {
      final refreshed = await refreshDay(today.add(Duration(days: offset)));
      succeeded = refreshed && succeeded;
    }
    return succeeded;
  }

  Future<void> load() async {
    final generation = ++_loadGeneration;
    final selectedDay = _state.selectedDay;
    final selectedDayKey = _dayKey(selectedDay);
    final dayFetchGeneration = _nextDayFetchGeneration(selectedDayKey);
    final cached = _dayCache[selectedDayKey];
    _state = ScheduleDashboardState(
      phase: ScheduleLoadPhase.loading,
      selectedDay: selectedDay,
      displayAnchor: _state.displayAnchor,
      snapshot: cached,
      isMutating: _mutationInFlight,
    );
    notifyListeners();
    try {
      final snapshot = await repository.fetchDayPlan(day: selectedDay);
      if (_dayFetchGenerations[selectedDayKey] != dayFetchGeneration) return;
      _dayCache[selectedDayKey] = snapshot;
      if (generation != _loadGeneration) return;
      _state = ScheduleDashboardState(
        phase: snapshot.isEmpty
            ? ScheduleLoadPhase.empty
            : ScheduleLoadPhase.success,
        selectedDay: selectedDay,
        displayAnchor: _state.displayAnchor,
        snapshot: snapshot,
        loadError: snapshot.syncWarnings.isEmpty
            ? null
            : snapshot.syncWarnings.join('；'),
        isMutating: _mutationInFlight,
      );
    } catch (error) {
      if (_dayFetchGenerations[selectedDayKey] != dayFetchGeneration) return;
      if (generation != _loadGeneration) return;
      _state = ScheduleDashboardState(
        phase: ScheduleLoadPhase.error,
        selectedDay: selectedDay,
        displayAnchor: _state.displayAnchor,
        snapshot: cached,
        loadError: _errorMessage(error),
        isMutating: _mutationInFlight,
      );
    }
    notifyListeners();
  }

  Future<void> selectDay(DateTime day) async {
    final selected = _dateOnly(day);
    if (_dayKey(selected) == _dayKey(_state.selectedDay)) {
      final displayAnchor = _isInDisplayWindow(_state.displayAnchor, selected)
          ? _state.displayAnchor
          : selected;
      if (_dayKey(displayAnchor) == _dayKey(_state.displayAnchor)) return;
      _state = ScheduleDashboardState(
        phase: _state.phase,
        selectedDay: _state.selectedDay,
        displayAnchor: displayAnchor,
        snapshot: _state.snapshot,
        loadError: _state.loadError,
        mutationError: _state.mutationError,
        isMutating: _state.isMutating,
      );
      notifyListeners();
      return;
    }
    final cached = _dayCache[_dayKey(selected)];
    final displayAnchor = _isInDisplayWindow(_state.displayAnchor, selected)
        ? _state.displayAnchor
        : selected;
    _state = ScheduleDashboardState(
      phase: cached == null
          ? ScheduleLoadPhase.loading
          : cached.isEmpty
          ? ScheduleLoadPhase.empty
          : ScheduleLoadPhase.success,
      selectedDay: selected,
      displayAnchor: displayAnchor,
      snapshot: cached,
      isMutating: _mutationInFlight,
    );
    notifyListeners();
    await load();
  }

  Future<bool> refreshDay(DateTime day) async {
    final refreshDay = _dateOnly(day);
    final refreshDayKey = _dayKey(refreshDay);
    final generation = _nextDayFetchGeneration(refreshDayKey);
    try {
      final snapshot = await repository.fetchDayPlan(day: refreshDay);
      if (_dayFetchGenerations[refreshDayKey] != generation) return false;
      _dayCache[refreshDayKey] = snapshot;
      if (_dayKey(_state.selectedDay) == refreshDayKey) {
        _state = ScheduleDashboardState(
          phase: snapshot.isEmpty
              ? ScheduleLoadPhase.empty
              : ScheduleLoadPhase.success,
          selectedDay: _state.selectedDay,
          displayAnchor: _state.displayAnchor,
          snapshot: snapshot,
          loadError: snapshot.syncWarnings.isEmpty
              ? null
              : snapshot.syncWarnings.join('；'),
          mutationError: _state.mutationError,
          isMutating: _mutationInFlight,
        );
        notifyListeners();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  void browseWeek(int direction) {
    if (direction == 0) return;
    _state = ScheduleDashboardState(
      phase: _state.phase,
      selectedDay: _state.selectedDay,
      displayAnchor: _state.displayAnchor.add(Duration(days: 7 * direction)),
      snapshot: _state.snapshot,
      loadError: _state.loadError,
      mutationError: _state.mutationError,
      isMutating: _state.isMutating,
    );
    notifyListeners();
  }

  Future<ScheduleTask?> createTask({
    String? planId,
    required String time,
    required String title,
    String description = '',
    ScheduleTaskKind kind = ScheduleTaskKind.other,
    String? idempotencyKey,
  }) {
    return _mutate<ScheduleTask>(
      action: (mutationDay) => repository.createTask(
        planId: planId,
        day: mutationDay,
        time: time,
        title: title,
        description: description,
        kind: kind,
        idempotencyKey: idempotencyKey,
      ),
      apply: (task, snapshot) => _replaceTask(snapshot, task),
    );
  }

  Future<ScheduleTask?> updateTask({
    required String taskId,
    required String time,
    required String title,
    String? description,
  }) {
    return _mutate<ScheduleTask>(
      action: (mutationDay) => repository.updateTask(
        taskId: taskId,
        day: mutationDay,
        time: time,
        title: title,
        description: description,
      ),
      apply: (task, snapshot) => _replaceTask(snapshot, task),
    );
  }

  Future<ScheduleTask?> setTaskState(
    String taskId,
    ScheduleTaskState taskState,
  ) {
    return _mutate<ScheduleTask>(
      action: (_) => repository.setTaskState(taskId: taskId, state: taskState),
      apply: (task, snapshot) => _replaceTask(snapshot, task),
    );
  }

  Future<bool> deleteTask(String taskId) async {
    final result = await _mutate<bool>(
      action: (_) async {
        await repository.deleteTask(taskId: taskId);
        return true;
      },
      apply: (_, snapshot) => snapshot.copyWith(
        tasks: snapshot.tasks
            .where((task) => task.id != taskId)
            .toList(growable: false),
      ),
    );
    return result ?? false;
  }

  Future<ScheduleRecord?> createPumpingRecord({
    required DateTime occurredAt,
    required int amountMl,
    int? durationSeconds,
    String? linkedTaskId,
    String? idempotencyKey,
  }) {
    return _mutate<ScheduleRecord>(
      action: (_) => repository.createPumpingRecord(
        occurredAt: occurredAt,
        amountMl: amountMl,
        durationSeconds: durationSeconds,
        linkedTaskId: linkedTaskId,
        idempotencyKey: idempotencyKey,
      ),
      apply: (record, snapshot) =>
          _appendRecordAndCompleteLinkedTask(snapshot, record),
    );
  }

  Future<ScheduleRecord?> createFeedingRecord({
    required DateTime occurredAt,
    int? amountMl,
    int? durationSeconds,
    String feedType = 'bottle',
    String? linkedTaskId,
    String? idempotencyKey,
  }) {
    return _mutate<ScheduleRecord>(
      action: (_) => repository.createFeedingRecord(
        occurredAt: occurredAt,
        amountMl: amountMl,
        durationSeconds: durationSeconds,
        feedType: feedType,
        linkedTaskId: linkedTaskId,
        idempotencyKey: idempotencyKey,
      ),
      apply: (record, snapshot) =>
          _appendRecordAndCompleteLinkedTask(snapshot, record),
    );
  }

  Future<bool> deleteRecord(ScheduleRecord record) async {
    final result = await _mutate<bool>(
      action: (_) async {
        await repository.deleteRecord(record: record);
        return true;
      },
      apply: (_, snapshot) => snapshot.copyWith(
        records: snapshot.records
            .where((item) => item.id != record.id)
            .toList(growable: false),
      ),
    );
    return result ?? false;
  }

  void clearMutationError() {
    if (_state.mutationError == null) return;
    _state = ScheduleDashboardState(
      phase: _state.phase,
      selectedDay: _state.selectedDay,
      displayAnchor: _state.displayAnchor,
      snapshot: _state.snapshot,
      loadError: _state.loadError,
      isMutating: _state.isMutating,
    );
    notifyListeners();
  }

  Future<T?> _mutate<T>({
    required Future<T> Function(DateTime mutationDay) action,
    required ScheduleDayPlan Function(T value, ScheduleDayPlan snapshot) apply,
  }) async {
    if (_mutationInFlight) return null;
    final generation = ++_mutationGeneration;
    final mutationDay = _state.selectedDay;
    final mutationDayKey = _dayKey(mutationDay);
    final initialSnapshot = _dayCache[mutationDayKey] ?? _state.snapshot;
    _mutationInFlight = true;
    _state = ScheduleDashboardState(
      phase: _state.phase,
      selectedDay: _state.selectedDay,
      displayAnchor: _state.displayAnchor,
      snapshot: _state.snapshot,
      loadError: _state.loadError,
      isMutating: true,
    );
    notifyListeners();
    try {
      final value = await action(mutationDay);
      if (generation != _mutationGeneration) return null;
      final current =
          _dayCache[mutationDayKey] ??
          initialSnapshot ??
          ScheduleDayPlan(day: mutationDay);
      final snapshot = apply(value, current);
      _dayCache[mutationDayKey] = snapshot;
      _mutationInFlight = false;
      if (_dayKey(_state.selectedDay) == mutationDayKey) {
        _state = ScheduleDashboardState(
          phase: snapshot.isEmpty
              ? ScheduleLoadPhase.empty
              : ScheduleLoadPhase.success,
          selectedDay: _state.selectedDay,
          displayAnchor: _state.displayAnchor,
          snapshot: snapshot,
        );
      } else {
        _state = _copyCurrentState(isMutating: false);
      }
      notifyListeners();
      return value;
    } catch (error) {
      if (generation != _mutationGeneration) return null;
      _mutationInFlight = false;
      final mutationError = _errorMessage(error);
      if (_dayKey(_state.selectedDay) == mutationDayKey) {
        final snapshot = _dayCache[mutationDayKey] ?? initialSnapshot;
        _state = ScheduleDashboardState(
          phase: snapshot == null
              ? _state.phase
              : snapshot.isEmpty
              ? ScheduleLoadPhase.empty
              : ScheduleLoadPhase.success,
          selectedDay: _state.selectedDay,
          displayAnchor: _state.displayAnchor,
          snapshot: snapshot,
          loadError: _state.loadError,
          mutationError: mutationError,
        );
      } else {
        _state = _copyCurrentState(isMutating: false);
      }
      notifyListeners();
      await _reconcileMutationFailure(
        mutationDay: mutationDay,
        mutationDayKey: mutationDayKey,
        mutationGeneration: generation,
        mutationError: mutationError,
      );
      return null;
    }
  }

  Future<void> _reconcileMutationFailure({
    required DateTime mutationDay,
    required String mutationDayKey,
    required int mutationGeneration,
    required String mutationError,
  }) async {
    final fetchGeneration = _nextDayFetchGeneration(mutationDayKey);
    try {
      final authoritative = await repository.fetchDayPlan(day: mutationDay);
      if (mutationGeneration != _mutationGeneration ||
          _dayFetchGenerations[mutationDayKey] != fetchGeneration) {
        return;
      }
      _dayCache[mutationDayKey] = authoritative;
      if (_dayKey(_state.selectedDay) != mutationDayKey) return;
      _state = ScheduleDashboardState(
        phase: authoritative.isEmpty
            ? ScheduleLoadPhase.empty
            : ScheduleLoadPhase.success,
        selectedDay: _state.selectedDay,
        displayAnchor: _state.displayAnchor,
        snapshot: authoritative,
        mutationError: mutationError,
      );
      notifyListeners();
    } catch (_) {
      // The original mutation error remains visible and the last known cache
      // remains intact when reconciliation is also unavailable.
    }
  }

  int _nextDayFetchGeneration(String dayKey) {
    final next = (_dayFetchGenerations[dayKey] ?? 0) + 1;
    _dayFetchGenerations[dayKey] = next;
    return next;
  }

  ScheduleDashboardState _copyCurrentState({required bool isMutating}) {
    return ScheduleDashboardState(
      phase: _state.phase,
      selectedDay: _state.selectedDay,
      displayAnchor: _state.displayAnchor,
      snapshot: _state.snapshot,
      loadError: _state.loadError,
      mutationError: _state.mutationError,
      isMutating: isMutating,
    );
  }
}

ScheduleDayPlan _replaceTask(ScheduleDayPlan snapshot, ScheduleTask task) {
  final tasks = [...snapshot.tasks];
  final index = tasks.indexWhere((item) => item.id == task.id);
  if (index < 0) {
    tasks.add(task);
  } else {
    tasks[index] = task;
  }
  return snapshot.copyWith(tasks: tasks);
}

ScheduleDayPlan _appendRecordAndCompleteLinkedTask(
  ScheduleDayPlan snapshot,
  ScheduleRecord record,
) {
  final linkedTaskId = record.linkedTaskId;
  final tasks = linkedTaskId == null
      ? snapshot.tasks
      : snapshot.tasks
            .map(
              (task) => task.id == linkedTaskId
                  ? task.copyWith(state: ScheduleTaskState.completed)
                  : task,
            )
            .toList(growable: false);
  return snapshot.copyWith(
    tasks: tasks,
    records: [...snapshot.records, record],
  );
}

String _errorMessage(Object error) {
  if (error is ApiHttpException) {
    return error.errorMessage ?? '请求失败（${error.statusCode}）';
  }
  return error.toString();
}

DateTime _dateOnly(DateTime value) => value.isUtc
    ? DateTime.utc(value.year, value.month, value.day)
    : DateTime(value.year, value.month, value.day);

String _dayKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

bool _isInDisplayWindow(DateTime anchor, DateTime selected) {
  final dayDistance = _dateOnly(selected).difference(_dateOnly(anchor)).inDays;
  return dayDistance >= -3 && dayDistance <= 3;
}
