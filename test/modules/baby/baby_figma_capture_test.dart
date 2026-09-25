import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/baby/baby_profile.dart';
import 'package:momcozy_flutter_app/domain/baby/baby_record.dart';
import 'package:momcozy_flutter_app/domain/shared/local_date.dart';
import 'package:momcozy_flutter_app/modules/baby/application/baby_record_editor_controller.dart';
import 'package:momcozy_flutter_app/modules/baby/application/baby_profile_controller.dart';
import 'package:momcozy_flutter_app/modules/baby/application/baby_knowledge_content.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_record_editor.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_profile_editor.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_knowledge_sheet.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_design.dart';
import 'baby_test_repositories.dart';
import 'package:momcozy_flutter_app/modules/baby/application/baby_home_controller.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_home_page.dart';
import '../../support/momcozy_test_fonts.dart';

class _PendingRecords extends BabyTestRecords {
  final gate = Completer<void>();
  @override
  Future<BabyRecord> save(
    BabyRecord r, {
    required String idempotencyKey,
  }) async {
    await gate.future;
    return super.save(r, idempotencyKey: idempotencyKey);
  }
}

class _PendingProfiles extends BabyTestProfiles {
  final gate = Completer<void>();
  @override
  Future<BabyProfile> save(
    BabyProfile p, {
    required String timezone,
    String? idempotencyKey,
  }) async {
    await gate.future;
    return super.save(p, timezone: timezone, idempotencyKey: idempotencyKey);
  }
}

// Reproducible, design-sized evidence. Reference images stay separate from golden baselines.
void main() {
  setUpAll(() async {
    await loadMomCozyTestFonts();
    await (FontLoader(
      'BabyNotoSans',
    )..addFont(rootBundle.load('assets/fonts/BabyNotoSans-VF.ttf'))).load();
  });
  final profile = BabyProfile(
    id: 'baby',
    name: 'Luna',
    birthDate: LocalDate(2026, 8, 22),
    sex: BabySex.female,
    version: 1,
  );
  final now = DateTime.utc(2026, 9, 13, 8);
  testWidgets('Figma baby switcher capture', (tester) async {
    tester.view.physicalSize = const Size(393, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = BabyHomeController(
      profileRepository: BabyTestProfiles()
        ..values = [
          profile,
          BabyProfile(
            id: 'leo',
            name: 'Leo',
            sex: BabySex.male,
            birthDate: profile.birthDate,
          ),
        ],
      recordRepository: BabyTestRecords(),
      timezoneProvider: () async => 'Asia/Shanghai',
      now: () => now,
    );
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: BabyDesign.theme(ThemeData()),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.only(top: 24, bottom: 34),
              viewPadding: const EdgeInsets.only(top: 24, bottom: 34),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: BabyHomePage(controller: c, onAsk: (_) {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Luna'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final bounds = tester.getRect(find.byType(BabySheetBody));
    await tester.runAsync(() async {
      final png =
          await (key.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 1);
      final data = await png.toByteData(format: ui.ImageByteFormat.png);
      final out = Directory('build/figma-comparison')
        ..createSync(recursive: true);
      File(
        '${out.path}/switcher.png',
      ).writeAsBytesSync(data!.buffer.asUint8List());
      File('${out.path}/switcher.bounds').writeAsStringSync(
        '${bounds.left},${bounds.top},${bounds.width},${bounds.height}',
      );
      png.dispose();
    });
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Figma home content capture', (tester) async {
    tester.view.physicalSize = const Size(390, 1236);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final p = BabyTestProfiles()..values = [profile];
    final r = BabyTestRecords()
      ..values = [
        BabyFeedingRecord(
          id: 'f',
          babyId: 'baby',
          occurredAt: DateTime.utc(2026, 9, 13, 9),
          method: BabyFeedingMethod.expressedMilk,
          volumeMl: 60,
        ),
        BabyDailyStatusRecord(
          id: 'd',
          babyId: 'baby',
          recordedOn: LocalDate(2026, 9, 13),
          timezone: 'Asia/Shanghai',
          savedAt: DateTime.utc(2026, 9, 13, 9),
          mentalState: BabyMentalState.content,
          wetCount: 1,
          stoolCount: 1,
        ),
        BabyDailyStatusRecord(
          id: 'prev',
          babyId: 'baby',
          recordedOn: LocalDate(2026, 9, 12),
          timezone: 'Asia/Shanghai',
          savedAt: DateTime.utc(2026, 9, 12, 9),
          mentalState: BabyMentalState.content,
        ),
        for (final m in GrowthMetric.values)
          BabyGrowthRecord(
            id: m.name,
            babyId: 'baby',
            recordedOn: LocalDate(2026, 9, 8),
            timezone: 'Asia/Shanghai',
            metric: m,
            value: m == GrowthMetric.weight
                ? 4.2
                : m == GrowthMetric.length
                ? 54
                : 36,
          ),
      ];
    final c = BabyHomeController(
      profileRepository: p,
      recordRepository: r,
      timezoneProvider: () async => 'Asia/Shanghai',
      now: () => DateTime.utc(2026, 9, 13, 10),
    );
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: BabyDesign.theme(ThemeData()),
          home: Scaffold(
            body: BabyHomePage(controller: c, onAsk: (_) {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('1 片'), findsNothing);
    expect(find.text('1 feeding'), findsOneWidget);
    await tester.runAsync(() async {
      final png =
          await (key.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 1);
      final data = await png.toByteData(format: ui.ImageByteFormat.png);
      final out = Directory('build/figma-comparison')
        ..createSync(recursive: true);
      File('${out.path}/home.png').writeAsBytesSync(data!.buffer.asUint8List());
      png.dispose();
    });
    await tester.pumpWidget(const SizedBox());
  });
  for (final state in [
    'feeding',
    'saving',
    'error',
    'nursing',
    'incomplete',
    'mental',
    'selected',
    'cross-tab',
    'wet',
    'stool',
    'growth',
    'profile',
    'profile-new',
    'profile-edited',
    'profile-saving',
    'profile-saved',
    'profile-again',
    'profile-long',
    'knowledge',
  ]) {
    testWidgets('Figma capture $state', (tester) async {
      tester.view.physicalSize = const Size(393, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final records = state == 'saving' ? _PendingRecords() : BabyTestRecords();
      final profiles = state == 'profile-saving'
          ? _PendingProfiles()
          : BabyTestProfiles();
      Future<Object?>? pending;
      final c = BabyRecordEditorController(
        repository: records,
        baby: profile,
        timezone: 'Asia/Shanghai',
        now: () => now,
        kind:
            [
              'feeding',
              'nursing',
              'incomplete',
              'saving',
              'error',
            ].contains(state)
            ? BabyRecordKind.feeding
            : state == 'growth'
            ? BabyRecordKind.growth
            : BabyRecordKind.dailyStatus,
      );
      addTearDown(c.dispose);
      if (['feeding', 'saving', 'error'].contains(state)) {
        c.selectBottle(true);
        c.setFeedingMethod(BabyFeedingMethod.expressedMilk);
        c.setVolume('80');
      }
      if (state == 'nursing') {
        c.setFeedingMethod(BabyFeedingMethod.breastfeeding);
        c.setSide(FeedingSide.left);
        c.setDuration('15');
      }
      if (state == 'wet') {
        c.selectDailyTab(BabyDailyTab.wet);
        c.setWetCount('1');
      }
      if (state == 'stool') {
        c.selectDailyTab(BabyDailyTab.stool);
        c.setStoolCount('1');
      }
      if (state == 'selected') c.setMentalState(BabyMentalState.content);
      if (state == 'cross-tab') c.setWetCount('2');
      if (state == 'growth') {
        c.setGrowthValue(GrowthMetric.weight, '4.2');
        c.selectMetric(GrowthMetric.length);
        c.setGrowthValue(GrowthMetric.length, '54');
        c.selectMetric(GrowthMetric.headCircumference);
        c.setGrowthValue(GrowthMetric.headCircumference, '36');
      }
      if (state == 'error') {
        records.failSave = true;
        await c.save();
      }
      if (state == 'saving') pending = c.save();
      final p = BabyProfileController(
        repository: profiles,
        timezone: 'Asia/Shanghai',
        now: () => now,
        deliveryDate: profile.birthDate,
        initial: state == 'profile-new'
            ? null
            : state == 'profile-long'
            ? BabyProfile(
                id: 'baby',
                name: 'A longer baby name should remain readable',
                birthDate: profile.birthDate,
                sex: BabySex.male,
                version: 1,
              )
            : profile,
      );
      addTearDown(p.dispose);
      if (state == 'profile-edited' || state == 'profile-saving') {
        p.setName('Luna Mae');
      }
      if (state == 'profile-saving') pending = p.save();
      if (state == 'profile-long') p.setSex(BabySex.female);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: BabyDesign.theme(ThemeData()),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                padding: const EdgeInsets.only(top: 24, bottom: 34),
                viewPadding: const EdgeInsets.only(top: 24, bottom: 34),
              ),
              child: child!,
            ),
            home: state.startsWith('profile')
                ? BabyProfileEditor(controller: p)
                : Scaffold(
                    body: Builder(
                      builder: (context) => TextButton(
                        onPressed: () {
                          if (state == 'knowledge') {
                            showBabyKnowledge(
                              context,
                              babyKnowledgeArticles[BabyKnowledgeTopic
                                  .feedingCues]!,
                              () {},
                            );
                          } else {
                            showBabySheet(
                              context,
                              BabyRecordEditor(controller: c),
                            );
                          }
                        },
                        child: const Text('open'),
                      ),
                    ),
                  ),
          ),
        ),
      );
      if (!state.startsWith('profile')) {
        await tester.tap(find.text('open'));
      }
      await tester.pumpAndSettle();
      if (state == 'profile-saved' || state == 'profile-again') {
        await tester.enterText(find.byType(TextField), 'Luna Mae');
        await tester.pump();
        await tester.tap(find.text('Save baby profile'));
        await tester.pumpAndSettle();
        expect(find.text('Baby profile'), findsOneWidget);
        if (state == 'profile-again') {
          await tester.enterText(find.byType(TextField), 'Luna Joy');
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
        }
      }
      if (state == 'profile-edited' || state == 'profile-saving') {
        expect(find.text('Baby profile'), findsOneWidget);
      }
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 80));
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final bounds = state.startsWith('profile')
          ? const Rect.fromLTWH(0, 0, 393, 844)
          : tester.getRect(find.byType(BabySheetBody));
      await tester.runAsync(() async {
        final png =
            await (key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 1);
        final data = await png.toByteData(format: ui.ImageByteFormat.png);
        final out = Directory('build/figma-comparison')
          ..createSync(recursive: true);
        File(
          '${out.path}/$state.png',
        ).writeAsBytesSync(data!.buffer.asUint8List());
        File('${out.path}/$state.bounds').writeAsStringSync(
          '${bounds.left},${bounds.top},${bounds.width},${bounds.height}',
        );
        png.dispose();
      });
      if (records is _PendingRecords) records.gate.complete();
      if (profiles is _PendingProfiles) profiles.gate.complete();
      await pending;
    });
  }
}
