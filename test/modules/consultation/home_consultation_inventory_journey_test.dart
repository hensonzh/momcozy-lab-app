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
import 'package:momcozy_flutter_app/shared/widgets/mom_companion_widgets.dart';
import '../../support/mom_inventory_transport.dart';
import '../../support/consultation_inventory_transport.dart';
import '../../support/fixture_api_transport.dart';
import '../../support/consultation_inventory_devices.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);
  setUpAll(() => WidgetController.hitTestWarningShouldBeFatal = true);
  late ConsultationInventoryTransport transport;
  late MomCozyRuntimeController runtime;
  late GoRouter router;
  String? previous;
  late ConsultationInventoryDevices devices;
  Future<void> mount(
    WidgetTester tester, {
    void Function(ConsultationInventoryTransport)? prepare,
    bool loading = false,
    double width = 393,
    double textScale = 1,
  }) async {
    previous = null;
    devices = ConsultationInventoryDevices()..install();
    FlutterSecureStorage.setMockInitialValues({});
    tester.view.physicalSize = Size(width, 844);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    transport = ConsultationInventoryTransport();
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
    await tester.pumpWidget(
      MomCozyFlutterApp(
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
      expect(devices.calls, isNot(contains('getUserMedia')));
      for (final gate in transport.readGates.values) {
        if (!gate.isCompleted) gate.complete();
      }
      if (transport.writeGate case final gate? when !gate.isCompleted) {
        gate.complete();
      }
      router.dispose();
      runtime.dispose();
      await platform.dispose();
    });
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
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  Future<void> capture(
    WidgetTester tester,
    String state,
    String action, {
    String route = '/services/appointments/service-appointment/room',
  }) async {
    // Commit edits and finish the input hint's fade without settling spinners.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(router.state.uri.path, route);
    expect(tester.takeException(), isNull);
    final suffix =
        '${tester.view.physicalSize.width.round()}${tester.platformDispatcher.textScaleFactor > 1 ? '-2x' : ''}';
    final source =
        'test/goldens/ui_inventory/home-consultation-journey-$state-$suffix.png';
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/ui_inventory/home-consultation-journey-$state-$suffix.png',
      ),
    );
    final row = {
      'source': source,
      'previous_source': previous,
      'route': route,
      'trigger': action,
      'root_entry': 'Authenticated More → Expert support → owned service',
      'evidence':
          'Actual MomCozyFlutterApp/createMomCozyRouter, production repositories/codecs and LiveKit device checks; isolated HTTP and native method channels, sandbox room, fixed clock/timezone; no real OS permission dialog or remote media',
      'test':
          'test/modules/consultation/home_consultation_inventory_journey_test.dart',
    };
    previous = source;
    final output = Platform.environment['MOMCOZY_UI_INVENTORY_DIR'];
    if (output != null) {
      final file = File(
        '$output/journeys/home-consultation-journey-$state-$suffix.json',
      );
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(row)}\n',
      );
    }
  }

  Future<void> homeEntry(WidgetTester tester) async {
    await tap(tester, find.byType(MomExpertPlanEntry));
    await tap(tester, find.text('View my services'));
    await tap(tester, find.text('Book an appointment'));
    await tap(
      tester,
      find.widgetWithText(OutlinedButton, 'Prepare for your consultation'),
    );
    expect(
      router.state.uri.path,
      '/services/appointments/service-appointment/room',
    );
    expect(find.byTooltip('Close appointment details'), findsOneWidget);
  }

  testWidgets('inventory home expired consultation window', (tester) async {
    await mount(
      tester,
      prepare: (transport) {
        transport.roomData['demo_early_join'] = false;
        transport.roomData['opens_at'] = inventoryMomNow
            .subtract(const Duration(hours: 2))
            .toIso8601String();
        transport.roomData['closes_at'] = inventoryMomNow
            .subtract(const Duration(minutes: 1))
            .toIso8601String();
      },
    );
    await homeEntry(tester);
    expect(find.text('Book another appointment'), findsOneWidget);
    await capture(
      tester,
      'window-expired',
      'Expert support appointment → expired entry window in preparation',
    );
    await tap(tester, find.text('Book another appointment'));
    expect(router.state.uri.path, '/services/episodes/service-episode/booking');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final narrow in [false, true]) {
    testWidgets(
      'inventory home consultation nested cancellation ${narrow ? "320/2" : "393/1"}',
      (tester) async {
        await mount(
          tester,
          width: narrow ? 320 : 393,
          textScale: narrow ? 2 : 1,
        );
        await homeEntry(tester);
        await capture(
          tester,
          'preparation',
          'Owned service → appointment preparation',
        );
        await tester.tapAt(const Offset(2, 20));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Close appointment details'), findsOneWidget);
        await capture(
          tester,
          'outside-dismiss-blocked',
          'Tap outside appointment dialog → modal remains open',
        );
        await tap(tester, find.text('Cancel appointment'));
        await capture(
          tester,
          'cancel-confirm',
          'Cancel appointment → nested confirmation dialog',
        );
        await tap(tester, find.text('Keep appointment'));
        expect(find.byTooltip('Close appointment details'), findsOneWidget);
        expect(
          transport.mutationPaths.where((p) => p.endsWith('/cancel')),
          isEmpty,
        );
        await capture(
          tester,
          'cancel-kept-home',
          'Keep appointment → nested dialog and preparation close; no cancellation mutation',
        );
        await tap(tester, find.byTooltip('Close appointment details'));
        await capture(
          tester,
          'cancel-kept-booking',
          'Leave preparation without canceling',
          route: '/services/episodes/service-episode/booking',
        );
        await tap(
          tester,
          find.widgetWithText(OutlinedButton, 'Prepare for your consultation'),
        );
        await capture(
          tester,
          'reopened',
          'View appointment again → preparation reopens',
        );
        await tap(tester, find.byTooltip('Close appointment details'));
        await capture(
          tester,
          'closed-home',
          'Close preparation → booking page',
          route: '/services/episodes/service-episode/booking',
        );
      },
    );
    testWidgets(
      'inventory home consultation intake route and return ${narrow ? "320/2" : "393/1"}',
      (tester) async {
        await mount(
          tester,
          width: narrow ? 320 : 393,
          textScale: narrow ? 2 : 1,
        );
        transport.roomData['intake_ready'] = false;
        transport.intake = null;
        await homeEntry(tester);
        await capture(
          tester,
          'intake-required',
          'Home preparation room context requires intake before joining',
        );
        await tap(tester, find.text('View intake form'));
        const route = '/services/appointments/service-appointment/intake';
        expect(router.state.uri.path, route);
        await capture(
          tester,
          'intake',
          'Preparation View intake → dismiss home modal then push actual intake page',
          route: route,
        );
        await tap(tester, find.text('Back'));
        await capture(
          tester,
          'intake-return-home',
          'Close intake → appointment preparation',
        );
      },
    );
  }
  testWidgets('inventory home consultation load failure retry', (tester) async {
    await mount(tester);
    await tap(tester, find.byType(MomExpertPlanEntry));
    await tap(tester, find.text('View my services'));
    await tap(tester, find.text('Book an appointment'));
    final button = find.widgetWithText(
      OutlinedButton,
      'Prepare for your consultation',
    );
    const path = '/v1/care/appointments/service-appointment/room';
    final gate = Completer<void>();
    transport.readGates[path] = gate;
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await capture(
      tester,
      'loading',
      'View appointment → room context pending in modal above home',
    );
    transport.failingReads.add(path);
    gate.complete();
    await tester.pumpAndSettle();
    await capture(
      tester,
      'load-error',
      'Room context fails → error and retry within home modal',
    );
    transport.failingReads.clear();
    await tap(tester, find.text('Try again'));
    expect(find.text('Start consultation'), findsOneWidget);
    await capture(
      tester,
      'load-recovered',
      'Retry room context → appointment preparation',
    );
    await tap(tester, find.byTooltip('Close appointment details'));
    await capture(
      tester,
      'load-return-home',
      'Close recovered preparation → booking page',
      route: '/services/episodes/service-episode/booking',
    );
  });
}
