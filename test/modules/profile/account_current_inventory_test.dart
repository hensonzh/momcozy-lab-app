import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/native/p0_platform_interfaces.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_design_system.dart';
import '../../support/mom_inventory_transport.dart';
import '../../support/notification_inventory_transport.dart';
import '../../support/notification_fakes.dart';
import 'package:momcozy_flutter_app/features/notifications/presentation/notification_coordinator.dart';
import 'package:momcozy_flutter_app/features/notifications/presentation/notification_permission_controller.dart';
import '../../support/fixture_api_transport.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);
  setUpAll(() => WidgetController.hitTestWarningShouldBeFatal = true);
  late _MoreTransport transport;
  late _MoreRuntime runtime;
  late MemoryMomCozySessionStore store;
  late String variant;
  late GoRouter router;
  String? previous;
  late FakePlatform permissions;
  late FakeGateway gateway;
  late NotificationCoordinator coordinator;
  Future<void> mount(
    WidgetTester tester, {
    void Function(_MoreTransport)? prepare,
    double width = 393,
    double scale = 1,
    int notificationCount = 3,
  }) async {
    previous = null;
    variant = '${width.toInt()}-${scale.toInt()}x';
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    permissions = FakePlatform();
    gateway = FakeGateway();
    FlutterSecureStorage.setMockInitialValues({});
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    transport = _MoreTransport()..seedInbox(notificationCount);

    const session = MomCozySession(
      status: MomCozySessionStatus.authenticated,
      userId: 'inventory-user',
      babyId: 'inventory-baby',
      locale: 'zh-CN',
      accessToken: 'fixture-access',
      refreshToken: 'fixture-refresh',
    );
    runtime = _MoreRuntime(transport, session);
    store = MemoryMomCozySessionStore(session);
    final platform = FakeRouteIntentPlatform();
    router = createMomCozyRouter(
      initialLocation: '/me',
      runtimeController: runtime,
      sessionStore: store,
    );
    coordinator = NotificationCoordinator(
      permission: NotificationPermissionController(permissions),
      gateway: gateway,
      store: FakeStore(),
      platformName: 'android',
      onNavigate: (route) => router.go(route),
      onMessage: (message) {
        final context = tester.element(find.byType(Scaffold).last);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      },
      onForeground: (_) {},
    );
    await tester.pumpWidget(
      MomCozyFlutterApp(
        notificationCoordinator: coordinator,
        router: router,
        runtimeController: runtime,
        sessionStore: store,
        routeIntentPlatform: platform,
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      // Long capture visits lazy children. Decode both local images before
      // comparing any viewport so later dialogs see the same loaded page.
      for (final asset in [
        MomCozyAssets.agentAvatar,
        'assets/images/mom_home/cozymate_avatar.png',
        'assets/images/mom_home/expert_group.png',
        'assets/images/mom/milk-hero.png',
        'assets/images/auth_mother_baby.png',
        'assets/images/momcozy_logo.png',
        'assets/images/google_sign_in.png',
      ]) {
        await precacheImage(
          AssetImage(asset),
          tester.element(find.byType(MaterialApp)),
        );
      }
    });
    expect(router.state.uri.path, '/me');
    prepare?.call(transport);
    addTearDown(() async {
      for (final gate in transport.readGates.values) {
        if (!gate.isCompleted) gate.complete();
      }
      if (transport.writeGate case final gate? when !gate.isCompleted) {
        gate.complete();
      }
      if (transport.deleteGate case final gate? when !gate.isCompleted) {
        gate.complete();
      }
      if (transport.logoutGate case final gate? when !gate.isCompleted) {
        gate.complete();
      }
      coordinator.dispose();
      router.dispose();
      runtime.dispose();
      await platform.dispose();
    });
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  }

  Future<void> tap(WidgetTester tester, Finder target) async {
    if (target.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        target,
        300,
        scrollable: find
            .byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.restorationId != 'editable' &&
                  (widget.axisDirection == AxisDirection.down ||
                      widget.axisDirection == AxisDirection.up),
            )
            .last,
      );
    } else {
      await tester.ensureVisible(target);
    }
    await settle(tester);
    await tester.tap(target);
    await settle(tester);
    expect(tester.takeException(), isNull);
  }

  Future<void> capture(
    WidgetTester tester,
    String state,
    String action, {
    String route = '/account',
  }) async {
    // Commit edits and finish the input hint's fade without settling spinners.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(router.state.uri.path, route);
    expect(tester.takeException(), isNull);
    final source =
        'test/goldens/ui_inventory/account-current-$state-$variant.png';
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/ui_inventory/account-current-$state-$variant.png',
      ),
    );
    final row = {
      'source': source,
      'previous_source': previous,
      'route': route,
      'trigger': action,
      'root_entry': 'Authenticated Me → tap More bottom navigation',
      'evidence':
          'Actual MomCozyFlutterApp/createMomCozyRouter, production More/account/privacy/service pages and notification coordinator/repositories; isolated HTTP, push gateway and permission platform; real router.go and ScaffoldMessenger callbacks, no native OS dialog or remote push',
      'test': 'test/modules/profile/account_current_inventory_test.dart',
    };
    previous = source;
    final output = Platform.environment['MOMCOZY_UI_INVENTORY_DIR'];
    if (output != null) {
      final file = File(
        '$output/journeys/account-current-$state-$variant.json',
      );
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(row)}\n',
      );
    }
  }

  Future<void> start(WidgetTester tester, String stem) async {
    await capture(
      tester,
      '$stem-mom',
      'Authenticated Me before More navigation',
      route: '/me',
    );
    await tap(tester, find.text('More'));
    await capture(
      tester,
      '$stem-more',
      'More before Account settings',
      route: '/more',
    );
    await tap(tester, find.text('账号设置'));
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> back(WidgetTester tester, String state, String route) async {
    final target = find.byType(BackButton).evaluate().isNotEmpty
        ? find.byType(BackButton)
        : find.byTooltip('Back').evaluate().isNotEmpty
        ? find.byTooltip('Back')
        : find.byTooltip('返回').evaluate().isNotEmpty
        ? find.byTooltip('返回')
        : find.text('返回');
    await tap(tester, target.first);
    await tester.pumpAndSettle();
    await capture(tester, state, 'Tap page Back → $route', route: route);
  }

  Future<void> message(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const ValueKey('account-message')));
    await settle(tester);
  }

  void busy(WidgetTester tester) {
    expect(
      tester
          .widget<TextButton>(find.byKey(const ValueKey('account-sign-out')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(find.byKey(const ValueKey('account-delete')))
          .onPressed,
      isNull,
    );
  }

  for (final narrow in [false, true]) {
    Future<void> open(WidgetTester tester, String name) async {
      await mount(tester, width: narrow ? 320 : 393, scale: narrow ? 2 : 1);
      await start(tester, name);
    }

    testWidgets('inventory current Account read recovery $narrow', (
      tester,
    ) async {
      await mount(tester, width: narrow ? 320 : 393, scale: narrow ? 2 : 1);
      await capture(tester, 'read-mom', 'Authenticated Me', route: '/me');
      await tap(tester, find.text('More'));
      await capture(
        tester,
        'read-more',
        'More before account read failure',
        route: '/more',
      );
      transport.readGates['/v1/auth/me'] = Completer<void>();
      await tap(tester, find.text('账号设置'));
      expect(find.text('Loading account…'), findsOneWidget);
      await capture(tester, 'loading', 'Account GET pending → loading');
      transport.failingReads.add('/v1/auth/me');
      transport.readGates['/v1/auth/me']!.complete();
      await settle(tester);
      expect(find.text('Account unavailable'), findsOneWidget);
      await capture(tester, 'read-error', 'GET 503 → account error and Retry');
      transport.failingReads.clear();
      transport.readGates['/v1/auth/me'] = Completer<void>();
      await tap(tester, find.text('Retry'));
      await capture(tester, 'retry-pending', 'Retry → loading again');
      transport.readGates['/v1/auth/me']!.complete();
      await settle(tester);
      await capture(
        tester,
        'retry-ready',
        'Retried GET succeeds → active verified email account',
      );
      await back(tester, 'read-return', '/more');
      await tester.pumpWidget(const SizedBox());
    });
    testWidgets('inventory current Account Google local unavailable $narrow', (
      tester,
    ) async {
      await open(tester, 'password');
      await capture(tester, 'password-ready', 'Email-only account');
      await tap(tester, find.byKey(const ValueKey('account-link-google')));
      await capture(
        tester,
        'password-empty',
        'Link Google → empty password confirmation',
      );
      await tap(tester, find.text('Continue'));
      expect(find.byKey(const ValueKey('account-link-password')), findsNothing);
      expect(find.byKey(const ValueKey('account-message')), findsNothing);
      await capture(
        tester,
        'password-empty-dismissed',
        'Continue empty password → silently return without mutation',
      );
      await tap(tester, find.byKey(const ValueKey('account-link-google')));
      await tester.enterText(
        find.byKey(const ValueKey('account-link-password')),
        'fixture-password',
      );
      await capture(
        tester,
        'password-entered',
        'Enter password → obscured input',
      );
      await tap(tester, find.text('Cancel'));
      await capture(
        tester,
        'password-cancelled',
        'Cancel filled password → no binding',
      );
      await tap(tester, find.byKey(const ValueKey('account-link-google')));
      await tester.enterText(
        find.byKey(const ValueKey('account-link-password')),
        'fixture-password',
      );
      await tap(tester, find.text('Continue'));
      expect(
        find.text('Google sign-in is unavailable. Try again or use email.'),
        findsOneWidget,
      );
      expect(
        transport.mutationPaths.where((p) => p.contains('/auth/google')),
        isEmpty,
      );
      await message(tester);
      await capture(
        tester,
        'google-unavailable',
        'Native gateway lacks build client ID → inline unavailable feedback',
      );
      await tap(tester, find.byKey(const ValueKey('account-link-google')));
      await capture(
        tester,
        'google-reopen',
        'Retry Link Google → password dialog reopens',
      );
      await tap(tester, find.text('Cancel'));
      await capture(
        tester,
        'google-retry-cancelled',
        'Cancel retry → previous error remains',
      );
      await back(tester, 'password-return', '/more');
      await tester.pumpWidget(const SizedBox());
    });
    testWidgets('inventory current Account delete recovery success $narrow', (
      tester,
    ) async {
      await open(tester, 'delete');
      await capture(tester, 'delete-ready', 'Account before deletion');
      await tap(tester, find.byKey(const ValueKey('account-delete')));
      await capture(
        tester,
        'delete-confirm',
        'Request deletion → confirmation',
      );
      await tap(tester, find.text('Cancel'));
      expect(transport.deleteCalls, 0);
      await capture(
        tester,
        'delete-cancelled',
        'Cancel deletion → no mutation',
      );
      await tap(tester, find.byKey(const ValueKey('account-delete')));
      transport.deleteGate = Completer<void>();
      transport.failDelete = true;
      await tap(tester, find.byKey(const ValueKey('account-confirm-delete')));
      busy(tester);
      await capture(
        tester,
        'delete-pending',
        'Confirm → DELETE pending, account actions disabled',
      );
      transport.deleteGate!.complete();
      await settle(tester);
      expect(runtime.runtime.session.isAuthenticated, isTrue);
      expect(
        find.text('Unable to continue. Please try again shortly.'),
        findsOneWidget,
      );
      await message(tester);
      await capture(
        tester,
        'delete-error',
        'DELETE 503 → account retained with inline error',
      );
      transport.failDelete = false;
      transport.deleteGate = Completer<void>();
      await tap(tester, find.byKey(const ValueKey('account-delete')));
      await capture(
        tester,
        'delete-retry-confirm',
        'Retry deletion → confirmation again',
      );
      await tap(tester, find.byKey(const ValueKey('account-confirm-delete')));
      busy(tester);
      expect(find.byKey(const ValueKey('account-message')), findsNothing);
      await capture(
        tester,
        'delete-retry-pending',
        'Confirm retry → clear error and disable actions',
      );
      transport.deleteGate!.complete();
      await tester.pumpAndSettle();
      expect(transport.deleteCalls, 2);
      expect(transport.logoutCalls, 0);
      expect(runtime.runtime.session.isAuthenticated, isFalse);
      expect(await store.readSession(), isNull);
      expect(
        find.text(
          'Account access removed. Your data erasure request is pending.',
        ),
        findsOneWidget,
      );
      await capture(
        tester,
        'deleted-login-message',
        'DELETE succeeds → local session cleared, login and erasure Snackbar',
        route: '/login',
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await capture(
        tester,
        'deleted-login',
        'Erasure Snackbar expires → login remains',
        route: '/login',
      );
      await tester.pumpWidget(const SizedBox());
    });
    for (final fail in [false, true]) {
      testWidgets('inventory current Account logout $fail $narrow', (
        tester,
      ) async {
        final stem = fail ? 'logout-error' : 'logout-success';
        await open(tester, stem);
        await capture(tester, '$stem-ready', 'Account before sign out');
        transport.failLogout = fail;
        transport.logoutGate = Completer<void>();
        await tap(tester, find.byKey(const ValueKey('account-sign-out')));
        expect(runtime.runtime.session.isAuthenticated, isFalse);
        expect(await store.readSession(), isNull);
        await capture(
          tester,
          '$stem-pending',
          'Sign out → login while remote revoke pending',
          route: '/login',
        );
        transport.logoutGate!.complete();
        await tester.pumpAndSettle();
        expect(transport.logoutCalls, 1);
        if (fail) {
          expect(
            find.text(
              'Sign-out could not finish on the server or this device. Reconnect and try again.',
            ),
            findsOneWidget,
          );
        }
        await capture(
          tester,
          '$stem-result',
          fail
              ? 'Remote revoke 503 → Account-specific sign-out Snackbar'
              : 'Remote revoke success → login',
          route: '/login',
        );
        if (fail) {
          await tester.pump(const Duration(seconds: 5));
          await tester.pumpAndSettle();
          await capture(
            tester,
            '$stem-dismissed',
            'Sign-out error expires → login',
            route: '/login',
          );
        }
        await tester.pumpWidget(const SizedBox());
      });
    }
    for (final kind in [
      'google-only',
      'disabled-empty',
      'long-pending-other',
    ]) {
      testWidgets('inventory current Account profile $kind $narrow', (
        tester,
      ) async {
        await mount(tester, width: narrow ? 320 : 393, scale: narrow ? 2 : 1);
        final profile = transport.responsesByPath['/v1/auth/me']!;
        if (kind == 'google-only') profile['auth_providers'] = ['google'];
        if (kind == 'disabled-empty') {
          profile.addAll({
            'auth_providers': <String>[],
            'account_status': 'disabled',
            'email': null,
            'email_verified': false,
          });
        }
        if (kind == 'long-pending-other') {
          profile.addAll({
            'auth_providers': ['email', 'google', 'custom'],
            'account_status': 'deletion_pending',
            'email_verified': false,
            'email': 'mia.catherine.chen.with.a.long.email@example.test',
          });
        }
        await start(tester, kind);
        expect(find.byKey(const ValueKey('account-link-google')), findsNothing);
        await capture(
          tester,
          '$kind-ready',
          'Account GET $kind → real identity status and provider layout',
        );
        await back(tester, '$kind-return', '/more');
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}

MomCozyApiRuntime _moreRuntime(_MoreTransport t, MomCozySession s) =>
    MomCozyApiRuntime(
      jsonTransport: t,
      multipartTransport: FixtureApiMultipartTransport({}),

      session: s,
      supportsSessionAutoRefresh: false,
      now: () => inventoryMomNow,
      timezoneProvider: () async => 'Asia/Shanghai',
    );

class _MoreRuntime extends MomCozyRuntimeController {
  _MoreRuntime(this.transport, MomCozySession session)
    : super(_moreRuntime(transport, session));
  final _MoreTransport transport;
  @override
  void replaceRuntime(MomCozyApiRuntime value) =>
      super.replaceRuntime(_moreRuntime(transport, value.session));
}

class _MoreTransport extends NotificationInventoryTransport {
  _MoreTransport() {
    responsesByPath['/v1/profile/me'] = {'display_name': 'Mia Chen', 'age': 30};
    responsesByPath['/v1/auth/me'] = {
      'id': 'inventory-user',
      'email': 'mia@example.test',
      'email_verified': true,
      'account_status': 'active',
      'auth_providers': ['email'],
    };
    seedInbox(3);
  }
  Completer<void>? deleteGate;
  bool failDelete = false;
  int deleteCalls = 0;
  @override
  Future<Map<String, Object?>> deleteJson(
    String path, {
    Map<String, String> headers = const {},
  }) async {
    if (path == '/v1/auth/me') {
      deleteCalls++;
      await deleteGate?.future;
      check(failDelete);
      return {};
    }
    return super.deleteJson(path, headers: headers);
  }

  Completer<void>? logoutGate;
  bool failLogout = false;
  int logoutCalls = 0;
  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    if (path == '/v1/auth/logout-session') {
      logoutCalls++;
      await logoutGate?.future;
      check(failLogout);
      return {};
    }
    return super.postJson(path, body: body, headers: headers);
  }
}
