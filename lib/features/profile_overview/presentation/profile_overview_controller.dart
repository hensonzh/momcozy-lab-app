import 'dart:async';

import 'package:flutter/foundation.dart';
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
    this.stage = MomLifeStage.postpartum,
    this.isResolved = false,
    this.isSaving = false,
    this.pendingStage,
    this.error,
  });

  final MomLifeStage stage;
  final bool isResolved;
  final bool isSaving;
  final MomLifeStage? pendingStage;
  final Object? error;
}

class ProfileOverviewController {
  ProfileOverviewController({
    required this.profileOverviewRepository,
    required this.feedingRepository,
    required this.milkTrendRepository,
    required this.growthRepository,
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
    final cachedStage = this.cache.overview?.value.mom?.stage;
    careStage = ValueNotifier<CareStageSelectionState>(
      CareStageSelectionState(
        stage: cachedStage ?? MomLifeStage.postpartum,
        isResolved: this.cache.overview != null,
      ),
    );
  }

  final ProfileOverviewRepository profileOverviewRepository;
  final FeedingRecordsRepository feedingRepository;
  final MilkTrendRepository milkTrendRepository;
  final GrowthRecordsRepository growthRepository;
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
  late final ValueNotifier<CareStageSelectionState> careStage;

  final Map<ProfileOverviewResourceKey, Future<void>> _activeResourceLoads = {};
  final Map<ProfileOverviewResourceKey, int> _resourceRequests = {};
  final Map<ProfileOverviewResourceKey, int> _resourceServiced = {};
  var _disposed = false;

  Future<void> initialize() {
    return _requestResources(_visibleResources(), showLoading: true);
  }

  Future<void> refresh() {
    return _requestResources(
      _visibleResources(),
      showLoading: false,
      force: true,
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
            if (identity == ProfileIdentity.mom) {
              careStage.value = CareStageSelectionState(
                stage: value.mom?.stage ?? MomLifeStage.postpartum,
                isResolved: true,
              );
            }
          },
          onError: (_) {
            if (identity == ProfileIdentity.mom) {
              careStage.value = CareStageSelectionState(
                stage: careStage.value.stage,
                isResolved: true,
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
          growthRepository.fetchGrowthRecords(babyId: babyId),
          onData: (value) => cache.growthRecords = OverviewCacheEntry(
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
    }
  }

  bool _resourceIsFresh(ProfileOverviewResourceKey resource) {
    final fetchedAt = switch (resource) {
      ProfileOverviewResourceKey.overview => cache.overview?.fetchedAt,
      ProfileOverviewResourceKey.feeding => cache.feedingRecords?.fetchedAt,
      ProfileOverviewResourceKey.milkTrends => cache.milkTrends?.fetchedAt,
      ProfileOverviewResourceKey.growth => cache.growthRecords?.fetchedAt,
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
    };
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    overview.dispose();
    feedingRecords.dispose();
    milkTrends.dispose();
    growthRecords.dispose();
    careStage.dispose();
  }
}
