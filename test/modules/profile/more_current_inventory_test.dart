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
      await tester.drag(find.byType(Scrollable).last, const Offset(0, 10000));
      await settle(tester);
    }
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
    String route = '/more',
  }) async {
    // Commit edits and finish the input hint's fade without settling spinners.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(router.state.uri.path, route);
    expect(tester.takeException(), isNull);
    final source = 'test/goldens/ui_inventory/more-current-$state-$variant.png';
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/ui_inventory/more-current-$state-$variant.png',
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
      'test': 'test/modules/profile/more_current_inventory_test.dart',
    };
    previous = source;
    final output = Platform.environment['MOMCOZY_UI_INVENTORY_DIR'];
    if (output != null) {
      final file = File('$output/journeys/more-current-$state-$variant.json');
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
    await tap(tester, find.byKey(const ValueKey('bottom-nav-more')));
  }

  Future<void> back(WidgetTester tester, String state, String route) async {
    final target = find.byType(BackButton).evaluate().isNotEmpty
        ? find.byType(BackButton)
        : find.byTooltip('Back').evaluate().isNotEmpty
        ? find.byTooltip('Back')
        : find.byTooltip('Back').evaluate().isNotEmpty
        ? find.byTooltip('Back')
        : find.text('Back');
    await tap(tester, target.first);
    await tester.pumpAndSettle();
    await capture(tester, state, 'Tap page Back → $route', route: route);
  }

  for (final narrow in [false, true]) {
    testWidgets('inventory current More routes ${narrow ? '320/2x' : '393/1x'}', (
      tester,
    ) async {
      await mount(tester, width: narrow ? 320 : 393, scale: narrow ? 2 : 1);
      await start(tester, 'routes');
      expect(find.text('Mia Chen'), findsOneWidget);
      expect(coordinator.inbox!.state.unreadCount, 3);
      await capture(
        tester,
        'routes-ready',
        'More current identity and three unread notifications',
      );
      await tap(tester, find.text('Privacy'));
      await capture(
        tester,
        'privacy',
        'More privacy → real privacy page',
        route: '/privacy',
      );
      await back(tester, 'privacy-return', '/more');
      await tap(tester, find.text('Account settings'));
      expect(find.text('Email verified'), findsOneWidget);
      await capture(
        tester,
        'account',
        'Account settings row → real account details and methods',
        route: '/account',
      );
      await tap(tester, find.byKey(const ValueKey('account-link-google')));
      await capture(
        tester,
        'account-link-confirm',
        'Link Google → password confirmation, before native sign in',
        route: '/account',
      );
      await tap(tester, find.text('Cancel'));
      await capture(
        tester,
        'account-link-cancel',
        'Cancel password confirmation → account unchanged',
        route: '/account',
      );
      await tap(tester, find.byKey(const ValueKey('account-delete')));
      await capture(
        tester,
        'account-delete-confirm',
        'Request account deletion → confirmation only',
        route: '/account',
      );
      await tap(tester, find.text('Cancel'));
      await capture(
        tester,
        'account-delete-cancel',
        'Cancel deletion → account retained',
        route: '/account',
      );
      await back(tester, 'account-return', '/more');
      await tap(tester, find.text('Notifications'));
      expect(router.state.uri.queryParameters['from'], '/more');
      await capture(
        tester,
        'inbox-unread',
        'Notifications row → real inbox preserving from=/more',
        route: '/notifications',
      );
      await tap(tester, find.text('Mark all read'));
      expect(coordinator.inbox!.state.unreadCount, 0);
      await capture(
        tester,
        'inbox-read',
        'Mark all read → inbox read and count zero',
        route: '/notifications',
      );
      await tap(tester, find.byTooltip('Notification settings'));
      await capture(
        tester,
        'notification-settings',
        'Inbox settings → real preferences and authorization state',
        route: '/notifications/settings',
      );
      await back(tester, 'settings-return', '/notifications');
      await back(tester, 'inbox-return', '/more');
      expect(coordinator.inbox!.state.unreadCount, 0);
      expect(find.text('3'), findsNothing);
      await tap(tester, find.text('Expert support'));
      await capture(
        tester,
        'expert-catalog',
        'Expert support card → real service catalog',
        route: '/services',
      );
      await tap(tester, find.text('View my services'));
      await capture(
        tester,
        'expert-package',
        'My service → purchased package details',
        route: '/services/feeding-confidence',
      );
      await back(tester, 'package-return', '/services');
      await back(tester, 'catalog-return', '/more');
      final logout = find.byKey(const ValueKey('more-logout'));
      await tester.ensureVisible(logout);
      await tester.pumpAndSettle();
      await capture(
        tester,
        'logout-visible',
        'Scroll More to sign-out control',
      );
      transport.logoutGate = Completer<void>();
      await tester.tap(logout);
      await tester.pumpAndSettle();
      expect(runtime.runtime.session.isAuthenticated, isFalse);
      expect(await store.readSession(), isNull);
      await capture(
        tester,
        'logout-remote-pending',
        'Sign out → local session cleared and login immediately, remote revoke pending',
        route: '/login',
      );
      transport.logoutGate!.complete();
      await tester.pumpAndSettle();
      expect(transport.logoutCalls, 1);
      await capture(
        tester,
        'logout-complete',
        'Remote logout-session completed → login remains',
        route: '/login',
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
    for (final condition in [
      'pending',
      'name-unavailable',
      'email-unavailable',
      'both-unavailable',
      'long',
    ]) {
      testWidgets(
        'inventory current More $condition ${narrow ? '320/2x' : '393/1x'}',
        (tester) async {
          await mount(
            tester,
            width: narrow ? 320 : 393,
            scale: narrow ? 2 : 1,
            notificationCount: condition == 'long' ? 101 : 3,
            prepare: (t) {
              if (condition == 'pending') {
                t.readGates['/v1/profile/me'] = Completer<void>();
                t.readGates['/v1/auth/me'] = Completer<void>();
              }
              if (condition == 'name-unavailable' ||
                  condition == 'both-unavailable') {
                t.failingReads.add('/v1/profile/me');
              }
              if (condition == 'email-unavailable' ||
                  condition == 'both-unavailable') {
                t.failingReads.add('/v1/auth/me');
              }
              if (condition == 'long') {
                t.responsesByPath['/v1/profile/me'] = {
                  'display_name': 'Mia Catherine Chen With A Long Display Name',
                };
                t.responsesByPath['/v1/auth/me'] = {
                  ...t.responsesByPath['/v1/auth/me']!,
                  'email': 'mia.catherine.chen.with.a.long.email@example.test',
                };
              }
            },
          );
          await start(tester, condition);
          if (condition == 'pending') {
            expect(find.text('Loading account…'), findsOneWidget);
            await capture(
              tester,
              'identity-pending',
              'Both identity endpoints pending → loading account card',
            );
            transport.readGates['/v1/profile/me']!.complete();
            await tester.pumpAndSettle();
            expect(find.text('Loading account…'), findsOneWidget);
            await capture(
              tester,
              'identity-name-only-arrived',
              'Name response arrived, email pending → combined identity still loading',
            );
            transport.readGates['/v1/auth/me']!.complete();
            await tester.pumpAndSettle();
            expect(find.text('Mia Chen'), findsOneWidget);
            await capture(
              tester,
              'identity-resolved',
              'Both responses arrived → name and email displayed',
            );
          } else {
            if (condition == 'name-unavailable' ||
                condition == 'both-unavailable') {
              expect(find.text('My account'), findsOneWidget);
            }
            if (condition == 'email-unavailable' ||
                condition == 'both-unavailable') {
              expect(
                find.text('Manage your account information'),
                findsOneWidget,
              );
            }
            if (condition == 'name-unavailable') {
              expect(find.text('mia@example.test'), findsOneWidget);
            }
            if (condition == 'email-unavailable') {
              expect(find.text('Mia Chen'), findsOneWidget);
            }
            if (condition == 'long') {
              expect(coordinator.inbox!.state.unreadCount, 101);
            }
            await capture(
              tester,
              'identity-$condition',
              'More identity $condition from independent HTTP responses',
            );
          }
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        },
      );
    }
    testWidgets(
      'inventory current More remote signout error ${narrow ? '320/2x' : '393/1x'}',
      (tester) async {
        await mount(tester, width: narrow ? 320 : 393, scale: narrow ? 2 : 1);
        await start(tester, 'logout-error');
        await capture(
          tester,
          'logout-error-ready',
          'More before failed remote revoke',
        );
        transport.failLogout = true;
        await tap(tester, find.byKey(const ValueKey('more-logout')));
        expect(runtime.runtime.session.isAuthenticated, isFalse);
        expect(await store.readSession(), isNull);
        expect(transport.logoutCalls, 1);
        expect(
          find.text('Sign-out could not finish. Reconnect and try again.'),
          findsOneWidget,
        );
        await capture(
          tester,
          'logout-error-message',
          'Remote revoke returns 503 → login with sign-out failure Snackbar',
          route: '/login',
        );
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        await capture(
          tester,
          'logout-error-dismissed',
          'Snackbar expires → anonymous login persists',
          route: '/login',
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
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
