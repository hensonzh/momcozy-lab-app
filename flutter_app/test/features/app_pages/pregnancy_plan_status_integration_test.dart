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
import 'package:momcozy_flutter_app/core/preferences/volume_unit_preference.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_page.dart';
import 'package:momcozy_flutter_app/features/pregnancy_plan/data/pregnancy_plan_api_repository.dart';
import 'package:momcozy_flutter_app/features/pregnancy_plan/domain/pregnancy_plan_change_store.dart';
import 'package:momcozy_flutter_app/features/status/data/status_api_repository.dart';
import 'package:momcozy_flutter_app/features/status/data/status_preference_store.dart';
import 'package:momcozy_flutter_app/features/status/domain/status_selection.dart';
import 'package:momcozy_flutter_app/native/p0_platform_interfaces.dart';

import '../../support/fixture_api_transport.dart';

void main() {
  testWidgets(
    'Agent plan change deduplicates replay and resolves the nav badge to the Birth Journey notice',
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
      await _pumpApp(
        tester,
        runtime: runtime,
        router: router,
        initialLocation: '/',
      );
      addTearDown(client.dispose);

      await _startAgentRun(tester);
      client.emit(_runStartedEvent());
      await tester.pump();
      final changed = _planChangedEvent();
      client.emit(changed);
      client.emit(changed);
      await tester.pump();

      expect(runtime.pregnancyPlanChangeStore.revision, 1);
      expect(runtime.pregnancyPlanChangeStore.hasUnread, isTrue);
      expect(
        find.byKey(const ValueKey('bottom-nav-status-plan-badge')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('bottom-nav-status-plan-badge')),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.label == '孕期计划有更新',
          ),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('bottom-nav-status')));
      await _pumpFrames(tester, 30);
      await _scrollToBirthJourney(tester);

      expect(transport.planGetCount, 1);
      expect(transport.planQueries.single, {
        'plan_type': 'pregnancy',
        'status': 'active',
        'limit': 1,
      });
      expect(runtime.pregnancyPlanChangeStore.hasUnread, isFalse);
      expect(runtime.pregnancyPlanChangeStore.highlightCard, isTrue);
      expect(
        find.byKey(const ValueKey('bottom-nav-status-plan-badge')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('status-birth-journey-dashboard')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('status-birth-journey-card')),
        findsOneWidget,
      );
      _expectBirthJourneyNotice();
      expect(find.text('和产科确认个性化复查节奏'), findsOneWidget);

      await _letBirthJourneyNoticeExpire(tester);
    },
  );

  testWidgets(
    'Agent change during the active Status load schedules one trailing refresh',
    (tester) async {
      await _setCompactViewport(tester);
      final initialPlan = Completer<Map<String, Object?>>();
      final transport = _PlanTransport(
        deferredPlanRequests: {1: initialPlan},
        planResponses: {2: _planResponse(title: '刷新后的孕期计划')},
      );
      final runtime = _runtime(transport);
      await _pumpApp(
        tester,
        runtime: runtime,
        initialLocation: '/status',
        settle: false,
      );
      await _pumpUntil(
        tester,
        () => transport.planGetCount == 1,
        reason: 'the initial Status load should request the active plan',
      );

      runtime.pregnancyPlanChangeStore.record(
        PregnancyPlanChange.tryFromEvent(
          _planChangedEvent(eventId: 'evt-plan-during-load'),
        )!,
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('bottom-nav-status-plan-badge')),
        findsOneWidget,
      );

      initialPlan.complete(const {'items': <Object?>[]});
      await _pumpUntil(
        tester,
        () => transport.planGetCount == 2,
        reason: 'the external change should run after the active load',
      );
      await _pumpFrames(tester, 30);
      await _scrollToBirthJourney(tester);

      expect(transport.planGetCount, 2);
      expect(find.text('和产科确认个性化复查节奏'), findsOneWidget);
      expect(runtime.pregnancyPlanChangeStore.hasUnread, isFalse);
      expect(runtime.pregnancyPlanChangeStore.highlightCard, isTrue);
      expect(
        find.byKey(const ValueKey('bottom-nav-status-plan-badge')),
        findsNothing,
      );
      _expectBirthJourneyNotice();

      await _letBirthJourneyNoticeExpire(tester);
    },
  );

  testWidgets('failed plan synchronization restores the unread badge', (
    tester,
  ) async {
    await _setCompactViewport(tester);
    final transport = _PlanTransport(failingPlanRequests: const {1});
    final runtime = _runtimeWithUnreadPlan(transport, 'evt-plan-failure');
    await _pumpApp(tester, runtime: runtime, initialLocation: '/schedule');

    await _openStatusAndSettle(tester, runtime);

    expect(transport.planGetCount, 1);
    _expectUnreadPlanBadge(runtime);
    expect(
      find.byKey(const ValueKey('status-birth-journey-card')),
      findsOneWidget,
    );
    expect(find.text('孕期计划暂时无法同步，请稍后重试'), findsOneWidget);
    expect(find.text('制定孕期计划'), findsNothing);
  });

  testWidgets('empty plan synchronization restores the unread badge', (
    tester,
  ) async {
    await _setCompactViewport(tester);
    final transport = _PlanTransport();
    final runtime = _runtimeWithUnreadPlan(transport, 'evt-plan-empty');
    await _pumpApp(tester, runtime: runtime, initialLocation: '/schedule');

    await _openStatusAndSettle(tester, runtime);

    expect(transport.planGetCount, 1);
    _expectUnreadPlanBadge(runtime);
    expect(
      find.byKey(const ValueKey('status-birth-journey-card')),
      findsOneWidget,
    );
    expect(find.text('制定孕期计划'), findsOneWidget);
  });

  testWidgets('malformed plan synchronization restores the unread badge', (
    tester,
  ) async {
    await _setCompactViewport(tester);
    final transport = _PlanTransport(
      planResponses: {1: _malformedPlanResponse()},
    );
    final runtime = _runtimeWithUnreadPlan(transport, 'evt-plan-malformed');
    await _pumpApp(tester, runtime: runtime, initialLocation: '/schedule');

    await _openStatusAndSettle(tester, runtime);

    expect(transport.planGetCount, 1);
    _expectUnreadPlanBadge(runtime);
    expect(
      find.byKey(const ValueKey('status-birth-journey-card')),
      findsOneWidget,
    );
    expect(find.text('孕期计划暂时无法同步，请稍后重试'), findsOneWidget);
    expect(find.text('制定孕期计划'), findsNothing);
  });

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
      await _pumpApp(
        tester,
        runtimeController: controller,
        router: router,
        initialLocation: '/',
      );
      addTearDown(firstClient.dispose);
      addTearDown(secondClient.dispose);

      await _startAgentRun(tester);
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
    await _pumpApp(
      tester,
      runtimeController: controller,
      router: router,
      initialLocation: '/',
    );
    addTearDown(firstClient.dispose);
    addTearDown(refreshedClient.dispose);

    await _startAgentRun(tester);
    expect(firstClient.requests, hasLength(1));

    controller.replaceRuntime(refreshedRuntime);
    await _pumpFrames(tester, 4);
    firstClient.emit(_planChangedEvent(eventId: 'evt-after-same-user-refresh'));
    await tester.pump();

    expect(firstClient.cancelCount, 0);
    expect(refreshedClient.requests, isEmpty);
    expect(sharedStore.revision, 1);
    expect(sharedStore.hasUnread, isTrue);
  });
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required String initialLocation,
  MomCozyApiRuntime? runtime,
  MomCozyRuntimeController? runtimeController,
  GoRouter? router,
  bool settle = true,
}) async {
  assert(runtime != null || runtimeController != null);
  final effectiveRouter =
      router ??
      createMomCozyRouter(
        initialLocation: initialLocation,
        runtimeController: runtimeController,
      );
  final routePlatform = FakeRouteIntentPlatform();
  addTearDown(effectiveRouter.dispose);
  addTearDown(routePlatform.dispose);
  if (runtimeController != null) addTearDown(runtimeController.dispose);
  await tester.pumpWidget(
    MomCozyFlutterApp(
      router: effectiveRouter,
      routeIntentPlatform: routePlatform,
      apiRuntime: runtime,
      runtimeController: runtimeController,
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await _pumpFrames(tester, 4);
  }
}

Future<void> _startAgentRun(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const ValueKey('agent-composer-input')),
    '生成孕期计划',
  );
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('agent-send-button')));
  await tester.pump();
}

Future<void> _openStatusAndSettle(
  WidgetTester tester,
  MomCozyApiRuntime runtime,
) async {
  expect(
    find.byKey(const ValueKey('bottom-nav-status-plan-badge')),
    findsOneWidget,
  );
  await tester.tap(find.byKey(const ValueKey('bottom-nav-status')));
  await tester.pumpAndSettle();
  await _pumpUntil(
    tester,
    () => runtime.pregnancyPlanChangeStore.hasUnread,
    reason: 'an unusable plan response should restore the navigation badge',
  );
  await _scrollToBirthJourney(tester);
}

Future<void> _scrollToBirthJourney(WidgetTester tester) async {
  final card = find.byKey(const ValueKey('status-birth-journey-card'));
  final statusScrollView = find.byKey(const ValueKey('route-page-/status'));
  for (var index = 0; index < 8 && card.evaluate().isEmpty; index += 1) {
    await tester.drag(statusScrollView, const Offset(0, -260));
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void _expectUnreadPlanBadge(MomCozyApiRuntime runtime) {
  expect(runtime.pregnancyPlanChangeStore.hasUnread, isTrue);
  expect(runtime.pregnancyPlanChangeStore.highlightCard, isFalse);
  expect(
    find.byKey(const ValueKey('bottom-nav-status-plan-badge')),
    findsOneWidget,
  );
  expect(
    find.byKey(const ValueKey('status-birth-journey-notice')),
    findsOneWidget,
  );
}

void _expectBirthJourneyNotice() {
  expect(
    find.byKey(const ValueKey('status-birth-journey-notice')),
    findsOneWidget,
  );
}

Future<void> _letBirthJourneyNoticeExpire(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
}

Future<void> _setCompactViewport(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpFrames(WidgetTester tester, int count) async {
  for (var index = 0; index < count; index += 1) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  required String reason,
}) async {
  for (var index = 0; index < 40 && !condition(); index += 1) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(condition(), isTrue, reason: reason);
}

MomCozyApiRuntime _runtimeWithUnreadPlan(
  _PlanTransport transport,
  String eventId,
) {
  final runtime = _runtime(transport);
  runtime.pregnancyPlanChangeStore.record(
    PregnancyPlanChange.tryFromEvent(_planChangedEvent(eventId: eventId))!,
  );
  return runtime;
}

MomCozyApiRuntime _runtime(
  _PlanTransport transport, {
  PregnancyPlanChangeStore? planChangeStore,
  String userId = 'plan-widget-user',
}) {
  return MomCozyApiRuntime(
    jsonTransport: transport,
    pregnancyPlanChangeStore: planChangeStore ?? PregnancyPlanChangeStore(),
    statusPreferenceStore: _MemoryStatusPreferenceStore(),
    volumeUnitPreferenceStore: _MemoryVolumeUnitPreferenceStore(),
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

class _MemoryStatusPreferenceStore implements StatusPreferenceStore {
  StatusCareStage? value;

  @override
  Future<StatusCareStage?> readCareStage() async => value;

  @override
  Future<void> writeCareStage(StatusCareStage stage) async {
    value = stage;
  }
}

class _MemoryVolumeUnitPreferenceStore implements VolumeUnitPreferenceStore {
  MomCozyVolumeUnit? value;

  @override
  Future<MomCozyVolumeUnit?> read() async => value;

  @override
  Future<void> write(MomCozyVolumeUnit unit) async {
    value = unit;
  }
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
    return const {'items': <Object?>[]};
  }

  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) {
    throw UnsupportedError('POST is not used by this read-only integration.');
  }
}

Map<String, Object?> _planResponse({String title = '我的孕期计划'}) {
  return {
    'items': [
      {
        'id': 'plan-pregnancy-1',
        'owner_user_id': 'plan-widget-user',
        'plan_type': 'pregnancy',
        'title': title,
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
                        'id': 'todo-current',
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
                      {'id': 'todo-upcoming', 'title': '确认入院路线'},
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

Map<String, Object?> _malformedPlanResponse() {
  return {
    'items': [
      {
        'id': 'plan-pregnancy-malformed',
        'owner_user_id': 'plan-widget-user',
        'plan_type': 'pregnancy',
        'title': '缺少阶段的损坏计划',
        'status': 'active',
        'source': 'agent_action',
        'payload': {
          'card': {
            'card_type': 'birth_journey_plan_card',
            'schema_version': '1.0',
            'card_json': {'title': '缺少 todo_plan 的损坏计划'},
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
