import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:momcozy_flutter_app/features/plan/domain/plan_dashboard.dart';
import 'package:momcozy_flutter_app/features/records/domain/records.dart';
import 'package:momcozy_flutter_app/features/profile_overview/domain/maternal_care_overview.dart';
import 'package:momcozy_flutter_app/features/profile_overview/domain/profile_overview.dart';
import 'package:momcozy_flutter_app/features/profile_overview/domain/profile_identity.dart';
import 'package:momcozy_flutter_app/features/profile_overview/presentation/profile_overview_cache.dart';

enum OverviewResourcePhase { initial, loading, data, error, unavailable }

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

  const ProfileOverviewResource.unavailable()
    : this._(phase: OverviewResourcePhase.unavailable);

  final OverviewResourcePhase phase;
  final T? data;
  final Object? error;

  bool get isLoading => phase == OverviewResourcePhase.loading;
  bool get hasError => phase == OverviewResourcePhase.error;
  bool get isUnavailable => phase == OverviewResourcePhase.unavailable;
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
    this.waterRepository,
    this.waterTrendRepository,
    this.vitalRepository,
    this.sleepRepository,
    this.diaperRepository,
    this.maternalCareOverviewRepository,
    this.planRepository,
    required this.babyId,
    this.onBabyIdResolved,
    required this.identity,
    required this.extendedProductResourcesEnabled,
    required this.timezoneProvider,
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
    maternalCareOverview =
        ValueNotifier<ProfileOverviewResource<MaternalCareOverview>>(
          !extendedProductResourcesEnabled
              ? const ProfileOverviewResource.unavailable()
              : this.cache.maternalCareOverview == null
              ? const ProfileOverviewResource.initial()
              : ProfileOverviewResource.data(
                  this.cache.maternalCareOverview!.value,
                ),
        );
    feedingRecords =
        ValueNotifier<ProfileOverviewResource<List<FeedingRecord>>>(
          this.cache.feedingRecords == null
              ? const ProfileOverviewResource.initial()
              : ProfileOverviewResource.data(this.cache.feedingRecords!.value),
        );
    feedingSummary = ValueNotifier<ProfileOverviewResource<FeedingSummary>>(
      !extendedProductResourcesEnabled
          ? const ProfileOverviewResource.unavailable()
          : this.cache.feedingSummary == null
          ? const ProfileOverviewResource.initial()
          : ProfileOverviewResource.data(this.cache.feedingSummary!.value),
    );
    milkTrends = ValueNotifier<ProfileOverviewResource<List<MilkTrendDay>>>(
      this.cache.milkTrends == null
          ? const ProfileOverviewResource.initial()
          : ProfileOverviewResource.data(this.cache.milkTrends!.value),
    );
    waterRecords =
        ValueNotifier<ProfileOverviewResource<List<WaterIntakeRecord>>>(
          !extendedProductResourcesEnabled
              ? const ProfileOverviewResource.unavailable()
              : this.cache.waterRecords == null
              ? const ProfileOverviewResource.initial()
              : ProfileOverviewResource.data(this.cache.waterRecords!.value),
        );
    waterTrends = ValueNotifier<ProfileOverviewResource<List<WaterTrendDay>>>(
      !extendedProductResourcesEnabled
          ? const ProfileOverviewResource.unavailable()
          : this.cache.waterTrends == null
          ? const ProfileOverviewResource.initial()
          : ProfileOverviewResource.data(this.cache.waterTrends!.value),
    );
    vitalRecords = ValueNotifier<ProfileOverviewResource<List<VitalRecord>>>(
      !extendedProductResourcesEnabled
          ? const ProfileOverviewResource.unavailable()
          : this.cache.vitalRecords == null
          ? const ProfileOverviewResource.initial()
          : ProfileOverviewResource.data(this.cache.vitalRecords!.value),
    );
    sleepRecords = ValueNotifier<ProfileOverviewResource<List<SleepRecord>>>(
      !extendedProductResourcesEnabled
          ? const ProfileOverviewResource.unavailable()
          : this.cache.sleepRecords == null
          ? const ProfileOverviewResource.initial()
          : ProfileOverviewResource.data(this.cache.sleepRecords!.value),
    );
    diaperRecords = ValueNotifier<ProfileOverviewResource<List<DiaperRecord>>>(
      !extendedProductResourcesEnabled
          ? const ProfileOverviewResource.unavailable()
          : this.cache.diaperRecords == null
          ? const ProfileOverviewResource.initial()
          : ProfileOverviewResource.data(this.cache.diaperRecords!.value),
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
  final WaterRecordsRepository? waterRepository;
  final WaterTrendRepository? waterTrendRepository;
  final VitalRecordsRepository? vitalRepository;
  final SleepRecordsRepository? sleepRepository;
  final DiaperRecordsRepository? diaperRepository;
  final MaternalCareOverviewRepository? maternalCareOverviewRepository;
  final PlanRepository? planRepository;
  final String babyId;
  final Future<void> Function(String babyId)? onBabyIdResolved;
  final ProfileIdentity identity;
  final bool extendedProductResourcesEnabled;
  final Future<String> Function() timezoneProvider;
  final DateTime Function() now;
  final ProfileOverviewCache cache;
  final ProfileOverviewCachePolicy cachePolicy;

  late final ValueNotifier<ProfileOverviewResource<ProfileOverview>> overview;
  late final ValueNotifier<ProfileOverviewResource<MaternalCareOverview>>
  maternalCareOverview;
  late final ValueNotifier<ProfileOverviewResource<List<FeedingRecord>>>
  feedingRecords;
  late final ValueNotifier<ProfileOverviewResource<FeedingSummary>>
  feedingSummary;
  late final ValueNotifier<ProfileOverviewResource<List<MilkTrendDay>>>
  milkTrends;
  late final ValueNotifier<ProfileOverviewResource<List<WaterIntakeRecord>>>
  waterRecords;
  late final ValueNotifier<ProfileOverviewResource<List<WaterTrendDay>>>
  waterTrends;
  late final ValueNotifier<ProfileOverviewResource<List<VitalRecord>>>
  vitalRecords;
  late final ValueNotifier<ProfileOverviewResource<List<SleepRecord>>>
  sleepRecords;
  late final ValueNotifier<ProfileOverviewResource<List<DiaperRecord>>>
  diaperRecords;
  late final ValueNotifier<ProfileOverviewResource<List<GrowthRecord>>>
  growthRecords;
  late final ValueNotifier<ProfileOverviewResource<PlanDashboard>> plans;
  late final ValueNotifier<RecordMutationState> recordMutation;

  final Map<ProfileOverviewResourceKey, Future<void>> _activeResourceLoads = {};
  final Map<ProfileOverviewResourceKey, int> _resourceRequests = {};
  final Map<ProfileOverviewResourceKey, int> _resourceServiced = {};
  var _disposed = false;
  late String _recordsBabyId;
  String? _persistedResolvedBabyId;

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
    await _persistResolvedBabyId();
    if (_disposed) return;
    await _requestResources(
      resources.where(
        (resource) => resource != ProfileOverviewResourceKey.overview,
      ),
      showLoading: showLoading,
      force: force,
    );
  }

  Future<void> _persistResolvedBabyId() async {
    final callback = onBabyIdResolved;
    final resolvedBabyId = overview.value.data?.baby?.id?.trim();
    if (callback == null ||
        resolvedBabyId == null ||
        resolvedBabyId.isEmpty ||
        resolvedBabyId == babyId.trim() ||
        resolvedBabyId == _persistedResolvedBabyId) {
      return;
    }
    try {
      await callback(resolvedBabyId);
      _persistedResolvedBabyId = resolvedBabyId;
    } catch (_) {
      // The owner-scoped infant ID is already authoritative for this load.
      // Keep the Baby page usable and retry session persistence on refresh.
    }
  }

  Set<ProfileOverviewResourceKey> _visibleResources() {
    return {
      ProfileOverviewResourceKey.overview,
      ProfileOverviewResourceKey.milkTrends,
      if (extendedProductResourcesEnabled &&
          identity == ProfileIdentity.mom &&
          waterRepository != null)
        ProfileOverviewResourceKey.waterRecords,
      if (extendedProductResourcesEnabled &&
          identity == ProfileIdentity.mom &&
          waterTrendRepository != null)
        ProfileOverviewResourceKey.waterTrends,
      if (extendedProductResourcesEnabled &&
          identity == ProfileIdentity.mom &&
          vitalRepository != null)
        ProfileOverviewResourceKey.vitals,
      if (extendedProductResourcesEnabled &&
          identity == ProfileIdentity.mom &&
          maternalCareOverviewRepository != null)
        ProfileOverviewResourceKey.maternalCareOverview,
      if (identity == ProfileIdentity.baby) ...{
        ProfileOverviewResourceKey.feeding,
        if (extendedProductResourcesEnabled)
          ProfileOverviewResourceKey.feedingSummary,
        if (extendedProductResourcesEnabled && sleepRepository != null)
          ProfileOverviewResourceKey.sleep,
        if (extendedProductResourcesEnabled && diaperRepository != null)
          ProfileOverviewResourceKey.diapers,
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
    if (_disposed || !_isResourceAvailable(resource)) {
      return Future<void>.value();
    }
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

  bool _isResourceAvailable(ProfileOverviewResourceKey resource) {
    if (extendedProductResourcesEnabled) return true;
    return switch (resource) {
      ProfileOverviewResourceKey.overview ||
      ProfileOverviewResourceKey.feeding ||
      ProfileOverviewResourceKey.milkTrends ||
      ProfileOverviewResourceKey.growth ||
      ProfileOverviewResourceKey.plans => true,
      ProfileOverviewResourceKey.maternalCareOverview ||
      ProfileOverviewResourceKey.feedingSummary ||
      ProfileOverviewResourceKey.waterRecords ||
      ProfileOverviewResourceKey.waterTrends ||
      ProfileOverviewResourceKey.vitals ||
      ProfileOverviewResourceKey.sleep ||
      ProfileOverviewResourceKey.diapers => false,
    };
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
            cache.reconcileAvatarFileId(value.mom?.avatarFileId);
            cache.overview = OverviewCacheEntry(value: value, fetchedAt: now());
            final resolvedBabyId = value.baby?.id?.trim();
            if (resolvedBabyId?.isNotEmpty == true) {
              _recordsBabyId = resolvedBabyId!;
            }
          },
        );
      case ProfileOverviewResourceKey.maternalCareOverview:
        final repository = maternalCareOverviewRepository;
        if (repository == null) return;
        final today = now();
        await _load(
          maternalCareOverview,
          repository.fetchOverview(
            onDate: DateTime(today.year, today.month, today.day),
          ),
          onData: (value) {
            cache.maternalCareOverview = OverviewCacheEntry(
              value: value,
              fetchedAt: now(),
            );
          },
        );
      case ProfileOverviewResourceKey.feeding:
        final today = now();
        await _load(
          feedingRecords,
          feedingRepository.fetchFeedingRecords(
            date: today,
            babyId: _recordsBabyId,
          ),
          onData: (value) => cache.feedingRecords = OverviewCacheEntry(
            value: value,
            fetchedAt: now(),
          ),
        );
      case ProfileOverviewResourceKey.feedingSummary:
        await _load(
          feedingSummary,
          () async {
            final timezone = (await timezoneProvider()).trim();
            if (timezone.isEmpty) {
              throw StateError('Device timezone is unavailable.');
            }
            return feedingRepository.fetchFeedingSummary(
              babyId: _recordsBabyId,
              days: 7,
              timezone: timezone,
            );
          }(),
          onData: (value) => cache.feedingSummary = OverviewCacheEntry(
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
            utcOffsetMinutes: today.timeZoneOffset.inMinutes,
          ),
          onData: (value) => cache.milkTrends = OverviewCacheEntry(
            value: value,
            fetchedAt: now(),
          ),
        );
      case ProfileOverviewResourceKey.waterRecords:
        final repository = waterRepository;
        if (repository == null) return;
        final today = now();
        await _load(
          waterRecords,
          repository.fetchWaterRecords(
            date: DateTime(today.year, today.month, today.day),
          ),
          onData: (value) => cache.waterRecords = OverviewCacheEntry(
            value: value,
            fetchedAt: now(),
          ),
        );
      case ProfileOverviewResourceKey.waterTrends:
        final repository = waterTrendRepository;
        if (repository == null) return;
        final today = now();
        final localToday = DateTime(today.year, today.month, today.day);
        await _load(
          waterTrends,
          repository.fetchWaterTrends(
            startDate: localToday.subtract(const Duration(days: 6)),
            days: 7,
            utcOffsetMinutes: today.timeZoneOffset.inMinutes,
          ),
          onData: (value) => cache.waterTrends = OverviewCacheEntry(
            value: value,
            fetchedAt: now(),
          ),
        );
      case ProfileOverviewResourceKey.vitals:
        final repository = vitalRepository;
        if (repository == null) return;
        await _load(
          vitalRecords,
          repository.fetchVitalRecords(),
          onData: (value) => cache.vitalRecords = OverviewCacheEntry(
            value: value,
            fetchedAt: now(),
          ),
        );
      case ProfileOverviewResourceKey.sleep:
        final repository = sleepRepository;
        if (repository == null) return;
        final today = now();
        final localToday = DateTime(today.year, today.month, today.day);
        await _load(
          sleepRecords,
          repository.fetchSleepRecords(
            babyId: _recordsBabyId,
            start: localToday.subtract(const Duration(days: 6)),
            end: localToday.add(const Duration(days: 1)),
          ),
          onData: (value) => cache.sleepRecords = OverviewCacheEntry(
            value: value,
            fetchedAt: now(),
          ),
        );
      case ProfileOverviewResourceKey.diapers:
        final repository = diaperRepository;
        if (repository == null) return;
        final today = now();
        final localToday = DateTime(today.year, today.month, today.day);
        await _load(
          diaperRecords,
          repository.fetchDiaperRecords(
            babyId: _recordsBabyId,
            start: localToday.subtract(const Duration(days: 6)),
            end: localToday.add(const Duration(days: 1)),
          ),
          onData: (value) => cache.diaperRecords = OverviewCacheEntry(
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

  Future<bool> savePumpingRecord({
    required DateTime startedAt,
    DateTime? endedAt,
    required double leftVolumeMl,
    required double rightVolumeMl,
    String? planTaskId,
  }) {
    final hasValidVolumes =
        leftVolumeMl > 0 &&
        leftVolumeMl <= 2000 &&
        rightVolumeMl > 0 &&
        rightVolumeMl <= 2000;
    final hasValidInterval = endedAt == null || endedAt.isAfter(startedAt);
    if (!hasValidVolumes || !hasValidInterval) {
      recordMutation.value = RecordMutationState(
        error: ArgumentError(
          'Both milk amounts and a valid time range are required.',
        ),
      );
      return Future<bool>.value(false);
    }
    return _saveRecord(() async {
      await pumpMilkRepository.createPumpMilkRecord(
        occurredAt: startedAt,
        endedAt: endedAt,
        milkVolumeMl: leftVolumeMl + rightVolumeMl,
        planTaskId: planTaskId,
        idempotencyKey: _recordIdempotencyKey(
          'pumping',
          planTaskId: planTaskId,
          occurredAt: startedAt,
        ),
      );
      await _requestResource(
        ProfileOverviewResourceKey.milkTrends,
        showLoading: false,
        force: true,
      );
    });
  }

  Future<bool> saveFeedingRecord({
    required DateTime startedAt,
    DateTime? endedAt,
    required FeedingMethod feedingMethod,
    double? amountMl,
    String? planTaskId,
  }) {
    final isDirect = feedingMethod == FeedingMethod.directBreastfeeding;
    final isBottle = feedingMethod == FeedingMethod.bottle;
    final hasValidInterval = endedAt == null || endedAt.isAfter(startedAt);
    final isValid =
        hasValidInterval &&
        ((isDirect && amountMl == null) ||
            (isBottle && amountMl != null && amountMl > 0 && amountMl <= 2000));
    if (!isValid) {
      recordMutation.value = RecordMutationState(
        error: ArgumentError('Feeding details are incomplete or invalid.'),
      );
      return Future<bool>.value(false);
    }
    return _saveRecord(() async {
      await feedingRepository.createFeedingRecord(
        babyId: _recordsBabyId,
        occurredAt: startedAt,
        feedingMethod: feedingMethod,
        volumeMl: isBottle ? amountMl : null,
        durationSeconds: isDirect && endedAt != null
            ? endedAt.difference(startedAt).inSeconds
            : null,
        planTaskId: planTaskId,
        idempotencyKey: _recordIdempotencyKey(
          'feeding',
          planTaskId: planTaskId,
          occurredAt: startedAt,
        ),
      );
      await Future.wait<void>([
        _requestResource(
          ProfileOverviewResourceKey.feeding,
          showLoading: false,
          force: true,
        ),
        _requestResource(
          ProfileOverviewResourceKey.feedingSummary,
          showLoading: false,
          force: true,
        ),
      ]);
    });
  }

  Future<bool> saveGrowthRecord({
    required DateTime measuredAt,
    required double weightKg,
    double? heightCm,
    required MeasurementContext measurementContext,
  }) {
    if (weightKg <= 0 ||
        weightKg > 500 ||
        (heightCm != null && (heightCm <= 0 || heightCm > 300))) {
      recordMutation.value = RecordMutationState(
        error: ArgumentError('Growth measurements are invalid.'),
      );
      return Future<bool>.value(false);
    }
    return _saveRecord(() async {
      await growthRepository.createGrowthRecord(
        babyId: _recordsBabyId,
        measuredAt: measuredAt,
        weightKg: weightKg,
        heightCm: heightCm,
        measurementPosition: MeasurementPosition.recumbent,
        measurementContext: measurementContext,
        idempotencyKey: _recordIdempotencyKey('growth', occurredAt: measuredAt),
      );
      await Future.wait<void>([
        _requestResource(
          ProfileOverviewResourceKey.growth,
          showLoading: false,
          force: true,
        ),
        _requestResource(
          ProfileOverviewResourceKey.feedingSummary,
          showLoading: false,
          force: true,
        ),
      ]);
    });
  }

  Future<bool> saveSleepRecord({
    required DateTime startedAt,
    DateTime? endedAt,
    required SleepKind kind,
  }) {
    final repository = sleepRepository;
    if (repository == null ||
        (endedAt != null && !endedAt.isAfter(startedAt))) {
      recordMutation.value = RecordMutationState(
        error: ArgumentError('Sleep end must be after its start.'),
      );
      return Future<bool>.value(false);
    }
    return _saveRecord(() async {
      await repository.createSleepRecord(
        babyId: _recordsBabyId,
        startedAt: startedAt,
        endedAt: endedAt,
        kind: kind,
        idempotencyKey: _recordIdempotencyKey('sleep', occurredAt: startedAt),
      );
      await _requestResource(
        ProfileOverviewResourceKey.sleep,
        showLoading: false,
        force: true,
      );
    });
  }

  Future<bool> saveDiaperRecord({
    DateTime? changedAt,
    int? wetDiaperCount,
    int? bowelMovementCount,
    String? stoolConsistency,
  }) {
    final repository = diaperRepository;
    final countsAreValid = [
      wetDiaperCount,
      bowelMovementCount,
    ].every((count) => count == null || (count >= 0 && count <= 100));
    if (repository == null || !countsAreValid) {
      recordMutation.value = RecordMutationState(
        error: ArgumentError('Diaper counts must be between 0 and 100.'),
      );
      return Future<bool>.value(false);
    }
    final hasWet = (wetDiaperCount ?? 0) > 0;
    final hasDirty =
        (bowelMovementCount ?? 0) > 0 ||
        stoolConsistency?.trim().isNotEmpty == true;
    final kind = hasWet && hasDirty
        ? DiaperKind.both
        : hasDirty
        ? DiaperKind.dirty
        : DiaperKind.wet;
    final occurredAt = changedAt ?? now();
    return _saveRecord(() async {
      await repository.createDiaperRecord(
        babyId: _recordsBabyId,
        changedAt: occurredAt,
        kind: kind,
        stoolConsistency: stoolConsistency,
        wetDiaperCount: wetDiaperCount,
        bowelMovementCount: bowelMovementCount,
        idempotencyKey: _recordIdempotencyKey('diaper', occurredAt: occurredAt),
      );
      await _requestResource(
        ProfileOverviewResourceKey.diapers,
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

  String _recordIdempotencyKey(
    String kind, {
    String? planTaskId,
    DateTime? occurredAt,
  }) {
    final normalizedPlanTaskId = planTaskId?.trim();
    if (normalizedPlanTaskId?.isNotEmpty == true) {
      return 'plan-task-record:$normalizedPlanTaskId:$kind';
    }
    final stableOccurredAt = occurredAt ?? now();
    return 'profile-overview-record:$kind:$_recordsBabyId:${stableOccurredAt.toUtc().microsecondsSinceEpoch}';
  }

  void clearRecordMutationError() {
    if (_disposed || recordMutation.value.error == null) return;
    recordMutation.value = const RecordMutationState();
  }

  void _setLoading(ProfileOverviewResourceKey resource) {
    switch (resource) {
      case ProfileOverviewResourceKey.overview:
        overview.value = ProfileOverviewResource.loading(
          previous: overview.value.data,
        );
      case ProfileOverviewResourceKey.maternalCareOverview:
        maternalCareOverview.value = ProfileOverviewResource.loading(
          previous: maternalCareOverview.value.data,
        );
      case ProfileOverviewResourceKey.feeding:
        feedingRecords.value = ProfileOverviewResource.loading(
          previous: feedingRecords.value.data,
        );
      case ProfileOverviewResourceKey.feedingSummary:
        feedingSummary.value = ProfileOverviewResource.loading(
          previous: feedingSummary.value.data,
        );
      case ProfileOverviewResourceKey.milkTrends:
        milkTrends.value = ProfileOverviewResource.loading(
          previous: milkTrends.value.data,
        );
      case ProfileOverviewResourceKey.waterRecords:
        waterRecords.value = ProfileOverviewResource.loading(
          previous: waterRecords.value.data,
        );
      case ProfileOverviewResourceKey.waterTrends:
        waterTrends.value = ProfileOverviewResource.loading(
          previous: waterTrends.value.data,
        );
      case ProfileOverviewResourceKey.vitals:
        vitalRecords.value = ProfileOverviewResource.loading(
          previous: vitalRecords.value.data,
        );
      case ProfileOverviewResourceKey.sleep:
        sleepRecords.value = ProfileOverviewResource.loading(
          previous: sleepRecords.value.data,
        );
      case ProfileOverviewResourceKey.diapers:
        diaperRecords.value = ProfileOverviewResource.loading(
          previous: diaperRecords.value.data,
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
      ProfileOverviewResourceKey.maternalCareOverview =>
        cache.maternalCareOverview?.fetchedAt,
      ProfileOverviewResourceKey.feeding => cache.feedingRecords?.fetchedAt,
      ProfileOverviewResourceKey.feedingSummary =>
        cache.feedingSummary?.fetchedAt,
      ProfileOverviewResourceKey.milkTrends => cache.milkTrends?.fetchedAt,
      ProfileOverviewResourceKey.waterRecords => cache.waterRecords?.fetchedAt,
      ProfileOverviewResourceKey.waterTrends => cache.waterTrends?.fetchedAt,
      ProfileOverviewResourceKey.vitals => cache.vitalRecords?.fetchedAt,
      ProfileOverviewResourceKey.sleep => cache.sleepRecords?.fetchedAt,
      ProfileOverviewResourceKey.diapers => cache.diaperRecords?.fetchedAt,
      ProfileOverviewResourceKey.growth => cache.growthRecords?.fetchedAt,
      ProfileOverviewResourceKey.plans => cache.planDashboard?.fetchedAt,
    };
    return fetchedAt != null &&
        now().difference(fetchedAt) <= cachePolicy.ttlFor(resource);
  }

  bool _resourceHasCache(ProfileOverviewResourceKey resource) {
    return switch (resource) {
      ProfileOverviewResourceKey.overview => cache.overview != null,
      ProfileOverviewResourceKey.maternalCareOverview =>
        cache.maternalCareOverview != null,
      ProfileOverviewResourceKey.feeding => cache.feedingRecords != null,
      ProfileOverviewResourceKey.feedingSummary => cache.feedingSummary != null,
      ProfileOverviewResourceKey.milkTrends => cache.milkTrends != null,
      ProfileOverviewResourceKey.waterRecords => cache.waterRecords != null,
      ProfileOverviewResourceKey.waterTrends => cache.waterTrends != null,
      ProfileOverviewResourceKey.vitals => cache.vitalRecords != null,
      ProfileOverviewResourceKey.sleep => cache.sleepRecords != null,
      ProfileOverviewResourceKey.diapers => cache.diaperRecords != null,
      ProfileOverviewResourceKey.growth => cache.growthRecords != null,
      ProfileOverviewResourceKey.plans => cache.planDashboard != null,
    };
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    overview.dispose();
    maternalCareOverview.dispose();
    feedingRecords.dispose();
    feedingSummary.dispose();
    milkTrends.dispose();
    waterRecords.dispose();
    waterTrends.dispose();
    vitalRecords.dispose();
    sleepRecords.dispose();
    diaperRecords.dispose();
    growthRecords.dispose();
    plans.dispose();
    recordMutation.dispose();
  }
}
