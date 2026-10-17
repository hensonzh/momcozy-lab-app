import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/features/onboarding/data/onboarding_api_repository.dart';
import 'package:momcozy_flutter_app/features/onboarding/presentation/onboarding_controller.dart';

import '../../support/fixture_api_transport.dart';

void main() {
  testWidgets('an owned legacy deep link resumes after the new role gate', (
    tester,
  ) async {
    final transport = FixtureApiJsonTransportByPath(
      const {
        chatFirstOnboardingEndpoint: {
          'status': 'required',
          'can_enter_app': false,
          'role': null,
          'profile_scope': 'none',
          'primary_infant_id': null,
        },
        '/v1/schedule': {
          'personal': <Object?>[],
          'server_time': '2026-10-15T08:00:00Z',
          'has_more': false,
        },
      },
      writeResponsesByPath: const {
        chatFirstOnboardingEndpoint: {
          'status': 'completed',
          'can_enter_app': true,
          'role': 'father',
          'profile_scope': 'chat_first',
          'primary_infant_id': null,
        },
      },
    );
    final runtime = MomCozyRuntimeController(
      MomCozyApiRuntime(
        jsonTransport: transport,
        timezoneProvider: () async => 'Asia/Shanghai',
        now: () => DateTime(2026, 10, 15),
        session: const MomCozySession(
          status: MomCozySessionStatus.authenticated,
          userId: 'deep-link-father',
          babyId: '',
          locale: 'zh-CN',
          accessToken: 'access',
        ),
      ),
    );
    final controller = OnboardingController(
      runtimeController: runtime,
      chatFirstMode: true,
    );
    await controller.load();
    final router = createMomCozyRouter(
      initialLocation: '/schedule',
      runtimeController: runtime,
      onboardingController: controller,
      chatFirstExperience: true,
      agentHubBuilder: (_, _, _) => const Text('聊天首页'),
    );
    await tester.pumpWidget(
      MomCozyFlutterApp(router: router, runtimeController: runtime),
    );
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/onboarding');
    expect(router.state.uri.queryParameters['from'], '/schedule');
    await tester.tap(find.byKey(const ValueKey('role-father')));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/schedule');
    expect(find.byKey(const ValueKey('section-back-chat')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('schedule-calendar-toggle')),
      findsOneWidget,
    );
    expect(transport.getPaths, contains('/v1/schedule'));
    await tester.tap(find.byKey(const ValueKey('section-back-chat')));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/');
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    controller.dispose();
    runtime.dispose();
  });

  testWidgets('new authenticated user enters role selection, then chat home', (
    tester,
  ) async {
    final transport = FixtureApiJsonTransportByPath(
      const {
        chatFirstOnboardingEndpoint: {
          'status': 'required',
          'can_enter_app': false,
          'role': null,
          'profile_scope': 'none',
          'primary_infant_id': null,
        },
      },
      writeResponsesByPath: const {
        chatFirstOnboardingEndpoint: {
          'status': 'completed',
          'can_enter_app': true,
          'role': 'father',
          'profile_scope': 'chat_first',
          'primary_infant_id': null,
        },
      },
    );
    final runtime = MomCozyRuntimeController(
      MomCozyApiRuntime(
        jsonTransport: transport,
        session: const MomCozySession(
          status: MomCozySessionStatus.authenticated,
          userId: 'new-father',
          babyId: '',
          locale: 'zh-CN',
          accessToken: 'access',
        ),
      ),
    );
    final controller = OnboardingController(
      runtimeController: runtime,
      chatFirstMode: true,
    );
    await controller.load();
    final router = createMomCozyRouter(
      runtimeController: runtime,
      onboardingController: controller,
      chatFirstExperience: true,
      agentHubBuilder: (_, _, _) => const Center(child: Text('聊天首页')),
    );
    await tester.pumpWidget(
      MomCozyFlutterApp(router: router, runtimeController: runtime),
    );
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/onboarding');
    expect(find.byKey(const ValueKey('role-father')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('role-father')));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/');
    expect(find.text('聊天首页'), findsOneWidget);
    expect(transport.lastBody, {'role': 'father'});
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    controller.dispose();
    runtime.dispose();
  });

  testWidgets('direct account deep link can return to secondary settings', (
    tester,
  ) async {
    final transport = FixtureApiJsonTransportByPath(const {
      chatFirstOnboardingEndpoint: {
        'status': 'completed',
        'can_enter_app': true,
        'role': 'father',
        'profile_scope': 'chat_first',
        'primary_infant_id': null,
      },
      '/v1/auth/me': {
        'email': 'father@example.test',
        'email_verified': true,
        'account_status': 'active',
        'auth_providers': ['email'],
      },
    });
    final runtime = MomCozyRuntimeController(
      MomCozyApiRuntime(
        jsonTransport: transport,
        session: const MomCozySession(
          status: MomCozySessionStatus.authenticated,
          userId: 'direct-account-user',
          babyId: '',
          locale: 'zh-CN',
          accessToken: 'access',
        ),
      ),
    );
    final controller = OnboardingController(
      runtimeController: runtime,
      chatFirstMode: true,
    );
    await controller.load();
    final router = createMomCozyRouter(
      initialLocation: '/account',
      runtimeController: runtime,
      onboardingController: controller,
      chatFirstExperience: true,
      agentHubBuilder: (_, _, _) => const Text('聊天首页'),
    );
    await tester.pumpWidget(
      MomCozyFlutterApp(router: router, runtimeController: runtime),
    );
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/account');
    expect(find.text('father@example.test'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('account-back')));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/more');
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    controller.dispose();
    runtime.dispose();
  });

  testWidgets('notification settings deep link can return to inbox', (
    tester,
  ) async {
    final transport = FixtureApiJsonTransportByPath(const {
      chatFirstOnboardingEndpoint: {
        'status': 'completed',
        'can_enter_app': true,
        'role': 'father',
        'profile_scope': 'chat_first',
        'primary_infant_id': null,
      },
    });
    final runtime = MomCozyRuntimeController(
      MomCozyApiRuntime(
        jsonTransport: transport,
        session: const MomCozySession(
          status: MomCozySessionStatus.authenticated,
          userId: 'notification-user',
          babyId: '',
          locale: 'zh-CN',
          accessToken: 'access',
        ),
      ),
    );
    final controller = OnboardingController(
      runtimeController: runtime,
      chatFirstMode: true,
    );
    await controller.load();
    final router = createMomCozyRouter(
      initialLocation: '/notifications/settings',
      runtimeController: runtime,
      onboardingController: controller,
      chatFirstExperience: true,
      agentHubBuilder: (_, _, _) => const Text('聊天首页'),
    );
    await tester.pumpWidget(
      MomCozyFlutterApp(router: router, runtimeController: runtime),
    );
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/notifications/settings');
    await tester.tap(find.byKey(const ValueKey('notification-settings-back')));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/notifications');
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    controller.dispose();
    runtime.dispose();
  });

  testWidgets('completed role ignores an onboarding self-return target', (
    tester,
  ) async {
    final transport = FixtureApiJsonTransportByPath(const {
      chatFirstOnboardingEndpoint: {
        'status': 'completed',
        'can_enter_app': true,
        'role': 'father',
        'profile_scope': 'chat_first',
        'primary_infant_id': null,
      },
    });
    final runtime = MomCozyRuntimeController(
      MomCozyApiRuntime(
        jsonTransport: transport,
        session: const MomCozySession(
          status: MomCozySessionStatus.authenticated,
          userId: 'safe-return-user',
          babyId: '',
          locale: 'zh-CN',
          accessToken: 'access',
        ),
      ),
    );
    final controller = OnboardingController(
      runtimeController: runtime,
      chatFirstMode: true,
    );
    await controller.load();
    final router = createMomCozyRouter(
      initialLocation: '/onboarding?from=%2Fonboarding',
      runtimeController: runtime,
      onboardingController: controller,
      chatFirstExperience: true,
      agentHubBuilder: (_, _, _) => const Text('聊天首页'),
    );
    await tester.pumpWidget(
      MomCozyFlutterApp(router: router, runtimeController: runtime),
    );
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/');
    expect(find.text('聊天首页'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    controller.dispose();
    runtime.dispose();
  });
}
