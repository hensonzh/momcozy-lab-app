@Tags(['golden'])
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/baby/baby_profile.dart';
import 'package:momcozy_flutter_app/domain/baby/baby_record.dart';
import 'package:momcozy_flutter_app/domain/shared/local_date.dart';
import 'package:momcozy_flutter_app/modules/baby/application/baby_record_editor_controller.dart';
import 'package:momcozy_flutter_app/modules/baby/application/baby_profile_controller.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_record_editor.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_profile_editor.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_design.dart';
import 'package:momcozy_flutter_app/services/baby/baby_record_codec.dart';
import 'package:momcozy_flutter_app/shared/zoned_time.dart';
import 'baby_test_repositories.dart';
import '../../support/momcozy_test_fonts.dart';

class SlowRecords extends BabyTestRecords {
  final gate = Completer<void>();
  @override
  Future<BabyRecord> save(
    BabyRecord record, {
    required String idempotencyKey,
  }) async {
    await gate.future;
    return super.save(record, idempotencyKey: idempotencyKey);
  }
}

class SlowProfiles extends BabyTestProfiles {
  final gate = Completer<void>();
  @override
  Future<BabyProfile> save(
    BabyProfile profile, {
    required String timezone,
    String? idempotencyKey,
  }) async {
    await gate.future;
    return super.save(
      profile,
      timezone: timezone,
      idempotencyKey: idempotencyKey,
    );
  }
}

BabyRecordEditorController editor(BabyTestRecords r, BabyRecordKind kind) =>
    BabyRecordEditorController(
      repository: r,
      baby: babyTestProfile,
      timezone: 'Asia/Shanghai',
      now: () => babyTestNow,
      kind: kind,
    );
void main() {
  setUpAll(() async {
    await loadMomCozyTestFonts();
    final loader = FontLoader('BabyNotoSans')
      ..addFont(rootBundle.load('assets/fonts/BabyNotoSans-VF.ttf'));
    await loader.load();
  });
  test(
    'daily tabs preserve draft and submit together even on an empty tab',
    () async {
      final r = BabyTestRecords();
      final daily = editor(r, BabyRecordKind.dailyStatus);
      addTearDown(daily.dispose);
      expect(daily.canSave, false);
      daily.selectDailyTab(BabyDailyTab.wet);
      daily.setWetCount('2');
      daily.selectDailyTab(BabyDailyTab.stool);
      daily.setStoolCount('1');
      daily.setStoolColor(StoolColor.yellow);
      daily.selectDailyTab(BabyDailyTab.mental);
      expect(daily.mentalState, isNull);
      expect(daily.canSave, true);
      final result = (await daily.save())!.single as BabyDailyStatusRecord;
      expect(result.wetCount, 2);
      expect(result.stoolCount, 1);
      expect(result.mentalState, isNull);
      expect(r.submissions.single.length, 1);
      expect(writeBabyObservation(result).containsKey('occurred_at'), false);
    },
  );
  test('partially filled invalid tab disables the whole save', () {
    final c = editor(BabyTestRecords(), BabyRecordKind.dailyStatus);
    addTearDown(c.dispose);
    c.setMentalState(BabyMentalState.content);
    c.setWetCount('1.5');
    expect(c.canSave, false);
    c.setWetCount('');
    expect(c.canSave, true);
    c.setStoolColor(StoolColor.yellow);
    expect(c.canSave, false);
    c.setStoolCount('2');
    expect(c.canSave, true);
  });
  test(
    'growth saves all filled metrics from an empty current metric',
    () async {
      final r = BabyTestRecords();
      final g = editor(r, BabyRecordKind.growth);
      addTearDown(g.dispose);
      g.setGrowthValue(GrowthMetric.weight, '4.2');
      g.selectMetric(GrowthMetric.length);
      g.setGrowthValue(GrowthMetric.length, '54');
      g.selectMetric(GrowthMetric.headCircumference);
      expect(g.canSave, true);
      final saved = await g.save();
      expect(saved!.length, 2);
      expect(saved.cast<BabyGrowthRecord>().map((e) => e.metric), [
        GrowthMetric.weight,
        GrowthMetric.length,
      ]);
    },
  );
  test(
    'saving locks edits, duplicate submission, and keeps the clicked snapshot',
    () async {
      final r = SlowRecords();
      final d = editor(r, BabyRecordKind.dailyStatus);
      addTearDown(d.dispose);
      d.setWetCount('2');
      final save = d.save();
      expect(d.busy, true);
      d.setWetCount('9');
      d.selectDailyTab(BabyDailyTab.stool);
      expect(d.wetCount, '2');
      expect(await d.save(), isNull);
      r.gate.complete();
      await save;
      expect((r.values.single as BabyDailyStatusRecord).wetCount, 2);
    },
  );
  test(
    'retry retains the idempotency key and avoids duplicate records',
    () async {
      final r = BabyTestRecords()..failSave = true;
      final c = editor(r, BabyRecordKind.dailyStatus);
      addTearDown(c.dispose);
      c.setMentalState(BabyMentalState.active);
      expect(await c.save(), isNull);
      expect(c.editable, true);
      expect(c.canSave, true);
      expect(await c.save(), isNotNull);
      expect(r.keys.toSet().length, 1);
      expect(r.values.length, 1);
    },
  );
  test('daily totals use latest entered value and preserve other fields', () {
    final date = LocalDate(2026, 9, 8);
    BabyDailyStatusRecord record(
      String id,
      int minute, {
      int? wet,
      int? stool,
      BabyMentalState? mental,
    }) => BabyDailyStatusRecord(
      id: id,
      babyId: 'baby',
      recordedOn: date,
      timezone: 'Asia/Shanghai',
      savedAt: babyTestNow.add(Duration(minutes: minute)),
      wetCount: wet,
      stoolCount: stool,
      mentalState: mental,
    );
    final s = BabyDaySummary.fromRecords(
      [
        record('a', 0, wet: 2, mental: BabyMentalState.content),
        record('b', 1, wet: 5),
        record('c', 2, stool: 1),
      ],
      babyId: 'baby',
      window: zonedDayWindow(date, 'Asia/Shanghai'),
      now: babyTestNow.add(const Duration(hours: 1)),
    );
    expect(s.wetCount, 5);
    expect(s.dirtyCount, 1);
    expect(s.latestMentalState, BabyMentalState.content);
  });
  test(
    'profile date aligns with mother and save is gated by complete dirty fields',
    () async {
      final r = BabyTestProfiles();
      final c = BabyProfileController(
        repository: r,
        timezone: 'Asia/Shanghai',
        now: () => babyTestNow,
        deliveryDate: LocalDate(2026, 8, 22),
      );
      addTearDown(c.dispose);
      expect(c.canSave, false);
      c.setName('Luna');
      expect(c.canSave, false);
      c.setSex(BabySex.female);
      expect(c.canSave, true);
      await c.save();
      expect(c.birthDate, LocalDate(2026, 8, 22));
      expect(c.canSave, false);
      c.setName('Luna 小宝');
      expect(c.canSave, true);
    },
  );
  test('profile saving ignores edits until completed', () async {
    final r = SlowProfiles();
    final c = BabyProfileController(
      repository: r,
      timezone: 'UTC',
      now: () => babyTestNow,
      initial: babyTestProfile,
    );
    addTearDown(c.dispose);
    c.setName('Luna 宝贝');
    final save = c.save();
    c.setName('Luna 小宝');
    expect(c.name, 'Luna 宝贝');
    expect(c.canSave, false);
    r.gate.complete();
    await save;
    expect(c.canSave, false);
    c.setName('Luna 小宝');
    expect(c.canSave, true);
  });
  for (final width in [320.0, 393.0, 430.0]) {
    for (final kind in [
      BabyRecordKind.feeding,
      BabyRecordKind.dailyStatus,
      BabyRecordKind.growth,
    ]) {
      testWidgets('layout $kind at $width', (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final c = editor(BabyTestRecords(), kind);
        addTearDown(c.dispose);
        if (kind == BabyRecordKind.feeding) {
          c.selectBottle(true);
          c.setFeedingMethod(BabyFeedingMethod.expressedMilk);
          c.setVolume('80');
        }
        if (kind == BabyRecordKind.dailyStatus) {
          c.selectDailyTab(BabyDailyTab.stool);
          c.setStoolCount('1');
        }
        if (kind == BabyRecordKind.growth) {
          c.setGrowthValue(GrowthMetric.weight, '4.2');
          c.selectMetric(GrowthMetric.headCircumference);
        }
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: BabyDesign.theme(ThemeData()),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () =>
                      showBabySheet(context, BabyRecordEditor(controller: c)),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('补充备注'), findsNothing);
        expect(find.textContaining('✓'), findsNothing);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/final-${kind.name}-${width.toInt()}.png'),
        );
        await tester.tapAt(const Offset(4, 4));
        await tester.pumpAndSettle();
        expect(find.byType(BabyRecordEditor), findsNothing);
      });
    }
  }
  testWidgets('daily UI switches back to empty tab with save still enabled', (
    tester,
  ) async {
    final c = editor(BabyTestRecords(), BabyRecordKind.dailyStatus);
    addTearDown(c.dispose);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: BabyDesign.theme(ThemeData()),
        home: Scaffold(body: BabyRecordEditor(controller: c)),
      ),
    );
    await tester.tap(find.text('Wet diapers'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('wet-count')), '2');
    await tester.tap(find.text('Mood'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('baby-save')))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.text('Wet diapers'));
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);
  });
  testWidgets(
    'profile remains open after save and only new edits enable saving',
    (tester) async {
      final c = BabyProfileController(
        repository: BabyTestProfiles(),
        timezone: 'UTC',
        now: () => babyTestNow,
        initial: babyTestProfile,
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(
        MaterialApp(home: BabyProfileEditor(controller: c)),
      );
      expect(find.text('Clear date'), findsNothing);
      expect(find.text('目前喂养方式'), findsNothing);
      await tester.enterText(find.byType(TextField), 'Luna 宝贝');
      await tester.pump();
      await tester.tap(find.text('Save baby profile'));
      await tester.pumpAndSettle();
      expect(find.text('Saved'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.enterText(find.byType(TextField), 'Luna 小宝');
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
    },
  );
}
