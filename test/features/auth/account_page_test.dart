import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/features/auth/presentation/account_page.dart';
import '../../support/fixture_api_transport.dart';

void main() {
  testWidgets('account route requires login and returns to the intended page', (tester) async {
    final transport = FixtureApiJsonTransport({'id': 'mia', 'email': 'mia@example.com', 'email_verified': true, 'account_status': 'active', 'auth_providers': ['email']});
    final controller = MomCozyRuntimeController(MomCozyApiRuntime(jsonTransport: transport));
    final router = createMomCozyRouter(runtimeController: controller, sessionStore: MemoryMomCozySessionStore(), initialLocation: '/account?tab=security');
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/login');
    expect(router.routeInformationProvider.value.uri.queryParameters['from'], '/account?tab=security');
    controller.replaceRuntime(MomCozyApiRuntime.fromSession(const MomCozySession(status: MomCozySessionStatus.authenticated, userId: 'mia', babyId: 'baby', locale: 'en-US', accessToken: 'access', refreshToken: 'refresh'), jsonTransport: transport));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.toString(), '/account?tab=security');
    expect(find.text('mia@example.com'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    router.dispose(); controller.dispose();
  });

  testWidgets('deletion requires explicit confirmation and clears local session', (tester) async {
    const session = MomCozySession(status: MomCozySessionStatus.authenticated, userId: 'mia', babyId: 'baby', locale: 'en-US', accessToken: 'access', refreshToken: 'refresh');
    final transport = FixtureApiJsonTransport({'id': 'mia', 'email': 'mia@example.com', 'email_verified': true,
      'auth_providers': ['email'], 'account_status': 'active', 'status': 'deletion_pending'});
    final controller = MomCozyRuntimeController(MomCozyApiRuntime.fromSession(session, jsonTransport: transport));
    final store = MemoryMomCozySessionStore(session);
    await tester.pumpWidget(MaterialApp(home: MomCozyAccountPage(runtimeController: controller, sessionStore: store)));
    await tester.pumpAndSettle();
    expect(find.text('mia@example.com'), findsOneWidget);
    expect(find.byKey(const ValueKey('account-link-google')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('account-delete')));
    await tester.tap(find.byKey(const ValueKey('account-delete'))); await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel')); await tester.pumpAndSettle();
    expect(transport.mutationPaths, isEmpty);
    await tester.tap(find.byKey(const ValueKey('account-delete'))); await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('account-confirm-delete'))); await tester.pumpAndSettle();
    expect(transport.lastMethod, 'DELETE');
    expect(transport.lastPath, '/v1/auth/me');
    expect(await store.readSession(), isNull);
    expect(controller.currentSession.isAuthenticated, isFalse);
    expect(find.text('Account access removed. Your data erasure request is pending.'), findsOneWidget);
  });
}
