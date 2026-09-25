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
import 'package:momcozy_flutter_app/modules/mom/presentation/mom_home_sections.dart';
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
  late FakePlatform permissions;
  late FakeGateway gateway;
  late NotificationCoordinator coordinator;
  Future<void> mount(
    WidgetTester tester, {
    void Function(NotificationInventoryTransport)? prepare,
    void Function(FakePlatform, FakeGateway)? preparePlatform,
  }) async {
    previous = null;
    permissions = FakePlatform();
    gateway = FakeGateway();
    FlutterSecureStorage.setMockInitialValues({});
    tester.view.physicalSize = const Size(393, 844);
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

  Future<void> tap(
    WidgetTester tester,
    Finder target, {
    bool waitForResult = true,
  }) async {
    final scrollable = find
        .byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.restorationId != 'editable' &&
              (widget.axisDirection == AxisDirection.down ||
                  widget.axisDirection == AxisDirection.up),
        )
        .last;
    if (target.evaluate().isEmpty) {
      final position = tester.state<ScrollableState>(scrollable).position;
      if (position.pixels > position.minScrollExtent) {
        position.jumpTo(position.minScrollExtent);
        await tester.pump();
      }
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
    if (target.hitTestable().evaluate().isEmpty) {
      await tester.drag(scrollable, const Offset(0, -240));
      await settle(tester);
    }
    await tester.tap(target);
    if (waitForResult) {
      await settle(tester);
    } else {
      await tester.pump();
    }
    expect(tester.takeException(), isNull);
  }

  Future<void> capture(
    WidgetTester tester,
    String state,
    String action, {
    String route = '/notifications',
  }) async {
    // Commit edits and finish the input hint's fade without settling spinners.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(router.state.uri.path, route);
    expect(tester.takeException(), isNull);
    final source =
        'test/goldens/ui_inventory/notification-journey-$state-393.png';
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/ui_inventory/notification-journey-$state-393.png',
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
          'test/features/notifications/notification_inventory_journey_test.dart',
    };
    previous = source;
    final output = Platform.environment['MOMCOZY_UI_INVENTORY_DIR'];
    if (output != null) {
      final file = File('$output/journeys/notification-journey-$state.json');
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(row)}\n',
      );
    }
  }

  const bookingRoute = '/services/episodes/service-episode/booking';
  const settingsRoute = '/notifications/settings';
  Future<void> bookingEntry(WidgetTester tester) async {
    await tap(tester, find.byType(MomExpertPlanEntry));
    await tap(tester, find.text('View my services'));
    await tap(tester, find.text('Book an appointment'));
    expect(router.state.uri.path, bookingRoute);
  }

  Future<void> inboxEntry(WidgetTester tester) async {
    await tap(tester, find.text('Notifications'));
    expect(router.state.uri.path, '/notifications');
  }

  Finder reminderSwitch() =>
      find.widgetWithText(SwitchListTile, 'Appointment reminder');
  Future<void> dismissSnackbar(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  testWidgets('inventory notification reminder education grant toggle settings', (
    tester,
  ) async {
    await mount(tester);
    await bookingEntry(tester);
    await capture(
      tester,
      'reminder-not-requested',
      'Booking → reminder not requested',
      route: bookingRoute,
    );
    await tap(tester, reminderSwitch());
    expect(find.text('Receive reminders?'), findsOneWidget);
    await capture(
      tester,
      'reminder-education',
      'Enable appointment reminder → permission education',
      route: bookingRoute,
    );
    await tap(tester, find.text('Not now'));
    expect(permissions.requests, 0);
    await capture(
      tester,
      'reminder-education-declined',
      'Decline education → reminder off and Snackbar',
      route: bookingRoute,
    );
    await dismissSnackbar(tester);
    await tap(tester, reminderSwitch());
    await tap(tester, find.text('Continue'));
    expect(permissions.requests, 1);
    expect(transport.reminderData['enabled'], true);
    await capture(
      tester,
      'reminder-enabled',
      'Continue education → isolated platform grants permission and reminder persists',
      route: bookingRoute,
    );
    await tap(tester, reminderSwitch());
    expect(transport.reminderData['enabled'], false);
    await capture(
      tester,
      'reminder-disabled',
      'Turn reminder off → persisted disabled state',
      route: bookingRoute,
    );
    await tap(tester, find.text('Notification settings'));
    await capture(
      tester,
      'settings-allowed',
      'Booking notification settings → system allowed and category preferences',
      route: settingsRoute,
    );
    await tap(tester, find.widgetWithText(SwitchListTile, 'Appointments'));
    expect(transport.preferencesData['appointments'], false);
    await capture(
      tester,
      'appointments-disabled',
      'Disable appointment notifications category',
      route: settingsRoute,
    );
    await tap(tester, find.widgetWithText(SwitchListTile, 'Appointments'));
    expect(transport.preferencesData['appointments'], true);
    await capture(
      tester,
      'appointments-enabled',
      'Enable appointment notifications category with permission already granted',
      route: settingsRoute,
    );
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'inventory notification denied permission settings restoration and preference failures',
    (tester) async {
      await mount(
        tester,
        preparePlatform: (p, g) => p.next = NotificationPermission.denied,
      );
      await bookingEntry(tester);
      await tap(tester, reminderSwitch());
      await tap(tester, find.text('Continue'));
      expect(permissions.requests, 1);
      expect(transport.reminderData['enabled'], false);
      await capture(
        tester,
        'permission-denied',
        'Platform denies permission → reminder stays off with feedback',
        route: bookingRoute,
      );
      await dismissSnackbar(tester);
      await tap(tester, reminderSwitch());
      await capture(
        tester,
        'permission-settings-offer',
        'Enable after denial → offer system settings',
        route: bookingRoute,
      );
      await tap(tester, find.text('Not now'));
      expect(permissions.settings, 0);
      await dismissSnackbar(tester);
      await tap(tester, reminderSwitch());
      await tap(tester, find.text('Open settings'));
      expect(permissions.settings, 1);
      await capture(
        tester,
        'permission-settings-requested',
        'Open settings invokes isolated platform → reminder remains off until permission restored',
        route: bookingRoute,
      );
      await dismissSnackbar(tester);
      await tap(tester, find.text('Notification settings'));
      await capture(
        tester,
        'settings-denied',
        'Notification settings after denial → system permission off',
        route: settingsRoute,
      );
      permissions.value = NotificationPermission.authorized;
      await tap(tester, find.text('Refresh status'));
      expect(coordinator.pushReady, true);
      await capture(
        tester,
        'settings-permission-restored',
        'Return from simulated system change and refresh → allowed; no new permission request',
        route: settingsRoute,
      );
      for (final label in [
        'Consultations',
        'Expert feedback',
        'Service updates',
      ]) {
        await tap(tester, find.widgetWithText(SwitchListTile, label));
        await capture(
          tester,
          'category-${label.toLowerCase().replaceAll(' ', '-')}-off',
          'Disable $label notifications',
          route: settingsRoute,
        );
      }
      transport.failingWrites.add(
        '/v1/notifications/preferences/consultations',
      );
      await tap(tester, find.widgetWithText(SwitchListTile, 'Consultations'));
      expect(transport.preferencesData['consultations'], false);
      await capture(
        tester,
        'preference-write-error',
        'Enable consultation category fails → previous switch value and Snackbar retained',
        route: settingsRoute,
      );
      transport.failingWrites.clear();
      await dismissSnackbar(tester);
      await tap(tester, find.widgetWithText(SwitchListTile, 'Consultations'));
      expect(transport.preferencesData['consultations'], true);
      await capture(
        tester,
        'preference-write-retry',
        'Retry enabling consultation category → saved',
        route: settingsRoute,
      );
      transport.failingReads.add('/v1/notifications/preferences');
      await tap(tester, find.text('Refresh status'));
      expect(
        find.text('Could not load your preferences. Please try again.'),
        findsOneWidget,
      );
      await capture(
        tester,
        'preferences-read-error',
        'Refresh preferences fails → inline error',
        route: settingsRoute,
      );
      transport.failingReads.clear();
      final gate = Completer<void>();
      transport.readGates['/v1/notifications/preferences'] = gate;
      await tap(tester, find.text('Refresh status'), waitForResult: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await capture(
        tester,
        'preferences-loading',
        'Retry preferences → loading and switches disabled',
        route: settingsRoute,
      );
      gate.complete();
      await tester.pumpAndSettle();
      await capture(
        tester,
        'preferences-recovered',
        'Preferences response arrives → error cleared and values restored',
        route: settingsRoute,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('inventory notification inbox empty loading paging and archive', (
    tester,
  ) async {
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
    expect(transport.notifications.every((n) => n['status'] == 'read'), true);
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
    expect(transport.notifications.any((n) => n['id'] == 'notice-1'), false);
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
  });

  testWidgets('inventory notification reminder failures and unavailable push', (
    tester,
  ) async {
    await mount(
      tester,
      preparePlatform: (p, g) => p.value = NotificationPermission.authorized,
    );
    transport.failingReads.add(inventoryReminderPath);
    await bookingEntry(tester);
    expect(find.text('Could not load reminder status'), findsOneWidget);
    await capture(
      tester,
      'reminder-read-error',
      'Booking reminder read fails → localized retry',
      route: bookingRoute,
    );
    transport.failingReads.clear();
    await tap(tester, find.text('Try again'));
    await capture(
      tester,
      'reminder-read-retry',
      'Retry reminder read → off and available',
      route: bookingRoute,
    );
    for (final error in [
      'notification_preference_disabled',
      'reminder_expired',
    ]) {
      transport.reminderFailureCode = error;
      await tap(tester, reminderSwitch());
      expect(transport.reminderData['enabled'], false);
      expect(
        find.text(
          error == 'reminder_expired'
              ? 'This appointment is too close to its start time to enable a reminder.'
              : 'Enable appointment notifications in Notification settings first.',
        ),
        findsOneWidget,
      );
      await capture(
        tester,
        error.replaceAll('_', '-'),
        'Reminder rejected by server: $error',
        route: bookingRoute,
      );
      await dismissSnackbar(tester);
    }
    transport.reminderFailureCode = null;
    transport.pushAvailable = false;
    await tap(tester, reminderSwitch());
    await capture(
      tester,
      'push-unavailable',
      'Server push delivery unavailable → no reminder write and explanation',
      route: bookingRoute,
    );
    await dismissSnackbar(tester);
    await tap(tester, find.text('Notification settings'));
    await capture(
      tester,
      'settings-push-unavailable',
      'Settings retains preferences while background push unavailable',
      route: settingsRoute,
    );
    transport.pushAvailable = true;
    await tap(tester, find.text('Refresh status'));
    await capture(
      tester,
      'push-restored',
      'Refresh after push available → device ready',
      route: settingsRoute,
    );
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'inventory notification opening errors unavailable target and appointment route',
    (tester) async {
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
      const route = '/services/appointments/$inventoryNotificationAppointment';
      expect(find.text('Appointment details'), findsOneWidget);
      await capture(
        tester,
        'notification-to-appointment',
        'Open available update → validated UUID appointment route',
        route: route,
      );
      await tap(tester, find.text('Back'));
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
      await mount(tester, prepare: (t) => t.seedInbox(7));
      await inboxEntry(tester);
      final pageGate = Completer<void>();
      transport.readGates['/v1/notifications'] = pageGate;
      await tap(tester, find.text('Load more'), waitForResult: false);
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
      transport.writeGate = Completer<void>();
      await tap(tester, find.text('Mark all read'), waitForResult: false);
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

  testWidgets(
    'inventory notification platform variants and preference restoration',
    (tester) async {
      await mount(
        tester,
        preparePlatform: (p, g) => p.value = NotificationPermission.provisional,
      );
      await inboxEntry(tester);
      await tap(tester, find.byTooltip('Notification settings'));
      expect(find.text('Quiet notifications allowed'), findsOneWidget);
      await capture(
        tester,
        'permission-provisional',
        'Inbox settings → platform quiet notification authorization',
        route: settingsRoute,
      );
      for (final label in ['Expert feedback', 'Service updates']) {
        await tap(tester, find.widgetWithText(SwitchListTile, label));
        await tap(tester, find.widgetWithText(SwitchListTile, label));
        await capture(
          tester,
          'category-${label.toLowerCase().replaceAll(' ', '-')}-on',
          'Re-enable $label → persisted preference',
          route: settingsRoute,
        );
      }
      permissions.value = NotificationPermission.unavailable;
      gateway.available = false;
      await tap(tester, find.text('Refresh status'));
      expect(find.text('Unavailable on this device'), findsOneWidget);
      await capture(
        tester,
        'permission-platform-unavailable',
        'Platform reports unavailable and push SDK unavailable → settings explain delivery boundary',
        route: settingsRoute,
      );
      await tap(tester, find.text('Settings'));
      expect(permissions.settings, 1);
      expect(router.state.uri.path, settingsRoute);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
