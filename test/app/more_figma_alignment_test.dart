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

import 'package:momcozy_flutter_app/shared/widgets/mom_companion_widgets.dart';
import 'package:momcozy_flutter_app/shared/widgets/mom_settings_row.dart';

int auditUnread = 0;

void main() {
  setUpAll(loadMomCozyTestFonts);

  testWidgets('More content matches Figma with shared navigation at 393x844', (
    tester,
  ) async {
    await _host(
      tester,
      FixtureApiJsonTransport({
        'display_name': 'Mia Chen',
        'email': 'mia@example.test',
      }),
      393,
      1,
      onLogout: () async {},
    );
    await _decodeImages(tester);
    expect(
      tester.getRect(find.byType(MomHomeSurface).first),
      const Rect.fromLTWH(16, 110, 361, 99),
    );
    expect(
      tester.getRect(find.byType(MomSettingsRow).first),
      const Rect.fromLTWH(16, 267, 361, 84),
    );
    expect(
      tester.getRect(find.byType(MomExpertPlanEntry)),
      const Rect.fromLTWH(16, 494, 361, 94),
    );
    expect(
      tester.getRect(find.byKey(const ValueKey('more-logout'))),
      const Rect.fromLTWH(16, 602, 361, 44),
    );
    expect(
      tester.getRect(find.byKey(const ValueKey('bottom-nav-chrome'))),
      const Rect.fromLTWH(0, 762, 393, 82),
    );
    for (final entry in {
      'me': 45.7,
      'baby': 121.1,
      'momcozy ai': 196.5,
      'schedule': 271.9,
      'more': 347.3,
    }.entries) {
      expect(
        tester.getCenter(find.byKey(ValueKey('bottom-nav-${entry.key}'))).dx,
        closeTo(entry.value, .001),
      );
    }
    for (final entry in {
      'More': 33.0,
      'Everyday settings': 223.0,
      'Expert care': 450.0,
      'Expert support': 510.0,
      'Sign out': 616.0,
    }.entries) {
      expect(tester.getTopLeft(find.text(entry.key).first).dy, entry.value);
    }
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../goldens/ui_refactor/more-figma-default-393-1x.png'),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('More loading disables sign out and failure restores it', (
    tester,
  ) async {
    final pending = _PendingIdentity();
    var exits = 0;
    final router = await _host(
      tester,
      pending,
      393,
      1,
      onLogout: () async {
        exits++;
      },
    );
    await _decodeImages(tester);
    final logout = find.byKey(const ValueKey('more-logout'));
    expect(find.text('Loading account…'), findsOneWidget);
    expect(tester.widget<TextButton>(logout).onPressed, isNull);
    await tester.tap(logout);
    expect(exits, 0);
    expect(router.state.uri.path, '/more');
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../goldens/ui_refactor/more-figma-loading-393-1x.png'),
    );
    pending.reply.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.text('Manage your account information'), findsOneWidget);
    expect(tester.widget<TextButton>(logout).onPressed, isNotNull);
    await tester.tap(logout);
    await tester.pumpAndSettle();
    expect(exits, 1);
    expect(router.state.uri.path, '/login');
    await tester.pumpWidget(const SizedBox());
  });
}

Future<void> _decodeImages(WidgetTester tester) async {
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
  }) async => NotificationPageData(items: [], unreadCount: auditUnread);
}
