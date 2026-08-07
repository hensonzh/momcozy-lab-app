import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/records/domain/records.dart';
import 'package:momcozy_flutter_app/features/profile_overview/domain/profile_overview.dart';
import 'package:momcozy_flutter_app/features/profile_overview/domain/mom_life_stage.dart';
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
      'stage changes publish saving and success without refetching',
      () async {
        final overviewRepository = _FakeProfileOverviewRepository();
        final controller = _controller(overviewRepository: overviewRepository);
        addTearDown(controller.dispose);
        await controller.initialize();

        final request = controller.updateCareStage(MomLifeStage.pregnancy);

        expect(controller.careStage.value.isSaving, isTrue);
        await request;
        expect(controller.careStage.value.stage, MomLifeStage.pregnancy);
        expect(controller.careStage.value.isSaving, isFalse);
        expect(controller.careStage.value.error, isNull);
        expect(overviewRepository.updatedStages, [MomLifeStage.pregnancy]);
        expect(
          controller.overview.value.data?.mom?.stage,
          MomLifeStage.pregnancy,
        );
      },
    );

    test('selecting the current stage does not write again', () async {
      final overviewRepository = _FakeProfileOverviewRepository();
      final controller = _controller(overviewRepository: overviewRepository);
      addTearDown(controller.dispose);
      await controller.initialize();

      final changed = await controller.updateCareStage(MomLifeStage.postpartum);

      expect(changed, isTrue);
      expect(overviewRepository.updatedStages, isEmpty);
    });

    test(
      'failed stage changes keep the previous workspace and expose retry state',
      () async {
        final overviewRepository = _FakeProfileOverviewRepository(
          updateError: StateError('offline'),
        );
        final controller = _controller(overviewRepository: overviewRepository);
        addTearDown(controller.dispose);
        await controller.initialize();

        final changed = await controller.updateCareStage(
          MomLifeStage.fertility,
        );

        expect(changed, isFalse);
        expect(controller.careStage.value.stage, MomLifeStage.postpartum);
        expect(controller.careStage.value.isSaving, isFalse);
        expect(controller.careStage.value.error, isNotNull);
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
  _FakeProfileOverviewRepository({this.updateError});

  final Object? updateError;
  var fetchCount = 0;
  final List<MomLifeStage> updatedStages = [];

  @override
  Future<ProfileOverview> fetchOverview() async {
    fetchCount += 1;
    return const ProfileOverview(
      mom: MomProfileOverview(
        stage: MomLifeStage.postpartum,
        postpartumDay: 42,
      ),
      baby: BabyProfileOverview(id: 'baby-001', nickname: 'Mia', ageDays: 42),
    );
  }

  @override
  Future<MomLifeStage> updateCareStage(MomLifeStage stage) async {
    updatedStages.add(stage);
    if (updateError != null) throw updateError!;
    return stage;
  }
}

class _FakeRecordsRepository
    implements
        FeedingRecordsRepository,
        MilkTrendRepository,
        GrowthRecordsRepository {
  _FakeRecordsRepository({
    this.feeding = const <FeedingRecord>[],
    this.growthError,
  });

  final List<FeedingRecord> feeding;
  final Object? growthError;
  DateTime? milkTrendStart;
  var feedingFetchCount = 0;
  var milkTrendFetchCount = 0;
  var growthFetchCount = 0;

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
    return const <GrowthRecord>[];
  }

  @override
  Future<GrowthRecord> createGrowthRecord({
    required String babyId,
    required DateTime measuredAt,
    double? weightKg,
    double? heightCm,
    double? headCm,
    String? idempotencyKey,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<GrowthRecord> updateGrowthRecord({
    required String recordId,
    double? weightKg,
    double? heightCm,
    double? headCm,
  }) {
    throw UnimplementedError();
  }
}
