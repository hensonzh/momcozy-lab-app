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
          sleep: const [
            SleepRecord(
              id: 'sleep-001',
              infantId: 'baby-001',
              type: 'nap',
              durationSeconds: 3600,
              startedAt: null,
              endedAt: null,
            ),
          ],
          diapers: const [
            DiaperRecord(
              id: 'diaper-001',
              infantId: 'baby-001',
              type: 'wet',
              changedAt: null,
            ),
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
        expect(
          controller.sleepRecords.value.data?.single.durationSeconds,
          3600,
        );
        expect(controller.diaperRecords.value.data?.single.type, 'wet');
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

    test('a refresh failure preserves previously loaded data', () async {
      final records = _FakeRecordsRepository();
      final controller = _controller(records: records);
      addTearDown(controller.dispose);
      await controller.initialize();
      final previous = controller.milkTrends.value.data;
      records.milkTrendError = StateError('offline');

      await controller.refresh();

      expect(controller.milkTrends.value.hasError, isTrue);
      expect(controller.milkTrends.value.data, same(previous));
    });

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
    test('a successful profile without a stage stays unselected', () async {
      final controller = _controller(
        overviewRepository: _FakeProfileOverviewRepository(
          overview: const ProfileOverview(),
        ),
      );
      addTearDown(controller.dispose);

      await controller.initialize();

      expect(controller.careStage.value.isResolved, isTrue);
      expect(controller.careStage.value.stage, isNull);
    });

    test('a failed profile read never invents a postpartum stage', () async {
      final controller = _controller(
        overviewRepository: _FakeProfileOverviewRepository(
          fetchError: StateError('offline'),
        ),
      );
      addTearDown(controller.dispose);

      await controller.initialize();

      expect(controller.overview.value.hasError, isTrue);
      expect(controller.careStage.value.isResolved, isFalse);
      expect(controller.careStage.value.stage, isNull);
      expect(controller.careStage.value.error, isNotNull);
    });

    test('Baby scopes feeding reads to the current session infant', () async {
      final records = _FakeRecordsRepository();
      final controller = _controller(
        records: records,
        identity: ProfileIdentity.baby,
      );
      addTearDown(controller.dispose);

      await controller.initialize();

      expect(records.feedingBabyId, 'baby-001');
      expect(records.feedingRangeStart, DateTime(2026, 7, 6));
      expect(records.feedingRangeEnd, DateTime(2026, 7, 13));
    });

    test(
      'Baby uses the resolved infant when the session id is stale',
      () async {
        final records = _FakeRecordsRepository();
        final controller = _controller(
          overviewRepository: _FakeProfileOverviewRepository(
            overview: const ProfileOverview(
              baby: BabyProfileOverview(id: 'baby-resolved'),
            ),
          ),
          records: records,
          identity: ProfileIdentity.baby,
        );
        addTearDown(controller.dispose);

        await controller.initialize();

        expect(records.feedingBabyId, 'baby-resolved');
      },
    );

    test('saving a pumping record refreshes measured milk trends', () async {
      final records = _FakeRecordsRepository();
      final controller = _controller(records: records);
      addTearDown(controller.dispose);
      await controller.initialize();

      final saved = await controller.savePumpingRecord(amountMl: 95);

      expect(saved, isTrue);
      expect(records.createdPumpingAmountMl, 95);
      expect(records.milkTrendFetchCount, 2);
      expect(controller.recordMutation.value.isSaving, isFalse);
      expect(controller.recordMutation.value.error, isNull);
    });

    test('saving a feeding record keeps the current infant scope', () async {
      final records = _FakeRecordsRepository();
      final controller = _controller(
        records: records,
        identity: ProfileIdentity.baby,
      );
      addTearDown(controller.dispose);
      await controller.initialize();

      final saved = await controller.saveFeedingRecord(
        type: 'bottle',
        amountMl: 80,
      );

      expect(saved, isTrue);
      expect(records.createdFeedingBabyId, 'baby-001');
      expect(records.createdFeedingAmountMl, 80);
      expect(records.feedingFetchCount, 2);
    });

    test(
      'saving baby-care records refreshes the current infant scope',
      () async {
        final records = _FakeRecordsRepository();
        final controller = _controller(
          records: records,
          identity: ProfileIdentity.baby,
        );
        addTearDown(controller.dispose);
        await controller.initialize();

        final sleepSaved = await controller.saveSleepRecord(
          startedAt: DateTime(2026, 7, 11, 8),
          endedAt: DateTime(2026, 7, 11, 10),
          type: 'nap',
        );
        final diaperSaved = await controller.saveDiaperRecord(type: 'mixed');

        expect(sleepSaved, isTrue);
        expect(diaperSaved, isTrue);
        expect(records.createdSleepBabyId, 'baby-001');
        expect(records.createdSleepType, 'nap');
        expect(records.sleepFetchCount, 2);
        expect(records.createdDiaperBabyId, 'baby-001');
        expect(records.createdDiaperType, 'mixed');
        expect(records.diaperFetchCount, 2);
      },
    );

    test('saving a growth record refreshes growth data', () async {
      final records = _FakeRecordsRepository();
      final controller = _controller(
        records: records,
        identity: ProfileIdentity.baby,
      );
      addTearDown(controller.dispose);
      await controller.initialize();

      final saved = await controller.saveGrowthRecord(weightKg: 6.3);

      expect(saved, isTrue);
      expect(records.createdGrowthBabyId, 'baby-001');
      expect(records.createdGrowthWeightKg, 6.3);
      expect(records.growthFetchCount, 2);
    });
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
    babyCareRepository: effectiveRecords,
    pumpMilkRepository: effectiveRecords,
    milkTrendRepository: effectiveRecords,
    growthRepository: effectiveRecords,
    babyId: 'baby-001',
    identity: identity,
    cache: cache,
    now: now ?? () => DateTime(2026, 7, 11, 10),
  );
}

class _FakeProfileOverviewRepository implements ProfileOverviewRepository {
  _FakeProfileOverviewRepository({
    this.updateError,
    this.fetchError,
    this.overview = const ProfileOverview(
      mom: MomProfileOverview(
        stage: MomLifeStage.postpartum,
        postpartumDay: 42,
      ),
      baby: BabyProfileOverview(id: 'baby-001', nickname: 'Mia', ageDays: 42),
    ),
  });

  final Object? updateError;
  final Object? fetchError;
  final ProfileOverview overview;
  var fetchCount = 0;
  final List<MomLifeStage> updatedStages = [];

  @override
  Future<ProfileOverview> fetchOverview() async {
    fetchCount += 1;
    if (fetchError != null) throw fetchError!;
    return overview;
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
        BabyCareRecordsRepository,
        PumpMilkRecordsRepository,
        MilkTrendRepository,
        GrowthRecordsRepository {
  _FakeRecordsRepository({
    this.feeding = const <FeedingRecord>[],
    this.sleep = const <SleepRecord>[],
    this.diapers = const <DiaperRecord>[],
    this.growth = const <GrowthRecord>[],
    this.growthError,
  });

  final List<FeedingRecord> feeding;
  final List<SleepRecord> sleep;
  final List<DiaperRecord> diapers;
  final List<GrowthRecord> growth;
  final Object? growthError;
  Object? milkTrendError;
  DateTime? milkTrendStart;
  var feedingFetchCount = 0;
  var sleepFetchCount = 0;
  var diaperFetchCount = 0;
  var milkTrendFetchCount = 0;
  var growthFetchCount = 0;
  var growthCreateCount = 0;
  var growthUpdateCount = 0;
  double? savedWeightKg;
  double? savedHeightCm;
  double? savedHeadCm;
  String? feedingBabyId;
  DateTime? feedingRangeStart;
  DateTime? feedingRangeEnd;
  String? createdFeedingBabyId;
  double? createdFeedingAmountMl;
  String? createdSleepBabyId;
  String? createdSleepType;
  String? createdDiaperBabyId;
  String? createdDiaperType;
  double? createdPumpingAmountMl;
  String? createdGrowthBabyId;
  double? createdGrowthWeightKg;

  @override
  Future<List<FeedingRecord>> fetchFeedingRecords({
    required DateTime date,
    required String babyId,
  }) async {
    feedingFetchCount += 1;
    feedingBabyId = babyId;
    return feeding;
  }

  @override
  Future<List<FeedingRecord>> fetchFeedingRecordsRange({
    required DateTime start,
    required DateTime end,
    required String babyId,
  }) async {
    feedingFetchCount += 1;
    feedingBabyId = babyId;
    feedingRangeStart = start;
    feedingRangeEnd = end;
    return feeding;
  }

  @override
  Future<FeedingRecord> createFeedingRecord({
    required String babyId,
    required DateTime occurredAt,
    required String type,
    double? amountMl,
    int? durationSeconds,
    String? idempotencyKey,
  }) async {
    createdFeedingBabyId = babyId;
    createdFeedingAmountMl = amountMl;
    return FeedingRecord(
      id: 'feeding-created',
      type: type,
      amountMl: amountMl?.round(),
      occurredAt: occurredAt,
    );
  }

  @override
  Future<List<SleepRecord>> fetchSleepRecordsRange({
    required DateTime start,
    required DateTime end,
    required String babyId,
  }) async {
    sleepFetchCount += 1;
    return sleep;
  }

  @override
  Future<SleepRecord> createSleepRecord({
    required String babyId,
    required DateTime startedAt,
    required DateTime endedAt,
    required String type,
    String notes = '',
    String? idempotencyKey,
  }) async {
    createdSleepBabyId = babyId;
    createdSleepType = type;
    return SleepRecord(
      id: 'sleep-created',
      infantId: babyId,
      type: type,
      durationSeconds: endedAt.difference(startedAt).inSeconds,
      startedAt: startedAt,
      endedAt: endedAt,
      notes: notes,
    );
  }

  @override
  Future<List<DiaperRecord>> fetchDiaperRecordsRange({
    required DateTime start,
    required DateTime end,
    required String babyId,
  }) async {
    diaperFetchCount += 1;
    return diapers;
  }

  @override
  Future<DiaperRecord> createDiaperRecord({
    required String babyId,
    required DateTime changedAt,
    required String type,
    String notes = '',
    String? idempotencyKey,
  }) async {
    createdDiaperBabyId = babyId;
    createdDiaperType = type;
    return DiaperRecord(
      id: 'diaper-created',
      infantId: babyId,
      type: type,
      changedAt: changedAt,
      notes: notes,
    );
  }

  @override
  Future<List<PumpMilkRecord>> fetchPumpMilkRecords({
    required DateTime date,
  }) async => const [];

  @override
  Future<List<PumpMilkRecord>> fetchPumpMilkRecordsRange({
    required DateTime start,
    required DateTime end,
  }) async => const [];

  @override
  Future<PumpMilkRecord> createPumpMilkRecord({
    required DateTime occurredAt,
    double? amountMl,
    int? durationSeconds,
    String? idempotencyKey,
  }) async {
    createdPumpingAmountMl = amountMl;
    return PumpMilkRecord(
      id: 'pumping-created',
      title: '',
      amountMl: amountMl?.round(),
      occurredAt: occurredAt,
    );
  }

  @override
  Future<List<MilkTrendDay>> fetchMilkTrends({
    required DateTime startDate,
    required int days,
    bool includeToday = true,
  }) async {
    milkTrendFetchCount += 1;
    milkTrendStart = startDate;
    if (milkTrendError != null) throw milkTrendError!;
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
    createdGrowthBabyId = babyId;
    createdGrowthWeightKg = weightKg;
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
