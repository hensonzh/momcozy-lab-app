import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:momcozy_flutter_app/app/mom_bottom_navigation.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/features/notifications/domain/momcozy_notification.dart';
import 'package:momcozy_flutter_app/features/notifications/presentation/notification_coordinator.dart';
import 'package:momcozy_flutter_app/features/notifications/presentation/notification_permission_controller.dart';
import 'package:momcozy_flutter_app/features/notifications/presentation/notification_scope.dart';
import 'package:momcozy_flutter_app/features/notifications/presentation/notifications_controller.dart';
import 'package:momcozy_flutter_app/modules/profile/presentation/more_page.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';

import '../support/fixture_api_transport.dart';
import '../support/momcozy_test_fonts.dart';
import '../support/notification_fakes.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);
  for (final (width, scale) in [(393.0, 1.0), (320.0, 2.0)]) {
    testWidgets('More pending and failed identity $width/$scale', (
      tester,
    ) async {
      final transport = _PendingIdentity();
      final router = await _host(tester, transport, width, scale);
      expect(find.text('正在加载账号…'), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          '../goldens/ui_refactor/more-loading-${width.toInt()}-${scale.toInt()}x.png',
        ),
      );

      transport.reply.completeError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(find.text('管理你的账号信息'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('Mia Chen'), findsNothing);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          '../goldens/ui_refactor/more-unavailable-${width.toInt()}-${scale.toInt()}x.png',
        ),
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('more-logout')),
        250,
      );
      expect(
        tester
            .widget<TextButton>(find.byKey(const ValueKey('more-logout')))
            .onPressed,
        isNull,
      );
      await tester.scrollUntilVisible(find.text('专家支持'), -200);
      await tester.tap(find.text('专家支持'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/services');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('More long identity and sign out $width/$scale', (
      tester,
    ) async {
      const name = 'Mia Catherine Chen With A Long Display Name';
      const email = 'mia.catherine.chen.with.a.long.email@example.test';
      var signedOut = 0;
      final router = await _host(
        tester,
        FixtureApiJsonTransport({'display_name': name, 'email': email}),
        width,
        scale,
        onLogout: () async {
          signedOut++;
        },
      );
      expect(find.text(name), findsOneWidget);
      expect(find.text(email), findsOneWidget);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          '../goldens/ui_refactor/more-long-identity-${width.toInt()}-${scale.toInt()}x.png',
        ),
      );
      final logout = find.byKey(const ValueKey('more-logout'));
      await tester.scrollUntilVisible(logout, 250);
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          '../goldens/ui_refactor/more-long-bottom-${width.toInt()}-${scale.toInt()}x.png',
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(logout);
      await tester.pumpAndSettle();
      expect(signedOut, 1);
      expect(router.state.uri.path, '/login');
      await tester.pumpWidget(const SizedBox());
    });
  }
}

Future<GoRouter> _host(
  WidgetTester tester,
  FixtureApiJsonTransport transport,
  double width,
  double scale, {
  Future<void> Function()? onLogout,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final runtime = MomCozyApiRuntime.fromSession(
    const MomCozySession(
      status: MomCozySessionStatus.authenticated,
      userId: 'synthetic-more-design',
      babyId: 'baby',
      locale: 'en',
    ),
    jsonTransport: transport,
  );
  final inbox = NotificationsController(repository: _UnreadRepository());
  await inbox.load();
  final coordinator = NotificationCoordinator(
    permission: NotificationPermissionController(FakePlatform()),
    gateway: FakeGateway(),
    store: FakeStore(),
    platformName: 'android',
    onNavigate: (_) {},
    onMessage: (_) {},
    onForeground: (_) {},
  )..inbox = inbox;
  addTearDown(coordinator.dispose);
  final router = GoRouter(
    initialLocation: '/more',
    routes: [
      GoRoute(
        path: '/more',
        builder: (_, _) => MomCozyRuntimeScope(
          apiRuntime: runtime,
          child: NotificationScope(
            coordinator: coordinator,
            child: Scaffold(
              body: SafeArea(child: MorePage(onLogout: onLogout)),
              bottomNavigationBar: const MomCozyBottomNavigation(
                location: '/more',
              ),
            ),
          ),
        ),
      ),
      for (final path in ['/services', '/login'])
        GoRoute(
          path: path,
          builder: (_, _) => Scaffold(body: Text(path)),
        ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: momCozyTheme(),
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    for (final asset in [
      'assets/images/momcozy-agent.png',
      'assets/images/mom_home/expert_group.png',
    ]) {
      await precacheImage(
        AssetImage(asset),
        tester.element(find.byType(MorePage)),
      );
    }
  });
  await tester.pumpAndSettle();
  return router;
}

class _PendingIdentity extends FixtureApiJsonTransport {
  _PendingIdentity() : super({});
  final reply = Completer<Map<String, Object?>>();
  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) => reply.future;
}

class _UnreadRepository extends FakeRepository {
  @override
  Future<NotificationPageData> fetchPage({
    String? cursor,
    int limit = 30,
  }) async => const NotificationPageData(items: [], unreadCount: 3);
}
