import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/baby/baby_record.dart';
import 'package:momcozy_flutter_app/domain/shared/local_date.dart';
import 'package:momcozy_flutter_app/domain/shared/product_failure.dart';
import 'package:momcozy_flutter_app/modules/baby/application/baby_home_controller.dart';
import 'package:momcozy_flutter_app/modules/baby/application/baby_record_editor_controller.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_home_page.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_record_editor.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_records_page.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import '../../support/momcozy_test_fonts.dart';
import 'baby_test_repositories.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);
  void viewport(WidgetTester tester, double width) {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget app(Widget child, {double textScale = 1}) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: momCozyTheme(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: child,
  );
  BabyTestRecords populated() => BabyTestRecords()
    ..values = [
      BabyFeedingRecord(
        id: 'feed',
        babyId: 'baby',
        occurredAt: babyTestNow.subtract(const Duration(hours: 1)),
        method: BabyFeedingMethod.expressedMilk,
        volumeMl: 60,
      ),
      BabySleepRecord(
        id: 'sleep',
        babyId: 'baby',
        occurredAt: babyTestNow.subtract(const Duration(hours: 4)),
        endedAt: babyTestNow.subtract(const Duration(hours: 2)),
      ),
      BabyDiaperRecord(
        id: 'diaper',
        babyId: 'baby',
        occurredAt: babyTestNow,
        kind: DiaperKind.both,
      ),
      BabyGrowthRecord(
        id: 'weight',
        babyId: 'baby',
        recordedOn: LocalDate(2026, 9, 8),
        timezone: 'Asia/Shanghai',
        metric: GrowthMetric.weight,
        value: 4.2,
      ),
      BabyGrowthRecord(
        id: 'length',
        babyId: 'baby',
        recordedOn: LocalDate(2026, 9, 8),
        timezone: 'Asia/Shanghai',
        metric: GrowthMetric.length,
        value: 54,
      ),
      BabyGrowthRecord(
        id: 'head',
        babyId: 'baby',
        recordedOn: LocalDate(2026, 9, 8),
        timezone: 'Asia/Shanghai',
        metric: GrowthMetric.headCircumference,
        value: 36,
      ),
    ];

  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('baby home and knowledge scroll with double text at $width', (
      tester,
    ) async {
      viewport(tester, width);
      final controller = BabyHomeController(
        profileRepository: BabyTestProfiles(),
        recordRepository: populated(),
        timezoneProvider: () async => 'Asia/Shanghai',
        now: () => babyTestNow,
      );
      await tester.pumpWidget(
        app(
          Scaffold(
            body: BabyHomePage(
              controller: controller,
              onAsk: (_) {},
              onHistory: (_) async {},
            ),
          ),
          textScale: 2,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('更好地了解 Luna'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('关闭'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('查看全部记录'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
    for (final kind in BabyRecordKind.values) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('${kind.name} editor remains usable at $width / $scale', (
          tester,
        ) async {
          viewport(tester, width);
          final repo = BabyTestRecords();
          final c = BabyRecordEditorController(
            repository: repo,
            baby: babyTestProfile,
            timezone: 'Asia/Shanghai',
            now: () => babyTestNow,
            kind: kind,
          );
          addTearDown(c.dispose);
          switch (kind) {
            case BabyRecordKind.feeding:
              c.setFeedingMethod(BabyFeedingMethod.formula);
              c.setVolume('60');
            case BabyRecordKind.sleep:
              c.setSleepStart(babyTestNow.subtract(const Duration(hours: 2)));
              c.setSleepEnd(babyTestNow);
            case BabyRecordKind.diaper:
              c.setDiaperKind(DiaperKind.both);
              c.setStoolColor(StoolColor.yellow);
              c.setStoolConsistency(StoolConsistency.loose);
            case BabyRecordKind.growth:
              c.setGrowthValue(GrowthMetric.weight, '4.2');
              c.setGrowthValue(GrowthMetric.length, '54');
            case BabyRecordKind.development:
              c.setDevelopment('looks-at-face', DevelopmentStatus.observed);
              c.setDevelopment('lifts-head', DevelopmentStatus.unsure);
          }
          List<BabyRecord>? saved;
          await tester.pumpWidget(
            app(
              Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () async {
                      saved = await showDialog<List<BabyRecord>>(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => BabyRecordEditor(controller: c),
                      );
                    },
                    child: const Text('开始记录'),
                  ),
                ),
              ),
              textScale: scale,
            ),
          );
          await tester.tap(find.text('开始记录'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (scale == 1) {
            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile(
                '../../goldens/design_system/baby-${kind.name}-editor-${width.toInt()}.png',
              ),
            );
          }
          if ((width == 390 && scale == 1) || (width == 320 && scale == 2)) {
            if (scale == 2) {
              await expectLater(
                find.byType(MaterialApp),
                matchesGoldenFile(
                  '../../goldens/design_system/baby-editor-current-${kind.name}-top-320-2x.png',
                ),
              );
            }
            final position = tester
                .state<ScrollableState>(find.byType(Scrollable).first)
                .position;
            if (kind == BabyRecordKind.diaper ||
                kind == BabyRecordKind.development) {
              position.jumpTo(position.maxScrollExtent / 2);
              await tester.pumpAndSettle();
              await expectLater(
                find.byType(MaterialApp),
                matchesGoldenFile(
                  '../../goldens/design_system/baby-editor-current-${kind.name}-middle-${width.toInt()}-${scale.toInt()}x.png',
                ),
              );
            }
            position.jumpTo(position.maxScrollExtent);
            await tester.pumpAndSettle();
            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile(
                '../../goldens/design_system/baby-editor-current-${kind.name}-end-${width.toInt()}-${scale.toInt()}x.png',
              ),
            );
          }
          if (width == 320 && kind == BabyRecordKind.feeding) {
            tester.view.viewInsets = const FakeViewPadding(bottom: 320);
            addTearDown(tester.view.resetViewInsets);
            await tester.pumpAndSettle();
          }
          await tester.ensureVisible(find.byKey(const ValueKey('baby-save')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('baby-save')));
          await tester.pumpAndSettle();
          expect(saved, isNotEmpty);
          expect(saved!.every((record) => record.babyId == 'baby'), isTrue);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        });
      }
    }
  }
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'history edits and restores the same baby record at $width / $scale',
        (tester) async {
          viewport(tester, width);
          final repo = populated();
          var privacyOpened = false;
          await tester.pumpWidget(
            app(
              BabyRecordsPage(
                babyId: 'baby',
                profiles: BabyTestProfiles(),
                repository: repo,
                timezoneProvider: () async => 'Asia/Shanghai',
                now: () => babyTestNow,
                onBack: () {},
                onPrivacy: () => privacyOpened = true,
              ),
              textScale: scale,
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (scale == 1) {
            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile(
                '../../goldens/design_system/baby-history-${width.toInt()}.png',
              ),
            );
          }
          await tester.scrollUntilVisible(
            find.text('数据来源'),
            220,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('数据来源'));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('隐私与授权'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('隐私与授权'));
          expect(privacyOpened, isTrue);
          if (width == 390 && scale == 1) {
            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile(
                '../../goldens/design_system/baby-history-source-390.png',
              ),
            );
          }
          await tester.scrollUntilVisible(
            find.text('编辑'),
            -200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('编辑'));
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byKey(const ValueKey('feeding-volume')),
            '90',
          );
          await tester.ensureVisible(find.byKey(const ValueKey('baby-save')));
          await tester.tap(find.byKey(const ValueKey('baby-save')));
          await tester.pumpAndSettle();
          expect(
            repo.values.whereType<BabyFeedingRecord>().single.volumeMl,
            90,
          );
          await tester.ensureVisible(find.text('删除'));
          await tester.tap(find.text('删除'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('删除').last);
          await tester.pumpAndSettle();
          expect(repo.values.whereType<BabyFeedingRecord>(), isEmpty);
          await tester.ensureVisible(find.text('撤销删除'));
          await tester.tap(find.text('撤销删除'));
          await tester.pumpAndSettle();
          expect(
            repo.values.whereType<BabyFeedingRecord>().single.volumeMl,
            90,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
  testWidgets('a record URL cannot load a baby outside the owned profiles', (
    tester,
  ) async {
    viewport(tester, 390);
    await tester.pumpWidget(
      app(
        BabyRecordsPage(
          babyId: 'other',
          profiles: BabyTestProfiles(),
          repository: populated(),
          timezoneProvider: () async => 'UTC',
          now: () => babyTestNow,
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('当前账号没有访问权限'), findsOneWidget);
    expect(find.textContaining('Luna'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('a failed home request is not presented as no records', (
    tester,
  ) async {
    viewport(tester, 390);
    final repo = BabyTestRecords()
      ..loadFailure = const ProductFailure(ProductFailureKind.offline);
    await tester.pumpWidget(
      app(
        Scaffold(
          body: BabyHomePage(
            controller: BabyHomeController(
              profileRepository: BabyTestProfiles(),
              recordRepository: repo,
              timezoneProvider: () async => 'UTC',
              now: () => babyTestNow,
            ),
            onAsk: (_) {},
            onHistory: (_) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('暂未载入'), findsWidgets);
    expect(find.text('未记录'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets(
      'baby overview matches the current product design at $width',
      (tester) async {
        viewport(tester, width);
        final boundary = GlobalKey();
        await tester.pumpWidget(
          app(
            RepaintBoundary(
              key: boundary,
              child: Scaffold(
                body: BabyHomePage(
                  controller: BabyHomeController(
                    profileRepository: BabyTestProfiles(),
                    recordRepository: populated(),
                    timezoneProvider: () async => 'Asia/Shanghai',
                    now: () => babyTestNow,
                  ),
                  onAsk: (_) {},
                  onHistory: (_) async {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => precacheImage(
            const AssetImage('assets/images/momcozy-agent.png'),
            tester.element(find.byType(MaterialApp)),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byKey(boundary),
          matchesGoldenFile('goldens/baby-home-${width.toInt()}.png'),
        );
        await tester.scrollUntilVisible(
          find.text('查看全部记录'),
          220,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await expectLater(
          find.byKey(boundary),
          matchesGoldenFile('goldens/baby-growth-${width.toInt()}.png'),
        );
        await tester.pumpWidget(const SizedBox());
      },
      tags: ['golden'],
    );
  }
}
