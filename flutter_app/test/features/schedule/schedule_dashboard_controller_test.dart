import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/schedule/domain/schedule_plan.dart';
import 'package:momcozy_flutter_app/features/schedule/presentation/schedule_dashboard_controller.dart';

void main() {
  test(
    'loads typed success and keeps skipped separate from completed',
    () async {
      final repository = _FakeScheduleRepository(snapshot: _snapshot());
      final controller = ScheduleDashboardController(
        repository: repository,
        initialDay: DateTime.utc(2026, 7, 3),
        now: () => DateTime.utc(2026, 7, 3, 10),
      );

      await controller.load();

      expect(controller.state.phase, ScheduleLoadPhase.success);
      expect(controller.state.snapshot?.completedTaskCount, 1);
      expect(controller.state.snapshot?.skippedTaskCount, 1);
      expect(controller.state.nextPendingTask?.id, 'pending');
    },
  );

  test(
    'week arrows browse dates without changing selection or refetching',
    () async {
      final repository = _FakeScheduleRepository(snapshot: _snapshot());
      final controller = ScheduleDashboardController(
        repository: repository,
        initialDay: DateTime.utc(2026, 7, 3),
        now: () => DateTime.utc(2026, 7, 3),
      );
      await controller.load();

      controller.browseWeek(1);

      expect(controller.state.selectedDay, DateTime.utc(2026, 7, 3));
      expect(controller.state.displayAnchor, DateTime.utc(2026, 7, 10));
      expect(repository.fetchCount, 1);

      await controller.selectDay(DateTime.utc(2026, 7, 9));
      expect(controller.state.displayAnchor, DateTime.utc(2026, 7, 10));
      expect(repository.fetchCount, 2);

      await controller.selectDay(DateTime.utc(2026, 7, 10));
      expect(repository.fetchCount, 3);
    },
  );

  test('background day refresh preserves the selected day and week', () async {
    final repository = _FakeScheduleRepository(snapshot: _snapshot());
    final controller = ScheduleDashboardController(
      repository: repository,
      initialDay: DateTime.utc(2026, 7, 3),
    );
    await controller.load();

    final refreshed = await controller.refreshDay(DateTime.utc(2026, 7, 4));

    expect(refreshed, isTrue);
    expect(controller.state.selectedDay, DateTime.utc(2026, 7, 3));
    expect(controller.state.displayAnchor, DateTime.utc(2026, 7, 3));
    expect(controller.state.snapshot?.day, DateTime.utc(2026, 7, 3));
    expect(repository.fetchCount, 2);

    final cachedSelection = controller.selectDay(DateTime.utc(2026, 7, 4));
    expect(controller.state.snapshot?.day, DateTime.utc(2026, 7, 4));
    await cachedSelection;
  });

  test(
    'selecting an uncached day never carries the previous snapshot',
    () async {
      final repository = _DeferredScheduleRepository(snapshot: _snapshot());
      final controller = ScheduleDashboardController(
        repository: repository,
        initialDay: DateTime.utc(2026, 7, 3),
      );
      final initialLoad = controller.load();
      repository.completeNext();
      await initialLoad;

      final nextLoad = controller.selectDay(DateTime.utc(2026, 7, 4));
      expect(controller.state.selectedDay, DateTime.utc(2026, 7, 4));
      expect(controller.state.displayAnchor, DateTime.utc(2026, 7, 3));
      expect(controller.state.snapshot, isNull);

      repository.completeNext();
      await nextLoad;
      expect(controller.state.snapshot?.day, DateTime.utc(2026, 7, 4));
    },
  );

  test(
    'uses authoritative mutation response and surfaces mutation failures',
    () async {
      final repository = _FakeScheduleRepository(snapshot: _snapshot());
      final controller = ScheduleDashboardController(
        repository: repository,
        initialDay: DateTime.utc(2026, 7, 3),
        now: () => DateTime.utc(2026, 7, 3),
      );
      await controller.load();

      await controller.setTaskState('pending', ScheduleTaskState.completed);
      expect(
        controller.state.snapshot?.tasks
            .firstWhere((task) => task.id == 'pending')
            .state,
        ScheduleTaskState.completed,
      );

      repository.failure = StateError('offline');
      await controller.deleteTask('completed');
      expect(controller.state.phase, ScheduleLoadPhase.success);
      expect(controller.state.mutationError, contains('offline'));
      expect(controller.state.snapshot?.tasks, hasLength(3));
    },
  );

  test('distinguishes initial error from an empty successful day', () async {
    final failingRepository = _FakeScheduleRepository(
      snapshot: _snapshot(),
      failure: StateError('backend down'),
    );
    final failed = ScheduleDashboardController(
      repository: failingRepository,
      initialDay: DateTime.utc(2026, 7, 3),
    );
    await failed.load();
    expect(failed.state.phase, ScheduleLoadPhase.error);

    final empty = ScheduleDashboardController(
      repository: _FakeScheduleRepository(
        snapshot: ScheduleDayPlan(day: DateTime.utc(2026, 7, 3)),
      ),
      initialDay: DateTime.utc(2026, 7, 3),
    );
    await empty.load();
    expect(empty.state.phase, ScheduleLoadPhase.empty);
  });

  test('mutation completion stays with its initiating day', () async {
    final repository = _DeferredMutationScheduleRepository(
      snapshot: _snapshot(),
    );
    final controller = ScheduleDashboardController(
      repository: repository,
      initialDay: DateTime.utc(2026, 7, 3),
    );
    await controller.load();

    final mutation = controller.setTaskState(
      'pending',
      ScheduleTaskState.completed,
    );
    expect(controller.state.isMutating, isTrue);

    await controller.selectDay(DateTime.utc(2026, 7, 4));
    expect(controller.state.selectedDay, DateTime.utc(2026, 7, 4));
    expect(controller.state.snapshot?.day, DateTime.utc(2026, 7, 4));
    expect(controller.state.isMutating, isTrue);

    repository.completeMutation();
    await mutation;

    expect(controller.state.selectedDay, DateTime.utc(2026, 7, 4));
    expect(controller.state.snapshot?.day, DateTime.utc(2026, 7, 4));
    expect(
      controller.state.snapshot?.tasks
          .firstWhere((task) => task.id == 'pending')
          .state,
      ScheduleTaskState.pending,
    );
    expect(controller.state.isMutating, isFalse);

    final originReload = controller.selectDay(DateTime.utc(2026, 7, 3));
    expect(
      controller.state.snapshot?.tasks
          .firstWhere((task) => task.id == 'pending')
          .state,
      ScheduleTaskState.completed,
    );
    await originReload;
  });

  test(
    'mutation failure without a snapshot never becomes fake success',
    () async {
      final controller = ScheduleDashboardController(
        repository: _FakeScheduleRepository(
          snapshot: _snapshot(),
          failure: StateError('offline'),
        ),
        initialDay: DateTime.utc(2026, 7, 3),
      );

      final created = await controller.createTask(time: '10:00', title: '吸奶');

      expect(created, isNull);
      expect(controller.state.snapshot, isNull);
      expect(controller.state.phase, ScheduleLoadPhase.loading);
      expect(controller.state.mutationError, contains('offline'));
    },
  );

  test(
    'lost mutation response reconciles authority and retry stays deduplicated',
    () async {
      final repository = _LostResponseScheduleRepository(snapshot: _snapshot());
      final controller = ScheduleDashboardController(
        repository: repository,
        initialDay: DateTime.utc(2026, 7, 3),
      );
      await controller.load();

      final first = await controller.createTask(
        time: '18:00',
        title: '晚间吸奶',
        idempotencyKey: 'stable-create-intent',
      );

      expect(first, isNull);
      expect(controller.state.mutationError, contains('response lost'));
      expect(
        controller.state.snapshot?.tasks.where(
          (task) => task.id == 'server-created',
        ),
        hasLength(1),
      );
      expect(repository.fetchCount, 2);

      final retried = await controller.createTask(
        time: '18:00',
        title: '晚间吸奶',
        idempotencyKey: 'stable-create-intent',
      );

      expect(retried?.id, 'server-created');
      expect(repository.idempotencyKeys, [
        'stable-create-intent',
        'stable-create-intent',
      ]);
      expect(
        controller.state.snapshot?.tasks.where(
          (task) => task.id == 'server-created',
        ),
        hasLength(1),
      );
    },
  );
}

ScheduleDayPlan _snapshot() {
  return ScheduleDayPlan(
    day: DateTime.utc(2026, 7, 3),
    tasks: [
      const ScheduleTask(
        id: 'completed',
        title: '晨间吸奶',
        state: ScheduleTaskState.completed,
      ),
      const ScheduleTask(
        id: 'skipped',
        title: '补水',
        state: ScheduleTaskState.skipped,
      ),
      ScheduleTask(
        id: 'pending',
        title: '喂养',
        state: ScheduleTaskState.pending,
        remindAt: DateTime.utc(2026, 7, 3, 14),
      ),
    ],
  );
}

class _FakeScheduleRepository implements ScheduleRepository {
  _FakeScheduleRepository({required this.snapshot, this.failure});

  ScheduleDayPlan snapshot;
  Object? failure;
  int fetchCount = 0;

  void _throwIfNeeded() {
    final error = failure;
    if (error != null) throw error;
  }

  @override
  Future<ScheduleDayPlan> fetchDayPlan({required DateTime day}) async {
    fetchCount += 1;
    _throwIfNeeded();
    return snapshot.copyWith(day: day);
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
    _throwIfNeeded();
    return ScheduleTask(
      id: 'created',
      planId: planId,
      title: title,
      description: description,
      kind: kind,
      state: ScheduleTaskState.pending,
      remindAt: DateTime(
        day.year,
        day.month,
        day.day,
        int.parse(time.split(':')[0]),
        int.parse(time.split(':')[1]),
      ),
    );
  }

  @override
  Future<ScheduleTask> updateTask({
    required String taskId,
    required DateTime day,
    required String time,
    required String title,
    String? description,
  }) async {
    _throwIfNeeded();
    final current = snapshot.tasks.firstWhere((task) => task.id == taskId);
    return current.copyWith(title: title);
  }

  @override
  Future<ScheduleTask> setTaskState({
    required String taskId,
    required ScheduleTaskState state,
  }) async {
    _throwIfNeeded();
    final current = snapshot.tasks.firstWhere((task) => task.id == taskId);
    return current.copyWith(state: state);
  }

  @override
  Future<void> deleteTask({required String taskId}) async => _throwIfNeeded();

  @override
  Future<ScheduleRecord> createPumpingRecord({
    required DateTime occurredAt,
    required int amountMl,
    int? durationSeconds,
    String? linkedTaskId,
    String? idempotencyKey,
  }) async {
    _throwIfNeeded();
    return ScheduleRecord(
      id: 'pump-created',
      kind: ScheduleRecordKind.pumping,
      occurredAt: occurredAt,
      amountMl: amountMl,
      linkedTaskId: linkedTaskId,
    );
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
    _throwIfNeeded();
    return ScheduleRecord(
      id: 'feed-created',
      kind: ScheduleRecordKind.feeding,
      occurredAt: occurredAt,
      amountMl: amountMl,
      linkedTaskId: linkedTaskId,
    );
  }

  @override
  Future<void> deleteRecord({required ScheduleRecord record}) async =>
      _throwIfNeeded();
}

class _DeferredScheduleRepository extends _FakeScheduleRepository {
  _DeferredScheduleRepository({required super.snapshot});

  final List<Completer<void>> _pending = [];

  @override
  Future<ScheduleDayPlan> fetchDayPlan({required DateTime day}) async {
    fetchCount += 1;
    final completer = Completer<void>();
    _pending.add(completer);
    await completer.future;
    return snapshot.copyWith(day: day);
  }

  void completeNext() => _pending.removeAt(0).complete();
}

class _DeferredMutationScheduleRepository extends _FakeScheduleRepository {
  _DeferredMutationScheduleRepository({required super.snapshot});

  Completer<ScheduleTask>? _pendingMutation;

  @override
  Future<ScheduleTask> setTaskState({
    required String taskId,
    required ScheduleTaskState state,
  }) {
    final current = snapshot.tasks.firstWhere((task) => task.id == taskId);
    final completer = Completer<ScheduleTask>();
    _pendingMutation = completer;
    return completer.future.then((_) => current.copyWith(state: state));
  }

  void completeMutation() {
    final completer = _pendingMutation;
    if (completer == null) throw StateError('No mutation is pending');
    _pendingMutation = null;
    completer.complete(
      const ScheduleTask(
        id: 'unused-completion-value',
        title: 'unused',
        state: ScheduleTaskState.pending,
      ),
    );
  }
}

class _LostResponseScheduleRepository extends _FakeScheduleRepository {
  _LostResponseScheduleRepository({required super.snapshot});

  bool _loseFirstResponse = true;
  final List<String?> idempotencyKeys = [];

  ScheduleTask get _createdTask => ScheduleTask(
    id: 'server-created',
    title: '晚间吸奶',
    kind: ScheduleTaskKind.pumping,
    state: ScheduleTaskState.pending,
    remindAt: DateTime.utc(2026, 7, 3, 18),
  );

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
    idempotencyKeys.add(idempotencyKey);
    if (_loseFirstResponse) {
      _loseFirstResponse = false;
      snapshot = snapshot.copyWith(tasks: [...snapshot.tasks, _createdTask]);
      throw StateError('response lost');
    }
    return _createdTask;
  }
}
