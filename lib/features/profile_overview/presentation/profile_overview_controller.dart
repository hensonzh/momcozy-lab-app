import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:momcozy_flutter_app/features/plan/domain/plan_dashboard.dart';
import 'package:momcozy_flutter_app/features/records/domain/records.dart';
import 'package:momcozy_flutter_app/features/profile_overview/domain/mom_life_stage.dart';
import 'package:momcozy_flutter_app/features/profile_overview/domain/profile_overview.dart';
import 'package:momcozy_flutter_app/features/profile_overview/domain/profile_identity.dart';
import 'package:momcozy_flutter_app/features/profile_overview/presentation/profile_overview_cache.dart';

enum OverviewResourcePhase { initial, loading, data, error }

class ProfileOverviewResource<T> {
  const ProfileOverviewResource._({required this.phase, this.data, this.error});

  const ProfileOverviewResource.initial()
    : this._(phase: OverviewResourcePhase.initial);

  const ProfileOverviewResource.loading({T? previous})
    : this._(phase: OverviewResourcePhase.loading, data: previous);

  const ProfileOverviewResource.data(T value)
    : this._(phase: OverviewResourcePhase.data, data: value);

  const ProfileOverviewResource.error(Object value, {T? previous})
    : this._(phase: OverviewResourcePhase.error, data: previous, error: value);

  final OverviewResourcePhase phase;
  final T? data;
  final Object? error;

  bool get isLoading => phase == OverviewResourcePhase.loading;
  bool get hasError => phase == OverviewResourcePhase.error;
}

class CareStageSelectionState {
  const CareStageSelectionState({
    this.stage,
    this.isResolved = false,
    this.isSaving = false,
    this.pendingStage,
    this.error,
  });

  final MomLifeStage? stage;
  final bool isResolved;
  final bool isSaving;
  final MomLifeStage? pendingStage;
  final Object? error;
}

enum ProfileOverviewMutationPhase { idle, saving, success, error }

class ProfileOverviewMutationState {
  const ProfileOverviewMutationState._({required this.phase, this.message});

  const ProfileOverviewMutationState.idle()
    : this._(phase: ProfileOverviewMutationPhase.idle);

  const ProfileOverviewMutationState.saving()
    : this._(phase: ProfileOverviewMutationPhase.saving);

  const ProfileOverviewMutationState.success(String value)
    : this._(phase: ProfileOverviewMutationPhase.success, message: value);

  const ProfileOverviewMutationState.error(String value)
    : this._(phase: ProfileOverviewMutationPhase.error, message: value);

  final ProfileOverviewMutationPhase phase;
  final String? message;

  bool get isSaving => phase == ProfileOverviewMutationPhase.saving;
}

class RecordMutationState {
  const RecordMutationState({this.isSaving = false, this.error});

  final bool isSaving;
  final Object? error;
}

class ProfileOverviewController {
  ProfileOverviewController({
    required this.profileOverviewRepository,
    required this.feedingRepository,
    required this.pumpMilkRepository,
    required this.milkTrendRepository,
    required this.growthRepository,
    this.planRepository,
    required this.babyId,
    required this.identity,
    ProfileOverviewCache? cache,
    this.cachePolicy = const ProfileOverviewCachePolicy(),
    DateTime Function()? now,
  }) : now = now ?? DateTime.now,
       cache = cache ?? ProfileOverviewCache(ownerUserId: '', babyId: babyId) {
    overview = ValueNotifier<ProfileOverviewResource<ProfileOverview>>(
      this.cache.overview == null
          ? const ProfileOverviewResource.initial()
          : ProfileOverviewResource.data(this.cache.overview!.value),
    );
    feedingRecords =
        ValueNotifier<ProfileOverviewResource<List<FeedingRecord>>>(
          this.cache.feedingRecords == null
              ? const ProfileOverviewResource.initial()
              : ProfileOverviewResource.data(this.cache.feedingRecords!.value),
        );
    milkTrends = ValueNotifier<ProfileOverviewResource<List<MilkTrendDay>>>(
      this.cache.milkTrends == null
          ? const ProfileOverviewResource.initial()
          : ProfileOverviewResource.data(this.cache.milkTrends!.value),
    );
    growthRecords = ValueNotifier<ProfileOverviewResource<List<GrowthRecord>>>(
      this.cache.growthRecords == null
          ? const ProfileOverviewResource.initial()
          : ProfileOverviewResource.data(this.cache.growthRecords!.value),
    );
    plans = ValueNotifier<ProfileOverviewResource<PlanDashboard>>(
      this.cache.planDashboard == null
          ? const ProfileOverviewResource.initial()
          : ProfileOverviewResource.data(this.cache.planDashboard!.value),
    );
    final cachedStage = this.cache.overview?.value.mom?.stage;
    careStage = ValueNotifier<CareStageSelectionState>(
      CareStageSelectionState(
        stage: cachedStage,
        isResolved: this.cache.overview != null,
      ),
    );
    growthMutation = ValueNotifier<ProfileOverviewMutationState>(
      const ProfileOverviewMutationState.idle(),
    );
    recordMutation = ValueNotifier<RecordMutationState>(
      const RecordMutationState(),
    );
    final cachedBabyId = this.cache.overview?.value.baby?.id?.trim();
    _recordsBabyId = cachedBabyId?.isNotEmpty == true
        ? cachedBabyId!
        : babyId.trim();
  }

  final ProfileOverviewRepository profileOverviewRepository;
  final FeedingRecordsRepository feedingRepository;
  final PumpMilkRecordsRepository pumpMilkRepository;
  final MilkTrendRepository milkTrendRepository;
  final GrowthRecordsRepository growthRepository;
  final PlanRepository? planRepository;
  final String babyId;
  final ProfileIdentity identity;
  final DateTime Function() now;
  final ProfileOverviewCache cache;
  final ProfileOverviewCachePolicy cachePolicy;

  late final ValueNotifier<ProfileOverviewResource<ProfileOverview>> overview;
  late final ValueNotifier<ProfileOverviewResource<List<FeedingRecord>>>
  feedingRecords;
  late final ValueNotifier<ProfileOverviewResource<List<MilkTrendDay>>>
  milkTrends;
  late final ValueNotifier<ProfileOverviewResource<List<GrowthRecord>>>
  growthRecords;
  late final ValueNotifier<ProfileOverviewResource<PlanDashboard>> plans;
  late final ValueNotifier<CareStageSelectionState> careStage;
  late final ValueNotifier<ProfileOverviewMutationState> growthMutation;
  late final ValueNotifier<RecordMutationState> recordMutation;

  final Map<ProfileOverviewResourceKey, Future<void>> _activeResourceLoads = {};
  final Map<ProfileOverviewResourceKey, int> _resourceRequests = {};
  final Map<ProfileOverviewResourceKey, int> _resourceServiced = {};
  var _disposed = false;
  late String _recordsBabyId;

  Future<void> initialize() {
    return _requestVisibleResources(showLoading: true);
  }

  Future<void> refresh() {
    return _requestVisibleResources(showLoading: false, force: true);
  }

  Future<void> _requestVisibleResources({
    required bool showLoading,
    bool force = false,
  }) async {
    final resources = _visibleResources();
    if (identity != ProfileIdentity.baby) {
      await _requestResources(
        resources,
        showLoading: showLoading,
        force: force,
      );
      return;
    }
    await _requestResource(
      ProfileOverviewResourceKey.overview,
      showLoading: showLoading,
      force: force,
    );
    await _requestResources(
      resources.where(
        (resource) => resource != ProfileOverviewResourceKey.overview,
      ),
      showLoading: showLoading,
      force: force,
    );
  }

  Set<ProfileOverviewResourceKey> _visibleResources() {
    return {
      ProfileOverviewResourceKey.overview,
      ProfileOverviewResourceKey.milkTrends,
      if (identity == ProfileIdentity.baby) ...{
        ProfileOverviewResourceKey.feeding,
        ProfileOverviewResourceKey.growth,
      },
      if (identity == ProfileIdentity.mom && planRepository != null)
        ProfileOverviewResourceKey.plans,
    };
  }

  Future<void> _requestResources(
    Iterable<ProfileOverviewResourceKey> resources, {
    required bool showLoading,
    bool force = false,
  }) {
    return Future.wait<void>([
      for (final resource in resources)
        _requestResource(resource, showLoading: showLoading, force: force),
    ]);
  }

  Future<void> _requestResource(
    ProfileOverviewResourceKey resource, {
    required bool showLoading,
    required bool force,
  }) {
    if (_disposed) return Future<void>.value();
    if (!force && _resourceIsFresh(resource)) {
      return Future<void>.value();
    }
    _resourceRequests[resource] = (_resourceRequests[resource] ?? 0) + 1;
    if (showLoading && !_resourceHasCache(resource)) {
      _setLoading(resource);
    }
    return _activeResourceLoads.putIfAbsent(
      resource,
      () => _drainResource(resource),
    );
  }

  Future<void> _drainResource(ProfileOverviewResourceKey resource) async {
    try {
      while (!_disposed &&
          (_resourceServiced[resource] ?? 0) <
              (_resourceRequests[resource] ?? 0)) {
        final request = _resourceRequests[resource] ?? 0;
        await _fetchResource(resource);
        _resourceServiced[resource] = request;
      }
    } finally {
      _activeResourceLoads.remove(resource);
    }
  }

  Future<void> _fetchResource(ProfileOverviewResourceKey resource) async {
    switch (resource) {
      case ProfileOverviewResourceKey.overview:
        await _load(
          overview,
          profileOverviewRepository.fetchOverview(),
          onData: (value) {
            cache.overview = OverviewCacheEntry(value: value, fetchedAt: now());
            final resolvedBabyId = value.baby?.id?.trim();
            if (resolvedBabyId?.isNotEmpty == true) {
              _recordsBabyId = resolvedBabyId!;
            }
            if (identity == ProfileIdentity.mom) {
              careStage.value = CareStageSelectionState(
                stage: value.mom?.stage,
                isResolved: true,
              );
            }
          },
          onError: (error) {
            if (identity == ProfileIdentity.mom) {
              careStage.value = CareStageSelectionState(
                stage: careStage.value.stage,
                isResolved: careStage.value.isResolved,
                error: error,
              );
            }
          },
        );
      case ProfileOverviewResourceKey.feeding:
        final today = now();
        await _load(
          feedingRecords,
          feedingRepository.fetchFeedingRecords(
            date: DateTime(today.year, today.month, today.day),
            babyId: _recordsBabyId,
          ),
          onData: (value) => cache.feedingRecords = OverviewCacheEntry(
            value: value,
            fetchedAt: now(),
          ),
        );
      case ProfileOverviewResourceKey.milkTrends:
        final today = now();
        await _load(
          milkTrends,
          milkTrendRepository.fetchMilkTrends(
            startDate: DateTime(
              today.year,
              today.month,
              today.day,
            ).subtract(const Duration(days: 30)),
            days: 31,
          ),
          onData: (value) => cache.milkTrends = OverviewCacheEntry(
            value: value,
            fetchedAt: now(),
          ),
        );
      case ProfileOverviewResourceKey.growth:
        await _load(
          growthRecords,
          growthRepository.fetchGrowthRecords(babyId: _recordsBabyId),
          onData: (value) => cache.growthRecords = OverviewCacheEntry(
            value: value,
            fetchedAt: now(),
          ),
        );
      case ProfileOverviewResourceKey.plans:
        final repository = planRepository;
        if (repository == null) return;
        final today = now();
        await _load(
          plans,
          repository.fetchDashboard(
            weekOf: DateTime(today.year, today.month, today.day),
          ),
          onData: (value) => cache.planDashboard = OverviewCacheEntry(
            value: value,
            fetchedAt: now(),
          ),
        );
    }
  }

  Future<void> _load<T>(
    ValueNotifier<ProfileOverviewResource<T>> notifier,
    Future<T> request, {
    required ValueChanged<T> onData,
    ValueChanged<Object>? onError,
  }) async {
    final previous = notifier.value.data;
    try {
      final value = await request;
      if (_disposed) return;
      onData(value);
      notifier.value = ProfileOverviewResource.data(value);
    } catch (error) {
      if (_disposed) return;
      onError?.call(error);
      notifier.value = ProfileOverviewResource.error(error, previous: previous);
    }
  }

  Future<bool> updateCareStage(MomLifeStage stage) async {
    if (_disposed || identity != ProfileIdentity.mom) return false;
    final current = careStage.value;
    if (current.isSaving) return false;
    if (stage == current.stage) {
      clearCareStageError();
      return true;
    }

    careStage.value = CareStageSelectionState(
      stage: current.stage,
      isResolved: true,
      isSaving: true,
      pendingStage: stage,
    );
    try {
      final saved = await profileOverviewRepository.updateCareStage(stage);
      if (_disposed) return false;
      _replaceOverviewStage(saved);
      careStage.value = CareStageSelectionState(stage: saved, isResolved: true);
      return true;
    } catch (error) {
      if (_disposed) return false;
      careStage.value = CareStageSelectionState(
        stage: current.stage,
        isResolved: true,
        error: error,
      );
      return false;
    }
  }

  Future<bool> savePumpingRecord({required double amountMl}) {
    return _saveRecord(() async {
      await pumpMilkRepository.createPumpMilkRecord(
        occurredAt: now(),
        amountMl: amountMl,
        idempotencyKey: _recordIdempotencyKey('pumping'),
      );
      await _requestResource(
        ProfileOverviewResourceKey.milkTrends,
        showLoading: false,
        force: true,
      );
    });
  }

  Future<bool> saveFeedingRecord({
    required String type,
    required double amountMl,
  }) {
    return _saveRecord(() async {
      await feedingRepository.createFeedingRecord(
        babyId: _recordsBabyId,
        occurredAt: now(),
        type: type,
        amountMl: amountMl,
        idempotencyKey: _recordIdempotencyKey('feeding'),
      );
      await _requestResource(
        ProfileOverviewResourceKey.feeding,
        showLoading: false,
        force: true,
      );
    });
  }

  Future<bool> saveGrowthRecord({
    double? weightKg,
    double? heightCm,
    double? headCm,
  }) {
    return _saveRecord(() async {
      await growthRepository.createGrowthRecord(
        babyId: _recordsBabyId,
        measuredAt: now(),
        weightKg: weightKg,
        heightCm: heightCm,
        headCm: headCm,
        idempotencyKey: _recordIdempotencyKey('growth'),
      );
      await _requestResource(
        ProfileOverviewResourceKey.growth,
        showLoading: false,
        force: true,
      );
    });
  }

  Future<bool> _saveRecord(Future<void> Function() operation) async {
    if (_disposed || recordMutation.value.isSaving) return false;
    recordMutation.value = const RecordMutationState(isSaving: true);
    try {
      await operation();
      if (_disposed) return false;
      recordMutation.value = const RecordMutationState();
      return true;
    } catch (error) {
      if (_disposed) return false;
      recordMutation.value = RecordMutationState(error: error);
      return false;
    }
  }

  String _recordIdempotencyKey(String kind) {
    return 'profile-overview-$kind-${now().microsecondsSinceEpoch}';
  }

  void clearRecordMutationError() {
    if (_disposed || recordMutation.value.error == null) return;
    recordMutation.value = const RecordMutationState();
  }

  void clearCareStageError() {
    if (_disposed || careStage.value.error == null) return;
    careStage.value = CareStageSelectionState(
      stage: careStage.value.stage,
      isResolved: careStage.value.isResolved,
    );
  }

  void _replaceOverviewStage(MomLifeStage stage) {
    final current = overview.value.data ?? const ProfileOverview();
    final mom = (current.mom ?? const MomProfileOverview()).copyWith(
      stage: stage,
    );
    final updated = current.copyWith(mom: mom);
    overview.value = ProfileOverviewResource.data(updated);
    cache.overview = OverviewCacheEntry(value: updated, fetchedAt: now());
  }

  Future<bool> saveGrowth({
    double? weightKg,
    double? heightCm,
    double? headCm,
  }) async {
    if (_disposed || growthMutation.value.isSaving) return false;
    final values = [weightKg, heightCm, headCm].whereType<double>().toList();
    if (values.isEmpty || values.any((value) => value <= 0)) {
      growthMutation.value = const ProfileOverviewMutationState.error(
        'Enter a valid measurement.',
      );
      return false;
    }

    growthMutation.value = const ProfileOverviewMutationState.saving();
    try {
      final current = growthRecords.value.data ?? const <GrowthRecord>[];
      final measuredAt = now();
      final latest = _latestGrowthRecord(current);
      final saved =
          latest?.measuredAt != null &&
              _sameLocalDay(latest!.measuredAt!, measuredAt)
          ? await growthRepository.updateGrowthRecord(
              recordId: latest.id,
              weightKg: weightKg,
              heightCm: heightCm,
              headCm: headCm,
            )
          : await growthRepository.createGrowthRecord(
              babyId: babyId,
              measuredAt: measuredAt,
              weightKg: weightKg,
              heightCm: heightCm,
              headCm: headCm,
              idempotencyKey:
                  'profile-growth-${measuredAt.microsecondsSinceEpoch}',
            );
      if (_disposed) return false;
      final next = _sortGrowthRecords([
        saved,
        ...current.where((record) => record.id != saved.id),
      ]);
      growthRecords.value = ProfileOverviewResource.data(next);
      cache.growthRecords = OverviewCacheEntry(value: next, fetchedAt: now());
      growthMutation.value = const ProfileOverviewMutationState.success(
        'Growth measurement saved.',
      );
      return true;
    } catch (_) {
      if (_disposed) return false;
      growthMutation.value = const ProfileOverviewMutationState.error(
        'The measurement could not be saved. Try again.',
      );
      return false;
    }
  }

  void _setLoading(ProfileOverviewResourceKey resource) {
    switch (resource) {
      case ProfileOverviewResourceKey.overview:
        overview.value = ProfileOverviewResource.loading(
          previous: overview.value.data,
        );
      case ProfileOverviewResourceKey.feeding:
        feedingRecords.value = ProfileOverviewResource.loading(
          previous: feedingRecords.value.data,
        );
      case ProfileOverviewResourceKey.milkTrends:
        milkTrends.value = ProfileOverviewResource.loading(
          previous: milkTrends.value.data,
        );
      case ProfileOverviewResourceKey.growth:
        growthRecords.value = ProfileOverviewResource.loading(
          previous: growthRecords.value.data,
        );
      case ProfileOverviewResourceKey.plans:
        plans.value = ProfileOverviewResource.loading(
          previous: plans.value.data,
        );
    }
  }

  bool _resourceIsFresh(ProfileOverviewResourceKey resource) {
    final fetchedAt = switch (resource) {
      ProfileOverviewResourceKey.overview => cache.overview?.fetchedAt,
      ProfileOverviewResourceKey.feeding => cache.feedingRecords?.fetchedAt,
      ProfileOverviewResourceKey.milkTrends => cache.milkTrends?.fetchedAt,
      ProfileOverviewResourceKey.growth => cache.growthRecords?.fetchedAt,
      ProfileOverviewResourceKey.plans => cache.planDashboard?.fetchedAt,
    };
    return fetchedAt != null &&
        now().difference(fetchedAt) <= cachePolicy.ttlFor(resource);
  }

  bool _resourceHasCache(ProfileOverviewResourceKey resource) {
    return switch (resource) {
      ProfileOverviewResourceKey.overview => cache.overview != null,
      ProfileOverviewResourceKey.feeding => cache.feedingRecords != null,
      ProfileOverviewResourceKey.milkTrends => cache.milkTrends != null,
      ProfileOverviewResourceKey.growth => cache.growthRecords != null,
      ProfileOverviewResourceKey.plans => cache.planDashboard != null,
    };
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    overview.dispose();
    feedingRecords.dispose();
    milkTrends.dispose();
    growthRecords.dispose();
    plans.dispose();
    careStage.dispose();
    growthMutation.dispose();
    recordMutation.dispose();
  }
}

GrowthRecord? _latestGrowthRecord(List<GrowthRecord> records) {
  if (records.isEmpty) return null;
  return _sortGrowthRecords(records).first;
}

List<GrowthRecord> _sortGrowthRecords(Iterable<GrowthRecord> records) {
  final values = List<GrowthRecord>.of(records);
  values.sort((left, right) {
    final leftTime = left.measuredAt;
    final rightTime = right.measuredAt;
    if (leftTime == null && rightTime == null) return 0;
    if (leftTime == null) return 1;
    if (rightTime == null) return -1;
    return rightTime.compareTo(leftTime);
  });
  return values;
}

bool _sameLocalDay(DateTime left, DateTime right) {
  final localLeft = left.toLocal();
  final localRight = right.toLocal();
  return localLeft.year == localRight.year &&
      localLeft.month == localRight.month &&
      localLeft.day == localRight.day;
}
