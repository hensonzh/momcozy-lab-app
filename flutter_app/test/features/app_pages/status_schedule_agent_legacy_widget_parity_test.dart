import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/app/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_client.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_event.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_io_transport.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_runner.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_page.dart';
import 'package:momcozy_flutter_app/features/pregnancy_diary/data/pregnancy_diary_api_repository.dart';
import 'package:momcozy_flutter_app/features/pregnancy_plan/data/pregnancy_plan_api_repository.dart';
import 'package:momcozy_flutter_app/features/schedule/data/schedule_api_repository.dart';
import 'package:momcozy_flutter_app/features/schedule/domain/milk_plan_change_store.dart';
import 'package:momcozy_flutter_app/features/records/data/records_api_repository.dart';
import 'package:momcozy_flutter_app/features/status/data/status_api_repository.dart';
import 'package:momcozy_flutter_app/native/p0_platform_interfaces.dart';

import '../../support/fixture_api_transport.dart';
import '../../support/fixture_reader.dart';
import '../../support/fake_agent_voice.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async {
          return switch (call.method) {
            'read' => null,
            'readAll' => <String, String>{},
            'containsKey' => false,
            'write' || 'delete' || 'deleteAll' => null,
            _ => null,
          };
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, null);
  });

  group('Legacy Web widget parity: 宝宝和我', () {
    testWidgets('covers postpartum mom widgets, trend card, and bottom nav', (
      tester,
    ) async {
      await _setCompactViewport(tester);
      final routeIntentPlatform = FakeRouteIntentPlatform();
      addTearDown(routeIntentPlatform.dispose);

      await tester.pumpWidget(
        MomCozyFlutterApp(
          router: createMomCozyRouter(initialLocation: '/status'),
          routeIntentPlatform: routeIntentPlatform,
          apiRuntime: _runtime(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('route-page-/status')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('status-care-stage-pregnancy')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('status-care-stage-postpartum')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('status-identity-tab-mom')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('status-identity-tab-baby')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('status-postpartum-mom-module-grid')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('status-module-milk-output')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('status-module-breast-health')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('status-module-postpartum-recovery')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('status-module-rest-nutrition')),
        findsOneWidget,
      );
      expect(find.text('母乳产出'), findsOneWidget);
      expect(find.text('210mL'), findsOneWidget);
      expect(find.text('3次'), findsOneWidget);
      expect(find.text('乳房健康'), findsOneWidget);
      expect(find.text('产后恢复'), findsOneWidget);
      expect(find.text('补能与休息'), findsOneWidget);

      await _scrollToFinder(
        tester,
        find.byKey(const ValueKey('status-milk-trend-preview')),
      );
      expect(
        find.byKey(const ValueKey('status-milk-trend-preview')),
        findsOneWidget,
      );
      expect(find.text('母乳趋势'), findsOneWidget);
      expect(find.text('吸乳总量'), findsOneWidget);

      expect(find.text('下一步'), findsNothing);
      expect(find.text('补写孕期日记'), findsNothing);
      expect(find.text('今日待办'), findsNothing);
      expect(find.byKey(const ValueKey('bottom-nav-status')), findsOneWidget);
      expect(find.byKey(const ValueKey('bottom-nav-agent')), findsOneWidget);
      for (final label in const ['宝宝和我', '计划', '社区', '设备']) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets(
      'covers pregnancy widgets, disabled baby tab, and hidden sync failure',
      (tester) async {
        await _setCompactViewport(tester);
        final routeIntentPlatform = FakeRouteIntentPlatform();
        addTearDown(routeIntentPlatform.dispose);

        await tester.pumpWidget(
          MomCozyFlutterApp(
            router: createMomCozyRouter(initialLocation: '/status'),
            routeIntentPlatform: routeIntentPlatform,
            apiRuntime: _runtime(),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey('status-care-stage-pregnancy')),
        );
        await tester.pumpAndSettle();

        expect(find.text('孕期日记'), findsOneWidget);
        expect(find.text('孕期计划'), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey('status-identity-tab-baby')),
        );
        await tester.pumpAndSettle();
        expect(find.text('孕期日记'), findsOneWidget);
        expect(find.text('宝宝成长曲线'), findsNothing);

        await tester.tap(
          find.byKey(const ValueKey('status-pregnancy-diary-view-button')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('status-detail-pregnancy-diary')),
          findsOneWidget,
        );
        expect(find.text('还没有孕期日记'), findsOneWidget);
        await tester.tap(find.byTooltip('关闭详情'));
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey('status-pregnancy-diary-record-button')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('status-pregnancy-diary-editor-dialog')),
          findsOneWidget,
        );
        await tester.enterText(
          find.byKey(const ValueKey('status-pregnancy-diary-note-input')),
          '今天胎动规律，想问医生睡眠问题。',
        );
        await tester.tap(
          find.byKey(const ValueKey('status-pregnancy-diary-save-button')),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('今天的记录已保存'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('status-detail-pregnancy-diary')),
          findsOneWidget,
        );
        await tester.tap(find.byTooltip('关闭详情'));
        await tester.pumpAndSettle();

        await _scrollToFinder(
          tester,
          find.byKey(const ValueKey('status-pregnancy-plan-agent-button')),
        );
        await tester.tap(
          find.byKey(const ValueKey('status-pregnancy-plan-agent-button')),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('agent-hub-page')), findsOneWidget);
        expect(
          tester
              .widget<TextField>(
                find.byKey(const ValueKey('agent-composer-input')),
              )
              .controller
              ?.text,
          '帮我生成孕期计划',
        );

        final failingRouteIntentPlatform = FakeRouteIntentPlatform();
        addTearDown(failingRouteIntentPlatform.dispose);

        await tester.pumpWidget(
          MomCozyFlutterApp(
            key: UniqueKey(),
            router: createMomCozyRouter(initialLocation: '/status'),
            routeIntentPlatform: failingRouteIntentPlatform,
            apiRuntime: _runtime(
              responsesByPath: {
                statusProfileEndpoint: const {
                  'http_status': 503,
                  'status_text': 'Service Unavailable',
                },
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('状态同步失败'), findsNothing);
        expect(find.text('检查后端连接或 token 后重试。'), findsNothing);
        expect(find.byTooltip('重试'), findsNothing);
      },
    );

    testWidgets('loads, blocks, details, and deletes a birth journey plan', (
      tester,
    ) async {
      await _setCompactViewport(tester);
      final routeIntentPlatform = FakeRouteIntentPlatform();
      addTearDown(routeIntentPlatform.dispose);

      await tester.pumpWidget(
        MomCozyFlutterApp(
          router: createMomCozyRouter(initialLocation: '/status'),
          routeIntentPlatform: routeIntentPlatform,
          apiRuntime: _runtime(
            responsesByPath: {
              pregnancyPlansEndpoint: _birthJourneyPlanResponse(),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('status-care-stage-pregnancy')),
      );
      await tester.pumpAndSettle();

      expect(find.text('当前阶段'), findsOneWidget);
      expect(find.text('准备产检资料'), findsOneWidget);
      await _scrollToFinder(
        tester,
        find.byKey(const ValueKey('status-birth-journey-period-upcoming')),
      );
      await tester.tap(
        find.byKey(const ValueKey('status-birth-journey-period-upcoming')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('status-birth-journey-todo-todo-upcoming')),
      );
      await tester.pump();
      expect(find.text('当前还未到该阶段，暂不适合进行该事项'), findsOneWidget);

      await _scrollToFinder(
        tester,
        find.byKey(const ValueKey('status-birth-journey-detail-button')),
      );
      await tester.tap(
        find.byKey(const ValueKey('status-birth-journey-detail-button')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('status-detail-birth-journey')),
        findsOneWidget,
      );
      final deleteButton = find.byKey(
        const ValueKey('status-birth-journey-delete-button'),
      );
      await tester.ensureVisible(deleteButton);
      await tester.tap(deleteButton);
      await tester.pump();
      await tester.tap(
        find.byKey(
          const ValueKey('status-birth-journey-delete-confirm-button'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('status-detail-birth-journey')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('status-pregnancy-plan-agent-button')),
        findsOneWidget,
      );
    });

    testWidgets('hands birth journey todo to Agent with auto-send', (
      tester,
    ) async {
      await _setCompactViewport(tester);
      final routeIntentPlatform = FakeRouteIntentPlatform();
      addTearDown(routeIntentPlatform.dispose);
      Object? routedExtra;
      final router = createMomCozyRouter(
        initialLocation: '/status',
        agentHubBuilder: (context, uri, extra, voicePlaybackCoordinator) {
          if (uri?.path == '/') routedExtra = extra;
          return const SizedBox(key: ValueKey('captured-agent-route'));
        },
      );

      await tester.pumpWidget(
        MomCozyFlutterApp(
          router: router,
          routeIntentPlatform: routeIntentPlatform,
          apiRuntime: _runtime(
            responsesByPath: {
              pregnancyPlansEndpoint: _birthJourneyPlanResponse(),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('status-care-stage-pregnancy')),
      );
      await tester.pumpAndSettle();

      final currentTodo = find.byKey(
        const ValueKey('status-birth-journey-todo-todo-current'),
      );
      await _scrollToFinder(tester, currentTodo);
      await tester.tap(currentTodo);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('captured-agent-route')),
        findsOneWidget,
      );
      expect(routedExtra, {
        'agentPrefill': '我已完成【准备产检资料】，请基于这个事项继续追问需要补充的执行细节，并在需要时同步更新我的孕期日记',
        'agentAutoSend': true,
      });
      expect(tester.takeException(), isNull);
    });

    testWidgets('covers postpartum mom chart and module actions', (
      tester,
    ) async {
      await _setCompactViewport(tester);
      final routeIntentPlatform = FakeRouteIntentPlatform();
      addTearDown(routeIntentPlatform.dispose);

      await tester.pumpWidget(
        MomCozyFlutterApp(
          router: createMomCozyRouter(initialLocation: '/status'),
          routeIntentPlatform: routeIntentPlatform,
          apiRuntime: _runtime(),
        ),
      );
      await tester.pumpAndSettle();

      await _scrollToFinder(
        tester,
        find.byKey(const ValueKey('status-milk-trend-preview')),
      );
      expect(find.bySemanticsLabel('母乳趋势图，共 7 天'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('status-milk-trend-segment-月')),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('母乳趋势图，共 30 天'), findsOneWidget);

      await _scrollToText(tester, '母乳产出');
      await tester.tap(
        find.byKey(const ValueKey('status-milk-output-info-button')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('status-detail-milk-info')),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('关闭详情'));
      await tester.pumpAndSettle();

      await _scrollToText(tester, '乳房健康');
      await tester.tap(
        find.byKey(const ValueKey('status-breast-health-info-button')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('status-detail-breast-info')),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('关闭详情'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('查看《乳房健康日记》'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('status-detail-breast-health')),
        findsOneWidget,
      );
      expect(find.text('涨奶硬块'), findsOneWidget);
      await tester.tap(find.byTooltip('关闭详情'));
      await tester.pumpAndSettle();
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
      expect(find.text('盆底肌康复训练'), findsOneWidget);
      await tester.tap(find.byTooltip('关闭详情'));
      await tester.pumpAndSettle();

      await _scrollToText(tester, '补能与休息');
      await tester.tap(find.byKey(const ValueKey('status-rest-info-button')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('status-detail-rest-info')),
        findsOneWidget,
      );
    });

    testWidgets('covers baby growth interactions and tab state retention', (
      tester,
    ) async {
      await _setCompactViewport(tester);
      final routeIntentPlatform = FakeRouteIntentPlatform();
      addTearDown(routeIntentPlatform.dispose);

      await tester.pumpWidget(
        MomCozyFlutterApp(
          router: createMomCozyRouter(initialLocation: '/status'),
          routeIntentPlatform: routeIntentPlatform,
          apiRuntime: _runtime(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('status-identity-tab-baby')));
      await tester.pumpAndSettle();

      expect(find.text('体重'), findsWidgets);
      expect(find.text('身高'), findsWidgets);
      expect(find.text('头围'), findsOneWidget);
      expect(find.text('成长milestone'), findsOneWidget);
      expect(find.text('查看健康信息'), findsOneWidget);
      expect(find.text('今日睡眠'), findsOneWidget);
      expect(find.text('4h 57min'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('status-baby-feed-info-button')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('status-detail-baby-feed-info')),
        findsOneWidget,
      );
      expect(find.text('今日摄入说明'), findsOneWidget);
      expect(find.text('妈妈实际记录的喂养数据，不包含亲喂'), findsOneWidget);
      await tester.tap(find.byTooltip('关闭详情'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('status-growth-record-action')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('status-growth-editor-dialog')),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('status-growth-weight-input')),
        '6.2',
      );
      await tester.enterText(
        find.byKey(const ValueKey('status-growth-height-input')),
        '64.5',
      );
      await tester.enterText(
        find.byKey(const ValueKey('status-growth-head-input')),
        '42',
      );
      tester.testTextInput.hide();
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('status-growth-save-button')));
      await tester.pumpAndSettle();
      expect(find.text('6.2kg'), findsOneWidget);
      expect(find.text('64.5cm'), findsOneWidget);
      expect(find.text('42cm'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('status-growth-milestone-action')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('status-detail-growth-milestone')),
        findsOneWidget,
      );
      expect(find.text('成长 milestone'), findsOneWidget);
      expect(find.text('说出完整主谓短句'), findsOneWidget);
      expect(find.text('2026.05.28'), findsOneWidget);
      expect(find.text('能说出带主语和动作的短句，语言组织能力继续发展。'), findsOneWidget);
      await tester.tap(find.byTooltip('关闭详情'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('查看健康信息'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('status-detail-baby-health')),
        findsOneWidget,
      );
      expect(find.text('自闭症风险筛查'), findsOneWidget);
      expect(find.text('宝宝情绪跟踪'), findsOneWidget);
      expect(find.text('待开通'), findsNWidgets(6));
      await tester.tap(find.byTooltip('关闭详情'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('查看报告'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('status-detail-baby-sleep')),
        findsOneWidget,
      );
      expect(find.text('宝宝睡眠报告'), findsOneWidget);
      expect(find.text('最长睡眠'), findsOneWidget);
      expect(find.text('3h 08min'), findsOneWidget);
      expect(find.text('哭闹'), findsWidgets);
      expect(find.text('活动'), findsWidgets);
      expect(find.text('宝宝睡眠记录'), findsOneWidget);
      expect(find.text('按时段看睡眠、活动和哭闹时长'), findsOneWidget);
      expect(find.text('00:00'), findsOneWidget);
      expect(find.text('10:00'), findsOneWidget);
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
      await tester.tap(find.byTooltip('关闭详情'));
      await tester.pumpAndSettle();

      await _scrollToFinder(
        tester,
        find.byKey(const ValueKey('status-baby-growth-curve-preview')),
      );
      await tester.tap(
        find.byKey(const ValueKey('status-baby-growth-segment-身高')),
      );
      await tester.pumpAndSettle();
      expect(find.text('当前查看：身高'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('status-baby-growth-segment-体重')),
      );
      await tester.pumpAndSettle();
      expect(find.text('当前查看：体重'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('status-baby-growth-segment-身高')),
      );
      await tester.pumpAndSettle();
      expect(find.text('当前查看：身高'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('bottom-nav-schedule')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('route-page-/schedule')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('bottom-nav-status')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('route-page-/status')), findsOneWidget);
      expect(find.text('宝宝成长曲线'), findsOneWidget);
      expect(find.text('6.2kg'), findsOneWidget);
      expect(find.text('当前查看：身高'), findsOneWidget);
    });

    testWidgets(
      'consumes a native growth notice once and highlights the curve',
      (tester) async {
        await _setCompactViewport(tester);
        final routeIntentPlatform = FakeRouteIntentPlatform();
        addTearDown(routeIntentPlatform.dispose);
        final router = createMomCozyRouter(initialLocation: '/schedule');

        await tester.pumpWidget(
          MomCozyFlutterApp(
            router: router,
            routeIntentPlatform: routeIntentPlatform,
            apiRuntime: _runtime(),
          ),
        );
        await tester.pumpAndSettle();

        routeIntentPlatform.dispatchActiveRoute(
          const PendingNativeRoute(
            path: '/status?mmcNotify=growth',
            notifyJson: {'event': 'grown'},
          ),
        );
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, '/status');

        routeIntentPlatform.dispatchActiveRoute(
          const PendingNativeRoute(
            path: '/status?mmcNotify=growth',
            notifyJson: {'event': 'grown'},
          ),
        );
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));

        expect(
          find.byKey(const ValueKey('route-page-/status')),
          findsOneWidget,
        );
        expect(find.text('成长发育'), findsOneWidget);
        expect(find.text('母乳产出'), findsNothing);
        final activeHighlight = tester.widget<AnimatedContainer>(
          find.byKey(const ValueKey('status-baby-growth-highlight')),
        );
        final activeBorder =
            (activeHighlight.decoration! as BoxDecoration).border! as Border;
        expect(activeBorder.top.color, isNot(Colors.transparent));

        await tester.pump(const Duration(milliseconds: 2800));
        expect(
          tester.widget(
            find.byKey(const ValueKey('status-baby-growth-highlight')),
          ),
          isA<KeyedSubtree>(),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('shows finite diary and birth journey notification notices', (
      tester,
    ) async {
      await _setCompactViewport(tester);
      final routeIntentPlatform = FakeRouteIntentPlatform();
      addTearDown(routeIntentPlatform.dispose);
      final router = createMomCozyRouter(initialLocation: '/schedule');

      await tester.pumpWidget(
        MomCozyFlutterApp(
          router: router,
          routeIntentPlatform: routeIntentPlatform,
          apiRuntime: _runtime(),
        ),
      );
      await tester.pumpAndSettle();

      routeIntentPlatform.dispatchActiveRoute(
        const PendingNativeRoute(path: '/status?statusIntent=pregnancy-diary'),
      );
      await tester.pumpAndSettle();
      routeIntentPlatform.dispatchActiveRoute(
        const PendingNativeRoute(path: '/status?statusIntent=pregnancy-diary'),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      expect(find.text('孕期日记'), findsOneWidget);
      expect(find.text('成长发育'), findsNothing);
      expect(
        _highlightBorderColor(
          tester,
          const ValueKey('status-pregnancy-diary-notice'),
        ),
        isNot(Colors.transparent),
      );

      router.go(
        '/status?statusIntent=birth-journey&statusIntentId=manual-plan-1',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(
        _highlightBorderColor(
          tester,
          const ValueKey('status-birth-journey-notice'),
        ),
        isNot(Colors.transparent),
      );

      await tester.pump(const Duration(milliseconds: 3200));
      expect(
        _highlightBorderColor(
          tester,
          const ValueKey('status-pregnancy-diary-notice'),
        ),
        Colors.transparent,
      );
      expect(
        _highlightBorderColor(
          tester,
          const ValueKey('status-birth-journey-notice'),
        ),
        Colors.transparent,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('Legacy Web widget parity: 计划', () {
    testWidgets(
      'transfers an Agent plan update into refreshed highlighted schedule UI',
      (tester) async {
        await _setCompactViewport(tester);
        final routeIntentPlatform = FakeRouteIntentPlatform();
        addTearDown(routeIntentPlatform.dispose);
        final runtime = _runtime(
          responsesByPath: {
            schedulePlansEndpoint: const {
              'items': [
                {
                  'id': 'milk-plan-widget',
                  'plan_type': 'milk_management',
                  'title': '稳奶计划',
                  'summary': '按当前阶段稳步执行',
                  'status': 'active',
                  'version': 3,
                  'payload': {'postpartum_week': 29, 'phase': '离乳期'},
                },
              ],
            },
            schedulePumpingRecordsEndpoint: const {'items': <Object?>[]},
          },
        );

        await tester.pumpWidget(
          MomCozyFlutterApp(
            router: createMomCozyRouter(initialLocation: '/status'),
            routeIntentPlatform: routeIntentPlatform,
            apiRuntime: runtime,
          ),
        );
        await tester.pumpAndSettle();

        runtime.milkPlanChangeStore.record(
          const MilkPlanChange(
            eventId: 'schedule-parity-plan-update',
            affectedDateKeys: ['2026-07-05'],
          ),
        );
        await tester.pump();
        expect(
          find.byKey(const ValueKey('bottom-nav-schedule-plan-badge')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const ValueKey('bottom-nav-schedule')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('route-page-/schedule')),
          findsOneWidget,
        );
        expect(find.text('稳奶计划执行中'), findsOneWidget);
        expect(
          find.text('已经根据你今天的会议日程，对吸乳排期做了调整哦，记得按时吸奶，有问题随时找我'),
          findsOneWidget,
        );
        expect(find.text('待执行任务'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('schedule-highlighted-date-2026-07-05')),
          findsOneWidget,
        );
        expect(runtime.milkPlanChangeStore.hasUnread, isFalse);
        expect(runtime.milkPlanChangeStore.hasPageNotice, isFalse);
        expect(
          find.byKey(const ValueKey('bottom-nav-schedule-plan-badge')),
          findsNothing,
        );

        await _scrollToText(tester, '稳奶计划已按最新权威数据刷新');
        await _scrollToFinder(
          tester,
          find.byKey(const ValueKey('schedule-quick-actions')),
        );
        final quickActions = find.byKey(
          const ValueKey('schedule-quick-actions'),
        );
        expect(
          find.descendant(of: quickActions, matching: find.text('吸奶补录')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: quickActions, matching: find.text('喂养记录')),
          findsOneWidget,
        );
      },
    );

    testWidgets('native schedule intent selects and focuses its linked task', (
      tester,
    ) async {
      await _setCompactViewport(tester);
      final routeIntentPlatform = FakeRouteIntentPlatform();
      addTearDown(routeIntentPlatform.dispose);
      final router = createMomCozyRouter(initialLocation: '/status');

      await tester.pumpWidget(
        MomCozyFlutterApp(
          router: router,
          routeIntentPlatform: routeIntentPlatform,
          apiRuntime: _runtime(
            responsesByPath: {
              schedulePlansEndpoint: const {
                'items': [
                  {
                    'id': 'milk-plan-widget',
                    'plan_type': 'milk_management',
                    'title': '稳奶计划',
                    'summary': '按当前阶段稳步执行',
                    'status': 'active',
                    'version': 3,
                  },
                ],
              },
              schedulePumpingRecordsEndpoint: const {'items': <Object?>[]},
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      routeIntentPlatform.dispatchActiveRoute(
        const PendingNativeRoute(
          path: '/schedule?date=2026-07-04&task_id=feeding-afternoon',
        ),
      );
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, '/schedule');
      expect(
        find.byKey(const ValueKey('schedule-highlighted-date-2026-07-04')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('schedule-timeline-task-feeding-afternoon')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('Legacy Web widget parity: 智能体主页', () {
    testWidgets(
      'covers shell nav, top controls, transcript, fade, and composer',
      (tester) async {
        await _setCompactViewport(tester);
        final routeIntentPlatform = FakeRouteIntentPlatform();
        addTearDown(routeIntentPlatform.dispose);

        await tester.pumpWidget(
          MomCozyFlutterApp(
            router: createMomCozyRouter(initialLocation: '/'),
            routeIntentPlatform: routeIntentPlatform,
            apiRuntime: _runtime(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('agent-hub-page')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('agent-auto-voice-button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('agent-new-session-button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('agent-chat-scroll-view')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('agent-top-fade')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('agent-run-transcript')),
          findsOneWidget,
        );
        expect(find.textContaining('嗨，我是 CozyMate'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('agent-composer-bar')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('agent-image-button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('agent-composer-input')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('agent-voice-button')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('agent-send-button')), findsOneWidget);
        expect(find.byKey(const ValueKey('bottom-nav-agent')), findsOneWidget);
        final agentAvatar = tester.widget<Container>(
          find.byKey(const ValueKey('bottom-nav-agent-avatar')),
        );
        final agentAvatarDecoration = agentAvatar.decoration as BoxDecoration;
        final agentAvatarImage =
            agentAvatarDecoration.image?.image as AssetImage;
        expect(agentAvatarImage.assetName, MomCozyAssets.agentAvatar);

        final imageButton = tester.widget<IconButton>(
          find.byKey(const ValueKey('agent-image-button')),
        );
        expect(imageButton.onPressed, isNotNull);
        final voiceButton = tester.widget<IconButton>(
          find.byKey(const ValueKey('agent-voice-button')),
        );
        expect(voiceButton.onPressed, isNotNull);

        await tester.enterText(
          find.byKey(const ValueKey('agent-composer-input')),
          '第一行\n第二行\n第三行',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('bottom-nav-schedule')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('bottom-nav-agent')));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextField>(
                find.byKey(const ValueKey('agent-composer-input')),
              )
              .controller
              ?.text,
          '第一行\n第二行\n第三行',
        );
      },
    );

    testWidgets(
      'replays bottom nav avatar wake animation when entering from another module',
      (tester) async {
        await _setCompactViewport(tester);
        final routeIntentPlatform = FakeRouteIntentPlatform();
        addTearDown(routeIntentPlatform.dispose);

        await tester.pumpWidget(
          MomCozyFlutterApp(
            router: createMomCozyRouter(initialLocation: '/schedule'),
            routeIntentPlatform: routeIntentPlatform,
            apiRuntime: _runtime(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('agent-hub-page')), findsNothing);
        expect(_agentAvatarPresenceScale(tester), closeTo(1, 0.001));
        expect(_agentAvatarWakeMedia(), findsNothing);

        await tester.tap(find.byKey(const ValueKey('bottom-nav-agent')));
        await _pumpUntilFinder(tester, _agentAvatarWakeMedia());
        await tester.pump(const Duration(milliseconds: 760));

        expect(find.byKey(const ValueKey('agent-hub-page')), findsOneWidget);
        expect(_agentAvatarPresenceScale(tester), greaterThan(1.08));
        expect(
          _opacityForKey(tester, 'bottom-nav-agent-avatar-wake-halo'),
          greaterThan(0.2),
        );
        expect(
          _opacityForKey(tester, 'bottom-nav-agent-avatar-wake-ring-opacity'),
          greaterThan(0.2),
        );
        expect(_agentAvatarWakeMedia(), findsOneWidget);
        final firstWakeImage = tester.widget<Image>(_agentAvatarWakeMedia());
        expect(firstWakeImage.image, isA<MemoryImage>());
        final firstWakeKey = firstWakeImage.key;

        await tester.pumpAndSettle();
        expect(_agentAvatarPresenceScale(tester), closeTo(1, 0.001));
        expect(
          _opacityForKey(tester, 'bottom-nav-agent-avatar-wake-halo'),
          closeTo(0, 0.001),
        );
        expect(_agentAvatarWakeMedia(), findsNothing);

        await tester.tap(find.byKey(const ValueKey('bottom-nav-schedule')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('bottom-nav-agent')));
        await _pumpUntilFinder(tester, _agentAvatarWakeMedia());
        await tester.pump(const Duration(milliseconds: 760));

        expect(find.byKey(const ValueKey('agent-hub-page')), findsOneWidget);
        expect(_agentAvatarPresenceScale(tester), greaterThan(1.08));
        expect(_agentAvatarWakeMedia(), findsOneWidget);
        final secondWakeImage = tester.widget<Image>(_agentAvatarWakeMedia());
        expect(secondWakeImage.key, isNot(firstWakeKey));
      },
    );

    testWidgets('covers history bubbles, image preview, and latest button', (
      tester,
    ) async {
      await _setCompactViewport(tester);
      final client = _FixtureAgentStreamClient(
        parseAgentJsonl(
          readMigrationFixture('agent_events/text_stream_basic.jsonl'),
        ),
      );
      final history = List<AgentHubHistoryMessage>.generate(
        18,
        (index) => AgentHubHistoryMessage(
          role: index.isEven
              ? AgentHubHistoryRole.user
              : AgentHubHistoryRole.assistant,
          content: index.isEven ? '用户消息 $index' : '助手消息 $index',
        ),
      );

      await tester.pumpWidget(
        _agentHost(
          AgentHubPage(
            runner: AgentStreamRunner(client),
            historyMessages: history,
            pickImage: (_) async => const AgentStreamImageInput(
              dataUrl: 'data:image/png;base64,fixture',
              mimeType: 'image/png',
              name: 'legacy-widget.png',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('agent-history-panel')), findsOneWidget);
      expect(find.text('用户消息 0'), findsOneWidget);
      expect(find.text('助手消息 1'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('agent-scroll-latest-button')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('agent-scroll-latest-button')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('agent-scroll-latest-button')),
        findsNothing,
      );
      expect(find.text('助手消息 17'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('agent-image-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('agent-photo-menu')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('agent-photo-upload-button')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('agent-image-attachment-chip')),
        findsOneWidget,
      );
      expect(find.text('图片 1'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('agent-remove-image-button')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('agent-remove-image-button')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('agent-image-attachment-chip')),
        findsNothing,
      );
    });
  });
}

const _secureStorageChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

Future<void> _setCompactViewport(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Map<String, Object?> _birthJourneyPlanResponse() {
  return const {
    'items': [
      {
        'id': 'birth-plan-widget',
        'plan_type': 'pregnancy',
        'title': '孕期计划',
        'status': 'active',
        'payload': {
          'card': {
            'card_type': 'birth_journey_plan_card',
            'schema_version': '1.0',
            'card_json': {
              'todo_plan': {
                'periods': [
                  {
                    'id': 'current',
                    'title': '当前阶段',
                    'subtitle': '孕 32-34 周',
                    'display_mode': 'expanded',
                    'status': 'current',
                    'items': [
                      {
                        'id': 'todo-current',
                        'title': '准备产检资料',
                        'priority_label': '重要',
                        'reason': '下次产检时集中确认',
                        'steps': ['整理检查报告'],
                        'completed': false,
                      },
                    ],
                  },
                  {
                    'id': 'upcoming',
                    'title': '后续阶段',
                    'subtitle': '孕 35-37 周',
                    'display_mode': 'collapsed',
                    'status': 'upcoming',
                    'items': [
                      {
                        'id': 'todo-upcoming',
                        'title': '整理待产包',
                        'priority_label': '建议',
                        'reason': '提前确认住院物品',
                        'steps': <String>[],
                        'completed': false,
                      },
                    ],
                  },
                  {
                    'id': 'terminal',
                    'title': '临产住院',
                    'subtitle': '出现临产信号时',
                    'display_mode': 'terminal',
                    'status': 'terminal',
                    'items': [
                      {
                        'id': 'todo-terminal',
                        'title': '联系医院',
                        'priority_label': '重要',
                        'steps': <String>[],
                        'completed': false,
                      },
                    ],
                  },
                ],
              },
            },
          },
        },
      },
    ],
  };
}

MomCozyApiRuntime _runtime({
  Map<String, Map<String, Object?>>? responsesByPath,
}) {
  return MomCozyApiRuntime(
    jsonTransport: FixtureApiJsonTransportByPath(
      {
        statusProfileEndpoint: const {
          'user_id': 'demo-user-fixture',
          'delivery_date': '2026-06-12',
        },
        statusInfantsEndpoint: const {
          'items': [
            {
              'id': 'demo-baby-fixture',
              'owner_user_id': 'demo-user-fixture',
              'infant_name': 'Mia',
              'birth_date': '2026-04-06',
              'sex': 'female',
              'status': 'active',
            },
          ],
        },
        milkTrendsEndpoint: const {
          'items': [
            {
              'date': '2026-07-01',
              'pumped_milk_volume_ml': 150,
              'pumping_count': 2,
              'measured_only': true,
            },
            {
              'date': '2026-07-02',
              'pumped_milk_volume_ml': 180,
              'pumping_count': 2,
              'measured_only': true,
            },
            {
              'date': '2026-07-03',
              'pumped_milk_volume_ml': 210,
              'pumping_count': 3,
              'measured_only': true,
            },
          ],
          'days': 31,
          'include_today': true,
        },
        feedingRecordsEndpoint: const {
          'items': [
            {
              'id': 'feeding-widget-1',
              'feed_type': 'bottle',
              'volume_ml': 80,
              'feed_time': '2026-07-03T06:00:00Z',
            },
            {
              'id': 'feeding-widget-2',
              'feed_type': 'bottle',
              'volume_ml': 40,
              'feed_time': '2026-07-03T10:00:00Z',
            },
          ],
        },
        growthRecordsEndpoint: const {
          'items': [
            {
              'id': 'growth-widget-saved',
              'weight_kg': 6.2,
              'height_cm': 64.5,
              'head_cm': 42,
              'measured_at': '2026-07-03T12:00:00Z',
            },
          ],
          'id': 'growth-widget-saved',
          'weight_kg': 6.2,
          'height_cm': 64.5,
          'head_cm': 42,
          'measured_at': '2026-07-03T12:00:00Z',
        },
        '$growthRecordsEndpoint/growth-widget-saved': const {
          'id': 'growth-widget-saved',
          'weight_kg': 6.2,
          'height_cm': 64.5,
          'head_cm': 42,
          'measured_at': '2026-07-03T12:00:00Z',
        },
        pregnancyDiaryEntriesEndpoint: const {'items': <Object?>[]},
        pregnancyPlansEndpoint: const {'items': <Object?>[]},
        '$pregnancyDiaryEntriesEndpoint/2026-07-03': const {
          'id': 'diary-widget-parity',
          'entry_date': '2026-07-03',
          'content': '今天胎动规律，想问医生睡眠问题。',
          'symptom_tags': <String>[],
          'health_notes': <Object?>[],
        },
        scheduleDayPlanEndpoint: const {
          'items': <Object?>[
            {
              'id': 'pump-morning',
              'owner_user_id': 'demo-user-fixture',
              'task_date': '2026-07-03',
              'task_time': '10:30',
              'title': '泵奶',
              'description': '',
              'status': 'completed',
              'payload': <String, Object?>{},
            },
            {
              'id': 'feeding-afternoon',
              'owner_user_id': 'demo-user-fixture',
              'task_date': '2026-07-03',
              'task_time': '14:00',
              'title': '喂养',
              'description': '',
              'status': 'pending',
              'payload': <String, Object?>{},
            },
            {
              'id': 'summary-evening',
              'owner_user_id': 'demo-user-fixture',
              'task_date': '2026-07-03',
              'task_time': '20:30',
              'title': '晚间复盘',
              'description': '',
              'status': 'pending',
              'payload': <String, Object?>{},
            },
          ],
        },
        ...?responsesByPath,
      },
      writeResponsesByPath: const {
        pregnancyDiaryEntriesEndpoint: {
          'id': 'diary-widget-parity',
          'entry_date': '2026-07-03',
          'content': '今天胎动规律，想问医生睡眠问题。',
          'symptom_tags': <String>[],
          'attachments': <Object?>[],
          'status': 'active',
        },
        '$pregnancyDiaryEntriesEndpoint/2026-07-03': {
          'id': 'diary-widget-parity',
          'entry_date': '2026-07-03',
          'content': '今天胎动规律，想问医生睡眠问题。',
          'symptom_tags': <String>[],
          'attachments': <Object?>[],
          'status': 'active',
        },
      },
    ),
    agentVoicePlaybackPlayer: const ImmediateAgentVoicePlaybackPlayer(),
    clientEventClient: const AgentStreamClientEventClient(sent: false),
    multipartTransport: FixtureApiMultipartTransport(const <String, Object?>{
      'status': 200,
      'data': <String, Object?>{
        'text': '',
        'audio_url': '/audio/test-voice.mp3',
      },
    }),
    blePlatform: FakeBlePlatform(initialPermission: BlePermissionState.granted),
    userId: 'demo-user-widget-parity',
    babyId: 'demo-baby-widget-parity',
    locale: 'zh-CN',
    now: () => DateTime.utc(2026, 7, 3),
  );
}

Widget _agentHost(Widget child) {
  return MaterialApp(
    theme: momCozyTheme(),
    debugShowCheckedModeBanner: false,
    home: Scaffold(body: SafeArea(child: child)),
  );
}

Future<void> _scrollToText(WidgetTester tester, String text) async {
  await _scrollToFinder(tester, find.text(text));
}

Future<void> _scrollToFinder(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isNotEmpty) {
    await tester.ensureVisible(finder.first);
    await tester.pumpAndSettle();
    return;
  }

  final scrollable = find.byType(Scrollable);
  if (scrollable.evaluate().isEmpty) {
    expect(finder, findsOneWidget);
    return;
  }

  await tester.scrollUntilVisible(
    finder,
    120,
    scrollable: scrollable.first,
    duration: const Duration(milliseconds: 50),
    maxScrolls: 18,
  );
  await tester.pumpAndSettle();
}

Color _highlightBorderColor(WidgetTester tester, Key key) {
  final widget = tester.widget(find.byKey(key));
  if (widget is! AnimatedContainer) return Colors.transparent;
  final container = widget;
  final border = (container.decoration! as BoxDecoration).border! as Border;
  return border.top.color;
}

Future<void> _pumpUntilFinder(WidgetTester tester, Finder finder) async {
  for (var index = 0; index < 20; index += 1) {
    await tester.pump(const Duration(milliseconds: 16));
    if (finder.evaluate().isNotEmpty) return;
  }
  expect(finder, findsOneWidget);
}

double _agentAvatarPresenceScale(WidgetTester tester) {
  final transform = tester.widget<Transform>(
    find.byKey(const ValueKey('bottom-nav-agent-avatar-presence-scale')),
  );
  return transform.transform.storage[0];
}

double _opacityForKey(WidgetTester tester, String key) {
  return tester.widget<Opacity>(find.byKey(ValueKey(key))).opacity;
}

Finder _agentAvatarWakeMedia() {
  return find.byWidgetPredicate((widget) {
    final key = widget.key;
    return key is ValueKey<String> &&
        key.value.startsWith('bottom-nav-agent-avatar-wake-media-');
  });
}

class _FixtureAgentStreamClient implements AgentStreamClient {
  _FixtureAgentStreamClient(this.events);

  final List<AgentStreamEvent> events;

  @override
  Stream<AgentStreamEvent> stream(AgentStreamRequest request) async* {
    for (final event in events) {
      await Future<void>.delayed(Duration.zero);
      yield event;
    }
  }
}
