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
import '../../support/fake_agent_voice.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);
  setUpAll(() => WidgetController.hitTestWarningShouldBeFatal = true);
  late _Transport transport;
  late MomCozyRuntimeController runtime;
  late GoRouter router;
  String? previous;
  late String variant;
  late String entry;
  var narrow = false;
  late _Platform permissions;
  late _Gateway gateway;
  late NotificationCoordinator coordinator;
  Future<void> mount(
    WidgetTester tester, {
    void Function(_Transport)? prepare,
    void Function(_Platform, _Gateway)? preparePlatform,
  }) async {
    previous = null;
    variant = narrow ? '320-2x' : '393-1x';
    tester.platformDispatcher.textScaleFactorTestValue = narrow ? 2 : 1;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    permissions = _Platform();
    gateway = _Gateway();
    FlutterSecureStorage.setMockInitialValues({});
    tester.view.physicalSize = Size(narrow ? 320 : 393, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    transport = _Transport();
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
        agentVoicePlaybackPlayer: ImmediateAgentVoicePlaybackPlayer(),
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
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
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
        'test/goldens/ui_inventory/notification-permission-current-$state-$variant.png';
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/ui_inventory/notification-permission-current-$state-$variant.png',
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
          'test/features/notifications/notification_permission_current_inventory_test.dart',
    };
    previous = source;
    final output = Platform.environment['MOMCOZY_UI_INVENTORY_DIR'];
    if (output != null) {
      final file = File(
        '$output/journeys/notification-permission-current-$state-$variant.json',
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

  Finder preference() =>
      find.byKey(const ValueKey('notification-preference-appointments'));
  Future<void> settingsEntry(WidgetTester tester) async {
    await inboxEntry(tester);
    await capture(tester, '$entry-inbox', 'More → notification center');
    await tap(tester, find.byTooltip('Notification settings'));
    await capture(
      tester,
      '$entry-ready',
      'Notification center settings → preferences',
      route: settingsRoute,
    );
  }

  Future<void> settingsCapture(
    WidgetTester tester,
    String name,
    String action,
  ) => capture(tester, name, action, route: settingsRoute);
  Future<void> returnMore(WidgetTester tester) async {
    await tap(tester, find.byTooltip('返回'));
    await capture(
      tester,
      '$entry-inbox-return',
      'Settings back → notification center',
    );
    await tap(tester, find.byTooltip('Back'));
    await capture(
      tester,
      '$entry-more-return',
      'Notification center back → More',
      route: '/more',
    );
    await tester.pumpWidget(const SizedBox());
  }

  for (final compact in [false, true]) {
    testWidgets(
      'notification permission education cancellation denial and settings $compact',
      (tester) async {
        narrow = compact;
        entry = 'education';
        await mount(
          tester,
          prepare: (t) => t.preferencesData['appointments'] = false,
        );
        await settingsEntry(tester);
        await tap(tester, preference());
        expect(find.text('Receive reminders?'), findsOneWidget);
        await settingsCapture(
          tester,
          'education-dialog',
          'Enable appointments → pre-permission education',
        );
        await tester.tapAt(const Offset(3, 3));
        await settle(tester);
        expect(find.text('Receive reminders?'), findsNothing);
        expect(permissions.requests, 0);
        expect(transport.preferencesData['appointments'], false);
        await settingsCapture(
          tester,
          'education-barrier-dismissed',
          'Tap outside education → dismissed, preference unchanged and feedback',
        );
        await dismissSnackbar(tester);
        await settingsCapture(
          tester,
          'education-feedback-dismissed',
          'Feedback timeout → original settings',
        );
        await tap(tester, preference());
        await settingsCapture(
          tester,
          'education-reopened',
          'Retry enable → education again',
        );
        await tap(tester, find.text('Not now'));
        expect(permissions.requests, 0);
        await settingsCapture(
          tester,
          'education-not-now',
          'Not now → no native permission request, preference stays off',
        );
        await dismissSnackbar(tester);
        await tap(tester, preference());
        await settingsCapture(
          tester,
          'education-before-back',
          'Enable again → education before back',
        );
        await tester.binding.handlePopRoute();
        await settle(tester);
        expect(find.text('Receive reminders?'), findsNothing);
        expect(permissions.requests, 0);
        await settingsCapture(
          tester,
          'education-back-dismissed',
          'Framework back → education dismissed with off feedback',
        );
        await dismissSnackbar(tester);
        await tap(tester, preference());
        await settingsCapture(
          tester,
          'education-before-denial',
          'Enable again → education before platform denial',
        );
        permissions.next = NotificationPermission.denied;
        await tap(tester, find.text('Continue'));
        expect(permissions.requests, 1);
        expect(transport.preferencesData['appointments'], false);
        expect(find.text('Off in system settings'), findsOneWidget);
        await settingsCapture(
          tester,
          'education-denied',
          'Continue → simulated native denial, settings off and Snackbar',
        );
        await dismissSnackbar(tester);
        await tap(tester, preference());
        expect(find.text('Notifications are off'), findsOneWidget);
        await settingsCapture(
          tester,
          'offer-settings-dialog',
          'Enable after denial → system-settings explanation',
        );
        await tap(tester, find.text('Not now'));
        expect(permissions.settings, 0);
        await settingsCapture(
          tester,
          'offer-settings-not-now',
          'Not now → do not open system settings, keep preference off',
        );
        await dismissSnackbar(tester);
        await tap(tester, preference());
        await settingsCapture(
          tester,
          'offer-settings-reopened',
          'Retry after denied permission → settings explanation again',
        );
        await tap(tester, find.text('Open settings'));
        expect(permissions.settings, 1);
        expect(transport.preferencesData['appointments'], false);
        await settingsCapture(
          tester,
          'offer-settings-opened',
          'Open settings → fake platform invoked; preference remains off, no OS-window claim',
        );
        await dismissSnackbar(tester);
        permissions.value = NotificationPermission.authorized;
        await tap(tester, find.text('Refresh status'));
        await settingsCapture(
          tester,
          'permission-restored',
          'Refresh after simulated system authorization → allowed, preference still off',
        );
        await tap(tester, preference());
        expect(transport.preferencesData['appointments'], true);
        expect(permissions.requests, 1);
        await settingsCapture(
          tester,
          'permission-restored-enabled',
          'Enable after authorization → true persisted without re-request',
        );
        await tap(tester, preference());
        expect(transport.preferencesData['appointments'], false);
        await settingsCapture(
          tester,
          'permission-restored-disabled',
          'Disable appointments → false persisted',
        );
        await returnMore(tester);
      },
    );

    testWidgets(
      'notification permission request failure retry and direct settings error $compact',
      (tester) async {
        narrow = compact;
        entry = 'request';
        await mount(
          tester,
          prepare: (t) => t.preferencesData['appointments'] = false,
        );
        await settingsEntry(tester);
        permissions.failRequest = true;
        await tap(tester, preference());
        await settingsCapture(
          tester,
          'request-error-education',
          'Enable → education before platform exception',
        );
        await tap(tester, find.text('Continue'));
        expect(permissions.requests, 1);
        expect(transport.preferencesData['appointments'], false);
        await settingsCapture(
          tester,
          'request-error',
          'Continue → platform request throws, preference remains off with feedback',
        );
        await dismissSnackbar(tester);
        await settingsCapture(
          tester,
          'request-error-dismissed',
          'Request-error feedback timeout → no permission change',
        );
        permissions.failRequest = false;
        await tap(tester, preference());
        await settingsCapture(
          tester,
          'request-retry-education',
          'Retry enable → repeat permission education',
        );
        await tap(tester, find.text('Continue'));
        expect(permissions.requests, 2);
        expect(transport.preferencesData['appointments'], true);
        await settingsCapture(
          tester,
          'request-authorized',
          'Continue → fake platform grants permission, registration and preference save succeed',
        );
        permissions.failSettings = true;
        await tap(tester, find.text('Settings'));
        expect(
          find.text('System settings are unavailable on this device.'),
          findsOneWidget,
        );
        await settingsCapture(
          tester,
          'direct-settings-error',
          'Direct Settings → platform opening error and Snackbar',
        );
        await dismissSnackbar(tester);
        await settingsCapture(
          tester,
          'direct-settings-error-dismissed',
          'Settings error timeout → page and enabled category preserved',
        );
        permissions.failSettings = false;
        await tap(tester, find.text('Settings'));
        expect(permissions.settings, 2);
        await settingsCapture(
          tester,
          'direct-settings-retry',
          'Direct Settings retry → platform invoked successfully',
        );
        await returnMore(tester);
      },
    );

    testWidgets(
      'notification registration waiting errors token server and recovery $compact',
      (tester) async {
        narrow = compact;
        entry = 'registration';
        await mount(
          tester,
          prepare: (t) => t.preferencesData['appointments'] = false,
          preparePlatform: (p, g) =>
              p.value = NotificationPermission.authorized,
        );
        await settingsEntry(tester);
        transport.registrationGate = Completer<void>();
        await tap(tester, find.text('Refresh status'));
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        await settingsCapture(
          tester,
          'registration-waiting',
          'Refresh status → installation request pending, categories disabled',
        );
        transport.failingWrites.add('/v1/notifications/installations');
        transport.registrationGate!.complete();
        await settle(tester);
        expect(
          find.text('Could not sync notification settings. Please try again.'),
          findsOneWidget,
        );
        await settingsCapture(
          tester,
          'registration-http-error',
          'Registration 503 → settings error, category values retained',
        );
        transport.failingWrites.clear();
        transport.tokenRegistered = false;
        await tap(tester, find.text('Refresh status'));
        await settingsCapture(
          tester,
          'registration-pending',
          'Refresh → server returns token binding pending',
        );
        await tap(tester, preference());
        expect(transport.preferencesData['appointments'], false);
        expect(
          transport.mutationPaths.where(
            (p) => p.endsWith('/preferences/appointments'),
          ),
          isEmpty,
        );
        await settingsCapture(
          tester,
          'registration-pending-enable',
          'Enable while token registration pending → Snackbar, no preference write',
        );
        await dismissSnackbar(tester);
        transport.tokenRegistered = true;
        gateway.failToken = true;
        await tap(tester, find.text('Refresh status'));
        expect(
          find.text(
            'Could not register this device. Try again when connected.',
          ),
          findsOneWidget,
        );
        await settingsCapture(
          tester,
          'registration-token-error',
          'Refresh → SDK token exception',
        );
        gateway.failToken = false;
        gateway.nullToken = true;
        await tap(tester, find.text('Refresh status'));
        await settingsCapture(
          tester,
          'registration-null-token',
          'Refresh → SDK returns no token, registration pending',
        );
        gateway.nullToken = false;
        transport.pushAvailable = false;
        await tap(tester, find.text('Refresh status'));
        await settingsCapture(
          tester,
          'registration-server-unavailable',
          'Refresh → server push unavailable, in-app inbox remains',
        );
        transport.pushAvailable = true;
        gateway.available = false;
        await tap(tester, find.text('Refresh status'));
        await settingsCapture(
          tester,
          'registration-sdk-unavailable',
          'Refresh → SDK unavailable, in-app inbox remains',
        );
        gateway.available = true;
        await tap(tester, find.text('Refresh status'));
        expect(coordinator.pushReady, true);
        await settingsCapture(
          tester,
          'registration-recovered',
          'Refresh → registration succeeds, error clears',
        );
        await tap(tester, preference());
        expect(transport.preferencesData['appointments'], true);
        await settingsCapture(
          tester,
          'registration-recovered-enabled',
          'Enable after recovery → preference saved true',
        );
        await returnMore(tester);
      },
    );
  }
}

class _Platform extends FakePlatform {
  bool failRequest = false, failSettings = false;
  @override
  Future<NotificationPermission> requestPermission() async {
    if (failRequest) {
      requests++;
      throw StateError('Isolated platform request error');
    }
    return super.requestPermission();
  }

  @override
  Future<void> openSettings() async {
    if (failSettings) {
      settings++;
      throw StateError('Isolated settings error');
    }
    await super.openSettings();
  }
}

class _Gateway extends FakeGateway {
  bool failToken = false, nullToken = false;
  @override
  Future<String?> token() async {
    if (failToken) throw StateError('Isolated token failure');
    if (nullToken) return null;
    return super.token();
  }
}

class _Transport extends NotificationInventoryTransport {
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
