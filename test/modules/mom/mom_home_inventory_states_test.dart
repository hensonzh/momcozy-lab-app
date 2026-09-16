import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/care/care_episode.dart';
import 'package:momcozy_flutter_app/domain/mother/mother_diary.dart';
import 'package:momcozy_flutter_app/modules/mom/application/mom_home_view_data.dart';
import 'package:momcozy_flutter_app/modules/mom/presentation/mom_home_sections.dart';

import '../../support/mom_home_handoff_scenarios.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);
  for (final state in [
    'loading',
    'profile-error',
    'diary-error',
    'lactation-error',
    'partial-records',
    'missing-delivery',
    'insight-unavailable',
    'insight-generating',
    'catalog-error',
    'purchased-no-records',
    'plan-paused',
    'plan-expired',
    'plan-exhausted',
    'expert-portrait-missing',
  ]) {
    testWidgets('inventory mom $state', (tester) async {
      tester.view.physicalSize = const Size(393, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final noRecords = state == 'loading' || state == 'purchased-no-records';
      final s = HandoffScenario(
        recorded: !noRecords,
        purchased:
            state.startsWith('plan-') ||
            state == 'purchased-no-records' ||
            state == 'expert-portrait-missing',
      );
      Completer<void>? gate;
      switch (state) {
        case 'loading':
          gate = Completer<void>();
          s.profile.gate = gate;
          s.diary.gate = gate;
          s.milk.gate = gate;
        case 'profile-error':
          s.profile.fail = true;
        case 'diary-error':
          s.diary.fail = true;
        case 'lactation-error':
          s.milk.fail = true;
        case 'partial-records':
          s.diary.value = const MotherDiary();
        case 'missing-delivery':
          s.profile.hasDelivery = false;
        case 'insight-unavailable':
          s.insight.fail = true;
        case 'insight-generating':
          s.insight.value = const MomDailyInsight(
            status: MomInsightStatus.generating,
            eyebrow: 'Cozymate · 正在生成',
            title: '正在分析今天的记录',
            body: '稍后回来查看',
          );
        case 'catalog-error':
          s.care.fail = true;
        case 'plan-paused':
          s.care.status = CareEpisodeStatus.paused;
        case 'plan-expired':
          s.care.endsAt = handoffNow.subtract(const Duration(days: 1));
        case 'plan-exhausted':
          s.care.remaining = 0;
        case 'expert-portrait-missing':
          s.mockPortrait = false;
      }
      await tester.pumpWidget(s.host());
      final context = tester.element(find.byType(MaterialApp));
      for (final name in [
        'cozymate_avatar.png',
        'expert_group.png',
        'ibclc_jamie_lee.png',
      ]) {
        await tester.runAsync(
          () => precacheImage(
            AssetImage('assets/images/mom_home/$name'),
            context,
          ),
        );
      }
      await tester.pumpAndSettle();
      if (state == 'loading') {
        expect(find.byType(MomHomeSkeleton), findsOneWidget);
      }
      if (state == 'diary-error') {
        expect(s.controller.diaries.failure, isNotNull);
      }
      if (state == 'lactation-error') {
        expect(s.controller.lactation.failure, isNotNull);
      }
      if (state == 'purchased-no-records') {
        expect(
          MomHomeViewData.fromController(s.controller).hasTodayRecords,
          isFalse,
        );
      }
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../../goldens/ui_inventory/mom-$state-393.png'),
      );
      await tester.pumpWidget(const SizedBox());
      gate?.complete();
      await tester.pumpAndSettle();
    });
  }
}
