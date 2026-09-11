import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/domain/mother/mother_diary.dart';
import 'package:momcozy_flutter_app/domain/shared/local_date.dart';
import 'package:momcozy_flutter_app/domain/shared/product_failure.dart';
import 'package:momcozy_flutter_app/modules/mom/application/mother_diary_controller.dart';
import 'package:momcozy_flutter_app/modules/mom/presentation/mother_diary_editor.dart';
import 'package:momcozy_flutter_app/services/mother/mother_diary_api_repository.dart';
import 'package:momcozy_flutter_app/services/mother/mother_diary_codec.dart';

import '../../support/fixture_api_transport.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  final date = LocalDate(2026, 9, 8);
  testWidgets(
    'app router opens the selected diary section with the current API',
    (tester) async {
      final transport = FixtureApiJsonTransport({'items': []});
      final router = createMomCozyRouter(
        initialLocation: '/me/diary?section=mood',
      );
      addTearDown(router.dispose);
      final runtime = MomCozyApiRuntime(
        jsonTransport: transport,
        now: () => DateTime(2026, 9, 8),
      );
      await tester.pumpWidget(
        MomCozyRuntimeScope(
          apiRuntime: runtime,
          child: MaterialApp.router(
            theme: momCozyTheme(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('今日心情'), findsOneWidget);
      expect(find.text('今天心里更接近哪一种'), findsOneWidget);
      expect(transport.lastPath, '/v1/mother/diary');
      expect(transport.lastQuery, {'start': '2026-09-08', 'end': '2026-09-08'});
    },
  );
  test(
    'repository writes canonical grouped fields, version and no owner override',
    () async {
      final transport = FixtureApiJsonTransport({
        'id': 'diary',
        'owner_user_id': 'mom',
        'entry_date': '2026-09-08',
        'version': 1,
        'updated_at': '2026-09-08T00:00:00Z',
        'diary': {
          'rest': {'total': '4-5h'},
        },
      });
      final repository = MotherDiaryApiRepository(transport: transport);
      final result = await repository.save(
        date: date,
        expectedVersion: 0,
        diary: const MotherDiary(
          rest: MotherRest(total: SleepTotalBand.fourToFiveHours),
        ),
      );
      expect(result.diary.rest.total, SleepTotalBand.fourToFiveHours);
      expect(transport.lastMethod, 'PUT');
      expect(transport.lastPath, '/v1/mother/diary/2026-09-08');
      expect(
        transport.lastBody!.keys,
        unorderedEquals(['expected_version', 'diary']),
      );
      expect(transport.lastBody!['expected_version'], 0);
      expect(
        () => readMotherDiary({'sleep_minutes': 240}),
        throwsFormatException,
      );
      expect(
        () => readMotherDiary({
          'mood': {'tone': 'legacy_calm'},
        }),
        throwsFormatException,
      );
      expect(
        () => readMotherDiary({
          'mood': {'note': 'retired field'},
        }),
        throwsFormatException,
      );
    },
  );

  test(
    'failure preserves draft and retry is versioned; duplicate taps save once',
    () async {
      final repository = DiaryFixture();
      final controller = MotherDiaryController(
        repository: repository,
        date: date,
      );
      addTearDown(controller.dispose);
      await controller.load();
      controller.edit(
        const MotherDiary(mood: MotherMood(tone: MoodTone.steady)),
      );
      repository.failure = const ProductFailure(ProductFailureKind.offline);
      expect(await controller.save(), false);
      expect(controller.draft.mood.tone, MoodTone.steady);
      expect(controller.dirty, true);
      expect(controller.failure!.kind, ProductFailureKind.offline);
      repository.failure = null;
      repository.gate = Completer<void>();
      final save = controller.save();
      expect(controller.phase, DiaryPhase.saving);
      expect(await controller.save(), false);
      repository.gate!.complete();
      expect(await save, true);
      expect(repository.saves, 2);
      expect(controller.dirty, false);
      expect(controller.saved!.version, 1);
    },
  );

  test('late async completion cannot notify a disposed editor', () async {
    final repository = DiaryFixture()..loadGate = Completer<void>();
    final controller = MotherDiaryController(
      repository: repository,
      date: date,
    );
    final load = controller.load();
    controller.dispose();
    repository.loadGate!.complete();
    await load;
  });

  testWidgets('three tabs preserve choices and saving shows a durable result', (
    tester,
  ) async {
    final repository = DiaryFixture();
    final controller = MotherDiaryController(
      repository: repository,
      date: date,
    );
    addTearDown(controller.dispose);
    await controller.load();
    await tester.pumpWidget(
      MaterialApp(
        theme: momCozyTheme(),
        home: Scaffold(
          body: MotherDiaryEditor(controller: controller, onClose: () {}),
        ),
      ),
    );
    await tester.tap(find.text('4–5 小时'));
    await tester.tap(find.text('心情'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('还算平稳'));
    await tester.tap(find.text('保存今天的记录'));
    await tester.pumpAndSettle();
    expect(find.text('今天的记录已保存'), findsOneWidget);
    expect(find.text('2/3 已记录'), findsOneWidget);
    expect(repository.entry!.diary.rest.total, SleepTotalBand.fourToFiveHours);
    expect(repository.entry!.diary.mood.tone, MoodTone.steady);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed loading has retry and does not look like a blank diary', (
    tester,
  ) async {
    final repository = DiaryFixture()
      ..failure = const ProductFailure(ProductFailureKind.forbidden);
    final controller = MotherDiaryController(
      repository: repository,
      date: date,
    );
    addTearDown(controller.dispose);
    await controller.load();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MotherDiaryEditor(controller: controller, onClose: () {}),
        ),
      ),
    );
    expect(find.text('当前账号没有访问权限'), findsOneWidget);
    expect(find.text('4–5 小时'), findsNothing);
    repository.failure = null;
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(find.text('4–5 小时'), findsOneWidget);
  });

  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('diary renders at ${width.toInt()}px', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await loadMomCozyTestFonts();
      final controller = MotherDiaryController(
        repository: DiaryFixture(),
        date: date,
      );
      addTearDown(controller.dispose);
      await controller.load();
      await tester.pumpWidget(
        MaterialApp(
          theme: momCozyTheme(),
          home: Scaffold(
            body: RepaintBoundary(
              key: const ValueKey('diary-render'),
              child: Material(
                color: MomCozyColors.background,
                child: MotherDiaryEditor(
                  controller: controller,
                  onClose: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(const ValueKey('diary-render')),
        matchesGoldenFile(
          '../../goldens/product_baseline/diary-${width.toInt()}.png',
        ),
      );
    });
  }
}

class DiaryFixture implements MotherDiaryRepository {
  MotherDiaryEntry? entry;
  ProductFailure? failure;
  Completer<void>? gate;
  Completer<void>? loadGate;
  int saves = 0;
  @override
  Future<List<MotherDiaryEntry>> list({
    required LocalDate start,
    required LocalDate end,
  }) async {
    await loadGate?.future;
    if (failure != null) throw failure!;
    return [?entry];
  }

  @override
  Future<MotherDiaryEntry> save({
    required LocalDate date,
    required MotherDiary diary,
    required int expectedVersion,
  }) async {
    saves++;
    await gate?.future;
    if (failure != null) throw failure!;
    return entry = MotherDiaryEntry(
      id: 'diary',
      ownerUserId: 'mom',
      date: date,
      diary: diary,
      version: expectedVersion + 1,
      updatedAt: DateTime.utc(2026, 9, 8),
    );
  }
}
