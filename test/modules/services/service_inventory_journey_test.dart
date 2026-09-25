import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:momcozy_flutter_app/domain/baby/baby_profile.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/native/p0_platform_interfaces.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/modules/mom/presentation/mom_home_sections.dart';
import 'package:momcozy_flutter_app/modules/mom/presentation/me_home_page.dart';
import 'package:momcozy_flutter_app/modules/services/presentation/service_catalog_page.dart';
import '../../support/mom_inventory_transport.dart';
import '../../support/service_inventory_transport.dart';
import '../../support/fixture_api_transport.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);
  setUpAll(() => WidgetController.hitTestWarningShouldBeFatal = true);
  late ServiceInventoryTransport transport;
  late MomCozyRuntimeController runtime;
  late GoRouter router;
  String? previous;
  Future<void> mount(
    WidgetTester tester, {
    void Function(ServiceInventoryTransport)? prepare,
    bool loading = false,
  }) async {
    previous = null;
    FlutterSecureStorage.setMockInitialValues({});
    tester.view.physicalSize = const Size(393, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    transport = ServiceInventoryTransport();
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
    String route = '/services/feeding-confidence',
  }) async {
    // Commit edits and finish the input hint's fade without settling spinners.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(router.state.uri.path, route);
    expect(tester.takeException(), isNull);
    final source = 'test/goldens/ui_inventory/service-journey-$state-393.png';
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/ui_inventory/service-journey-$state-393.png',
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
      'test': 'test/modules/services/service_inventory_journey_test.dart',
    };
    previous = source;
    final output = Platform.environment['MOMCOZY_UI_INVENTORY_DIR'];
    if (output != null) {
      final file = File('$output/journeys/service-journey-$state.json');
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(row)}\n',
      );
    }
  }

  const packageRoute = '/services/feeding-confidence';
  const bookingRoute = '/services/episodes/service-episode/booking';
  const intakeRoute = '/services/appointments/service-appointment/intake';

  Future<void> catalog(WidgetTester tester) =>
      tap(tester, find.byType(MomExpertPlanEntry));
  Future<void> package(WidgetTester tester) async {
    await catalog(tester);
    await tap(tester, find.text('View plans →').first);
  }

  Future<void> region(WidgetTester tester, String label) async {
    await tap(tester, find.byType(DropdownButtonFormField<String>).first);
    await tap(tester, find.text(label).last);
  }

  Future<void> paymentForm(WidgetTester tester) async {
    await package(tester);
    await tap(tester, find.text('Purchase'));
    await region(tester, 'California (CA)');
    await tap(tester, find.byType(CheckboxListTile));
    await tap(tester, find.text('Confirm and continue'));
    expect(transport.order, isNotNull);
  }

  Future<void> bookingEntry(WidgetTester tester) async {
    await catalog(tester);
    await tap(tester, find.text('View my services'));
    await tap(tester, find.text('Book an appointment'));
    expect(router.state.uri.path, bookingRoute);
  }

  Future<void> refreshCatalog(WidgetTester tester) async {
    final before = transport.getPaths
        .where((p) => p == '/v1/care/catalog')
        .length;
    final scroll = find
        .descendant(
          of: find.byType(ServiceCatalogPage),
          matching: find.byType(Scrollable),
        )
        .first;
    for (var pass = 0; pass < 4; pass++) {
      final position = tester.state<ScrollableState>(scroll).position;
      if (position.pixels <= position.minScrollExtent + .5) break;
      await tester.drag(scroll, const Offset(0, 500));
      await tester.pumpAndSettle();
    }
    await tester.drag(scroll, const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(
      transport.getPaths.where((p) => p == '/v1/care/catalog').length,
      greaterThan(before),
    );
  }

  Future<void> precheck(WidgetTester tester) async {
    await region(tester, 'California (CA)');
    await tap(
      tester,
      find.text('I need IBCLC support with lactation or feeding.'),
    );
    await tap(tester, find.text('None of these apply right now'));
    await tap(tester, find.text('Continue to time selection'));
  }

  testWidgets('inventory Services catalog team and every package detail', (
    tester,
  ) async {
    await mount(tester);
    await catalog(tester);
    await capture(
      tester,
      'catalog',
      'More expert support → actual service catalog',
      route: '/services',
    );
    await tap(tester, find.text('Meet the team'));
    await capture(
      tester,
      'catalog-team',
      'Learn about team → provider modal',
      route: '/services',
    );
    await tap(tester, find.text('Close'));
    final names = {
      'feeding-confidence': 'Feeding Confidence',
      'better-breastfeeding': 'Better Breastfeeding',
      'milk-supply-care': 'Milk Supply Care',
      'comfortable-feeding': 'Comfortable Feeding',
    };
    for (final entry in names.entries) {
      await tester.scrollUntilVisible(
        find.text(entry.value),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      final card = find.ancestor(
        of: find.text(entry.value),
        matching: find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == '_PackageCard',
        ),
      );
      await tap(
        tester,
        find.descendant(of: card, matching: find.text('View plans →')),
      );
      await capture(
        tester,
        'package-${entry.key}',
        'Catalog ${entry.value} → detail and purchase CTA',
        route: '/services/${entry.key}',
      );
      await tap(tester, find.text('Meet the team'));
      await capture(
        tester,
        'package-team-${entry.key}',
        'Package detail → team information',
        route: '/services/${entry.key}',
      );
      await tap(tester, find.text('Close'));
      await tap(tester, find.text('Back'));
    }
    await capture(
      tester,
      'catalog-return',
      'All four package detail back paths → catalog',
      route: '/services',
    );
    await tap(tester, find.text('Back'));
    await capture(
      tester,
      'catalog-return-home',
      'Catalog back → More',
      route: '/more',
    );
    expect(transport.requests, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'inventory Services purchase validation decline challenge success and booking',
    (tester) async {
      await mount(tester);
      await package(tester);
      await tap(tester, find.text('Purchase'));
      await capture(
        tester,
        'purchase-eligibility-empty',
        'Purchase → eligibility dialog',
      );
      await tap(tester, find.byType(DropdownButtonFormField<String>));
      await capture(
        tester,
        'purchase-region-menu',
        'Open current state selector',
      );
      await tap(tester, find.text('New York (NY)').last);
      await tap(tester, find.byType(CheckboxListTile));
      await capture(
        tester,
        'purchase-unsupported-region',
        'Unsupported state and acknowledgment → blocked CTA',
      );
      await region(tester, 'California (CA)');
      await capture(
        tester,
        'purchase-eligibility-ready',
        'Supported state → eligibility can be submitted',
      );
      await tap(tester, find.text('Confirm and continue'));
      await capture(
        tester,
        'purchase-card-form',
        'Eligibility and order API responses → sandbox card form',
      );
      await tester.enterText(find.byType(TextFormField).first, '12');
      await tap(tester, find.text('Pay \$219'));
      await capture(
        tester,
        'purchase-invalid-card',
        'Submit short card number → inline validation',
      );
      expect(
        transport.requests.where(
          (r) => (r['path'] as String).endsWith('sandbox-payment'),
        ),
        isEmpty,
      );
      await tester.enterText(
        find.byType(TextFormField).first,
        '4000 0000 0000 9995',
      );
      await tap(tester, find.text('Pay \$219'));
      expect(transport.order!['status'], 'failed');
      await capture(
        tester,
        'purchase-declined',
        'Declined test card → retryable payment failure',
      );
      await tester.enterText(
        find.byType(TextFormField).first,
        '4000 0025 0000 3155',
      );
      await tap(tester, find.text('Pay \$219'));
      await capture(
        tester,
        'purchase-bank-challenge',
        'Challenge test card → bank verification',
      );
      await tap(tester, find.text('Confirm verification'));
      expect(transport.episode, isNotNull);
      await capture(
        tester,
        'purchase-success',
        'Confirm bank verification → purchased benefits',
      );
      await tap(tester, find.text('Book an appointment'));
      await capture(
        tester,
        'purchase-to-booking',
        'Purchase success CTA → booking route and precheck',
        route: bookingRoute,
      );
      await tap(tester, find.byTooltip('Close booking check'));
      await tap(tester, find.text('Back'));
      await capture(
        tester,
        'purchase-owned-detail',
        'Booking back → purchased package detail',
        route: packageRoute,
      );
      await tap(tester, find.text('Back'));
      await capture(
        tester,
        'purchase-owned-catalog',
        'Package back → catalog retains prior loaded state until refresh',
        route: '/services',
      );
      await refreshCatalog(tester);
      expect(find.text('View my services'), findsOneWidget);
      await capture(
        tester,
        'purchase-owned-catalog-refreshed',
        'Pull refresh → catalog marks purchased plan',
        route: '/services',
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'inventory Services booking eligibility hold confirm intake and cancellation',
    (tester) async {
      await mount(tester, prepare: (t) => t.ownPlan());
      await bookingEntry(tester);
      await capture(
        tester,
        'booking-precheck',
        'Owned package → booking precheck',
        route: bookingRoute,
      );
      await region(tester, 'New York (NY)');
      await tap(
        tester,
        find.text('I need IBCLC support with lactation or feeding.'),
      );
      await tap(tester, find.text('None of these apply right now'));
      await capture(
        tester,
        'booking-region-blocked',
        'Unsupported booking region → cannot continue',
        route: bookingRoute,
      );
      await region(tester, 'California (CA)');
      await tap(tester, find.text('Yes, or I am not sure'));
      await capture(
        tester,
        'booking-emergency',
        'Potential emergency selected → guidance and disabled booking',
        route: bookingRoute,
      );
      await tap(tester, find.text('None of these apply right now'));
      await tap(tester, find.text('Continue to time selection'));
      await capture(
        tester,
        'booking-slots',
        'Suitable and eligible → available and unavailable slots',
        route: bookingRoute,
      );
      await tap(tester, find.text('10:00 – 11:00 PDT'));
      expect(transport.appointment!['status'], 'held');
      await capture(
        tester,
        'booking-held',
        'Select slot → server hold and confirm time dialog',
        route: bookingRoute,
      );
      await tap(tester, find.byTooltip('Close time confirmation'));
      await capture(
        tester,
        'booking-held-collapsed',
        'Close time confirmation → hold retained on booking page',
        route: bookingRoute,
      );
      await tap(tester, find.text('View selected time'));
      await tap(tester, find.text('Confirm appointment'));
      expect(transport.appointment!['status'], 'confirmed');
      await capture(
        tester,
        'booking-intake-entry',
        'Confirm hold → actual intake route',
        route: intakeRoute,
      );
      await tap(tester, find.text('Back'));
      await capture(
        tester,
        'booking-confirmed-details',
        'Intake back → confirmed appointment details',
        route: bookingRoute,
      );
      await tap(tester, find.text('Cancel appointment'));
      await capture(
        tester,
        'booking-cancel-confirm',
        'Cancel appointment → cancellation confirmation',
        route: bookingRoute,
      );
      await tap(tester, find.text('Keep appointment'));
      await capture(
        tester,
        'booking-cancel-retained',
        'Keep appointment → confirmed details unchanged',
        route: bookingRoute,
      );
      await tap(tester, find.text('Cancel appointment'));
      transport.failingWrites.add(
        '/v1/care/appointments/service-appointment/cancel',
      );
      await tap(tester, find.text('Confirm cancellation'));
      await capture(
        tester,
        'booking-cancel-error',
        'Cancel request fails → original operation retained',
        route: bookingRoute,
      );
      expect(transport.appointment!['status'], 'confirmed');
      transport.failingWrites.clear();
      await tap(tester, find.text('Try canceling again'));
      expect(transport.appointment!['status'], 'cancelled');
      await capture(
        tester,
        'booking-cancelled',
        'Retry cancellation → actual product returns to package detail',
        route: packageRoute,
      );
      await tap(tester, find.text('View service progress'));
      await capture(
        tester,
        'booking-cancelled-timeline',
        'Package service progress → cancellation included in timeline',
        route: '/services/episodes/service-episode',
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'inventory Services create order retry pending payment and resume',
    (tester) async {
      await mount(tester);
      await package(tester);
      await tap(tester, find.text('Purchase'));
      await region(tester, 'California (CA)');
      await tap(tester, find.byType(CheckboxListTile));
      transport.failingWrites.add('/v1/care/orders');
      await tap(tester, find.text('Confirm and continue'));
      await capture(
        tester,
        'purchase-order-error',
        'Order creation unavailable → retry retains eligibility',
      );
      expect(transport.order, isNull);
      transport.failingWrites.clear();
      await tap(tester, find.text('Try again'));
      final creates = transport.requests
          .where((r) => r['path'] == '/v1/care/orders')
          .toList();
      expect(creates, hasLength(2));
      expect(creates.first['headers'], creates.last['headers']);
      await tap(tester, find.byTooltip('Close purchase'));
      await capture(
        tester,
        'purchase-pending-detail',
        'Close unpaid order → continue payment on package',
      );
      await tap(tester, find.text('Back'));
      await capture(
        tester,
        'purchase-pending-catalog',
        'Package back → catalog retains its previously loaded state',
        route: '/services',
      );
      await refreshCatalog(tester);
      await capture(
        tester,
        'purchase-pending-catalog-refreshed',
        'Pull refresh → pending order resume action',
        route: '/services',
      );
      await tap(tester, find.text('Continue to payment'));
      transport.failingReads.add('/v1/care/orders/service-order');
      await tap(tester, find.text('Continue to payment'));
      await capture(
        tester,
        'purchase-resume-error',
        'Resume order read fails → snackbar on package',
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      await capture(
        tester,
        'purchase-resume-message-dismissed',
        'Transient error snackbar expires → payment CTA unobscured',
      );
      transport.failingReads.clear();
      await tap(tester, find.text('Continue to payment'));
      await capture(
        tester,
        'purchase-resumed-form',
        'Retry resume → same order card form',
      );
      expect(find.byType(TextFormField), findsNWidgets(4));
      transport.writeGate = Completer<void>();
      await tester.ensureVisible(find.text('Pay \$219'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pay \$219'));
      await tester.pump();
      await capture(
        tester,
        'purchase-payment-pending',
        'Payment response pending → controls and close disabled',
      );
      transport.failingWrites.add(
        '/v1/care/orders/service-order/sandbox-payment',
      );
      transport.writeGate!.complete();
      await tester.pumpAndSettle();
      await capture(
        tester,
        'purchase-payment-uncertain',
        'Payment unavailable → pending outcome retained for retry',
      );
      transport.failingWrites.clear();
      await tap(tester, find.text('Try payment again'));
      await capture(
        tester,
        'purchase-retry-success',
        'Retry same outcome → payment and benefits confirmed',
      );
      await tap(tester, find.text('Book later'));
      await capture(
        tester,
        'purchase-later-booking',
        'Book later → owned detail without automatic booking',
      );
      expect(transport.appointment, isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'inventory Services cancelled challenge and reconciling payment',
    (tester) async {
      await mount(tester);
      await paymentForm(tester);
      await tester.enterText(
        find.byType(TextFormField).first,
        '4000 0025 0000 3155',
      );
      await tap(tester, find.text('Pay \$219'));
      await tap(tester, find.text('Cancel payment'));
      await capture(
        tester,
        'purchase-challenge-cancelled',
        'Cancel bank verification → cancelled order with no entitlement',
      );
      expect(transport.episode, isNull);
      await tap(tester, find.text('Back to plan'));
      await capture(
        tester,
        'purchase-cancelled-detail',
        'Cancelled order back → package can be purchased again',
      );
      await tap(tester, find.text('Purchase'));
      await region(tester, 'California (CA)');
      await tap(tester, find.byType(CheckboxListTile));
      await tap(tester, find.text('Confirm and continue'));
      transport.paymentStatusOverride = 'reconciling';
      await tap(tester, find.text('Pay \$219'));
      await capture(
        tester,
        'purchase-reconciling',
        'Server payment reconciliation → query instead of duplicate payment',
      );
      transport.failingReads.add('/v1/care/orders/${transport.order!['id']}');
      await tap(tester, find.text('Check status'));
      await capture(
        tester,
        'purchase-query-error',
        'Query reconciling payment fails → recoverable order error',
      );
      transport.failingReads.clear();
      transport.paymentStatusOverride = null;
      await tap(tester, find.text('Complete simulated payment'));
      await capture(
        tester,
        'purchase-reconciliation-complete',
        'Complete pending sandbox payment → purchased benefits',
      );
      await tap(tester, find.text('Book later'));
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'inventory Services catalog loading error empty and package refresh',
    (tester) async {
      await mount(tester);
      transport.readGates['/v1/care/catalog'] = Completer<void>();
      await tester.ensureVisible(find.byType(MomExpertPlanEntry));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(MomExpertPlanEntry));
      await tester.pump();
      // Finish route motion while keeping the API gate closed. Otherwise the
      // departing shell page remains mounted and contributes a hidden scroll.
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(MeHomePage), findsNothing);
      await capture(
        tester,
        'catalog-loading',
        'Catalog navigation with requests pending',
        route: '/services',
      );
      transport.failingReads.add('/v1/care/catalog');
      transport.readGates['/v1/care/catalog']!.complete();
      await tester.pumpAndSettle();
      await capture(
        tester,
        'catalog-read-error',
        'Catalog unavailable → full-page error',
        route: '/services',
      );
      transport.failingReads.clear();
      final packages =
          transport.responsesByPath['/v1/care/catalog']!['packages'];
      transport.responsesByPath['/v1/care/catalog']!['packages'] = [];
      await tap(tester, find.text('Try again'));
      await capture(
        tester,
        'catalog-empty',
        'Retry returns no packages → empty catalog',
        route: '/services',
      );
      transport.responsesByPath['/v1/care/catalog']!['packages'] = packages;
      await refreshCatalog(tester);
      await capture(
        tester,
        'catalog-pull-refreshed',
        'Pull refresh → packages restored',
        route: '/services',
      );
      transport.failingReads.add('/v1/care/catalog');
      await tap(tester, find.text('View plans →').first);
      await capture(
        tester,
        'package-read-error',
        'Enter package while API unavailable → detail error',
      );
      transport.failingReads.clear();
      await tap(tester, find.text('Try again'));
      await capture(
        tester,
        'package-read-recovered',
        'Retry package read → full detail',
      );
      await tap(tester, find.text('Back'));
      transport.responsesByPath['/v1/care/catalog']!['payment_mode'] =
          'disabled';
      await tap(tester, find.text('View plans →').first);
      await capture(
        tester,
        'package-payment-disabled',
        'Package with disabled payment mode → purchase unavailable',
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(
                FilledButton,
                'Not available to purchase yet',
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'inventory Services booking availability error empty picker and hold recovery',
    (tester) async {
      await mount(tester, prepare: (t) => t.ownPlan());
      await bookingEntry(tester);
      await precheck(tester);
      await tap(tester, find.byType(DropdownButtonFormField<String>));
      await capture(
        tester,
        'booking-provider-menu',
        'Open provider selector',
        route: bookingRoute,
      );
      await tap(tester, find.text('Test IBCLC').last);
      transport.failingReads.add(
        '/v1/care/episodes/service-episode/availability',
      );
      await tap(tester, find.byTooltip('Refresh appointment'));
      await capture(
        tester,
        'booking-availability-error',
        'Refresh with slot read failure → error and retained selection',
        route: bookingRoute,
      );
      transport.failingReads.clear();
      transport.emptySlots = true;
      await tap(tester, find.text('Try again'));
      await capture(
        tester,
        'booking-no-slots',
        'Slot retry returns no availability → empty state',
        route: bookingRoute,
      );
      transport.emptySlots = false;
      await tap(tester, find.byTooltip('Refresh appointment'));
      transport.failingWrites.add('/v1/care/episodes/service-episode/holds');
      await tap(tester, find.text('10:00 – 11:00 PDT'));
      await capture(
        tester,
        'booking-hold-error',
        'Hold unavailable → uncertain submission and retry CTA',
        route: bookingRoute,
      );
      transport.failingWrites.clear();
      await tap(tester, find.text('Retry last submission'));
      await capture(
        tester,
        'booking-hold-recovered',
        'Retry original hold → confirmation dialog',
        route: bookingRoute,
      );
      transport.failingWrites.add(
        '/v1/care/appointments/service-appointment/confirm',
      );
      await tap(tester, find.text('Confirm appointment'));
      await capture(
        tester,
        'booking-confirm-error',
        'Confirm hold unavailable → retry original confirmation',
        route: bookingRoute,
      );
      transport.failingWrites.clear();
      await tap(tester, find.text('Retry last submission').last);
      await capture(
        tester,
        'booking-confirm-recovered',
        'Retry confirmation → intake page',
        route: intakeRoute,
      );
      final holds = transport.requests
          .where((r) => (r['path'] as String).endsWith('/holds'))
          .toList();
      expect(holds, hasLength(2));
      expect(holds.first['headers'], holds.last['headers']);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'inventory Services intake fields consent uncertain save and update',
    (tester) async {
      await mount(tester, prepare: (t) => t.ownPlan());
      await bookingEntry(tester);
      await precheck(tester);
      await tap(tester, find.text('10:00 – 11:00 PDT'));
      await tap(tester, find.text('Confirm appointment'));
      await capture(
        tester,
        'intake-unfilled',
        'Confirmed booking → unfilled intake with profile prefill',
        route: intakeRoute,
      );
      await tap(tester, find.text('Latching difficulties'));
      await tap(tester, find.text('Pain during feeding'));
      await tester.enterText(
        find.byKey(const ValueKey('goal-1')),
        'For this test, I would like a steadier feeding routine.',
      );
      await tap(tester, find.text('Additional details'));
      await tester.enterText(
        find.byKey(const ValueKey('support-1')),
        'Additional consultation context for this isolated test.',
      );
      await capture(
        tester,
        'intake-optional-filled',
        'Choose concerns, goal and optional background',
        route: intakeRoute,
      );
      await tap(tester, find.byType(DropdownButtonFormField<FeedingMode>));
      await capture(
        tester,
        'intake-feeding-menu',
        'Open feeding method selector',
        route: intakeRoute,
      );
      await tap(tester, find.text('Bottle-fed breast milk').last);
      await tap(tester, find.text('Read details'));
      await capture(
        tester,
        'intake-consent-info',
        'Information use details → consent explanation dialog',
        route: intakeRoute,
      );
      await tap(tester, find.text('Got it'));
      await tap(tester, find.byKey(const ValueKey('intake-consent')));
      await capture(
        tester,
        'intake-ready',
        'Explicit consent → save enabled',
        route: intakeRoute,
      );
      await tap(tester, find.text('Back'));
      await capture(
        tester,
        'intake-discard-confirm',
        'Back with edited intake → discard confirmation',
        route: intakeRoute,
      );
      await tap(tester, find.text('Keep editing'));
      transport.writeGate = Completer<void>();
      await tester.ensureVisible(find.text('Save information'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Save information'),
            )
            .onPressed,
        isNotNull,
      );
      final savesBefore = transport.requests
          .where((r) => (r['path'] as String).endsWith('/intake'))
          .length;
      await tester.tap(find.text('Save information'));
      await tester.pump();
      expect(
        transport.requests
            .where((r) => (r['path'] as String).endsWith('/intake'))
            .length,
        savesBefore + 1,
      );
      expect(find.text('Saving…'), findsOneWidget);
      await capture(
        tester,
        'intake-saving',
        'Save response pending → fields locked',
        route: intakeRoute,
      );
      transport.failingWrites.add(
        '/v1/care/appointments/service-appointment/intake',
      );
      transport.writeGate!.complete();
      await tester.pumpAndSettle();
      await capture(
        tester,
        'intake-save-uncertain',
        'Save unavailable → snapshot retained and retry enabled',
        route: intakeRoute,
      );
      await tap(tester, find.text('Back'));
      await capture(
        tester,
        'intake-uncertain-leave',
        'Back with uncertain save → reconciliation warning',
        route: intakeRoute,
      );
      await tap(tester, find.text('Keep editing'));
      transport.failingWrites.clear();
      await tap(tester, find.text('Try saving again'));
      expect(transport.intake, isNotNull);
      await capture(
        tester,
        'intake-saved',
        'Retry original snapshot → intake completion modal',
        route: intakeRoute,
      );
      await tap(tester, find.text('Maybe later · View appointment'));
      await capture(
        tester,
        'intake-saved-return',
        'Save complete then view appointment → confirmed detail',
        route: bookingRoute,
      );
      await tap(tester, find.text('View intake form'));
      await capture(
        tester,
        'intake-reopened',
        'Reopen saved intake → populated data and granted consent',
        route: intakeRoute,
      );
      await tester.enterText(
        find.byKey(const ValueKey('goal-1')),
        'A revised goal for this UI test.',
      );
      await tap(tester, find.text('Save changes'));
      await capture(
        tester,
        'intake-update-saved',
        'Modify saved intake → return to confirmed appointment',
        route: bookingRoute,
      );
      expect(transport.intake!['version'], 2);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'inventory Services date pickers intake retry profile and preconsult',
    (tester) async {
      await mount(tester, prepare: (t) => t.ownPlan());
      await bookingEntry(tester);
      await precheck(tester);
      await tap(tester, find.byIcon(Icons.calendar_today_outlined));
      await capture(
        tester,
        'booking-date-calendar',
        'Open appointment date calendar',
        route: bookingRoute,
      );
      final strings = MaterialLocalizations.of(
        tester.element(find.byType(DatePickerDialog)),
      );
      await tap(tester, find.byTooltip(strings.inputDateModeButtonLabel));
      await capture(
        tester,
        'booking-date-input',
        'Switch appointment date picker to typed input',
        route: bookingRoute,
      );
      await tester.enterText(
        find.descendant(
          of: find.byType(DatePickerDialog),
          matching: find.byType(TextField),
        ),
        'invalid',
      );
      await tap(tester, find.text(strings.okButtonLabel));
      await capture(
        tester,
        'booking-date-invalid',
        'Submit malformed appointment date → inline validation',
        route: bookingRoute,
      );
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tap(tester, find.text(strings.cancelButtonLabel));
      await capture(
        tester,
        'booking-date-cancelled',
        'Cancel invalid date → original slot date retained',
        route: bookingRoute,
      );
      await tap(tester, find.byIcon(Icons.calendar_today_outlined));
      await tap(
        tester,
        find.descendant(
          of: find.byType(DatePickerDialog),
          matching: find.text('14'),
        ),
      );
      await capture(
        tester,
        'booking-date-selected',
        'Select September 14 in calendar before confirmation',
        route: bookingRoute,
      );
      await tap(tester, find.text(strings.okButtonLabel));
      await capture(
        tester,
        'booking-date-applied',
        'Confirm another date → availability reloaded',
        route: bookingRoute,
      );
      expect(find.text('2026-09-14'), findsOneWidget);
      await tap(tester, find.text('10:00 – 11:00 PDT'));
      transport.failingReads.add(
        '/v1/care/appointments/service-appointment/intake',
      );
      await tap(tester, find.text('Confirm appointment'));
      expect(transport.appointment!['starts_at'], '2026-09-14T17:00:00.000Z');
      await capture(
        tester,
        'intake-load-error',
        'Confirmed appointment → intake read failure with retry',
        route: intakeRoute,
      );
      transport.failingReads.clear();
      final gate = Completer<void>();
      transport.readGates['/v1/care/appointments/service-appointment/intake'] =
          gate;
      await tester.tap(find.text('Try again'));
      await tester.pump();
      await capture(
        tester,
        'intake-loading',
        'Retry intake while read pending → loading view',
        route: intakeRoute,
      );
      gate.complete();
      await tester.pumpAndSettle();
      await capture(
        tester,
        'intake-load-recovered',
        'Read retry resolves → intact editable form',
        route: intakeRoute,
      );
      await tap(tester, find.text('Milk supply concerns'));
      await tester.enterText(
        find.byKey(const ValueKey('goal-1')),
        'For this test, I want to clarify my consultation priorities.',
      );
      await tap(tester, find.byIcon(Icons.calendar_today_outlined));
      await capture(
        tester,
        'intake-birth-calendar',
        'Open prefilled baby birth date calendar',
        route: intakeRoute,
      );
      final birthStrings = MaterialLocalizations.of(
        tester.element(find.byType(DatePickerDialog)),
      );
      await tap(tester, find.text(birthStrings.cancelButtonLabel));
      await tap(tester, find.byType(DropdownButtonFormField<BabySex>));
      await capture(
        tester,
        'intake-sex-menu',
        'Open recorded sex options',
        route: intakeRoute,
      );
      await tap(tester, find.text('Boy').last);
      await tap(tester, find.byType(DropdownButtonFormField<String>));
      await capture(
        tester,
        'intake-region-menu',
        'Open intake current-state selector',
        route: intakeRoute,
      );
      await tap(tester, find.text('California (CA)').last);
      await tap(tester, find.byType(DropdownButtonFormField<FeedingMode>));
      await tap(tester, find.text('Bottle-fed breast milk').last);
      await tap(tester, find.byKey(const ValueKey('intake-consent')));
      await tap(tester, find.byKey(const ValueKey('intake-consent')));
      await capture(
        tester,
        'intake-consent-withdrawn-draft',
        'Uncheck draft consent → save disabled without server mutation',
        route: intakeRoute,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Save information'),
            )
            .onPressed,
        isNull,
      );
      expect(transport.intake, isNull);
      await tap(tester, find.byKey(const ValueKey('intake-consent')));
      await tap(tester, find.text('Save information'));
      expect(transport.intake, isNotNull);
      await capture(
        tester,
        'intake-preconsult-completion',
        'First intake save → completion choices',
        route: intakeRoute,
      );
      await tap(tester, find.text('Discuss with Momcozy AI'));
      await capture(
        tester,
        'intake-to-momcozy-ai',
        'Preconsult CTA → actual Momcozy AI route with context draft',
        route: '/',
      );
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('agent-composer-input')),
            )
            .controller!
            .text,
        "I've completed my consultation intake. Can you help me prepare the key points to discuss?",
      );
      expect(
        transport.requests.any((r) => (r['path'] as String).contains('/runs')),
        isFalse,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}
