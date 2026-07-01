import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/features/app_pages/momcozy_feature_pages.dart';
import 'package:momcozy_flutter_app/features/pump_session/data/pump_workstate_api_repository.dart';
import 'package:momcozy_flutter_app/features/records/data/records_api_repository.dart';
import 'package:momcozy_flutter_app/features/schedule/data/schedule_api_repository.dart';
import 'package:momcozy_flutter_app/features/status/data/status_api_repository.dart';

import '../../support/fixture_api_transport.dart';

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

    testWidgets('renders every feature page on compact mobile viewport', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final route in momCozyRoutes.where((route) => route.path != '/')) {
        await tester.pumpWidget(_FeaturePageHost(route: route));
        await tester.pump();

        final page = find.byKey(ValueKey('route-page-${route.path}'));
        expect(page, findsOneWidget);
        await tester.drag(page, const Offset(0, -360));
        await tester.pump();
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

    testWidgets('feature entry actions navigate through route workflows', (
      tester,
    ) async {
      final router = createMomCozyRouter(initialLocation: '/device');

      await tester.pumpWidget(
        MomCozyFlutterApp(router: router, apiRuntime: _appRuntime()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, '管理'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('route-page-/device/manage')),
        findsOneWidget,
      );

      router.go('/device');
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(
        tester.element(find.text('进入舒适校准')),
        alignment: 0.35,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('进入舒适校准'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('route-page-/calibration')),
        findsOneWidget,
      );
      expect(find.byType(NavigationBar), findsNothing);

      await tester.ensureVisible(find.widgetWithText(FilledButton, '保存并进入泵奶'));
      await tester.tap(find.widgetWithText(FilledButton, '保存并进入泵奶'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('route-page-/pump')), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);

      router.go('/status');
      await tester.pumpAndSettle();
      await tester.tap(find.text('补写孕期日记'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('route-page-/records')), findsOneWidget);

      router.go('/status');
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(
        tester.element(find.text('今日待办')),
        alignment: 0.35,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('今日待办'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('route-page-/schedule')),
        findsOneWidget,
      );
      expect(find.byType(NavigationBar), findsOneWidget);

      router.go('/w1');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('使用教程'));
      await tester.tap(find.text('使用教程'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('route-page-/media-viewer')),
        findsOneWidget,
      );
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('local page controls update visible state', (tester) async {
      await tester.pumpWidget(_FeaturePageHost(route: _route('/schedule')));
      await tester.pump();
      expect(_checkboxesWithValue(tester, true), 1);

      await tester.tap(find.text('14:00 喂养'));
      await tester.pump();
      expect(_checkboxesWithValue(tester, true), 2);

      await tester.pumpWidget(
        _FeaturePageHost(route: _route('/ibclc-chat.html')),
      );
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );

      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );

      await tester.tap(find.widgetWithText(FilledButton, '进入 IBCLC 咨询'));
      await tester.pump();
      expect(find.text('咨询准备中'), findsWidgets);
      expect(find.text('已进入咨询队列'), findsOneWidget);
    });

    testWidgets('status page loads overview from runtime repository', (
      tester,
    ) async {
      await tester.pumpWidget(_FeaturePageHost(route: _route('/status')));
      await tester.pumpAndSettle();

      expect(find.text('哺乳期'), findsOneWidget);
      expect(find.text('产后第 21 天'), findsOneWidget);

      await tester.tap(find.text('宝宝'));
      await tester.pumpAndSettle();

      expect(find.text('Mia'), findsOneWidget);
      expect(find.text('88 天'), findsOneWidget);
    });

    testWidgets('schedule page loads day plan from runtime repository', (
      tester,
    ) async {
      await tester.pumpWidget(_FeaturePageHost(route: _route('/schedule')));
      await tester.pumpAndSettle();

      expect(find.text('3 项计划'), findsOneWidget);
      expect(find.text('10:30 泵奶'), findsOneWidget);
      expect(find.text('14:00 喂养'), findsOneWidget);
      expect(_checkboxesWithValue(tester, true), 1);

      await tester.tap(find.text('14:00 喂养'));
      await tester.pump();

      expect(_checkboxesWithValue(tester, true), 2);
    });

    testWidgets('records page loads pump feeding and growth repositories', (
      tester,
    ) async {
      await tester.pumpWidget(_FeaturePageHost(route: _route('/records')));
      await tester.pumpAndSettle();

      expect(find.text('200 mL'), findsOneWidget);
      expect(find.textContaining('晨间泵奶'), findsOneWidget);
      expect(find.textContaining('120 mL'), findsWidgets);

      await tester.tap(find.text('喂养'));
      await tester.pumpAndSettle();
      expect(find.textContaining('breast_milk'), findsOneWidget);
      expect(find.textContaining('80 mL'), findsWidgets);

      await tester.tap(find.text('成长'));
      await tester.pumpAndSettle();
      expect(find.textContaining('6.2 kg'), findsOneWidget);
      expect(find.textContaining('64.5 cm'), findsOneWidget);
    });

    testWidgets('pump page uploads workstate through runtime repository', (
      tester,
    ) async {
      await tester.pumpWidget(_FeaturePageHost(route: _route('/pump')));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, '开始'));
      await tester.pumpAndSettle();

      expect(find.text('Workstate 已同步'), findsOneWidget);
      expect(find.text('Workstate accepted'), findsOneWidget);
    });
  });
}

MomCozyRouteConfig _route(String path) {
  return momCozyRoutes.singleWhere((route) => route.path == path);
}

int _checkboxesWithValue(WidgetTester tester, bool value) {
  return tester
      .widgetList<Checkbox>(find.byType(Checkbox))
      .where((checkbox) => checkbox.value == value)
      .length;
}

class _FeaturePageHost extends StatelessWidget {
  const _FeaturePageHost({required this.route});

  final MomCozyRouteConfig route;

  @override
  Widget build(BuildContext context) {
    return MomCozyRuntimeScope(
      apiRuntime: _appRuntime(),
      child: MaterialApp(
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
      ),
    );
  }
}

MomCozyApiRuntime _appRuntime() {
  return MomCozyApiRuntime(
    jsonTransport: FixtureApiJsonTransportByPath({
      statusOverviewEndpoint: const <String, Object?>{
        'status': 200,
        'data': <String, Object?>{
          'mom': <String, Object?>{'stage': '哺乳期', 'postpartum_day': 21},
          'baby': <String, Object?>{'nickname': 'Mia', 'age_days': 88},
        },
      },
      scheduleDayPlanEndpoint: const <String, Object?>{
        'status': 200,
        'data': <String, Object?>{
          'tasks': <Object?>[
            <String, Object?>{
              'id': 'pump',
              'title': '10:30 泵奶',
              'completed': true,
              'remind_at': '2026-07-01T02:30:00Z',
            },
            <String, Object?>{
              'id': 'feeding',
              'title': '14:00 喂养',
              'completed': false,
              'remind_at': '2026-07-01T06:00:00Z',
            },
            <String, Object?>{
              'id': 'summary',
              'title': '20:30 晚间复盘',
              'completed': false,
              'remind_at': '2026-07-01T12:30:00Z',
            },
          ],
        },
      },
      pumpMilkRecordsEndpoint: const <String, Object?>{
        'status': 200,
        'data': <String, Object?>{
          'pump_milk_list': <Object?>[
            <String, Object?>{
              'pump_id': 7001,
              'pump_type': 0,
              'pump_source': 0,
              'pump_time': '2026-07-01T02:40:00Z',
              'pump_title': '晨间泵奶',
              'pump_milk_volum': 120,
            },
          ],
        },
      },
      feedingRecordsEndpoint: const <String, Object?>{
        'status': 200,
        'data': <String, Object?>{
          'records': <Object?>[
            <String, Object?>{
              'id': 'feeding-1001',
              'type': 'breast_milk',
              'amount_ml': 80,
              'occurred_at': '2026-07-01T06:00:00Z',
            },
          ],
        },
      },
      growthRecordsEndpoint: const <String, Object?>{
        'status': 200,
        'data': <String, Object?>{
          'records': <Object?>[
            <String, Object?>{
              'id': 'growth-1001',
              'weight_g': 6200,
              'height_cm': 64.5,
              'measured_at': '2026-07-01',
            },
          ],
        },
      },
      pumpWorkstateEndpoint: const <String, Object?>{
        'status': 200,
        'data': <String, Object?>{
          'need_reply': true,
          'output': 'Workstate accepted',
          'reply_code': 'pump_state_changed',
          'reply_side': 'left',
        },
      },
    }),
    userId: 'demo-user-fixture',
    babyId: 'demo-baby-fixture',
    locale: 'zh-CN',
    now: () => DateTime.utc(2026, 7),
  );
}
