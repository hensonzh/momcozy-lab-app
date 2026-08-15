import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/plan/domain/plan_dashboard.dart';
import 'package:momcozy_flutter_app/features/records/domain/records.dart';
import 'package:momcozy_flutter_app/features/profile_overview/domain/delivery_type.dart';
import 'package:momcozy_flutter_app/features/profile_overview/domain/profile_overview.dart';
import 'package:momcozy_flutter_app/features/profile_overview/domain/maternal_care_overview.dart';
import 'package:momcozy_flutter_app/features/profile_overview/domain/mom_life_stage.dart';
import 'package:momcozy_flutter_app/features/profile_overview/domain/profile_identity.dart';
import 'package:momcozy_flutter_app/features/profile_overview/presentation/profile_overview_cache.dart';
import 'package:momcozy_flutter_app/features/profile_overview/presentation/profile_overview_controller.dart';

void main() {
  group('ProfileOverviewController', () {
    test(
      'default Product capability marks missing resources unavailable',
      () async {
        final records = _FakeRecordsRepository();
        final care = _FakeMaternalCareOverviewRepository(
          const MaternalCareOverview(),
        );
        final controller = _controller(
          records: records,
          maternalCareOverviewRepository: care,
          extendedProductResourcesEnabled: false,
        );
        addTearDown(controller.dispose);

        await controller.initialize();

        expect(controller.overview.value.phase, OverviewResourcePhase.data);
        expect(controller.milkTrends.value.phase, OverviewResourcePhase.data);
        expect(
          controller.maternalCareOverview.value.phase,
          OverviewResourcePhase.unavailable,
        );
        expect(
          controller.waterRecords.value.phase,
          OverviewResourcePhase.unavailable,
        );
        expect(
          controller.waterTrends.value.phase,
          OverviewResourcePhase.unavailable,
        );
        expect(
          controller.vitalRecords.value.phase,
          OverviewResourcePhase.unavailable,
        );
        expect(records.waterFetchCount, 0);
        expect(records.waterTrendFetchCount, 0);
        expect(records.vitalFetchCount, 0);
        expect(care.fetchCount, 0);
      },
    );

    test(
      'Baby keeps supported records when extended resources are off',
      () async {
        final records = _FakeRecordsRepository();
        final controller = _controller(
          records: records,
          identity: ProfileIdentity.baby,
          extendedProductResourcesEnabled: false,
        );
        addTearDown(controller.dispose);

        await controller.initialize();

        expect(
          controller.feedingRecords.value.phase,
          OverviewResourcePhase.data,
        );
        expect(
          controller.growthRecords.value.phase,
          OverviewResourcePhase.data,
        );
        expect(
          controller.feedingSummary.value.phase,
          OverviewResourcePhase.unavailable,
        );
        expect(
          controller.sleepRecords.value.phase,
          OverviewResourcePhase.unavailable,
        );
        expect(
          controller.diaperRecords.value.phase,
          OverviewResourcePhase.unavailable,
        );
        expect(records.feedingFetchCount, 1);
        expect(records.growthFetchCount, 1);
        expect(records.feedingSummaryFetchCount, 0);
        expect(records.sleepFetchCount, 0);
        expect(records.diaperFetchCount, 0);
      },
    );

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
      expect(controller.waterRecords.value.phase, OverviewResourcePhase.data);
      expect(controller.waterTrends.value.phase, OverviewResourcePhase.data);
      expect(controller.vitalRecords.value.phase, OverviewResourcePhase.data);
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
      expect(records.waterFetchCount, 1);
      expect(records.waterTrendFetchCount, 1);
      expect(records.vitalFetchCount, 1);
      expect(records.feedingFetchCount, 0);
      expect(records.growthFetchCount, 0);
      expect(records.milkTrendStart, DateTime(2026, 6, 11));
      expect(
        records.milkTrendUtcOffsetMinutes,
        DateTime(2026, 7, 11).timeZoneOffset.inMinutes,
      );
    });

    test('Me exposes confirmed active plans to the stage workspace', () async {
      final plans = _FakePlanRepository(
        PlanDashboard(
          weekOf: DateTime(2026, 7, 11),
          plans: const [
            CarePlan(
              id: 'prenatal-yoga',
              category: PlanCategory.yoga,
              title: 'Prenatal Yoga Program',
              summary: 'Confirmed plan',
            ),
          ],
        ),
      );
      final controller = _controller(planRepository: plans);
      addTearDown(controller.dispose);

      await controller.initialize();

      expect(plans.requestedDay, DateTime(2026, 7, 11));
      expect(
        controller.plans.value.data?.plans.single.title,
        'Prenatal Yoga Program',
      );
    });

    test('Me loads the authoritative maternal care overview', () async {
      final careOverviewRepository = _FakeMaternalCareOverviewRepository(
        const MaternalCareOverview(
          stage: MomLifeStage.pregnancy,
          pregnancy: PregnancyProgress(
            state: PregnancyProgressState.ready,
            gestationalWeek: 28,
            daysRemaining: 84,
            trimester: PregnancyTrimester.third,
          ),
          program: MaternalProgramProgress(
            planId: 'prenatal-yoga',
            title: 'Prenatal Yoga Program',
            completedSessions: 6,
            totalSessions: 12,
          ),
        ),
      );
      final controller = _controller(
        maternalCareOverviewRepository: careOverviewRepository,
      );
      addTearDown(controller.dispose);

      await controller.initialize();

      expect(careOverviewRepository.fetchCount, 1);
      expect(careOverviewRepository.requestedDate, DateTime(2026, 7, 11));
      expect(
        controller.maternalCareOverview.value.phase,
        OverviewResourcePhase.data,
      );
      expect(
        controller.maternalCareOverview.value.data?.pregnancy?.gestationalWeek,
        28,
      );
    });

    test(
      'Baby loads feeding and growth while keeping failures local',
      () async {
        final records = _FakeRecordsRepository(
          feeding: const [
            FeedingRecord(
              id: 'feed-001',
              feedingMethod: FeedingMethod.bottle,
              milkComponents: [
                FeedingMilkComponent(
                  milkSource: MilkSource.breastMilk,
                  volumeMl: 80,
                ),
              ],
            ),
          ],
          sleep: [
            SleepRecord(
              id: 'sleep-001',
              infantId: 'baby-001',
              kind: SleepKind.nap,
              startedAt: DateTime(2026, 7, 11, 9),
              endedAt: DateTime(2026, 7, 11, 10),
            ),
          ],
          diapers: [
            DiaperRecord(
              id: 'diaper-001',
              infantId: 'baby-001',
              kind: DiaperKind.wet,
              changedAt: DateTime(2026, 7, 11, 9),
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
        expect(
          controller.feedingRecords.value.data?.single.measuredVolumeMl,
          80,
        );
        expect(controller.feedingSummary.value.data?.measuredVolumeMl, 175.5);
        expect(
          controller.sleepRecords.value.data?.single.durationSeconds,
          3600,
        );
        expect(controller.diaperRecords.value.data?.single.type, 'wet');
        expect(controller.sleepRecords.value.phase, OverviewResourcePhase.data);
        expect(
          controller.diaperRecords.value.phase,
          OverviewResourcePhase.data,
        );
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
      expect(records.feedingDays, 1);
      expect(records.feedingSummaryFetchCount, 1);
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
        await controller.saveGrowthRecord(
          measuredAt: DateTime.utc(2026, 7, 11),
          weightKg: 6.2,
          measurementContext: MeasurementContext.routine,
        );

        expect(records.feedingBabyId, 'baby-resolved');
        expect(records.createdGrowthBabyId, 'baby-resolved');
      },
    );

    test('saving a pumping record refreshes measured milk trends', () async {
      final records = _FakeRecordsRepository();
      final controller = _controller(records: records);
      addTearDown(controller.dispose);
      await controller.initialize();

      final saved = await controller.savePumpingRecord(
        startedAt: DateTime.utc(2026, 7, 11, 8),
        endedAt: DateTime.utc(2026, 7, 11, 8, 20),
        leftVolumeMl: 95,
        rightVolumeMl: 42.5,
        isPostFeedPumping: true,
      );

      expect(saved, isTrue);
      expect(records.createdPumpingAmountMl, 137.5);
      expect(records.createdPumpingOutputs, hasLength(2));
      expect(records.createdPumpingEndedAt, DateTime.utc(2026, 7, 11, 8, 20));
      expect(records.createdPumpingIsPostFeed, isTrue);
      expect(records.milkTrendFetchCount, 2);
      expect(controller.recordMutation.value.isSaving, isFalse);
      expect(controller.recordMutation.value.error, isNull);
    });

    test(
      'pumping requires both measured sides and a forward interval',
      () async {
        final records = _FakeRecordsRepository();
        final controller = _controller(records: records);
        addTearDown(controller.dispose);
        await controller.initialize();

        final missingRight = await controller.savePumpingRecord(
          startedAt: DateTime.utc(2026, 7, 11, 8),
          leftVolumeMl: 95,
          rightVolumeMl: 0,
        );
        final invalidInterval = await controller.savePumpingRecord(
          startedAt: DateTime.utc(2026, 7, 11, 8),
          endedAt: DateTime.utc(2026, 7, 11, 7, 59),
          leftVolumeMl: 95,
          rightVolumeMl: 42,
        );

        expect(missingRight, isFalse);
        expect(invalidInterval, isFalse);
        expect(records.pumpingCreateCount, 0);
      },
    );

    test('saving a feeding record keeps the current infant scope', () async {
      final records = _FakeRecordsRepository();
      final controller = _controller(
        records: records,
        identity: ProfileIdentity.baby,
      );
      addTearDown(controller.dispose);
      await controller.initialize();

      final saved = await controller.saveFeedingRecord(
        startedAt: DateTime.utc(2026, 7, 11, 9),
        feedingMethod: FeedingMethod.bottle,
        milkSource: MilkSource.breastMilk,
        amountMl: 80,
      );

      expect(saved, isTrue);
      expect(records.createdFeedingBabyId, 'baby-001');
      expect(records.createdFeedingAmountMl, 80);
      expect(records.feedingFetchCount, 2);
      expect(records.feedingSummaryFetchCount, 2);
    });

    test('feeding rejects missing bottle amount and reversed time', () async {
      final records = _FakeRecordsRepository();
      final controller = _controller(
        records: records,
        identity: ProfileIdentity.baby,
      );
      addTearDown(controller.dispose);
      await controller.initialize();

      final missingAmount = await controller.saveFeedingRecord(
        startedAt: DateTime.utc(2026, 7, 11, 9),
        feedingMethod: FeedingMethod.bottle,
      );
      final reversedTime = await controller.saveFeedingRecord(
        startedAt: DateTime.utc(2026, 7, 11, 9),
        endedAt: DateTime.utc(2026, 7, 11, 8, 59),
        feedingMethod: FeedingMethod.directBreastfeeding,
      );

      expect(missingAmount, isFalse);
      expect(reversedTime, isFalse);
      expect(records.createdFeedingBabyId, isNull);
    });

    test('saving a growth record refreshes growth data', () async {
      final records = _FakeRecordsRepository();
      final controller = _controller(
        records: records,
        identity: ProfileIdentity.baby,
      );
      addTearDown(controller.dispose);
      await controller.initialize();

      final saved = await controller.saveGrowthRecord(
        measuredAt: DateTime.utc(2026, 7, 11, 10),
        weightKg: 6.3,
        heightCm: 64,
        measurementContext: MeasurementContext.routine,
      );

      expect(saved, isTrue);
      expect(records.createdGrowthBabyId, 'baby-001');
      expect(records.createdGrowthWeightKg, 6.3);
      expect(records.savedHeightCm, 64);
      expect(records.growthFetchCount, 2);
      expect(records.feedingSummaryFetchCount, 2);
    });

    test('saving infant sleep and diaper records keeps infant scope', () async {
      final records = _FakeRecordsRepository();
      final controller = _controller(
        records: records,
        identity: ProfileIdentity.baby,
      );
      addTearDown(controller.dispose);
      await controller.initialize();

      final sleepSaved = await controller.saveSleepRecord(
        startedAt: DateTime.utc(2026, 7, 11, 11),
        endedAt: DateTime.utc(2026, 7, 11, 11, 45),
        kind: SleepKind.nap,
      );
      final diaperSaved = await controller.saveDiaperRecord(
        wetDiaperCount: 7,
        bowelMovementCount: 3,
        stoolConsistency: 'soft',
      );

      expect(sleepSaved, isTrue);
      expect(diaperSaved, isTrue);
      expect(records.createdSleepBabyId, 'baby-001');
      expect(records.createdSleepDuration, const Duration(minutes: 45));
      expect(records.createdDiaperBabyId, 'baby-001');
      expect(records.createdDiaperKind, DiaperKind.both);
      expect(records.createdWetDiaperCount, 7);
      expect(records.createdBowelMovementCount, 3);
      expect(records.sleepFetchCount, 2);
      expect(records.diaperFetchCount, 2);
    });
  });
}

ProfileOverviewController _controller({
  _FakeProfileOverviewRepository? overviewRepository,
  _FakeRecordsRepository? records,
  ProfileOverviewCache? cache,
  ProfileIdentity identity = ProfileIdentity.mom,
  DateTime Function()? now,
  PlanRepository? planRepository,
  MaternalCareOverviewRepository? maternalCareOverviewRepository,
  bool extendedProductResourcesEnabled = true,
}) {
  final effectiveRecords = records ?? _FakeRecordsRepository();
  return ProfileOverviewController(
    profileOverviewRepository:
        overviewRepository ?? _FakeProfileOverviewRepository(),
    feedingRepository: effectiveRecords,
    pumpMilkRepository: effectiveRecords,
    milkTrendRepository: effectiveRecords,
    growthRepository: effectiveRecords,
    waterRepository: effectiveRecords,
    waterTrendRepository: effectiveRecords,
    vitalRepository: effectiveRecords,
    sleepRepository: effectiveRecords,
    diaperRepository: effectiveRecords,
    planRepository: planRepository,
    maternalCareOverviewRepository: maternalCareOverviewRepository,
    babyId: 'baby-001',
    identity: identity,
    extendedProductResourcesEnabled: extendedProductResourcesEnabled,
    cache: cache,
    timezoneProvider: () async => 'Asia/Shanghai',
    now: now ?? () => DateTime(2026, 7, 11, 10),
  );
}

class _FakeMaternalCareOverviewRepository
    implements MaternalCareOverviewRepository {
  _FakeMaternalCareOverviewRepository(this.overview);

  final MaternalCareOverview overview;
  var fetchCount = 0;
  DateTime? requestedDate;

  @override
  Future<MaternalCareOverview> fetchOverview({required DateTime onDate}) async {
    fetchCount += 1;
    requestedDate = onDate;
    return overview;
  }
}

class _FakePlanRepository implements PlanRepository {
  _FakePlanRepository(this.dashboard);

  final PlanDashboard dashboard;
  DateTime? requestedDay;

  @override
  Future<PlanDashboard> fetchDashboard({required DateTime weekOf}) async {
    requestedDay = weekOf;
    return dashboard;
  }
}

class _FakeProfileOverviewRepository implements ProfileOverviewRepository {
  _FakeProfileOverviewRepository({
    this.fetchError,
    this.overview = const ProfileOverview(
      mom: MomProfileOverview(
        stage: MomLifeStage.postpartum,
        postpartumDay: 42,
      ),
      baby: BabyProfileOverview(id: 'baby-001', nickname: 'Mia', ageDays: 42),
    ),
  });

  final Object? fetchError;
  final ProfileOverview overview;
  var fetchCount = 0;

  @override
  Future<ProfileOverview> fetchOverview() async {
    fetchCount += 1;
    if (fetchError != null) throw fetchError!;
    return overview;
  }

  @override
  Future<DeliveryType?> updateDeliveryType(DeliveryType? deliveryType) async {
    return deliveryType;
  }
}

class _FakeRecordsRepository
    implements
        FeedingRecordsRepository,
        PumpMilkRecordsRepository,
        MilkTrendRepository,
        GrowthRecordsRepository,
        WaterRecordsRepository,
        WaterTrendRepository,
        VitalRecordsRepository,
        SleepRecordsRepository,
        DiaperRecordsRepository {
  _FakeRecordsRepository({
    this.feeding = const <FeedingRecord>[],
    this.sleep = const <SleepRecord>[],
    this.diapers = const <DiaperRecord>[],
    this.growthError,
  });

  final List<FeedingRecord> feeding;
  final List<SleepRecord> sleep;
  final List<DiaperRecord> diapers;
  final Object? growthError;
  Object? milkTrendError;
  DateTime? milkTrendStart;
  int? milkTrendUtcOffsetMinutes;
  var feedingFetchCount = 0;
  var sleepFetchCount = 0;
  var diaperFetchCount = 0;
  var milkTrendFetchCount = 0;
  var growthFetchCount = 0;
  var waterFetchCount = 0;
  var waterTrendFetchCount = 0;
  var vitalFetchCount = 0;
  double? savedHeightCm;
  String? feedingBabyId;
  DateTime? feedingRangeStart;
  DateTime? feedingRangeEnd;
  int? feedingDays;
  String? createdFeedingBabyId;
  double? createdFeedingAmountMl;
  String? createdSleepBabyId;
  String? createdDiaperBabyId;
  double? createdPumpingAmountMl;
  List<PumpingOutput> createdPumpingOutputs = const [];
  DateTime? createdPumpingEndedAt;
  bool? createdPumpingIsPostFeed;
  var pumpingCreateCount = 0;
  var feedingSummaryFetchCount = 0;
  Duration? createdSleepDuration;
  DiaperKind? createdDiaperKind;
  int? createdWetDiaperCount;
  int? createdBowelMovementCount;
  String? createdGrowthBabyId;
  double? createdGrowthWeightKg;

  @override
  Future<List<FeedingRecord>> fetchFeedingRecords({
    required DateTime date,
    required String babyId,
    int days = 1,
  }) async {
    feedingFetchCount += 1;
    feedingBabyId = babyId;
    feedingDays = days;
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
    required FeedingMethod feedingMethod,
    required List<FeedingMilkComponent> milkComponents,
    int? durationSeconds,
    FeedingBreastSide? breastSide,
    String? idempotencyKey,
  }) async {
    createdFeedingBabyId = babyId;
    createdFeedingAmountMl = milkComponents
        .map((component) => component.volumeMl)
        .whereType<double>()
        .fold<double>(0, (sum, value) => sum + value);
    return FeedingRecord(
      id: 'feeding-created',
      feedingMethod: feedingMethod,
      milkComponents: milkComponents,
      durationSeconds: durationSeconds,
      breastSide: breastSide,
      occurredAt: occurredAt,
    );
  }

  @override
  Future<FeedingSummary> fetchFeedingSummary({
    required String babyId,
    required int days,
    required String timezone,
  }) async {
    feedingSummaryFetchCount += 1;
    return _feedingSummary();
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
    DateTime? endedAt,
    required List<PumpingOutput> outputs,
    int? durationSeconds,
    bool? isPostFeedPumping,
    String? idempotencyKey,
  }) async {
    pumpingCreateCount += 1;
    createdPumpingAmountMl = outputs
        .map((output) => output.volumeMl)
        .whereType<double>()
        .fold<double>(0, (sum, value) => sum + value);
    createdPumpingOutputs = outputs;
    createdPumpingEndedAt = endedAt;
    createdPumpingIsPostFeed = isPostFeedPumping;
    return PumpMilkRecord(
      id: 'pumping-created',
      pumpType: 'manual',
      outputs: outputs,
      durationSeconds: durationSeconds,
      occurredAt: occurredAt,
      endedAt: endedAt,
      isPostFeedPumping: isPostFeedPumping,
    );
  }

  @override
  Future<List<WaterIntakeRecord>> fetchWaterRecords({
    required DateTime date,
  }) async {
    waterFetchCount += 1;
    return const [];
  }

  @override
  Future<WaterIntakeRecord> createWaterRecord({
    required DateTime occurredAt,
    required double amountMl,
    String? idempotencyKey,
  }) async {
    return WaterIntakeRecord(
      id: 'water-created',
      amountMl: amountMl,
      occurredAt: occurredAt,
    );
  }

  @override
  Future<List<WaterTrendDay>> fetchWaterTrends({
    required DateTime startDate,
    required int days,
    required int utcOffsetMinutes,
  }) async {
    waterTrendFetchCount += 1;
    return const [];
  }

  @override
  Future<List<VitalRecord>> fetchVitalRecords({
    DateTime? start,
    DateTime? end,
  }) async {
    vitalFetchCount += 1;
    return const [];
  }

  @override
  Future<VitalRecord> createVitalRecord({
    required DateTime measuredAt,
    double? weightKg,
    int? systolicMmhg,
    int? diastolicMmhg,
    int? heartRateBpm,
    double? temperatureC,
    String? idempotencyKey,
  }) async {
    return VitalRecord(
      id: 'vital-created',
      measuredAt: measuredAt,
      weightKg: weightKg,
      systolicMmhg: systolicMmhg,
      diastolicMmhg: diastolicMmhg,
      heartRateBpm: heartRateBpm,
      temperatureC: temperatureC,
    );
  }

  @override
  Future<List<SleepRecord>> fetchSleepRecords({
    required String babyId,
    required DateTime start,
    required DateTime end,
  }) async {
    sleepFetchCount += 1;
    return sleep;
  }

  @override
  Future<SleepRecord> createSleepRecord({
    required String babyId,
    required DateTime startedAt,
    DateTime? endedAt,
    required SleepKind kind,
    String? idempotencyKey,
  }) async {
    createdSleepBabyId = babyId;
    createdSleepDuration = endedAt?.difference(startedAt);
    return SleepRecord(
      id: 'sleep-created',
      infantId: babyId,
      startedAt: startedAt,
      endedAt: endedAt,
      kind: kind,
    );
  }

  @override
  Future<List<DiaperRecord>> fetchDiaperRecords({
    required String babyId,
    required DateTime start,
    required DateTime end,
  }) async {
    diaperFetchCount += 1;
    return diapers;
  }

  @override
  Future<DiaperRecord> createDiaperRecord({
    required String babyId,
    required DateTime changedAt,
    required DiaperKind kind,
    DiaperWetness? wetness,
    String? stoolColor,
    String? stoolConsistency,
    int? wetDiaperCount,
    int? bowelMovementCount,
    String notes = '',
    String? idempotencyKey,
  }) async {
    createdDiaperBabyId = babyId;
    createdDiaperKind = kind;
    createdWetDiaperCount = wetDiaperCount;
    createdBowelMovementCount = bowelMovementCount;
    return DiaperRecord(
      id: 'diaper-created',
      infantId: babyId,
      changedAt: changedAt,
      kind: kind,
      wetness: wetness,
      stoolColor: stoolColor,
      stoolConsistency: stoolConsistency,
      wetDiaperCount: wetDiaperCount,
      bowelMovementCount: bowelMovementCount,
      notes: notes,
    );
  }

  @override
  Future<List<MilkTrendDay>> fetchMilkTrends({
    required DateTime startDate,
    required int days,
    bool includeToday = true,
    int? utcOffsetMinutes,
  }) async {
    milkTrendFetchCount += 1;
    milkTrendStart = startDate;
    milkTrendUtcOffsetMinutes = utcOffsetMinutes;
    if (milkTrendError != null) throw milkTrendError!;
    return [
      MilkTrendDay(
        date: DateTime(2026, 7, 11),
        measuredVolumeMl: 120,
        pumpingCount: 2,
        measuredPumpingCount: 2,
      ),
    ];
  }

  @override
  Future<List<GrowthRecord>> fetchGrowthRecords({
    required String babyId,
  }) async {
    growthFetchCount += 1;
    if (growthError != null) throw growthError!;
    return const [];
  }

  @override
  Future<GrowthRecord> createGrowthRecord({
    required String babyId,
    required DateTime measuredAt,
    double? weightKg,
    double? heightCm,
    double? headCm,
    required MeasurementPosition measurementPosition,
    required MeasurementContext measurementContext,
    String? idempotencyKey,
  }) async {
    savedHeightCm = heightCm;
    createdGrowthBabyId = babyId;
    createdGrowthWeightKg = weightKg;
    return GrowthRecord(
      id: 'growth-created',
      weightGram: weightKg == null ? null : (weightKg * 1000).round(),
      heightCm: heightCm,
      headCm: headCm,
      measuredAt: measuredAt,
      measurementPosition: measurementPosition,
      measurementContext: measurementContext,
    );
  }

  @override
  Future<GrowthRecord> updateGrowthRecord({
    required String recordId,
    double? weightKg,
    double? heightCm,
    double? headCm,
    MeasurementPosition? measurementPosition,
    MeasurementContext? measurementContext,
  }) async {
    return GrowthRecord(
      id: recordId,
      weightGram: weightKg == null ? null : (weightKg * 1000).round(),
      heightCm: heightCm,
      headCm: headCm,
      measuredAt: DateTime(2026, 7, 11, 10),
      measurementPosition: measurementPosition ?? MeasurementPosition.recumbent,
      measurementContext: measurementContext ?? MeasurementContext.routine,
    );
  }
}

FeedingSummary _feedingSummary() => FeedingSummary(
  days: 7,
  timezone: 'Asia/Shanghai',
  feedingCount: 3,
  measuredVolumeCount: 2,
  measuredVolumeMl: 175.5,
  averageMeasuredVolumeMl: 87.75,
  feedingMethodCounts: const {
    FeedingMethod.bottle: 2,
    FeedingMethod.directBreastfeeding: 1,
  },
  milkSourceVolumesMl: const {
    MilkSource.breastMilk: 95.5,
    MilkSource.formula: 80,
  },
  latestFeedingAt: DateTime.parse('2026-07-02T08:00:00Z'),
  completedDays: CompletedFeedingDays(
    windowDays: 1,
    recordedDays: 0,
    measuredDays: 0,
    averageVolumePerMeasuredDayMl: null,
    averageFeedingsPerRecordedDay: null,
    dailySeries: [
      FeedingTrendDay(
        date: DateTime(2026, 7, 1),
        measuredVolumeMl: null,
        feedingCount: 0,
        measuredFeedingCount: 0,
      ),
    ],
  ),
  comparison: const MilkWindowComparison(
    status: 'insufficient_data',
    currentAverageVolumePerMeasuredDayMl: null,
    previousAverageVolumePerMeasuredDayMl: null,
    changePercent: null,
    currentMeasuredDays: 0,
    previousMeasuredDays: 0,
    minimumMeasuredDays: 5,
  ),
  intakeEvaluationContext: const IntakeEvaluationContext(
    status: IntakeEvaluationStatus.insufficientData,
    reasonCode: 'growth_record_missing',
    growthMeasurementDate: null,
    chronologicalAgeDays: null,
  ),
);
