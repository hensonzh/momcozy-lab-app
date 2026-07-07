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
    final router = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => MomCozyAuthPage(
            runtimeController: controller,
            sessionStore: store,
            inviteCode: 'MOMCOZY-BETA',
            authDeviceIdStore: const _FixedAuthDeviceIdStore(
              'flutter-device-001',
            ),
          ),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('home')),
        ),
      ],
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

class _FixedAuthDeviceIdStore implements MomCozyAuthDeviceIdStore {
  const _FixedAuthDeviceIdStore(this.deviceId);

  final String deviceId;

  @override
  Future<String> readOrCreateDeviceId() async => deviceId;
}
