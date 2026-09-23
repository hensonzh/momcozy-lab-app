import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/care/service_package.dart';
import 'package:momcozy_flutter_app/domain/care/care_plan.dart';
import 'package:momcozy_flutter_app/domain/shared/local_date.dart';
import 'package:momcozy_flutter_app/modules/schedule/application/schedule_controller.dart';
import 'package:momcozy_flutter_app/modules/schedule/data/schedule_api_repository.dart';
import 'package:momcozy_flutter_app/modules/schedule/domain/schedule.dart';

void main() {
  test(
    'loads a six-week calendar window and selects a month without derived ages',
    () async {
      final repository = _FakeScheduleRepository();
      final controller = ScheduleController(
        repository: repository,
        timezoneProvider: () async => 'Asia/Shanghai',
        catalogLoader: () async => _catalog,
        now: () => DateTime(2026, 9, 9, 10),
      );
      await controller.load();
      expect(repository.lastStart, LocalDate(2026, 8, 31));
      expect(repository.lastEnd, LocalDate(2026, 10, 12));
      expect(controller.state.selected, LocalDate(2026, 9, 9));
      controller.select(LocalDate(2026, 10, 1));
      expect(controller.state.month, LocalDate(2026, 10, 1));
      controller.dispose();
    },
  );

  test(
    'personal schedule mutations use the repository and reload authoritative state',
    () async {
      final repository = _FakeScheduleRepository();
      final controller = ScheduleController(
        repository: repository,
        timezoneProvider: () async => 'UTC',
        catalogLoader: () async => _catalog,
        now: () => DateTime(2026, 9, 9),
      );
      await controller.savePersonal(
        title: '宝宝体检',
        date: LocalDate(2026, 9, 9),
        startTime: '09:30',
        note: '带记录',
      );
      expect(repository.createdTitle, '宝宝体检');
      expect(repository.readCount, 1);
      await controller.deletePersonal(repository.entry);
      expect(repository.deletedId, 'personal-1');
      controller.dispose();
    },
  );
  ScheduleController controlled(_DeferredRepository repo) => ScheduleController(
    repository: repo,
    timezoneProvider: () async => 'UTC',
    catalogLoader: () async => _catalog,
    now: () => DateTime(2026, 9, 9),
  );
  test(
    'same-month selection does not read; returning to cache rejects a later month response',
    () async {
      final repo = _DeferredRepository();
      final c = controlled(repo);
      await c.load();
      final cached = c.state.page;
      c.select(LocalDate(2026, 9, 10));
      expect(repo.readCount, 1);
      final gate = Completer<SchedulePageData>();
      repo.nextRead = gate;
      c.select(LocalDate(2026, 10, 9));
      await Future<void>.delayed(Duration.zero);
      c.select(LocalDate(2026, 9, 12));
      gate.complete(repo.page('October'));
      await Future<void>.delayed(Duration.zero);
      expect(c.state.page, same(cached));
      expect(c.state.month, LocalDate(2026, 9, 1));
      expect(c.state.selected, LocalDate(2026, 9, 12));
      expect(c.state.phase, SchedulePhase.ready);
      c.dispose();
    },
  );
  test('out-of-order requests retain newest month and selected day', () async {
    final repo = _DeferredRepository();
    final c = controlled(repo);
    await c.load();
    final october = Completer<SchedulePageData>();
    repo.nextRead = october;
    c.select(LocalDate(2026, 10, 9));
    await Future<void>.delayed(Duration.zero);
    final november = Completer<SchedulePageData>();
    repo.nextRead = november;
    c.select(LocalDate(2026, 11, 9));
    await Future<void>.delayed(Duration.zero);
    c.select(LocalDate(2026, 11, 12));
    november.complete(repo.page('November'));
    await Future<void>.delayed(Duration.zero);
    october.complete(repo.page('October'));
    await Future<void>.delayed(Duration.zero);
    expect(c.state.page!.personal.single.title, 'November');
    expect(c.state.selected, LocalDate(2026, 11, 12));
    expect(repo.readCount, 3);
    c.dispose();
  });
  test(
    'save applies authoritative object; stale refresh cannot restore removed entries',
    () async {
      final repo = _DeferredRepository();
      final c = controlled(repo);
      await c.load();
      final gate = Completer<SchedulePageData>();
      repo.nextRead = gate;
      final refresh = c.load();
      await Future<void>.delayed(Duration.zero);
      final duplicate = c.load();
      expect(repo.readCount, 2);
      final saved = await c.savePersonal(
        title: 'client',
        date: LocalDate(2026, 9, 9),
        startTime: '09:30',
        note: '',
      );
      expect(c.state.page!.personal.single, same(saved));
      expect(saved.title, '宝宝体检');
      await c.deletePersonal(saved);
      expect(c.state.page!.personal, isEmpty);
      gate.complete(repo.page('stale'));
      await Future.wait([refresh, duplicate]);
      expect(c.state.page!.personal, isEmpty);
      expect(repo.readCount, 2);
      c.dispose();
    },
  );
}

final _catalog = ServiceCatalog(
  packages: [
    const ServicePackage(
      id: 'feeding-confidence',
      name: '喂养安心',
      subtitle: '',
      description: '',
      durationDays: 7,
      sessions: 2,
      priceMinor: 1,
      currency: 'USD',
      highlights: [],
      expertServices: [],
      continuousServices: [],
    ),
  ],
  providers: const [],
  availableRegions: const ['US'],
  paymentMode: PaymentMode.sandbox,
);

class _FakeScheduleRepository implements ScheduleRepository {
  LocalDate? lastStart, lastEnd;
  int readCount = 0;
  String? createdTitle, deletedId;
  final entry = PersonalScheduleEntry(
    id: 'personal-1',
    title: '宝宝体检',
    date: LocalDate(2026, 9, 9),
    startTime: '09:30',
    note: '',
    updatedAt: DateTime.utc(2026, 9, 9),
  );

  @override
  Future<SchedulePageData> read({
    required LocalDate start,
    required LocalDate end,
    required String timezone,
    int offset = 0,
    int limit = 100,
  }) async {
    lastStart = start;
    lastEnd = end;
    readCount++;
    return SchedulePageData(
      personal: [entry],
      appointments: const [],
      plans: const [],
      episodes: const [],
      serverTime: DateTime.utc(2026, 9, 9),
      hasMore: false,
    );
  }

  @override
  Future<PersonalScheduleEntry> create({
    required String title,
    required LocalDate date,
    required String startTime,
    required String note,
    required String idempotencyKey,
  }) async {
    createdTitle = title;
    return entry;
  }

  @override
  Future<PersonalScheduleEntry> update(
    PersonalScheduleEntry entry, {
    required String title,
    required LocalDate date,
    required String startTime,
    required String note,
  }) async => entry;
  @override
  Future<void> delete(PersonalScheduleEntry entry) async {
    deletedId = entry.id;
  }

  @override
  Future<PublishedCarePlan> updateTask({
    required String publicationId,
    required String sourceKey,
    required int expectedVersion,
    required CareTaskStatus status,
  }) async => throw UnimplementedError();
}

class _DeferredRepository extends _FakeScheduleRepository {
  Completer<SchedulePageData>? nextRead;
  SchedulePageData page(String title) => SchedulePageData(
    personal: [
      PersonalScheduleEntry(
        id: 'personal-1',
        title: title,
        date: LocalDate(2026, 9, 9),
        startTime: '09:30',
        note: '',
        updatedAt: DateTime.utc(2026, 9, 9),
      ),
    ],
    appointments: [],
    plans: [],
    episodes: [],
    serverTime: DateTime.utc(2026, 9, 9),
    hasMore: false,
  );
  @override
  Future<SchedulePageData> read({
    required LocalDate start,
    required LocalDate end,
    required String timezone,
    int offset = 0,
    int limit = 100,
  }) async {
    final pending = nextRead;
    nextRead = null;
    if (pending != null) {
      readCount++;
      return pending.future;
    }
    return super.read(
      start: start,
      end: end,
      timezone: timezone,
      offset: offset,
      limit: limit,
    );
  }
}
