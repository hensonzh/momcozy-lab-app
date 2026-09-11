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
