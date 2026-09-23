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
import 'package:momcozy_flutter_app/features/notifications/domain/notification_permission.dart';
import '../../support/fixture_api_transport.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);
  setUpAll(() => WidgetController.hitTestWarningShouldBeFatal = true);
  late NotificationInventoryTransport transport;
  late MomCozyRuntimeController runtime;
  late GoRouter router;
  String? previous;
  late String variant;
  late String entry;
  var narrow = false;
  late FakePlatform permissions;
  late FakeGateway gateway;
  late NotificationCoordinator coordinator;
  Future<void> mount(
    WidgetTester tester, {
    void Function(NotificationInventoryTransport)? prepare,
    void Function(FakePlatform, FakeGateway)? preparePlatform,
  }) async {
    previous = null;
    variant = narrow ? '320-2x' : '393-1x';
    tester.platformDispatcher.textScaleFactorTestValue = narrow ? 2 : 1;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    permissions = FakePlatform();
    gateway = FakeGateway();
    FlutterSecureStorage.setMockInitialValues({});
    tester.view.physicalSize = Size(narrow ? 320 : 393, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    transport = NotificationInventoryTransport();
    prepare?.call(transport);
    preparePlatform?.call(permissions, gateway);
    const session = MomCozySession(
      status: MomCozySessionStatus.authenticated,
      userId: 'inventory-user',
      babyId: 'inventory-baby',
      locale: 'zh-CN',
      accessToken: 'fixture-access',
      refreshToken: 'fixture-refresh',
    );
    runtime = MomCozyRuntimeController(
      MomCozyApiRuntime(
        jsonTransport: transport,
        multipartTransport: FixtureApiMultipartTransport({}),

        session: session,
        supportsSessionAutoRefresh: false,
        now: () => inventoryMomNow,
        timezoneProvider: () async => 'Asia/Shanghai',
      ),
    );
    final store = MemoryMomCozySessionStore(session);
    final platform = FakeRouteIntentPlatform();
    router = createMomCozyRouter(
      initialLocation: '/more',
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
      ]) {
        await precacheImage(
          AssetImage(asset),
          tester.element(find.byType(MaterialApp)),
        );
      }
    });
    expect(router.state.uri.path, '/more');
    addTearDown(() async {
      for (final gate in transport.readGates.values) {
        if (!gate.isCompleted) gate.complete();
      }
      if (transport.writeGate case final gate? when !gate.isCompleted) {
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
    // The reminder remains busy underneath permission education until a choice.
    if (find.text('Receive reminders?').evaluate().isNotEmpty ||
        find.text('Notifications are off').evaluate().isNotEmpty) {
      await tester.pump(const Duration(milliseconds: 500));
    } else {
      await tester.pumpAndSettle();
    }
  }

  Future<void> tap(WidgetTester tester, Finder target) async {
    if (target.evaluate().isEmpty) {
      await tester.drag(find.byType(Scrollable).last, const Offset(0, 8000));
      await tester.pumpAndSettle();
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
    String route = '/notifications',
  }) async {
    if (route == '/more') {
      await tester.drag(find.byType(ListView).last, const Offset(0, 8000));
      await tester.pumpAndSettle();
      action = '$action; scroll More back to top';
    }
    // Commit edits and finish the input hint's fade without settling spinners.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(router.state.uri.path, route);
    expect(tester.takeException(), isNull);
    final source =
        'test/goldens/ui_inventory/notification-current-$state-$variant.png';
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/ui_inventory/notification-current-$state-$variant.png',
      ),
    );
    final row = {
      'source': source,
      'previous_source': previous,
      'route': route,
      'trigger': action,
      'root_entry': 'Authenticated More page',
      'evidence':
          'Actual MomCozyFlutterApp/createMomCozyRouter, production notification coordinator/repository/controller; isolated HTTP, push gateway and permission platform; real router.go and ScaffoldMessenger callbacks, no native OS dialog or remote push',
      'test':
          'test/features/notifications/notification_current_inventory_test.dart',
    };
    previous = source;
    final output = Platform.environment['MOMCOZY_UI_INVENTORY_DIR'];
    if (output != null) {
      final file = File(
        '$output/journeys/notification-current-$state-$variant.json',
      );
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(row)}\n',
      );
    }
  }

  const settingsRoute = '/notifications/settings';
  Future<void> inboxEntry(WidgetTester tester) async {
    await capture(
      tester,
      '$entry-more',
      'Authenticated More before notifications',
      route: '/more',
    );

    await tap(tester, find.text('通知'));
    expect(router.state.uri.path, '/notifications');
  }

  Future<void> dismissSnackbar(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  for (final compact in [false, true]) {
    testWidgets(
      'inventory notification inbox empty loading paging and archive',
      (tester) async {
        narrow = compact;
        entry = 'list';
        await mount(tester);
        await inboxEntry(tester);
        await capture(
          tester,
          'inbox-empty',
          'More notifications entry → empty inbox',
        );
        final gate = Completer<void>();
        transport.readGates['/v1/notifications'] = gate;
        await tester.tap(find.byTooltip('Refresh notifications'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await capture(
          tester,
          'inbox-loading',
          'Refresh empty inbox → pending response',
        );
        transport.failingReads.add('/v1/notifications');
        gate.complete();
        await tester.pumpAndSettle();
        await capture(
          tester,
          'inbox-read-error',
          'Empty inbox read fails → error and retry',
        );
        transport.failingReads.clear();
        transport.seedInbox(7);
        await tap(tester, find.text('Retry'));
        expect(find.text('7 unread'), findsOneWidget);
        await capture(
          tester,
          'inbox-first-page',
          'Retry → first three updates with unread count and load more',
        );
        await tap(tester, find.text('Load more'));
        expect(coordinator.inbox!.state.notifications.length, 6);
        await capture(
          tester,
          'inbox-second-page',
          'Load more → append second page',
        );
        await tap(tester, find.text('Load more'));
        expect(coordinator.inbox!.state.notifications.length, 7);
        await capture(
          tester,
          'inbox-last-page',
          'Load final page → full list, no load-more CTA',
        );
        await tap(
          tester,
          find.byKey(const ValueKey('notification-archive-notice-7')),
        );
        expect(transport.notifications.length, 6);
        await capture(
          tester,
          'inbox-archived',
          'Archive last update → removed immediately, unread count refreshed',
        );
        await tap(tester, find.text('Mark all read'));
        expect(
          transport.notifications.every((n) => n['status'] == 'read'),
          true,
        );
        await capture(
          tester,
          'inbox-all-read',
          'Mark all read → server state refreshed, unread badge cleared',
        );
        transport.failingWrites.add('/v1/notifications/notice-1');
        await tap(
          tester,
          find.byKey(const ValueKey('notification-archive-notice-1')),
        );
        await capture(
          tester,
          'archive-error',
          'Archive request fails → row retained and error banner',
        );
        transport.failingWrites.clear();
        await tap(
          tester,
          find.byKey(const ValueKey('notification-archive-notice-1')),
        );
        expect(
          transport.notifications.any((n) => n['id'] == 'notice-1'),
          false,
        );
        await capture(
          tester,
          'archive-retry',
          'Retry archive same update → row removed',
        );
        await tap(tester, find.byTooltip('Notification settings'));
        await capture(
          tester,
          'inbox-to-settings',
          'Inbox settings toolbar → notification preferences',
          route: settingsRoute,
        );
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'inventory notification opening errors unavailable target and appointment route',
      (tester) async {
        narrow = compact;
        entry = 'open';
        await mount(tester, prepare: (t) => t.seedInbox(3));
        await inboxEntry(tester);
        await capture(
          tester,
          'inbox-open-entry',
          'More → unread service updates',
        );
        transport.failingWrites.add('/v1/notifications/notice-1/open');
        await tap(tester, find.text('Service update 1'));
        expect(router.state.uri.path, '/notifications');
        expect(transport.notifications.first['status'], 'unread');
        await capture(
          tester,
          'notification-open-error',
          'Open update request fails → inbox retained with Snackbar',
        );
        transport.failingWrites.clear();
        await dismissSnackbar(tester);
        transport.unavailableTargets.add('notice-1');
        await tap(tester, find.text('Service update 1'));
        expect(transport.notifications.first['status'], 'read');
        await capture(
          tester,
          'notification-target-unavailable',
          'Retry open → server reports resource unavailable, item read, no navigation',
        );
        await dismissSnackbar(tester);
        await tap(tester, find.text('Service update 2'));
        const route =
            '/services/appointments/$inventoryNotificationAppointment';
        expect(find.text('预约详情'), findsOneWidget);
        await capture(
          tester,
          'notification-to-appointment',
          'Open available update → validated UUID appointment route',
          route: route,
        );
        await tap(tester, find.text('返回'));
        await capture(
          tester,
          'appointment-to-inbox',
          'Appointment back → notification center with read state',
        );
        await tap(tester, find.byTooltip('Back'));
        await capture(
          tester,
          'inbox-to-more',
          'Inbox back → More with updated unread badge',
          route: '/more',
        );
        await tester.pumpWidget(const SizedBox());
      },
    );
    testWidgets(
      'inventory notification pagination mutation waits and error retries',
      (tester) async {
        narrow = compact;
        entry = 'mutation';
        await mount(tester, prepare: (t) => t.seedInbox(7));
        await inboxEntry(tester);
        final pageGate = Completer<void>();
        transport.readGates['/v1/notifications'] = pageGate;
        await tester.scrollUntilVisible(
          find.text('Load more'),
          300,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Load more'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await capture(
          tester,
          'pagination-loading',
          'Load more → pending next page with first page retained',
        );
        transport.failingReads.add('/v1/notifications');
        pageGate.complete();
        await tester.pumpAndSettle();
        expect(coordinator.inbox!.state.notifications.length, 3);
        await capture(
          tester,
          'pagination-error',
          'Next page read fails → first page and error banner retained',
        );
        transport.failingReads.clear();
        await tap(tester, find.text('Load more'));
        expect(coordinator.inbox!.state.notifications.length, 6);
        await capture(
          tester,
          'pagination-retry',
          'Retry load more with same cursor → append second page',
        );
        await tester.drag(find.byType(ListView).last, const Offset(0, 8000));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Mark all read'));
        await tester.pumpAndSettle();
        transport.writeGate = Completer<void>();
        await tester.tap(find.text('Mark all read'));
        await tester.pump();
        await capture(
          tester,
          'mark-all-pending',
          'Mark all read pending → action disabled, unread count preserved',
        );
        transport.failingWrites.add('/v1/notifications/read-all');
        transport.writeGate!.complete();
        await tester.pumpAndSettle();
        await capture(
          tester,
          'mark-all-error',
          'Mark-all request fails → unread updates and retry banner retained',
        );
        transport.failingWrites.clear();
        await tap(tester, find.text('Mark all read'));
        expect(coordinator.inbox!.state.unreadCount, 0);
        await capture(
          tester,
          'mark-all-retry',
          'Retry mark all read → read state refreshed',
        );
        transport.writeGate = Completer<void>();
        await tester.ensureVisible(
          find.byKey(const ValueKey('notification-archive-notice-1')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('notification-archive-notice-1')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await capture(
          tester,
          'archive-pending',
          'Archive update → row spinner while request pending',
        );
        transport.writeGate!.complete();
        await tester.pumpAndSettle();
        await capture(
          tester,
          'archive-pending-completed',
          'Archive response → row removed and count refreshed',
        );
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets('inventory current notification settings switches and errors', (
      tester,
    ) async {
      narrow = compact;
      entry = 'settings';
      await mount(
        tester,
        preparePlatform: (p, g) => p.value = NotificationPermission.authorized,
      );
      await inboxEntry(tester);
      await capture(
        tester,
        'settings-inbox',
        'More → empty inbox before settings',
      );
      transport.readGates['/v1/notifications/preferences'] = Completer<void>();
      await tester.tap(find.byTooltip('Notification settings'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await capture(
        tester,
        'preferences-initial-loading',
        'Open settings → preference request pending, switches disabled',
        route: settingsRoute,
      );
      transport.failingReads.add('/v1/notifications/preferences');
      transport.readGates['/v1/notifications/preferences']!.complete();
      await tester.pumpAndSettle();
      await capture(
        tester,
        'preferences-initial-error',
        'Initial preferences 503 → error and no editable values',
        route: settingsRoute,
      );
      transport.failingReads.clear();
      await tap(tester, find.text('Refresh status'));
      await capture(
        tester,
        'settings-authorized',
        'Retry → system allowed and preference values loaded',
        route: settingsRoute,
      );
      for (final category in [
        'appointments',
        'consultations',
        'expert_feedback',
        'service_updates',
      ]) {
        final f = find.byKey(ValueKey('notification-preference-$category'));
        await tap(tester, f);
        expect(transport.preferencesData[category], false);
        await capture(
          tester,
          '$category-off',
          'Disable $category → saved false',
          route: settingsRoute,
        );
        await tap(tester, f);
        expect(transport.preferencesData[category], true);
        await capture(
          tester,
          '$category-on',
          'Enable $category → saved true',
          route: settingsRoute,
        );
      }
      final consultations = find.byKey(
        const ValueKey('notification-preference-consultations'),
      );
      await tester.ensureVisible(consultations);
      await tester.pumpAndSettle();
      transport.writeGate = Completer<void>();
      await tester.tap(consultations);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await capture(
        tester,
        'preference-write-pending',
        'Disable consultations → pending write, all switches disabled',
        route: settingsRoute,
      );
      transport.failingWrites.add(
        '/v1/notifications/preferences/consultations',
      );
      transport.writeGate!.complete();
      await tester.pumpAndSettle();
      expect(transport.preferencesData['consultations'], true);
      await capture(
        tester,
        'preference-write-error',
        'Write 503 → prior switch value plus Snackbar',
        route: settingsRoute,
      );
      transport.failingWrites.clear();
      await dismissSnackbar(tester);
      await tap(tester, consultations);
      await capture(
        tester,
        'preference-write-retry',
        'Retry disable → saved false',
        route: settingsRoute,
      );
      permissions.value = NotificationPermission.denied;
      await tap(tester, find.text('Refresh status'));
      await capture(
        tester,
        'settings-denied',
        'Refresh after simulated system denial → unavailable delivery labels',
        route: settingsRoute,
      );
      await tap(tester, find.text('Settings'));
      expect(permissions.settings, 1);
      await capture(
        tester,
        'settings-open-platform',
        'Settings calls fake platform, page remains; no OS screenshot claim',
        route: settingsRoute,
      );
      permissions.value = NotificationPermission.provisional;
      await tap(tester, find.text('Refresh status'));
      await capture(
        tester,
        'settings-provisional',
        'Refresh after quiet authorization → delivery available',
        route: settingsRoute,
      );
      permissions.value = NotificationPermission.unavailable;
      gateway.available = false;
      await tap(tester, find.text('Refresh status'));
      await capture(
        tester,
        'settings-unavailable',
        'Unavailable platform and SDK → delivery unavailable',
        route: settingsRoute,
      );
      await tap(tester, find.byTooltip('返回'));
      await capture(tester, 'settings-return', 'Settings Back → inbox');
      await tap(tester, find.byTooltip('Back'));
      await capture(
        tester,
        'settings-more-return',
        'Inbox Back → More',
        route: '/more',
      );
      await tester.pumpWidget(const SizedBox());
    });
    testWidgets(
      'inventory current notification tooltips and empty after archive',
      (tester) async {
        narrow = compact;
        entry = 'tooltip';
        await mount(tester, prepare: (t) => t.seedInbox(1));
        await inboxEntry(tester);
        await capture(tester, 'tooltip-ready', 'One unread notification');
        for (final label in [
          'Refresh notifications',
          'Notification settings',
          'Archive notification',
          'Back',
        ]) {
          final f = find.byTooltip(label);
          if (f.evaluate().isEmpty) {
            await tester.drag(
              find.byType(ListView).last,
              const Offset(0, 8000),
            );
            await tester.pumpAndSettle();
          }
          if (f.evaluate().isEmpty) {
            await tester.scrollUntilVisible(
              f,
              300,
              scrollable: find.byType(Scrollable).last,
            );
          }
          await tester.ensureVisible(f);
          await tester.pumpAndSettle();
          if (label == 'Back') {
            // This tooltip crosses the fixed AppBar/body boundary. Capture it
            // at the top so its two parts share the same document offset.
            await tester.drag(
              find.byType(ListView).last,
              const Offset(0, 8000),
            );
            await tester.pumpAndSettle();
          }
          await tester.longPress(f);
          await tester.pump(const Duration(milliseconds: 250));
          await capture(
            tester,
            'tooltip-${label.toLowerCase().replaceAll(' ', '-')}',
            '${label == 'Back' ? 'Scroll inbox to top; ' : ''}'
                'Long press $label → tooltip, action not invoked',
          );
          await tester.pump(const Duration(seconds: 4));
          await tester.pumpAndSettle();
          await capture(
            tester,
            'tooltip-${label.toLowerCase().replaceAll(' ', '-')}-dismissed',
            'Tooltip timeout → same inbox',
          );
        }
        await tap(
          tester,
          find.byKey(const ValueKey('notification-archive-notice-1')),
        );
        expect(coordinator.inbox!.state.unreadCount, 0);
        await capture(
          tester,
          'archive-final-empty',
          'Archive only notification → empty inbox and count zero',
        );
        await tap(tester, find.byTooltip('Back'));
        await capture(
          tester,
          'archive-final-more',
          'Back More → no unread badge',
          route: '/more',
        );
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
