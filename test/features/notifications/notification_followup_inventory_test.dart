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
  late _FollowupTransport transport;
  late MomCozyRuntimeController runtime;
  late GoRouter router;
  String? previous;
  late FakePlatform permissions;
  late _Gateway gateway;
  late NotificationCoordinator coordinator;
  Future<void> mount(
    WidgetTester tester, {
    void Function(_FollowupTransport)? prepare,
    void Function(FakePlatform, FakeGateway)? preparePlatform,
  }) async {
    previous = null;
    permissions = FakePlatform();
    gateway = _Gateway();
    FlutterSecureStorage.setMockInitialValues({});
    tester.view.physicalSize = const Size(393, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    transport = _FollowupTransport();
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
      if (transport.registrationGate case final gate? when !gate.isCompleted) {
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
    String route = '/notifications',
  }) async {
    // Commit edits and finish the input hint's fade without settling spinners.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(router.state.uri.path, route);
    expect(tester.takeException(), isNull);
    final source =
        'test/goldens/ui_inventory/notification-followup-$state-393.png';
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/ui_inventory/notification-followup-$state-393.png',
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
          'test/features/notifications/notification_followup_inventory_test.dart',
    };
    previous = source;
    final output = Platform.environment['MOMCOZY_UI_INVENTORY_DIR'];
    if (output != null) {
      final file = File('$output/journeys/notification-followup-$state.json');
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(row)}\n',
      );
    }
  }

  const bookingRoute = '/services/episodes/service-episode/booking';
  const settingsRoute = '/notifications/settings';
  Future<void> bookingEntry(WidgetTester tester) async {
    await capture(
      tester,
      'booking-more',
      'Authenticated More entry',
      route: '/more',
    );
    await tap(tester, find.byType(MomExpertPlanEntry));
    await capture(
      tester,
      'booking-catalog',
      'More Expert support → service catalog',
      route: '/services',
    );
    await tap(tester, find.text('View my services'));
    await capture(
      tester,
      'booking-package',
      'My service → purchased package details',
      route: '/services/feeding-confidence',
    );
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

  testWidgets(
    'notification registration waiting failure pending and retry from booking',
    (tester) async {
      await mount(
        tester,
        preparePlatform: (p, g) => p.value = NotificationPermission.authorized,
      );
      await bookingEntry(tester);
      await capture(
        tester,
        'reminder-ready',
        'Appointment booking → reminder off',
        route: bookingRoute,
      );
      transport.registrationGate = Completer<void>();
      transport.tokenRegistered = false;
      await tap(tester, reminderSwitch());
      expect(find.byType(LinearProgressIndicator), findsWidgets);
      expect(
        transport.mutationPaths.where((p) => p == inventoryReminderPath),
        isEmpty,
      );
      await capture(
        tester,
        'registration-waiting',
        'Enable reminder → device registration request pending',
        route: bookingRoute,
      );
      transport.registrationGate!.complete();
      await settle(tester);
      expect(
        find.text('Device registration is pending. Please try again.'),
        findsOneWidget,
      );
      await capture(
        tester,
        'registration-pending',
        'Registration returned no token binding → reminder remains off with Snackbar',
        route: bookingRoute,
      );
      await dismissSnackbar(tester);
      transport.tokenRegistered = true;
      transport.failingWrites.add('/v1/notifications/installations');
      await tap(tester, reminderSwitch());
      expect(
        find.text('Could not sync notification settings. Please try again.'),
        findsOneWidget,
      );
      await capture(
        tester,
        'registration-http-error',
        'Retry reminder → installation HTTP error and feedback',
        route: bookingRoute,
      );
      await dismissSnackbar(tester);
      transport.failingWrites.clear();
      gateway.failToken = true;
      await tap(tester, reminderSwitch());
      expect(
        find.text('Could not register this device. Try again when connected.'),
        findsOneWidget,
      );
      await capture(
        tester,
        'registration-token-error',
        'Retry reminder → push token error and feedback',
        route: bookingRoute,
      );
      expect(
        transport.mutationPaths.where((p) => p == inventoryReminderPath),
        isEmpty,
      );
      await dismissSnackbar(tester);
      gateway.failToken = false;
      await tap(tester, reminderSwitch());
      expect(transport.reminderData['enabled'], isTrue);
      await capture(
        tester,
        'registration-retry-enabled',
        'Retry after token recovery → reminder saved and enabled',
        route: bookingRoute,
      );
      await tap(tester, reminderSwitch());
      expect(transport.reminderData['enabled'], isFalse);
      await capture(
        tester,
        'registration-disabled',
        'Turn reminder off → saved disabled',
        route: bookingRoute,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('notification settings registration errors refresh and return', (
    tester,
  ) async {
    await mount(
      tester,
      preparePlatform: (p, g) => p.value = NotificationPermission.authorized,
    );
    await capture(
      tester,
      'settings-more',
      'Authenticated More entry',
      route: '/more',
    );
    await inboxEntry(tester);
    await capture(tester, 'settings-inbox', 'More notifications → inbox');
    await tap(tester, find.byTooltip('Notification settings'));
    await capture(
      tester,
      'settings-ready',
      'Inbox settings → registered device',
      route: settingsRoute,
    );
    transport.registrationGate = Completer<void>();
    await tap(tester, find.text('Refresh status'));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await capture(
      tester,
      'settings-refresh-waiting',
      'Refresh status → registration pending and categories disabled',
      route: settingsRoute,
    );
    transport.failingWrites.add('/v1/notifications/installations');
    transport.registrationGate!.complete();
    await settle(tester);
    expect(
      find.text('Could not sync notification settings. Please try again.'),
      findsOneWidget,
    );
    await capture(
      tester,
      'settings-registration-error',
      'Registration HTTP failure → settings error and unavailable delivery',
      route: settingsRoute,
    );
    transport.failingWrites.clear();
    transport.tokenRegistered = false;
    await tap(tester, find.text('Refresh status'));
    expect(
      find.text('Device registration is pending. Please try again.'),
      findsOneWidget,
    );
    await capture(
      tester,
      'settings-registration-pending',
      'Refresh → server token registration pending',
      route: settingsRoute,
    );
    transport.tokenRegistered = true;
    gateway.failToken = true;
    await tap(tester, find.text('Refresh status'));
    expect(
      find.text('Could not register this device. Try again when connected.'),
      findsOneWidget,
    );
    await capture(
      tester,
      'settings-token-error',
      'Refresh → SDK token unavailable',
      route: settingsRoute,
    );
    gateway.failToken = false;
    await tap(tester, find.text('Refresh status'));
    expect(coordinator.pushReady, isTrue);
    await capture(
      tester,
      'settings-recovered',
      'Refresh → device registered and service notifications available',
      route: settingsRoute,
    );
    await tap(tester, find.byTooltip('Back'));
    await capture(tester, 'settings-inbox-return', 'Settings back → inbox');
    await tap(tester, find.byKey(const ValueKey('notifications-back')));
    await capture(
      tester,
      'settings-more-return',
      'Inbox back → original More',
      route: '/more',
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('notification actual long press tooltips and dismissals', (
    tester,
  ) async {
    await mount(tester, prepare: (t) => t.seedInbox(1));
    await capture(
      tester,
      'tooltip-more',
      'Authenticated More entry',
      route: '/more',
    );
    await inboxEntry(tester);
    await capture(
      tester,
      'tooltip-inbox',
      'More notifications → one unread notification',
    );
    for (final label in [
      'Refresh notifications',
      'Notification settings',
      'Archive notification',
      'Back',
    ]) {
      final key = label.toLowerCase().replaceAll(' ', '-');
      await tester.longPress(find.byTooltip(label));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(label), findsOneWidget);
      await capture(
        tester,
        'tooltip-$key',
        'Long press $label → actual Tooltip overlay',
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text(label), findsNothing);
      await capture(
        tester,
        'tooltip-$key-dismissed',
        'Tooltip timeout → inbox retained, action not invoked',
      );
    }
    expect(transport.notifications, hasLength(1));
    expect(transport.notifications.single['status'], 'unread');
    await tap(tester, find.byTooltip('Archive notification'));
    expect(transport.notifications, isEmpty);
    await capture(
      tester,
      'tooltip-archive-clicked',
      'Short tap Archive notification → row removed and empty inbox',
    );
    await tap(tester, find.byKey(const ValueKey('notifications-back')));
    await capture(
      tester,
      'tooltip-more-return',
      'Back button short tap → More',
      route: '/more',
    );
    await tester.pumpWidget(const SizedBox());
  });
}

class _Gateway extends FakeGateway {
  bool failToken = false;
  @override
  Future<String?> token() async {
    if (failToken) throw StateError('Isolated SDK token failure');
    return super.token();
  }
}

class _FollowupTransport extends NotificationInventoryTransport {
  Completer<void>? registrationGate;
  bool tokenRegistered = true;
  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    if (path.endsWith('/installations')) await registrationGate?.future;
    final result = await super.postJson(path, body: body, headers: headers);
    if (path.endsWith('/installations')) {
      return {
        ...result,
        'token_registered': tokenRegistered && body['token'] != null,
      };
    }
    return result;
  }
}
