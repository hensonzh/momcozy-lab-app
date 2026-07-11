import 'package:flutter/foundation.dart';
import 'package:momcozy_flutter_app/features/records/domain/records.dart';
import 'package:momcozy_flutter_app/features/status/domain/birth_journey_plan.dart';
import 'package:momcozy_flutter_app/features/status/domain/pregnancy_diary.dart';
import 'package:momcozy_flutter_app/features/status/domain/status_overview.dart';

enum StatusResourcePhase { initial, loading, data, error }

class StatusResource<T> {
  const StatusResource._({required this.phase, this.data, this.error});

  const StatusResource.initial() : this._(phase: StatusResourcePhase.initial);

  const StatusResource.loading({T? previous})
    : this._(phase: StatusResourcePhase.loading, data: previous);

  const StatusResource.data(T value)
    : this._(phase: StatusResourcePhase.data, data: value);

  const StatusResource.error(Object value, {T? previous})
    : this._(phase: StatusResourcePhase.error, data: previous, error: value);

  final StatusResourcePhase phase;
  final T? data;
  final Object? error;

  bool get isLoading => phase == StatusResourcePhase.loading;
  bool get hasError => phase == StatusResourcePhase.error;
}

enum StatusMutationPhase { idle, saving, success, error }

class StatusMutationState {
  const StatusMutationState._({required this.phase, this.message});

  const StatusMutationState.idle() : this._(phase: StatusMutationPhase.idle);

  const StatusMutationState.saving()
    : this._(phase: StatusMutationPhase.saving);

  const StatusMutationState.success([String? message])
    : this._(phase: StatusMutationPhase.success, message: message);

  const StatusMutationState.error(String message)
    : this._(phase: StatusMutationPhase.error, message: message);

  final StatusMutationPhase phase;
  final String? message;

  bool get isSaving => phase == StatusMutationPhase.saving;
}

class StatusDashboardController {
  StatusDashboardController({
    required this.statusRepository,
    required this.feedingRepository,
    required this.pumpRepository,
    required this.growthRepository,
    required this.pregnancyDiaryRepository,
    required this.birthJourneyPlanRepository,
    required this.babyId,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  final StatusRepository statusRepository;
  final FeedingRecordsRepository feedingRepository;
  final PumpMilkRecordsRepository pumpRepository;
  final GrowthRecordsRepository growthRepository;
  final PregnancyDiaryRepository pregnancyDiaryRepository;
  final BirthJourneyPlanRepository birthJourneyPlanRepository;
  final String babyId;
  final DateTime Function() now;

  final overview = ValueNotifier<StatusResource<StatusOverview>>(
    const StatusResource.initial(),
  );
  final feedingRecords = ValueNotifier<StatusResource<List<FeedingRecord>>>(
    const StatusResource.initial(),
  );
  final pumpRecords = ValueNotifier<StatusResource<List<PumpMilkRecord>>>(
    const StatusResource.initial(),
  );
  final growthRecords = ValueNotifier<StatusResource<List<GrowthRecord>>>(
    const StatusResource.initial(),
  );
  final pregnancyDiaryEntries =
      ValueNotifier<StatusResource<List<PregnancyDiaryEntry>>>(
        const StatusResource.initial(),
      );
  final birthJourneyPlan = ValueNotifier<StatusResource<BirthJourneyPlan?>>(
    const StatusResource.initial(),
  );

  final diaryMutation = ValueNotifier<StatusMutationState>(
    const StatusMutationState.idle(),
  );
  final growthMutation = ValueNotifier<StatusMutationState>(
    const StatusMutationState.idle(),
  );
  final planMutation = ValueNotifier<StatusMutationState>(
    const StatusMutationState.idle(),
  );

  var _generation = 0;
  var _disposed = false;

  Future<void> load() async {
    if (_disposed) return;
    final generation = ++_generation;
    final current = now();
    final today = DateTime(current.year, current.month, current.day);
    final trendStart = today.subtract(const Duration(days: 29));
    final trendEnd = today.add(const Duration(days: 1));

    _markLoading(overview);
    _markLoading(feedingRecords);
    _markLoading(pumpRecords);
    _markLoading(growthRecords);
    _markLoading(pregnancyDiaryEntries);
    _markLoading(birthJourneyPlan);

    await Future.wait<void>([
      _resolve(overview, statusRepository.fetchOverview(), generation),
      _resolve(
        feedingRecords,
        feedingRepository.fetchFeedingRecords(date: today),
        generation,
      ),
      _resolve(
        pumpRecords,
        pumpRepository.fetchPumpMilkRecordsRange(
          start: trendStart,
          end: trendEnd,
        ),
        generation,
      ),
      _resolve(
        growthRecords,
        growthRepository.fetchGrowthRecords(babyId: babyId),
        generation,
        normalize: _sortGrowthRecords,
      ),
      _resolve(
        pregnancyDiaryEntries,
        pregnancyDiaryRepository.fetchEntries(limit: 12),
        generation,
        normalize: _sortDiaryEntries,
      ),
      _resolve(
        birthJourneyPlan,
        birthJourneyPlanRepository.fetchActivePlan(),
        generation,
      ),
    ]);
  }

  Future<bool> saveDiary({
    required DateTime entryDate,
    required PregnancyDiaryDraft draft,
  }) async {
    if (_disposed || diaryMutation.value.isSaving) return false;
    if (!draft.hasContent) {
      diaryMutation.value = const StatusMutationState.error('至少写下一项今天的状态或记录');
      return false;
    }
    diaryMutation.value = const StatusMutationState.saving();
    try {
      final saved = await pregnancyDiaryRepository.upsertEntry(
        entryDate: entryDate,
        draft: draft,
      );
      if (_disposed) return false;
      final current = pregnancyDiaryEntries.value.data ?? const [];
      final next = <PregnancyDiaryEntry>[
        saved,
        ...current.where(
          (entry) => !_sameDay(entry.entryDate, saved.entryDate),
        ),
      ];
      pregnancyDiaryEntries.value = StatusResource.data(
        _sortDiaryEntries(next),
      );
      diaryMutation.value = const StatusMutationState.success('今天的记录已保存');
      return true;
    } catch (_) {
      if (_disposed) return false;
      diaryMutation.value = const StatusMutationState.error('保存失败，请稍后重试');
      return false;
    }
  }

  Future<bool> saveGrowth({
    required double? weightKg,
    required double? heightCm,
    required double? headCm,
  }) async {
    if (_disposed || growthMutation.value.isSaving) return false;
    if (!_positive(weightKg) || !_positive(heightCm) || !_positive(headCm)) {
      growthMutation.value = const StatusMutationState.error('请填写完整的体重、身高与头围');
      return false;
    }
    growthMutation.value = const StatusMutationState.saving();
    try {
      final current = growthRecords.value.data ?? const <GrowthRecord>[];
      final today = now();
      final latest = current.isEmpty ? null : current.first;
      final saved =
          latest?.measuredAt != null && _sameDay(latest!.measuredAt!, today)
          ? await growthRepository.updateGrowthRecord(
              recordId: latest.id,
              weightKg: weightKg,
              heightCm: heightCm,
              headCm: headCm,
            )
          : await growthRepository.createGrowthRecord(
              babyId: babyId,
              measuredAt: today,
              weightKg: weightKg,
              heightCm: heightCm,
              headCm: headCm,
              idempotencyKey: 'status-growth-${today.microsecondsSinceEpoch}',
            );
      if (_disposed) return false;
      final next = <GrowthRecord>[
        saved,
        ...current.where((record) => record.id != saved.id),
      ];
      growthRecords.value = StatusResource.data(_sortGrowthRecords(next));
      growthMutation.value = const StatusMutationState.success('成长指标已保存');
      return true;
    } catch (_) {
      if (_disposed) return false;
      growthMutation.value = const StatusMutationState.error('保存失败，请稍后重试');
      return false;
    }
  }

  Future<bool> togglePlanTodo({
    required String taskId,
    required bool completed,
  }) async {
    if (_disposed || planMutation.value.isSaving) return false;
    final plan = birthJourneyPlan.value.data;
    if (plan == null) return false;
    BirthJourneyPeriod? ownerPeriod;
    for (final period in plan.periods) {
      if (period.items.any((item) => item.id == taskId)) {
        ownerPeriod = period;
        break;
      }
    }
    if (ownerPeriod == null || !ownerPeriod.isCurrent) {
      planMutation.value = const StatusMutationState.error(
        '当前还未到该阶段，暂不适合进行该事项',
      );
      return false;
    }

    final optimistic = plan.withTodoCompletion(taskId, completed);
    birthJourneyPlan.value = StatusResource.data(optimistic);
    planMutation.value = const StatusMutationState.saving();
    try {
      await birthJourneyPlanRepository.updateTodoCompletion(
        taskId: taskId,
        completed: completed,
      );
      if (_disposed) return false;
      final refreshed = await birthJourneyPlanRepository.fetchActivePlan();
      if (_disposed) return false;
      birthJourneyPlan.value = StatusResource.data(refreshed ?? optimistic);
      planMutation.value = const StatusMutationState.success('计划已更新');
      return true;
    } catch (_) {
      if (_disposed) return false;
      birthJourneyPlan.value = StatusResource.data(plan);
      planMutation.value = const StatusMutationState.error('同步计划完成状态失败');
      return false;
    }
  }

  Future<bool> deleteBirthJourneyPlan() async {
    if (_disposed || planMutation.value.isSaving) return false;
    final plan = birthJourneyPlan.value.data;
    if (plan == null) return false;
    planMutation.value = const StatusMutationState.saving();
    try {
      await birthJourneyPlanRepository.deletePlan(planId: plan.id);
      if (_disposed) return false;
      birthJourneyPlan.value = const StatusResource.data(null);
      planMutation.value = const StatusMutationState.success('孕期计划已删除');
      return true;
    } catch (_) {
      if (_disposed) return false;
      planMutation.value = const StatusMutationState.error('删除孕期计划失败');
      return false;
    }
  }

  void clearMutationFeedback() {
    if (_disposed) return;
    diaryMutation.value = const StatusMutationState.idle();
    growthMutation.value = const StatusMutationState.idle();
    planMutation.value = const StatusMutationState.idle();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation += 1;
    overview.dispose();
    feedingRecords.dispose();
    pumpRecords.dispose();
    growthRecords.dispose();
    pregnancyDiaryEntries.dispose();
    birthJourneyPlan.dispose();
    diaryMutation.dispose();
    growthMutation.dispose();
    planMutation.dispose();
  }

  void _markLoading<T>(ValueNotifier<StatusResource<T>> notifier) {
    notifier.value = StatusResource.loading(previous: notifier.value.data);
  }

  Future<void> _resolve<T>(
    ValueNotifier<StatusResource<T>> notifier,
    Future<T> operation,
    int generation, {
    T Function(T value)? normalize,
  }) async {
    try {
      final value = await operation;
      if (!_accept(generation)) return;
      notifier.value = StatusResource.data(
        normalize == null ? value : normalize(value),
      );
    } catch (error) {
      if (!_accept(generation)) return;
      notifier.value = StatusResource.error(
        error,
        previous: notifier.value.data,
      );
    }
  }

  bool _accept(int generation) => !_disposed && generation == _generation;
}

List<GrowthRecord> _sortGrowthRecords(List<GrowthRecord> records) {
  final result = [...records];
  result.sort((a, b) {
    final aTime = a.measuredAt?.millisecondsSinceEpoch ?? 0;
    final bTime = b.measuredAt?.millisecondsSinceEpoch ?? 0;
    return bTime.compareTo(aTime);
  });
  return List<GrowthRecord>.unmodifiable(result);
}

List<PregnancyDiaryEntry> _sortDiaryEntries(List<PregnancyDiaryEntry> entries) {
  final result = [...entries]
    ..sort((a, b) => b.entryDate.compareTo(a.entryDate));
  return List<PregnancyDiaryEntry>.unmodifiable(result);
}

bool _sameDay(DateTime a, DateTime b) {
  final localA = a.toLocal();
  final localB = b.toLocal();
  return localA.year == localB.year &&
      localA.month == localB.month &&
      localA.day == localB.day;
}

bool _positive(double? value) => value != null && value > 0;
