import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/shared/local_date.dart';
import 'package:momcozy_flutter_app/domain/shared/product_failure.dart';
import 'package:momcozy_flutter_app/modules/schedule/data/schedule_api_repository.dart';
import 'package:momcozy_flutter_app/modules/schedule/domain/schedule.dart';
import 'package:momcozy_flutter_app/modules/schedule/presentation/schedule_page.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import '../../support/momcozy_test_fonts.dart';

class MemoryScheduleRepository implements ScheduleRepository {
  final values = <PersonalScheduleEntry>[];
  final keys = <String>[];
  final created = <String, PersonalScheduleEntry>{};
  bool failCreate = false;
  Completer<void>? pendingCreate;
  @override
  Future<SchedulePageData> read({
    required LocalDate start,
    required LocalDate end,
    required String timezone,
    int offset = 0,
    int limit = 100,
  }) async => SchedulePageData(
    personal: values,
    serverTime: DateTime.utc(2026, 9, 12),
    hasMore: false,
  );
  @override
  Future<PersonalScheduleEntry> create({
    required String title,
    required LocalDate date,
    required String startTime,
    required String note,
    required String idempotencyKey,
  }) async {
    keys.add(idempotencyKey);
    await pendingCreate?.future;
    final entry = created.putIfAbsent(
      idempotencyKey,
      () => PersonalScheduleEntry(
        id: 'personal-${created.length + 1}',
        title: title,
        date: date,
        startTime: startTime,
        note: note,
        updatedAt: DateTime.utc(2026, 9, 12),
      ),
    );
    if (!values.any((value) => value.id == entry.id)) values.add(entry);
    if (failCreate) {
      failCreate = false;
      throw const ProductFailure(ProductFailureKind.unavailable);
    }
    return entry;
  }

  @override
  Future<PersonalScheduleEntry> update(
    PersonalScheduleEntry entry, {
    required String title,
    required LocalDate date,
    required String startTime,
    required String note,
  }) async {
    final updated = PersonalScheduleEntry(
      id: entry.id,
      title: title,
      date: date,
      startTime: startTime,
      note: note,
      updatedAt: DateTime.utc(2026, 9, 12, 1),
    );
    values.removeWhere((e) => e.id == entry.id);
    values.add(updated);
    return updated;
  }

  @override
  Future<void> delete(PersonalScheduleEntry entry) async {
    values.removeWhere((e) => e.id == entry.id);
  }
}

Future<void> mountSchedule(
  WidgetTester tester,
  MemoryScheduleRepository repo, {
  double width = 390,
  double scale = 1,
}) async {
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
      home: Scaffold(
        body: SchedulePage(
          repository: repo,
          timezoneProvider: () async => 'Asia/Shanghai',
          now: () => DateTime(2026, 9, 12),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadMomCozyTestFonts);
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('personal schedule create edit delete at $width/$scale', (
        tester,
      ) async {
        final repo = MemoryScheduleRepository();
        await mountSchedule(tester, repo, width: width, scale: scale);
        await tester.tap(find.byTooltip('Add to schedule'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<FilledButton>(find.byKey(const ValueKey('schedule-save')))
              .onPressed,
          isNull,
        );
        if (scale == 1) {
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              '../../goldens/design_system/schedule-create-${width.toInt()}.png',
            ),
          );
        }
        await tester.enterText(
          find.byKey(const ValueKey('schedule-title')),
          'Baby checkup',
        );
        await tester.pump();
        await tester.ensureVisible(find.byKey(const ValueKey('schedule-date')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('schedule-date')));
        await tester.pumpAndSettle();
        if (width == 390 && scale == 1) {
          await _editorShot(
            tester,
            find.byType(DatePickerDialog).evaluate().isNotEmpty
                ? 'date-picker'
                : 'time-picker',
          );
        }
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const ValueKey('schedule-time')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('schedule-time')));
        await tester.pumpAndSettle();
        if (width == 390 && scale == 1) {
          await _editorShot(
            tester,
            find.byType(DatePickerDialog).evaluate().isNotEmpty
                ? 'date-picker'
                : 'time-picker',
          );
        }
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const ValueKey('schedule-note')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('schedule-note')),
          'Bring the growth records',
        );
        await tester.pump();
        if (width == 320) {
          tester.view.viewInsets = const FakeViewPadding(bottom: 300);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          tester.view.resetViewInsets();
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(find.byKey(const ValueKey('schedule-save')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('schedule-save')));
        await tester.pumpAndSettle();
        expect(repo.values.single.note, 'Bring the growth records');
        expect(repo.values.single.startTime, '09:00');
        await tester.ensureVisible(
          find.byTooltip('More options for Baby checkup'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('More options for Baby checkup'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Edit'));
        await tester.pumpAndSettle();
        if (scale == 1) {
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              '../../goldens/design_system/schedule-edit-${width.toInt()}.png',
            ),
          );
        }
        await tester.enterText(
          find.byKey(const ValueKey('schedule-title')),
          'Baby checkup follow-up',
        );
        await tester.pump();
        await tester.tap(find.byTooltip('Close schedule item'));
        await tester.pumpAndSettle();
        expect(find.text('Leave this record?'), findsOneWidget);
        await tester.tap(find.text('Keep editing'));
        await tester.pumpAndSettle();
        expect(find.text('Baby checkup follow-up'), findsOneWidget);
        await tester.ensureVisible(find.byKey(const ValueKey('schedule-save')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('schedule-save')));
        await tester.pumpAndSettle();
        expect(repo.values.single.id, 'personal-1');
        await tester.ensureVisible(
          find.byTooltip('More options for Baby checkup follow-up'),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byTooltip('More options for Baby checkup follow-up'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();
        if (scale == 1) {
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              '../../goldens/design_system/schedule-delete-${width.toInt()}.png',
            ),
          );
        }
        await tester.ensureVisible(find.text('Keep item'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Keep item'));
        await tester.pumpAndSettle();
        expect(repo.values, hasLength(1));
        await tester.tap(
          find.byTooltip('More options for Baby checkup follow-up'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Delete item'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete item'));
        await tester.pumpAndSettle();
        expect(repo.values, isEmpty);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
  testWidgets(
    'short keyboard viewport can reach the preserved failure and retry',
    (tester) async {
      final repo = MemoryScheduleRepository()..failCreate = true;
      await mountSchedule(tester, repo, width: 320, scale: 2);
      tester.view.physicalSize = const Size(320, 568);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.tap(find.byTooltip('Add to schedule'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('schedule-title')),
        'Baby checkup',
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('schedule-save')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('schedule-save')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('schedule-save')));
      await tester.pumpAndSettle();
      expect(find.text('Try saving again'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Try saving again'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Try saving again'));
      await tester.pumpAndSettle();
      expect(repo.values, hasLength(1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('failed save preserves the draft and retries the same creation', (
    tester,
  ) async {
    final repo = MemoryScheduleRepository()..failCreate = true;
    await mountSchedule(tester, repo);
    await tester.tap(find.byTooltip('Add to schedule'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Baby checkup');
    await tester.pump();
    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('Baby checkup'), findsOneWidget);
    expect(find.text('Try saving again'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/design_system/schedule-save-failure-390.png',
      ),
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).first).enabled,
      isTrue,
    );
    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();
    expect(repo.values, hasLength(1));
    expect(repo.keys.toSet(), hasLength(1));
    expect(repo.keys, hasLength(2));
    expect(find.byType(TextField), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'edited retry recovers the original creation then updates without duplicates',
    (tester) async {
      final repo = MemoryScheduleRepository()..failCreate = true;
      await mountSchedule(tester, repo);
      await tester.tap(find.byTooltip('Add to schedule'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('schedule-title')),
        'Original event',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('schedule-save')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('schedule-title')),
        'Updated event',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('schedule-save')));
      await tester.pumpAndSettle();
      expect(repo.values, hasLength(1));
      expect(repo.values.single.title, 'Updated event');
      expect(repo.keys, hasLength(2));
      expect(repo.keys.toSet(), hasLength(1));
      expect(find.byTooltip('Close schedule item'), findsNothing);
    },
  );
  testWidgets('pending personal save locks edits and close then creates once', (
    tester,
  ) async {
    final repo = MemoryScheduleRepository()..pendingCreate = Completer<void>();
    await mountSchedule(tester, repo, width: 320, scale: 2);
    await tester.tap(find.byTooltip('Add to schedule'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('schedule-title')),
      'Single event',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('schedule-save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('schedule-save')));
    await tester.pump();
    expect(repo.keys, hasLength(1));
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('schedule-title')))
          .enabled,
      isFalse,
    );
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (w) => w is IconButton && w.tooltip == 'Close schedule item',
            ),
          )
          .onPressed,
      isNull,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Add to schedule'), findsOneWidget);
    await _editorShot(tester, 'save-busy-320-2x');
    repo.pendingCreate!.complete();
    await tester.pumpAndSettle();
    expect(repo.values, hasLength(1));
    expect(repo.keys, hasLength(1));
    expect(find.byTooltip('Close schedule item'), findsNothing);
  });
  testWidgets(
    'large editor date and time validation retain draft and accepted values',
    (tester) async {
      final repo = MemoryScheduleRepository();
      await mountSchedule(tester, repo, width: 320, scale: 2);
      tester.view.physicalSize = const Size(320, 568);
      await tester.tap(find.byTooltip('Add to schedule'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('schedule-title')),
        'Prepare for the checkup',
      );
      await tester.ensureVisible(find.byKey(const ValueKey('schedule-date')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('schedule-date')));
      await tester.pumpAndSettle();
      final strings = MaterialLocalizations.of(
        tester.element(find.byType(DatePickerDialog)),
      );
      await tester.enterText(
        find.byType(TextFormField),
        strings.formatCompactDate(DateTime(2030, 9, 15)),
      );
      await tester.ensureVisible(find.text(strings.okButtonLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(strings.okButtonLabel));
      await tester.pumpAndSettle();
      expect(find.text(strings.dateOutOfRangeLabel), findsOneWidget);
      await _editorShot(tester, 'date-range-error-320-2x-short');
      await tester.enterText(
        find.byType(TextFormField),
        strings.formatCompactDate(DateTime(2026, 9, 15)),
      );
      await tester.tap(find.text(strings.okButtonLabel));
      await tester.pumpAndSettle();
      expect(find.text('2026-09-15'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('schedule-time')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('schedule-time')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '25');
      await tester.ensureVisible(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('momcozy-time-picker')), findsOneWidget);
      await _editorShot(tester, 'time-error-320-2x-short');
      await tester.enterText(find.byType(TextFormField).first, '10');
      await tester.enterText(find.byType(TextFormField).last, '45');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('schedule-save')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('schedule-save')));
      await tester.pumpAndSettle();
      expect(repo.values.single.date, LocalDate(2026, 9, 15));
      expect(repo.values.single.startTime, '10:45');
      expect(repo.values.single.title, 'Prepare for the checkup');
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _editorShot(WidgetTester tester, String name) async {
  expect(tester.takeException(), isNull);
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('../../goldens/design_system/schedule-$name.png'),
  );
}
