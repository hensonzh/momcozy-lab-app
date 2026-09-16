import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/core/config/momcozy_app_capabilities.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_voice.dart';
import 'package:momcozy_flutter_app/features/auth/presentation/auth_page.dart';
import 'package:momcozy_flutter_app/features/onboarding/data/onboarding_api_repository.dart';
import 'package:momcozy_flutter_app/features/records/data/records_api_repository.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_home_page.dart';
import 'package:momcozy_flutter_app/modules/mom/presentation/mother_home_page.dart';
import 'package:momcozy_flutter_app/modules/schedule/presentation/schedule_page.dart';
import 'package:momcozy_flutter_app/native/p0_platform_interfaces.dart';

import '../../support/fixture_api_transport.dart';

void main() {
  testWidgets('default app startup bypasses the unsupported onboarding gate', (
    tester,
  ) async {
    final fixture = _fixture();

    await tester.pumpWidget(
      MomCozyFlutterApp(
        runtimeController: fixture.controller,
        sessionStore: MemoryMomCozySessionStore(fixture.session),
        routeIntentPlatform: fixture.routeIntents,
        agentHubBuilder: _agentHubBuilder,
      ),
    );
    await tester.pumpAndSettle();

    expect(fixture.transport.getPaths, isNot(contains(onboardingMeEndpoint)));
    expect(find.byType(MotherHomePage), findsOneWidget);
    expect(find.byKey(const ValueKey('bottom-nav-me')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    fixture.dispose();
  });

  testWidgets('unsupported extended Product routes render an explicit gate', (
    tester,
  ) async {
    final fixture = _fixture();
    const capabilities = MomCozyAppCapabilities();
    final router = createMomCozyRouter(
      initialLocation: '/more',
      runtimeController: fixture.controller,
      capabilities: capabilities,
      agentHubBuilder: _agentHubBuilder,
    );

    await tester.pumpWidget(
      MomCozyFlutterApp(
        router: router,
        runtimeController: fixture.controller,
        sessionStore: MemoryMomCozySessionStore(fixture.session),
        routeIntentPlatform: fixture.routeIntents,
        capabilities: capabilities,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('route-page-/more')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    fixture.dispose();
  });

  testWidgets('an explicit capability keeps the onboarding route available', (
    tester,
  ) async {
    final fixture = _fixture();

    await tester.pumpWidget(
      MomCozyFlutterApp(
        runtimeController: fixture.controller,
        sessionStore: MemoryMomCozySessionStore(fixture.session),
        routeIntentPlatform: fixture.routeIntents,
        agentHubBuilder: _agentHubBuilder,
        capabilities: const MomCozyAppCapabilities(onboardingGateEnabled: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(fixture.transport.getPaths, contains(onboardingMeEndpoint));
    expect(
      find.byKey(const ValueKey('onboarding-display-name')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('bottom-nav-me')), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    fixture.dispose();
  });

  for (final initialLocation in const [
    '/onboarding',
    '/avatar/review',
    '/avatar/create?from=/me',
  ]) {
    testWidgets(
      'disabled onboarding sends $initialLocation safely home after login',
      (tester) async {
        const anonymous = MomCozySession(
          status: MomCozySessionStatus.anonymous,
          userId: 'anonymous-capability-user',
          babyId: '',
          locale: 'en-US',
        );
        final fixture = _fixture(session: anonymous);
        final router = createMomCozyRouter(
          initialLocation: initialLocation,
          runtimeController: fixture.controller,
          agentHubBuilder: _agentHubBuilder,
        );

        await tester.pumpWidget(
          MomCozyFlutterApp(
            router: router,
            runtimeController: fixture.controller,
            sessionStore: MemoryMomCozySessionStore(anonymous),
            routeIntentPlatform: fixture.routeIntents,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byKey(const ValueKey('auth-email-field')), findsOneWidget);
        expect(router.routeInformationProvider.value.uri.path, '/login');

        fixture.controller.replaceRuntime(
          _runtime(
            session: _authenticatedSession,
            transport: fixture.transport,
          ),
        );
        expect(fixture.controller.currentSession.isAuthenticated, isTrue);
        router.go('/login');
        await tester.pumpAndSettle();

        expect(router.routeInformationProvider.value.uri.path, '/me');
        expect(find.byType(MotherHomePage), findsOneWidget);
        expect(find.byType(MomCozyAuthPage), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
        router.dispose();
        fixture.dispose();
      },
    );
  }

  for (final initialLocation in const ['/me', '/baby', '/schedule']) {
    testWidgets(
      'default $initialLocation requests no missing Product resource path',
      (tester) async {
        final fixture = _fixture();
        final router = createMomCozyRouter(
          initialLocation: initialLocation,
          runtimeController: fixture.controller,
          agentHubBuilder: _agentHubBuilder,
        );

        await tester.pumpWidget(
          MomCozyFlutterApp(
            router: router,
            runtimeController: fixture.controller,
            sessionStore: MemoryMomCozySessionStore(fixture.session),
            routeIntentPlatform: fixture.routeIntents,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          fixture.transport.getPaths.toSet().intersection(
            _missingProductResourcePaths,
          ),
          isEmpty,
        );
        expect(
          initialLocation == '/me'
              ? find.byType(MotherHomePage)
              : initialLocation == '/baby'
              ? find.byType(BabyHomePage)
              : find.byType(SchedulePage),
          findsOneWidget,
        );

        await tester.pumpWidget(const SizedBox.shrink());
        router.dispose();
        fixture.dispose();
      },
    );
  }
}

Widget _agentHubBuilder(
  BuildContext context,
  Uri? uri,
  Object? extra,
  AgentVoicePlaybackCoordinator voicePlaybackCoordinator,
) {
  return const SizedBox(key: ValueKey('test-agent-hub'));
}

const _authenticatedSession = MomCozySession(
  status: MomCozySessionStatus.authenticated,
  userId: 'capability-user',
  babyId: 'capability-baby',
  locale: 'en-US',
  accessToken: 'access',
);

const _missingProductResourcePaths = <String>{
  '/v1/profile/care-overview',
  feedingSummaryEndpoint,
  waterRecordsEndpoint,
  waterTrendsEndpoint,
  vitalRecordsEndpoint,
  sleepRecordsEndpoint,
  diaperRecordsEndpoint,
};

_CapabilityFixture _fixture({MomCozySession session = _authenticatedSession}) {
  final transport = FixtureApiJsonTransportByPath(const {
    onboardingMeEndpoint: {
      'status': 'required',
      'current_step': 'profile',
      'profile_confirmed': false,
    },
  });
  return _CapabilityFixture(
    session: session,
    transport: transport,
    controller: _StaticRuntimeController(
      _runtime(session: session, transport: transport),
    ),
  );
}

MomCozyApiRuntime _runtime({
  required MomCozySession session,
  required FixtureApiJsonTransportByPath transport,
}) {
  return MomCozyApiRuntime(
    jsonTransport: transport,
    multipartTransport: FixtureApiMultipartTransport(const {}),
    session: session,
    supportsSessionAutoRefresh: true,
  );
}

class _CapabilityFixture {
  _CapabilityFixture({
    required this.session,
    required this.transport,
    required this.controller,
  });

  final MomCozySession session;
  final FixtureApiJsonTransportByPath transport;
  final _StaticRuntimeController controller;
  final FakeRouteIntentPlatform routeIntents = FakeRouteIntentPlatform();

  void dispose() {
    controller.dispose();
    routeIntents.dispose();
  }
}

class _StaticRuntimeController extends MomCozyRuntimeController {
  _StaticRuntimeController(super.runtime);

  @override
  void enableSessionAutoRefresh(MomCozySessionStore store) {}
}
