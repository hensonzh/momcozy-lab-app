import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/baby/baby_profile.dart';
import 'package:momcozy_flutter_app/domain/baby/baby_record.dart';
import 'package:momcozy_flutter_app/domain/shared/local_date.dart';
import 'package:momcozy_flutter_app/domain/shared/product_failure.dart';
import 'package:momcozy_flutter_app/modules/baby/application/baby_home_controller.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_growth_curve.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_home_page.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_profile_editor.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import '../../support/momcozy_test_fonts.dart';
import 'baby_test_repositories.dart';

class _Records extends BabyTestRecords {
  Completer<void>? gate;
  @override
  Future<BabyRecordPage> list({
    required String babyId,
    required LocalDate startDate,
    required LocalDate endDate,
    required String timezone,
    BabyRecordKind? kind,
    int offset = 0,
    int limit = 100,
  }) async {
    await gate?.future;
    return super.list(
      babyId: babyId,
      startDate: startDate,
      endDate: endDate,
      timezone: timezone,
      kind: kind,
      offset: offset,
      limit: limit,
    );
  }
}

void main() {
  setUpAll(loadMomCozyTestFonts);
  for (final size in [(390.0, 1.0), (320.0, 2.0)]) {
    final (width, scale) = size;
    Future<BabyHomeController> open(
      WidgetTester tester,
      _Records records, {
      BabyTestProfiles? profiles,
      void Function(String)? onAsk,
      Future<void> Function(String)? onHistory,
    }) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = BabyHomeController(
        profileRepository: profiles ?? BabyTestProfiles(),
        recordRepository: records,
        timezoneProvider: () async => 'Asia/Shanghai',
        now: () => babyTestNow,
      );
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
            body: BabyHomePage(
              controller: c,
              onAsk: onAsk ?? (_) {},
              onHistory: onHistory ?? (_) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        for (final asset in [
          'assets/images/momcozy-agent.png',
          'assets/images/me_baby_overview/nursery_camera_clean.png',
        ]) {
          await precacheImage(
            AssetImage(asset),
            tester.element(find.byType(MaterialApp)),
          );
        }
      });
      await tester.pumpAndSettle();
      return c;
    }

    Future<void> capture(WidgetTester tester, String state) async {
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          '../../goldens/design_system/baby-home-current-$state-${width.toInt()}-${scale.toInt()}x.png',
        ),
      );
    }

    Future<void> reach(WidgetTester tester, Finder finder) async {
      if (finder.evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          finder,
          350,
          scrollable: find.byType(Scrollable).first,
          maxScrolls: 40,
        );
      } else {
        await tester.ensureVisible(finder);
      }
      await tester.pumpAndSettle();
    }

    Future<void> tap(WidgetTester tester, Finder finder) async {
      await reach(tester, finder);
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    _Records populated() => _Records()
      ..values = [
        BabyFeedingRecord(
          id: 'feed',
          babyId: 'baby',
          occurredAt: babyTestNow,
          method: BabyFeedingMethod.expressedMilk,
          volumeMl: 60,
        ),
        BabySleepRecord(
          id: 'sleep',
          babyId: 'baby',
          occurredAt: babyTestNow.subtract(const Duration(hours: 2)),
          endedAt: babyTestNow,
        ),
        for (final metric in GrowthMetric.values)
          BabyGrowthRecord(
            id: metric.name,
            babyId: 'baby',
            recordedOn: LocalDate(2026, 9, 8),
            timezone: 'Asia/Shanghai',
            metric: metric,
            value: metric == GrowthMetric.weight
                ? 4.2
                : metric == GrowthMetric.length
                ? 54
                : 36,
          ),
      ];

    testWidgets('home redesign layout and original navigation $width/$scale', (
      tester,
    ) async {
      final profiles = BabyTestProfiles()
        ..values = [
          babyTestProfile,
          const BabyProfile(id: 'milo', name: 'Milo', version: 1),
        ];
      String? asked, history;
      final c = await open(
        tester,
        populated(),
        profiles: profiles,
        onAsk: (s) => asked = s,
        onHistory: (s) async {
          history = s;
        },
      );
      expect(
        tester.widget<Text>(find.text('Luna').first).style!.fontFamily,
        'NotoSansSCHome',
      );
      expect(c.summary!.measuredIntakeMl, 60);
      expect(c.summary!.sleepDuration, const Duration(hours: 2));
      await capture(tester, 'recorded-top');
      await tap(tester, find.text('更好地了解 Luna'));
      await capture(tester, 'knowledge-top');
      await reach(tester, find.textContaining('内容用于帮助理解记录'));
      await capture(tester, 'knowledge-end');
      await tap(tester, find.text('问问 Cozymate'));
      expect(asked, isNotEmpty);
      expect(find.byType(Dialog), findsNothing);
      for (final section in ['今日吃奶', '今日状态', '生长发育记录']) {
        await reach(tester, find.text(section));
        await capture(tester, 'section-$section');
      }
      final chart = find.byType(BabyGrowthCurve);
      await reach(tester, chart);
      for (final metric in GrowthMetric.values) {
        final label = metric == GrowthMetric.weight
            ? '体重'
            : metric == GrowthMetric.length
            ? '身长'
            : '头围';
        await tap(
          tester,
          find.descendant(of: chart, matching: find.text(label)),
        );
        expect(tester.widget<BabyGrowthCurve>(chart).metric, metric);
        await capture(tester, 'curve-${metric.name}');
      }
      await tap(tester, find.text('查看全部记录'));
      expect(history, 'baby');
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      await tap(tester, find.text('Luna').first);
      await capture(tester, 'switcher');
      await tap(tester, find.byTooltip('关闭宝宝切换'));
      expect(c.baby!.id, 'baby');
      expect(find.byType(Dialog), findsNothing);
      await tap(tester, find.text('Luna').first);
      await tap(tester, find.text('Milo'));
      expect(c.baby!.id, 'milo');
      expect(c.summary!.feedingCount, 0);
      await reach(tester, chart);
      await capture(tester, 'missing-reference');
      await tap(tester, find.text('完善资料'));
      expect(find.byType(BabyProfileEditor), findsOneWidget);
      expect(find.text('Milo 的资料'), findsOneWidget);
      await tap(tester, find.byTooltip('关闭宝宝资料'));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('home redesign empty loading and error recover $width/$scale', (
      tester,
    ) async {
      final repo = _Records();
      final c = await open(tester, repo);
      await capture(tester, 'empty-top');
      repo.gate = Completer<void>();
      final pending = c.refreshRecords();
      await tester.pump();
      expect(find.text('载入中…'), findsWidgets);
      await capture(tester, 'loading');
      repo.gate!.complete();
      await pending;
      await tester.pumpAndSettle();
      repo.loadFailure = const ProductFailure(ProductFailureKind.offline);
      await c.refreshRecords();
      await tester.pumpAndSettle();
      expect(find.text('未记录'), findsNothing);
      await reach(tester, find.text('今日状态'));
      expect(find.text('暂未载入'), findsWidgets);
      await capture(tester, 'error');
      repo.loadFailure = null;
      await tap(tester, find.text('重试').first);
      expect(find.text('网络未连接，请连接后重试'), findsNothing);
      expect(find.text('未记录'), findsWidgets);
      await tester.pumpWidget(const SizedBox());
      await open(tester, _Records(), profiles: BabyTestProfiles()..values = []);
      await capture(tester, 'no-profile');
      await tap(tester, find.text('添加宝宝'));
      expect(find.byType(BabyProfileEditor), findsOneWidget);
      await tap(tester, find.byTooltip('关闭宝宝资料'));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('home redesign saved undo failure and recovery $width/$scale', (
      tester,
    ) async {
      final repo = populated();
      final c = await open(tester, repo);
      c.showSaved([repo.values.first], allowUndo: true);
      await tester.pumpAndSettle();
      await reach(tester, find.text('查看全部记录'));
      await capture(tester, 'saved');
      repo.failDelete = true;
      await tap(tester, find.text('撤销'));
      expect(find.text('重试确认撤销'), findsOneWidget);
      await capture(tester, 'undo-error');
      await tap(tester, find.text('重试确认撤销'));
      expect(find.text('已撤销这次记录。'), findsOneWidget);
      expect(repo.values.whereType<BabyFeedingRecord>(), isEmpty);
      await capture(tester, 'undone');
      await tap(tester, find.byTooltip('关闭保存提示'));
      expect(c.savedFeedback, isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
