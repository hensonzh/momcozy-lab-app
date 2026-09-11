@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/care/care_plan.dart';
import 'package:momcozy_flutter_app/domain/care/service_package.dart';
import 'package:momcozy_flutter_app/domain/shared/local_date.dart';
import 'package:momcozy_flutter_app/modules/schedule/data/schedule_api_repository.dart';
import 'package:momcozy_flutter_app/modules/schedule/domain/schedule.dart';
import 'package:momcozy_flutter_app/modules/schedule/presentation/schedule_page.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('schedule month and selected day agenda at $width / $scale', (
        tester,
      ) async {
        await loadMomCozyTestFonts();
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: momCozyTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: SchedulePage(
              repository: _ScheduleRepository(),
              timezoneProvider: () async => 'Asia/Shanghai',
              catalogLoader: () async => _catalog,
              now: () => DateTime(2026, 9, 9, 10),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (scale == 1) {
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              width == 390
                  ? '../../goldens/product_baseline/schedule-390.png'
                  : '../../goldens/design_system/schedule-${width.toInt()}.png',
            ),
          );
        }
        await tester.tap(find.byIcon(Icons.chevron_right_rounded).first);
        await tester.pumpAndSettle();
        expect(find.textContaining('2026年10月'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
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

class _ScheduleRepository implements ScheduleRepository {
  final _entry = PersonalScheduleEntry(
    id: 'personal-1',
    title: '宝宝体检',
    date: LocalDate(2026, 9, 9),
    startTime: '09:30',
    note: '带好成长记录',
    updatedAt: DateTime.utc(2026, 9, 9),
  );

  @override
  Future<SchedulePageData> read({
    required LocalDate start,
    required LocalDate end,
    required String timezone,
    int offset = 0,
    int limit = 100,
  }) async => SchedulePageData(
    personal: [_entry],
    appointments: const [],
    plans: const [],
    episodes: const [],
    serverTime: DateTime.utc(2026, 9, 9),
    hasMore: false,
  );

  @override
  Future<PersonalScheduleEntry> create({
    required String title,
    required LocalDate date,
    required String startTime,
    required String note,
    required String idempotencyKey,
  }) async => _entry;

  @override
  Future<PersonalScheduleEntry> update(
    PersonalScheduleEntry entry, {
    required String title,
    required LocalDate date,
    required String startTime,
    required String note,
  }) async => _entry;

  @override
  Future<void> delete(PersonalScheduleEntry entry) async {}

  @override
  Future<PublishedCarePlan> updateTask({
    required String publicationId,
    required String sourceKey,
    required int expectedVersion,
    required CareTaskStatus status,
  }) => throw UnimplementedError();
}
