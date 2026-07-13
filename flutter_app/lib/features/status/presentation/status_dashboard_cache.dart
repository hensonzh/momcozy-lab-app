import 'package:momcozy_flutter_app/features/pregnancy_diary/domain/pregnancy_diary_entry.dart';
import 'package:momcozy_flutter_app/features/records/domain/records.dart';
import 'package:momcozy_flutter_app/features/status/domain/birth_journey_plan.dart';
import 'package:momcozy_flutter_app/features/status/domain/status_overview.dart';

enum StatusDashboardResource {
  overview,
  feeding,
  milkTrends,
  growth,
  pregnancyDiary,
  pregnancyPlan,
}

class StatusCacheEntry<T> {
  const StatusCacheEntry({required this.value, required this.fetchedAt});

  final T value;
  final DateTime fetchedAt;

  bool isFresh(DateTime now, Duration ttl) {
    return now.difference(fetchedAt) <= ttl;
  }
}

class StatusDashboardCachePolicy {
  const StatusDashboardCachePolicy({
    this.overviewTtl = const Duration(minutes: 5),
    this.feedingTtl = const Duration(seconds: 30),
    this.milkTrendsTtl = const Duration(minutes: 2),
    this.growthTtl = const Duration(minutes: 2),
    this.pregnancyDiaryTtl = const Duration(minutes: 1),
    this.pregnancyPlanTtl = const Duration(minutes: 5),
  });

  final Duration overviewTtl;
  final Duration feedingTtl;
  final Duration milkTrendsTtl;
  final Duration growthTtl;
  final Duration pregnancyDiaryTtl;
  final Duration pregnancyPlanTtl;

  Duration ttlFor(StatusDashboardResource resource) {
    return switch (resource) {
      StatusDashboardResource.overview => overviewTtl,
      StatusDashboardResource.feeding => feedingTtl,
      StatusDashboardResource.milkTrends => milkTrendsTtl,
      StatusDashboardResource.growth => growthTtl,
      StatusDashboardResource.pregnancyDiary => pregnancyDiaryTtl,
      StatusDashboardResource.pregnancyPlan => pregnancyPlanTtl,
    };
  }
}

class StatusDashboardCache {
  StatusDashboardCache({required this.ownerUserId, required this.babyId});

  final String ownerUserId;
  final String babyId;

  StatusCacheEntry<StatusOverview>? overview;
  StatusCacheEntry<List<FeedingRecord>>? feedingRecords;
  StatusCacheEntry<List<MilkTrendDay>>? milkTrends;
  StatusCacheEntry<List<GrowthRecord>>? growthRecords;
  StatusCacheEntry<List<PregnancyDiaryEntry>>? pregnancyDiaryEntries;
  StatusCacheEntry<BirthJourneyPlan?>? pregnancyPlan;

  bool matches({required String ownerUserId, required String babyId}) {
    return this.ownerUserId == ownerUserId && this.babyId == babyId;
  }

  void invalidatePregnancyDiary() {
    pregnancyDiaryEntries = null;
  }

  void clear() {
    overview = null;
    feedingRecords = null;
    milkTrends = null;
    growthRecords = null;
    pregnancyDiaryEntries = null;
    pregnancyPlan = null;
  }
}
