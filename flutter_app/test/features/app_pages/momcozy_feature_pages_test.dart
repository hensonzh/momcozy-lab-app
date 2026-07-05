import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_io_transport.dart';
import 'package:momcozy_flutter_app/features/app_pages/momcozy_feature_pages.dart';
import 'package:momcozy_flutter_app/features/hospital_bag/data/hospital_bag_cart_api_repository.dart';
import 'package:momcozy_flutter_app/features/pump_session/data/pump_workstate_api_repository.dart';
import 'package:momcozy_flutter_app/features/records/data/records_api_repository.dart';
import 'package:momcozy_flutter_app/features/schedule/data/schedule_api_repository.dart';
import 'package:momcozy_flutter_app/features/status/data/status_api_repository.dart';
import 'package:momcozy_flutter_app/native/p0_platform_interfaces.dart';

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
        if (route.path == '/status') {
          expect(find.text('妈妈'), findsWidgets);
        } else if (route.path == '/pump') {
          expect(find.text('沉浸式吸乳'), findsWidgets);
        } else if (route.path == '/device') {
          expect(find.text('设备连接'), findsWidgets);
        } else if (route.path == '/device/user') {
          expect(find.text('用户参数配置'), findsWidgets);
        } else if (route.path == '/community') {
          expect(find.text('社区功能还在建设中哦～'), findsWidgets);
        } else if (route.path == '/hospital-bag-cart') {
          expect(find.text('待产包一键打包'), findsWidgets);
        } else if (route.path == '/ibclc-chat.html') {
          expect(find.text('IBCLC 在线咨询'), findsWidgets);
        } else if (route.path == '/media-viewer') {
          expect(find.text('媒体'), findsWidgets);
        } else if (route.path == '/schedule') {
          expect(find.text('稳奶计划执行中'), findsWidgets);
        } else {
          expect(find.text(route.title), findsWidgets);
        }
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
        if (route.path == '/pump') {
          await _dismissPumpCalibrationPrompt(tester);
        }
        await tester.drag(page, const Offset(0, -360));
        await tester.pump();
      }
    });

    testWidgets('status page and bottom tabs fit compact mobile width', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final router = createMomCozyRouter(initialLocation: '/status');
      await tester.pumpWidget(
        MomCozyFlutterApp(router: router, apiRuntime: _appRuntime()),
      );
      await tester.pumpAndSettle();

      _expectFinderWithinViewport(
        tester,
        find.byKey(const ValueKey('status-care-stage-pregnancy')),
      );
      _expectFinderWithinViewport(
        tester,
        find.byKey(const ValueKey('status-care-stage-postpartum')),
      );
      _expectFinderWithinViewport(
        tester,
        find.byKey(const ValueKey('status-identity-tab-mom')),
      );
      _expectFinderWithinViewport(
        tester,
        find.byKey(const ValueKey('status-identity-tab-baby')),
      );

      for (final label in const ['宝宝和我', '计划', '社区', '设备']) {
        _expectFinderWithinViewport(tester, find.text(label));
      }
      _expectFinderWithinViewport(
        tester,
        find.byKey(const ValueKey('bottom-nav-agent')),
      );

      router.go('/');
      await tester.pumpAndSettle();
      _expectFinderWithinViewport(
        tester,
        find.byKey(const ValueKey('agent-composer-input')),
      );
    });

    testWidgets('device and community content fit compact mobile width', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_FeaturePageHost(route: _route('/device')));
      await tester.pumpAndSettle();
      _expectFinderWithinViewport(
        tester,
        find.byKey(const ValueKey('device-quick-menu-button')),
      );
      _expectFinderWithinViewport(
        tester,
        find.byKey(const ValueKey('device-start-pump-button')),
      );
      _expectFinderWithinViewport(
        tester,
        find.byKey(const ValueKey('device-deck-card-L')),
      );
      _expectFinderWithinViewport(
        tester,
        find.byKey(const ValueKey('device-deck-card-R')),
      );

      await tester.pumpWidget(_FeaturePageHost(route: _route('/community')));
      await tester.pumpAndSettle();
      _expectFinderWithinViewport(tester, find.text('社区功能还在建设中哦～'));
      _expectFinderWithinViewport(
        tester,
        find.textContaining('我们将打造一个妈妈们一起交流分享的社区'),
      );
    });

    testWidgets('legacy horizontal panels fit compact mobile width', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_FeaturePageHost(route: _route('/w1')));
      await tester.pumpAndSettle();
      _expectFinderWithinViewport(tester, find.text('续航'));
      _expectFinderWithinViewport(tester, find.text('4h+'));

      await tester.pumpWidget(_FeaturePageHost(route: _route('/pump')));
      await tester.pumpAndSettle();
      _expectFinderWithinViewport(
        tester,
        find.byKey(const ValueKey('pump-calibration-prompt-card')),
      );
    });

    testWidgets('renders core status, schedule, device, and pump sections', (
      tester,
    ) async {
      await tester.pumpWidget(_FeaturePageHost(route: _route('/status')));
      await tester.pumpAndSettle();
      expect(find.text('母乳产出'), findsOneWidget);
      expect(find.text('下一步'), findsNothing);
      expect(find.text('补写孕期日记'), findsNothing);
      expect(find.text('今日待办'), findsNothing);

      await tester.pumpWidget(_FeaturePageHost(route: _route('/schedule')));
      await tester.pump();
      expect(find.text('稳奶计划执行中'), findsOneWidget);
      await _scrollToText(tester, '泵奶提醒');
      expect(find.text('泵奶提醒'), findsOneWidget);

      await tester.pumpWidget(_FeaturePageHost(route: _route('/device')));
      await tester.pump();
      expect(find.text('Momcozy W1 · 全新上市'), findsOneWidget);
      expect(find.text('Air One'), findsOneWidget);
      expect(find.text('RIGHT'), findsOneWidget);

      await tester.pumpWidget(_FeaturePageHost(route: _route('/pump')));
      await tester.pump();
      expect(find.text('设备控制'), findsOneWidget);
      expect(find.text('个性化舒适档位'), findsOneWidget);
      await _dismissPumpCalibrationPrompt(tester);
      await _scrollToText(tester, '上传状态');
      expect(find.text('上传状态'), findsOneWidget);
    });

    testWidgets('renders focused flow pages without generic placeholders', (
      tester,
    ) async {
      await tester.pumpWidget(_FeaturePageHost(route: _route('/calibration')));
      await tester.pump();
      expect(find.text('舒适负压调节'), findsOneWidget);
      expect(find.text('/calibration'), findsNothing);

      await tester.pumpWidget(_FeaturePageHost(route: _route('/media-viewer')));
      await tester.pump();
      expect(find.text('媒体'), findsOneWidget);
      expect(find.text('缺少资源参数，请从资料卡片进入。'), findsOneWidget);
      expect(find.text('/media-viewer'), findsNothing);
    });

    testWidgets('renders recoverable not found page', (tester) async {
      await tester.pumpWidget(const _FeaturePageHost(route: notFoundRoute));
      await tester.pump();

      expect(find.byKey(const ValueKey('route-page-/404')), findsOneWidget);
      expect(find.text('Oops! Page not found'), findsOneWidget);
      expect(find.text('Return to Home'), findsOneWidget);
    });

    testWidgets('feature entry actions navigate through route workflows', (
      tester,
    ) async {
      final router = createMomCozyRouter(initialLocation: '/device');
      final pumpProtocol = FakePumpProtocolPlatform();

      await tester.pumpWidget(
        MomCozyFlutterApp(
          router: router,
          apiRuntime: _appRuntime(pumpProtocolPlatform: pumpProtocol),
        ),
      );
      await tester.pumpAndSettle();

      await _tapDeviceQuickMenuItem(tester, '设备提醒');
      expect(
        find.byKey(const ValueKey('route-page-/device/manage')),
        findsOneWidget,
      );

      router.go('/device');
      await tester.pumpAndSettle();
      await _tapScrollableText(tester, '左侧 S12 Pro L');
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('route-page-/calibration')),
        findsOneWidget,
      );
      expect(find.byType(MomCozyBottomNavigation), findsNothing);

      await _acknowledgeCalibrationIntro(tester);
      await _tapScrollableText(tester, '保存并进入泵奶');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('route-page-/pump')), findsOneWidget);
      expect(find.byType(MomCozyBottomNavigation), findsNothing);
      expect(
        pumpProtocol.recordedCommands.map(
          (command) =>
              '${command.name}:${command.side.name}:${command.payload['gear']}',
        ),
        ['adjustGearForSide:left:4', 'adjustGearForSide:right:4'],
      );

      router.go('/w1');
      await tester.pumpAndSettle();
      await _tapScrollableText(tester, '使用教程');
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('route-page-/media-viewer')),
        findsOneWidget,
      );
      expect(find.byType(MomCozyBottomNavigation), findsNothing);
      await pumpProtocol.dispose();
    });

    testWidgets('local page controls update visible state', (tester) async {
      await tester.pumpWidget(_FeaturePageHost(route: _route('/schedule')));
      await tester.pumpAndSettle();
      await _scrollToText(tester, '14:00 喂养');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -520));
      await tester.pumpAndSettle();
      final visibleCompletedCount = _checkboxesWithValue(tester, true);

      await tester.tap(find.byType(Checkbox).last);
      await tester.pump();
      expect(_checkboxesWithValue(tester, true), visibleCompletedCount + 1);

      await tester.pumpWidget(
        _FeaturePageHost(route: _route('/ibclc-chat.html')),
      );
      await tester.pump();
      expect(find.text('IBCLC 在线咨询'), findsOneWidget);
      expect(find.text('连接中'), findsOneWidget);
      expect(find.text('发送'), findsNothing);

      await tester.pump(const Duration(seconds: 8));
      await tester.pumpAndSettle();
      expect(find.text('发送'), findsOneWidget);

      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '结束咨询'))
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('status page loads overview from runtime repository', (
      tester,
    ) async {
      await tester.pumpWidget(_FeaturePageHost(route: _route('/status')));
      await tester.pumpAndSettle();

      expect(find.text('哺乳期'), findsWidgets);
      expect(find.text('妈妈档案待绑定'), findsOneWidget);
      expect(find.text('母乳产出'), findsOneWidget);

      await tester.tap(find.text('宝宝'));
      await tester.pumpAndSettle();

      expect(find.text('成长发育'), findsOneWidget);
      expect(find.text('Mia'), findsWidgets);
      expect(find.text('待记录'), findsWidgets);
    });

    testWidgets('status page records growth locally', (tester) async {
      await tester.pumpWidget(_FeaturePageHost(route: _route('/status')));
      await tester.pumpAndSettle();

      expect(find.text('母乳产出'), findsOneWidget);

      await tester.tap(find.text('宝宝'));
      await tester.pumpAndSettle();

      expect(find.text('待记录'), findsOneWidget);

      await _scrollToText(tester, '记录成长事件');
      await tester.tap(find.text('记录成长事件').first);
      await tester.pumpAndSettle();

      expect(find.text('已添加'), findsOneWidget);
      expect(find.text('已记录'), findsOneWidget);
      expect(find.text('成长记录已添加'), findsNothing);
    });

    testWidgets('status page renders long text and runtime context', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _FeaturePageHost(
          route: _route('/status'),
          jsonTransport: FixtureApiJsonTransportByPath({
            statusProfileEndpoint: const {
              'user_id': 'demo-user-fixture',
              'daily_summary': '哺乳期恢复阶段，需要同时关注睡眠、补水、泵奶舒适度和情绪波动',
              'delivery_date': '2026-02-24',
            },
            statusInfantsEndpoint: const {
              'items': [
                {
                  'id': 'demo-baby-fixture',
                  'owner_user_id': 'demo-user-fixture',
                  'infant_name': 'Mia Sophia Long Profile Name',
                  'birth_date': '2025-12-26',
                  'sex': 'female',
                  'status': 'active',
                },
              ],
            },
          }),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('哺乳期恢复阶段'), findsWidgets);
      expect(find.text('母乳产出'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('宝宝'));
      await tester.pumpAndSettle();

      expect(find.text('Mia Sophia Long Profile Name'), findsWidgets);
      expect(find.text('成长发育'), findsOneWidget);
      expect(find.text('待记录'), findsWidgets);
      expect(tester.takeException(), isNull);

      expect(find.text('下一步'), findsNothing);
      expect(find.text('今日待办'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('status page renders empty and failed states', (tester) async {
      await tester.pumpWidget(
        _FeaturePageHost(
          route: _route('/status'),
          jsonTransport: FixtureApiJsonTransportByPath({
            statusProfileEndpoint: const {'user_id': 'demo-user-fixture'},
            statusInfantsEndpoint: const {'items': []},
          }),
        ),
      );
      await tester.pumpAndSettle();

      await _scrollToText(tester, '母乳产出');
      expect(find.text('母乳产出'), findsOneWidget);
      await _scrollToText(tester, '母乳趋势');
      expect(find.text('母乳趋势'), findsOneWidget);
      await _scrollToText(tester, '暂无状态数据');
      expect(find.text('暂无状态数据'), findsOneWidget);

      await tester.pumpWidget(
        _FeaturePageHost(
          route: _route('/status'),
          jsonTransport: FixtureApiJsonTransportByPath({
            statusProfileEndpoint: const {
              'http_status': 500,
              'status_text': 'Server Error',
            },
          }),
        ),
      );
      await tester.pumpAndSettle();

      await _scrollToText(tester, '母乳产出');
      expect(find.text('母乳产出'), findsOneWidget);
      await _scrollToText(tester, '母乳趋势');
      expect(find.text('母乳趋势'), findsOneWidget);
      await _scrollToText(tester, '状态同步失败');
      expect(find.text('状态同步失败'), findsOneWidget);
      expect(find.text('检查后端连接或 token 后重试。'), findsOneWidget);
    });

    testWidgets('schedule page loads day plan from runtime repository', (
      tester,
    ) async {
      await tester.pumpWidget(_FeaturePageHost(route: _route('/schedule')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('schedule-context-reminder-button')),
        findsOneWidget,
      );
      expect(find.text('1/3'), findsOneWidget);
      await _scrollToText(tester, '10:30 泵奶');
      expect(find.text('10:30 泵奶'), findsOneWidget);
      await _scrollToText(tester, '14:00 喂养');
      expect(find.text('14:00 喂养'), findsWidgets);
      expect(_checkboxesWithValue(tester, true), 1);

      await tester.tap(find.text('14:00 喂养').last);
      await tester.pump();

      expect(_checkboxesWithValue(tester, true), 2);
    });

    testWidgets('schedule page switches date and reminder state', (
      tester,
    ) async {
      final transport = FixtureApiJsonTransportByPath({
        scheduleDayPlanEndpoint: const {
          'items': <Object?>[
            {
              'id': 'pump',
              'owner_user_id': 'demo-user-fixture',
              'task_date': '2026-07-01',
              'task_time': '10:30',
              'title': '泵奶',
              'description': '',
              'status': 'completed',
              'payload': <String, Object?>{},
            },
            {
              'id': 'feeding',
              'owner_user_id': 'demo-user-fixture',
              'task_date': '2026-07-01',
              'task_time': '14:00',
              'title': '喂养',
              'description': '',
              'status': 'pending',
              'payload': <String, Object?>{},
            },
          ],
        },
      });

      await tester.pumpWidget(
        _FeaturePageHost(route: _route('/schedule'), jsonTransport: transport),
      );
      await tester.pumpAndSettle();

      expect(transport.lastQuery, containsPair('task_date', '2026-07-01'));
      expect(transport.lastQuery, isNot(containsPair('user_id', anything)));
      expect(find.text('1/2'), findsOneWidget);

      await tester.tap(find.text('3').first);
      await tester.pumpAndSettle();

      expect(transport.lastQuery, containsPair('task_date', '2026-07-03'));

      await _scrollToText(tester, '10:30 泵奶');
      expect(find.text('10:30 泵奶'), findsOneWidget);

      await _scrollToText(tester, '泵奶提醒');
      final enabledReminderSwitches = _switchesWithValue(tester, true);
      expect(enabledReminderSwitches, greaterThanOrEqualTo(1));
      await tester.tap(find.byType(Switch).first);
      await tester.pump();
      expect(_switchesWithValue(tester, true), enabledReminderSwitches - 1);
    });

    testWidgets('schedule page adds deletes local tasks and shows badge', (
      tester,
    ) async {
      await tester.pumpWidget(_FeaturePageHost(route: _route('/schedule')));
      await tester.pumpAndSettle();

      expect(find.text('1/3'), findsOneWidget);
      expect(find.text('待执行任务'), findsOneWidget);

      final addTaskButton = find.byKey(
        const ValueKey('schedule-add-task-button'),
      );
      await _scrollToFinder(tester, addTaskButton);
      await tester.tap(addTaskButton);
      await tester.pumpAndSettle();

      expect(find.text('1/4'), findsOneWidget);
      await _scrollToText(tester, '本地补充 1');
      expect(find.text('本地补充 1'), findsOneWidget);

      await tester.tap(find.byTooltip('删除任务').last);
      await tester.pumpAndSettle();

      await tester.drag(find.byType(Scrollable).first, const Offset(0, 600));
      await tester.pumpAndSettle();

      expect(find.text('1/3'), findsOneWidget);
      expect(find.text('本地补充 1'), findsNothing);
    });

    testWidgets('schedule page renders cross-day countdown', (tester) async {
      await tester.pumpWidget(
        _FeaturePageHost(
          route: _route('/schedule'),
          jsonTransport: FixtureApiJsonTransportByPath({
            scheduleDayPlanEndpoint: const {
              'items': <Object?>[
                {
                  'id': 'prenatal-check',
                  'owner_user_id': 'demo-user-fixture',
                  'task_date': '2026-07-03',
                  'task_time': '14:00',
                  'title': '周五产检',
                  'description': '',
                  'status': 'pending',
                  'payload': <String, Object?>{},
                },
              ],
            },
          }),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('0/1'), findsOneWidget);
      expect(find.textContaining('周五产检 还有 2 天 6 小时'), findsOneWidget);
    });

    testWidgets('schedule page renders empty and failed states', (
      tester,
    ) async {
      await tester.pumpWidget(
        _FeaturePageHost(
          route: _route('/schedule'),
          jsonTransport: FixtureApiJsonTransportByPath({
            scheduleDayPlanEndpoint: const {'items': <Object?>[]},
          }),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('0/0'), findsOneWidget);
      expect(find.text('今天还没有计划任务'), findsOneWidget);
      await _scrollToText(tester, '当天暂无执行内容');
      expect(find.text('当天暂无执行内容'), findsOneWidget);

      await tester.pumpWidget(
        _FeaturePageHost(
          route: _route('/schedule'),
          jsonTransport: FixtureApiJsonTransportByPath({
            scheduleDayPlanEndpoint: const {
              'http_status': 503,
              'status_text': 'Service Unavailable',
            },
          }),
        ),
      );
      await tester.pumpAndSettle();

      await _scrollToText(tester, '计划同步失败');
      expect(find.text('计划同步失败'), findsOneWidget);
      expect(find.text('检查后端连接或 token 后重试。'), findsOneWidget);
    });

    testWidgets('pump page uploads workstate through runtime repository', (
      tester,
    ) async {
      await tester.pumpWidget(_FeaturePageHost(route: _route('/pump')));
      await tester.pumpAndSettle();
      await _dismissPumpCalibrationPrompt(tester);

      await _tapScrollableText(tester, '开始');
      await tester.pumpAndSettle();

      await _scrollToText(tester, 'Workstate 已同步');
      expect(find.text('Workstate 已同步'), findsOneWidget);
      expect(find.text('Pump telemetry accepted.'), findsOneWidget);
    });

    testWidgets('pump page moves through local session states', (tester) async {
      await tester.pumpWidget(_FeaturePageHost(route: _route('/pump')));
      await tester.pumpAndSettle();
      await _dismissPumpCalibrationPrompt(tester);

      expect(find.text('待开始'), findsWidgets);

      await _tapScrollableText(tester, '开始');
      await tester.pumpAndSettle();
      await _scrollToText(tester, '运行中');
      expect(find.text('运行中'), findsOneWidget);

      await _tapScrollableText(tester, '暂停');
      await tester.pumpAndSettle();
      await _scrollToText(tester, '已暂停');
      expect(find.text('已暂停'), findsOneWidget);

      await _tapScrollableText(tester, '恢复');
      await tester.pumpAndSettle();
      await _scrollToText(tester, '运行中');
      expect(find.text('运行中'), findsOneWidget);

      await _tapScrollableText(tester, '结束');
      await tester.pumpAndSettle();
      expect(find.text('待开始'), findsWidgets);
    });

    testWidgets('pump page tracks side progress and blocks duplicate finish', (
      tester,
    ) async {
      final transport = FixtureApiJsonTransportByPath({
        pumpWorkstateEndpoint: const {
          'id': 'telemetry-001',
          'owner_user_id': 'demo-user-fixture',
          'device_id': 'app-pump-session',
          'event_type': 'workstate',
          'occurred_at': '2026-07-01T10:00:00Z',
          'payload': <String, Object?>{},
        },
      });

      await tester.pumpWidget(
        _FeaturePageHost(route: _route('/pump'), jsonTransport: transport),
      );
      await tester.pumpAndSettle();
      await _dismissPumpCalibrationPrompt(tester);

      expect(find.text('0 分钟'), findsOneWidget);
      expect(find.text('0 mL'), findsNWidgets(2));

      await _tapScrollableText(tester, '开始');
      await tester.pumpAndSettle();

      await _scrollToText(tester, '2 分钟');
      expect(find.text('2 分钟'), findsOneWidget);
      await _scrollToText(tester, '10 mL');
      expect(find.text('10 mL'), findsOneWidget);
      await _scrollToText(tester, '8 mL');
      expect(find.text('8 mL'), findsOneWidget);
      await _scrollToText(tester, '绑定 demo-user-fixture');
      expect(find.text('绑定 demo-user-fixture'), findsOneWidget);
      expect(transport.postedBodies, hasLength(1));
      expect(transport.postedBodies.first['user_id'], isNull);
      expect(transport.postedBodies.first['device_id'], 'app-pump-session');
      expect(transport.postedBodies.first['event_type'], 'workstate');
      expect(transport.postedBodies.first['occurred_at'], isA<String>());
      final firstPayload =
          transport.postedBodies.first['payload'] as Map<String, Object?>;
      expect(firstPayload['left'], {
        'state': 1,
        'mode': 'massage_expression',
        'level': 5,
      });
      expect(firstPayload['right'], {
        'state': 1,
        'mode': 'expression',
        'level': 5,
      });

      final endButton = find.widgetWithText(FilledButton, '结束');
      await _scrollToFinder(tester, endButton);
      await tester.ensureVisible(endButton);
      await tester.pumpAndSettle();
      await tester.tap(endButton);
      await tester.tap(endButton);
      await tester.pumpAndSettle();

      expect(transport.postedBodies, hasLength(2));
      final lastPayload =
          transport.postedBodies.last['payload'] as Map<String, Object?>;
      expect(lastPayload['left'], {
        'state': 0,
        'mode': 'massage_expression',
        'level': 5,
      });
      await _scrollToText(tester, '重复结束已拦截');
      expect(find.text('重复结束已拦截'), findsOneWidget);
      expect(find.textContaining('只保留一组结束上传'), findsOneWidget);
      expect(find.text('1/1'), findsOneWidget);
    });

    testWidgets('pump page clears active session when runtime user changes', (
      tester,
    ) async {
      final transport = FixtureApiJsonTransportByPath({
        pumpWorkstateEndpoint: const {
          'id': 'telemetry-001',
          'owner_user_id': 'demo-user-fixture',
          'device_id': 'app-pump-session',
          'event_type': 'workstate',
          'occurred_at': '2026-07-01T10:00:00Z',
          'payload': <String, Object?>{},
        },
      });
      final hostKey = GlobalKey<_RuntimeSwapFeaturePageHostState>();

      await tester.pumpWidget(
        _RuntimeSwapFeaturePageHost(
          key: hostKey,
          route: _route('/pump'),
          jsonTransport: transport,
          initialUserId: 'user-a',
        ),
      );
      await tester.pumpAndSettle();
      await _dismissPumpCalibrationPrompt(tester);

      await _tapScrollableText(tester, '开始');
      await tester.pumpAndSettle();

      await _scrollToText(tester, '绑定 user-a');
      expect(find.text('绑定 user-a'), findsOneWidget);
      expect(transport.postedBodies.last['user_id'], isNull);

      hostKey.currentState!.switchUser('user-b');
      await tester.pumpAndSettle();

      expect(find.text('待开始'), findsWidgets);
      await _scrollToText(tester, '未绑定用户');
      expect(find.text('未绑定用户'), findsOneWidget);
      await _scrollToText(tester, '0 分钟');
      expect(find.text('0 分钟'), findsOneWidget);
      await _scrollToText(tester, '检测到用户切换，已清空上一用户 session。');
      expect(find.text('检测到用户切换，已清空上一用户 session。'), findsOneWidget);
      expect(transport.postedBodies, hasLength(1));

      await _tapScrollableText(tester, '开始');
      await tester.pumpAndSettle();

      await _scrollToText(tester, '绑定 user-b');
      expect(find.text('绑定 user-b'), findsOneWidget);
      expect(transport.postedBodies, hasLength(2));
      expect(transport.postedBodies.last['user_id'], isNull);
    });

    testWidgets('pump page renders upload failure state', (tester) async {
      await tester.pumpWidget(
        _FeaturePageHost(
          route: _route('/pump'),
          jsonTransport: FixtureApiJsonTransportByPath({
            pumpWorkstateEndpoint: const {
              'http_status': 500,
              'status_text': 'Server Error',
            },
          }),
        ),
      );
      await tester.pumpAndSettle();
      await _dismissPumpCalibrationPrompt(tester);

      await _tapScrollableText(tester, '开始');
      await tester.pumpAndSettle();

      await _scrollToText(tester, 'Workstate 同步失败');
      expect(find.text('Workstate 同步失败'), findsOneWidget);
      expect(find.text('检查后端连接或 token 后重试。'), findsOneWidget);

      await tester.tap(find.byTooltip('重试同步'));
      await tester.pumpAndSettle();

      expect(find.text('Workstate 同步失败'), findsOneWidget);
    });

    testWidgets('device page reads connected devices from BLE runtime', (
      tester,
    ) async {
      await tester.pumpWidget(_FeaturePageHost(route: _route('/device')));
      await tester.pumpAndSettle();

      expect(find.text('左侧 S12 Pro L'), findsOneWidget);

      await _tapDeviceQuickMenuItem(tester, '添加设备');

      expect(find.text('正在扫描附近设备'), findsOneWidget);
      expect(find.text('停止扫描'), findsOneWidget);
    });

    testWidgets(
      'device page disconnects local devices when runtime user changes',
      (tester) async {
        final ble = FakeBlePlatform(
          initialPermission: BlePermissionState.granted,
          seedDevices: const [
            BleDeviceSnapshot(
              side: 'L',
              deviceId: 'user-a-left',
              deviceName: 'User A L',
              connected: true,
              battery: 86,
            ),
            BleDeviceSnapshot(
              side: 'R',
              deviceId: 'user-a-right',
              deviceName: 'User A R',
              connected: true,
              battery: 82,
            ),
          ],
        );
        addTearDown(ble.dispose);
        final hostKey = GlobalKey<_RuntimeSwapFeaturePageHostState>();

        await tester.pumpWidget(
          _RuntimeSwapFeaturePageHost(
            key: hostKey,
            route: _route('/device'),
            jsonTransport: FixtureApiJsonTransportByPath(const {}),
            blePlatform: ble,
            initialUserId: 'user-a',
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('左侧 User A L'), findsOneWidget);
        expect(find.text('右侧 User A R'), findsOneWidget);
        expect(await ble.getConnectedDevices(), hasLength(2));

        hostKey.currentState!.switchUser('user-b');
        await tester.pumpAndSettle();

        expect(await ble.getConnectedDevices(), isEmpty);
        expect(find.text('LEFT'), findsOneWidget);
        expect(find.text('RIGHT'), findsOneWidget);
        expect(find.text('连接设备'), findsNWidgets(2));
        expect(find.text('检测到用户切换，已隔离上一用户设备连接。'), findsOneWidget);
      },
    );

    testWidgets('device page handles empty and denied permission states', (
      tester,
    ) async {
      final ble = FakeBlePlatform(
        initialPermission: BlePermissionState.unknown,
        requestPermissionResult: BlePermissionState.denied,
      );
      addTearDown(ble.dispose);

      await tester.pumpWidget(
        _FeaturePageHost(route: _route('/device'), blePlatform: ble),
      );
      await tester.pumpAndSettle();

      expect(find.text('LEFT'), findsOneWidget);
      expect(find.text('RIGHT'), findsOneWidget);
      expect(find.text('连接设备'), findsNWidgets(2));
      expect(find.textContaining('权限状态 未请求'), findsNothing);
      expect(find.text('内部调试参数'), findsNothing);

      await _tapDeviceQuickMenuItem(tester, '添加设备');

      expect(find.text('BLE 权限未授权'), findsOneWidget);
      expect(find.byTooltip('打开蓝牙设置'), findsOneWidget);
      expect(find.textContaining('已恢复 0 台已连接设备'), findsNothing);
    });

    testWidgets('device page recovers from permanently denied permission', (
      tester,
    ) async {
      final ble = FakeBlePlatform(
        initialPermission: BlePermissionState.permanentlyDenied,
        requestPermissionResult: BlePermissionState.permanentlyDenied,
      );
      addTearDown(ble.dispose);

      await tester.pumpWidget(
        _FeaturePageHost(route: _route('/device'), blePlatform: ble),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('权限状态 永久拒绝'), findsNothing);

      await _tapDeviceQuickMenuItem(tester, '添加设备');
      expect(find.text('BLE 权限已永久拒绝，请从系统设置重新开启。'), findsOneWidget);

      ble.setPermissionState(
        BlePermissionState.granted,
        nextRequestPermissionResult: BlePermissionState.granted,
      );
      await tester.tap(find.byTooltip('打开系统设置'));
      await tester.pumpAndSettle();

      expect(ble.openedAppSettings, isTrue);

      await _tapDeviceQuickMenuItem(tester, '添加设备');

      expect(find.text('正在扫描附近设备'), findsOneWidget);
    });

    testWidgets('device page renders dual devices and scan outcomes', (
      tester,
    ) async {
      final ble = FakeBlePlatform(
        initialPermission: BlePermissionState.granted,
        seedDevices: const [
          BleDeviceSnapshot(
            side: 'L',
            deviceId: 'left-connected',
            deviceName: 'S12 Pro L',
            connected: true,
            battery: 87,
            rssi: -54,
          ),
          BleDeviceSnapshot(
            side: 'R',
            deviceId: 'right-connected',
            deviceName: 'S12 Pro R',
            connected: true,
          ),
        ],
      );
      addTearDown(ble.dispose);

      await tester.pumpWidget(
        _FeaturePageHost(route: _route('/device'), blePlatform: ble),
      );
      await tester.pumpAndSettle();

      expect(find.text('左侧 S12 Pro L'), findsOneWidget);
      expect(find.text('右侧 S12 Pro R'), findsOneWidget);
      expect(find.text('已连接'), findsWidgets);
      expect(find.text('87%'), findsOneWidget);

      await _tapDeviceQuickMenuItem(tester, '添加设备');
      expect(find.text('停止扫描'), findsOneWidget);

      ble.addScanResult(
        const BleDeviceSnapshot(
          side: 'L',
          deviceId: 'nearby-left',
          deviceName: 'Nearby Pump L',
          battery: 76,
          rssi: -48,
        ),
      );
      ble.addScanResult(
        const BleDeviceSnapshot(
          side: 'R',
          deviceId: 'nearby-right',
          deviceName: 'Nearby Pump R',
          battery: 74,
          rssi: -52,
        ),
      );
      await tester.pump();

      await _scrollToText(tester, 'Nearby Pump L');
      expect(find.text('Nearby Pump L'), findsOneWidget);
      expect(find.text('Nearby Pump R'), findsOneWidget);
      expect(find.textContaining('nearby-left'), findsOneWidget);
      expect(find.textContaining('电量 76%'), findsOneWidget);
      expect(find.textContaining('RSSI -48'), findsOneWidget);

      ble.failScan(const BleScanFailure(code: 'timeout', message: '扫描超时'));
      await tester.pump();

      expect(find.text('扫描超时'), findsOneWidget);
    });

    testWidgets('device page renders scan empty and connect outcomes', (
      tester,
    ) async {
      final ble = FakeBlePlatform(
        initialPermission: BlePermissionState.granted,
      );
      addTearDown(ble.dispose);

      await tester.pumpWidget(
        _FeaturePageHost(route: _route('/device'), blePlatform: ble),
      );
      await tester.pumpAndSettle();

      await _tapDeviceQuickMenuItem(tester, '添加设备');

      expect(find.text('暂无扫描结果'), findsOneWidget);

      ble.addScanResult(
        const BleDeviceSnapshot(
          side: 'L',
          deviceId: 'nearby-left',
          deviceName: 'Nearby Pump L',
          battery: 76,
          rssi: -48,
        ),
      );
      await tester.pump();

      await _tapScrollableText(tester, 'Nearby Pump L');
      await tester.pumpAndSettle();

      await _scrollToText(tester, 'Nearby Pump L 已连接');
      expect(find.text('Nearby Pump L 已连接'), findsOneWidget);
      expect(find.text('左侧 Nearby Pump L'), findsOneWidget);
      expect(find.text('76%'), findsOneWidget);

      final failingBle = _ConnectFailingBlePlatform(
        initialPermission: BlePermissionState.granted,
      );
      addTearDown(failingBle.dispose);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        _FeaturePageHost(route: _route('/device'), blePlatform: failingBle),
      );
      await tester.pumpAndSettle();

      await _tapDeviceQuickMenuItem(tester, '添加设备');
      failingBle.addScanResult(
        const BleDeviceSnapshot(
          side: 'R',
          deviceId: 'nearby-right',
          deviceName: 'Nearby Pump R',
        ),
      );
      await tester.pump();

      await _tapScrollableText(tester, 'Nearby Pump R');
      await tester.pumpAndSettle();

      await _scrollToText(tester, '连接 Nearby Pump R 失败，请重试。');
      expect(find.text('连接 Nearby Pump R 失败，请重试。'), findsOneWidget);
    });

    testWidgets('calibration page saves gears through pump protocol runtime', (
      tester,
    ) async {
      final pumpProtocol = FakePumpProtocolPlatform();
      final router = createMomCozyRouter(initialLocation: '/calibration');

      await tester.pumpWidget(
        MomCozyFlutterApp(
          router: router,
          apiRuntime: _appRuntime(pumpProtocolPlatform: pumpProtocol),
        ),
      );
      await tester.pumpAndSettle();

      await _acknowledgeCalibrationIntro(tester);
      await _tapScrollableText(tester, '保存并进入泵奶');
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('route-page-/pump')), findsOneWidget);
      expect(
        pumpProtocol.recordedCommands.map(
          (command) =>
              '${command.name}:${command.side.name}:${command.payload['gear']}',
        ),
        ['adjustGearForSide:left:4', 'adjustGearForSide:right:4'],
      );

      await pumpProtocol.dispose();
    });

    testWidgets('calibration page surfaces missing device failures', (
      tester,
    ) async {
      await tester.pumpWidget(
        _FeaturePageHost(
          route: _route('/calibration'),
          pumpProtocolPlatform: _ThrowingPumpProtocolPlatform(
            StateError('No BLE device connected'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _acknowledgeCalibrationIntro(tester);
      await _tapScrollableText(tester, '保存并进入泵奶');
      await tester.pumpAndSettle();

      expect(find.text('未检测到左右设备连接，请先在设备页连接后再保存。'), findsOneWidget);
    });

    testWidgets(
      'calibration page renders side availability and unsaved guard',
      (tester) async {
        final ble = FakeBlePlatform(
          initialPermission: BlePermissionState.granted,
          seedDevices: const [
            BleDeviceSnapshot(
              side: 'L',
              deviceId: 'left-calibration',
              deviceName: 'Calibration L',
              connected: true,
              battery: 83,
            ),
          ],
        );
        addTearDown(ble.dispose);

        await tester.pumpWidget(
          _FeaturePageHost(route: _route('/calibration'), blePlatform: ble),
        );
        await tester.pumpAndSettle();

        await _acknowledgeCalibrationIntro(tester);
        expect(find.text('左侧设备已连接'), findsOneWidget);
        expect(find.textContaining('Calibration L · 电量 83%'), findsOneWidget);
        expect(find.text('右侧设备未连接'), findsOneWidget);

        final leftGearUp = find.byTooltip('提高左侧档位');
        await tester.drag(
          find.byKey(const ValueKey('route-page-/calibration')),
          const Offset(0, -260),
        );
        await tester.pumpAndSettle();
        for (var i = 0; i < 3; i += 1) {
          await tester.tap(leftGearUp);
          await tester.pump();
        }

        expect(find.text('左侧 舒适档位 7'), findsOneWidget);

        await _tapScrollableText(tester, '退出校准');
        await tester.pumpAndSettle();

        expect(find.text('有未保存校准更改，请先保存或恢复默认后再退出。'), findsOneWidget);
      },
    );

    testWidgets('calibration page can recover interrupted unsaved changes', (
      tester,
    ) async {
      final router = createMomCozyRouter(initialLocation: '/calibration');

      await tester.pumpWidget(
        MomCozyFlutterApp(router: router, apiRuntime: _appRuntime()),
      );
      await tester.pumpAndSettle();

      await _acknowledgeCalibrationIntro(tester);
      final leftGearUp = find.byTooltip('提高左侧档位');
      await tester.drag(
        find.byKey(const ValueKey('route-page-/calibration')),
        const Offset(0, -260),
      );
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i += 1) {
        await tester.tap(leftGearUp);
        await tester.pump();
      }

      await _tapScrollableText(tester, '退出校准');
      await tester.pumpAndSettle();

      expect(find.text('有未保存校准更改，请先保存或恢复默认后再退出。'), findsOneWidget);
      expect(find.text('左侧 舒适档位 7'), findsOneWidget);

      await _tapScrollableText(tester, '恢复默认');
      await tester.pumpAndSettle();

      expect(find.text('已恢复默认校准档位，可安全退出。'), findsOneWidget);
      expect(find.text('左侧 舒适档位 4'), findsOneWidget);

      await _tapScrollableText(tester, '退出校准');
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('route-page-/device')), findsOneWidget);
    });

    testWidgets('calibration page renders right-only and dual device states', (
      tester,
    ) async {
      final rightOnlyBle = FakeBlePlatform(
        initialPermission: BlePermissionState.granted,
        seedDevices: const [
          BleDeviceSnapshot(
            side: 'R',
            deviceId: 'right-calibration',
            deviceName: 'Calibration R',
            connected: true,
            battery: 79,
          ),
        ],
      );
      addTearDown(rightOnlyBle.dispose);

      await tester.pumpWidget(
        _FeaturePageHost(
          route: _route('/calibration'),
          blePlatform: rightOnlyBle,
        ),
      );
      await tester.pumpAndSettle();

      await _acknowledgeCalibrationIntro(tester);
      expect(find.text('左侧设备未连接'), findsOneWidget);
      expect(find.text('右侧设备已连接'), findsOneWidget);
      expect(find.textContaining('Calibration R · 电量 79%'), findsOneWidget);

      final dualBle = FakeBlePlatform(
        initialPermission: BlePermissionState.granted,
        seedDevices: const [
          BleDeviceSnapshot(
            side: 'L',
            deviceId: 'dual-left-calibration',
            deviceName: 'Dual L',
            connected: true,
            battery: 84,
          ),
          BleDeviceSnapshot(
            side: 'R',
            deviceId: 'dual-right-calibration',
            deviceName: 'Dual R',
            connected: true,
            battery: 81,
          ),
        ],
      );
      addTearDown(dualBle.dispose);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        _FeaturePageHost(route: _route('/calibration'), blePlatform: dualBle),
      );
      await tester.pumpAndSettle();

      await _acknowledgeCalibrationIntro(tester);
      expect(find.text('左侧设备已连接'), findsOneWidget);
      expect(find.textContaining('Dual L · 电量 84%'), findsOneWidget);
      expect(find.text('右侧设备已连接'), findsOneWidget);
      expect(find.textContaining('Dual R · 电量 81%'), findsOneWidget);
    });

    testWidgets('media viewer renders old Web missing-resource chrome', (
      tester,
    ) async {
      await tester.pumpWidget(_FeaturePageHost(route: _route('/media-viewer')));
      await tester.pumpAndSettle();

      expect(find.text('媒体'), findsOneWidget);
      expect(find.byKey(const ValueKey('media-return-button')), findsOneWidget);
      expect(find.text('缺少资源参数，请从资料卡片进入。'), findsOneWidget);
      expect(find.text('资料预览'), findsNothing);
      expect(find.text('上传示例资料'), findsNothing);
    });

    testWidgets('media viewer reads resource query and renders viewer state', (
      tester,
    ) async {
      final router = createMomCozyRouter(
        initialLocation:
            '/media-viewer?kind=pdf&url=%2Fdemo%2Fw1.pdf&title=W1%20使用教程',
      );

      await tester.pumpWidget(MomCozyFlutterApp(router: router));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('route-page-/media-viewer')),
        findsOneWidget,
      );
      expect(find.text('W1 使用教程'), findsOneWidget);
      expect(find.text('加载 PDF…'), findsOneWidget);
      expect(find.text('缺少资源参数，请从资料卡片进入。'), findsNothing);
    });

    testWidgets('media page returns to the previous route when pushed', (
      tester,
    ) async {
      final router = createMomCozyRouter(initialLocation: '/status');

      await tester.pumpWidget(MomCozyFlutterApp(router: router));
      await tester.pumpAndSettle();

      router.push('/media-viewer');
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('route-page-/media-viewer')),
        findsOneWidget,
      );

      const returnButton = ValueKey('media-return-button');
      await tester.tap(find.byKey(returnButton));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('route-page-/status')), findsOneWidget);
    });

    testWidgets('IBCLC page posts client event through runtime client', (
      tester,
    ) async {
      final recorded = <Map<String, Object?>>[];
      final client = AgentStreamClientEventClient(recorder: recorded.add);

      await tester.pumpWidget(
        _FeaturePageHost(
          route: _route('/ibclc-chat.html'),
          clientEventClient: client,
        ),
      );
      await tester.pumpAndSettle();

      await tester.pump(const Duration(seconds: 8));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('ibclc-upload-image-button')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('ibclc-message-input')), findsOneWidget);
      expect(find.byKey(const ValueKey('ibclc-voice-button')), findsOneWidget);
      expect(find.byKey(const ValueKey('ibclc-send-button')), findsOneWidget);

      final body = recorded.single;
      expect(find.text('咨询事件已同步。'), findsOneWidget);
      expect(body['event_type'], 'ibclc_consult_started');
      expect(body.containsKey('user_id'), isFalse);
      expect(body.containsKey('thread_id'), isFalse);
      expect(body['locale'], 'zh-CN');
      expect(body['metadata'], containsPair('source', 'ibclc-chat'));
      expect(body['metadata'], containsPair('handoff', 'vendor_h5_native'));
      expect(body['metadata'], containsPair('return_to', '/status'));
    });

    testWidgets('IBCLC page enters local queue when event sync fails', (
      tester,
    ) async {
      const client = AgentStreamClientEventClient(sent: false);

      await tester.pumpWidget(
        _FeaturePageHost(
          route: _route('/ibclc-chat.html'),
          clientEventClient: client,
        ),
      );
      await tester.pumpAndSettle();

      await tester.pump(const Duration(seconds: 8));
      await tester.pumpAndSettle();

      expect(find.text('本地已进入队列，稍后重试同步。'), findsOneWidget);
    });

    testWidgets('IBCLC page opens vendor handoff and returns to status route', (
      tester,
    ) async {
      final client = AgentStreamClientEventClient();
      final router = createMomCozyRouter(initialLocation: '/ibclc-chat.html');

      await tester.pumpWidget(
        MomCozyFlutterApp(
          router: router,
          apiRuntime: _appRuntime(clientEventClient: client),
        ),
      );
      await tester.pumpAndSettle();

      await tester.pump(const Duration(seconds: 8));
      await tester.pumpAndSettle();

      expect(find.textContaining('你好，我是 Emily Chen'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('ibclc-return-status-button')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('route-page-/status')), findsOneWidget);
    });

    testWidgets('hospital bag page syncs cart changes through repository', (
      tester,
    ) async {
      final transport = FixtureApiJsonTransportByPath({
        hospitalBagCartUpdateEndpoint: const {
          'status': 200,
          'data': {'message': '购物车已同步', 'synced_count': 17},
        },
      });

      await tester.pumpWidget(
        _FeaturePageHost(
          route: _route('/hospital-bag-cart'),
          jsonTransport: transport,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('hospital-bag-item-count-chip')),
        findsOneWidget,
      );
      expect(find.text('18 件'), findsOneWidget);
      expect(find.textContaining('已含组合优惠'), findsOneWidget);
      expect(find.text('产褥垫组合装'), findsOneWidget);

      await tester.longPress(find.text('产褥垫组合装'));
      await tester.pumpAndSettle();

      expect(find.text('购物车已同步'), findsOneWidget);
      expect(find.text('17 件'), findsOneWidget);

      final cartPayload =
          transport.postedBodies.last['payload']! as Map<String, Object?>;
      final items = List<Object?>.from(cartPayload['items']! as List);
      expect(items, hasLength(17));
      expect(
        items.whereType<Map>().map((item) => item['id']),
        isNot(contains('mom-pad')),
      );
    });

    testWidgets('hospital bag page deletes items and restores defaults', (
      tester,
    ) async {
      final transport = FixtureApiJsonTransportByPath({
        hospitalBagCartUpdateEndpoint: const {
          'id': 'cart-plan-001',
          'owner_user_id': 'demo-user-fixture',
          'plan_type': 'hospital_bag_cart',
          'title': 'Hospital bag cart',
          'summary': '清单已同步',
          'status': 'active',
          'source': 'flutter',
          'payload': {
            'items': <Object?>[
              {'id': 'pump', 'title': '吸奶器和配件', 'packed': true},
              {'id': 'pads', 'title': '产后护理用品', 'packed': false},
            ],
          },
        },
      });

      await tester.pumpWidget(
        _FeaturePageHost(
          route: _route('/hospital-bag-cart'),
          jsonTransport: transport,
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.text('产褥垫组合装'));
      await tester.pumpAndSettle();

      expect(find.text('产褥垫组合装'), findsNothing);
      expect(find.text('清单已同步'), findsOneWidget);

      expect(transport.lastHeaders?['Idempotency-Key'], isNotEmpty);
      expect(transport.postedBodies.last['user_id'], isNull);
      expect(
        transport.postedBodies.last,
        containsPair('plan_type', 'hospital_bag_cart'),
      );
      final deletedPayload =
          transport.postedBodies.last['payload']! as Map<String, Object?>;
      final deletedItems = List<Object?>.from(deletedPayload['items']! as List);
      expect(deletedItems, hasLength(17));
      expect(
        deletedItems.whereType<Map>().map((item) => item['id']),
        isNot(contains('mom-pad')),
      );

      await _tapScrollableWidgetWithText(tester, OutlinedButton, '恢复默认清单');
      await tester.pumpAndSettle();

      await _scrollToText(tester, '产褥垫组合装');
      expect(find.text('产褥垫组合装'), findsOneWidget);
      final restoredPayload =
          transport.postedBodies.last['payload']! as Map<String, Object?>;
      final restoredItems = List<Object?>.from(
        restoredPayload['items']! as List,
      );
      expect(restoredItems, hasLength(18));
    });

    testWidgets('hospital bag page handles sync failure and default restore', (
      tester,
    ) async {
      await tester.pumpWidget(
        _FeaturePageHost(
          route: _route('/hospital-bag-cart'),
          jsonTransport: FixtureApiJsonTransportByPath({
            hospitalBagCartUpdateEndpoint: const {
              'http_status': 500,
              'status_text': 'Server Error',
            },
          }),
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.text('产褥垫组合装'));
      await tester.pumpAndSettle();

      expect(find.text('本地清单已更新，稍后重试同步。'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        _FeaturePageHost(
          route: _route('/hospital-bag-cart'),
          jsonTransport: FixtureApiJsonTransportByPath({
            hospitalBagCartUpdateEndpoint: const {
              'id': 'cart-plan-001',
              'owner_user_id': 'demo-user-fixture',
              'plan_type': 'hospital_bag_cart',
              'title': 'Hospital bag cart',
              'summary': '默认清单已恢复',
              'status': 'active',
              'source': 'flutter',
              'payload': {
                'items': <Object?>[
                  {'id': 'pump', 'title': '吸奶器和配件', 'packed': true},
                  {'id': 'pads', 'title': '产后护理用品', 'packed': true},
                  {'id': 'baby', 'title': '宝宝衣物', 'packed': false},
                ],
              },
            },
          }),
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.text('产褥垫组合装'));
      await tester.pumpAndSettle();
      expect(find.text('产褥垫组合装'), findsNothing);

      await _tapScrollableWidgetWithText(tester, OutlinedButton, '恢复默认清单');
      await tester.pumpAndSettle();

      expect(find.text('默认清单已恢复'), findsOneWidget);
      await _scrollToText(tester, '产褥垫组合装');
      expect(find.text('产褥垫组合装'), findsOneWidget);
    });

    testWidgets('device subpages mirror reminder and user config routes', (
      tester,
    ) async {
      final recorded = <Map<String, Object?>>[];
      final client = AgentStreamClientEventClient(recorder: recorded.add);

      await tester.pumpWidget(
        _FeaturePageHost(
          route: _route('/device/manage'),
          clientEventClient: client,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('设备提醒'), findsOneWidget);
      expect(find.text('任务提醒'), findsOneWidget);
      expect(find.text('健康问题通知'), findsOneWidget);

      await tester.tap(find.text('任务提醒'));
      await tester.pumpAndSettle();

      final body = recorded.single;
      expect(find.text('任务提醒已发送到设备提醒通道。'), findsOneWidget);
      expect(body['event_type'], 'device_reminder_action_triggered');
      expect(body['metadata'], containsPair('action_key', 'task_reminder'));
      expect(body.containsKey('user_id'), isFalse);
      expect(body.containsKey('thread_id'), isFalse);

      await tester.pumpWidget(_FeaturePageHost(route: _route('/device/user')));
      await tester.pumpAndSettle();

      expect(find.text('用户参数配置'), findsOneWidget);
      expect(find.text('用户名'), findsOneWidget);
      expect(find.text('用户类型'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('device-user-list-button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('device-user-stage-menu-icon')),
        findsOneWidget,
      );
      expect(find.text('删除用户'), findsOneWidget);
      expect(find.text('切换用户'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('device-user-list-button')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('device-user-list-panel')),
        findsOneWidget,
      );
    });

    testWidgets('community page renders construction empty state', (
      tester,
    ) async {
      await tester.pumpWidget(_FeaturePageHost(route: _route('/community')));
      await tester.pumpAndSettle();

      expect(find.text('社区功能还在建设中哦～'), findsOneWidget);
      expect(find.textContaining('我们将打造一个妈妈们一起交流分享的社区'), findsOneWidget);
      expect(find.text('妈妈小组更新'), findsNothing);
    });

    testWidgets('W1 page posts tutorial event before opening media viewer', (
      tester,
    ) async {
      final recorded = <Map<String, Object?>>[];
      final client = AgentStreamClientEventClient(recorder: recorded.add);
      final router = createMomCozyRouter(initialLocation: '/w1');

      await tester.pumpWidget(
        MomCozyFlutterApp(
          router: router,
          apiRuntime: _appRuntime(clientEventClient: client),
        ),
      );
      await tester.pumpAndSettle();

      await _tapScrollableText(tester, '使用教程');
      await tester.pumpAndSettle();

      final body = recorded.single;
      expect(
        find.byKey(const ValueKey('route-page-/media-viewer')),
        findsOneWidget,
      );
      expect(body['event_type'], 'w1_tutorial_opened');
      expect(body['metadata'], containsPair('target', 'media-viewer'));
      expect(body.containsKey('user_id'), isFalse);
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

int _switchesWithValue(WidgetTester tester, bool value) {
  return tester
      .widgetList<Switch>(find.byType(Switch))
      .where((switchWidget) => switchWidget.value == value)
      .length;
}

Future<void> _tapScrollableText(WidgetTester tester, String text) async {
  await _scrollToText(tester, text);
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

Future<void> _tapScrollableWidgetWithText(
  WidgetTester tester,
  Type widgetType,
  String text,
) async {
  final finder = find.widgetWithText(widgetType, text);
  await _scrollToFinder(tester, finder);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

Future<void> _tapDeviceQuickMenuItem(WidgetTester tester, String label) async {
  await tester.tap(find.byTooltip('打开设备快捷菜单'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Future<void> _acknowledgeCalibrationIntro(WidgetTester tester) async {
  expect(find.text('请先正确穿戴吸奶器'), findsOneWidget);
  await tester.tap(find.widgetWithText(FilledButton, '我已穿戴好'));
  await tester.pumpAndSettle();
}

Future<void> _scrollToText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await _scrollToFinder(tester, finder);
}

Future<void> _scrollToFinder(WidgetTester tester, Finder finder) async {
  for (final offset in const [Offset(0, -240), Offset(0, 240)]) {
    for (var attempt = 0; attempt < 12; attempt += 1) {
      if (finder.evaluate().isNotEmpty) return;
      await tester.drag(find.byType(Scrollable).first, offset);
      await tester.pump();
    }
  }
  expect(finder, findsWidgets);
}

void _expectFinderWithinViewport(WidgetTester tester, Finder finder) {
  expect(finder, findsOneWidget);
  final rect = tester.getRect(finder);
  final viewportWidth =
      tester.view.physicalSize.width / tester.view.devicePixelRatio;
  final viewportHeight =
      tester.view.physicalSize.height / tester.view.devicePixelRatio;

  expect(rect.left, greaterThanOrEqualTo(0));
  expect(rect.right, lessThanOrEqualTo(viewportWidth));
  expect(rect.top, greaterThanOrEqualTo(0));
  expect(rect.bottom, lessThanOrEqualTo(viewportHeight));
}

Future<void> _dismissPumpCalibrationPrompt(WidgetTester tester) async {
  final skipButton = find.widgetWithText(OutlinedButton, '先跳过');
  expect(skipButton, findsOneWidget);
  await tester.tap(skipButton);
  await tester.pumpAndSettle();
}

class _FeaturePageHost extends StatelessWidget {
  const _FeaturePageHost({
    required this.route,
    this.clientEventClient,
    this.jsonTransport,
    this.blePlatform,
    this.pumpProtocolPlatform,
  });

  final MomCozyRouteConfig route;
  final AgentStreamClientEventClient? clientEventClient;
  final FixtureApiJsonTransportByPath? jsonTransport;
  final BlePlatform? blePlatform;
  final PumpProtocolPlatform? pumpProtocolPlatform;

  @override
  Widget build(BuildContext context) {
    return MomCozyRuntimeScope(
      apiRuntime: _appRuntime(
        clientEventClient: clientEventClient,
        jsonTransport: jsonTransport,
        blePlatform: blePlatform,
        pumpProtocolPlatform: pumpProtocolPlatform,
      ),
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

class _RuntimeSwapFeaturePageHost extends StatefulWidget {
  const _RuntimeSwapFeaturePageHost({
    super.key,
    required this.route,
    required this.jsonTransport,
    required this.initialUserId,
    this.blePlatform,
  });

  final MomCozyRouteConfig route;
  final FixtureApiJsonTransportByPath jsonTransport;
  final String initialUserId;
  final BlePlatform? blePlatform;

  @override
  State<_RuntimeSwapFeaturePageHost> createState() =>
      _RuntimeSwapFeaturePageHostState();
}

class _RuntimeSwapFeaturePageHostState
    extends State<_RuntimeSwapFeaturePageHost> {
  late String _userId = widget.initialUserId;

  void switchUser(String userId) {
    setState(() {
      _userId = userId;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MomCozyRuntimeScope(
      apiRuntime: _appRuntime(
        jsonTransport: widget.jsonTransport,
        blePlatform: widget.blePlatform,
        userId: _userId,
      ),
      child: MaterialApp(
        theme: momCozyTheme(),
        home: Scaffold(
          body: MomCozyFeaturePage(
            path: widget.route.path,
            title: widget.route.title,
            summary: widget.route.summary,
            icon: widget.route.icon,
            accent: widget.route.accent,
            priority: widget.route.priority,
          ),
        ),
      ),
    );
  }
}

MomCozyApiRuntime _appRuntime({
  PumpProtocolPlatform? pumpProtocolPlatform,
  AgentStreamClientEventClient? clientEventClient,
  FixtureApiJsonTransportByPath? jsonTransport,
  BlePlatform? blePlatform,
  String userId = 'demo-user-fixture',
}) {
  return MomCozyApiRuntime(
    jsonTransport:
        jsonTransport ??
        FixtureApiJsonTransportByPath({
          statusProfileEndpoint: const <String, Object?>{
            'user_id': 'demo-user-fixture',
            'daily_summary': '哺乳期',
            'delivery_date': '2026-06-11',
          },
          statusInfantsEndpoint: const <String, Object?>{
            'items': <Object?>[
              <String, Object?>{
                'id': 'demo-baby-fixture',
                'owner_user_id': 'demo-user-fixture',
                'infant_name': 'Mia',
                'birth_date': '2026-04-05',
                'sex': 'female',
                'status': 'active',
              },
            ],
          },
          scheduleDayPlanEndpoint: const <String, Object?>{
            'items': <Object?>[
              <String, Object?>{
                'id': 'pump',
                'owner_user_id': 'demo-user-fixture',
                'task_date': '2026-07-01',
                'task_time': '10:30',
                'title': '泵奶',
                'description': '',
                'status': 'completed',
                'payload': <String, Object?>{},
              },
              <String, Object?>{
                'id': 'feeding',
                'owner_user_id': 'demo-user-fixture',
                'task_date': '2026-07-01',
                'task_time': '14:00',
                'title': '喂养',
                'description': '',
                'status': 'pending',
                'payload': <String, Object?>{},
              },
              <String, Object?>{
                'id': 'summary',
                'owner_user_id': 'demo-user-fixture',
                'task_date': '2026-07-01',
                'task_time': '20:30',
                'title': '晚间复盘',
                'description': '',
                'status': 'pending',
                'payload': <String, Object?>{},
              },
            ],
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
            'id': 'telemetry-001',
            'owner_user_id': 'demo-user-fixture',
            'device_id': 'app-pump-session',
            'event_type': 'workstate',
            'occurred_at': '2026-07-01T10:00:00Z',
            'payload': <String, Object?>{},
          },
        }),
    clientEventClient: clientEventClient,
    blePlatform:
        blePlatform ??
        FakeBlePlatform(
          initialPermission: BlePermissionState.granted,
          seedDevices: const [
            BleDeviceSnapshot(
              side: 'L',
              deviceId: 'ble-left-fixture',
              deviceName: 'S12 Pro L',
              connected: true,
            ),
          ],
        ),
    pumpProtocolPlatform: pumpProtocolPlatform,
    userId: userId,
    babyId: 'demo-baby-fixture',
    locale: 'zh-CN',
    now: () => DateTime.utc(2026, 7),
  );
}

class _ThrowingPumpProtocolPlatform implements PumpProtocolPlatform {
  const _ThrowingPumpProtocolPlatform(this.error);

  final Object error;

  @override
  Stream<PumpProtocolCommand> get commands => const Stream.empty();

  @override
  Future<void> adjustGearForSide(PumpSide side, int gear) async {
    throw error;
  }

  @override
  Future<void> endRun(PumpSide side) async {
    throw error;
  }

  @override
  Future<void> getDeviceInfo(PumpSide side) async {
    throw error;
  }

  @override
  Future<void> powerOff(PumpSide side, {bool reboot = false}) async {
    throw error;
  }

  @override
  Future<void> queryDeviceStatus(PumpSide side) async {
    throw error;
  }

  @override
  Future<void> setModeForSide(PumpSide side, int mode) async {
    throw error;
  }

  @override
  Future<void> setPumpParams(PumpSide side, PumpParamsRequest request) async {
    throw error;
  }

  @override
  Future<void> setRtc(PumpSide side, int utcSeconds) async {
    throw error;
  }

  @override
  Future<void> setSceneForSide(PumpSide side, int scene) async {
    throw error;
  }

  @override
  Future<void> setStartStopForSide(PumpSide side, int startStop) async {
    throw error;
  }
}

class _ConnectFailingBlePlatform extends FakeBlePlatform {
  _ConnectFailingBlePlatform({super.initialPermission});

  @override
  Future<void> connect(String deviceId) async {
    throw StateError('connect failed');
  }
}
