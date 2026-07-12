import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_client.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_event.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_runner.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_page.dart';
import 'package:momcozy_flutter_app/features/pregnancy_diary/data/pregnancy_diary_api_repository.dart';
import 'package:momcozy_flutter_app/features/pregnancy_diary/domain/pregnancy_diary_change_store.dart';
import 'package:momcozy_flutter_app/features/pregnancy_plan/data/pregnancy_plan_api_repository.dart';
import 'package:momcozy_flutter_app/features/pregnancy_plan/domain/pregnancy_plan_change_store.dart';
import 'package:momcozy_flutter_app/features/status/data/status_api_repository.dart';
import 'package:momcozy_flutter_app/native/p0_platform_interfaces.dart';

import '../../support/fixture_api_transport.dart';

void main() {
  testWidgets(
    'Status distinguishes loading and empty before offering Agent CTA',
    (tester) async {
      await _setCompactViewport(tester);
      final planResponse = Completer<Map<String, Object?>>();
      final transport = _PlanTransport(deferredPlanRequests: {1: planResponse});
      final harness = await _pumpApp(
        tester,
        transport: transport,
        initialLocation: '/status',
      );

      await tester.tap(
        find.byKey(const ValueKey('status-care-stage-pregnancy')),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('status-pregnancy-plan-loading')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('status-pregnancy-plan-agent-button')),
        findsNothing,
      );

      planResponse.complete(const {'items': <Object?>[]});
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('status-pregnancy-plan-empty')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('status-pregnancy-plan-agent-button')),
        findsOneWidget,
      );
      expect(find.text('制定孕期计划'), findsOneWidget);

      await _scrollTo(
        tester,
        find.byKey(const ValueKey('status-pregnancy-plan-agent-button')),
      );
      await tester.tap(
        find.byKey(const ValueKey('status-pregnancy-plan-agent-button')),
      );
      await _pumpFrames(tester, 12);

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
      expect(transport.planQueries.single, {
        'plan_type': 'pregnancy',
        'status': 'active',
        'limit': 1,
      });

      harness.dispose();
    },
  );

  testWidgets(
    'Status retries errors and renders persisted plan card without CTA',
    (tester) async {
      await _setCompactViewport(tester);
      final transport = _PlanTransport(
        failingPlanRequests: const {1},
        planResponses: {2: _planResponse(title: '重试后的孕期计划')},
      );
      final harness = await _pumpApp(
        tester,
        transport: transport,
        initialLocation: '/status',
      );

      await tester.tap(
        find.byKey(const ValueKey('status-care-stage-pregnancy')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('status-pregnancy-plan-error')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('status-pregnancy-plan-agent-button')),
        findsNothing,
      );

      await _scrollTo(
        tester,
        find.byKey(const ValueKey('status-pregnancy-plan-retry-button')),
      );
      await tester.tap(
        find.byKey(const ValueKey('status-pregnancy-plan-retry-button')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('status-pregnancy-plan-card')),
        findsOneWidget,
      );
      expect(find.text('重试后的孕期计划'), findsOneWidget);
      expect(find.text('当前阶段｜孕 32 周起'), findsOneWidget);
      expect(find.text('和产科确认个性化复查节奏'), findsOneWidget);
      expect(find.text('因为是双胎，需要更密切观察生长'), findsOneWidget);
      expect(find.text('确认孕周口径'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('status-pregnancy-plan-agent-button')),
        findsNothing,
      );

      harness.dispose();
    },
  );

  testWidgets(
    'malformed plan after a created event restores badge and never shows CTA',
    (tester) async {
      await _setCompactViewport(tester);
      final transport = _PlanTransport(
        planResponses: {
          1: {
            'items': [
              {
                'id': 'plan-pregnancy-malformed',
                'plan_type': 'pregnancy',
                'title': '孕期计划',
                'status': 'active',
                'source': 'agent_action',
                'payload': {
                  'card': {
                    'card_type': 'birth_journey_plan_card',
                    'schema_version': '1.0',
                    'card_json': {
                      'title': '缺少阶段的损坏计划',
                      'owner': {'current_week': '孕 32 周'},
                    },
                  },
                },
              },
            ],
          },
        },
      );
      final runtime = _runtime(transport);
      runtime.pregnancyPlanChangeStore.record(
        PregnancyPlanChange.tryFromEvent(
          _planChangedEvent(eventId: 'evt-plan-malformed'),
        )!,
      );
      final harness = await _pumpApp(
        tester,
        transport: transport,
        runtime: runtime,
        initialLocation: '/schedule',
      );

      expect(
        find.byKey(const ValueKey('bottom-nav-status-plan-badge')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('bottom-nav-status')));
      await tester.pumpAndSettle();

      expect(runtime.pregnancyPlanChangeStore.hasUnread, isTrue);
      expect(runtime.pregnancyPlanChangeStore.highlightCard, isFalse);
      expect(
        find.byKey(const ValueKey('status-pregnancy-plan-error')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('status-pregnancy-plan-agent-button')),
        findsNothing,
      );

      harness.dispose();
    },
  );

  testWidgets(
    'Agent plan event deduplicates replay and hands combined nav notices to cards',
    (tester) async {
      await _setCompactViewport(tester);
      final transport = _PlanTransport(planResponses: {1: _planResponse()});
      final client = _ControllableAgentStreamClient();
      final runtime = _runtime(transport);
      final router = createMomCozyRouter(
        initialLocation: '/',
        agentHubBuilder: (context, uri, extra, voicePlaybackCoordinator) {
          return AgentHubPage(
            runner: AgentStreamRunner(client),
            requestBuilder: (message) => AgentStreamRequest(message: message),
            voicePlaybackCoordinator: voicePlaybackCoordinator,
            onPregnancyPlanChange: runtime.pregnancyPlanChangeStore.record,
          );
        },
      );
      final routePlatform = FakeRouteIntentPlatform();
      addTearDown(client.dispose);
      addTearDown(router.dispose);
      addTearDown(routePlatform.dispose);

      await tester.pumpWidget(
        MomCozyFlutterApp(
          router: router,
          routeIntentPlatform: routePlatform,
          apiRuntime: runtime,
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('agent-composer-input')),
        '生成孕期计划',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('agent-send-button')));
      await tester.pump();
      expect(client.requests, hasLength(1));
      client.emit(_runStartedEvent());
      await tester.pump();

      router.go('/schedule');
      await tester.pumpAndSettle();
      runtime.pregnancyDiaryChangeStore.record(
        PregnancyDiaryChange.tryFromEvent(_diaryChangedEvent())!,
      );
      final planChanged = _planChangedEvent();
      client.emit(planChanged);
      client.emit(planChanged);
      await tester.pump();

      expect(runtime.pregnancyPlanChangeStore.revision, 1);
      expect(
        find.byKey(const ValueKey('bottom-nav-status-diary-badge')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('bottom-nav-status-plan-badge')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('bottom-nav-status-badge')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('bottom-nav-status-plan-badge')),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label == '孕期日记和孕期计划有更新',
          ),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('bottom-nav-status')));
      await _pumpFrames(tester, 8);

      expect(transport.planGetCount, 1);
      expect(runtime.pregnancyDiaryChangeStore.hasUnread, isFalse);
      expect(runtime.pregnancyDiaryChangeStore.highlightCard, isTrue);
      expect(runtime.pregnancyPlanChangeStore.hasUnread, isFalse);
      expect(runtime.pregnancyPlanChangeStore.highlightCard, isTrue);
      expect(
        find.byKey(const ValueKey('status-pregnancy-plan-change-highlight')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('bottom-nav-status-plan-badge')),
        findsNothing,
      );

      final upcomingPeriod = find.byKey(
        const ValueKey('journey-period:upcoming'),
      );
      await _scrollTo(tester, upcomingPeriod);
      await tester.tap(upcomingPeriod);
      await tester.pump();
      expect(find.text('确认入院路线'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      expect(runtime.pregnancyPlanChangeStore.highlightCard, isFalse);
      expect(find.text('确认入院路线'), findsOneWidget);
    },
  );

  testWidgets('empty plan after a created event restores the unread badge', (
    tester,
  ) async {
    await _setCompactViewport(tester);
    final transport = _PlanTransport();
    final runtime = _runtime(transport);
    runtime.pregnancyPlanChangeStore.record(
      PregnancyPlanChange.tryFromEvent(_planChangedEvent())!,
    );
    final harness = await _pumpApp(
      tester,
      transport: transport,
      runtime: runtime,
      initialLocation: '/schedule',
    );

    expect(
      find.byKey(const ValueKey('bottom-nav-status-plan-badge')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('bottom-nav-status')));
    await tester.pumpAndSettle();

    expect(transport.planGetCount, 1);
    expect(runtime.pregnancyPlanChangeStore.hasUnread, isTrue);
    expect(runtime.pregnancyPlanChangeStore.highlightCard, isFalse);
    expect(
      find.byKey(const ValueKey('status-pregnancy-plan-error')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('status-pregnancy-plan-agent-button')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('bottom-nav-status-plan-badge')),
      findsOneWidget,
    );

    harness.dispose();
  });

  testWidgets('stale failed reload cannot undo a newer plan success', (
    tester,
  ) async {
    await _setCompactViewport(tester);
    final second = Completer<Map<String, Object?>>();
    final third = Completer<Map<String, Object?>>();
    final transport = _PlanTransport(
      planResponses: {
        1: const {'items': <Object?>[]},
      },
      deferredPlanRequests: {2: second, 3: third},
    );
    final runtime = _runtime(transport);
    final harness = await _pumpApp(
      tester,
      transport: transport,
      runtime: runtime,
      initialLocation: '/status',
    );
    await tester.tap(find.byKey(const ValueKey('status-care-stage-pregnancy')));
    await tester.pumpAndSettle();
    expect(transport.planGetCount, 1);

    runtime.pregnancyPlanChangeStore.record(
      PregnancyPlanChange.tryFromEvent(
        _planChangedEvent(eventId: 'evt-plan-2'),
      )!,
    );
    await tester.pump();
    runtime.pregnancyPlanChangeStore.record(
      PregnancyPlanChange.tryFromEvent(
        _planChangedEvent(eventId: 'evt-plan-3', sequence: 3),
      )!,
    );
    await tester.pump();

    third.complete(_planResponse(title: '最新孕期计划'));
    await _pumpFrames(tester, 4);
    second.completeError(StateError('stale plan GET failed'));
    await _pumpFrames(tester, 4);

    expect(transport.planGetCount, 3);
    expect(runtime.pregnancyPlanChangeStore.revision, 2);
    expect(runtime.pregnancyPlanChangeStore.hasUnread, isFalse);
    expect(runtime.pregnancyPlanChangeStore.highlightCard, isTrue);
    expect(find.text('最新孕期计划'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('bottom-nav-status-plan-badge')),
      findsNothing,
    );

    harness.dispose();
  });

  testWidgets(
    'same-revision stale success cannot override a refreshed runtime failure',
    (tester) async {
      await _setCompactViewport(tester);
      final staleResponse = Completer<Map<String, Object?>>();
      final sharedStore = PregnancyPlanChangeStore();
      sharedStore.record(
        PregnancyPlanChange.tryFromEvent(
          _planChangedEvent(eventId: 'evt-same-revision-refresh'),
        )!,
      );
      final firstTransport = _PlanTransport(
        deferredPlanRequests: {1: staleResponse},
      );
      final secondTransport = _PlanTransport(failingPlanRequests: const {1});
      final firstRuntime = _runtime(
        firstTransport,
        planChangeStore: sharedStore,
      );
      final controller = MomCozyRuntimeController(firstRuntime);
      final router = createMomCozyRouter(
        initialLocation: '/status',
        runtimeController: controller,
      );
      final routePlatform = FakeRouteIntentPlatform();
      addTearDown(controller.dispose);
      addTearDown(router.dispose);
      addTearDown(routePlatform.dispose);

      await tester.pumpWidget(
        MomCozyFlutterApp(
          router: router,
          routeIntentPlatform: routePlatform,
          runtimeController: controller,
        ),
      );
      await _pumpFrames(tester, 4);
      expect(firstTransport.planGetCount, 1);

      controller.replaceRuntime(
        _runtime(secondTransport, planChangeStore: sharedStore),
      );
      await tester.pumpAndSettle();
      expect(secondTransport.planGetCount, 1);
      expect(
        find.byKey(const ValueKey('status-pregnancy-plan-error')),
        findsOneWidget,
      );
      expect(sharedStore.hasUnread, isTrue);

      staleResponse.complete(_planResponse(title: '过期计划'));
      await _pumpFrames(tester, 4);

      expect(sharedStore.hasUnread, isTrue);
      expect(sharedStore.highlightCard, isFalse);
      expect(
        find.byKey(const ValueKey('bottom-nav-status-plan-badge')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('status-pregnancy-plan-error')),
        findsOneWidget,
      );
    },
  );

  testWidgets('successful reload keeps unread when its card is not rendered', (
    tester,
  ) async {
    await _setCompactViewport(tester);
    final changedResponse = Completer<Map<String, Object?>>();
    final transport = _PlanTransport(
      planResponses: {
        1: const {'items': <Object?>[]},
      },
      deferredPlanRequests: {2: changedResponse},
    );
    final runtime = _runtime(transport);
    final harness = await _pumpApp(
      tester,
      transport: transport,
      runtime: runtime,
      initialLocation: '/status',
    );
    await tester.tap(find.byKey(const ValueKey('status-care-stage-pregnancy')));
    await tester.pumpAndSettle();

    runtime.pregnancyPlanChangeStore.record(
      PregnancyPlanChange.tryFromEvent(
        _planChangedEvent(eventId: 'evt-hidden-plan-card'),
      )!,
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('status-care-stage-postpartum')),
    );
    await tester.pump();

    changedResponse.complete(_planResponse(title: '未渲染的计划'));
    await _pumpFrames(tester, 4);

    expect(runtime.pregnancyPlanChangeStore.hasUnread, isTrue);
    expect(runtime.pregnancyPlanChangeStore.highlightCard, isFalse);
    expect(
      find.byKey(const ValueKey('bottom-nav-status-plan-badge')),
      findsOneWidget,
    );

    harness.dispose();
  });

  testWidgets(
    'acknowledged restore does not switch postpartum Status or fetch a plan',
    (tester) async {
      await _setCompactViewport(tester);
      final persistence = _BlockingPlanPersistence(
        const PregnancyPlanPendingState(
          hasUnread: false,
          highlightCard: false,
          revision: 3,
          lastEventId: 'evt-acknowledged-plan',
          seenEventIds: ['evt-acknowledged-plan'],
        ),
      );
      final store = PregnancyPlanChangeStore(persistence: persistence);
      final transport = _PlanTransport();
      final harness = await _pumpApp(
        tester,
        transport: transport,
        runtime: _runtime(transport, planChangeStore: store),
        initialLocation: '/status',
      );

      expect(transport.planGetCount, 0);
      expect(
        find.byKey(const ValueKey('status-pregnancy-plan-loading')),
        findsNothing,
      );

      persistence.release();
      await _pumpFrames(tester, 4);

      expect(store.revision, 3);
      expect(store.hasUnread, isFalse);
      expect(store.highlightCard, isFalse);
      expect(transport.planGetCount, 0);
      expect(
        find.byKey(const ValueKey('status-pregnancy-plan-loading')),
        findsNothing,
      );

      harness.dispose();
    },
  );

  testWidgets(
    'account switch disposes the active Agent stream before late plan events',
    (tester) async {
      await _setCompactViewport(tester);
      final firstClient = _ControllableAgentStreamClient();
      final secondClient = _ControllableAgentStreamClient();
      final firstStore = PregnancyPlanChangeStore();
      final secondStore = PregnancyPlanChangeStore();
      final firstRuntime = _runtime(
        _PlanTransport(),
        planChangeStore: firstStore,
        userId: 'plan-user-a',
      );
      final secondRuntime = _runtime(
        _PlanTransport(),
        planChangeStore: secondStore,
        userId: 'plan-user-b',
      );
      final controller = MomCozyRuntimeController(firstRuntime);
      final router = createMomCozyRouter(
        initialLocation: '/',
        runtimeController: controller,
        agentHubBuilder: (context, uri, extra, voicePlaybackCoordinator) {
          final runtime = MomCozyRuntimeScope.of(context);
          final client = runtime.session.userId == 'plan-user-a'
              ? firstClient
              : secondClient;
          return AgentHubPage(
            runner: AgentStreamRunner(client),
            voicePlaybackCoordinator: voicePlaybackCoordinator,
            onPregnancyPlanChange: runtime.pregnancyPlanChangeStore.record,
          );
        },
      );
      final routePlatform = FakeRouteIntentPlatform();
      addTearDown(firstClient.dispose);
      addTearDown(secondClient.dispose);
      addTearDown(controller.dispose);
      addTearDown(router.dispose);
      addTearDown(routePlatform.dispose);

      await tester.pumpWidget(
        MomCozyFlutterApp(
          router: router,
          routeIntentPlatform: routePlatform,
          runtimeController: controller,
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('agent-composer-input')),
        '生成孕期计划',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('agent-send-button')));
      await tester.pump();
      expect(firstClient.requests, hasLength(1));

      controller.replaceRuntime(secondRuntime);
      await _pumpFrames(tester, 4);
      firstClient.emit(_planChangedEvent(eventId: 'evt-late-from-user-a'));
      await tester.pump();

      expect(firstClient.cancelCount, 1);
      expect(firstStore.revision, 0);
      expect(secondStore.revision, 0);
      expect(secondStore.hasUnread, isFalse);
    },
  );

  testWidgets('same-user runtime refresh preserves the active Agent stream', (
    tester,
  ) async {
    await _setCompactViewport(tester);
    final firstClient = _ControllableAgentStreamClient();
    final refreshedClient = _ControllableAgentStreamClient();
    final sharedStore = PregnancyPlanChangeStore();
    final firstRuntime = _runtime(
      _PlanTransport(),
      planChangeStore: sharedStore,
      userId: 'same-plan-user',
    );
    final refreshedRuntime = _runtime(
      _PlanTransport(),
      planChangeStore: sharedStore,
      userId: 'same-plan-user',
    );
    final controller = MomCozyRuntimeController(firstRuntime);
    final router = createMomCozyRouter(
      initialLocation: '/',
      runtimeController: controller,
      agentHubBuilder: (context, uri, extra, voicePlaybackCoordinator) {
        final runtime = MomCozyRuntimeScope.of(context);
        final client = identical(runtime, firstRuntime)
            ? firstClient
            : refreshedClient;
        return AgentHubPage(
          runner: AgentStreamRunner(client),
          voicePlaybackCoordinator: voicePlaybackCoordinator,
          onPregnancyPlanChange: runtime.pregnancyPlanChangeStore.record,
        );
      },
    );
    final routePlatform = FakeRouteIntentPlatform();
    addTearDown(firstClient.dispose);
    addTearDown(refreshedClient.dispose);
    addTearDown(controller.dispose);
    addTearDown(router.dispose);
    addTearDown(routePlatform.dispose);

    await tester.pumpWidget(
      MomCozyFlutterApp(
        router: router,
        routeIntentPlatform: routePlatform,
        runtimeController: controller,
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('agent-composer-input')),
      '生成孕期计划',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('agent-send-button')));
    await tester.pump();

    controller.replaceRuntime(refreshedRuntime);
    await _pumpFrames(tester, 4);
    firstClient.emit(_planChangedEvent(eventId: 'evt-after-same-user-refresh'));
    await tester.pump();

    expect(firstClient.cancelCount, 0);
    expect(refreshedClient.requests, isEmpty);
    expect(sharedStore.revision, 1);
    expect(sharedStore.hasUnread, isTrue);
  });

  testWidgets(
    'logout disposes the active Agent stream despite retained user id',
    (tester) async {
      await _setCompactViewport(tester);
      final authenticatedClient = _ControllableAgentStreamClient();
      final loggedOutClient = _ControllableAgentStreamClient();
      final sharedStore = PregnancyPlanChangeStore();
      final authenticatedRuntime = _runtime(
        _PlanTransport(),
        planChangeStore: sharedStore,
        userId: 'logout-plan-user',
      );
      sharedStore.record(
        PregnancyPlanChange.tryFromEvent(
          _planChangedEvent(eventId: 'evt-before-logout'),
        )!,
      );
      final controller = MomCozyRuntimeController(authenticatedRuntime);
      final router = createMomCozyRouter(
        initialLocation: '/',
        agentHubBuilder: (context, uri, extra, voicePlaybackCoordinator) {
          final runtime = MomCozyRuntimeScope.of(context);
          final client =
              runtime.session.status == MomCozySessionStatus.authenticated
              ? authenticatedClient
              : loggedOutClient;
          return AgentHubPage(
            runner: AgentStreamRunner(client),
            voicePlaybackCoordinator: voicePlaybackCoordinator,
            onPregnancyPlanChange: runtime.pregnancyPlanChangeStore.record,
          );
        },
      );
      final routePlatform = FakeRouteIntentPlatform();
      addTearDown(authenticatedClient.dispose);
      addTearDown(loggedOutClient.dispose);
      addTearDown(controller.dispose);
      addTearDown(router.dispose);
      addTearDown(routePlatform.dispose);

      await tester.pumpWidget(
        MomCozyFlutterApp(
          router: router,
          routeIntentPlatform: routePlatform,
          runtimeController: controller,
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('agent-composer-input')),
        '生成孕期计划',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('agent-send-button')));
      await tester.pump();

      controller.replaceSession(authenticatedRuntime.session.loggedOut());
      await _pumpFrames(tester, 4);
      final loggedOutStore = controller.runtime.pregnancyPlanChangeStore;
      authenticatedClient.emit(
        _planChangedEvent(eventId: 'evt-late-after-logout'),
      );
      await tester.pump();

      expect(authenticatedClient.cancelCount, 1);
      expect(loggedOutStore, isNot(same(sharedStore)));
      expect(loggedOutStore.revision, 0);
      expect(loggedOutStore.hasUnread, isFalse);
      expect(sharedStore.revision, 1);
      expect(sharedStore.hasUnread, isTrue);
      expect(loggedOutClient.requests, isEmpty);
    },
  );
}

Future<_AppHarness> _pumpApp(
  WidgetTester tester, {
  required _PlanTransport transport,
  MomCozyApiRuntime? runtime,
  required String initialLocation,
}) async {
  final resolvedRuntime = runtime ?? _runtime(transport);
  final router = createMomCozyRouter(initialLocation: initialLocation);
  final routePlatform = FakeRouteIntentPlatform();
  await tester.pumpWidget(
    MomCozyFlutterApp(
      router: router,
      routeIntentPlatform: routePlatform,
      apiRuntime: resolvedRuntime,
    ),
  );
  await tester.pumpAndSettle();
  return _AppHarness(router: router, routePlatform: routePlatform);
}

class _AppHarness {
  const _AppHarness({required this.router, required this.routePlatform});

  final GoRouter router;
  final FakeRouteIntentPlatform routePlatform;

  void dispose() {
    router.dispose();
    routePlatform.dispose();
  }
}

Future<void> _setCompactViewport(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    260,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpFrames(WidgetTester tester, int count) async {
  for (var index = 0; index < count; index++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

MomCozyApiRuntime _runtime(
  _PlanTransport transport, {
  PregnancyPlanChangeStore? planChangeStore,
  String userId = 'plan-widget-user',
}) {
  return MomCozyApiRuntime(
    jsonTransport: transport,
    pregnancyPlanChangeStore: planChangeStore ?? PregnancyPlanChangeStore(),
    multipartTransport: FixtureApiMultipartTransport(const <String, Object?>{}),
    session: MomCozySession(
      status: MomCozySessionStatus.authenticated,
      userId: userId,
      babyId: '$userId-baby',
      locale: 'zh-CN',
      accessToken: '$userId-access',
      refreshToken: '$userId-refresh',
    ),
    now: () => DateTime.utc(2026, 7, 12),
  );
}

class _ControllableAgentStreamClient implements AgentStreamClient {
  final requests = <AgentStreamRequest>[];
  final _controllers = <StreamController<AgentStreamEvent>>[];
  int cancelCount = 0;

  @override
  Stream<AgentStreamEvent> stream(AgentStreamRequest request) {
    requests.add(request);
    final controller = StreamController<AgentStreamEvent>(
      onCancel: () {
        cancelCount += 1;
      },
    );
    _controllers.add(controller);
    return controller.stream;
  }

  void emit(AgentStreamEvent event) => _controllers.single.add(event);

  Future<void> dispose() async {
    for (final controller in _controllers) {
      await controller.close();
    }
  }
}

class _PlanTransport implements ApiJsonTransport {
  _PlanTransport({
    this.failingPlanRequests = const <int>{},
    this.planResponses = const <int, Map<String, Object?>>{},
    this.deferredPlanRequests = const <int, Completer<Map<String, Object?>>>{},
  });

  final Set<int> failingPlanRequests;
  final Map<int, Map<String, Object?>> planResponses;
  final Map<int, Completer<Map<String, Object?>>> deferredPlanRequests;
  int planGetCount = 0;
  final List<Map<String, Object?>> planQueries = [];

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) async {
    if (path == statusProfileEndpoint) {
      return const {
        'user_id': 'plan-widget-user',
        'delivery_date': '2026-09-01',
      };
    }
    if (path == statusInfantsEndpoint) {
      return const {'items': <Object?>[]};
    }
    if (path == pregnancyDiaryEntriesEndpoint) {
      return const {'items': <Object?>[]};
    }
    if (path == pregnancyPlansEndpoint) {
      planGetCount += 1;
      planQueries.add(Map<String, Object?>.from(query));
      if (failingPlanRequests.contains(planGetCount)) {
        throw StateError('pregnancy plan GET failed');
      }
      final deferred = deferredPlanRequests[planGetCount];
      if (deferred != null) return deferred.future;
      return planResponses[planGetCount] ?? const {'items': <Object?>[]};
    }
    return const <String, Object?>{};
  }

  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) {
    throw UnsupportedError('POST is not used by this test.');
  }

  @override
  Future<Map<String, Object?>> patchJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) {
    throw UnsupportedError('PATCH is not used by this test.');
  }

  @override
  Future<void> deleteJson(
    String path, {
    Map<String, String> headers = const {},
  }) {
    throw UnsupportedError('DELETE is not used by this test.');
  }
}

class _BlockingPlanPersistence implements PregnancyPlanChangePersistence {
  _BlockingPlanPersistence(this.value);

  final PregnancyPlanPendingState value;
  final Completer<void> _release = Completer<void>();

  void release() => _release.complete();

  @override
  Future<PregnancyPlanPendingState?> read() async {
    await _release.future;
    return value;
  }

  @override
  Future<void> write(PregnancyPlanPendingState state) async {}
}

Map<String, Object?> _planResponse({String title = '我的孕期计划'}) {
  return {
    'items': [
      {
        'id': 'plan-pregnancy-1',
        'owner_user_id': 'plan-widget-user',
        'plan_type': 'pregnancy',
        'title': '孕期计划',
        'summary': '从现在到生产前后的阶段计划与待办',
        'status': 'active',
        'source': 'agent_action',
        'payload': {
          'card': {
            'card_type': 'birth_journey_plan_card',
            'schema_version': '1.0',
            'card_json': {
              'title': title,
              'todo_plan': {
                'periods': [
                  {
                    'id': 'current',
                    'title': '当前阶段｜孕 32 周起',
                    'status': 'current',
                    'items': [
                      {
                        'title': '和产科确认个性化复查节奏',
                        'reason': '因为是双胎，需要更密切观察生长',
                        'steps': ['确认孕周口径', '安排胎儿生长复查'],
                      },
                    ],
                  },
                  {
                    'id': 'upcoming',
                    'title': '后续阶段｜临产准备',
                    'status': 'upcoming',
                    'items': [
                      {'title': '确认入院路线'},
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

AgentStreamEvent _runStartedEvent() => AgentStreamEvent(const {
  'event_id': 'evt-run-started',
  'sequence': 1,
  'type': 'run.started',
  'thread_id': 'thread-plan',
  'run_id': 'run-plan',
  'payload': <String, Object?>{},
});

AgentStreamEvent _planChangedEvent({
  String eventId = 'evt-plan-changed',
  int sequence = 2,
}) {
  return AgentStreamEvent({
    'event_id': eventId,
    'sequence': sequence,
    'type': 'pregnancy_plan.changed',
    'thread_id': 'thread-plan',
    'run_id': 'run-plan',
    'payload': const {
      'operation': 'created',
      'plan_id': 'plan-pregnancy-1',
      'plan_type': 'pregnancy',
      'source': 'agent_action',
      'action_id': 'action-plan-create',
    },
  });
}

AgentStreamEvent _diaryChangedEvent() => AgentStreamEvent(const {
  'event_id': 'evt-diary-changed',
  'sequence': 2,
  'type': 'pregnancy_diary.changed',
  'payload': {
    'operation': 'created',
    'entry_id': 'diary-2026-07-12',
    'entry_date': '2026-07-12',
    'updated_at': '2026-07-12T08:30:00Z',
    'source': 'agent',
  },
});
