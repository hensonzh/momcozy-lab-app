import 'package:flutter/material.dart';
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

  testWidgets('account details no longer contain the deletion entry', (
    tester,
  ) async {
    final controller = MomCozyRuntimeController(
      MomCozyApiRuntime(
        jsonTransport: FixtureApiJsonTransport({
          'email': 'mia@example.com',
          'email_verified': true,
          'account_status': 'active',
          'auth_providers': ['email'],
        }),
      ),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: MomCozyAccountPage(
          runtimeController: controller,
          sessionStore: MemoryMomCozySessionStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('mia@example.com'), findsOneWidget);
    expect(find.byKey(const ValueKey('account-delete')), findsNothing);
    expect(find.text('Request account deletion'), findsNothing);
  });
  testWidgets('legacy account shows password recovery guidance', (
    tester,
  ) async {
    final transport = FixtureApiJsonTransport({
      'email': 'legacy@example.com',
      'email_verified': true,
      'account_status': 'active',
      'auth_providers': ['google'],
    });
    final controller = MomCozyRuntimeController(
      MomCozyApiRuntime(jsonTransport: transport),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: MomCozyAccountPage(
          runtimeController: controller,
          sessionStore: MemoryMomCozySessionStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('This account has no email password'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('account-link-google')), findsNothing);
  });
}
