import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/app/momcozy_app.dart';
import 'package:app/app/momcozy_design_system.dart';
import 'package:app/features/status/presentation/baby_status_sheets.dart';

import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);

  group('Baby status details', () {
    testWidgets('shows the legacy feeding explanation in a centered dialog', (
      tester,
    ) async {
      await _pumpHost(tester);

      await tester.tap(find.byKey(const ValueKey('open-feeding-info')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('status-detail-baby-feed-info')),
        findsOneWidget,
      );
      expect(find.text('今日摄入说明'), findsOneWidget);
      expect(find.text('妈妈实际记录的喂养数据，不包含亲喂'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows all six legacy baby health entries', (tester) async {
      await _pumpHost(tester);

      await tester.tap(find.byKey(const ValueKey('open-health')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('status-detail-baby-health')),
        findsOneWidget,
      );
      expect(find.text('自闭症风险筛查'), findsOneWidget);
      expect(find.text('生长发育迟缓风险筛查'), findsOneWidget);
      expect(find.text('消化系统风险筛查'), findsOneWidget);
      expect(find.text('皮肤异常风险筛查'), findsOneWidget);
      expect(find.text('认知互动风险筛查'), findsOneWidget);
      expect(find.text('宝宝情绪跟踪'), findsOneWidget);
      expect(find.text('待开通'), findsNWidgets(6));
      expect(tester.takeException(), isNull);
    });

    testWidgets('keeps the complete milestone timeline scrollable', (
      tester,
    ) async {
      await _pumpHost(tester);

      await tester.tap(find.byKey(const ValueKey('open-milestone')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('status-detail-growth-milestone')),
        findsOneWidget,
      );
      expect(find.text('说出完整主谓短句'), findsOneWidget);
      expect(
        find.image(const AssetImage(MomCozyAssets.babyAvatar)),
        findsWidgets,
      );

      await tester.scrollUntilVisible(
        find.text('出生后首次自主抬头'),
        280,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('status-baby-milestone-list')),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.text('2025.11.18'), findsOneWidget);
      expect(find.text('趴卧时能短暂抬起头，开始建立颈肩控制。'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('milestone sheet matches the narrow visual baseline', (
      tester,
    ) async {
      await _pumpHost(tester);
      await tester.tap(find.byKey(const ValueKey('open-milestone')));
      await tester.pumpAndSettle();

      await expectLater(
        find.byKey(const ValueKey('status-detail-growth-milestone')),
        matchesGoldenFile(
          '../../goldens/status_details/baby_milestone_sheet_360x800.png',
        ),
      );
    });

    testWidgets('renders the complete static sleep report without overflow', (
      tester,
    ) async {
      await _pumpHost(tester);

      await tester.tap(find.byKey(const ValueKey('open-sleep')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('status-detail-baby-sleep')),
        findsOneWidget,
      );
      expect(find.text('总睡眠'), findsOneWidget);
      expect(find.text('最长睡眠'), findsOneWidget);
      expect(find.text('4h 57min'), findsOneWidget);
      expect(find.text('3h 08min'), findsOneWidget);
      expect(find.text('0次'), findsOneWidget);
      expect(find.text('26次'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(
              find.byKey(const ValueKey('status-baby-sleep-previous-day')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(
              find.byKey(const ValueKey('status-baby-sleep-next-day')),
            )
            .onPressed,
        isNull,
      );

      await tester.drag(
        find.byKey(const ValueKey('status-baby-sleep-scroll')),
        const Offset(0, -520),
      );
      await tester.pumpAndSettle();
      expect(find.text('00:00'), findsOneWidget);
      expect(find.text('10:00'), findsOneWidget);
      expect(find.text('90m'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sleep sheet matches the narrow visual baseline', (
      tester,
    ) async {
      await _pumpHost(tester);
      await tester.tap(find.byKey(const ValueKey('open-sleep')));
      await tester.pumpAndSettle();

      await expectLater(
        find.byKey(const ValueKey('status-detail-baby-sleep')),
        matchesGoldenFile(
          '../../goldens/status_details/baby_sleep_sheet_360x800.png',
        ),
      );
    });
  });
}

Future<void> _pumpHost(WidgetTester tester) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: momCozyTheme(),
      home: Scaffold(
        body: Builder(
          builder: (context) => Wrap(
            children: [
              Image.asset(
                MomCozyAssets.babyAvatar,
                width: 1,
                height: 1,
                fit: BoxFit.cover,
              ),
              TextButton(
                key: const ValueKey('open-feeding-info'),
                onPressed: () => showBabyFeedingInfoDialog(context),
                child: const Text('喂养说明'),
              ),
              TextButton(
                key: const ValueKey('open-health'),
                onPressed: () =>
                    showBabyStatusPanel(context, panel: BabyStatusPanel.health),
                child: const Text('健康'),
              ),
              TextButton(
                key: const ValueKey('open-milestone'),
                onPressed: () => showBabyStatusPanel(
                  context,
                  panel: BabyStatusPanel.milestone,
                ),
                child: const Text('里程碑'),
              ),
              TextButton(
                key: const ValueKey('open-sleep'),
                onPressed: () =>
                    showBabyStatusPanel(context, panel: BabyStatusPanel.sleep),
                child: const Text('睡眠'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
