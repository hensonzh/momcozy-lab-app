import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_auth_api.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_auth_device_id.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_last_invite_code.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
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

  testWidgets('auth page shows the last invite code as an empty-field hint', (
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
    expect(field.decoration?.hintText, 'MCZ-LAST-0001');
    expect(
      field.decoration?.floatingLabelBehavior,
      FloatingLabelBehavior.always,
    );
    expect(field.controller?.text, isEmpty);

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
    'user': {'id': 'invite-user-001'},
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
