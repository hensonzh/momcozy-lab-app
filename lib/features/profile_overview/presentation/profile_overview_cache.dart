import 'package:flutter/foundation.dart';
import 'package:momcozy_flutter_app/features/records/domain/records.dart';
import 'package:momcozy_flutter_app/features/plan/domain/plan_dashboard.dart';
import 'package:momcozy_flutter_app/features/profile_overview/domain/profile_overview.dart';
import 'package:momcozy_flutter_app/features/profile_overview/domain/maternal_care_overview.dart';

enum ProfileOverviewResourceKey {
  overview,
  maternalCareOverview,
  feeding,
  feedingSummary,
  milkTrends,
  waterRecords,
  waterTrends,
  vitals,
  sleep,
  diapers,
  growth,
  plans,
}

class OverviewCacheEntry<T> {
  const OverviewCacheEntry({required this.value, required this.fetchedAt});

  final T value;
  final DateTime fetchedAt;

  bool isFresh(DateTime now, Duration ttl) {
    return now.difference(fetchedAt) <= ttl;
  }
}

class ProfileOverviewCachePolicy {
  const ProfileOverviewCachePolicy({
    this.overviewTtl = const Duration(minutes: 5),
    this.maternalCareOverviewTtl = const Duration(minutes: 2),
    this.feedingTtl = const Duration(seconds: 30),
    this.feedingSummaryTtl = const Duration(seconds: 30),
    this.milkTrendsTtl = const Duration(minutes: 2),
    this.waterRecordsTtl = const Duration(seconds: 30),
    this.waterTrendsTtl = const Duration(minutes: 2),
    this.vitalsTtl = const Duration(minutes: 2),
    this.sleepTtl = const Duration(seconds: 30),
    this.diapersTtl = const Duration(seconds: 30),
    this.growthTtl = const Duration(minutes: 2),
    this.plansTtl = const Duration(minutes: 2),
  });

  final Duration overviewTtl;
  final Duration maternalCareOverviewTtl;
  final Duration feedingTtl;
  final Duration feedingSummaryTtl;
  final Duration milkTrendsTtl;
  final Duration waterRecordsTtl;
  final Duration waterTrendsTtl;
  final Duration vitalsTtl;
  final Duration sleepTtl;
  final Duration diapersTtl;
  final Duration growthTtl;
  final Duration plansTtl;

  Duration ttlFor(ProfileOverviewResourceKey resource) {
    return switch (resource) {
      ProfileOverviewResourceKey.overview => overviewTtl,
      ProfileOverviewResourceKey.maternalCareOverview =>
        maternalCareOverviewTtl,
      ProfileOverviewResourceKey.feeding => feedingTtl,
      ProfileOverviewResourceKey.feedingSummary => feedingSummaryTtl,
      ProfileOverviewResourceKey.milkTrends => milkTrendsTtl,
      ProfileOverviewResourceKey.waterRecords => waterRecordsTtl,
      ProfileOverviewResourceKey.waterTrends => waterTrendsTtl,
      ProfileOverviewResourceKey.vitals => vitalsTtl,
      ProfileOverviewResourceKey.sleep => sleepTtl,
      ProfileOverviewResourceKey.diapers => diapersTtl,
      ProfileOverviewResourceKey.growth => growthTtl,
      ProfileOverviewResourceKey.plans => plansTtl,
    };
  }
}

class ProfileOverviewCache extends ChangeNotifier {
  ProfileOverviewCache({required this.ownerUserId, required this.babyId});

  final String ownerUserId;
  final String babyId;

  OverviewCacheEntry<ProfileOverview>? overview;
  OverviewCacheEntry<MaternalCareOverview>? maternalCareOverview;
  OverviewCacheEntry<List<FeedingRecord>>? feedingRecords;
  OverviewCacheEntry<FeedingSummary>? feedingSummary;
  OverviewCacheEntry<List<MilkTrendDay>>? milkTrends;
  OverviewCacheEntry<List<WaterIntakeRecord>>? waterRecords;
  OverviewCacheEntry<List<WaterTrendDay>>? waterTrends;
  OverviewCacheEntry<List<VitalRecord>>? vitalRecords;
  OverviewCacheEntry<List<SleepRecord>>? sleepRecords;
  OverviewCacheEntry<List<DiaperRecord>>? diaperRecords;
  OverviewCacheEntry<List<GrowthRecord>>? growthRecords;
  OverviewCacheEntry<PlanDashboard>? planDashboard;

  bool matches({required String ownerUserId, required String babyId}) {
    return this.ownerUserId == ownerUserId && this.babyId == babyId;
  }

  void invalidateOverview() {
    invalidate(const [ProfileOverviewResourceKey.overview]);
  }

  void invalidate(Iterable<ProfileOverviewResourceKey> resources) {
    var invalidated = false;
    for (final resource in resources) {
      invalidated = true;
      switch (resource) {
        case ProfileOverviewResourceKey.overview:
          overview = null;
        case ProfileOverviewResourceKey.maternalCareOverview:
          maternalCareOverview = null;
        case ProfileOverviewResourceKey.feeding:
          feedingRecords = null;
        case ProfileOverviewResourceKey.feedingSummary:
          feedingSummary = null;
        case ProfileOverviewResourceKey.milkTrends:
          milkTrends = null;
        case ProfileOverviewResourceKey.waterRecords:
          waterRecords = null;
        case ProfileOverviewResourceKey.waterTrends:
          waterTrends = null;
        case ProfileOverviewResourceKey.vitals:
          vitalRecords = null;
        case ProfileOverviewResourceKey.sleep:
          sleepRecords = null;
        case ProfileOverviewResourceKey.diapers:
          diaperRecords = null;
        case ProfileOverviewResourceKey.growth:
          growthRecords = null;
        case ProfileOverviewResourceKey.plans:
          planDashboard = null;
      }
    }
    if (invalidated) notifyListeners();
  }

  void clear() {
    overview = null;
    maternalCareOverview = null;
    feedingRecords = null;
    feedingSummary = null;
    milkTrends = null;
    waterRecords = null;
    waterTrends = null;
    vitalRecords = null;
    sleepRecords = null;
    diaperRecords = null;
    growthRecords = null;
    planDashboard = null;
  }
}
