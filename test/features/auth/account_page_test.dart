import 'dart:async';

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

  testWidgets('change password validates, submits both copies and signs out', (
    tester,
  ) async {
    final transport = FixtureApiJsonTransportByPath({
      '/v1/auth/me': {
        'email': 'mia@example.com',
        'email_verified': true,
        'account_status': 'active',
        'auth_providers': ['email'],
      },
      '/v1/auth/change-password': {'status': 'password_changed'},
    });
    final store = MemoryMomCozySessionStore(
      const MomCozySession(
        status: MomCozySessionStatus.authenticated,
        userId: 'mia',
        babyId: 'baby',
        locale: 'en-US',
        accessToken: 'access',
        refreshToken: 'refresh',
      ),
    );
    final controller = MomCozyRuntimeController(
      MomCozyApiRuntime.fromSession(
        (await store.readSession())!,
        jsonTransport: transport,
      ),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: MomCozyAccountPage(
          runtimeController: controller,
          sessionStore: store,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('account-change-password')),
    );
    await tester.tap(find.byKey(const ValueKey('account-change-password')));
    await tester.pumpAndSettle();
    final current = find.byKey(const ValueKey('account-current-password'));
    final next = find.byKey(const ValueKey('account-new-password'));
    final confirm = find.byKey(const ValueKey('account-confirm-password'));
    final submit = find.byKey(const ValueKey('account-change-password-submit'));
    await tester.enterText(current, 'secret123');
    await tester.enterText(next, 'new-secret123');
    await tester.enterText(confirm, 'mismatch123');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('Passwords do not match.'), findsOneWidget);
    expect(transport.mutationPaths, isEmpty);
    await tester.enterText(confirm, 'new-secret123');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(transport.lastPath, '/v1/auth/change-password');
    expect(transport.lastBody, {
      'current_password': 'secret123',
      'new_password': 'new-secret123',
      'confirm_password': 'new-secret123',
    });
    expect(controller.currentSession.isAuthenticated, isFalse);
    expect(await store.readSession(), isNull);
  });
  testWidgets('incorrect current password leaves session and form available', (
    tester,
  ) async {
    final transport = FixtureApiJsonTransportByPath({
      '/v1/auth/me': {
        'email': 'mia@example.com',
        'email_verified': true,
        'account_status': 'active',
        'auth_providers': ['email'],
      },
      '/v1/auth/change-password': {
        'http_status': 422,
        'body': {
          'error': {'code': 'invalid_current_password'},
        },
      },
    });
    final session = const MomCozySession(
      status: MomCozySessionStatus.authenticated,
      userId: 'mia',
      babyId: 'baby',
      locale: 'en-US',
      accessToken: 'access',
      refreshToken: 'refresh',
    );
    final store = MemoryMomCozySessionStore(session);
    final controller = MomCozyRuntimeController(
      MomCozyApiRuntime.fromSession(session, jsonTransport: transport),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: MomCozyAccountPage(
          runtimeController: controller,
          sessionStore: store,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('account-change-password')),
    );
    await tester.tap(find.byKey(const ValueKey('account-change-password')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('account-current-password')),
      'wrong-password',
    );
    await tester.enterText(
      find.byKey(const ValueKey('account-new-password')),
      'new-secret123',
    );
    await tester.enterText(
      find.byKey(const ValueKey('account-confirm-password')),
      'new-secret123',
    );
    await tester.tap(
      find.byKey(const ValueKey('account-change-password-submit')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Current password is incorrect.'), findsOneWidget);
    expect(controller.currentSession.isAuthenticated, isTrue);
    expect((await store.readSession())?.refreshToken, 'refresh');
  });

  testWidgets('uncertain password change signs out without retrying', (
    tester,
  ) async {
    final transport = _TimeoutPasswordChangeTransport();
    final session = const MomCozySession(
      status: MomCozySessionStatus.authenticated,
      userId: 'mia',
      babyId: 'baby',
      locale: 'en-US',
      accessToken: 'access',
      refreshToken: 'refresh',
    );
    final store = MemoryMomCozySessionStore(session);
    final controller = MomCozyRuntimeController(
      MomCozyApiRuntime.fromSession(session, jsonTransport: transport),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: MomCozyAccountPage(
          runtimeController: controller,
          sessionStore: store,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('account-change-password')),
    );
    await tester.tap(find.byKey(const ValueKey('account-change-password')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('account-current-password')),
      'secret123',
    );
    await tester.enterText(
      find.byKey(const ValueKey('account-new-password')),
      'new-secret123',
    );
    await tester.enterText(
      find.byKey(const ValueKey('account-confirm-password')),
      'new-secret123',
    );
    await tester.tap(
      find.byKey(const ValueKey('account-change-password-submit')),
    );
    await tester.pumpAndSettle();
    expect(transport.attempts, 1);
    expect(controller.currentSession.isAuthenticated, isFalse);
    expect(await store.readSession(), isNull);
  });

  testWidgets(
    'changing a password redirects the authenticated route to sign in',
    (tester) async {
      final transport = FixtureApiJsonTransportByPath({
        '/v1/auth/me': {
          'id': 'mia',
          'email': 'mia@example.com',
          'email_verified': true,
          'account_status': 'active',
          'auth_providers': ['email'],
        },
        '/v1/auth/change-password': {'status': 'password_changed'},
      });
      final session = const MomCozySession(
        status: MomCozySessionStatus.authenticated,
        userId: 'mia',
        babyId: 'baby',
        locale: 'en-US',
        accessToken: 'access',
        refreshToken: 'refresh',
      );
      final store = MemoryMomCozySessionStore(session);
      final controller = MomCozyRuntimeController(
        MomCozyApiRuntime.fromSession(session, jsonTransport: transport),
      );
      final router = createMomCozyRouter(
        runtimeController: controller,
        sessionStore: store,
        initialLocation: '/account',
      );
      addTearDown(() {
        router.dispose();
        controller.dispose();
      });
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/account');
      await tester.ensureVisible(
        find.byKey(const ValueKey('account-change-password')),
      );
      await tester.tap(find.byKey(const ValueKey('account-change-password')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('account-current-password')),
        'secret123',
      );
      await tester.enterText(
        find.byKey(const ValueKey('account-new-password')),
        'new-secret123',
      );
      await tester.enterText(
        find.byKey(const ValueKey('account-confirm-password')),
        'new-secret123',
      );
      await tester.tap(
        find.byKey(const ValueKey('account-change-password-submit')),
      );
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/login');
      expect(controller.currentSession.isAuthenticated, isFalse);
    },
  );

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

class _TimeoutPasswordChangeTransport extends FixtureApiJsonTransportByPath {
  _TimeoutPasswordChangeTransport()
    : super({
        '/v1/auth/me': {
          'email': 'mia@example.com',
          'email_verified': true,
          'account_status': 'active',
          'auth_providers': ['email'],
        },
      });
  int attempts = 0;

  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    if (path == '/v1/auth/change-password') {
      attempts++;
      throw TimeoutException('Change password response lost');
    }
    return super.postJson(path, body: body, headers: headers);
  }
}
