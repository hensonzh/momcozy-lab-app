import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/preferences/volume_unit_preference.dart';
import 'package:momcozy_flutter_app/features/pregnancy_diary/domain/pregnancy_diary_entry.dart';
import 'package:momcozy_flutter_app/features/pregnancy_plan/domain/pregnancy_plan.dart';
import 'package:momcozy_flutter_app/features/records/domain/records.dart';
import 'package:momcozy_flutter_app/features/status/data/status_preference_store.dart';
import 'package:momcozy_flutter_app/features/status/domain/status_overview.dart';
import 'package:momcozy_flutter_app/features/status/domain/status_selection.dart';
import 'package:momcozy_flutter_app/features/status/presentation/status_dashboard_cache.dart';
import 'package:momcozy_flutter_app/features/status/presentation/status_dashboard_controller.dart';

void main() {
  group('StatusDashboardController', () {
    test(
      'loads resources independently and keeps partial failures local',
      () async {
        final records = _FakeRecordsRepository(
          feeding: const [
            FeedingRecord(id: 'feed-001', type: 'bottle', amountMl: 80),
          ],
          growth: [
            GrowthRecord(id: 'growth-old', measuredAt: DateTime(2026, 7, 1)),
            GrowthRecord(id: 'growth-new', measuredAt: DateTime(2026, 7, 10)),
          ],
          milkTrendError: StateError('trend unavailable'),
        );
        final controller = _controller(records: records);
        addTearDown(controller.dispose);

        await controller.load();

        expect(controller.overview.value.phase, StatusResourcePhase.data);
        expect(controller.feedingRecords.value.data?.single.amountMl, 80);
        expect(controller.milkTrends.value.hasError, isTrue);
        expect(controller.growthRecords.value.data?.first.id, 'growth-new');
        expect(
          controller.pregnancyDiaryEntries.value.phase,
          StatusResourcePhase.data,
        );
        expect(
          controller.birthJourneyPlan.value.phase,
          StatusResourcePhase.data,
        );
        expect(records.milkTrendStart, DateTime(2026, 6, 11));
        expect(records.milkTrendDays, 31);
        expect(records.milkTrendIncludeToday, isTrue);
      },
    );

    test(
      'coalesces concurrent loads and keeps silent refresh data visible',
      () async {
        final status = _FakeStatusRepository(deferFetch: true);
        final controller = _controller(status: status);
        addTearDown(controller.dispose);

        final first = controller.load();
        final duplicate = controller.load();
        expect(status.fetchCount, 1);
        expect(controller.overview.value.isLoading, isTrue);
        status.completeFetch();
        await Future.wait([first, duplicate]);

        status.deferFetch = true;
        final refresh = controller.refresh();
        expect(status.fetchCount, 2);
        expect(controller.overview.value.phase, StatusResourcePhase.data);
        status.completeFetch();
        await refresh;
      },
    );

    test(
      'runs a trailing refresh after an external change during load',
      () async {
        final status = _FakeStatusRepository(deferFetch: true);
        final controller = _controller(status: status);
        addTearDown(controller.dispose);

        final initial = controller.load();
        final externalRefresh = controller.refreshAfterExternalChange();
        expect(status.fetchCount, 1);

        status.completeFetch();
        await Future.wait([initial, externalRefresh]);

        expect(status.fetchCount, 2);
      },
    );

    test('reuses a fresh owner-scoped snapshot without repository reads', () async {
      var clock = DateTime(2026, 7, 11, 10);
      final cache = StatusDashboardCache(
        ownerUserId: 'user-001',
        babyId: 'baby-001',
      );
      final status = _FakeStatusRepository();
      final records = _FakeRecordsRepository();
      final diary = _FakePregnancyDiaryRepository();
      final plans = _FakePregnancyPlanRepository(plan: _pregnancyPlan());
      final first = _controller(
        status: status,
        records: records,
        diary: diary,
        plans: plans,
        cache: cache,
        now: () => clock,
      );
      await first.load();
      first.dispose();

      final countsAfterFirstLoad = (
        status: status.fetchCount,
        feeding: records.feedingFetchCount,
        milk: records.milkTrendFetchCount,
        growth: records.growthFetchCount,
        diary: diary.fetchCount,
        plan: plans.fetchCount,
      );
      clock = clock.add(const Duration(seconds: 30));
      final second = _controller(
        status: status,
        records: records,
        diary: diary,
        plans: plans,
        cache: cache,
        now: () => clock,
      );
      addTearDown(second.dispose);

      expect(second.birthJourneyPlan.value.phase, StatusResourcePhase.data);
      expect(second.birthJourneyPlan.value.data?.id, 'plan-001');
      await second.load();

      expect(
        (
          status: status.fetchCount,
          feeding: records.feedingFetchCount,
          milk: records.milkTrendFetchCount,
          growth: records.growthFetchCount,
          diary: diary.fetchCount,
          plan: plans.fetchCount,
        ),
        countsAfterFirstLoad,
      );
    });

    test('renders stale data first and refreshes each expired resource', () async {
      var clock = DateTime(2026, 7, 11, 10);
      final cache = StatusDashboardCache(
        ownerUserId: 'user-001',
        babyId: 'baby-001',
      );
      final status = _FakeStatusRepository();
      final records = _FakeRecordsRepository();
      final diary = _FakePregnancyDiaryRepository();
      final plans = _FakePregnancyPlanRepository(plan: _pregnancyPlan());
      final first = _controller(
        status: status,
        records: records,
        diary: diary,
        plans: plans,
        cache: cache,
        now: () => clock,
      );
      await first.load();
      first.dispose();

      clock = clock.add(const Duration(minutes: 6));
      final second = _controller(
        status: status,
        records: records,
        diary: diary,
        plans: plans,
        cache: cache,
        now: () => clock,
      );
      addTearDown(second.dispose);
      expect(second.birthJourneyPlan.value.data?.id, 'plan-001');
      expect(second.birthJourneyPlan.value.isLoading, isFalse);

      await second.load();

      expect(status.fetchCount, 2);
      expect(records.feedingFetchCount, 2);
      expect(records.milkTrendFetchCount, 2);
      expect(records.growthFetchCount, 2);
      expect(diary.fetchCount, 2);
      expect(plans.fetchCount, 2);
    });

    test('refreshes plan and diary changes without fetching unrelated resources', () async {
      final status = _FakeStatusRepository();
      final records = _FakeRecordsRepository();
      final diary = _FakePregnancyDiaryRepository();
      final plans = _FakePregnancyPlanRepository(plan: _pregnancyPlan());
      final controller = _controller(
        status: status,
        records: records,
        diary: diary,
        plans: plans,
      );
      addTearDown(controller.dispose);
      await controller.load();

      await controller.refreshPregnancyPlan();
      expect(plans.fetchCount, 2);
      expect(diary.fetchCount, 1);
      expect(status.fetchCount, 1);
      expect(records.totalFetchCount, 3);

      await controller.refreshPregnancyDiary();
      expect(plans.fetchCount, 2);
      expect(diary.fetchCount, 2);
      expect(status.fetchCount, 1);
      expect(records.totalFetchCount, 3);
    });

    test(
      'validates and saves a diary entry into the local projection',
      () async {
        final diary = _FakePregnancyDiaryRepository();
        final controller = _controller(diary: diary);
        addTearDown(controller.dispose);
        await controller.load();

        expect(
          await controller.saveDiary(
            entryDate: DateTime(2026, 7, 11),
            draft: const PregnancyDiaryDraft(),
          ),
          isFalse,
        );
        expect(controller.diaryMutation.value.message, '至少写下一项今天的状态或记录');

        expect(
          await controller.saveDiary(
            entryDate: DateTime(2026, 7, 11),
            draft: const PregnancyDiaryDraft(mood: '平稳'),
          ),
          isTrue,
        );
        expect(diary.lastDraft?.mood, '平稳');
        expect(controller.pregnancyDiaryEntries.value.data?.single.mood, '平稳');
        expect(
          controller.diaryMutation.value.phase,
          StatusMutationPhase.success,
        );
        expect(diary.createCount, 1);
        expect(diary.updateCount, 0);

        expect(
          await controller.saveDiary(
            entryDate: DateTime(2026, 7, 11),
            draft: const PregnancyDiaryDraft(mood: '开心'),
          ),
          isTrue,
        );
        expect(diary.createCount, 1);
        expect(diary.updateCount, 1);
      },
    );

    test('updates same-day growth and creates a new-day record', () async {
      final records = _FakeRecordsRepository(
        milkTrends: [
          MilkTrendDay(
            date: DateTime(2026, 7, 10),
            pumpedMilkVolumeMl: 180,
            pumpingCount: 2,
          ),
        ],
        growth: [
          GrowthRecord(
            id: 'growth-today',
            measuredAt: DateTime(2026, 7, 11, 7),
          ),
        ],
      );
      final controller = _controller(records: records);
      addTearDown(controller.dispose);
      await controller.load();

      expect(controller.milkTrends.value.data?.single.pumpingCount, 2);

      expect(
        await controller.saveGrowth(weightKg: 4.3, heightCm: 55, headCm: 36.5),
        isTrue,
      );
      expect(records.updatedIds, ['growth-today']);
      expect(records.createdCount, 0);

      final nextDayRecords = _FakeRecordsRepository(
        growth: [
          GrowthRecord(
            id: 'growth-yesterday',
            measuredAt: DateTime(2026, 7, 10, 7),
          ),
        ],
      );
      final nextDayController = _controller(records: nextDayRecords);
      addTearDown(nextDayController.dispose);
      await nextDayController.load();

      expect(
        await nextDayController.saveGrowth(
          weightKg: 4.4,
          heightCm: 55.5,
          headCm: 36.7,
        ),
        isTrue,
      );
      expect(nextDayRecords.createdCount, 1);
      expect(nextDayRecords.updatedIds, isEmpty);
    });

    test(
      'hands current todo completion to the Agent without an API write',
      () async {
        final plans = _FakePregnancyPlanRepository(plan: _pregnancyPlan());
        final controller = _controller(plans: plans);
        addTearDown(controller.dispose);
        await controller.load();

        expect(
          await controller.togglePlanTodo(
            taskId: 'task-current',
            completed: true,
          ),
          isTrue,
        );
        expect(
          controller
              .birthJourneyPlan
              .value
              .data
              ?.periods
              .first
              .items
              .first
              .completed,
          isFalse,
        );
        expect(plans.deleteIds, isEmpty);
        expect(
          controller.planMutation.value.message,
          '请通过 CozyMate 同步该事项的完成状态',
        );

        expect(
          await controller.togglePlanTodo(
            taskId: 'task-future',
            completed: true,
          ),
          isFalse,
        );
        expect(controller.planMutation.value.message, '当前还未到该阶段，暂不适合进行该事项');
      },
    );

    test('does not publish mutation results after disposal', () async {
      final diary = _FakePregnancyDiaryRepository(deferUpsert: true);
      final controller = _controller(diary: diary);
      await controller.load();

      final operation = controller.saveDiary(
        entryDate: DateTime(2026, 7, 11),
        draft: const PregnancyDiaryDraft(mood: '平稳'),
      );
      expect(controller.diaryMutation.value.isSaving, isTrue);

      controller.dispose();
      diary.completeDeferredUpsert();

      expect(await operation, isFalse);
    });

    test(
      'restores care stage and enforces the pregnancy identity constraint',
      () async {
        final preferences = _FakeStatusPreferenceStore(
          storedStage: StatusCareStage.pregnancy,
        );
        final controller = _controller(
          preferences: preferences,
          initialIdentity: StatusIdentity.baby,
        );
        addTearDown(controller.dispose);

        await controller.restoreSelection();

        expect(controller.careStage.value, StatusCareStage.pregnancy);
        expect(controller.identity.value, StatusIdentity.mom);
        expect(controller.selectionReady.value, isTrue);
        expect(controller.selectIdentity(StatusIdentity.baby), isFalse);

        await controller.changeCareStage(StatusCareStage.postpartum);
        expect(controller.selectIdentity(StatusIdentity.baby), isTrue);
        await controller.changeCareStage(StatusCareStage.pregnancy);

        expect(controller.identity.value, StatusIdentity.mom);
        expect(preferences.writes, [
          StatusCareStage.postpartum,
          StatusCareStage.pregnancy,
        ]);
      },
    );

    test(
      'does not let a late preference read overwrite a user selection',
      () async {
        final preferences = _FakeStatusPreferenceStore(deferRead: true);
        final controller = _controller(preferences: preferences);
        addTearDown(controller.dispose);

        final restore = controller.restoreSelection();
        await controller.changeCareStage(StatusCareStage.pregnancy);
        preferences.completeRead(StatusCareStage.postpartum);
        await restore;

        expect(controller.careStage.value, StatusCareStage.pregnancy);
        expect(controller.selectionReady.value, isTrue);
      },
    );

    test('serializes rapid care stage preference writes', () async {
      final preferences = _FakeStatusPreferenceStore(deferWrites: true);
      final controller = _controller(preferences: preferences);
      addTearDown(controller.dispose);

      final first = controller.changeCareStage(StatusCareStage.pregnancy);
      final second = controller.changeCareStage(StatusCareStage.postpartum);
      await Future<void>.delayed(Duration.zero);

      expect(preferences.writes, [StatusCareStage.pregnancy]);
      preferences.completeNextWrite();
      await Future<void>.delayed(Duration.zero);
      expect(preferences.writes, [
        StatusCareStage.pregnancy,
        StatusCareStage.postpartum,
      ]);
      preferences.completeNextWrite();

      await Future.wait<void>([first, second]);
      expect(preferences.storedStage, StatusCareStage.postpartum);
    });

    test('restores and persists the global volume unit', () async {
      final volumePreferences = _FakeVolumeUnitPreferenceStore(
        stored: MomCozyVolumeUnit.ounces,
      );
      final controller = _controller(volumePreferences: volumePreferences);
      addTearDown(controller.dispose);

      await controller.restoreVolumeUnit();
      expect(controller.volumeUnit.value, MomCozyVolumeUnit.ounces);

      await controller.changeVolumeUnit(MomCozyVolumeUnit.milliliters);
      expect(controller.volumeUnit.value, MomCozyVolumeUnit.milliliters);
      expect(volumePreferences.writes, [MomCozyVolumeUnit.milliliters]);
    });
  });
}

StatusDashboardController _controller({
  _FakeStatusRepository? status,
  _FakeRecordsRepository? records,
  _FakePregnancyDiaryRepository? diary,
  _FakePregnancyPlanRepository? plans,
  _FakeStatusPreferenceStore? preferences,
  _FakeVolumeUnitPreferenceStore? volumePreferences,
  StatusDashboardCache? cache,
  DateTime Function()? now,
  StatusIdentity initialIdentity = StatusIdentity.mom,
}) {
  final effectiveRecords = records ?? _FakeRecordsRepository();
  return StatusDashboardController(
    statusRepository: status ?? _FakeStatusRepository(),
    feedingRepository: effectiveRecords,
    milkTrendRepository: effectiveRecords,
    growthRepository: effectiveRecords,
    pregnancyDiaryRepository: diary ?? _FakePregnancyDiaryRepository(),
    pregnancyPlanRepository: plans ?? _FakePregnancyPlanRepository(plan: null),
    preferenceStore: preferences ?? _FakeStatusPreferenceStore(),
    volumeUnitPreferenceStore:
        volumePreferences ?? _FakeVolumeUnitPreferenceStore(),
    initialIdentity: initialIdentity,
    babyId: 'baby-001',
    cache: cache,
    now: now ?? () => DateTime(2026, 7, 11, 10),
  );
}

class _FakeVolumeUnitPreferenceStore implements VolumeUnitPreferenceStore {
  _FakeVolumeUnitPreferenceStore({this.stored});

  MomCozyVolumeUnit? stored;
  final writes = <MomCozyVolumeUnit>[];

  @override
  Future<MomCozyVolumeUnit?> read() async => stored;

  @override
  Future<void> write(MomCozyVolumeUnit unit) async {
    writes.add(unit);
    stored = unit;
  }
}

class _FakeStatusPreferenceStore implements StatusPreferenceStore {
  _FakeStatusPreferenceStore({
    this.storedStage,
    this.deferRead = false,
    this.deferWrites = false,
  });

  StatusCareStage? storedStage;
  final bool deferRead;
  final bool deferWrites;
  final writes = <StatusCareStage>[];
  Completer<StatusCareStage?>? _readCompleter;
  final _writeCompleters = <Completer<void>>[];

  void completeRead(StatusCareStage? stage) {
    _readCompleter?.complete(stage);
  }

  void completeNextWrite() {
    _writeCompleters.removeAt(0).complete();
  }

  @override
  Future<StatusCareStage?> readCareStage() async {
    if (!deferRead) return storedStage;
    _readCompleter = Completer<StatusCareStage?>();
    return _readCompleter!.future;
  }

  @override
  Future<void> writeCareStage(StatusCareStage stage) async {
    writes.add(stage);
    if (deferWrites) {
      final completer = Completer<void>();
      _writeCompleters.add(completer);
      await completer.future;
    }
    storedStage = stage;
  }
}

class _FakeStatusRepository implements StatusRepository {
  _FakeStatusRepository({this.deferFetch = false});

  bool deferFetch;
  var fetchCount = 0;
  Completer<void>? _fetchCompleter;

  void completeFetch() {
    _fetchCompleter?.complete();
    _fetchCompleter = null;
  }

  @override
  Future<StatusOverview> fetchOverview() async {
    fetchCount += 1;
    if (deferFetch) {
      deferFetch = false;
      _fetchCompleter = Completer<void>();
      await _fetchCompleter!.future;
    }
    return const StatusOverview(
      mom: MomStatus(stage: '哺乳期', postpartumDay: 42),
      baby: BabyStatus(id: 'baby-001', nickname: '宝宝', ageDays: 42),
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
    this.milkTrends = const <MilkTrendDay>[],
    this.growth = const <GrowthRecord>[],
    this.milkTrendError,
  });

  final List<FeedingRecord> feeding;
  final List<MilkTrendDay> milkTrends;
  final List<GrowthRecord> growth;
  final Object? milkTrendError;
  DateTime? milkTrendStart;
  int? milkTrendDays;
  bool? milkTrendIncludeToday;
  final List<String> updatedIds = [];
  var createdCount = 0;
  var feedingFetchCount = 0;
  var milkTrendFetchCount = 0;
  var growthFetchCount = 0;

  int get totalFetchCount =>
      feedingFetchCount + milkTrendFetchCount + growthFetchCount;

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
    milkTrendDays = days;
    milkTrendIncludeToday = includeToday;
    if (milkTrendError != null) throw milkTrendError!;
    return milkTrends;
  }

  @override
  Future<List<GrowthRecord>> fetchGrowthRecords({
    required String babyId,
  }) async {
    growthFetchCount += 1;
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
    createdCount += 1;
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
    updatedIds.add(recordId);
    return GrowthRecord(
      id: recordId,
      weightGram: weightKg == null ? null : (weightKg * 1000).round(),
      heightCm: heightCm,
      headCm: headCm,
      measuredAt: DateTime(2026, 7, 11, 10),
    );
  }
}

class _FakePregnancyDiaryRepository implements PregnancyDiaryRepository {
  _FakePregnancyDiaryRepository({this.deferUpsert = false});

  final bool deferUpsert;
  PregnancyDiaryDraft? lastDraft;
  Completer<void>? _upsertCompleter;
  var createCount = 0;
  var updateCount = 0;
  var fetchCount = 0;

  void completeDeferredUpsert() {
    _upsertCompleter?.complete();
  }

  @override
  Future<List<PregnancyDiaryEntry>> fetchEntries({
    DateTime? startDate,
    DateTime? endDate,
    int limit = 30,
  }) async {
    fetchCount += 1;
    return const <PregnancyDiaryEntry>[];
  }

  @override
  Future<PregnancyDiaryEntry> createEntry({
    required DateTime entryDate,
    required PregnancyDiaryDraft draft,
  }) async {
    createCount += 1;
    if (deferUpsert) {
      _upsertCompleter = Completer<void>();
      await _upsertCompleter!.future;
    }
    lastDraft = draft;
    return PregnancyDiaryEntry(
      id: 'diary-001',
      entryDate: entryDate,
      mood: draft.mood,
    );
  }

  @override
  Future<PregnancyDiaryEntry> updateEntry({
    required DateTime entryDate,
    required PregnancyDiaryDraft draft,
  }) async {
    updateCount += 1;
    lastDraft = draft;
    return PregnancyDiaryEntry(
      id: 'diary-001',
      entryDate: entryDate,
      mood: draft.mood,
    );
  }

  @override
  Future<void> deleteEntry({required DateTime entryDate}) async {}
}

class _FakePregnancyPlanRepository implements PregnancyPlanRepository {
  _FakePregnancyPlanRepository({required this.plan});

  PregnancyPlan? plan;
  final deleteIds = <String>[];
  var fetchCount = 0;

  @override
  Future<PregnancyPlan?> fetchActivePlan() async {
    fetchCount += 1;
    return plan;
  }

  @override
  Future<void> deletePlan({required String planId}) async {
    deleteIds.add(planId);
    plan = null;
  }
}

PregnancyPlan _pregnancyPlan() {
  return const PregnancyPlan(
    id: 'plan-001',
    planType: 'pregnancy',
    title: '孕期计划',
    summary: '',
    status: 'active',
    source: 'agent_action',
    payload: {
      'card': {
        'card_type': 'birth_journey_plan_card',
        'card_json': {
          'todo_plan': {
            'periods': [
              {
                'id': 'current',
                'title': '当前阶段',
                'display_mode': 'expanded',
                'status': 'current',
                'items': [
                  {'id': 'task-current', 'title': '当前事项'},
                ],
              },
              {
                'id': 'future',
                'title': '后续阶段',
                'display_mode': 'collapsed',
                'status': 'upcoming',
                'items': [
                  {'id': 'task-future', 'title': '未来事项'},
                ],
              },
            ],
          },
        },
      },
    },
  );
}
