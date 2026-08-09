import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_auth_api.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_auth_device_id.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_last_invite_code.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/core/observability/momcozy_observability.dart';
import 'package:momcozy_flutter_app/features/auth/presentation/auth_page.dart';

import '../../support/fixture_api_transport.dart';

void main() {
  testWidgets('auth page exposes only invite login entry', (tester) async {
    final transport = FixtureApiJsonTransport(_tokenResponse());
    final runtime = MomCozyApiRuntime(
      jsonTransport: transport,
      userId: 'demo-user',
      babyId: 'demo-baby',
      locale: 'zh-CN',
    );
    final controller = MomCozyRuntimeController(runtime);
    final store = MemoryMomCozySessionStore();
    final router = _authRouter(
      controller: controller,
      store: store,
      deviceId: 'flutter-device-001',
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    expect(
      find.byKey(const ValueKey('auth-invite-login-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('auth-invite-code-field')),
      findsOneWidget,
    );
    expect(find.text('邀请码登录'), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-email-field')), findsNothing);
    expect(find.byKey(const ValueKey('auth-password-field')), findsNothing);
    expect(find.byKey(const ValueKey('auth-display-name-field')), findsNothing);
    expect(find.byKey(const ValueKey('auth-submit-button')), findsNothing);
    expect(find.text('注册'), findsNothing);
    expect(find.text('登录'), findsNothing);

    controller.dispose();
    router.dispose();
  });

  testWidgets('invite login requires a typed invite code before posting', (
    tester,
  ) async {
    final transport = FixtureApiJsonTransport(_tokenResponse());
    final runtime = MomCozyApiRuntime(
      jsonTransport: transport,
      userId: 'demo-user',
      babyId: 'demo-baby',
      locale: 'zh-CN',
    );
    final controller = MomCozyRuntimeController(runtime);
    final store = MemoryMomCozySessionStore();
    final router = _authRouter(
      controller: controller,
      store: store,
      deviceId: 'flutter-device-001',
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    await tester.tap(find.byKey(const ValueKey('auth-invite-login-button')));
    await tester.pump();

    final errorText = tester.widget<Text>(
      find.byKey(const ValueKey('auth-error-text')),
    );
    expect(errorText.data, '请输入邀请码');
    expect(transport.lastPath, isNull);
    expect(await store.readSession(), isNull);

    controller.dispose();
    router.dispose();
  });

  testWidgets('auth page restores the last invite code as an editable value', (
    tester,
  ) async {
    final runtime = MomCozyApiRuntime(
      jsonTransport: FixtureApiJsonTransport(_tokenResponse()),
      userId: 'demo-user',
      babyId: 'demo-baby',
      locale: 'zh-CN',
    );
    final controller = MomCozyRuntimeController(runtime);
    final store = MemoryMomCozySessionStore();
    final lastInviteCodeStore = _MemoryLastInviteCodeStore(' MCZ-LAST-0001 ');
    final router = _authRouter(
      controller: controller,
      store: store,
      deviceId: 'flutter-device-001',
      lastInviteCodeStore: lastInviteCodeStore,
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('auth-invite-code-field')),
    );
    expect(field.decoration?.hintText, '请输入邀请码');
    expect(
      field.decoration?.floatingLabelBehavior,
      FloatingLabelBehavior.always,
    );
    expect(field.controller?.text, 'MCZ-LAST-0001');

    controller.dispose();
    router.dispose();
  });

  testWidgets('late invite restore does not overwrite user input', (
    tester,
  ) async {
    final runtime = MomCozyApiRuntime(
      jsonTransport: FixtureApiJsonTransport(_tokenResponse()),
      userId: 'demo-user',
      babyId: 'demo-baby',
      locale: 'zh-CN',
    );
    final controller = MomCozyRuntimeController(runtime);
    final store = MemoryMomCozySessionStore();
    final lastInviteCodeStore = _DeferredLastInviteCodeStore();
    final router = _authRouter(
      controller: controller,
      store: store,
      deviceId: 'flutter-device-001',
      lastInviteCodeStore: lastInviteCodeStore,
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.enterText(
      find.byKey(const ValueKey('auth-invite-code-field')),
      'MCZ-NEW-0002',
    );
    lastInviteCodeStore.complete('MCZ-LAST-0001');
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('auth-invite-code-field')),
    );
    expect(field.controller?.text, 'MCZ-NEW-0002');

    controller.dispose();
    router.dispose();
  });

  testWidgets('invite login writes the issued session and redirects', (
    tester,
  ) async {
    final transport = FixtureApiJsonTransport(_tokenResponse());
    final runtime = MomCozyApiRuntime(
      jsonTransport: transport,
      userId: 'demo-user',
      babyId: 'demo-baby',
      locale: 'zh-CN',
    );
    final controller = MomCozyRuntimeController(runtime);
    final store = MemoryMomCozySessionStore();
    final lastInviteCodeStore = _MemoryLastInviteCodeStore();
    final router = _authRouter(
      controller: controller,
      store: store,
      deviceId: 'flutter-device-001',
      lastInviteCodeStore: lastInviteCodeStore,
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    await tester.enterText(
      find.byKey(const ValueKey('auth-invite-code-field')),
      ' mcz-abcd-2345 ',
    );
    await tester.tap(find.byKey(const ValueKey('auth-invite-login-button')));
    await tester.pumpAndSettle();

    final session = await store.readSession();
    expect(transport.lastPath, authInviteLoginEndpoint);
    expect(transport.lastBody, {
      'invite_code': 'mcz-abcd-2345',
      'device_id': 'flutter-device-001',
    });
    expect(session?.status, MomCozySessionStatus.authenticated);
    expect(session?.userId, 'invite-user-001');
    expect(session?.refreshToken, 'refresh-token-001');
    expect(controller.runtime.session.userId, 'invite-user-001');
    expect(lastInviteCodeStore.value, 'mcz-abcd-2345');
    expect(find.text('home'), findsOneWidget);

    controller.dispose();
    router.dispose();
  });

  testWidgets(
    'release-reset account with blank display name still authenticates',
    (tester) async {
      final response = _tokenResponse()
        ..['user'] = {'id': 'release-reset-user-001', 'display_name': ''};
      final transport = FixtureApiJsonTransport(response);
      final runtime = MomCozyApiRuntime(
        jsonTransport: transport,
        userId: 'demo-user',
        babyId: 'demo-baby',
        locale: 'zh-CN',
      );
      final controller = MomCozyRuntimeController(runtime);
      final store = MemoryMomCozySessionStore();
      final router = _authRouter(
        controller: controller,
        store: store,
        deviceId: 'flutter-device-001',
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.enterText(
        find.byKey(const ValueKey('auth-invite-code-field')),
        'MCZ-RESET-0001',
      );
      await tester.tap(find.byKey(const ValueKey('auth-invite-login-button')));
      await tester.pumpAndSettle();

      final session = await store.readSession();
      expect(session?.isAuthenticated, isTrue);
      expect(session?.userId, 'release-reset-user-001');
      expect(session?.accessToken, 'access-token-001');
      expect(find.text('home'), findsOneWidget);
      expect(find.byKey(const ValueKey('auth-error-text')), findsNothing);

      controller.dispose();
      router.dispose();
    },
  );

  testWidgets(
    'successful invite auth reports a local session persistence failure',
    (tester) async {
      final transport = FixtureApiJsonTransport(_tokenResponse());
      final telemetry = MemoryMomCozyTelemetrySink();
      final runtime = MomCozyApiRuntime(
        jsonTransport: transport,
        userId: 'demo-user',
        babyId: 'demo-baby',
        locale: 'zh-CN',
        observability: MomCozyObservability(sink: telemetry),
      );
      final controller = MomCozyRuntimeController(runtime);
      final store = _FailingSessionStore();
      final lastInviteCodeStore = _MemoryLastInviteCodeStore('MCZ-LAST-0001');
      final router = _authRouter(
        controller: controller,
        store: store,
        deviceId: 'flutter-device-001',
        lastInviteCodeStore: lastInviteCodeStore,
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.enterText(
        find.byKey(const ValueKey('auth-invite-code-field')),
        'MCZ-ABCD-2345',
      );
      await tester.tap(find.byKey(const ValueKey('auth-invite-login-button')));
      await tester.pumpAndSettle();

      expect(transport.lastPath, authInviteLoginEndpoint);
      expect(find.text('账号认证已通过，但无法保存本机登录状态。请重启 App 后重试。'), findsOneWidget);
      expect(controller.currentSession.isAuthenticated, isFalse);
      expect(lastInviteCodeStore.value, 'MCZ-LAST-0001');
      final event = telemetry.events.singleWhere(
        (event) => event.name == 'app.non_fatal',
      );
      expect(event.attributes['context'], {
        'feature': 'auth',
        'operation': 'persist_session',
      });
      expect(event.attributes.toString(), isNot(contains('access-token-001')));
      expect(event.attributes.toString(), isNot(contains('refresh-token-001')));

      controller.dispose();
      router.dispose();
    },
  );

  testWidgets('invite login shows bound-device message on permission denied', (
    tester,
  ) async {
    final transport = FixtureApiJsonTransport(
      _httpError(
        403,
        code: 'permission_denied',
        message: 'Invite code is already bound to another device.',
      ),
    );
    final runtime = MomCozyApiRuntime(
      jsonTransport: transport,
      userId: 'demo-user',
      babyId: 'demo-baby',
      locale: 'zh-CN',
    );
    final controller = MomCozyRuntimeController(runtime);
    final store = MemoryMomCozySessionStore();
    final lastInviteCodeStore = _MemoryLastInviteCodeStore('MCZ-LAST-0001');
    final router = _authRouter(
      controller: controller,
      store: store,
      deviceId: 'flutter-device-002',
      lastInviteCodeStore: lastInviteCodeStore,
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    await tester.enterText(
      find.byKey(const ValueKey('auth-invite-code-field')),
      'MCZ-ABCD-2345',
    );
    await tester.tap(find.byKey(const ValueKey('auth-invite-login-button')));
    await tester.pumpAndSettle();

    expect(transport.lastPath, authInviteLoginEndpoint);
    expect(find.byKey(const ValueKey('auth-error-text')), findsOneWidget);
    expect(find.text('邀请码已在其他设备使用过'), findsOneWidget);
    expect(find.text('home'), findsNothing);
    expect(await store.readSession(), isNull);
    expect(lastInviteCodeStore.value, 'MCZ-LAST-0001');

    controller.dispose();
    router.dispose();
  });
}

GoRouter _authRouter({
  required MomCozyRuntimeController controller,
  required MomCozySessionStore store,
  required String deviceId,
  MomCozyLastInviteCodeStore? lastInviteCodeStore,
}) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: controller,
    redirect: (context, state) {
      if (controller.currentSession.isAuthenticated &&
          state.uri.path == '/login') {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => MomCozyAuthPage(
          runtimeController: controller,
          sessionStore: store,
          authDeviceIdStore: _FixedAuthDeviceIdStore(deviceId),
          lastInviteCodeStore:
              lastInviteCodeStore ?? _MemoryLastInviteCodeStore(),
        ),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: Text('home')),
      ),
    ],
  );
}

Map<String, Object?> _tokenResponse() {
  return {
    'access_token': 'access-token-001',
    'refresh_token': 'refresh-token-001',
    'expires_in': 3600,
    'token_type': 'bearer',
    'user': {'id': 'invite-user-001', 'display_name': 'Invite User'},
  };
}

Map<String, Object?> _httpError(
  int statusCode, {
  required String code,
  required String message,
}) {
  return {
    'http_status': statusCode,
    'status_text': 'HTTP $statusCode',
    'body': {
      'error': {
        'code': code,
        'message': message,
        'request_id': 'req-test',
        'details': <String, Object?>{},
      },
    },
  };
}

class _FixedAuthDeviceIdStore implements MomCozyAuthDeviceIdStore {
  const _FixedAuthDeviceIdStore(this.deviceId);

  final String deviceId;

  @override
  Future<String> readOrCreateDeviceId() async => deviceId;
}

class _MemoryLastInviteCodeStore implements MomCozyLastInviteCodeStore {
  _MemoryLastInviteCodeStore([this.value]);

  String? value;

  @override
  Future<String?> readLastInviteCode() async => value;

  @override
  Future<void> writeLastInviteCode(String inviteCode) async {
    value = inviteCode;
  }
}

class _DeferredLastInviteCodeStore implements MomCozyLastInviteCodeStore {
  final _value = Completer<String?>();

  void complete(String? value) => _value.complete(value);

  @override
  Future<String?> readLastInviteCode() => _value.future;

  @override
  Future<void> writeLastInviteCode(String inviteCode) async {}
}

class _FailingSessionStore implements MomCozySessionStore {
  @override
  Future<void> clearSession() async {}

  @override
  Future<MomCozySession?> readSession() async => null;

  @override
  Future<void> writeSession(MomCozySession session) async {
    throw StateError('simulated secure storage failure');
  }
}
