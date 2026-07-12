import 'dart:async';

import 'package:flutter/material.dart';
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
import 'package:momcozy_flutter_app/features/status/data/status_api_repository.dart';
import 'package:momcozy_flutter_app/native/p0_platform_interfaces.dart';

import '../../support/fixture_api_transport.dart';
import '../../support/fixture_reader.dart';
import '../../support/fake_agent_voice.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);

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
        expect(find.text('最近 7 天记录'), findsOneWidget);
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
        expect(find.text('今天的记录已保存'), findsOneWidget);
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

    testWidgets('reads pregnancy diary entries from the backend repository', (
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
              pregnancyDiaryEntriesEndpoint: const {
                'items': [
                  {
                    'id': 'diary-1',
                    'entry_date': '2026-07-03',
                    'content': '今天胎动规律，心情很安心。',
                    'mood': '安心',
                    'symptom_tags': <Object?>[],
                    'attachments': <Object?>[],
                    'status': 'active',
                  },
                ],
              },
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('status-care-stage-pregnancy')),
      );
      await tester.pumpAndSettle();

      expect(find.text('今天胎动规律，心情很安心。'), findsOneWidget);
      expect(find.text('今天的记录已保存'), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey('status-pregnancy-diary-view-button')),
      );
      await tester.pumpAndSettle();
      expect(find.text('今天的记录已保存'), findsOneWidget);
      expect(find.text('安心'), findsOneWidget);
    });

    testWidgets(
      'does not create a diary entry when the current diary state is unknown',
      (tester) async {
        await _setCompactViewport(tester);
        final routeIntentPlatform = FakeRouteIntentPlatform();
        addTearDown(routeIntentPlatform.dispose);

        await tester.pumpWidget(
          MomCozyFlutterApp(
            router: createMomCozyRouter(initialLocation: '/status'),
            routeIntentPlatform: routeIntentPlatform,
            apiRuntime: _runtime(
              responsesByPath: {
                pregnancyDiaryEntriesEndpoint: const {
                  'http_status': 503,
                  'status_text': 'Service Unavailable',
                },
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('status-care-stage-pregnancy')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('status-pregnancy-diary-record-button')),
        );
        await tester.pumpAndSettle();

        expect(find.text('日记加载失败，请稍后重试'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('status-pregnancy-diary-editor-dialog')),
          findsNothing,
        );
      },
    );

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
      expect(find.text('近7日趋势'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('status-milk-trend-segment-月')),
      );
      await tester.pumpAndSettle();
      expect(find.text('近30日趋势'), findsOneWidget);

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

      await tester.tap(
        find.byKey(const ValueKey('status-baby-feed-info-button')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('status-detail-baby-feed-info')),
        findsOneWidget,
      );
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
      await tester.tap(find.byKey(const ValueKey('status-growth-save-button')));
      await tester.pumpAndSettle();
      expect(find.text('已添加'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('status-growth-milestone-action')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('status-detail-growth-milestone')),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('关闭详情'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('查看筛查'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('status-detail-baby-health')),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('关闭详情'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('查看报告'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('status-detail-baby-sleep')),
        findsOneWidget,
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
      expect(find.text('已添加'), findsOneWidget);
      expect(find.text('当前查看：身高'), findsOneWidget);
    });
  });

  group('Legacy Web widget parity: 计划', () {
    testWidgets(
      'covers date strip, plan summary, agent card, and task toolbar',
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

        expect(
          find.byKey(const ValueKey('route-page-/schedule')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('schedule-date-strip')),
          findsOneWidget,
        );
        expect(find.text('2026年7月'), findsOneWidget);
        expect(find.text('今'), findsOneWidget);
        expect(find.text('3'), findsOneWidget);
        expect(find.text('稳奶计划执行中'), findsOneWidget);
        expect(find.text('产后第29周（离乳期）'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('schedule-context-reminder-button')),
          findsOneWidget,
        );
        expect(find.text('今日任务'), findsWidgets);
        expect(find.text('1/3'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('schedule-agent-card')),
          findsOneWidget,
        );
        expect(find.text('提醒开关'), findsOneWidget);
        expect(find.text('对话'), findsOneWidget);
        expect(find.text('待执行任务'), findsOneWidget);
        expect(find.text('泵奶提醒'), findsNothing);
        expect(find.text('每日摘要'), findsNothing);

        await _scrollToFinder(
          tester,
          find.byKey(const ValueKey('schedule-list-toolbar')),
        );
        expect(
          find.byKey(const ValueKey('schedule-list-toolbar')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('schedule-task-help-button')),
          findsOneWidget,
        );
        expect(find.text('调整日程'), findsOneWidget);
        expect(find.text('添加任务'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('bottom-nav-schedule')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('bottom-nav-agent')), findsOneWidget);

        await tester.tap(
          find.byKey(const ValueKey('schedule-task-help-button')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('schedule-task-explanation-dialog')),
          findsOneWidget,
        );
        expect(find.text('今日任务说明'), findsOneWidget);
        await tester.tapAt(const Offset(12, 12));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('schedule-task-explanation-dialog')),
          findsNothing,
        );
        await tester.tap(
          find.byKey(const ValueKey('schedule-task-help-button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('知道了'));
        await tester.pumpAndSettle();

        await _scrollToText(tester, '14:00 喂养');
        expect(find.text('14:00 喂养'), findsWidgets);
        expect(find.byTooltip('删除任务'), findsWidgets);
        expect(_checkboxesWithValue(tester, true), 1);

        await tester.tap(find.text('14:00 喂养').last);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('schedule-task-edit-title-input')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('schedule-task-edit-time-input')),
          findsOneWidget,
        );
        expect(_checkboxesWithValue(tester, true), 1);
        await tester.tap(
          find.byKey(const ValueKey('schedule-task-edit-cancel-button')),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(Checkbox).last);
        await tester.pump();
        expect(_checkboxesWithValue(tester, true), 2);
        await tester.tap(find.byType(Checkbox).last);
        await tester.pump();
        expect(_checkboxesWithValue(tester, true), 1);

        await _scrollToFinder(
          tester,
          find.byKey(const ValueKey('schedule-add-task-button')),
        );
        await tester.tap(
          find.byKey(const ValueKey('schedule-add-task-button')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('schedule-add-task-dialog')),
          findsOneWidget,
        );
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('schedule-add-task-dialog')),
          findsNothing,
        );
        expect(find.text('本地补充 1'), findsNothing);

        await tester.tap(
          find.byKey(const ValueKey('schedule-add-task-button')),
        );
        await tester.pumpAndSettle();
        await _scrollToText(tester, '本地补充 1');
        expect(find.text('本地补充 1'), findsOneWidget);
      },
    );

    testWidgets('covers empty and failed states', (tester) async {
      await _setCompactViewport(tester);
      final routeIntentPlatform = FakeRouteIntentPlatform();
      addTearDown(routeIntentPlatform.dispose);

      await tester.pumpWidget(
        MomCozyFlutterApp(
          router: createMomCozyRouter(initialLocation: '/schedule'),
          routeIntentPlatform: routeIntentPlatform,
          apiRuntime: _runtime(
            responsesByPath: {
              scheduleDayPlanEndpoint: const {'items': <Object?>[]},
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('0/0'), findsOneWidget);
      expect(find.text('今天还没有计划任务'), findsOneWidget);
      await _scrollToText(tester, '当天暂无执行内容');
      expect(find.text('当天暂无执行内容'), findsOneWidget);
      expect(find.text('吸奶补录'), findsOneWidget);
      expect(find.text('喂养记录'), findsOneWidget);

      final failingRouteIntentPlatform = FakeRouteIntentPlatform();
      addTearDown(failingRouteIntentPlatform.dispose);

      await tester.pumpWidget(
        MomCozyFlutterApp(
          key: UniqueKey(),
          router: createMomCozyRouter(initialLocation: '/schedule'),
          routeIntentPlatform: failingRouteIntentPlatform,
          apiRuntime: _runtime(
            responsesByPath: {
              scheduleDayPlanEndpoint: const {
                'http_status': 503,
                'status_text': 'Service Unavailable',
              },
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _scrollToText(tester, '当天暂无执行内容');
      expect(find.text('当天暂无执行内容'), findsOneWidget);
      expect(find.text('吸奶补录'), findsOneWidget);
      expect(find.text('喂养记录'), findsOneWidget);
      expect(find.text('计划同步失败'), findsNothing);
      expect(find.text('检查后端连接或 token 后重试。'), findsNothing);
      expect(find.byTooltip('重试'), findsNothing);
    });

    testWidgets('covers date switching, reminders, and local state retention', (
      tester,
    ) async {
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

      expect(find.text('今'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('schedule-date-2026-07-04')));
      await tester.pumpAndSettle();
      expect(find.text('7月4日 稳奶计划'), findsOneWidget);
      expect(find.text('未来的计划'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('schedule-date-2026-07-03')),
          matching: find.text('今'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('schedule-date-2026-07-04')),
          matching: find.text('六'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('schedule-date-2026-07-04')),
          matching: find.text('今'),
        ),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('schedule-back-to-today-button')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('schedule-back-to-today-button')),
      );
      await tester.pumpAndSettle();
      expect(find.text('稳奶计划执行中'), findsOneWidget);
      expect(find.text('提醒已开启'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('schedule-week-next-button')));
      await tester.pumpAndSettle();
      expect(find.text('7月10日 稳奶计划'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('schedule-date-2026-07-10')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('schedule-week-prev-button')));
      await tester.pumpAndSettle();
      expect(find.text('稳奶计划执行中'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('schedule-context-reminder-button')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('schedule-reminder-confirm-dialog')),
        findsOneWidget,
      );
      expect(find.text('关闭计划提醒？'), findsOneWidget);
      expect(find.text('提醒已开启'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('schedule-reminder-cancel')));
      await tester.pumpAndSettle();
      expect(find.text('提醒已开启'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('schedule-context-reminder-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('schedule-reminder-confirm')));
      await tester.pumpAndSettle();
      expect(find.text('提醒已关闭'), findsOneWidget);
      expect(find.byTooltip('开启计划提醒'), findsOneWidget);
      await tester.tap(find.text('提醒开关'));
      await tester.pumpAndSettle();
      expect(find.text('提醒已开启'), findsOneWidget);

      await _scrollToFinder(
        tester,
        find.byKey(const ValueKey('schedule-adjust-button')),
      );
      await tester.tap(find.byKey(const ValueKey('schedule-adjust-button')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('schedule-adjust-upload-dialog')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('schedule-adjust-submit')));
      await tester.pumpAndSettle();
      expect(find.text('日程调整已提交'), findsOneWidget);
      expect(find.text('已提交'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('schedule-adjust-button')),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(
        find.byKey(const ValueKey('schedule-adjust-button')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('schedule-adjust-upload-dialog')),
        findsNothing,
      );

      await tester.tap(find.byKey(const ValueKey('schedule-add-task-button')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('schedule-add-task-dialog')),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('schedule-add-task-title-input')),
        '本地补充 1',
      );
      await tester.tap(find.byKey(const ValueKey('schedule-add-task-submit')));
      await tester.pumpAndSettle();
      await _scrollToText(tester, '本地补充 1');
      expect(find.text('本地补充 1'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('bottom-nav-status')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('bottom-nav-schedule')));
      await tester.pumpAndSettle();
      expect(find.text('提醒已开启'), findsOneWidget);
      await _scrollToText(tester, '本地补充 1');
      expect(find.text('本地补充 1'), findsOneWidget);
      expect(find.text('已提交'), findsOneWidget);
    });

    testWidgets('covers schedule conversation prefill and next task controls', (
      tester,
    ) async {
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

      expect(find.text('手动完成并记录数据'), findsOneWidget);
      expect(find.text('顺延半小时'), findsOneWidget);
      expect(find.text('跳过这次任务'), findsOneWidget);

      await tester.tap(find.text('顺延半小时'));
      await tester.pumpAndSettle();
      expect(find.text('顺延半小时已更新'), findsOneWidget);
      expect(find.text('14:30'), findsWidgets);

      await tester.tap(find.text('跳过这次任务'));
      await tester.pumpAndSettle();
      expect(find.text('已跳过'), findsOneWidget);
      expect(find.text('20:30'), findsWidgets);

      await tester.tap(find.text('手动完成并记录数据'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('schedule-record-entry-dialog')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('schedule-record-complete-only')),
      );
      await tester.pumpAndSettle();
      expect(find.text('执行记录已完成'), findsOneWidget);

      await tester.tap(find.text('对话'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('agent-hub-page')), findsOneWidget);
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('agent-composer-input')),
            )
            .controller
            ?.text,
        '我想调整今天的吸乳排期',
      );
    });

    testWidgets('covers empty quick actions as local entry shortcuts', (
      tester,
    ) async {
      await _setCompactViewport(tester);
      final routeIntentPlatform = FakeRouteIntentPlatform();
      addTearDown(routeIntentPlatform.dispose);

      await tester.pumpWidget(
        MomCozyFlutterApp(
          router: createMomCozyRouter(initialLocation: '/schedule'),
          routeIntentPlatform: routeIntentPlatform,
          apiRuntime: _runtime(
            responsesByPath: {
              scheduleDayPlanEndpoint: const {'items': <Object?>[]},
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _scrollToText(tester, '吸奶补录');
      await tester.tap(find.text('吸奶补录'));
      await tester.pumpAndSettle();
      expect(find.text('吸奶补录'), findsWidgets);
      expect(find.text('吸奶补录已添加'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      final feedingRouteIntentPlatform = FakeRouteIntentPlatform();
      addTearDown(feedingRouteIntentPlatform.dispose);
      await tester.pumpWidget(
        MomCozyFlutterApp(
          router: createMomCozyRouter(initialLocation: '/schedule'),
          routeIntentPlatform: feedingRouteIntentPlatform,
          apiRuntime: _runtime(
            responsesByPath: {
              scheduleDayPlanEndpoint: const {'items': <Object?>[]},
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _scrollToText(tester, '喂养记录');
      await tester.tap(find.text('喂养记录').last);
      await tester.pumpAndSettle();
      expect(find.text('喂养记录已添加'), findsOneWidget);
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

Future<void> _setCompactViewport(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
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
        pregnancyPlansEndpoint: const {'items': <Object?>[]},
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
          'id': 'diary-created',
          'entry_date': '2026-07-03',
          'content': '今天胎动规律，想问医生睡眠问题。',
          'mood': '',
          'symptom_tags': <Object?>[],
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

int _checkboxesWithValue(WidgetTester tester, bool value) {
  return tester.widgetList<Checkbox>(find.byType(Checkbox)).where((checkbox) {
    return checkbox.value == value;
  }).length;
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
