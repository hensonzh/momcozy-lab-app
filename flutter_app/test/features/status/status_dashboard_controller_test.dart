import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/records/domain/records.dart';
import 'package:momcozy_flutter_app/features/status/domain/birth_journey_plan.dart';
import 'package:momcozy_flutter_app/features/status/domain/pregnancy_diary.dart';
import 'package:momcozy_flutter_app/features/status/domain/status_overview.dart';
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
          pumpError: StateError('pump unavailable'),
        );
        final controller = _controller(records: records);
        addTearDown(controller.dispose);

        await controller.load();

        expect(controller.overview.value.phase, StatusResourcePhase.data);
        expect(controller.feedingRecords.value.data?.single.amountMl, 80);
        expect(controller.pumpRecords.value.hasError, isTrue);
        expect(controller.growthRecords.value.data?.first.id, 'growth-new');
        expect(
          controller.pregnancyDiaryEntries.value.phase,
          StatusResourcePhase.data,
        );
        expect(
          controller.birthJourneyPlan.value.phase,
          StatusResourcePhase.data,
        );
        expect(records.pumpRangeStart, DateTime(2026, 6, 12));
        expect(records.pumpRangeEnd, DateTime(2026, 7, 12));
      },
    );

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
      },
    );

    test('updates same-day growth and creates a new-day record', () async {
      final records = _FakeRecordsRepository(
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
      'optimistically toggles current plan todo and rolls back on failure',
      () async {
        final plans = _FakeBirthJourneyPlanRepository(
          plan: _birthJourneyPlan(),
          deferUpdate: true,
        );
        final controller = _controller(plans: plans);
        addTearDown(controller.dispose);
        await controller.load();

        final operation = controller.togglePlanTodo(
          taskId: 'task-current',
          completed: true,
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
          isTrue,
        );
        expect(controller.planMutation.value.isSaving, isTrue);

        plans.failDeferredUpdate();
        expect(await operation, isFalse);
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
        expect(controller.planMutation.value.message, '同步计划完成状态失败');

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
  });
}

StatusDashboardController _controller({
  _FakeRecordsRepository? records,
  _FakePregnancyDiaryRepository? diary,
  _FakeBirthJourneyPlanRepository? plans,
}) {
  final effectiveRecords = records ?? _FakeRecordsRepository();
  return StatusDashboardController(
    statusRepository: _FakeStatusRepository(),
    feedingRepository: effectiveRecords,
    pumpRepository: effectiveRecords,
    growthRepository: effectiveRecords,
    pregnancyDiaryRepository: diary ?? _FakePregnancyDiaryRepository(),
    birthJourneyPlanRepository:
        plans ?? _FakeBirthJourneyPlanRepository(plan: null),
    babyId: 'baby-001',
    now: () => DateTime(2026, 7, 11, 10),
  );
}

class _FakeStatusRepository implements StatusRepository {
  @override
  Future<StatusOverview> fetchOverview() async {
    return const StatusOverview(
      mom: MomStatus(stage: '哺乳期', postpartumDay: 42),
      baby: BabyStatus(id: 'baby-001', nickname: '宝宝', ageDays: 42),
    );
  }
}

class _FakeRecordsRepository
    implements
        FeedingRecordsRepository,
        PumpMilkRecordsRepository,
        GrowthRecordsRepository {
  _FakeRecordsRepository({
    this.feeding = const <FeedingRecord>[],
    this.growth = const <GrowthRecord>[],
    this.pumpError,
  });

  final List<FeedingRecord> feeding;
  final List<PumpMilkRecord> pumping = const <PumpMilkRecord>[];
  final List<GrowthRecord> growth;
  final Object? pumpError;
  DateTime? pumpRangeStart;
  DateTime? pumpRangeEnd;
  final List<String> updatedIds = [];
  var createdCount = 0;

  @override
  Future<List<FeedingRecord>> fetchFeedingRecords({
    required DateTime date,
  }) async {
    return feeding;
  }

  @override
  Future<List<PumpMilkRecord>> fetchPumpMilkRecords({
    required DateTime date,
  }) async {
    return pumping;
  }

  @override
  Future<List<PumpMilkRecord>> fetchPumpMilkRecordsRange({
    required DateTime start,
    required DateTime end,
  }) async {
    pumpRangeStart = start;
    pumpRangeEnd = end;
    if (pumpError != null) throw pumpError!;
    return pumping;
  }

  @override
  Future<List<GrowthRecord>> fetchGrowthRecords({
    required String babyId,
  }) async {
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

  void completeDeferredUpsert() {
    _upsertCompleter?.complete();
  }

  @override
  Future<List<PregnancyDiaryEntry>> fetchEntries({
    DateTime? startDate,
    DateTime? endDate,
    int limit = 30,
  }) async {
    return const <PregnancyDiaryEntry>[];
  }

  @override
  Future<PregnancyDiaryEntry> upsertEntry({
    required DateTime entryDate,
    required PregnancyDiaryDraft draft,
  }) async {
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
}

class _FakeBirthJourneyPlanRepository implements BirthJourneyPlanRepository {
  _FakeBirthJourneyPlanRepository({
    required this.plan,
    this.deferUpdate = false,
  });

  BirthJourneyPlan? plan;
  final bool deferUpdate;
  Completer<void>? _updateCompleter;

  void failDeferredUpdate() {
    _updateCompleter?.completeError(StateError('update failed'));
  }

  @override
  Future<BirthJourneyPlan?> fetchActivePlan() async => plan;

  @override
  Future<void> updateTodoCompletion({
    required String taskId,
    required bool completed,
  }) async {
    if (deferUpdate) {
      _updateCompleter = Completer<void>();
      await _updateCompleter!.future;
    }
    plan = plan?.withTodoCompletion(taskId, completed);
  }

  @override
  Future<void> deletePlan({required String planId}) async {
    plan = null;
  }
}

BirthJourneyPlan _birthJourneyPlan() {
  return const BirthJourneyPlan(
    id: 'plan-001',
    title: '孕期计划',
    summary: '',
    status: 'active',
    periods: [
      BirthJourneyPeriod(
        id: 'current',
        title: '当前阶段',
        subtitle: '',
        displayMode: 'expanded',
        status: 'current',
        items: [
          BirthJourneyTodo(
            id: 'task-current',
            title: '当前事项',
            priorityLabel: '重要',
            reason: '',
            steps: [],
            completed: false,
          ),
        ],
      ),
      BirthJourneyPeriod(
        id: 'future',
        title: '后续阶段',
        subtitle: '',
        displayMode: 'collapsed',
        status: 'upcoming',
        items: [
          BirthJourneyTodo(
            id: 'task-future',
            title: '未来事项',
            priorityLabel: '建议',
            reason: '',
            steps: [],
            completed: false,
          ),
        ],
      ),
    ],
  );
}
