import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_io_transport.dart';
import 'package:momcozy_flutter_app/features/app_pages/momcozy_feature_pages.dart';
import 'package:momcozy_flutter_app/features/hospital_bag/data/hospital_bag_cart_api_repository.dart';
import 'package:momcozy_flutter_app/features/media/data/media_api_repository.dart';
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
      await _scrollToText(tester, '泵奶提醒');
      expect(find.text('泵奶提醒'), findsOneWidget);

      await tester.pumpWidget(_FeaturePageHost(route: _route('/device')));
      await tester.pump();
      expect(find.text('左右设备'), findsOneWidget);
      expect(find.text('BLE 权限和扫描'), findsOneWidget);

      await tester.pumpWidget(_FeaturePageHost(route: _route('/pump')));
      await tester.pump();
      expect(find.text('Session 控制'), findsOneWidget);
      await _scrollToText(tester, '上传状态');
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
      final pumpProtocol = FakePumpProtocolPlatform();

      await tester.pumpWidget(
        MomCozyFlutterApp(
          router: router,
          apiRuntime: _appRuntime(pumpProtocolPlatform: pumpProtocol),
        ),
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

      await _tapScrollableText(tester, '保存并进入泵奶');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('route-page-/pump')), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(
        pumpProtocol.recordedCommands.map(
          (command) =>
              '${command.name}:${command.side.name}:${command.payload['gear']}',
        ),
        ['adjustGearForSide:left:4', 'adjustGearForSide:right:4'],
      );

      router.go('/status');
      await tester.pumpAndSettle();
      await _tapScrollableText(tester, '补写孕期日记');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('route-page-/records')), findsOneWidget);

      router.go('/status');
      await tester.pumpAndSettle();
      await _tapScrollableText(tester, '今日待办');
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
      await pumpProtocol.dispose();
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

    testWidgets('status page switches care stage and records growth locally', (
      tester,
    ) async {
      await tester.pumpWidget(_FeaturePageHost(route: _route('/status')));
      await tester.pumpAndSettle();

      expect(find.text('产后第 21 天'), findsOneWidget);

      await tester.tap(find.text('孕期模式'));
      await tester.pumpAndSettle();

      expect(find.text('孕期'), findsOneWidget);
      expect(find.text('孕期重点：体征与日记'), findsOneWidget);

      await tester.tap(find.text('宝宝'));
      await tester.pumpAndSettle();

      expect(find.text('待记录'), findsOneWidget);

      await _tapScrollableText(tester, '记录成长事件');
      await tester.pumpAndSettle();

      expect(find.text('成长记录已添加'), findsOneWidget);
      expect(find.text('本地草稿已保存，同步恢复后会写入成长记录。'), findsOneWidget);
      expect(find.text('已添加'), findsOneWidget);
      expect(find.text('本地草稿待同步'), findsOneWidget);
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
            statusOverviewEndpoint: const {
              'status': 200,
              'data': {
                'mom': {
                  'stage': '哺乳期恢复阶段，需要同时关注睡眠、补水、泵奶舒适度和情绪波动',
                  'postpartum_day': 128,
                },
                'baby': {
                  'nickname': 'Mia Sophia Long Profile Name',
                  'age_days': 188,
                },
              },
            },
          }),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('哺乳期恢复阶段'), findsOneWidget);
      expect(find.text('demo-user-fixture'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('宝宝'));
      await tester.pumpAndSettle();

      expect(find.text('Mia Sophia Long Profile Name'), findsOneWidget);
      expect(find.text('demo-baby-fixture'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.drag(
        find.byKey(const ValueKey('route-page-/status')),
        const Offset(0, -360),
      );
      await tester.pump();

      await _scrollToText(tester, '今日待办');
      expect(find.text('今日待办'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('status page renders empty and failed states', (tester) async {
      await tester.pumpWidget(
        _FeaturePageHost(
          route: _route('/status'),
          jsonTransport: FixtureApiJsonTransportByPath({
            statusOverviewEndpoint: const {
              'status': 200,
              'data': <String, Object?>{},
            },
          }),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('暂无状态数据'), findsOneWidget);

      await tester.pumpWidget(
        _FeaturePageHost(
          route: _route('/status'),
          jsonTransport: FixtureApiJsonTransportByPath({
            statusOverviewEndpoint: const {
              'http_status': 500,
              'status_text': 'Server Error',
            },
          }),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('状态同步失败'), findsOneWidget);
      expect(find.text('检查后端连接或 token 后重试。'), findsOneWidget);
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

    testWidgets('schedule page switches date and reminder state', (
      tester,
    ) async {
      final transport = FixtureApiJsonTransportByPath({
        scheduleDayPlanEndpoint: const {
          'status': 200,
          'data': {
            'tasks': <Object?>[
              {
                'id': 'pump',
                'title': '10:30 泵奶',
                'completed': true,
                'remind_at': '2026-07-01T02:30:00Z',
              },
              {
                'id': 'feeding',
                'title': '14:00 喂养',
                'completed': false,
                'remind_at': '2026-07-01T06:00:00Z',
              },
            ],
          },
        },
      });

      await tester.pumpWidget(
        _FeaturePageHost(route: _route('/schedule'), jsonTransport: transport),
      );
      await tester.pumpAndSettle();

      expect(
        transport.lastQuery,
        containsPair('timestamp', _apiTimestamp(DateTime.utc(2026, 7))),
      );
      expect(find.text('2 项计划'), findsOneWidget);
      expect(_checkboxesWithValue(tester, true), 1);

      await tester.tap(find.text('03'));
      await tester.pumpAndSettle();

      expect(
        transport.lastQuery,
        containsPair('timestamp', _apiTimestamp(DateTime(2026, 7, 3))),
      );

      await tester.tap(find.text('14:00 喂养'));
      await tester.pump();
      expect(_checkboxesWithValue(tester, true), 2);

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

      expect(find.text('3 项计划'), findsOneWidget);
      expect(find.text('未完成 2'), findsOneWidget);
      expect(find.text('下一项倒计时'), findsOneWidget);

      await tester.tap(find.text('添加今日任务'));
      await tester.pumpAndSettle();

      expect(find.text('4 项计划'), findsOneWidget);
      expect(find.text('未完成 3'), findsOneWidget);
      await _scrollToText(tester, '本地补充 1');
      expect(find.text('本地补充 1'), findsOneWidget);

      await tester.tap(find.byTooltip('删除任务').last);
      await tester.pumpAndSettle();

      await tester.drag(find.byType(Scrollable).first, const Offset(0, 600));
      await tester.pumpAndSettle();

      expect(find.text('3 项计划'), findsOneWidget);
      expect(find.text('未完成 2'), findsOneWidget);
      expect(find.text('本地补充 1'), findsNothing);
    });

    testWidgets('schedule page renders cross-day countdown', (tester) async {
      await tester.pumpWidget(
        _FeaturePageHost(
          route: _route('/schedule'),
          jsonTransport: FixtureApiJsonTransportByPath({
            scheduleDayPlanEndpoint: const {
              'status': 200,
              'data': {
                'tasks': <Object?>[
                  {
                    'id': 'prenatal-check',
                    'title': '周五产检',
                    'completed': false,
                    'remind_at': '2026-07-03T06:00:00Z',
                  },
                ],
              },
            },
          }),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 项计划'), findsOneWidget);
      expect(find.text('未完成 1'), findsOneWidget);
      expect(find.textContaining('周五产检 还有 2 天 6 小时'), findsOneWidget);
    });

    testWidgets('schedule page renders empty and failed states', (
      tester,
    ) async {
      await tester.pumpWidget(
        _FeaturePageHost(
          route: _route('/schedule'),
          jsonTransport: FixtureApiJsonTransportByPath({
            scheduleDayPlanEndpoint: const {
              'status': 200,
              'data': {'tasks': <Object?>[]},
            },
          }),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('暂无计划'), findsOneWidget);
      expect(find.text('0 项计划'), findsOneWidget);

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

      expect(find.text('计划同步失败'), findsOneWidget);
      expect(find.text('检查后端连接或 token 后重试。'), findsOneWidget);
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

    testWidgets('records page switches mL and oz units', (tester) async {
      await tester.pumpWidget(_FeaturePageHost(route: _route('/records')));
      await tester.pumpAndSettle();

      expect(find.text('200 mL'), findsOneWidget);
      expect(find.textContaining('120 mL'), findsWidgets);

      await tester.tap(find.text('oz'));
      await tester.pumpAndSettle();

      expect(find.text('6.8 oz'), findsOneWidget);
      expect(find.textContaining('4.1 oz'), findsWidgets);

      await tester.tap(find.text('喂养'));
      await tester.pumpAndSettle();

      expect(find.textContaining('2.7 oz'), findsWidgets);
    });

    testWidgets('records page adds edits and deletes manual pump records', (
      tester,
    ) async {
      await tester.pumpWidget(_FeaturePageHost(route: _route('/records')));
      await tester.pumpAndSettle();

      await _scrollToText(tester, '手动补录');
      await tester.tap(find.text('手动补录'));
      await tester.pumpAndSettle();

      expect(find.textContaining('手动补录 1'), findsOneWidget);
      expect(find.text('90 mL · 来源 9'), findsOneWidget);

      await tester.tap(find.byTooltip('编辑记录').first);
      await tester.pumpAndSettle();

      expect(find.textContaining('已编辑 手动补录 1'), findsOneWidget);
      expect(find.text('100 mL · 来源 9'), findsOneWidget);

      await tester.tap(find.byTooltip('删除记录').first);
      await tester.pumpAndSettle();

      expect(find.textContaining('已编辑 手动补录 1'), findsNothing);
    });

    testWidgets('records page marks cross-day pump records', (tester) async {
      await tester.pumpWidget(
        _FeaturePageHost(
          route: _route('/records'),
          jsonTransport: FixtureApiJsonTransportByPath({
            pumpMilkRecordsEndpoint: const {
              'status': 200,
              'data': {
                'pump_milk_list': <Object?>[
                  {
                    'pump_id': 8001,
                    'pump_title': '夜间跨天泵奶',
                    'pump_milk_volum': 95,
                    'pump_time': '2026-06-30T23:30:00Z',
                  },
                ],
              },
            },
            feedingRecordsEndpoint: const {
              'status': 200,
              'data': {'records': <Object?>[]},
            },
            growthRecordsEndpoint: const {
              'status': 200,
              'data': {'records': <Object?>[]},
            },
          }),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('夜间跨天泵奶'), findsOneWidget);
      expect(find.textContaining('跨天记录'), findsOneWidget);
    });

    testWidgets('records page renders empty and failed states', (tester) async {
      await tester.pumpWidget(
        _FeaturePageHost(
          route: _route('/records'),
          jsonTransport: FixtureApiJsonTransportByPath({
            pumpMilkRecordsEndpoint: const {
              'status': 200,
              'data': {'pump_milk_list': <Object?>[]},
            },
            feedingRecordsEndpoint: const {
              'status': 200,
              'data': {'records': <Object?>[]},
            },
            growthRecordsEndpoint: const {
              'status': 200,
              'data': {'records': <Object?>[]},
            },
          }),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('0 mL'), findsOneWidget);
      expect(find.text('暂无奶量趋势'), findsOneWidget);
      expect(find.text('暂无泵奶记录'), findsOneWidget);

      await tester.tap(find.text('喂养'));
      await tester.pumpAndSettle();
      expect(find.text('暂无喂养记录'), findsOneWidget);

      await tester.tap(find.text('成长'));
      await tester.pumpAndSettle();
      expect(find.text('暂无成长记录'), findsOneWidget);

      await tester.pumpWidget(
        _FeaturePageHost(
          route: _route('/records'),
          jsonTransport: FixtureApiJsonTransportByPath({
            pumpMilkRecordsEndpoint: const {
              'http_status': 500,
              'status_text': 'Server Error',
            },
          }),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('记录同步失败'), findsOneWidget);
      expect(find.text('弱网/离线时保留本地筛选，可点击重试。'), findsOneWidget);
    });

    testWidgets('pump page uploads workstate through runtime repository', (
      tester,
    ) async {
      await tester.pumpWidget(_FeaturePageHost(route: _route('/pump')));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, '开始'));
      await tester.pumpAndSettle();

      await _scrollToText(tester, 'Workstate 已同步');
      expect(find.text('Workstate 已同步'), findsOneWidget);
      expect(find.text('Workstate accepted'), findsOneWidget);
    });

    testWidgets('pump page moves through local session states', (tester) async {
      await tester.pumpWidget(_FeaturePageHost(route: _route('/pump')));
      await tester.pumpAndSettle();

      expect(find.text('待开始'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, '开始'));
      await tester.pumpAndSettle();
      expect(find.text('进行中'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, '暂停'));
      await tester.pumpAndSettle();
      expect(find.text('已暂停'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, '恢复'));
      await tester.pumpAndSettle();
      expect(find.text('进行中'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, '结束'));
      await tester.pumpAndSettle();
      expect(find.text('待开始'), findsOneWidget);
    });

    testWidgets('pump page tracks side progress and blocks duplicate finish', (
      tester,
    ) async {
      final transport = FixtureApiJsonTransportByPath({
        pumpWorkstateEndpoint: const {
          'status': 200,
          'data': {
            'need_reply': true,
            'output': 'Workstate accepted',
            'reply_code': 'pump_state_changed',
            'reply_side': 'left',
          },
        },
      });

      await tester.pumpWidget(
        _FeaturePageHost(route: _route('/pump'), jsonTransport: transport),
      );
      await tester.pumpAndSettle();

      expect(find.text('0 分钟'), findsOneWidget);
      expect(find.text('0 mL'), findsNWidgets(2));

      await tester.tap(find.widgetWithText(FilledButton, '开始'));
      await tester.pumpAndSettle();

      expect(find.text('2 分钟'), findsOneWidget);
      expect(find.text('10 mL'), findsOneWidget);
      expect(find.text('8 mL'), findsOneWidget);
      expect(find.text('绑定 demo-user-fixture'), findsOneWidget);
      expect(transport.postedBodies, hasLength(1));
      expect(transport.postedBodies.first['user_id'], 'demo-user-fixture');
      expect(transport.postedBodies.first['device_left'], {
        'state': 1,
        'mode': 'massage_expression',
        'level': 5,
      });
      expect(transport.postedBodies.first['device_right'], {
        'state': 1,
        'mode': 'expression',
        'level': 5,
      });

      await tester.tap(find.widgetWithText(OutlinedButton, '结束'));
      await tester.tap(find.widgetWithText(OutlinedButton, '结束'));
      await tester.pumpAndSettle();

      expect(transport.postedBodies, hasLength(2));
      expect(transport.postedBodies.last['device_left'], {
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
          'status': 200,
          'data': {'output': 'Workstate accepted'},
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

      await tester.tap(find.widgetWithText(FilledButton, '开始'));
      await tester.pumpAndSettle();

      expect(find.text('绑定 user-a'), findsOneWidget);
      expect(transport.postedBodies.last['user_id'], 'user-a');

      hostKey.currentState!.switchUser('user-b');
      await tester.pumpAndSettle();

      expect(find.text('待开始'), findsOneWidget);
      expect(find.text('未绑定用户'), findsOneWidget);
      expect(find.text('0 分钟'), findsOneWidget);
      await _scrollToText(tester, '检测到用户切换，已清空上一用户 session。');
      expect(find.text('检测到用户切换，已清空上一用户 session。'), findsOneWidget);
      expect(transport.postedBodies, hasLength(1));

      await _tapScrollableText(tester, '开始');
      await tester.pumpAndSettle();

      expect(find.text('绑定 user-b'), findsOneWidget);
      expect(transport.postedBodies, hasLength(2));
      expect(transport.postedBodies.last['user_id'], 'user-b');
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

      await tester.tap(find.widgetWithText(FilledButton, '开始'));
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
      expect(find.textContaining('已恢复 1 台已连接设备'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, '扫描'));
      await tester.pump();

      expect(find.text('正在扫描附近设备'), findsOneWidget);
      expect(find.text('停止扫描'), findsOneWidget);
    });

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

      expect(find.text('左侧 等待连接'), findsOneWidget);
      expect(find.text('右侧 等待连接'), findsOneWidget);
      expect(find.textContaining('权限状态 未知'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, '扫描'));
      await tester.pumpAndSettle();

      expect(find.text('BLE 权限未授权'), findsOneWidget);
      expect(find.textContaining('已恢复 0 台已连接设备'), findsNothing);
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
      expect(find.textContaining('电量 87%'), findsOneWidget);
      expect(find.textContaining('已恢复 2 台已连接设备'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, '扫描'));
      await tester.pump();

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

      await tester.tap(find.widgetWithText(FilledButton, '扫描'));
      await tester.pump();

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

      await tester.tap(find.text('Nearby Pump L'));
      await tester.pumpAndSettle();

      expect(find.text('Nearby Pump L 已连接'), findsOneWidget);
      expect(find.text('左侧 Nearby Pump L'), findsOneWidget);
      expect(find.textContaining('状态 已连接 · 电量 76%'), findsOneWidget);

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

      await tester.tap(find.widgetWithText(FilledButton, '扫描'));
      await tester.pump();
      failingBle.addScanResult(
        const BleDeviceSnapshot(
          side: 'R',
          deviceId: 'nearby-right',
          deviceName: 'Nearby Pump R',
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Nearby Pump R'));
      await tester.pumpAndSettle();

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

        expect(find.text('左侧设备已连接'), findsOneWidget);
        expect(find.textContaining('Calibration L · 电量 83%'), findsOneWidget);
        expect(find.text('右侧设备未连接'), findsOneWidget);

        tester.widget<Slider>(find.byType(Slider).first).onChanged!(7);
        await tester.pump();

        expect(find.text('左侧 舒适档位 7'), findsOneWidget);

        await _tapScrollableText(tester, '退出校准');
        await tester.pumpAndSettle();

        expect(find.text('有未保存校准更改，请先保存或恢复默认后再退出。'), findsOneWidget);
      },
    );

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

      expect(find.text('左侧设备已连接'), findsOneWidget);
      expect(find.textContaining('Dual L · 电量 84%'), findsOneWidget);
      expect(find.text('右侧设备已连接'), findsOneWidget);
      expect(find.textContaining('Dual R · 电量 81%'), findsOneWidget);
    });

    testWidgets('media page uploads sample media through runtime repository', (
      tester,
    ) async {
      final multipart = FixtureApiMultipartTransport({
        'status': 200,
        'data': {
          'id': 'file-001',
          'name': 'pump-display-fixture.png',
          'size': 68,
          'extension': 'png',
          'mime_type': 'image/png',
        },
      });

      await tester.pumpWidget(
        _FeaturePageHost(
          route: _route('/media-viewer'),
          multipartTransport: multipart,
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byTooltip('上传'));
      await tester.tap(find.byTooltip('上传'));
      await tester.pumpAndSettle();

      expect(find.text('已上传 pump-display-fixture.png'), findsOneWidget);
      expect(find.textContaining('文件 ID file-001'), findsOneWidget);
      expect(multipart.lastPath, mediaUploadEndpoint);
      expect(multipart.lastFields, {'user_id': 'demo-user-fixture'});
      expect(multipart.lastFile?.name, 'pump-display-fixture.png');
    });

    testWidgets(
      'media page switches preview types and surfaces upload failure',
      (tester) async {
        final multipart = FixtureApiMultipartTransport(const {
          'http_status': 503,
          'status_text': 'Service Unavailable',
        });

        await tester.pumpWidget(
          _FeaturePageHost(
            route: _route('/media-viewer'),
            multipartTransport: multipart,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('PDF 预览'), findsOneWidget);

        await tester.tap(find.text('图片'));
        await tester.pumpAndSettle();
        expect(find.text('图片预览'), findsOneWidget);

        await tester.tap(find.text('视频'));
        await tester.pumpAndSettle();
        expect(find.text('视频预览'), findsOneWidget);

        await tester.ensureVisible(find.byTooltip('上传'));
        await tester.tap(find.byTooltip('上传'));
        await tester.pumpAndSettle();

        expect(find.text('媒体服务暂不可用，请稍后重试。'), findsOneWidget);
        expect(multipart.lastPath, mediaUploadEndpoint);
      },
    );

    testWidgets('IBCLC page posts client event through runtime client', (
      tester,
    ) async {
      final connector = _RecordingControlHttpConnector(
        const AgentStreamControlHttpResponse(
          statusCode: 200,
          body: '{"status":"ok"}',
        ),
      );
      final client = AgentStreamClientEventClient(
        endpoint: AgentStreamEndpoint(
          uri: Uri.parse('http://127.0.0.1:8769/api/client-event'),
          token: 'test-token',
        ),
        connector: connector,
      );

      await tester.pumpWidget(
        _FeaturePageHost(
          route: _route('/ibclc-chat.html'),
          clientEventClient: client,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '进入 IBCLC 咨询'));
      await tester.pumpAndSettle();

      final body = jsonDecode(connector.body!) as Map<String, Object?>;
      expect(find.text('咨询事件已同步。'), findsOneWidget);
      expect(connector.uri!.path, '/api/client-event');
      expect(
        connector.headers,
        containsPair('Authorization', 'Bearer test-token'),
      );
      expect(body['event_type'], 'ibclc_consult_started');
      expect(body['user_id'], 'demo-user-fixture');
      expect(body['thread_id'], 'thread-demo-user-fixture');
      expect(body['locale'], 'zh-CN');
      expect(body['metadata'], containsPair('source', 'ibclc-chat'));
    });

    testWidgets('IBCLC page enters local queue when event sync fails', (
      tester,
    ) async {
      final connector = _RecordingControlHttpConnector(
        const AgentStreamControlHttpResponse(
          statusCode: 503,
          body: '{"error":"unavailable"}',
        ),
      );
      final client = AgentStreamClientEventClient(
        endpoint: AgentStreamEndpoint(
          uri: Uri.parse('http://127.0.0.1:8769/api/client-event'),
          token: 'test-token',
        ),
        connector: connector,
      );

      await tester.pumpWidget(
        _FeaturePageHost(
          route: _route('/ibclc-chat.html'),
          clientEventClient: client,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '进入 IBCLC 咨询'));
      await tester.pumpAndSettle();

      expect(find.text('已进入咨询队列'), findsOneWidget);
      expect(find.text('本地已进入队列，稍后重试同步。'), findsOneWidget);
      expect(connector.uri!.path, '/api/client-event');
    });

    testWidgets('hospital bag page syncs cart changes through repository', (
      tester,
    ) async {
      await tester.pumpWidget(
        _FeaturePageHost(
          route: _route('/hospital-bag-cart'),
          jsonTransport: FixtureApiJsonTransportByPath({
            hospitalBagCartUpdateEndpoint: const {
              'status': 200,
              'data': {'message': '购物车已同步', 'synced_count': 3},
            },
          }),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Checkbox).at(1));
      await tester.pumpAndSettle();

      expect(find.text('2/3 已准备'), findsOneWidget);
      expect(find.text('购物车已同步'), findsOneWidget);
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

      await tester.tap(find.byType(Checkbox).at(1));
      await tester.pumpAndSettle();

      expect(find.text('2/3 已准备'), findsOneWidget);
      expect(find.text('本地清单已更新，稍后重试同步。'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        _FeaturePageHost(
          route: _route('/hospital-bag-cart'),
          jsonTransport: FixtureApiJsonTransportByPath({
            hospitalBagCartUpdateEndpoint: const {
              'status': 200,
              'data': {'message': '默认清单已恢复', 'synced_count': 3},
            },
          }),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Checkbox).at(1));
      await tester.pumpAndSettle();
      expect(find.text('2/3 已准备'), findsOneWidget);

      await tester.tap(find.text('恢复默认清单'));
      await tester.pumpAndSettle();

      expect(find.text('1/3 已准备'), findsOneWidget);
      expect(find.text('默认清单已恢复'), findsOneWidget);
    });

    testWidgets('device subpages read and update BLE runtime state', (
      tester,
    ) async {
      await tester.pumpWidget(
        _FeaturePageHost(route: _route('/device/manage')),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('L S12 Pro L'), findsOneWidget);
      expect(find.text('已同步 1 台设备。'), findsOneWidget);

      await tester.tap(find.text('解绑设备'));
      await tester.pumpAndSettle();

      expect(find.text('已解绑 1 台设备。'), findsOneWidget);
      expect(find.text('暂无已连接设备'), findsOneWidget);

      await tester.pumpWidget(_FeaturePageHost(route: _route('/device/user')));
      await tester.pumpAndSettle();

      expect(
        find.text('demo-user-fixture · baby demo-baby-fixture · zh-CN'),
        findsOneWidget,
      );
    });

    testWidgets('community page posts item open events', (tester) async {
      final connector = _RecordingControlHttpConnector(
        const AgentStreamControlHttpResponse(
          statusCode: 200,
          body: '{"status":"ok"}',
        ),
      );
      final client = AgentStreamClientEventClient(
        endpoint: AgentStreamEndpoint(
          uri: Uri.parse('http://127.0.0.1:8769/api/client-event'),
          token: 'test-token',
        ),
        connector: connector,
      );

      await tester.pumpWidget(
        _FeaturePageHost(
          route: _route('/community'),
          clientEventClient: client,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('妈妈小组更新'));
      await tester.pumpAndSettle();

      final body = jsonDecode(connector.body!) as Map<String, Object?>;
      expect(find.text('已记录 妈妈小组更新。'), findsOneWidget);
      expect(body['event_type'], 'community_item_opened');
      expect(body['metadata'], containsPair('item_key', 'group_updates'));
    });

    testWidgets('W1 page posts tutorial event before opening media viewer', (
      tester,
    ) async {
      final connector = _RecordingControlHttpConnector(
        const AgentStreamControlHttpResponse(
          statusCode: 200,
          body: '{"status":"ok"}',
        ),
      );
      final client = AgentStreamClientEventClient(
        endpoint: AgentStreamEndpoint(
          uri: Uri.parse('http://127.0.0.1:8769/api/client-event'),
          token: 'test-token',
        ),
        connector: connector,
      );
      final router = createMomCozyRouter(initialLocation: '/w1');

      await tester.pumpWidget(
        MomCozyFlutterApp(
          router: router,
          apiRuntime: _appRuntime(clientEventClient: client),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('使用教程'));
      await tester.tap(find.text('使用教程'));
      await tester.pumpAndSettle();

      final body = jsonDecode(connector.body!) as Map<String, Object?>;
      expect(
        find.byKey(const ValueKey('route-page-/media-viewer')),
        findsOneWidget,
      );
      expect(body['event_type'], 'w1_tutorial_opened');
      expect(body['metadata'], containsPair('target', 'media-viewer'));
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

String _apiTimestamp(DateTime value) {
  return value.toUtc().toIso8601String().replaceFirst('.000Z', 'Z');
}

Future<void> _tapScrollableText(WidgetTester tester, String text) async {
  final finder = find.text(text, skipOffstage: false);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

Future<void> _scrollToText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  for (var attempt = 0; attempt < 12; attempt += 1) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -240));
    await tester.pump();
  }
  expect(finder, findsOneWidget);
}

class _FeaturePageHost extends StatelessWidget {
  const _FeaturePageHost({
    required this.route,
    this.clientEventClient,
    this.jsonTransport,
    this.multipartTransport,
    this.blePlatform,
    this.pumpProtocolPlatform,
  });

  final MomCozyRouteConfig route;
  final AgentStreamClientEventClient? clientEventClient;
  final FixtureApiJsonTransportByPath? jsonTransport;
  final FixtureApiMultipartTransport? multipartTransport;
  final BlePlatform? blePlatform;
  final PumpProtocolPlatform? pumpProtocolPlatform;

  @override
  Widget build(BuildContext context) {
    return MomCozyRuntimeScope(
      apiRuntime: _appRuntime(
        clientEventClient: clientEventClient,
        jsonTransport: jsonTransport,
        multipartTransport: multipartTransport,
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
  });

  final MomCozyRouteConfig route;
  final FixtureApiJsonTransportByPath jsonTransport;
  final String initialUserId;

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
  FixtureApiMultipartTransport? multipartTransport,
  BlePlatform? blePlatform,
  String userId = 'demo-user-fixture',
}) {
  return MomCozyApiRuntime(
    jsonTransport:
        jsonTransport ??
        FixtureApiJsonTransportByPath({
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
    clientEventClient: clientEventClient,
    multipartTransport: multipartTransport,
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

class _RecordingControlHttpConnector
    implements AgentStreamControlHttpConnector {
  _RecordingControlHttpConnector(this.response);

  final AgentStreamControlHttpResponse response;
  Uri? uri;
  Map<String, String>? headers;
  String? body;

  @override
  Future<AgentStreamControlHttpResponse> post(
    Uri uri, {
    required Map<String, String> headers,
    required String body,
  }) async {
    this.uri = uri;
    this.headers = Map<String, String>.from(headers);
    this.body = body;
    return response;
  }
}
