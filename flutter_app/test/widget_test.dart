import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_client.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_event.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_runner.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_auth_device_id.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/core/observability/momcozy_observability.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_page.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_voice.dart';
import 'package:momcozy_flutter_app/native/p0_platform_interfaces.dart';

import 'support/fixture_api_transport.dart';

void main() {
  testWidgets('route shell starts at Agent Hub and navigates bottom tabs', (
    tester,
  ) async {
    await tester.pumpWidget(
      MomCozyFlutterApp(apiRuntime: _authenticatedRuntime()),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('agent-hub-page')), findsOneWidget);
    expect(find.textContaining('嗨，我是 CozyMate'), findsOneWidget);
    expect(
      tester
          .widget<AgentHubPage>(find.byType(AgentHubPage))
          .interactionStateStore,
      isNull,
    );

    await tester.enterText(
      find.byKey(const ValueKey('agent-composer-input')),
      'Review my pattern',
    );
    await tester.pump();

    final sendButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('agent-send-button')),
    );
    expect(sendButton.onPressed, isNotNull);

    await tester.tap(find.text('计划').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('route-page-/schedule')), findsOneWidget);
    expect(find.text('计划'), findsWidgets);
  });

  testWidgets(
    'route shell keeps Agent Hub stream and voice alive across bottom tabs',
    (tester) async {
      final client = _ControllableAgentStreamClient();
      final voicePlayer = _WidgetFakeVoicePlaybackPlayer();
      AgentVoicePlaybackCoordinator? shellCoordinator;

      await tester.pumpWidget(
        MomCozyFlutterApp(
          apiRuntime: _authenticatedRuntime(),
          agentHubBuilder: (context, uri, extra, voicePlaybackCoordinator) {
            final runtime = MomCozyRuntimeScope.of(context);
            shellCoordinator = voicePlaybackCoordinator;
            return AgentHubPage(
              stateCacheKey: runtime,
              runner: AgentStreamRunner(client),
              voicePlaybackCoordinator: voicePlaybackCoordinator,
              voicePlaybackPlayer: voicePlayer,
              requestBuilder: (message) => AgentStreamRequest(message: message),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('agent-composer-input')),
        'Keep this reply running',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('agent-send-button')));
      await tester.pump();

      expect(client.requests, hasLength(1));
      client.emit(
        0,
        _agentEvent(
          id: 'evt-keep-1',
          type: 'message.delta',
          sequence: 1,
          text: 'I am still ',
        ),
      );
      await tester.pump();
      expect(find.textContaining('I am still'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('bottom-nav-schedule')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('route-page-/schedule')),
        findsOneWidget,
      );
      expect(client.cancelCount, 0);

      client
        ..emit(
          0,
          _agentEvent(
            id: 'evt-keep-2',
            type: 'message.delta',
            sequence: 2,
            text: 'running while hidden.',
          ),
        )
        ..emit(
          0,
          _agentEvent(
            id: 'evt-keep-3',
            type: 'message.completed',
            sequence: 3,
            text: 'I am still running while hidden.',
          ),
        )
        ..emit(
          0,
          _agentEvent(id: 'evt-keep-4', type: 'run.completed', sequence: 4),
        );
      await tester.pump();
      await tester.pump();

      expect(
        shellCoordinator?.activeSource,
        AgentVoicePlaybackSource.autoReply,
      );
      expect(shellCoordinator?.activeId, 'msg-keep-alive');

      await tester.tap(find.byKey(const ValueKey('bottom-nav-agent')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const ValueKey('agent-hub-page')), findsOneWidget);
      expect(
        find.textContaining('I am still running while hidden.'),
        findsOneWidget,
      );
      expect(find.textContaining('连接中断'), findsNothing);
      expect(
        find.byKey(const ValueKey('agent-assistant-avatar-speaking')),
        findsOneWidget,
      );

      voicePlayer.complete();
      await tester.pump();
      await tester.pump();
      await client.dispose();
    },
  );

  testWidgets('route shell clears Agent composer focus across bottom tabs', (
    tester,
  ) async {
    await tester.pumpWidget(
      MomCozyFlutterApp(apiRuntime: _authenticatedRuntime()),
    );
    await tester.pumpAndSettle();

    final composer = find.byKey(const ValueKey('agent-composer-input'));
    await tester.showKeyboard(composer);
    await tester.enterText(composer, 'Draft stays, keyboard should not');
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);

    await tester.tap(find.byKey(const ValueKey('bottom-nav-schedule')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('route-page-/schedule')), findsOneWidget);
    expect(tester.testTextInput.isVisible, isFalse);

    await tester.tap(find.byKey(const ValueKey('bottom-nav-agent')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('agent-hub-page')), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('agent-composer-input')))
          .controller
          ?.text,
      'Draft stays, keyboard should not',
    );
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets('route shell lazily mounts the Agent Hub keep-alive slot', (
    tester,
  ) async {
    var buildCount = 0;
    final router = createMomCozyRouter(
      initialLocation: '/pump',
      agentHubBuilder: (context, uri, extra, voicePlaybackCoordinator) {
        buildCount += 1;
        return const SizedBox(key: ValueKey('agent-hub-stub'));
      },
    );

    await tester.pumpWidget(
      MomCozyFlutterApp(router: router, apiRuntime: _authenticatedRuntime()),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('route-page-/pump')), findsOneWidget);
    expect(buildCount, 0);

    router.go('/');
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('agent-hub-stub')), findsOneWidget);
    expect(buildCount, 1);

    router.go('/schedule');
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('route-page-/schedule')), findsOneWidget);
    expect(find.byKey(const ValueKey('agent-hub-stub')), findsNothing);
    expect(
      find.byKey(const ValueKey('agent-hub-stub'), skipOffstage: false),
      findsOneWidget,
    );
    expect(buildCount, greaterThanOrEqualTo(2));
  });

  testWidgets('route shell forwards Agent prefill extra and auto-sends once', (
    tester,
  ) async {
    final client = _ControllableAgentStreamClient();
    final router = createMomCozyRouter(
      initialLocation: '/schedule',
      agentHubBuilder: (context, uri, extra, voicePlaybackCoordinator) {
        final extraMap = extra is Map ? extra : null;
        final prefill = extraMap?['agentPrefill'];
        final autoSend =
            extraMap?['agentAutoSend'] == true || extraMap?['autoSend'] == true;
        return AgentHubPage(
          runner: AgentStreamRunner(client),
          requestBuilder: (message) => AgentStreamRequest(message: message),
          voicePlaybackCoordinator: voicePlaybackCoordinator,
          initialComposerText: prefill is String ? prefill : null,
          initialAutoSend: autoSend,
        );
      },
    );

    await tester.pumpWidget(
      MomCozyFlutterApp(router: router, apiRuntime: _authenticatedRuntime()),
    );
    await tester.pumpAndSettle();

    router.go(
      '/',
      extra: const {
        'agentPrefill': '我已完成孕期计划事项，请继续同步孕期日记',
        'agentAutoSend': true,
      },
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(client.requests, hasLength(1));
    expect(client.requests.single.message, '我已完成孕期计划事项，请继续同步孕期日记');

    await tester.pump();
    await tester.pump();
    expect(client.requests, hasLength(1));

    router.dispose();
    await client.dispose();
  });

  testWidgets('route shell hides bottom navigation on focused flows', (
    tester,
  ) async {
    final router = createMomCozyRouter(initialLocation: '/pump');

    await tester.pumpWidget(MomCozyFlutterApp(router: router));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('route-page-/pump')), findsOneWidget);
    expect(find.byType(MomCozyBottomNavigation), findsNothing);

    for (final route in const [
      '/calibration',
      '/hospital-bag-cart',
      '/ibclc-chat.html',
      '/media-viewer',
    ]) {
      router.go(route);
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('route-page-$route')), findsOneWidget);
      expect(find.byType(MomCozyBottomNavigation), findsNothing);
    }
  });

  testWidgets('route shell renders recoverable not found route', (
    tester,
  ) async {
    final router = createMomCozyRouter(initialLocation: '/unknown-old-page');

    await tester.pumpWidget(MomCozyFlutterApp(router: router));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('route-page-/404')), findsOneWidget);
    expect(find.text('Oops! Page not found'), findsOneWidget);
    expect(find.byType(MomCozyBottomNavigation), findsOneWidget);
  });

  testWidgets('route shell opens media viewer from Agent artifact action', (
    tester,
  ) async {
    await tester.pumpWidget(
      MomCozyFlutterApp(apiRuntime: _authenticatedRuntime()),
    );
    await tester.pumpAndSettle();

    final page = tester.widget<AgentHubPage>(find.byType(AgentHubPage));
    page.onArtifactAction?.call(
      const AgentArtifactActionView(
        label: '打开文档',
        icon: Icons.description_outlined,
        kind: 'doc',
        value: '/docs/a.pdf',
        routePath: '/media-viewer',
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('route-page-/media-viewer')),
      findsOneWidget,
    );
    expect(find.byType(MomCozyBottomNavigation), findsNothing);
  });

  testWidgets('route shell consumes pending native route on startup', (
    tester,
  ) async {
    final routes = FakeRouteIntentPlatform();
    await routes.enqueuePendingRoute(const PendingNativeRoute(path: '/pump'));

    await tester.pumpWidget(
      MomCozyFlutterApp(
        apiRuntime: _authenticatedRuntime(),
        routeIntentPlatform: routes,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('route-page-/pump')), findsOneWidget);
    expect(find.byType(MomCozyBottomNavigation), findsNothing);

    await routes.dispose();
  });

  testWidgets('route shell follows active native route events', (tester) async {
    final routes = FakeRouteIntentPlatform();
    final router = createMomCozyRouter(initialLocation: '/status');

    await tester.pumpWidget(
      MomCozyFlutterApp(router: router, routeIntentPlatform: routes),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('route-page-/status')), findsOneWidget);

    routes.dispatchActiveRoute(const PendingNativeRoute(path: '/pump'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('route-page-/pump')), findsOneWidget);

    await routes.dispose();
  });

  testWidgets('route shell opens schedule from native reminder notification', (
    tester,
  ) async {
    final routes = FakeRouteIntentPlatform();

    await tester.pumpWidget(
      MomCozyFlutterApp(
        apiRuntime: _authenticatedRuntime(),
        routeIntentPlatform: routes,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('agent-hub-page')), findsOneWidget);

    routes.dispatchActiveRoute(
      const PendingNativeRoute(
        path: '/schedule',
        notifyJson: {'event': 'schedule_reminder', 'taskId': 'task-001'},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('route-page-/schedule')), findsOneWidget);
    expect(find.byType(MomCozyBottomNavigation), findsOneWidget);

    await routes.dispose();
  });

  testWidgets('route shell records route view telemetry', (tester) async {
    final sink = MemoryMomCozyTelemetrySink();
    final runtime = _authenticatedRuntime(
      userId: 'route-user',
      babyId: 'route-baby',
      observability: MomCozyObservability(sink: sink),
    );

    await tester.pumpWidget(MomCozyFlutterApp(apiRuntime: runtime));
    await tester.pumpAndSettle();
    await tester.tap(find.text('计划').last);
    await tester.pumpAndSettle();

    final routeEvents = sink.events
        .where((event) => event.name == 'route.view')
        .map((event) => event.attributes['route'])
        .toList(growable: false);

    expect(routeEvents, containsAll(['/', '/schedule']));
    expect(sink.events.toString(), isNot(contains('route-user')));
  });

  testWidgets('runtime controller updates Agent Hub session context', (
    tester,
  ) async {
    final controller = MomCozyRuntimeController(
      _authenticatedRuntime(
        userId: 'initial-user',
        babyId: 'initial-baby',
        locale: 'zh-CN',
      ),
    );

    await tester.pumpWidget(MomCozyFlutterApp(runtimeController: controller));
    await tester.pumpAndSettle();

    var page = tester.widget<AgentHubPage>(find.byType(AgentHubPage));
    expect(page.requestBuilder('hello').locale, 'zh-CN');
    expect(page.requestBuilder('hello').threadId, isNull);

    controller.replaceSession(
      const MomCozySession(
        status: MomCozySessionStatus.authenticated,
        userId: 'secure-user',
        babyId: 'secure-baby',
        locale: 'en-US',
        accessToken: 'secure-access',
      ),
    );
    await tester.pump();

    page = tester.widget<AgentHubPage>(find.byType(AgentHubPage));
    expect(page.requestBuilder('hello').locale, 'en-US');
    expect(page.requestBuilder('hello').threadId, isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('route guard sends anonymous sessions to login', (tester) async {
    await tester.pumpWidget(
      MomCozyFlutterApp(
        apiRuntime: MomCozyApiRuntime(
          jsonTransport: FixtureApiJsonTransport(const {
            'status': 200,
            'data': {},
          }),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('auth-invite-login-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('auth-invite-code-field')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('agent-hub-page')), findsNothing);
  });

  testWidgets('login replaces runtime session and opens requested page', (
    tester,
  ) async {
    final store = MemoryMomCozySessionStore();
    final transport = FixtureApiJsonTransport(const {
      'access_token': 'access-login',
      'refresh_token': 'refresh-login',
      'token_type': 'bearer',
      'expires_in': 3600,
      'user': {'id': 'login-user', 'display_name': 'Login User'},
    });
    final controller = MomCozyRuntimeController(
      MomCozyApiRuntime(jsonTransport: transport),
    );
    final router = createMomCozyRouter(
      initialLocation: '/media-viewer',
      runtimeController: controller,
      sessionStore: store,
      authDeviceIdStore: const _FixedAuthDeviceIdStore('widget-device-001'),
    );

    await tester.pumpWidget(
      MomCozyFlutterApp(
        router: router,
        runtimeController: controller,
        sessionStore: store,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('auth-invite-code-field')),
      'MCZ-ROUTE-0001',
    );
    await tester.tap(find.byKey(const ValueKey('auth-invite-login-button')));
    await tester.pumpAndSettle();

    expect(controller.runtime.session.isAuthenticated, isTrue);
    expect(controller.runtime.userId, 'login-user');
    expect((await store.readSession())?.accessToken, 'access-login');
    expect(transport.lastPath, '/v1/auth/invite-login');
    expect(transport.lastBody?['invite_code'], 'MCZ-ROUTE-0001');
    expect(transport.lastBody?['device_id'], 'widget-device-001');
    expect(
      find.byKey(const ValueKey('route-page-/media-viewer')),
      findsOneWidget,
    );

    router.dispose();
    controller.dispose();
  });
}

class _FixedAuthDeviceIdStore implements MomCozyAuthDeviceIdStore {
  const _FixedAuthDeviceIdStore(this.deviceId);

  final String deviceId;

  @override
  Future<String> readOrCreateDeviceId() async => deviceId;
}

class _ControllableAgentStreamClient implements AgentStreamClient {
  final requests = <AgentStreamRequest>[];
  final _controllers = <StreamController<AgentStreamEvent>>[];
  var cancelCount = 0;

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

  void emit(int runIndex, AgentStreamEvent event) {
    _controllers[runIndex].add(event);
  }

  Future<void> dispose() async {
    for (final controller in _controllers) {
      await controller.close();
    }
  }
}

class _WidgetFakeVoicePlaybackPlayer implements AgentVoicePlaybackPlayer {
  Completer<void>? _active;

  @override
  Future<void> playText(String text) {
    _active = Completer<void>();
    return _active!.future;
  }

  @override
  Future<void> stop() async {
    complete();
  }

  void complete() {
    final active = _active;
    if (active != null && !active.isCompleted) {
      active.complete();
    }
  }
}

AgentStreamEvent _agentEvent({
  required String id,
  required String type,
  required int sequence,
  String? text,
}) {
  final payload = <String, Object?>{};
  if (text != null) {
    payload['text'] = text;
  }
  if (type == 'run.completed') {
    payload['status'] = 'completed';
  }

  return AgentStreamEvent({
    'event_id': id,
    'thread_id': 'thread-keep-alive',
    'run_id': 'run-keep-alive',
    'message_id': 'msg-keep-alive',
    'sequence': sequence,
    'type': type,
    'payload': payload,
  });
}

MomCozyApiRuntime _authenticatedRuntime({
  String userId = 'demo-user',
  String babyId = 'demo-baby',
  String locale = 'zh-CN',
  MomCozyObservability? observability,
}) {
  return MomCozyApiRuntime.fromSession(
    MomCozySession(
      status: MomCozySessionStatus.authenticated,
      userId: userId,
      babyId: babyId,
      locale: locale,
      accessToken: 'test-access-token',
      refreshToken: 'test-refresh-token',
    ),
    jsonTransport: FixtureApiJsonTransport(const {'status': 200, 'data': {}}),
    observability: observability,
  );
}
