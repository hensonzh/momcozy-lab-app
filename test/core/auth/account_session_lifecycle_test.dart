import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_auth_api.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import '../../support/fixture_api_transport.dart';

const session = MomCozySession(
  status: MomCozySessionStatus.authenticated,
  userId: 'mia',
  babyId: 'baby',
  locale: 'en-US',
  accessToken: 'old-access',
  refreshToken: 'old-refresh',
);

class _DelayedStore extends MemoryMomCozySessionStore {
  _DelayedStore() : super(session);
  final started = Completer<void>();
  final release = Completer<void>();
  @override
  Future<void> writeSession(MomCozySession next) async {
    if (!started.isCompleted) started.complete();
    await release.future;
    await super.writeSession(next);
  }
}

class _RestoreTransport implements ApiJsonTransport {
  _RestoreTransport({this.refreshStatus = 200});
  final int refreshStatus;
  int refreshes = 0;
  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) async => throw const ApiHttpException(
    statusCode: 401,
    statusText: 'Expired',
    body: null,
  );
  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    expect(path, '/v1/auth/refresh');
    refreshes++;
    if (refreshStatus != 200) {
      throw ApiHttpException(
        statusCode: refreshStatus,
        statusText: 'Rejected',
        body: null,
      );
    }
    return {
      'access_token': 'new-access',
      'refresh_token': 'new-refresh',
      'expires_in': 900,
      'user': {'id': 'mia'},
    };
  }
}

void main() {
  test(
    'restart restores and persists rotated tokens; revoked refresh expires session',
    () async {
      final store = MemoryMomCozySessionStore(session);
      final transport = _RestoreTransport();
      final restored = await MomCozySessionRestorer(
        authRepository: MomCozyAuthApiRepository(transport: transport),
        store: store,
      ).restore(session);
      expect(restored.accessToken, 'new-access');
      expect((await store.readSession())?.refreshToken, 'new-refresh');
      expect(transport.refreshes, 1);
      final revoked = await MomCozySessionRestorer(
        authRepository: MomCozyAuthApiRepository(
          transport: _RestoreTransport(refreshStatus: 401),
        ),
        store: store,
      ).restore(restored);
      expect(revoked.status, MomCozySessionStatus.expired);
      expect((await store.readSession())?.accessToken, isNull);
    },
  );

  test(
    'logout prevents an in-flight refresh write from restoring credentials',
    () async {
      final store = _DelayedStore();
      final controller = MomCozyRuntimeController(
        MomCozyApiRuntime.fromSession(session),
      );
      controller.enableSessionAutoRefresh(store);
      final transport =
          controller.runtime.jsonTransport as AuthenticatedApiJsonTransport;
      final pending = transport.refreshCoordinator.store.writeSession(
        session.copyWith(
          accessToken: 'late-access',
          refreshToken: 'late-refresh',
        ),
      );
      final rejected = expectLater(pending, throwsStateError);
      await store.started.future;
      // Inject a runtime that does not require platform file-cache plugins for this unit test.
      controller.replaceRuntime(
        MomCozyApiRuntime.fromSession(
          session,
          jsonTransport: FixtureApiJsonTransport({}),
        ),
      );
      final logout = controller.logout(
        sessionStore: store,
        revokeRemote: false,
      );
      store.release.complete();
      await rejected;
      await logout;
      expect(controller.currentSession.isAuthenticated, isFalse);
      expect(await store.readSession(), isNull);
      controller.dispose();
    },
  );

  test('late login persistence cannot revive a session after logout', () async {
    final store = _DelayedStore();
    final controller = MomCozyRuntimeController(
      MomCozyApiRuntime(jsonTransport: FixtureApiJsonTransport({})),
    );
    final pending = controller.saveAuthenticatedSession(
      session,
      sessionStore: store,
    );
    final rejected = expectLater(pending, throwsStateError);
    await store.started.future;
    final logout = controller.logout(sessionStore: store, revokeRemote: false);
    store.release.complete();
    await rejected;
    await logout;
    expect(controller.currentSession.isAuthenticated, isFalse);
    expect(await store.readSession(), isNull);
  });
}
