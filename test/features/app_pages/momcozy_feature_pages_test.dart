import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_io_transport.dart';
import 'package:momcozy_flutter_app/features/agent_hub/data/ibclc_consult_store.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/ibclc_consult.dart';
import 'package:momcozy_flutter_app/features/app_pages/momcozy_feature_pages.dart';
import 'package:momcozy_flutter_app/features/media/data/product_asset_repository.dart';
import 'package:momcozy_flutter_app/features/plan/data/plan_api_repository.dart';
import 'package:momcozy_flutter_app/features/plan/domain/plan_dashboard.dart';
import 'package:momcozy_flutter_app/features/pump_session/data/pump_workstate_api_repository.dart';
import 'package:momcozy_flutter_app/features/records/data/records_api_repository.dart';
import 'package:momcozy_flutter_app/features/profile_overview/data/profile_overview_api_repository.dart';
import 'package:momcozy_flutter_app/native/p0_platform_interfaces.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import '../../support/fixture_api_transport.dart';
import '../../support/fake_agent_voice.dart';
import '../../support/fake_video_player_platform.dart';
import '../../support/test_pdf_fixture.dart';

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
        if (route.path == '/me') {
          expect(find.text('Postpartum Recovery'), findsWidgets);
        } else if (route.path == '/baby') {
          expect(find.text('Infant'), findsOneWidget);
        } else if (route.path == '/pump') {
          expect(find.text('沉浸式吸乳'), findsWidgets);
        } else if (route.path == '/device') {
          expect(find.text('设备连接'), findsWidgets);
        } else if (route.path == '/device/user') {
          expect(find.text('用户参数配置'), findsWidgets);
        } else if (route.path == '/community') {
          expect(find.text('社区功能还在建设中哦～'), findsWidgets);
        } else if (route.path == '/ibclc-chat.html') {
          expect(find.text('IBCLC 在线咨询'), findsWidgets);
        } else if (route.path == '/media-viewer') {
          expect(find.text('媒体'), findsWidgets);
        } else if (route.path == '/plan') {
          expect(find.text('No Plans Yet'), findsWidgets);
        } else if (route.path == '/more/body-profile/edit') {
          expect(
            find.byKey(const ValueKey('body-profile-save')),
            findsOneWidget,
          );
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

    testWidgets('device logout requires explicit confirmation', (tester) async {
      var logoutCalls = 0;
      await tester.pumpWidget(
        _FeaturePageHost(
          route: _route('/device'),
          onLogout: () async {
            logoutCalls += 1;
          },
        ),
      );
      await tester.pumpAndSettle();

      await _tapDeviceQuickMenuItem(tester, '退出登录');
      expect(
        find.byKey(const ValueKey('device-logout-dialog')),
        findsOneWidget,
      );
      expect(find.text('退出后需要重新输入邀请码登录。'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('device-logout-cancel')));
      await tester.pumpAndSettle();
      expect(logoutCalls, 0);
      expect(find.byKey(const ValueKey('device-logout-dialog')), findsNothing);

      await _tapDeviceQuickMenuItem(tester, '退出登录');
      await tester.tap(find.byKey(const ValueKey('device-logout-confirm')));
      await tester.pumpAndSettle();

      expect(logoutCalls, 1);
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

      expect(
        transport.mutationPaths.where((path) => path == pumpWorkstateEndpoint),
        hasLength(2),
      );
      expect(
        transport.mutationPaths.where(
          (path) => path == pumpMilkRecordsEndpoint,
        ),
        hasLength(1),
      );
      final lastWorkstateIndex = transport.mutationPaths.lastIndexOf(
        pumpWorkstateEndpoint,
      );
      final lastPayload =
          transport.postedBodies[lastWorkstateIndex]['payload']
              as Map<String, Object?>;
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

    testWidgets('pump completion preserves the stable plan task id', (
      tester,
    ) async {
      const taskId = '2ecbf33a-15c5-4d60-bff0-cd16ce36cdae';
      final transport = FixtureApiJsonTransportByPath(
        {
          pumpWorkstateEndpoint: const {
            'id': 'telemetry-001',
            'owner_user_id': 'demo-user-fixture',
            'device_id': 'app-pump-session',
            'event_type': 'workstate',
            'occurred_at': '2026-07-01T10:00:00Z',
            'payload': <String, Object?>{},
          },
        },
        writeResponsesByPath: {
          pumpMilkRecordsEndpoint: const {
            'id': '9f3e28d7-d927-4d50-a3ce-b24249f9578a',
            'pump_start_time': '2026-07-01T00:00:00Z',
            'milk_volume_ml': 27,
            'pump_type': 'manual',
            'source': 'manual',
          },
        },
      );
      final task = PlanSession(
        id: taskId,
        planId: 'milk-plan',
        title: 'Morning pumping',
        scheduledAt: DateTime.utc(2026, 7, 1),
        status: PlanSessionStatus.next,
        kind: PlanSessionKind.pumping,
      );

      await tester.pumpWidget(
        _FeaturePageHost(
          route: _route('/pump'),
          jsonTransport: transport,
          routeExtra: task,
        ),
      );
      await tester.pumpAndSettle();
      await _dismissPumpCalibrationPrompt(tester);
      await _tapScrollableText(tester, '开始');
      await tester.pumpAndSettle();
      await _tapScrollableText(tester, '结束');
      await tester.pumpAndSettle();

      final recordIndex = transport.mutationPaths.indexOf(
        pumpMilkRecordsEndpoint,
      );
      expect(recordIndex, isNonNegative);
      expect(transport.postedBodies[recordIndex], {
        'pump_start_time': '2026-07-01T00:00:00.000Z',
        'pump_end_time': '2026-07-01T00:00:00.000Z',
        'milk_volume_ml': 27.0,
        'duration_seconds': 180,
        'plan_task_id': taskId,
        'pump_type': 'manual',
        'source': 'manual',
      });
      expect(find.text('奶量记录与计划任务已原子完成。'), findsOneWidget);
    });

    testWidgets('non-record plan tasks start the matching Agent workflow', (
      tester,
    ) async {
      const taskId = 'd5e23a71-cb3a-423a-8bf8-34317efda608';
      Object? agentRouteExtra;
      final transport = FixtureApiJsonTransportByPath({
        planListEndpoint: const {
          'items': [
            {
              'id': 'f495db63-28a7-4b7d-a688-b294fab40226',
              'plan_type': 'yoga',
              'title': 'Recovery Yoga Plan',
              'summary': 'Postpartum recovery guidance',
              'status': 'active',
              'payload': <String, Object?>{},
            },
          ],
        },
        planSessionListEndpoint: const {
          'items': [
            {
              'id': taskId,
              'plan_id': 'f495db63-28a7-4b7d-a688-b294fab40226',
              'task_date': '2026-07-01',
              'task_time': '08:00',
              'title': 'Gentle recovery practice',
              'status': 'pending',
              'payload': {'activity_type': 'yoga'},
            },
          ],
        },
      });
      final router = createMomCozyRouter(
        initialLocation: '/plan',
        agentHubBuilder: (context, uri, extra, voicePlaybackCoordinator) {
          agentRouteExtra = extra;
          return const SizedBox(key: ValueKey('agent-plan-task-stub'));
        },
      );

      await tester.pumpWidget(
        MomCozyFlutterApp(
          router: router,
          apiRuntime: _appRuntime(jsonTransport: transport),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('route-page-/pump')), findsNothing);
      expect(
        find.byKey(const ValueKey('agent-plan-task-stub')),
        findsOneWidget,
      );
      final extra = agentRouteExtra! as Map;
      final autoRun = extra['agentAutoRun']! as Map;
      expect(
        autoRun['requestMessage'],
        'Guide me through "Gentle recovery practice".',
      );
      expect(autoRun['idempotencyKey'], 'plan-task-start:$taskId');
      expect(autoRun['metadata'], {'source': 'plan_task:$taskId'});
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

    testWidgets('media viewer rejects retired demo PDF URLs', (tester) async {
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
      expect(
        find.byKey(const ValueKey('media-viewer-load-error')),
        findsOneWidget,
      );
      expect(find.text('PDF 加载失败'), findsOneWidget);
      expect(find.text('缺少资源参数，请从资料卡片进入。'), findsNothing);
    });

    testWidgets('media page returns to the previous route when pushed', (
      tester,
    ) async {
      final router = createMomCozyRouter(initialLocation: '/me');

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

      expect(find.byKey(const ValueKey('route-page-/me')), findsOneWidget);
    });

    testWidgets('media viewer loads an authenticated product image with zoom', (
      tester,
    ) async {
      final repository = _productAssetRepository([
        _assetResponse(statusCode: 200, body: _onePixelPng),
      ]);
      final location = Uri(
        path: '/media-viewer',
        queryParameters: const {
          'kind': 'image',
          'url': '/v1/assets/asset-image?kind=image',
          'title': 'Air1 核心部件',
        },
      ).toString();
      final router = createMomCozyRouter(initialLocation: location);

      await tester.pumpWidget(
        MomCozyFlutterApp(
          apiRuntime: _appRuntime(productAssetRepository: repository),
          router: router,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Air1 核心部件'), findsOneWidget);
      expect(find.byKey(const ValueKey('media-image-viewer')), findsOneWidget);
      expect(find.byKey(const ValueKey('product-asset-image')), findsOneWidget);
      final viewer = tester.widget<InteractiveViewer>(
        find.byKey(const ValueKey('media-image-interactive-viewer')),
      );
      expect(viewer.minScale, 1);
      expect(viewer.maxScale, 5);
      expect(viewer.panEnabled, isTrue);

      final imageViewer = find.byKey(const ValueKey('media-image-viewer'));
      final center = tester.getCenter(imageViewer);
      await tester.tapAt(center);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(center);
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        viewer.transformationController!.value.getMaxScaleOnAxis(),
        closeTo(2.5, 0.01),
      );
    });

    testWidgets('media image failure can be retried without leaving the page', (
      tester,
    ) async {
      final connector = _FakeProductAssetConnector([
        _assetResponse(statusCode: 503, contentType: 'application/json'),
        _assetResponse(statusCode: 200, body: _onePixelPng),
      ]);
      final repository = ProductAssetRepository(
        baseUri: Uri.parse('https://api.example.test'),
        connector: connector,
      );
      final router = createMomCozyRouter(
        initialLocation: Uri(
          path: '/media-viewer',
          queryParameters: const {
            'kind': 'image',
            'url': '/v1/assets/asset-image?kind=image',
          },
        ).toString(),
      );

      await tester.pumpWidget(
        MomCozyFlutterApp(
          apiRuntime: _appRuntime(productAssetRepository: repository),
          router: router,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('media-viewer-load-error')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('media-viewer-retry')));
      await tester.pumpAndSettle();

      expect(connector.calls, 2);
      expect(find.byKey(const ValueKey('product-asset-image')), findsOneWidget);
    });

    testWidgets('media viewer loads an authenticated multi-page PDF', (
      tester,
    ) async {
      _installPathProviderMock();
      final connector = _FakeProductAssetConnector([
        _assetResponse(
          statusCode: 200,
          contentType: 'application/pdf',
          body: buildTwoPageTestPdf(),
        ),
      ]);
      final repository = ProductAssetRepository(
        baseUri: Uri.parse('https://api.example.test'),
        connector: connector,
      );
      final router = createMomCozyRouter(
        initialLocation: Uri(
          path: '/media-viewer',
          queryParameters: const {
            'kind': 'pdf',
            'url': '/v1/assets/asset-pdf?kind=pdf',
            'title': 'Air1 快速上手指南',
          },
        ).toString(),
      );

      await tester.pumpWidget(
        MomCozyFlutterApp(
          apiRuntime: _appRuntime(productAssetRepository: repository),
          router: router,
        ),
      );
      await _pumpUntilFound(
        tester,
        find.byKey(const ValueKey('media-pdf-viewer')),
      );

      expect(connector.calls, 1);
      expect(find.text('Air1 快速上手指南'), findsOneWidget);
      final viewer = tester.widget<PdfViewer>(find.byType(PdfViewer));
      expect(viewer.params.minScale, 0.1);
      expect(viewer.params.maxScale, 4);
      expect(viewer.params.panAxis, PanAxis.free);
      expect(viewer.controller, isNotNull);
      expect(viewer.key, const ValueKey('media-pdf-document-1'));
      final documentRef = viewer.documentRef as PdfDocumentRefData;
      expect(latin1.decode(documentRef.data), contains('/Count 2'));
    });

    testWidgets('media PDF failure can be retried without leaving the page', (
      tester,
    ) async {
      _installPathProviderMock();
      final connector = _FakeProductAssetConnector([
        _assetResponse(statusCode: 503, contentType: 'application/json'),
        _assetResponse(
          statusCode: 200,
          contentType: 'application/pdf',
          body: buildTwoPageTestPdf(),
        ),
      ]);
      final repository = ProductAssetRepository(
        baseUri: Uri.parse('https://api.example.test'),
        connector: connector,
      );
      final router = createMomCozyRouter(
        initialLocation: Uri(
          path: '/media-viewer',
          queryParameters: const {
            'kind': 'pdf',
            'url': '/v1/assets/asset-pdf?kind=pdf',
          },
        ).toString(),
      );

      await tester.pumpWidget(
        MomCozyFlutterApp(
          apiRuntime: _appRuntime(productAssetRepository: repository),
          router: router,
        ),
      );
      await _pumpUntilFound(
        tester,
        find.byKey(const ValueKey('media-viewer-load-error')),
      );

      await tester.tap(find.byKey(const ValueKey('media-viewer-retry')));
      await _pumpUntilFound(
        tester,
        find.byKey(const ValueKey('media-pdf-viewer')),
      );

      expect(connector.calls, 2);
      expect(find.byType(PdfViewer), findsOneWidget);
      expect(
        tester.widget<PdfViewer>(find.byType(PdfViewer)).key,
        const ValueKey('media-pdf-document-2'),
      );
    });

    testWidgets('media viewer streams an authenticated video request', (
      tester,
    ) async {
      final previousPlatform = VideoPlayerPlatform.instance;
      final videoPlatform = FakeVideoPlayerPlatform();
      VideoPlayerPlatform.instance = videoPlatform;
      addTearDown(() {
        VideoPlayerPlatform.instance = previousPlatform;
      });
      final repository = ProductAssetRepository(
        baseUri: Uri.parse('https://api.example.test'),
        tokenProvider: () => 'route-video-token',
        connector: _FakeProductAssetConnector(const []),
      );
      final router = createMomCozyRouter(
        initialLocation: Uri(
          path: '/media-viewer',
          queryParameters: const {
            'kind': 'video',
            'url': '/v1/assets/asset-video?kind=video',
            'title': 'Air1 操作视频',
          },
        ).toString(),
      );

      await tester.pumpWidget(
        MomCozyFlutterApp(
          apiRuntime: _appRuntime(productAssetRepository: repository),
          router: router,
        ),
      );
      await _pumpUntilFoundWithPlatformEvents(
        tester,
        find.byKey(const ValueKey('product-asset-video-player')),
      );

      expect(find.text('Air1 操作视频'), findsOneWidget);
      expect(videoPlatform.createdSources, hasLength(1));
      final source = videoPlatform.createdSources.single;
      expect(source.uri, 'https://api.example.test/v1/assets/asset-video');
      expect(source.httpHeaders['Authorization'], 'Bearer route-video-token');
      expect(source.httpHeaders['Accept'], 'video/*');
    });

    testWidgets('IBCLC page posts client event through runtime client', (
      tester,
    ) async {
      final recorded = <Map<String, Object?>>[];
      final client = AgentStreamClientEventClient(recorder: recorded.add);
      final consultStore = IbclcConsultStore.inMemory(
        now: () => DateTime.utc(2026, 7, 11),
      );
      const routeState = IbclcConsultRouteState(
        consultId: 'consult-feature',
        sourceArtifactId: 'artifact-feature',
        threadId: 'thread-feature',
        runId: 'run-feature',
        returnPath: '/',
        consultantName: 'Lin Zhao',
        reason: '含乳疼痛',
        feedingContext: '左侧喂养后疼痛',
      );

      await tester.pumpWidget(
        _FeaturePageHost(
          route: _route('/ibclc-chat.html'),
          clientEventClient: client,
          ibclcConsultStore: consultStore,
          routeExtra: routeState,
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
      expect(body['metadata'], containsPair('consult_id', 'consult-feature'));
      expect(body['metadata'], containsPair('thread_id', 'thread-feature'));
      expect(body['metadata'], containsPair('return_to', '/'));
      expect(body['metadata'], containsPair('reason', '含乳疼痛'));
    });

    testWidgets(
      'IBCLC page reports unsynced state without claiming a retry queue',
      (tester) async {
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

        expect(find.text('已进入咨询，但本次状态未同步。'), findsOneWidget);
      },
    );

    testWidgets('IBCLC page completes the consult and returns to Agent Hub', (
      tester,
    ) async {
      final recorded = <Map<String, Object?>>[];
      final client = AgentStreamClientEventClient(recorder: recorded.add);
      final consultStore = IbclcConsultStore.inMemory(
        now: () => DateTime.utc(2026, 7, 11),
      );
      const routeState = IbclcConsultRouteState(
        consultId: 'consult-route',
        sourceArtifactId: 'artifact-route',
        threadId: 'thread-route',
        runId: 'run-route',
        returnPath: '/',
        consultantName: 'Lin Zhao',
        reason: '含乳疼痛',
      );
      final router = createMomCozyRouter();

      await tester.pumpWidget(
        MomCozyFlutterApp(
          router: router,
          apiRuntime: _appRuntime(
            clientEventClient: client,
            ibclcConsultStore: consultStore,
          ),
        ),
      );
      await tester.pumpAndSettle();

      router.go('/ibclc-chat.html', extra: routeState);
      await tester.pumpAndSettle();

      await tester.pump(const Duration(seconds: 8));
      await tester.pumpAndSettle();

      expect(find.textContaining('你好，我是 Lin Zhao'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('ibclc-return-status-button')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('agent-hub-page')), findsOneWidget);
      expect(consultStore.isCompleted('consult-route'), isTrue);
      expect(
        recorded.map((event) => event['event_type']),
        containsAllInOrder([
          'ibclc_consult_started',
          'ibclc_consult_completed',
        ]),
      );
      final completed = recorded.last;
      expect(
        completed['metadata'],
        containsPair('consult_id', 'consult-route'),
      );
      expect(completed['metadata'], containsPair('thread_id', 'thread-route'));
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
      expect(find.text('每日奶量总结'), findsNothing);
      expect(find.text('每日泌乳建议'), findsNothing);
      expect(find.text('宝宝生长发育指标更新'), findsNothing);
      expect(find.text('健康问题通知'), findsNothing);

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
      expect(find.text('用户类型'), findsNothing);
      expect(
        find.byKey(const ValueKey('device-user-list-button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('device-user-stage-menu-icon')),
        findsNothing,
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

Future<void> _tapScrollableText(WidgetTester tester, String text) async {
  await _scrollToText(tester, text);
  final finder = find.text(text);
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
    this.routeExtra,
    this.ibclcConsultStore,
    this.onLogout,
  });

  final MomCozyRouteConfig route;
  final AgentStreamClientEventClient? clientEventClient;
  final FixtureApiJsonTransportByPath? jsonTransport;
  final BlePlatform? blePlatform;
  final PumpProtocolPlatform? pumpProtocolPlatform;
  final Object? routeExtra;
  final IbclcConsultStore? ibclcConsultStore;
  final Future<void> Function()? onLogout;

  @override
  Widget build(BuildContext context) {
    return MomCozyRuntimeScope(
      apiRuntime: _appRuntime(
        clientEventClient: clientEventClient,
        jsonTransport: jsonTransport,
        blePlatform: blePlatform,
        pumpProtocolPlatform: pumpProtocolPlatform,
        ibclcConsultStore: ibclcConsultStore,
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
            routeExtra: routeExtra,
            onLogout: onLogout,
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
  ProductAssetRepository? productAssetRepository,
  IbclcConsultStore? ibclcConsultStore,
  String userId = 'demo-user-fixture',
}) {
  return MomCozyApiRuntime(
    jsonTransport:
        jsonTransport ??
        FixtureApiJsonTransportByPath({
          profileMeEndpoint: const <String, Object?>{
            'user_id': 'demo-user-fixture',
            'actual_delivery_date': '2026-06-11',
          },
          profileInfantsEndpoint: const <String, Object?>{
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
          planListEndpoint: const <String, Object?>{'items': <Object?>[]},
          pumpMilkRecordsEndpoint: const <String, Object?>{
            'items': <Object?>[
              <String, Object?>{
                'id': 'pumping-7001',
                'pump_type': 'manual',
                'pump_start_time': '2026-07-01T02:40:00Z',
                'milk_volume_ml': 120,
              },
            ],
          },
          milkTrendsEndpoint: const <String, Object?>{
            'items': <Object?>[
              <String, Object?>{
                'date': '2026-06-30',
                'pumped_milk_volume_ml': 110,
                'pumping_count': 2,
                'measured_only': true,
              },
              <String, Object?>{
                'date': '2026-07-01',
                'pumped_milk_volume_ml': 120,
                'pumping_count': 1,
                'measured_only': true,
              },
            ],
            'days': 31,
            'include_today': true,
          },
          feedingRecordsEndpoint: const <String, Object?>{
            'items': <Object?>[
              <String, Object?>{
                'id': 'feeding-1001',
                'infant_id': 'demo-baby-fixture',
                'feed_type': 'bottle',
                'volume_ml': 80,
                'feed_time': '2026-07-01T06:00:00Z',
              },
            ],
          },
          feedingSummaryEndpoint: _appPageFeedingSummary(),
          growthRecordsEndpoint: const <String, Object?>{
            'items': <Object?>[
              <String, Object?>{
                'id': 'growth-1001',
                'weight_kg': 6.2,
                'height_cm': 64.5,
                'head_cm': 42,
                'measurement_position': 'recumbent',
                'measurement_context': 'routine',
                'measured_at': '2026-07-01T12:00:00Z',
              },
            ],
            'id': 'growth-1001',
            'weight_kg': 6.2,
            'height_cm': 64.5,
            'head_cm': 42,
            'measurement_position': 'recumbent',
            'measurement_context': 'routine',
            'measured_at': '2026-07-01T12:00:00Z',
          },
          '$growthRecordsEndpoint/growth-1001': const <String, Object?>{
            'id': 'growth-1001',
            'weight_kg': 6.2,
            'height_cm': 64.5,
            'head_cm': 42,
            'measurement_position': 'recumbent',
            'measurement_context': 'routine',
            'measured_at': '2026-07-01T12:00:00Z',
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
    clientEventClient:
        clientEventClient ?? const AgentStreamClientEventClient(sent: false),
    agentVoicePlaybackPlayer: const ImmediateAgentVoicePlaybackPlayer(),
    productAssetRepository: productAssetRepository,
    ibclcConsultStore: ibclcConsultStore,
    multipartTransport: FixtureApiMultipartTransport(const <String, Object?>{
      'status': 200,
      'data': <String, Object?>{
        'text': '',
        'audio_url': '/audio/test-voice.mp3',
      },
    }),
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
    timezoneProvider: () async => 'UTC',
  );
}

Map<String, Object?> _appPageFeedingSummary() => <String, Object?>{
  'days': 7,
  'timezone': 'UTC',
  'feeding_count': 1,
  'measured_volume_count': 1,
  'measured_volume_ml': 80,
  'average_measured_volume_ml': 80,
  'feeding_method_counts': <String, Object?>{'bottle': 1},
  'milk_source_volumes_ml': <String, Object?>{'breast_milk': 80},
  'latest_feeding_at': '2026-07-01T06:00:00Z',
  'completed_days': <String, Object?>{
    'window_days': 6,
    'recorded_days': 1,
    'measured_days': 1,
    'average_volume_per_measured_day_ml': 80,
    'average_feedings_per_recorded_day': 1,
    'daily_series': <Object?>[
      for (final date in <String>[
        '2026-06-25',
        '2026-06-26',
        '2026-06-27',
        '2026-06-28',
        '2026-06-29',
        '2026-06-30',
      ])
        <String, Object?>{
          'date': date,
          'measured_volume_ml': date == '2026-06-30' ? 80 : null,
          'feeding_count': date == '2026-06-30' ? 1 : 0,
          'measured_feeding_count': date == '2026-06-30' ? 1 : 0,
        },
    ],
  },
  'comparison': <String, Object?>{
    'status': 'insufficient_data',
    'current_average_volume_per_measured_day_ml': 80,
    'previous_average_volume_per_measured_day_ml': null,
    'change_percent': null,
    'current_measured_days': 1,
    'previous_measured_days': 0,
    'minimum_measured_days': 5,
  },
  'intake_evaluation_context': <String, Object?>{
    'status': 'insufficient_data',
    'reason_code': 'growth_record_missing',
    'growth_measurement_date': null,
    'chronological_age_days': null,
  },
};

final _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);

ProductAssetRepository _productAssetRepository(
  List<ProductAssetHttpResponse> responses,
) {
  return ProductAssetRepository(
    baseUri: Uri.parse('https://api.example.test'),
    connector: _FakeProductAssetConnector(responses),
  );
}

ProductAssetHttpResponse _assetResponse({
  required int statusCode,
  String contentType = 'image/png',
  Uint8List? body,
}) {
  return ProductAssetHttpResponse(
    statusCode: statusCode,
    statusText: statusCode == 200 ? 'OK' : 'Unavailable',
    contentType: contentType,
    body: body ?? Uint8List(0),
  );
}

class _FakeProductAssetConnector implements ProductAssetHttpConnector {
  _FakeProductAssetConnector(List<ProductAssetHttpResponse> responses)
    : _responses = List.of(responses);

  final List<ProductAssetHttpResponse> _responses;
  int calls = 0;

  @override
  Future<ProductAssetHttpResponse> get(
    Uri uri, {
    required Map<String, String> headers,
    required int maxBytes,
  }) async {
    calls += 1;
    return _responses.removeAt(0);
  }
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var frame = 0; frame < 80; frame += 1) {
    await tester.pump(const Duration(milliseconds: 16));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail(
    'Expected widget did not appear '
    '(pdfViewer=${find.byType(PdfViewer).evaluate().length}, '
    'loadError=${find.byKey(const ValueKey('media-viewer-load-error')).evaluate().length}, '
    'loading=${find.byKey(const ValueKey('media-viewer-loading')).evaluate().length}).',
  );
}

Future<void> _pumpUntilFoundWithPlatformEvents(
  WidgetTester tester,
  Finder finder,
) async {
  for (var frame = 0; frame < 80; frame += 1) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Expected platform-backed widget did not appear.');
}

void _installPathProviderMock() {
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  final directory = Directory.systemTemp.createTempSync('momcozy-pdf-test-');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getTemporaryDirectory') return directory.path;
        return null;
      });
  addTearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });
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
