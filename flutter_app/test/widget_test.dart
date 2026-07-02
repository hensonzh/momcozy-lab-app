import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/core/observability/momcozy_observability.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_page.dart';
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
    expect(find.text('智能体'), findsWidgets);

    await tester.enterText(
      find.byKey(const ValueKey('agent-composer-input')),
      'Review my pattern',
    );
    await tester.pump();

    final sendButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('agent-send-button')),
    );
    expect(sendButton.onPressed, isNotNull);

    await tester.tap(find.text('设备').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('route-page-/device')), findsOneWidget);
    expect(find.text('设备'), findsWidgets);
  });

  testWidgets('route shell hides bottom navigation on focused flows', (
    tester,
  ) async {
    final router = createMomCozyRouter(initialLocation: '/pump');

    await tester.pumpWidget(MomCozyFlutterApp(router: router));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('route-page-/pump')), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('route shell renders recoverable not found route', (
    tester,
  ) async {
    final router = createMomCozyRouter(initialLocation: '/unknown-old-page');

    await tester.pumpWidget(MomCozyFlutterApp(router: router));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('route-page-/404')), findsOneWidget);
    expect(find.text('页面未找到'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
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
    expect(find.byType(NavigationBar), findsNothing);
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
    expect(find.byType(NavigationBar), findsNothing);

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
    expect(find.byType(NavigationBar), findsOneWidget);

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
          jsonTransport: FixtureApiJsonTransport(
            const {'status': 200, 'data': {}},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('auth-email-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('agent-hub-page')), findsNothing);
  });

  testWidgets('login replaces runtime session and opens requested page', (
    tester,
  ) async {
    final store = MemoryMomCozySessionStore();
    final controller = MomCozyRuntimeController(
      MomCozyApiRuntime(
        jsonTransport: FixtureApiJsonTransport(const {
          'access_token': 'access-login',
          'refresh_token': 'refresh-login',
          'token_type': 'bearer',
          'expires_in': 3600,
          'user': {'id': 'login-user', 'display_name': 'Login User'},
        }),
      ),
    );
    final router = createMomCozyRouter(
      initialLocation: '/media-viewer',
      runtimeController: controller,
      sessionStore: store,
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
      find.byKey(const ValueKey('auth-email-field')),
      'mom@example.test',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-password-field')),
      'secret123',
    );
    await tester.tap(find.byKey(const ValueKey('auth-submit-button')));
    await tester.pumpAndSettle();

    expect(controller.runtime.session.isAuthenticated, isTrue);
    expect(controller.runtime.userId, 'login-user');
    expect((await store.readSession())?.accessToken, 'access-login');
    expect(
      find.byKey(const ValueKey('route-page-/media-viewer')),
      findsOneWidget,
    );

    router.dispose();
    controller.dispose();
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
