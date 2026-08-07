import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/records/domain/records.dart';
import 'package:momcozy_flutter_app/features/profile_overview/domain/profile_overview.dart';
import 'package:momcozy_flutter_app/features/profile_overview/domain/profile_identity.dart';
import 'package:momcozy_flutter_app/features/profile_overview/presentation/profile_overview_cache.dart';
import 'package:momcozy_flutter_app/features/profile_overview/presentation/profile_overview_controller.dart';

void main() {
  group('ProfileOverviewController', () {
    test('Me loads only the resources used by the current page', () async {
      final overviewRepository = _FakeProfileOverviewRepository();
      final records = _FakeRecordsRepository();
      final controller = _controller(
        overviewRepository: overviewRepository,
        records: records,
      );
      addTearDown(controller.dispose);

      await controller.initialize();

      expect(controller.overview.value.phase, OverviewResourcePhase.data);
      expect(controller.milkTrends.value.phase, OverviewResourcePhase.data);
      expect(
        controller.feedingRecords.value.phase,
        OverviewResourcePhase.initial,
      );
      expect(
        controller.growthRecords.value.phase,
        OverviewResourcePhase.initial,
      );
      expect(overviewRepository.fetchCount, 1);
      expect(records.milkTrendFetchCount, 1);
      expect(records.feedingFetchCount, 0);
      expect(records.growthFetchCount, 0);
      expect(records.milkTrendStart, DateTime(2026, 6, 11));
    });

    test(
      'Baby loads feeding and growth while keeping failures local',
      () async {
        final records = _FakeRecordsRepository(
          feeding: const [
            FeedingRecord(id: 'feed-001', type: 'bottle', amountMl: 80),
          ],
          growthError: StateError('growth unavailable'),
        );
        final controller = _controller(
          records: records,
          identity: ProfileIdentity.baby,
        );
        addTearDown(controller.dispose);

        await controller.initialize();

        expect(controller.overview.value.phase, OverviewResourcePhase.data);
        expect(controller.feedingRecords.value.data?.single.amountMl, 80);
        expect(controller.milkTrends.value.phase, OverviewResourcePhase.data);
        expect(controller.growthRecords.value.hasError, isTrue);
      },
    );

    test(
      'fresh cache avoids reads and explicit refresh fetches again',
      () async {
        var clock = DateTime(2026, 7, 11, 10);
        final cache = ProfileOverviewCache(
          ownerUserId: 'user-001',
          babyId: 'baby-001',
        );
        final overviewRepository = _FakeProfileOverviewRepository();
        final records = _FakeRecordsRepository();

        final first = _controller(
          overviewRepository: overviewRepository,
          records: records,
          cache: cache,
          now: () => clock,
        );
        await first.initialize();
        first.dispose();

        clock = clock.add(const Duration(seconds: 20));
        final second = _controller(
          overviewRepository: overviewRepository,
          records: records,
          cache: cache,
          now: () => clock,
        );
        addTearDown(second.dispose);

        await second.initialize();
        expect(overviewRepository.fetchCount, 1);
        expect(records.milkTrendFetchCount, 1);

        await second.refresh();
        expect(overviewRepository.fetchCount, 2);
        expect(records.milkTrendFetchCount, 2);
      },
    );

    test(
      'Baby saves a valid growth measurement and refreshes local state',
      () async {
        final records = _FakeRecordsRepository();
        final controller = _controller(
          records: records,
          identity: ProfileIdentity.baby,
        );
        addTearDown(controller.dispose);
        await controller.initialize();

        final saved = await controller.saveGrowth(weightKg: 6.4);

        expect(saved, isTrue);
        expect(records.growthCreateCount, 1);
        expect(records.savedWeightKg, 6.4);
        expect(controller.growthRecords.value.data?.first.weightKg, 6.4);
        expect(
          controller.growthMutation.value.phase,
          ProfileOverviewMutationPhase.success,
        );
      },
    );

    test(
      'Baby rejects an invalid growth measurement before the API call',
      () async {
        final records = _FakeRecordsRepository();
        final controller = _controller(
          records: records,
          identity: ProfileIdentity.baby,
        );
        addTearDown(controller.dispose);

        final saved = await controller.saveGrowth(weightKg: 0);

        expect(saved, isFalse);
        expect(records.growthCreateCount, 0);
        expect(
          controller.growthMutation.value.phase,
          ProfileOverviewMutationPhase.error,
        );
      },
    );

    test(
      'Baby updates today’s growth record instead of duplicating it',
      () async {
        final records = _FakeRecordsRepository(
          growth: [
            GrowthRecord(
              id: 'growth-today',
              weightGram: 6400,
              measuredAt: DateTime(2026, 7, 11, 8),
            ),
          ],
        );
        final controller = _controller(
          records: records,
          identity: ProfileIdentity.baby,
        );
        addTearDown(controller.dispose);
        await controller.initialize();

        final saved = await controller.saveGrowth(heightCm: 65);

        expect(saved, isTrue);
        expect(records.growthCreateCount, 0);
        expect(records.growthUpdateCount, 1);
        expect(records.savedHeightCm, 65);
      },
    );
  });
}

ProfileOverviewController _controller({
  _FakeProfileOverviewRepository? overviewRepository,
  _FakeRecordsRepository? records,
  ProfileOverviewCache? cache,
  ProfileIdentity identity = ProfileIdentity.mom,
  DateTime Function()? now,
}) {
  final effectiveRecords = records ?? _FakeRecordsRepository();
  return ProfileOverviewController(
    profileOverviewRepository:
        overviewRepository ?? _FakeProfileOverviewRepository(),
    feedingRepository: effectiveRecords,
    milkTrendRepository: effectiveRecords,
    growthRepository: effectiveRecords,
    babyId: 'baby-001',
    identity: identity,
    cache: cache,
    now: now ?? () => DateTime(2026, 7, 11, 10),
  );
}

class _FakeProfileOverviewRepository implements ProfileOverviewRepository {
  var fetchCount = 0;

  @override
  Future<ProfileOverview> fetchOverview() async {
    fetchCount += 1;
    return const ProfileOverview(
      mom: MomProfileOverview(stage: 'postpartum', postpartumDay: 42),
      baby: BabyProfileOverview(id: 'baby-001', nickname: 'Mia', ageDays: 42),
    );
  }
}

class _FakeRecordsRepository
    implements
        FeedingRecordsRepository,
        MilkTrendRepository,
        GrowthRecordsRepository {
  _FakeRecordsRepository({
    this.feeding = const <FeedingRecord>[],
    this.growth = const <GrowthRecord>[],
    this.growthError,
  });

  final List<FeedingRecord> feeding;
  final List<GrowthRecord> growth;
  final Object? growthError;
  DateTime? milkTrendStart;
  var feedingFetchCount = 0;
  var milkTrendFetchCount = 0;
  var growthFetchCount = 0;
  var growthCreateCount = 0;
  var growthUpdateCount = 0;
  double? savedWeightKg;
  double? savedHeightCm;
  double? savedHeadCm;

  @override
  Future<List<FeedingRecord>> fetchFeedingRecords({
    required DateTime date,
  }) async {
    feedingFetchCount += 1;
    return feeding;
  }

  @override
  Future<List<MilkTrendDay>> fetchMilkTrends({
    required DateTime startDate,
    required int days,
    bool includeToday = true,
  }) async {
    milkTrendFetchCount += 1;
    milkTrendStart = startDate;
    return [
      MilkTrendDay(
        date: DateTime(2026, 7, 11),
        pumpedMilkVolumeMl: 120,
        pumpingCount: 2,
      ),
    ];
  }

  @override
  Future<List<GrowthRecord>> fetchGrowthRecords({
    required String babyId,
  }) async {
    growthFetchCount += 1;
    if (growthError != null) throw growthError!;
    return growth;
  }

  @override
  Future<GrowthRecord> createGrowthRecord({
    required String babyId,
    required DateTime measuredAt,
    double? weightKg,
    double? heightCm,
    double? headCm,
    String? idempotencyKey,
  }) async {
    growthCreateCount += 1;
    savedWeightKg = weightKg;
    savedHeightCm = heightCm;
    savedHeadCm = headCm;
    return GrowthRecord(
      id: 'growth-created',
      weightGram: weightKg == null ? null : (weightKg * 1000).round(),
      heightCm: heightCm,
      headCm: headCm,
      measuredAt: measuredAt,
    );
  }

  @override
  Future<GrowthRecord> updateGrowthRecord({
    required String recordId,
    double? weightKg,
    double? heightCm,
    double? headCm,
  }) async {
    growthUpdateCount += 1;
    savedWeightKg = weightKg;
    savedHeightCm = heightCm;
    savedHeadCm = headCm;
    return GrowthRecord(
      id: recordId,
      weightGram: weightKg == null ? null : (weightKg * 1000).round(),
      heightCm: heightCm,
      headCm: headCm,
      measuredAt: DateTime(2026, 7, 11, 10),
    );
  }
}
