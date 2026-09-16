import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/core/auth/google_sign_in_gateway.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/features/auth/presentation/account_page.dart';
import '../../support/fixture_api_transport.dart';

void main() {
  testWidgets('account route requires login and returns to the intended page', (
    tester,
  ) async {
    final transport = FixtureApiJsonTransport({
      'id': 'mia',
      'email': 'mia@example.com',
      'email_verified': true,
      'account_status': 'active',
      'auth_providers': ['email'],
    });
    final controller = MomCozyRuntimeController(
      MomCozyApiRuntime(jsonTransport: transport),
    );
    final router = createMomCozyRouter(
      runtimeController: controller,
      sessionStore: MemoryMomCozySessionStore(),
      initialLocation: '/account?tab=security',
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/login');
    expect(
      router.routeInformationProvider.value.uri.queryParameters['from'],
      '/account?tab=security',
    );
    controller.replaceRuntime(
      MomCozyApiRuntime.fromSession(
        const MomCozySession(
          status: MomCozySessionStatus.authenticated,
          userId: 'mia',
          babyId: 'baby',
          locale: 'en-US',
          accessToken: 'access',
          refreshToken: 'refresh',
        ),
        jsonTransport: transport,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/account?tab=security',
    );
    expect(find.text('mia@example.com'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    controller.dispose();
  });

  testWidgets(
    'deletion requires explicit confirmation and clears local session',
    (tester) async {
      const session = MomCozySession(
        status: MomCozySessionStatus.authenticated,
        userId: 'mia',
        babyId: 'baby',
        locale: 'en-US',
        accessToken: 'access',
        refreshToken: 'refresh',
      );
      final transport = FixtureApiJsonTransport({
        'id': 'mia',
        'email': 'mia@example.com',
        'email_verified': true,
        'auth_providers': ['email'],
        'account_status': 'active',
        'status': 'deletion_pending',
      });
      final controller = MomCozyRuntimeController(
        MomCozyApiRuntime.fromSession(session, jsonTransport: transport),
      );
      final store = MemoryMomCozySessionStore(session);
      await tester.pumpWidget(
        MaterialApp(
          home: MomCozyAccountPage(
            runtimeController: controller,
            sessionStore: store,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('mia@example.com'), findsOneWidget);
      expect(find.byKey(const ValueKey('account-link-google')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('account-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('account-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(transport.mutationPaths, isEmpty);
      await tester.tap(find.byKey(const ValueKey('account-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('account-confirm-delete')));
      await tester.pumpAndSettle();
      expect(transport.lastMethod, 'DELETE');
      expect(transport.lastPath, '/v1/auth/me');
      expect(await store.readSession(), isNull);
      expect(controller.currentSession.isAuthenticated, isFalse);
      expect(
        find.text(
          'Account access removed. Your data erasure request is pending.',
        ),
        findsOneWidget,
      );
    },
  );
  testWidgets('account read retry and password-confirmed Google linking', (
    tester,
  ) async {
    final responses = <String, Map<String, Object?>>{
      '/v1/auth/me': {
        'http_status': 503,
        'body': {
          'error': {'code': 'unavailable'},
        },
      },
    };
    final transport = FixtureApiJsonTransportByPath(
      responses,
      writeResponsesByPath: {'/v1/auth/google/link': {}},
    );
    final runtime = MomCozyRuntimeController(
      MomCozyApiRuntime(jsonTransport: transport),
    );
    addTearDown(runtime.dispose);
    final google = _Google();
    await tester.pumpWidget(
      MaterialApp(
        home: MomCozyAccountPage(
          runtimeController: runtime,
          sessionStore: MemoryMomCozySessionStore(),
          googleSignIn: google,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    responses['/v1/auth/me'] = {
      'email': 'mia@example.test',
      'email_verified': true,
      'account_status': 'active',
      'auth_providers': ['email'],
    };
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('mia@example.test'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('account-link-google')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(google.calls, 0);
    expect(transport.mutationPaths, isEmpty);
    await tester.tap(find.byKey(const ValueKey('account-link-google')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('account-link-password')),
      'test-password',
    );
    responses['/v1/auth/me']!['auth_providers'] = ['email', 'google'];
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(google.calls, 1);
    expect(transport.mutationPaths, ['/v1/auth/google/link']);
    expect(transport.lastBody, {
      'id_token': 'test-google-token',
      'password': 'test-password',
    });
    expect(find.text('Google account linked.'), findsOneWidget);
    expect(find.text('Google'), findsOneWidget);
    expect(find.byKey(const ValueKey('account-link-google')), findsNothing);
  });
}

class _Google implements GoogleSignInGateway {
  int calls = 0;
  @override
  Future<String?> signIn() async {
    calls++;
    return 'test-google-token';
  }
}
