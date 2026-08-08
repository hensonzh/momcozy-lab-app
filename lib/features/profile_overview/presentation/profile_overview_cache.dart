import 'package:momcozy_flutter_app/features/records/domain/records.dart';
import 'package:momcozy_flutter_app/features/profile_overview/domain/profile_overview.dart';

enum ProfileOverviewResourceKey {
  overview,
  feeding,
  sleep,
  diaper,
  milkTrends,
  growth,
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
    this.feedingTtl = const Duration(seconds: 30),
    this.sleepTtl = const Duration(seconds: 30),
    this.diaperTtl = const Duration(seconds: 30),
    this.milkTrendsTtl = const Duration(minutes: 2),
    this.growthTtl = const Duration(minutes: 2),
  });

  final Duration overviewTtl;
  final Duration feedingTtl;
  final Duration sleepTtl;
  final Duration diaperTtl;
  final Duration milkTrendsTtl;
  final Duration growthTtl;

  Duration ttlFor(ProfileOverviewResourceKey resource) {
    return switch (resource) {
      ProfileOverviewResourceKey.overview => overviewTtl,
      ProfileOverviewResourceKey.feeding => feedingTtl,
      ProfileOverviewResourceKey.sleep => sleepTtl,
      ProfileOverviewResourceKey.diaper => diaperTtl,
      ProfileOverviewResourceKey.milkTrends => milkTrendsTtl,
      ProfileOverviewResourceKey.growth => growthTtl,
    };
  }
}

class ProfileOverviewCache {
  ProfileOverviewCache({required this.ownerUserId, required this.babyId});

  final String ownerUserId;
  final String babyId;

  OverviewCacheEntry<ProfileOverview>? overview;
  OverviewCacheEntry<List<FeedingRecord>>? feedingRecords;
  OverviewCacheEntry<List<SleepRecord>>? sleepRecords;
  OverviewCacheEntry<List<DiaperRecord>>? diaperRecords;
  OverviewCacheEntry<List<MilkTrendDay>>? milkTrends;
  OverviewCacheEntry<List<GrowthRecord>>? growthRecords;

  bool matches({required String ownerUserId, required String babyId}) {
    return this.ownerUserId == ownerUserId && this.babyId == babyId;
  }

  void clear() {
    overview = null;
    feedingRecords = null;
    sleepRecords = null;
    diaperRecords = null;
    milkTrends = null;
    growthRecords = null;
  }
}
