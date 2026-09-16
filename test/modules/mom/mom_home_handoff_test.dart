import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/mother/mother_diary.dart';
import 'package:momcozy_flutter_app/modules/mom/application/mom_home_view_data.dart';
import 'package:momcozy_flutter_app/domain/care/care_episode.dart';
import 'package:momcozy_flutter_app/modules/services/presentation/expert_support_section.dart';
import 'package:momcozy_flutter_app/modules/mom/presentation/mother_diary_editor.dart';
import 'package:momcozy_flutter_app/modules/mom/presentation/mom_home_sections.dart';
import '../../support/mom_home_handoff_scenarios.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);
  testWidgets('Me typography follows each card record state from Figma', (
    tester,
  ) async {
    for (final state in ['initial', 'recorded', 'diary-only', 'milk-only']) {
      final scenario = HandoffScenario(recorded: state != 'initial');
      if (state == 'diary-only') scenario.milk.records.clear();
      if (state == 'milk-only') scenario.diary.value = const MotherDiary();
      await scenario.controller.load();
      final data = MomHomeViewData.fromController(scenario.controller);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 393,
              child: Column(
                children: [
                  MomLactationCard(data: data, onRecord: () {}),
                  MomRecoveryStatus(
                    data: data,
                    onBody: () {},
                    onRest: () {},
                    onMood: (_) {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final milk = find.descendant(
        of: find.byType(MomLactationCard),
        matching: find.text(data.lactationValue),
      );
      expect(
        tester.widget<Text>(milk).style!.fontSize,
        state == 'recorded' || state == 'milk-only' ? 22 : 18,
        reason: state,
      );
      for (final value in [data.bodyValue, data.sleepValue]) {
        final text = find
            .descendant(
              of: find.byType(MomRecoveryStatus),
              matching: find.text(value),
            )
            .first;
        expect(
          tester.widget<Text>(text).style!.fontSize,
          state == 'recorded' || state == 'diary-only' ? 22 : 18,
          reason: state,
        );
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      scenario.controller.dispose();
    }
  });
  testWidgets(
    'quick mood starts a draft; save preserves other groups and refreshes home',
    (tester) async {
      final s = HandoffScenario(recorded: true);
      await tester.pumpWidget(s.host());
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('不太好'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('不太好'));
      await tester.pumpAndSettle();
      final editor = tester.widget<MotherDiaryEditor>(
        find.byType(MotherDiaryEditor),
      );
      expect(editor.controller.draft.mood.tone, MoodTone.low);
      expect(s.diary.saves, 0);
      await tester.tap(find.text('保存今天的记录'));
      await tester.pumpAndSettle();
      expect(s.diary.saves, 1);
      expect(s.diary.value.rest.total, SleepTotalBand.fourToFiveHours);
      expect(s.diary.value.body.energy, BodyEnergy.energized);
      await tester.tap(find.byTooltip('关闭记录'));
      await tester.pumpAndSettle();
      expect(MomHomeViewData.fromController(s.controller).moodSelection, 0);
      expect(s.insight.reads, greaterThan(1));
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'lactation create uses the existing editor and refreshes total and analysis',
    (tester) async {
      final s = HandoffScenario();
      await tester.pumpWidget(s.host());
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('＋ 记录一次泌乳'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('＋ 记录一次泌乳'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('lactation-measurement-pump')),
        '80',
      );
      await tester.pump();
      await tester.tap(find.text('保存这次记录'));
      await tester.pumpAndSettle();
      expect(s.milk.records, hasLength(1));
      expect(
        MomHomeViewData.fromController(s.controller).lactationValue,
        '80 ml',
      );
      expect(s.insight.reads, greaterThan(1));
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'first frame uses skeleton then independent purchased and empty records',
    (tester) async {
      final s = HandoffScenario(purchased: true);
      await tester.pumpWidget(s.host());
      expect(find.byType(MomHomeSkeleton), findsOneWidget);
      await tester.pumpAndSettle();
      expect(
        MomHomeViewData.fromController(s.controller).insight.status,
        MomInsightStatus.waiting,
      );
      await tester.scrollUntilVisible(
        find.text('我的陪伴计划'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('我的陪伴计划'), findsOneWidget);
      expect(s.diary.saves, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );
  test(
    'generating insight preserves its state without a ready conclusion',
    () async {
      final s = HandoffScenario(recorded: true);
      s.insight.value = const MomDailyInsight(
        status: MomInsightStatus.generating,
        eyebrow: 'Cozymate · 正在生成',
        title: '正在分析今天的记录',
        body: '稍后回来查看',
      );
      await s.controller.load();
      expect(
        MomHomeViewData.fromController(s.controller).insight.status,
        MomInsightStatus.generating,
      );
      expect(
        MomHomeViewData.fromController(s.controller).insight.title,
        '正在分析今天的记录',
      );
      s.controller.dispose();
    },
  );
  testWidgets(
    'failed portrait uses single expert fallback and keeps service actions',
    (tester) async {
      final care = HandoffCare()..purchased = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpertServiceCard(
              episode: care.episode,
              package: HandoffCare.package,
              now: handoffNow,
              portrait: MemoryImage(Uint8List.fromList([0, 1, 2])),
              onProgress: () {},
              onBook: () {},
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.person_outline), findsOneWidget);
      expect(find.text('预约咨询'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final state in ['paused', 'expired', 'exhausted']) {
    testWidgets('$state service retains progress and disables new booking', (
      tester,
    ) async {
      final care = HandoffCare()..purchased = true;
      if (state == 'paused') care.status = CareEpisodeStatus.paused;
      if (state == 'expired') {
        care.endsAt = handoffNow.subtract(const Duration(days: 1));
      }
      if (state == 'exhausted') care.remaining = 0;
      var progress = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ExpertServiceCard(
                episode: care.episode,
                package: HandoffCare.package,
                now: handoffNow,
                onProgress: () => progress++,
                onBook: () => fail('Must not book'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '预约咨询'))
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('服务进度 ›'));
      expect(progress, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  test(
    'partial records preserve missing sections and unknown percentages',
    () async {
      final s = HandoffScenario(recorded: true);
      s.diary.value = const MotherDiary();
      await s.controller.load();
      final data = MomHomeViewData.fromController(s.controller);
      expect(data.hasTodayRecords, isTrue);
      expect(data.completedGroups, 0);
      expect(data.bodyValue, '待记录');
      expect(data.sleepValue, '待记录');
      expect(data.moodSelection, isNull);
      expect(data.lactationValue, '110 ml');
      s.controller.dispose();
    },
  );
  test(
    'record refresh reloads insight; failure cannot show a stale conclusion',
    () async {
      final s = HandoffScenario(recorded: true);
      await s.controller.load();
      expect(
        MomHomeViewData.fromController(s.controller).insight.status,
        MomInsightStatus.ready,
      );
      s.insight.fail = true;
      await s.controller.load();
      expect(s.insight.reads, 2);
      expect(
        MomHomeViewData.fromController(s.controller).insight.status,
        MomInsightStatus.unavailable,
      );
      s.controller.dispose();
    },
  );
  test(
    'diary failure is local; missing delivery date has honest stage fallback',
    () async {
      final s = HandoffScenario(recorded: true);
      s.diary.fail = true;
      s.profile.hasDelivery = false;
      await s.controller.load();
      final data = MomHomeViewData.fromController(s.controller);
      expect(data.phaseLabel, '陪伴每个阶段');
      expect(data.lactationValue, '110 ml');
      expect(data.bodyValue, '暂未载入');
      expect(s.controller.diaries.failure, isNotNull);
      s.controller.dispose();
    },
  );
  for (final width in [320.0, 360.0, 393.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final state in ['initial', 'recorded', 'purchased']) {
        testWidgets('handoff $state $width/$scale', (tester) async {
          tester.view.physicalSize = Size(width, 1100);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await verifyMomHandoff(
            tester,
            scenario: HandoffScenario(
              recorded: state != 'initial',
              purchased: state == 'purchased',
            ),
            scale: scale,
            capture: (part) => expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile(
                '../../goldens/design_system/mom-handoff-$state-$part-${width.toInt()}-${scale.toInt()}x.png',
              ),
            ),
          );
        });
      }
    }
  }
}
