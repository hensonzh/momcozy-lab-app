import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_auth_api.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_auth_device_id.dart';
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
    final router = _authRouter(
      controller: controller,
      store: store,
      deviceId: 'flutter-device-001',
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    await tester.tap(find.byKey(const ValueKey('auth-invite-login-button')));
    await tester.pumpAndSettle();

    final session = await store.readSession();
    expect(transport.lastPath, authInviteLoginEndpoint);
    expect(transport.lastBody, {
      'invite_code': 'MOMCOZY-BETA',
      'device_id': 'flutter-device-001',
    });
    expect(session?.status, MomCozySessionStatus.authenticated);
    expect(session?.userId, 'invite-user-001');
    expect(session?.refreshToken, 'refresh-token-001');
    expect(controller.runtime.session.userId, 'invite-user-001');
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
    final router = _authRouter(
      controller: controller,
      store: store,
      deviceId: 'flutter-device-002',
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    await tester.tap(find.byKey(const ValueKey('auth-invite-login-button')));
    await tester.pumpAndSettle();

    expect(transport.lastPath, authInviteLoginEndpoint);
    expect(find.byKey(const ValueKey('auth-error-text')), findsOneWidget);
    expect(find.text('邀请码已在其他设备使用过'), findsOneWidget);
    expect(find.text('home'), findsNothing);
    expect(await store.readSession(), isNull);

    controller.dispose();
    router.dispose();
  });
}

GoRouter _authRouter({
  required MomCozyRuntimeController controller,
  required MomCozySessionStore store,
  required String deviceId,
}) {
  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => MomCozyAuthPage(
          runtimeController: controller,
          sessionStore: store,
          inviteCode: 'MOMCOZY-BETA',
          authDeviceIdStore: _FixedAuthDeviceIdStore(deviceId),
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
