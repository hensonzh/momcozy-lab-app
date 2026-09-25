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
import 'package:momcozy_flutter_app/modules/services/presentation/service_timeline.dart';
import '../../support/mom_inventory_transport.dart';
import '../../support/consultation_inventory_transport.dart';
import '../../support/fixture_api_transport.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);
  setUpAll(() => WidgetController.hitTestWarningShouldBeFatal = true);
  late _TimelineTransport transport;
  late MomCozyRuntimeController runtime;
  late GoRouter router;
  String? previous;
  var narrow = false;
  late String variant;
  Future<void> mount(
    WidgetTester tester, {
    void Function(_TimelineTransport)? prepare,
    bool loading = false,
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
    transport = _TimelineTransport();
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
    String route = '/services/episodes/service-episode',
  }) async {
    // A room close awaits endOfFrame before popping. Flush that deferred
    // navigation and settle its transition before recording the returned page.
    await settle(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(router.state.uri.path, route);
    expect(tester.takeException(), isNull);
    final source =
        'test/goldens/ui_inventory/progress-current-$state-$variant.png';
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/ui_inventory/progress-current-$state-$variant.png',
      ),
    );
    final row = {
      'source': source,
      'previous_source': previous,
      'route': route,
      'trigger': action,
      'root_entry': 'Authenticated More → tap Me bottom navigation',
      'evidence':
          'Actual MomCozyFlutterApp/createMomCozyRouter, production repositories and codecs, isolated in-memory HTTP data, fixed clock and timezone',
      'test': 'test/modules/services/progress_current_inventory_test.dart',
    };
    previous = source;
    final output = Platform.environment['MOMCOZY_UI_INVENTORY_DIR'];
    if (output != null) {
      final file = File(
        '$output/journeys/progress-current-$state-$variant.json',
      );
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(row)}\n',
      );
    }
  }

  const overview = '/v1/care/overview';
  const booking = '/v1/care/episodes/service-episode/booking';
  const progressRoute = '/services/episodes/service-episode';
  Future<void> enter(
    WidgetTester tester,
    String chain, {
    void Function(_TimelineTransport)? prepare,
  }) async {
    await mount(tester, prepare: prepare);
    await capture(
      tester,
      '$chain-home',
      'More before expert support',
      route: '/more',
    );
    await tap(tester, find.text('Expert support'));
    await tap(tester, find.text('View my services'));
    await tap(tester, find.text('View service progress'));
  }

  Future<void> finish(WidgetTester tester, String chain) async {
    await tap(tester, find.text('Back'));
    await capture(
      tester,
      '$chain-home-return',
      'Timeline Back → service plan',
      route: '/services/feeding-confidence',
    );
    await tester.pumpWidget(const SizedBox());
  }

  Future<void> refresh(WidgetTester tester) async {
    final scroll = find
        .descendant(
          of: find.byType(ServiceTimeline),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.drag(scroll, const Offset(0, 10000));
    await settle(tester);
    await tester.drag(scroll, const Offset(0, 500));
    await settle(tester);
  }

  for (final compact in [false, true]) {
    testWidgets('current timeline loading missing and retry $compact', (
      tester,
    ) async {
      narrow = compact;
      await mount(tester);
      await capture(
        tester,
        'errors-home',
        'More before expert support',
        route: '/more',
      );
      await tap(tester, find.text('Expert support'));
      await tap(tester, find.text('View my services'));
      transport.readGates[overview] = Completer<void>();
      await tap(tester, find.text('View service progress'));
      await capture(
        tester,
        'initial-loading',
        'Service progress → overview pending',
      );
      transport.failingReads.add(overview);
      transport.readGates[overview]!.complete();
      await tester.pumpAndSettle();
      await capture(tester, 'initial-error', 'Overview 503 → retry card');
      transport.failingReads.clear();
      final saved = transport.episode;
      transport.episode = null;
      await tap(tester, find.text('Try again'));
      await capture(
        tester,
        'episode-missing',
        'Retry returns no matching episode → missing service',
      );
      transport.episode = saved;
      await tap(tester, find.text('Back to home'));
      await capture(
        tester,
        'missing-home-return',
        'Missing service action → service plan',
        route: '/services/feeding-confidence',
      );
      transport.readGates[booking] = Completer<void>();
      await tap(tester, find.text('View service progress'));
      await capture(
        tester,
        'appointments-loading',
        'Overview recovered, appointment context pending',
      );
      transport.failingReads.add(booking);
      transport.readGates[booking]!.complete();
      await tester.pumpAndSettle();
      await capture(
        tester,
        'appointments-error',
        'Appointment read 503 → service identity retained',
      );
      transport.failingReads.clear();
      await tap(tester, find.text('Reload appointments'));
      await capture(
        tester,
        'appointments-recovered',
        'Retry appointment read → purchase-only timeline',
      );
      transport.readGates[overview] = Completer<void>();
      await refresh(tester);
      await capture(
        tester,
        'refresh-loading',
        'Pull refresh → retained timeline with progress',
      );
      transport.failingReads.add(overview);
      transport.readGates[overview]!.complete();
      await tester.pumpAndSettle();
      await capture(
        tester,
        'refresh-error',
        'Overview refresh 503 → full error surface',
      );
      transport.failingReads.clear();
      await tap(tester, find.text('Try again'));
      await capture(
        tester,
        'refresh-recovered',
        'Retry overview → service timeline restored',
      );
      await finish(tester, 'errors');
    });
    testWidgets(
      'current timeline earlier latest appointment and summary $compact',
      (tester) async {
        narrow = compact;
        await enter(tester, 'events', prepare: (t) => t.seedEvents());
        await capture(
          tester,
          'events-latest',
          'Open multi-event service → latest event',
        );
        expect(find.text('Package purchased'), findsOneWidget);
        expect(find.text('Consultation ended'), findsOneWidget);
        expect(find.text('Appointment canceled'), findsOneWidget);
        expect(find.text('Appointment expired'), findsOneWidget);
        expect(find.text('View appointment'), findsOneWidget);
        await tap(tester, find.text('↑ Earlier records'));
        await capture(
          tester,
          'events-earlier',
          'Earlier records → identity and first event',
        );
        expect(find.text('↓ Back to latest records'), findsOneWidget);
        await tap(tester, find.text('↓ Back to latest records'));
        await capture(
          tester,
          'events-latest-return',
          'Back to latest → latest event and footer',
        );
        final current = transport.appointment;
        transport.appointment = Map<String, Object?>.from(
          transport.events.first,
        );
        transport.consultation(
          status: 'closed',
          roomStatus: 'closed',
          endReason: 'completed',
        );
        transport.publishSummary();
        await tap(tester, find.text('View consultation summary'));
        await capture(
          tester,
          'event-summary',
          'Completed event → published summary',
          route: '/services/appointments/completed-event/summary',
        );
        expect(find.text('Published client-facing summary'), findsOneWidget);
        await tap(tester, find.byTooltip('Back'));
        await capture(
          tester,
          'summary-return',
          'Summary Back → original timeline',
        );
        transport.appointment = current;
        transport.roomData['appointment'] = current;
        transport.roomData['consultation'] = null;
        await tap(tester, find.text('View appointment'));
        await capture(
          tester,
          'event-appointment',
          'Confirmed event → appointment detail',
          route: '/services/appointments/service-appointment/room',
        );
        await tap(tester, find.byTooltip('Close appointment details'));
        await capture(
          tester,
          'appointment-return',
          'Appointment Close → timeline',
        );
        await tap(tester, find.text('Book consultation'));
        await capture(
          tester,
          'event-booking',
          'Timeline booking with confirmed appointment → existing appointment detail',
          route: '$progressRoute/booking',
        );
        expect(find.text('Booking details'), findsOneWidget);
        await tap(tester, find.text('Back'));
        await capture(tester, 'booking-return', 'Booking Back → timeline');
        transport.readGates[booking] = Completer<void>();
        await refresh(tester);
        await capture(
          tester,
          'events-refresh-pending',
          'Pull refresh → existing events while appointment context waits',
        );
        transport.failingReads.add(booking);
        transport.readGates[booking]!.complete();
        await tester.pumpAndSettle();
        await capture(
          tester,
          'events-refresh-error',
          'Appointment context 503 → retained old events and retry',
        );
        transport.failingReads.clear();
        await tap(tester, find.text('Reload appointments'));
        await capture(
          tester,
          'events-refresh-recovered',
          'Retry → synced events and latest position',
        );
        transport.events.last['starts_at'] = inventoryMomNow
            .subtract(const Duration(minutes: 10))
            .toIso8601String();
        transport.events.last['ends_at'] = inventoryMomNow
            .add(const Duration(minutes: 50))
            .toIso8601String();
        transport.consultation(status: 'in_progress');
        await refresh(tester);
        await capture(
          tester,
          'event-in-progress',
          'Refresh current consultation → in-progress event',
        );
        expect(find.text('Consultation in progress'), findsOneWidget);
        await tap(tester, find.text('View appointment'));
        await capture(
          tester,
          'in-progress-room',
          'In-progress event → active consultation entry',
          route: '/services/appointments/service-appointment/room',
        );
        await tap(tester, find.byTooltip('Close appointment details'));
        await capture(
          tester,
          'in-progress-return',
          'Close active consultation entry → timeline',
        );
        await finish(tester, 'events');
      },
    );
    testWidgets('current timeline service states and renewal entry $compact', (
      tester,
    ) async {
      narrow = compact;
      await enter(tester, 'states');
      await capture(tester, 'active', 'Active plan → appointment action');
      await tap(tester, find.text('Book consultation'));
      await capture(
        tester,
        'active-booking',
        'Active plan without appointment → booking precheck',
        route: '$progressRoute/booking',
      );
      await tap(tester, find.byTooltip('Close booking check'));
      await capture(
        tester,
        'active-booking-closed',
        'Close precheck → start-confirmation page',
        route: '$progressRoute/booking',
      );
      await tap(tester, find.text('Back'));
      await capture(
        tester,
        'active-booking-return',
        'Booking Back → active timeline',
      );
      for (final status in [
        'provisioning_pending',
        'paused',
        'completed',
        'cancelled',
      ]) {
        transport.episode!['status'] = status;
        transport.episode!['stage'] = status == 'completed'
            ? 'conclusion'
            : 'preparation';
        await refresh(tester);
        await capture(
          tester,
          'state-$status',
          'Refresh server episode $status → supported state and actions',
        );
        expect(find.text('Book consultation'), findsNothing);
        expect(
          find.text('Continue care'),
          status == 'completed' || status == 'cancelled'
              ? findsOneWidget
              : findsNothing,
        );
      }
      await tap(tester, find.text('Continue care'));
      await capture(
        tester,
        'renew-options',
        'Ended service Continue support → renewal options',
        route: '$progressRoute/renew',
      );
      await tap(tester, find.text('Select').first);
      await capture(
        tester,
        'renew-purchase',
        'Select renewal plan → real eligibility dialog',
        route: '$progressRoute/renew',
      );
      await tap(tester, find.byTooltip('Close purchase'));
      await capture(
        tester,
        'renew-purchase-closed',
        'Close eligibility → renewal options',
        route: '$progressRoute/renew',
      );
      await tap(tester, find.byTooltip('Back'));
      await capture(tester, 'renew-return', 'Renewal Back → ended timeline');
      transport.episode!['status'] = 'active';
      transport.episode!['remaining_sessions'] = 0;
      await refresh(tester);
      await capture(
        tester,
        'active-exhausted',
        'Active service with zero remaining → no new booking or renewal',
      );
      expect(find.text('Book consultation'), findsNothing);
      expect(find.text('Continue care'), findsNothing);
      transport.episode!['remaining_sessions'] = 1;
      transport.episode!['ends_at'] = inventoryMomNow
          .subtract(const Duration(days: 1))
          .toIso8601String();
      await refresh(tester);
      await capture(
        tester,
        'active-past-end',
        'Server still active after endsAt → current timeline retains booking action',
      );
      expect(find.text('Book consultation'), findsOneWidget);
      await tap(tester, find.text('Book consultation'));
      await capture(
        tester,
        'past-end-booking',
        'Past-end active plan booking → actual target handling',
        route: '$progressRoute/booking',
      );
      await tap(tester, find.byTooltip('Close booking check'));
      await tap(tester, find.text('Back'));
      await capture(
        tester,
        'past-end-return',
        'Booking Back → unchanged active timeline',
      );
      expect(transport.mutationPaths, isEmpty);
      await finish(tester, 'states');
    });
  }
}

class _TimelineTransport extends ConsultationInventoryTransport {
  final events = <Map<String, Object?>>[];
  void seedEvents() {
    order!['created_at'] = inventoryMomNow
        .subtract(const Duration(days: 4))
        .toIso8601String();
    for (final row in [
      ('completed-event', 'completed', -3),
      ('cancelled-event', 'cancelled', -2),
      ('expired-event', 'expired', -1),
      ('held-event', 'held', 1),
      ('service-appointment', 'confirmed', 2),
    ]) {
      final start = inventoryMomNow.add(Duration(days: row.$3));
      events.add({
        ...appointment!,
        'id': row.$1,
        'status': row.$2,
        'starts_at': start.toIso8601String(),
        'ends_at': start.add(const Duration(hours: 1)).toIso8601String(),
      });
    }
    appointment = events.last;
    roomData['appointment'] = appointment;
  }

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) async {
    if (path.endsWith('/booking')) {
      await readGates[path]?.future;
      check(failingReads.contains(path));
      getPaths.add(path);
      return {
        'episode': episode!,
        'providers': [provider],
        'appointments': events,
        'eligibility': bookingEligibility,
        'server_time': inventoryMomNow.toIso8601String(),
      };
    }
    return super.getJson(path, query: query);
  }
}
