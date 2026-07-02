import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_auth_api.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';

import '../../support/fixture_api_transport.dart';

void main() {
  group('MomCozyAuthApiRepository', () {
    test('login posts production auth body and maps token response', () async {
      final transport = FixtureApiJsonTransport(_tokenResponse());
      final repository = MomCozyAuthApiRepository(transport: transport);

      final tokens = await repository.login(
        email: ' mom@example.test ',
        password: 'strong-password',
        deviceId: ' device-001 ',
      );

      expect(transport.lastPath, authLoginEndpoint);
      expect(transport.lastBody, {
        'email': 'mom@example.test',
        'password': 'strong-password',
        'device_id': 'device-001',
      });
      expect(tokens.accessToken, 'access-token-001');
      expect(tokens.refreshToken, 'refresh-token-001');
      expect(tokens.expiresIn, 3600);
      expect(tokens.user.id, 'user-001');
      expect(tokens.user.displayName, 'Test User');
    });

    test('signup sends optional fields only when present', () async {
      final transport = FixtureApiJsonTransport(_tokenResponse());
      final repository = MomCozyAuthApiRepository(transport: transport);

      await repository.signup(
        email: 'new@example.test',
        password: 'strong-password',
        displayName: ' New Mom ',
      );

      expect(transport.lastPath, authSignupEndpoint);
      expect(transport.lastBody, {
        'email': 'new@example.test',
        'password': 'strong-password',
        'display_name': 'New Mom',
      });
      expect(transport.lastBody, isNot(containsPair('device_id', anything)));
    });

    test('refresh sends refresh token in the body only', () async {
      final transport = FixtureApiJsonTransport(_tokenResponse());
      final repository = MomCozyAuthApiRepository(transport: transport);

      await repository.refresh(refreshToken: ' refresh-token-001 ');

      expect(transport.lastPath, authRefreshEndpoint);
      expect(transport.lastBody, {'refresh_token': 'refresh-token-001'});
      expect(transport.lastQuery, isNull);
    });

    test('logout uses the production logout endpoint', () async {
      final transport = FixtureApiJsonTransport({'status': 'ok'});
      final repository = MomCozyAuthApiRepository(transport: transport);

      await repository.logout();

      expect(transport.lastPath, authLogoutEndpoint);
      expect(transport.lastBody, isEmpty);
    });

    test('rejects malformed token responses', () async {
      final repository = MomCozyAuthApiRepository(
        transport: FixtureApiJsonTransport({'access_token': 'missing-fields'}),
      );

      await expectLater(
        repository.login(email: 'mom@example.test', password: 'password'),
        throwsA(isA<MomCozyAuthResponseFormatException>()),
      );
    });
  });

  group('MomCozySessionRefreshCoordinator', () {
    test('concurrent refresh calls share one backend request', () async {
      final transport = _DeferredRefreshTransport(_tokenResponse());
      final repository = MomCozyAuthApiRepository(transport: transport);
      final store = MemoryMomCozySessionStore();
      final coordinator = MomCozySessionRefreshCoordinator(
        authRepository: repository,
        store: store,
      );
      const current = MomCozySession(
        status: MomCozySessionStatus.authenticated,
        userId: 'old-user',
        babyId: 'baby-001',
        locale: 'en-US',
        accessToken: 'old-access',
        refreshToken: 'old-refresh',
      );

      final first = coordinator.refresh(current);
      final second = coordinator.refresh(current);
      expect(transport.refreshCallCount, 1);

      transport.complete();
      final sessions = await Future.wait([first, second]);

      expect(identical(sessions.first, sessions.last), isTrue);
      expect(sessions.first.userId, 'user-001');
      expect(sessions.first.babyId, 'baby-001');
      expect(sessions.first.locale, 'en-US');
      expect(sessions.first.accessToken, 'access-token-001');
      expect((await store.readSession())?.refreshToken, 'refresh-token-001');
    });

    test('missing refresh token expires the stored session', () async {
      final store = MemoryMomCozySessionStore();
      final coordinator = MomCozySessionRefreshCoordinator(
        authRepository: MomCozyAuthApiRepository(
          transport: FixtureApiJsonTransport(_tokenResponse()),
        ),
        store: store,
      );

      final expired = await coordinator.refresh(
        const MomCozySession(
          status: MomCozySessionStatus.authenticated,
          userId: 'user-001',
          babyId: 'baby-001',
          locale: 'zh-CN',
          accessToken: 'stale-access',
        ),
      );

      expect(expired.status, MomCozySessionStatus.expired);
      expect(expired.accessToken, isNull);
      expect(expired.refreshToken, isNull);
      expect((await store.readSession())?.status, MomCozySessionStatus.expired);
    });
  });
}

Map<String, Object?> _tokenResponse() {
  return {
    'access_token': 'access-token-001',
    'refresh_token': 'refresh-token-001',
    'expires_in': 3600,
    'token_type': 'bearer',
    'user': {'id': 'user-001', 'display_name': 'Test User'},
  };
}

class _DeferredRefreshTransport implements ApiJsonTransport {
  _DeferredRefreshTransport(this.response);

  final Map<String, Object?> response;
  final Completer<void> _completer = Completer<void>();
  int refreshCallCount = 0;

  void complete() {
    if (!_completer.isCompleted) _completer.complete();
  }

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> body = const {},
  }) async {
    expect(path, authRefreshEndpoint);
    expect(body, {'refresh_token': 'old-refresh'});
    refreshCallCount += 1;
    await _completer.future;
    return response;
  }
}
