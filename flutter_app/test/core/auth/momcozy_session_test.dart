import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';

void main() {
  group('MomCozySession', () {
    test('environment bootstrap is anonymous without tokens', () {
      final session = MomCozySession.fromEnvironment(
        accessToken: ' ',
        refreshToken: '',
        userId: ' user-env ',
        babyId: ' baby-env ',
        locale: ' zh-CN ',
      );

      expect(session.status, MomCozySessionStatus.anonymous);
      expect(session.isAuthenticated, isFalse);
      expect(session.accessToken, isNull);
      expect(session.refreshToken, isNull);
      expect(session.userId, 'user-env');
      expect(session.babyId, 'baby-env');
      expect(session.locale, 'zh-CN');
    });

    test('environment bootstrap is authenticated with access token', () {
      final session = MomCozySession.fromEnvironment(
        accessToken: ' access-token ',
        refreshToken: ' refresh-token ',
        userId: 'user-env',
        babyId: 'baby-env',
        locale: 'zh-CN',
      );

      expect(session.status, MomCozySessionStatus.authenticated);
      expect(session.isAuthenticated, isTrue);
      expect(session.accessToken, 'access-token');
      expect(session.refreshToken, 'refresh-token');
    });
  });

  group('MomCozySessionManager', () {
    test('stored secure session wins over environment session', () async {
      final store = MemoryMomCozySessionStore(
        const MomCozySession(
          status: MomCozySessionStatus.authenticated,
          userId: 'stored-user',
          babyId: 'stored-baby',
          locale: 'en-US',
          accessToken: 'stored-access',
          refreshToken: 'stored-refresh',
        ),
      );
      final manager = MomCozySessionManager(
        store: store,
        environmentSession: const MomCozySession(
          status: MomCozySessionStatus.anonymous,
          userId: 'env-user',
          babyId: 'env-baby',
          locale: 'zh-CN',
        ),
      );

      final session = await manager.bootstrap();

      expect(session.userId, 'stored-user');
      expect(session.babyId, 'stored-baby');
      expect(session.locale, 'en-US');
      expect(session.accessToken, 'stored-access');
      expect(session.refreshToken, 'stored-refresh');
    });

    test(
      'logout clears stored secrets and returns anonymous session',
      () async {
        final current = const MomCozySession(
          status: MomCozySessionStatus.authenticated,
          userId: 'user-001',
          babyId: 'baby-001',
          locale: 'zh-CN',
          accessToken: 'access-secret',
          refreshToken: 'refresh-secret',
        );
        final store = MemoryMomCozySessionStore(current);
        final manager = MomCozySessionManager(
          store: store,
          environmentSession: current,
        );

        final loggedOut = await manager.logout(current);

        expect(await store.readSession(), isNull);
        expect(loggedOut.status, MomCozySessionStatus.anonymous);
        expect(loggedOut.accessToken, isNull);
        expect(loggedOut.refreshToken, isNull);
        expect(loggedOut.userId, 'user-001');
      },
    );

    test(
      'switchAccount clears old session before writing next account',
      () async {
        final store = MemoryMomCozySessionStore(
          const MomCozySession(
            status: MomCozySessionStatus.authenticated,
            userId: 'old-user',
            babyId: 'old-baby',
            locale: 'zh-CN',
            accessToken: 'old-access',
            refreshToken: 'old-refresh',
          ),
        );
        final next = const MomCozySession(
          status: MomCozySessionStatus.authenticated,
          userId: 'next-user',
          babyId: 'next-baby',
          locale: 'en-US',
          accessToken: 'next-access',
          refreshToken: 'next-refresh',
        );
        final manager = MomCozySessionManager(
          store: store,
          environmentSession: next,
        );

        final switched = await manager.switchAccount(next);
        final stored = await store.readSession();

        expect(switched.userId, 'next-user');
        expect(switched.accessToken, 'next-access');
        expect(stored?.userId, 'next-user');
        expect(stored?.accessToken, 'next-access');
      },
    );
  });
}
