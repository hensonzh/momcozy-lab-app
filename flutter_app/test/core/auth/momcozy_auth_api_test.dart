import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_auth_api.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/core/network/api_envelope.dart';
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

  group('AuthenticatedApiJsonTransport', () {
    test('refreshes on 401 and retries the original request once', () async {
      var current = const MomCozySession(
        status: MomCozySessionStatus.authenticated,
        userId: 'old-user',
        babyId: 'baby-001',
        locale: 'zh-CN',
        accessToken: 'old-access',
        refreshToken: 'old-refresh',
      );
      final store = MemoryMomCozySessionStore(current);
      final refreshTransport = FixtureApiJsonTransport(_tokenResponse());
      final businessTransport = _SequenceTokenTransport([
        _httpError(401, code: 'authentication_required'),
        {
          'status': 200,
          'data': {'ok': true},
        },
      ]);
      final transport = AuthenticatedApiJsonTransport(
        transportFactory: businessTransport.forToken,
        sessionProvider: () => current,
        refreshCoordinator: MomCozySessionRefreshCoordinator(
          authRepository: MomCozyAuthApiRepository(transport: refreshTransport),
          store: store,
        ),
        onSessionChanged: (session) async {
          current = session;
        },
      );

      final response = await transport.getJson('/v1/profile/me');

      expect(response['status'], 200);
      expect(refreshTransport.lastPath, authRefreshEndpoint);
      expect(businessTransport.paths, ['/v1/profile/me', '/v1/profile/me']);
      expect(businessTransport.tokens, ['old-access', 'access-token-001']);
      expect(current.accessToken, 'access-token-001');
      expect((await store.readSession())?.refreshToken, 'refresh-token-001');
    });

    test(
      'shares one refresh request across concurrent 401 responses',
      () async {
        var current = const MomCozySession(
          status: MomCozySessionStatus.authenticated,
          userId: 'old-user',
          babyId: 'baby-001',
          locale: 'en-US',
          accessToken: 'old-access',
          refreshToken: 'old-refresh',
        );
        final store = MemoryMomCozySessionStore(current);
        final refreshTransport = _DeferredRefreshTransport(_tokenResponse());
        final businessTransport = _PerPathTokenTransport({
          '/v1/profile/me': [
            _httpError(401, code: 'authentication_required'),
            {
              'status': 200,
              'data': {'profile': true},
            },
          ],
          '/v1/plans/tasks': [
            _httpError(401, code: 'authentication_required'),
            {
              'status': 200,
              'data': {'tasks': []},
            },
          ],
        });
        final transport = AuthenticatedApiJsonTransport(
          transportFactory: businessTransport.forToken,
          sessionProvider: () => current,
          refreshCoordinator: MomCozySessionRefreshCoordinator(
            authRepository: MomCozyAuthApiRepository(
              transport: refreshTransport,
            ),
            store: store,
          ),
          onSessionChanged: (session) async {
            current = session;
          },
        );

        final first = transport.getJson('/v1/profile/me');
        final second = transport.getJson('/v1/plans/tasks');
        await Future<void>.delayed(Duration.zero);
        expect(refreshTransport.refreshCallCount, 1);
        refreshTransport.complete();
        final responses = await Future.wait([first, second]);

        expect(responses.first['status'], 200);
        expect(responses.last['status'], 200);
        expect(refreshTransport.refreshCallCount, 1);
        expect(businessTransport.tokens, [
          'old-access',
          'old-access',
          'access-token-001',
          'access-token-001',
        ]);
      },
    );

    test('does not refresh non-auth HTTP failures', () async {
      var current = const MomCozySession(
        status: MomCozySessionStatus.authenticated,
        userId: 'user-001',
        babyId: 'baby-001',
        locale: 'zh-CN',
        accessToken: 'old-access',
        refreshToken: 'old-refresh',
      );
      final refreshTransport = FixtureApiJsonTransport(_tokenResponse());
      final businessTransport = _SequenceTokenTransport([
        _httpError(500, code: 'server_error'),
      ]);
      final transport = AuthenticatedApiJsonTransport(
        transportFactory: businessTransport.forToken,
        sessionProvider: () => current,
        refreshCoordinator: MomCozySessionRefreshCoordinator(
          authRepository: MomCozyAuthApiRepository(transport: refreshTransport),
          store: MemoryMomCozySessionStore(current),
        ),
        onSessionChanged: (session) async {
          current = session;
        },
      );

      await expectLater(
        transport.getJson('/v1/profile/me'),
        throwsA(
          isA<ApiHttpException>().having(
            (error) => error.statusCode,
            'statusCode',
            500,
          ),
        ),
      );

      expect(refreshTransport.lastPath, isNull);
      expect(current.accessToken, 'old-access');
    });

    test(
      'refreshes multipart uploads and retries with the new token',
      () async {
        var current = const MomCozySession(
          status: MomCozySessionStatus.authenticated,
          userId: 'old-user',
          babyId: 'baby-001',
          locale: 'zh-CN',
          accessToken: 'old-access',
          refreshToken: 'old-refresh',
        );
        final store = MemoryMomCozySessionStore(current);
        final refreshTransport = FixtureApiJsonTransport(_tokenResponse());
        final uploadTransport = _SequenceMultipartTokenTransport([
          _httpError(401, code: 'authentication_required'),
          {'status': 200, 'file_id': 'file-001'},
        ]);
        final transport = AuthenticatedApiMultipartTransport(
          transportFactory: uploadTransport.forToken,
          sessionProvider: () => current,
          refreshCoordinator: MomCozySessionRefreshCoordinator(
            authRepository: MomCozyAuthApiRepository(
              transport: refreshTransport,
            ),
            store: store,
          ),
          onSessionChanged: (session) async {
            current = session;
          },
        );

        final response = await transport.uploadMultipart(
          '/v1/files/upload',
          fields: {'owner_type': 'user'},
          file: const ApiUploadFile(
            name: 'photo.png',
            mimeType: 'image/png',
            sizeBytes: 3,
            bytes: [1, 2, 3],
          ),
        );

        expect(response['file_id'], 'file-001');
        expect(uploadTransport.paths, ['/v1/files/upload', '/v1/files/upload']);
        expect(uploadTransport.tokens, ['old-access', 'access-token-001']);
        expect(current.accessToken, 'access-token-001');
      },
    );
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

Map<String, Object?> _httpError(int statusCode, {String code = 'error'}) {
  return {
    'http_status': statusCode,
    'status_text': statusCode == 401 ? 'Unauthorized' : 'Error',
    'body': {
      'error': {
        'code': code,
        'message': code,
        'request_id': 'req-$statusCode-$code',
      },
    },
  };
}

class _SequenceTokenTransport {
  _SequenceTokenTransport(this.responses);

  final List<Map<String, Object?>> responses;
  final List<String> tokens = [];
  final List<String> paths = [];

  ApiJsonTransport forToken(String? token) {
    return _TokenTransport(
      token: token,
      onRequest: (path) {
        paths.add(path);
        tokens.add(token ?? '');
        final response = responses.removeAt(0);
        if (isHttpErrorBody(response)) {
          throw ApiHttpException.fromBody(response);
        }
        return response;
      },
    );
  }
}

class _PerPathTokenTransport {
  _PerPathTokenTransport(this.responsesByPath);

  final Map<String, List<Map<String, Object?>>> responsesByPath;
  final List<String> tokens = [];

  ApiJsonTransport forToken(String? token) {
    return _TokenTransport(
      token: token,
      onRequest: (path) {
        tokens.add(token ?? '');
        final responses = responsesByPath[path];
        if (responses == null || responses.isEmpty) {
          throw StateError('Missing response for $path');
        }
        final response = responses.removeAt(0);
        if (isHttpErrorBody(response)) {
          throw ApiHttpException.fromBody(response);
        }
        return response;
      },
    );
  }
}

class _TokenTransport implements ApiJsonTransport {
  _TokenTransport({required this.token, required this.onRequest});

  final String? token;
  final Map<String, Object?> Function(String path) onRequest;

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) async {
    return onRequest(path);
  }

  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    return onRequest(path);
  }
}

class _SequenceMultipartTokenTransport {
  _SequenceMultipartTokenTransport(this.responses);

  final List<Map<String, Object?>> responses;
  final List<String> tokens = [];
  final List<String> paths = [];

  ApiMultipartTransport forToken(String? token) {
    return _MultipartTokenTransport(
      token: token,
      onRequest: (path) {
        paths.add(path);
        tokens.add(token ?? '');
        final response = responses.removeAt(0);
        if (isHttpErrorBody(response)) {
          throw ApiHttpException.fromBody(response);
        }
        return response;
      },
    );
  }
}

class _MultipartTokenTransport implements ApiMultipartTransport {
  _MultipartTokenTransport({required this.token, required this.onRequest});

  final String? token;
  final Map<String, Object?> Function(String path) onRequest;

  @override
  Future<Map<String, Object?>> uploadMultipart(
    String path, {
    Map<String, Object?> fields = const {},
    Map<String, String> headers = const {},
    required ApiUploadFile file,
  }) async {
    return onRequest(path);
  }
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
    Map<String, String> headers = const {},
  }) async {
    expect(path, authRefreshEndpoint);
    expect(body, {'refresh_token': 'old-refresh'});
    refreshCallCount += 1;
    await _completer.future;
    return response;
  }
}
