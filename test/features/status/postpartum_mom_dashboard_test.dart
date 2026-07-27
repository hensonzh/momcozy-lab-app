import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/app/momcozy_app.dart';
import 'package:app/core/preferences/volume_unit_preference.dart';
import 'package:app/features/records/domain/records.dart';
import 'package:app/features/status/presentation/postpartum_mom_dashboard.dart';
import 'package:app/features/status/presentation/status_dashboard_controller.dart';

void main() {
  group('PostpartumMomDashboard', () {
    testWidgets('renders loading, real summary, trend controls and tooltip', (
      tester,
    ) async {
      await _setViewport(tester);
      final trends = ValueNotifier<StatusResource<List<MilkTrendDay>>>(
        const StatusResource.loading(),
      );
      addTearDown(trends.dispose);

      await tester.pumpWidget(_DashboardHost(trends: trends));

      expect(find.text('加载中'), findsNWidgets(2));
      expect(find.text('正在加载最近一个月泌乳数据…'), findsOneWidget);

      trends.value = StatusResource.data(_trendFixture());
      await tester.pumpAndSettle();

      expect(find.text('240mL'), findsOneWidget);
      expect(find.text('3次'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('status-milk-trend-chart')),
        findsOneWidget,
      );

      final chart = find.byKey(const ValueKey('status-milk-trend-chart'));
      await tester.ensureVisible(chart);
      await tester.pumpAndSettle();
      await tester.tapAt(tester.getCenter(chart));
      await tester.pump();

      expect(
        find.byKey(const ValueKey('status-milk-trend-tooltip')),
        findsOneWidget,
      );
      expect(find.textContaining('吸乳总量：'), findsOneWidget);

      tester
          .state<_DashboardHostState>(find.byType(_DashboardHost))
          .setVolumeUnit(MomCozyVolumeUnit.ounces);
      await tester.pump();
      expect(find.text('8.1oz'), findsOneWidget);
      expect(find.textContaining('吸乳总量：'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('status-milk-trend-segment-月')),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('母乳趋势图，共 30 天'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('status-milk-trend-toggle')));
      await tester.pumpAndSettle();
      expect(chart, findsNothing);
    });

    testWidgets('opens legacy info dialogs and detailed bottom sheets', (
      tester,
    ) async {
      await _setViewport(tester);
      final trends = ValueNotifier<StatusResource<List<MilkTrendDay>>>(
        StatusResource.data(_trendFixture()),
      );
      addTearDown(trends.dispose);
      final prompts = <String>[];

      await tester.pumpWidget(
        _DashboardHost(trends: trends, onAgentPrompt: prompts.add),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('status-milk-output-info-button')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('status-detail-milk-info')),
        findsOneWidget,
      );
      expect(find.text('使用吸奶器产出的奶量，不含亲喂'), findsOneWidget);
      await tester.tap(find.byTooltip('关闭详情'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('status-breast-health-info-button')),
      );
      await tester.pumpAndSettle();
      expect(find.text('通过您和智能体的日常对话采集的乳房健康记录'), findsOneWidget);
      await tester.tap(find.byTooltip('关闭详情'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('查看《乳房健康日记》'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('status-detail-breast-health')),
        findsOneWidget,
      );
      expect(find.text('涨奶硬块'), findsOneWidget);
      expect(find.text('轻微涨奶'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, '让我了解更多'));
      await tester.pumpAndSettle();
      expect(prompts, ['我想了解乳房健康情况，最近有涨奶和硬块，按压会疼']);
      expect(
        find.byKey(const ValueKey('status-detail-breast-health')),
        findsNothing,
      );

      await tester.tap(find.text('查看计划'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('status-detail-postpartum-recovery')),
        findsOneWidget,
      );
      expect(find.text('暂未开通此功能'), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey('status-postpartum-continue-button')),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('暂未开通此功能'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1500));
      expect(find.text('暂未开通此功能'), findsNothing);
      await tester.tap(find.byTooltip('关闭详情'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('status-rest-info-button')));
      await tester.pumpAndSettle();
      expect(find.text('所有信息来自智能体的收集。'), findsOneWidget);
    });

    testWidgets('renders honest empty and failed trend states', (tester) async {
      await _setViewport(tester);
      final trends = ValueNotifier<StatusResource<List<MilkTrendDay>>>(
        const StatusResource.data(<MilkTrendDay>[]),
      );
      addTearDown(trends.dispose);

      await tester.pumpWidget(_DashboardHost(trends: trends));
      await tester.pumpAndSettle();

      expect(find.text('待记录'), findsOneWidget);
      expect(find.text('待同步'), findsOneWidget);
      expect(find.text('暂无母乳趋势数据，可多日记录产量后在本页查看。'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('status-milk-trend-chart')),
        findsNothing,
      );

      trends.value = StatusResource.error(StateError('offline'));
      await tester.pumpAndSettle();

      expect(find.text('母乳趋势暂时无法同步，请稍后重试。'), findsOneWidget);
    });
  });
}

class _DashboardHost extends StatefulWidget {
  const _DashboardHost({required this.trends, this.onAgentPrompt});

  final ValueNotifier<StatusResource<List<MilkTrendDay>>> trends;
  final ValueChanged<String>? onAgentPrompt;

  @override
  State<_DashboardHost> createState() => _DashboardHostState();
}

class _DashboardHostState extends State<_DashboardHost> {
  var _windowDays = 7;
  final _volumeUnit = ValueNotifier<MomCozyVolumeUnit>(
    MomCozyVolumeUnit.milliliters,
  );

  void setVolumeUnit(MomCozyVolumeUnit unit) {
    _volumeUnit.value = unit;
  }

  @override
  void dispose() {
    _volumeUnit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: momCozyTheme(),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: PostpartumMomDashboard(
            milkTrends: widget.trends,
            volumeUnit: _volumeUnit,
            now: () => DateTime(2026, 7, 11, 10),
            windowDays: _windowDays,
            onWindowDaysChanged: (days) {
              setState(() => _windowDays = days);
            },
            onAgentPrompt: widget.onAgentPrompt ?? (_) {},
          ),
        ),
      ),
    );
  }
}

List<MilkTrendDay> _trendFixture() {
  return [
    for (var day = 11; day >= 1; day -= 1)
      MilkTrendDay(
        date: DateTime(2026, 7, day),
        pumpedMilkVolumeMl: day == 11 ? 240 : 100 + day * 10,
        pumpingCount: day == 11 ? 3 : 2,
      ),
    MilkTrendDay(
      date: DateTime(2026, 6, 11),
      pumpedMilkVolumeMl: 130,
      pumpingCount: 1,
    ),
  ];
}

Future<void> _setViewport(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
