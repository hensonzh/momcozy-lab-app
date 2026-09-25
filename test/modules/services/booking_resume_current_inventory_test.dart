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
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import '../../support/mom_inventory_transport.dart';
import '../../support/service_inventory_transport.dart';
import '../../support/fixture_api_transport.dart';
import '../../support/momcozy_test_fonts.dart';
import '../../support/notification_fakes.dart';
import '../../support/notification_inventory_transport.dart';
import 'package:momcozy_flutter_app/features/notifications/presentation/notification_coordinator.dart';
import 'package:momcozy_flutter_app/features/notifications/presentation/notification_permission_controller.dart';
import 'package:momcozy_flutter_app/features/notifications/domain/notification_permission.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);
  setUpAll(() => WidgetController.hitTestWarningShouldBeFatal = true);
  late _BookingTransport transport;
  late MomCozyRuntimeController runtime;
  late GoRouter router;
  String? previous;
  var narrow = false;
  late String variant;
  NotificationCoordinator? coordinator;
  late FakePlatform permissionPlatform;
  Future<void> mount(
    WidgetTester tester, {
    void Function(_BookingTransport)? prepare,
    bool loading = false,
    bool withNotifications = false,
  }) async {
    previous = null;
    variant = narrow ? '320-2x' : '393-1x';
    tester.platformDispatcher.textScaleFactorTestValue = narrow ? 2 : 1;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    FlutterSecureStorage.setMockInitialValues({});
    tester.view.physicalSize = Size(narrow ? 320 : 393, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    transport = _BookingTransport();
    prepare?.call(transport);
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
        now: () => transport.clock,
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
    coordinator = null;
    if (withNotifications) {
      permissionPlatform = FakePlatform()..next = NotificationPermission.denied;
      coordinator = NotificationCoordinator(
        permission: NotificationPermissionController(permissionPlatform),
        gateway: FakeGateway(),
        store: FakeStore(),
        platformName: 'android',
        onNavigate: router.go,
        onMessage: (_) {},
        onForeground: (_) {},
      );
    }
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
    if (loading) {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    } else {
      await tester.pumpAndSettle();
    }
    expect(router.state.uri.path, '/more');
    addTearDown(() async {
      for (final gate in transport.readGates.values) {
        if (!gate.isCompleted) gate.complete();
      }
      if (transport.writeGate case final gate? when !gate.isCompleted) {
        gate.complete();
      }
      coordinator?.dispose();
      router.dispose();
      runtime.dispose();
      await platform.dispose();
    });
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    if (transport.readGates.values.any((gate) => !gate.isCompleted) ||
        (transport.writeGate != null && !transport.writeGate!.isCompleted) ||
        find.byType(LinearProgressIndicator).evaluate().isNotEmpty ||
        find.byType(CircularProgressIndicator).evaluate().isNotEmpty) {
      await tester.pump(const Duration(milliseconds: 500));
    } else {
      await tester.pumpAndSettle();
    }
  }

  Future<void> tap(WidgetTester tester, Finder target) async {
    if (target.evaluate().isEmpty) {
      await tester.drag(find.byType(Scrollable).last, const Offset(0, 10000));
      await settle(tester);
    }
    if (target.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        target,
        250,
        scrollable: find.byType(Scrollable).last,
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
    String route = '/services/episodes/service-episode/booking',
  }) async {
    // A room close awaits endOfFrame before popping. Flush that deferred
    // navigation and settle its transition before recording the returned page.
    await settle(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(router.state.uri.path, route);
    expect(tester.takeException(), isNull);
    final source =
        'test/goldens/ui_inventory/booking-resume-current-$state-$variant.png';
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/ui_inventory/booking-resume-current-$state-$variant.png',
      ),
    );
    final row = {
      'source': source,
      'previous_source': previous,
      'route': route,
      'trigger': action,
      'root_entry': 'Authenticated More → Expert support',
      'evidence':
          'Actual MomCozyFlutterApp/createMomCozyRouter, production repositories and codecs, isolated in-memory HTTP data, fixed clock and timezone',
      'test':
          'test/modules/services/booking_resume_current_inventory_test.dart',
    };
    previous = source;
    final output = Platform.environment['MOMCOZY_UI_INVENTORY_DIR'];
    if (output != null) {
      final file = File(
        '$output/journeys/booking-resume-current-$state-$variant.json',
      );
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(row)}\n',
      );
    }
  }

  const holds = '/v1/care/episodes/service-episode/holds';
  const confirm = '/v1/care/appointments/service-appointment/confirm';
  const cancel = '/v1/care/appointments/service-appointment/cancel';
  Future<void> enter(
    WidgetTester tester,
    String chain, {
    bool withNotifications = false,
    bool record = true,
  }) async {
    await mount(tester, withNotifications: withNotifications);
    if (record) {
      await capture(
        tester,
        '$chain-home',
        'More before expert support',
        route: '/more',
      );
    }
    await tap(tester, find.text('Expert support'));
    await tap(tester, find.text('View my services'));
    await tap(tester, find.text('Book an appointment'));
    await tap(tester, find.byType(DropdownButtonFormField<String>));
    await tap(tester, find.text('California (CA)').last);
    await tap(
      tester,
      find.text('I need IBCLC support with lactation or feeding.'),
    );
    await tap(tester, find.text('None of these apply right now'));
    await tap(tester, find.text('Continue to time selection'));
    if (record) {
      await capture(
        tester,
        '$chain-slots',
        'Complete precheck → available times',
      );
    }
  }

  Future<void> finish(WidgetTester tester, String chain) async {
    await tap(tester, find.text('Back'));
    await capture(
      tester,
      '$chain-home-return',
      'Booking Back → package detail',
      route: '/services/feeding-confidence',
    );
    await tester.pumpWidget(const SizedBox());
  }

  Future<void> hold(WidgetTester tester) => tap(tester, find.text('60 min'));

  testWidgets('booking reminder configured coordinator permission chain', (
    tester,
  ) async {
    narrow = false;
    await enter(
      tester,
      'configured-reminder',
      withNotifications: true,
      record: false,
    );
    await hold(tester);
    await tap(tester, find.text('Remind me 15 minutes before'));
    await tap(tester, find.text('Confirm appointment'));
    expect(transport.appointment?['status'], 'confirmed');
    expect(find.text('Receive reminders?'), findsOneWidget);
    expect(permissionPlatform.requests, 0);
    await tap(tester, find.text('Continue'));
    expect(permissionPlatform.requests, 1);
    expect(
      router.state.uri.path,
      '/services/appointments/service-appointment/intake',
    );
    await tap(tester, find.text('Back'));
    final toggle = find.widgetWithText(SwitchListTile, 'Appointment reminder');
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
    await tap(tester, toggle);
    expect(find.text('Notifications are off'), findsOneWidget);
    await tap(tester, find.text('Open settings'));
    expect(permissionPlatform.settings, 1);
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
    permissionPlatform.value = NotificationPermission.authorized;
    await coordinator!.refresh();
    await tester.pumpAndSettle();
    await tap(tester, toggle);
    expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
    expect(transport.notificationTransport.reminderData['enabled'], isTrue);
    await capture(
      tester,
      'configured-reminder-enabled',
      'Confirm booking → permission explanation → deny → intake → booking reminder → system settings offer → refreshed authorization → enable',
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  for (final compact in [false, true]) {
    testWidgets('unknown confirm closes to a safe retry $compact', (
      tester,
    ) async {
      narrow = compact;
      await enter(tester, 'confirm');
      await hold(tester);
      transport.failingWrites.add(confirm);
      await tap(tester, find.text('Confirm appointment'));
      final request = Map<String, Object?>.from(transport.requests.last);
      await capture(
        tester,
        'confirm-unknown',
        'Confirm HTTP 503 → unresolved dialog',
      );
      await tap(tester, find.byTooltip('Close time confirmation'));
      await capture(
        tester,
        'confirm-closed',
        'Close unresolved confirmation → page retry action',
      );
      await tester.drag(find.byType(ListView).last, const Offset(0, 10000));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('View selected time'), findsNothing);
      expect(find.text('Retry last submission'), findsOneWidget);
      transport.failingWrites.clear();
      await tester.tap(find.text('Retry last submission'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(transport.requests.last['body'], request['body']);
      await capture(
        tester,
        'confirm-retry-intake',
        'Page retry same confirmation → intake',
        route: '/services/appointments/service-appointment/intake',
      );
      await tap(tester, find.text('Back'));
      await capture(
        tester,
        'confirm-retry-return',
        'Intake Back → confirmed appointment',
      );
      await finish(tester, 'confirm');
    });
    testWidgets('unknown held cancellation close and retry $compact', (
      tester,
    ) async {
      narrow = compact;
      await enter(tester, 'cancel');
      await hold(tester);
      transport.failingWrites.add(cancel);
      await tap(tester, find.text('Choose another time'));
      final request = Map<String, Object?>.from(transport.requests.last);
      await capture(
        tester,
        'cancel-unknown',
        'Reselect held time → cancellation HTTP 503',
      );
      await tap(tester, find.byTooltip('Close time confirmation'));
      await capture(
        tester,
        'cancel-closed',
        'Close unresolved held cancellation → page retry',
      );
      transport.failingWrites.clear();
      await tap(tester, find.text('Retry last submission'));
      expect(transport.requests.last['body'], request['body']);
      expect(transport.appointment?['status'], 'cancelled');
      await capture(
        tester,
        'cancel-recovered',
        'Page retries original cancel → picker restored',
      );
      await finish(tester, 'cancel');
    });
    testWidgets('unknown hold leave and reenter $compact', (tester) async {
      narrow = compact;
      await enter(tester, 'hold');
      transport.failingWrites.add(holds);
      await hold(tester);
      final request = Map<String, Object?>.from(transport.requests.last);
      await capture(tester, 'hold-unknown', 'Hold HTTP 503 → retry action');
      await tap(tester, find.text('Back'));
      await capture(
        tester,
        'hold-left',
        'Leave unresolved booking → package detail',
        route: '/services/feeding-confidence',
      );
      transport.failingWrites.clear();
      await tap(tester, find.text('Book an appointment'));
      expect(find.text('Retry last submission'), findsNothing);
      await capture(
        tester,
        'hold-reentered',
        'Reenter → server eligibility retained, no active hold and no local pending retry',
      );
      await hold(tester);
      expect(transport.requests.last['headers'], isNot(request['headers']));
      await capture(
        tester,
        'hold-new-request',
        'Select time after reentry → new hold key and review',
      );
      await tap(tester, find.text('Choose another time'));
      await finish(tester, 'hold');
    });
    testWidgets('selected reminder unavailable after confirmation $compact', (
      tester,
    ) async {
      narrow = compact;
      await enter(tester, 'reminder');
      await hold(tester);
      await tap(tester, find.text('Remind me 15 minutes before'));
      await capture(
        tester,
        'reminder-selected',
        'Select reminder before confirming',
      );
      await tap(tester, find.text('Confirm appointment'));
      expect(transport.appointment?['status'], 'confirmed');
      expect(
        find.text(
          'Your appointment is saved. Background reminders are unavailable on this device.',
        ),
        findsOneWidget,
      );
      await capture(
        tester,
        'reminder-unavailable-intake',
        'Confirm without notification coordinator → saved appointment snackbar and intake',
        route: '/services/appointments/service-appointment/intake',
      );
      await tester.pump(const Duration(seconds: 5));
      await settle(tester);
      await capture(
        tester,
        'reminder-message-dismissed',
        'Unavailable reminder snackbar times out → intake remains',
        route: '/services/appointments/service-appointment/intake',
      );
      await tap(tester, find.text('Back'));
      await capture(
        tester,
        'reminder-return',
        'Intake Back → saved appointment and disabled reminder tile',
      );
      await finish(tester, 'reminder');
    });
  }
}

class _BookingTransport extends ServiceInventoryTransport {
  _BookingTransport() {
    ownPlan();
  }
  DateTime clock = inventoryMomNow;
  final codes = <String, String>{};
  final notificationTransport = NotificationInventoryTransport();
  @override
  Future<Map<String, Object?>> putJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    if (path == '/v1/notifications/appointments/service-appointment/reminder') {
      return notificationTransport.putJson(
        inventoryReminderPath,
        body: body,
        headers: headers,
      );
    }
    return super.putJson(path, body: body, headers: headers);
  }

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) async {
    if (path.startsWith('/v1/notifications')) {
      return notificationTransport.getJson(path, query: query);
    }
    final data = await super.getJson(path, query: query);
    return data.containsKey('server_time')
        ? {...data, 'server_time': clock.toIso8601String()}
        : data;
  }

  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    if (path.startsWith('/v1/notifications')) {
      return notificationTransport.postJson(path, body: body, headers: headers);
    }
    if (codes[path] case final code?) {
      requests.add({
        'path': path,
        'body': Map<String, Object?>.from(body),
        'headers': Map<String, String>.from(headers),
      });
      mutationPaths.add(path);
      if (code == 'eligibility_required') {
        bookingEligibility = null;
      }
      throw ApiHttpException.fromBody({
        'http_status': 409,
        'body': {
          'error': {'code': code},
        },
      });
    }
    final data = await super.postJson(path, body: body, headers: headers);
    if (path.endsWith('/holds')) {
      data['hold_expires_at'] = clock
          .add(const Duration(minutes: 10))
          .toIso8601String();
    }
    if (path.endsWith('/booking-eligibility')) {
      data['expires_at'] = clock
          .add(const Duration(hours: 1))
          .toIso8601String();
    }
    return data;
  }
}
