import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:app/core/preferences/volume_unit_preference.dart';
import 'package:app/features/pregnancy_diary/domain/pregnancy_diary_entry.dart';
import 'package:app/features/pregnancy_plan/domain/pregnancy_plan.dart';
import 'package:app/features/records/domain/records.dart';
import 'package:app/features/status/data/status_preference_store.dart';
import 'package:app/features/status/domain/birth_journey_plan.dart';
import 'package:app/features/status/domain/status_overview.dart';
import 'package:app/features/status/domain/status_selection.dart';
import 'package:app/features/status/presentation/status_dashboard_cache.dart';

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
    required this.milkTrendRepository,
    required this.growthRepository,
    required this.pregnancyDiaryRepository,
    required this.pregnancyPlanRepository,
    required this.preferenceStore,
    required this.volumeUnitPreferenceStore,
    required this.babyId,
    StatusDashboardCache? cache,
    this.cachePolicy = const StatusDashboardCachePolicy(),
    StatusCareStage initialCareStage = StatusCareStage.postpartum,
    StatusIdentity initialIdentity = StatusIdentity.mom,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now,
       cache = cache ?? StatusDashboardCache(ownerUserId: '', babyId: babyId) {
    careStage = ValueNotifier<StatusCareStage>(initialCareStage);
    identity = ValueNotifier<StatusIdentity>(
      initialCareStage == StatusCareStage.pregnancy
          ? StatusIdentity.mom
          : initialIdentity,
    );
    overview = ValueNotifier<StatusResource<StatusOverview>>(
      this.cache.overview == null
          ? const StatusResource.initial()
          : StatusResource.data(this.cache.overview!.value),
    );
    feedingRecords = ValueNotifier<StatusResource<List<FeedingRecord>>>(
      this.cache.feedingRecords == null
          ? const StatusResource.initial()
          : StatusResource.data(this.cache.feedingRecords!.value),
    );
    milkTrends = ValueNotifier<StatusResource<List<MilkTrendDay>>>(
      this.cache.milkTrends == null
          ? const StatusResource.initial()
          : StatusResource.data(this.cache.milkTrends!.value),
    );
    growthRecords = ValueNotifier<StatusResource<List<GrowthRecord>>>(
      this.cache.growthRecords == null
          ? const StatusResource.initial()
          : StatusResource.data(this.cache.growthRecords!.value),
    );
    pregnancyDiaryEntries =
        ValueNotifier<StatusResource<List<PregnancyDiaryEntry>>>(
          this.cache.pregnancyDiaryEntries == null
              ? const StatusResource.initial()
              : StatusResource.data(this.cache.pregnancyDiaryEntries!.value),
        );
    birthJourneyPlan = ValueNotifier<StatusResource<BirthJourneyPlan?>>(
      this.cache.pregnancyPlan == null
          ? const StatusResource.initial()
          : StatusResource.data(this.cache.pregnancyPlan!.value),
    );
  }

  final StatusRepository statusRepository;
  final FeedingRecordsRepository feedingRepository;
  final MilkTrendRepository milkTrendRepository;
  final GrowthRecordsRepository growthRepository;
  final PregnancyDiaryRepository pregnancyDiaryRepository;
  final PregnancyPlanRepository pregnancyPlanRepository;
  final StatusPreferenceStore preferenceStore;
  final VolumeUnitPreferenceStore volumeUnitPreferenceStore;
  final String babyId;
  final DateTime Function() now;
  final StatusDashboardCache cache;
  final StatusDashboardCachePolicy cachePolicy;

  late final ValueNotifier<StatusCareStage> careStage;
  late final ValueNotifier<StatusIdentity> identity;
  final selectionReady = ValueNotifier<bool>(false);
  final volumeUnit = ValueNotifier<MomCozyVolumeUnit>(
    MomCozyVolumeUnit.milliliters,
  );

  late final ValueNotifier<StatusResource<StatusOverview>> overview;
  late final ValueNotifier<StatusResource<List<FeedingRecord>>> feedingRecords;
  late final ValueNotifier<StatusResource<List<MilkTrendDay>>> milkTrends;
  late final ValueNotifier<StatusResource<List<GrowthRecord>>> growthRecords;
  late final ValueNotifier<StatusResource<List<PregnancyDiaryEntry>>>
  pregnancyDiaryEntries;
  late final ValueNotifier<StatusResource<BirthJourneyPlan?>> birthJourneyPlan;

  final diaryMutation = ValueNotifier<StatusMutationState>(
    const StatusMutationState.idle(),
  );
  final growthMutation = ValueNotifier<StatusMutationState>(
    const StatusMutationState.idle(),
  );
  final planMutation = ValueNotifier<StatusMutationState>(
    const StatusMutationState.idle(),
  );

  var _selectionRevision = 0;
  var _volumeUnitRevision = 0;
  var _disposed = false;
  Future<void> _preferenceWrites = Future<void>.value();
  Future<void> _volumeUnitWrites = Future<void>.value();
  final Map<StatusDashboardResource, Future<void>> _activeResourceLoads = {};
  final Map<StatusDashboardResource, int> _resourceRequests = {};
  final Map<StatusDashboardResource, int> _resourceServiced = {};
  final Set<StatusDashboardResource> _showLoadingOnNextFetch = {};

  Future<void> initialize() async {
    var selectionResolved = false;
    final selection = restoreSelection().whenComplete(() {
      selectionResolved = true;
    });
    unawaited(restoreVolumeUnit());
    await Future.wait<void>([
      Future.any<void>([selection, Future<void>.microtask(() {})]),
      _requestResource(
        StatusDashboardResource.overview,
        showLoading: true,
        force: false,
      ),
    ]);
    final requestedCareStage = careStage.value;
    final requestedIdentity = identity.value;
    await _requestResources(
      _visibleBranchResources(),
      showLoading: true,
      force: false,
    );
    Future<void> loadRestoredBranchIfChanged() {
      if (_disposed ||
          (careStage.value == requestedCareStage &&
              identity.value == requestedIdentity)) {
        return Future<void>.value();
      }
      return _requestResources(
        _visibleBranchResources(),
        showLoading: true,
        force: false,
      );
    }

    if (selectionResolved) {
      await loadRestoredBranchIfChanged();
    } else {
      unawaited(selection.then((_) => loadRestoredBranchIfChanged()));
    }
  }

  Future<void> restoreSelection() async {
    if (_disposed) return;
    final revision = _selectionRevision;
    try {
      final stored = await preferenceStore.readCareStage();
      if (_disposed || revision != _selectionRevision) return;
      if (stored != null) {
        careStage.value = stored;
        if (stored == StatusCareStage.pregnancy) {
          identity.value = StatusIdentity.mom;
        }
      }
    } catch (_) {
      // Preference persistence is best effort, matching the legacy behavior.
    } finally {
      if (!_disposed) selectionReady.value = true;
    }
  }

  Future<void> changeCareStage(StatusCareStage stage) {
    if (_disposed) return Future<void>.value();
    _selectionRevision += 1;
    careStage.value = stage;
    if (stage == StatusCareStage.pregnancy) {
      identity.value = StatusIdentity.mom;
    }
    _preferenceWrites = _preferenceWrites
        .then<void>((_) => preferenceStore.writeCareStage(stage))
        .catchError((Object _) {});
    return _preferenceWrites;
  }

  bool selectIdentity(StatusIdentity next) {
    if (_disposed ||
        (careStage.value == StatusCareStage.pregnancy &&
            next == StatusIdentity.baby)) {
      return false;
    }
    identity.value = next;
    return true;
  }

  Future<void> restoreVolumeUnit() async {
    if (_disposed) return;
    final revision = _volumeUnitRevision;
    try {
      final stored = await volumeUnitPreferenceStore.read();
      if (_disposed || revision != _volumeUnitRevision || stored == null) {
        return;
      }
      volumeUnit.value = stored;
    } catch (_) {
      // Unit persistence is best effort, matching the legacy behavior.
    }
  }

  Future<void> changeVolumeUnit(MomCozyVolumeUnit unit) {
    if (_disposed) return Future<void>.value();
    _volumeUnitRevision += 1;
    volumeUnit.value = unit;
    _volumeUnitWrites = _volumeUnitWrites
        .then<void>((_) => volumeUnitPreferenceStore.write(unit))
        .catchError((Object _) {});
    return _volumeUnitWrites;
  }

  Future<void> load({bool showLoading = true}) {
    return _requestResources(
      StatusDashboardResource.values,
      showLoading: showLoading,
      force: false,
    );
  }

  Future<void> loadVisible({bool showLoading = true}) {
    return _requestResources(
      _visibleResources(),
      showLoading: showLoading,
      force: false,
    );
  }

  Future<void> refresh() {
    return _requestResources(
      _visibleResources(),
      showLoading: false,
      force: true,
    );
  }

  Future<void> refreshStale() => loadVisible(showLoading: false);

  Future<void> refreshPregnancyPlan() {
    return _requestResource(
      StatusDashboardResource.pregnancyPlan,
      showLoading: false,
      force: true,
    );
  }

  Future<void> refreshPregnancyDiary() {
    return _requestResource(
      StatusDashboardResource.pregnancyDiary,
      showLoading: false,
      force: true,
    );
  }

  Set<StatusDashboardResource> _visibleResources() {
    final resources = <StatusDashboardResource>{
      StatusDashboardResource.overview,
    }..addAll(_visibleBranchResources());
    return resources;
  }

  Set<StatusDashboardResource> _visibleBranchResources() {
    final resources = <StatusDashboardResource>{};
    if (careStage.value == StatusCareStage.pregnancy) {
      return resources
        ..add(StatusDashboardResource.pregnancyDiary)
        ..add(StatusDashboardResource.pregnancyPlan);
    }
    if (identity.value == StatusIdentity.baby) {
      return resources
        ..add(StatusDashboardResource.feeding)
        ..add(StatusDashboardResource.growth);
    }
    return resources..add(StatusDashboardResource.milkTrends);
  }

  Future<void> _requestResources(
    Iterable<StatusDashboardResource> resources, {
    required bool showLoading,
    required bool force,
  }) async {
    if (_disposed) return;
    await Future.wait<void>(
      resources.map(
        (resource) =>
            _requestResource(resource, showLoading: showLoading, force: force),
      ),
    );
  }

  Future<void> _requestResource(
    StatusDashboardResource resource, {
    required bool showLoading,
    required bool force,
  }) {
    if (_disposed) return Future<void>.value();
    final active = _activeResourceLoads[resource];
    if (active != null) {
      if (force) {
        _resourceRequests[resource] = (_resourceRequests[resource] ?? 0) + 1;
      }
      return active;
    }
    if (!force && _resourceIsFresh(resource)) return Future<void>.value();

    _resourceRequests[resource] = (_resourceRequests[resource] ?? 0) + 1;
    if (showLoading && !_resourceHasCache(resource)) {
      _showLoadingOnNextFetch.add(resource);
    }
    late final Future<void> operation;
    operation = _drainResource(resource).whenComplete(() {
      if (identical(_activeResourceLoads[resource], operation)) {
        _activeResourceLoads.remove(resource);
      }
    });
    _activeResourceLoads[resource] = operation;
    return operation;
  }

  Future<void> _drainResource(StatusDashboardResource resource) async {
    while (!_disposed &&
        (_resourceServiced[resource] ?? 0) <
            (_resourceRequests[resource] ?? 0)) {
      final targetRevision = _resourceRequests[resource] ?? 0;
      final showLoading = _showLoadingOnNextFetch.remove(resource);
      await _fetchResource(resource, showLoading: showLoading);
      _resourceServiced[resource] = targetRevision;
    }
  }

  Future<void> _fetchResource(
    StatusDashboardResource resource, {
    required bool showLoading,
  }) async {
    final current = now();
    final today = DateTime(current.year, current.month, current.day);
    final trendStart = today.subtract(const Duration(days: 30));
    switch (resource) {
      case StatusDashboardResource.overview:
        await _resolve(
          overview,
          statusRepository.fetchOverview(),
          onData: (value) =>
              cache.overview = StatusCacheEntry(value: value, fetchedAt: now()),
          showLoading: showLoading,
        );
        break;
      case StatusDashboardResource.feeding:
        await _resolve(
          feedingRecords,
          feedingRepository.fetchFeedingRecords(date: today),
          onData: (value) => cache.feedingRecords = StatusCacheEntry(
            value: value,
            fetchedAt: now(),
          ),
          showLoading: showLoading,
        );
        break;
      case StatusDashboardResource.milkTrends:
        await _resolve(
          milkTrends,
          milkTrendRepository.fetchMilkTrends(startDate: trendStart, days: 31),
          onData: (value) => cache.milkTrends = StatusCacheEntry(
            value: value,
            fetchedAt: now(),
          ),
          showLoading: showLoading,
        );
        break;
      case StatusDashboardResource.growth:
        await _resolve(
          growthRecords,
          growthRepository.fetchGrowthRecords(babyId: babyId),
          normalize: _sortGrowthRecords,
          onData: (value) => cache.growthRecords = StatusCacheEntry(
            value: value,
            fetchedAt: now(),
          ),
          showLoading: showLoading,
        );
        break;
      case StatusDashboardResource.pregnancyDiary:
        await _resolve(
          pregnancyDiaryEntries,
          pregnancyDiaryRepository.fetchEntries(limit: 12),
          normalize: _sortDiaryEntries,
          onData: (value) => cache.pregnancyDiaryEntries = StatusCacheEntry(
            value: value,
            fetchedAt: now(),
          ),
          showLoading: showLoading,
        );
        break;
      case StatusDashboardResource.pregnancyPlan:
        await _resolve(
          birthJourneyPlan,
          _fetchBirthJourneyPlan(),
          onData: (value) => cache.pregnancyPlan = StatusCacheEntry(
            value: value,
            fetchedAt: now(),
          ),
          showLoading: showLoading,
        );
        break;
    }
  }

  bool _resourceIsFresh(StatusDashboardResource resource) {
    final fetchedAt = switch (resource) {
      StatusDashboardResource.overview => cache.overview?.fetchedAt,
      StatusDashboardResource.feeding => cache.feedingRecords?.fetchedAt,
      StatusDashboardResource.milkTrends => cache.milkTrends?.fetchedAt,
      StatusDashboardResource.growth => cache.growthRecords?.fetchedAt,
      StatusDashboardResource.pregnancyDiary =>
        cache.pregnancyDiaryEntries?.fetchedAt,
      StatusDashboardResource.pregnancyPlan => cache.pregnancyPlan?.fetchedAt,
    };
    if (fetchedAt == null) return false;
    return now().difference(fetchedAt) <= cachePolicy.ttlFor(resource);
  }

  bool _resourceHasCache(StatusDashboardResource resource) {
    return switch (resource) {
      StatusDashboardResource.overview => cache.overview != null,
      StatusDashboardResource.feeding => cache.feedingRecords != null,
      StatusDashboardResource.milkTrends => cache.milkTrends != null,
      StatusDashboardResource.growth => cache.growthRecords != null,
      StatusDashboardResource.pregnancyDiary =>
        cache.pregnancyDiaryEntries != null,
      StatusDashboardResource.pregnancyPlan => cache.pregnancyPlan != null,
    };
  }

  Future<BirthJourneyPlan?> _fetchBirthJourneyPlan() async {
    final plan = await pregnancyPlanRepository.fetchActivePlan();
    return plan == null ? null : projectBirthJourneyPlan(plan);
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
    final diaryResource = pregnancyDiaryEntries.value;
    if (diaryResource.phase != StatusResourcePhase.data) {
      diaryMutation.value = const StatusMutationState.error('孕期日记尚未同步，请稍后重试');
      return false;
    }
    diaryMutation.value = const StatusMutationState.saving();
    try {
      final current = diaryResource.data ?? const <PregnancyDiaryEntry>[];
      final existing = _findDiaryEntry(current, entryDate);
      final saved = existing == null
          ? await pregnancyDiaryRepository.createEntry(
              entryDate: entryDate,
              draft: draft,
            )
          : await pregnancyDiaryRepository.updateEntry(
              entryDate: entryDate,
              draft: draft,
            );
      if (_disposed) return false;
      final next = <PregnancyDiaryEntry>[
        saved,
        ...current.where(
          (entry) => !_sameDay(entry.entryDate, saved.entryDate),
        ),
      ];
      pregnancyDiaryEntries.value = StatusResource.data(
        _sortDiaryEntries(next),
      );
      cache.pregnancyDiaryEntries = StatusCacheEntry(
        value: pregnancyDiaryEntries.value.data!,
        fetchedAt: now(),
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
      cache.growthRecords = StatusCacheEntry(
        value: growthRecords.value.data!,
        fetchedAt: now(),
      );
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
    BirthJourneyTodo? item;
    for (final period in plan.periods) {
      for (final candidate in period.items) {
        if (candidate.authoritativeItemId == taskId) {
          item = candidate;
          break;
        }
      }
      if (item != null) {
        ownerPeriod = period;
        break;
      }
    }
    if (ownerPeriod == null || item == null || !ownerPeriod.isCurrent) {
      planMutation.value = const StatusMutationState.error(
        '当前还未到该阶段，暂不适合进行该事项',
      );
      return false;
    }
    if (!item.canMutate || plan.version < 1) {
      planMutation.value = const StatusMutationState.error(
        '这份旧版计划暂不支持直接更新，请交给 CozyMate 继续处理',
      );
      return false;
    }

    planMutation.value = const StatusMutationState.saving();
    birthJourneyPlan.value = StatusResource.data(
      plan.withTodoCompletion(item.id, completed),
    );
    cache.pregnancyPlan = StatusCacheEntry(
      value: plan,
      fetchedAt: DateTime.fromMillisecondsSinceEpoch(0),
    );
    try {
      final updated = await pregnancyPlanRepository.updateTodoCompletion(
        planId: plan.id,
        itemId: item.authoritativeItemId,
        completed: completed,
        expectedVersion: plan.version,
        idempotencyKey:
            'pregnancy-todo-${plan.id}-${item.authoritativeItemId}-'
            'v${plan.version}-${completed ? 1 : 0}',
      );
      if (_disposed) return false;
      final authoritative = projectBirthJourneyPlan(updated);
      birthJourneyPlan.value = StatusResource.data(authoritative);
      cache.pregnancyPlan = StatusCacheEntry(
        value: authoritative,
        fetchedAt: now(),
      );
      planMutation.value = StatusMutationState.success(
        completed ? '事项已完成' : '事项已恢复为未完成',
      );
      return true;
    } catch (_) {
      if (_disposed) return false;
      birthJourneyPlan.value = StatusResource.data(plan);
      cache.pregnancyPlan = StatusCacheEntry(
        value: plan,
        fetchedAt: DateTime.fromMillisecondsSinceEpoch(0),
      );
      await refreshPregnancyPlan();
      if (_disposed) return false;
      planMutation.value = const StatusMutationState.error(
        '同步计划完成状态失败，已恢复最新计划',
      );
      return false;
    }
  }

  Future<bool> deleteBirthJourneyPlan() async {
    if (_disposed || planMutation.value.isSaving) return false;
    final plan = birthJourneyPlan.value.data;
    if (plan == null) return false;
    planMutation.value = const StatusMutationState.saving();
    try {
      await pregnancyPlanRepository.deletePlan(planId: plan.id);
      if (_disposed) return false;
      birthJourneyPlan.value = const StatusResource.data(null);
      cache.pregnancyPlan = StatusCacheEntry(value: null, fetchedAt: now());
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
    _selectionRevision += 1;
    _volumeUnitRevision += 1;
    careStage.dispose();
    identity.dispose();
    selectionReady.dispose();
    volumeUnit.dispose();
    overview.dispose();
    feedingRecords.dispose();
    milkTrends.dispose();
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
    Future<T> operation, {
    T Function(T value)? normalize,
    required void Function(T value) onData,
    required bool showLoading,
  }) async {
    if (showLoading) _markLoading(notifier);
    try {
      final value = await operation;
      if (_disposed) return;
      final normalized = normalize == null ? value : normalize(value);
      notifier.value = StatusResource.data(normalized);
      onData(normalized);
    } catch (error) {
      if (_disposed) return;
      notifier.value = StatusResource.error(
        error,
        previous: notifier.value.data,
      );
    }
  }
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

PregnancyDiaryEntry? _findDiaryEntry(
  List<PregnancyDiaryEntry> entries,
  DateTime date,
) {
  for (final entry in entries) {
    if (_sameDay(entry.entryDate, date)) return entry;
  }
  return null;
}

bool _positive(double? value) => value != null && value > 0;
