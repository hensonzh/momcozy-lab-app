import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/features/app_pages/momcozy_feature_pages.dart';

void main() {
  group('MomCozy feature pages', () {
    testWidgets('renders a concrete page for every non-Agent route', (
      tester,
    ) async {
      for (final route in momCozyRoutes.where((route) => route.path != '/')) {
        await tester.pumpWidget(_FeaturePageHost(route: route));
        await tester.pump();

        expect(
          find.byKey(ValueKey('route-page-${route.path}')),
          findsOneWidget,
        );
        expect(find.text(route.title), findsWidgets);
        expect(find.text(route.path), findsNothing);
      }
    });

    testWidgets('renders core status, schedule, device, and pump sections', (
      tester,
    ) async {
      await tester.pumpWidget(_FeaturePageHost(route: _route('/status')));
      await tester.pump();
      expect(find.text('今日状态'), findsOneWidget);
      expect(find.text('下一步'), findsOneWidget);

      await tester.pumpWidget(_FeaturePageHost(route: _route('/schedule')));
      await tester.pump();
      expect(find.text('计划'), findsWidgets);
      expect(find.text('提醒'), findsOneWidget);

      await tester.pumpWidget(_FeaturePageHost(route: _route('/device')));
      await tester.pump();
      expect(find.text('左右设备'), findsOneWidget);
      expect(find.text('BLE 权限和扫描'), findsOneWidget);

      await tester.pumpWidget(_FeaturePageHost(route: _route('/pump')));
      await tester.pump();
      expect(find.text('Session 控制'), findsOneWidget);
      expect(find.text('上传状态'), findsOneWidget);
    });

    testWidgets('renders focused flow pages without generic placeholders', (
      tester,
    ) async {
      await tester.pumpWidget(_FeaturePageHost(route: _route('/calibration')));
      await tester.pump();
      expect(find.text('舒适档位'), findsOneWidget);
      expect(find.text('/calibration'), findsNothing);

      await tester.pumpWidget(_FeaturePageHost(route: _route('/media-viewer')));
      await tester.pump();
      expect(find.text('预览'), findsOneWidget);
      expect(find.text('/media-viewer'), findsNothing);
    });

    testWidgets('renders recoverable not found page', (tester) async {
      await tester.pumpWidget(const _FeaturePageHost(route: notFoundRoute));
      await tester.pump();

      expect(find.byKey(const ValueKey('route-page-/404')), findsOneWidget);
      expect(find.text('页面未找到'), findsOneWidget);
      expect(find.text('返回主入口'), findsOneWidget);
    });
  });
}

MomCozyRouteConfig _route(String path) {
  return momCozyRoutes.singleWhere((route) => route.path == path);
}

class _FeaturePageHost extends StatelessWidget {
  const _FeaturePageHost({required this.route});

  final MomCozyRouteConfig route;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: momCozyTheme(),
      home: Scaffold(
        body: MomCozyFeaturePage(
          path: route.path,
          title: route.title,
          summary: route.summary,
          icon: route.icon,
          accent: route.accent,
          priority: route.priority,
        ),
      ),
    );
  }
}
