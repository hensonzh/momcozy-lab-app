import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/features/records/domain/records.dart';
import 'package:momcozy_flutter_app/features/status/presentation/baby_growth_chart.dart';
import 'package:momcozy_flutter_app/features/status/presentation/status_dashboard_controller.dart';

void main() {
  group('BabyGrowthChart', () {
    testWidgets('renders loading, empty, data, tooltip, and metric switching', (
      tester,
    ) async {
      await _setViewport(tester, const Size(360, 800));
      final hostKey = GlobalKey<_ChartHostState>();
      await tester.pumpWidget(_ChartHost(key: hostKey));

      expect(find.text('正在加载生长发育历史…'), findsOneWidget);

      hostKey.currentState!.publish(const []);
      await tester.pump();
      expect(find.text('暂无成长曲线数据，录入多项测量后与同龄参考一同展示。'), findsOneWidget);

      hostKey.currentState!.publish(_records());
      await tester.pump();
      expect(find.bySemanticsLabel('宝宝成长曲线，体重，共 3 个周数据点'), findsOneWidget);
      final chart = find.byKey(const ValueKey('status-baby-growth-chart'));
      expect(chart, findsOneWidget);
      await tester.tapAt(tester.getCenter(chart));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('status-baby-growth-tooltip')),
        findsOneWidget,
      );
      expect(find.textContaining('kg'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('status-baby-growth-segment-身高')),
      );
      await tester.pump();
      expect(hostKey.currentState!.selectedMetric, '身高');
      expect(find.text('当前查看：身高'), findsOneWidget);
      expect(find.bySemanticsLabel('宝宝成长曲线，身高，共 3 个周数据点'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('collapses without changing the selected metric', (
      tester,
    ) async {
      await _setViewport(tester, const Size(390, 844));
      final hostKey = GlobalKey<_ChartHostState>();
      await tester.pumpWidget(
        _ChartHost(key: hostKey, initial: StatusResource.data(_records())),
      );

      await tester.tap(
        find.byKey(const ValueKey('status-baby-growth-segment-身高')),
      );
      await tester.tap(
        find.byKey(const ValueKey('status-baby-growth-chart-toggle')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('status-baby-growth-chart')).hitTestable(),
        findsNothing,
      );
      expect(hostKey.currentState!.selectedMetric, '身高');
      expect(find.text('宝宝成长曲线'), findsOneWidget);
    });

    testWidgets('keeps a resource failure local to the chart', (tester) async {
      await _setViewport(tester, const Size(390, 844));
      await tester.pumpWidget(
        _ChartHost(initial: StatusResource.error(StateError('offline'))),
      );

      expect(find.text('生长发育历史暂时无法同步，请稍后重试。'), findsOneWidget);
    });
  });
}

class _ChartHost extends StatefulWidget {
  const _ChartHost({super.key, this.initial = const StatusResource.loading()});

  final StatusResource<List<GrowthRecord>> initial;

  @override
  State<_ChartHost> createState() => _ChartHostState();
}

class _ChartHostState extends State<_ChartHost> {
  late final ValueNotifier<StatusResource<List<GrowthRecord>>> records;
  var selectedMetric = '体重';

  @override
  void initState() {
    super.initState();
    records = ValueNotifier(widget.initial);
  }

  void publish(List<GrowthRecord> value) {
    records.value = StatusResource.data(value);
  }

  @override
  void dispose() {
    records.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: momCozyTheme(),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: BabyGrowthChart(
            records: records,
            birthDate: DateTime(2026, 7, 1),
            selectedMetric: selectedMetric,
            onMetricChanged: (metric) {
              setState(() => selectedMetric = metric);
            },
          ),
        ),
      ),
    );
  }
}

List<GrowthRecord> _records() {
  return [
    GrowthRecord(
      id: 'growth-1',
      weightGram: 3400,
      heightCm: 50,
      headCm: 34,
      measuredAt: DateTime(2026, 7, 1, 8),
    ),
    GrowthRecord(
      id: 'growth-2',
      weightGram: 3700,
      heightCm: 52,
      headCm: 35,
      measuredAt: DateTime(2026, 7, 8, 8),
    ),
    GrowthRecord(
      id: 'growth-3',
      weightGram: 4000,
      heightCm: 54,
      headCm: 36,
      measuredAt: DateTime(2026, 7, 15, 8),
    ),
  ];
}

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
