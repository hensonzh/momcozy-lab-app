import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
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
import 'package:momcozy_flutter_app/modules/services/presentation/service_catalog_page.dart';
import 'package:momcozy_flutter_app/shared/widgets/mom_timeline_event.dart';
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
  var narrow = false;
  late String variant;
  Future<void> mount(
    WidgetTester tester, {
    void Function(ServiceInventoryTransport)? prepare,
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

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    if (transport.readGates.values.any((gate) => !gate.isCompleted) ||
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
    String route = '/services/feeding-confidence',
  }) async {
    // Commit edits and finish the input hint's fade without settling spinners.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(router.state.uri.path, route);
    expect(tester.takeException(), isNull);
    final source =
        'test/goldens/ui_inventory/service-current-$state-$variant.png';
    final timelineRect = state == 'owned-progress' && narrow
        ? tester.getRect(find.byType(MomTimelineEvent))
        : null;
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/ui_inventory/service-current-$state-$variant.png',
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
      'test': 'test/modules/services/service_current_inventory_test.dart',
    };
    previous = source;
    final output = Platform.environment['MOMCOZY_UI_INVENTORY_DIR'];
    if (output != null) {
      if (timelineRect != null &&
          Platform.environment['MOMCOZY_UI_INVENTORY_LONG'] == '1') {
        // The timeline footer changes viewport height while stitching. The
        // complete event is visible in the matched window: its pixels must
        // remain identical at the corresponding position in the long image.
        await tester.runAsync(() async {
          final meta =
              jsonDecode(File('$output/$source.json').readAsStringSync())
                  as Map<String, dynamic>;
          final scroll = meta['long_capture'] as Map<String, dynamic>;
          final offset = (scroll['original_scroll_offset'] as num).round();
          final windowCodec = await ui.instantiateImageCodec(
            File('$output/$source').readAsBytesSync(),
          );
          final longCodec = await ui.instantiateImageCodec(
            File(scroll['file'] as String).readAsBytesSync(),
          );
          final windowImage = (await windowCodec.getNextFrame()).image;
          final longImage = (await longCodec.getNextFrame()).image;
          try {
            final windowBytes = (await windowImage.toByteData())!.buffer
                .asUint8List();
            final longBytes = (await longImage.toByteData())!.buffer
                .asUint8List();
            final stride = windowImage.width * 4;
            // Compare the event's interior, avoiding the rounded outer edge
            // whose antialiasing can vary by one channel value when scrolled.
            final left = (timelineRect.left + 48).ceil() * 4;
            final right = (timelineRect.right - 32).floor() * 4;
            for (
              var y = timelineRect.top.ceil();
              y < timelineRect.bottom.floor();
              y++
            ) {
              expect(
                longBytes.sublist(
                  (y + offset) * stride + left,
                  (y + offset) * stride + right,
                ),
                windowBytes.sublist(y * stride + left, y * stride + right),
                reason: 'A changing footer must not enter event row $y',
              );
            }
          } finally {
            windowImage.dispose();
            longImage.dispose();
            windowCodec.dispose();
            longCodec.dispose();
          }
        });
      }
      final file = File(
        '$output/journeys/service-current-$state-$variant.json',
      );
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(row)}\n',
      );
    }
  }

  const catalogPath = '/v1/care/catalog';
  const orderPath = '/v1/care/orders/service-order';
  Future<void> catalog(WidgetTester tester) =>
      tap(tester, find.byType(MomExpertPlanEntry));
  Future<void> refreshCatalog(WidgetTester tester) async {
    final before = transport.getPaths.where((p) => p == catalogPath).length;
    final scroll = find
        .descendant(
          of: find.byType(ServiceCatalogPage),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.drag(scroll, const Offset(0, 10000));
    await settle(tester);
    await tester.drag(scroll, const Offset(0, 500));
    await settle(tester);
    if (transport.readGates[catalogPath] == null) {
      expect(
        transport.getPaths.where((p) => p == catalogPath).length,
        greaterThan(before),
      );
    }
  }

  Future<void> openFirstAvailablePlan(WidgetTester tester) async {
    final scroll = find.descendant(
      of: find.byType(ServiceCatalogPage),
      matching: find.byType(ListView),
    );
    for (
      var i = 0;
      i < 30 && find.text('View plans →').hitTestable().evaluate().isEmpty;
      i++
    ) {
      await tester.drag(scroll, const Offset(0, -240));
      await settle(tester);
    }
    await tap(tester, find.text('View plans →').hitTestable().first);
  }

  Future<void> enter(WidgetTester tester, String entry) async {
    await capture(
      tester,
      '$entry-home',
      'Authenticated More before service entry',
      route: '/more',
    );
    await catalog(tester);
  }

  Future<void> closeDialog(WidgetTester tester) => tap(
    tester,
    find.byTooltip('Close purchase').evaluate().isNotEmpty
        ? find.byTooltip('Close purchase')
        : find.byTooltip('Close booking check').evaluate().isNotEmpty
        ? find.byTooltip('Close booking check')
        : find.text('Close').last,
  );
  for (final compact in [false, true]) {
    testWidgets(
      'current service catalog all package and team entries $compact',
      (tester) async {
        narrow = compact;
        await mount(tester);
        await enter(tester, 'discovery');
        await capture(
          tester,
          'catalog',
          'Home expert plan → current catalog',
          route: '/services',
        );
        await tap(tester, find.text('Meet the team'));
        await capture(
          tester,
          'catalog-team',
          'Catalog team action → provider dialog',
          route: '/services',
        );
        await closeDialog(tester);
        await capture(
          tester,
          'catalog-team-closed',
          'Team Close → catalog',
          route: '/services',
        );
        await tap(tester, find.text('Meet the team'));
        await tester.tapAt(const Offset(3, 3));
        await settle(tester);
        expect(find.text('IBCLC team'), findsNothing);
        await capture(
          tester,
          'catalog-team-barrier-dismissed',
          'Team outside tap → catalog',
          route: '/services',
        );
        await tap(tester, find.text('Meet the team'));
        await tester.binding.handlePopRoute();
        await settle(tester);
        expect(find.text('IBCLC team'), findsNothing);
        await capture(
          tester,
          'catalog-team-back-dismissed',
          'Team Flutter back → catalog',
          route: '/services',
        );
        const names = {
          'feeding-confidence': 'Feeding Confidence',
          'better-breastfeeding': 'Better Breastfeeding',
          'milk-supply-care': 'Milk Supply Care',
          'comfortable-feeding': 'Comfortable Feeding',
        };
        for (final item in names.entries) {
          final card = find.ancestor(
            of: find.text(item.value),
            matching: find.byWidgetPredicate(
              (w) => w.runtimeType.toString() == '_PackageCard',
            ),
          );
          await tap(
            tester,
            find.descendant(of: card, matching: find.text('View plans →')),
          );
          final route = '/services/${item.key}';
          await capture(
            tester,
            'package-${item.key}',
            'Catalog ${item.value} → current package',
            route: route,
          );
          await tap(tester, find.text('Meet the team'));
          await capture(
            tester,
            'package-team-${item.key}',
            'Package learn team → provider dialog',
            route: route,
          );
          await closeDialog(tester);
          await tap(tester, find.text('Purchase'));
          await capture(
            tester,
            'package-buy-${item.key}',
            'Package purchase → eligibility flow',
            route: route,
          );
          await closeDialog(tester);
          await capture(
            tester,
            'package-buy-cancel-${item.key}',
            'Close before submitting eligibility → package',
            route: route,
          );
          await tap(tester, find.text('Back').first);
        }
        await capture(
          tester,
          'catalog-all-return',
          'Four package Back paths → catalog',
          route: '/services',
        );
        await tap(tester, find.text('Back').first);
        await capture(
          tester,
          'catalog-home-return',
          'Catalog Back → mother home',
          route: '/more',
        );
        expect(transport.requests, isEmpty);
        await tester.pumpWidget(const SizedBox());
      },
    );
    testWidgets('current catalog loading empty errors and refresh $compact', (
      tester,
    ) async {
      narrow = compact;
      await mount(tester);
      final original = Map<String, Object?>.from(
        transport.responsesByPath[catalogPath]!,
      );
      transport.readGates[catalogPath] = Completer<void>();
      await enter(tester, 'catalog-recovery');
      await capture(
        tester,
        'catalog-loading',
        'Enter catalog with GET pending',
        route: '/services',
      );
      transport.failingReads.add(catalogPath);
      transport.readGates.remove(catalogPath)!.complete();
      await settle(tester);
      await capture(
        tester,
        'catalog-error',
        'Catalog 503 → retry',
        route: '/services',
      );
      transport.failingReads.clear();
      transport.responsesByPath[catalogPath]!['packages'] = [];
      transport.responsesByPath[catalogPath]!['providers'] = [];
      await tap(tester, find.text('Try again'));
      await tester.scrollUntilVisible(
        find.text('No service plans available'),
        240,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('No service plans available'), findsOneWidget);
      await capture(
        tester,
        'catalog-empty',
        'Retry → no available packages',
        route: '/services',
      );
      await tap(tester, find.text('Meet the team'));
      await capture(
        tester,
        'catalog-team-empty',
        'Empty catalog team → no available experts',
        route: '/services',
      );
      await closeDialog(tester);
      transport.responsesByPath[catalogPath] = original;
      await refreshCatalog(tester);
      await capture(
        tester,
        'catalog-refresh-filled',
        'Pull refresh after catalog restored → available packages',
        route: '/services',
      );
      transport.readGates[catalogPath] = Completer<void>();
      await refreshCatalog(tester);
      await capture(
        tester,
        'catalog-refresh-pending',
        'Pull refresh pending → retained catalog with progress',
        route: '/services',
      );
      transport.failingReads.add(catalogPath);
      transport.readGates.remove(catalogPath)!.complete();
      await settle(tester);
      await capture(
        tester,
        'catalog-refresh-error',
        'Refresh 503 → retained catalog and retry',
        route: '/services',
      );
      transport.failingReads.clear();
      await tap(tester, find.text('Try again'));
      await capture(
        tester,
        'catalog-refresh-recovered',
        'Retry refresh → error removed and catalog restored',
        route: '/services',
      );
      await tap(tester, find.text('Back').first);
      await capture(
        tester,
        'catalog-recovery-home-return',
        'Catalog recovery Back → home',
        route: '/more',
      );
      await tester.pumpWidget(const SizedBox());
    });
    testWidgets(
      'current package loading missing recovery disabled payment $compact',
      (tester) async {
        narrow = compact;
        await mount(tester);
        await enter(tester, 'package-recovery');
        await capture(
          tester,
          'package-recovery-catalog',
          'Catalog before opening package',
          route: '/services',
        );
        final original = Map<String, Object?>.from(
          transport.responsesByPath[catalogPath]!,
        );
        transport.readGates[catalogPath] = Completer<void>();
        await openFirstAvailablePlan(tester);
        await capture(
          tester,
          'package-loading',
          'Select package with GET pending',
        );
        transport.failingReads.add(catalogPath);
        transport.readGates.remove(catalogPath)!.complete();
        await settle(tester);
        await capture(
          tester,
          'package-error',
          'Package catalog GET 503 → retry',
        );
        transport.failingReads.clear();
        transport.responsesByPath[catalogPath]!['packages'] = [];
        await tap(tester, find.text('Try again'));
        await capture(
          tester,
          'package-missing',
          'Retry returns removed package → unavailable page',
        );
        expect(find.text('Could not find this service plan'), findsOneWidget);
        await tap(tester, find.text('Back').first);
        transport.responsesByPath[catalogPath] = original;
        transport.responsesByPath[catalogPath]!['payment_mode'] = 'disabled';
        await openFirstAvailablePlan(tester);
        await capture(
          tester,
          'package-purchase-disabled',
          'Reenter package when payment disabled',
        );
        final disabled = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Not available to purchase yet'),
        );
        expect(disabled.onPressed, isNull);
        await tap(tester, find.text('Back').first);
        await tap(tester, find.text('Back').first);
        await capture(
          tester,
          'package-recovery-home-return',
          'Package and catalog Back → home',
          route: '/more',
        );
        expect(transport.requests, isEmpty);
        await tester.pumpWidget(const SizedBox());
      },
    );
    testWidgets('current owned service progress and booking entries $compact', (
      tester,
    ) async {
      narrow = compact;
      await mount(tester, prepare: (t) => t.ownPlan());
      await enter(tester, 'owned');
      await capture(
        tester,
        'owned-catalog',
        'Owned service grouped above available packages',
        route: '/services',
      );
      await tap(tester, find.text('View my services'));
      await capture(
        tester,
        'owned-package',
        'Owned package → expert identity, remaining sessions, progress and booking',
      );
      await tap(tester, find.text('View service progress'));
      await capture(
        tester,
        'owned-progress',
        'Package progress action → actual service timeline',
        route: '/services/episodes/service-episode',
      );
      await tap(tester, find.text('Back').first);
      await capture(
        tester,
        'owned-progress-return',
        'Timeline Back → owned package',
      );
      await tap(tester, find.text('Book an appointment'));
      await capture(
        tester,
        'owned-booking',
        'Owned package booking → actual booking preparation',
        route: '/services/episodes/service-episode/booking',
      );
      if (find.text('Close').evaluate().isNotEmpty ||
          find.byTooltip('Close booking check').evaluate().isNotEmpty) {
        await closeDialog(tester);
      }
      await tap(tester, find.text('Back').first);
      await capture(
        tester,
        'owned-booking-return',
        'Booking cancel/back → owned package',
      );
      await tap(tester, find.text('Back').first);
      transport.episode!['status'] = 'paused';
      transport.episode!['remaining_sessions'] = 0;
      await tap(tester, find.text('View my services'));
      await capture(
        tester,
        'paused-package',
        'Reenter paused zero-session plan → existing package state',
      );
      await tap(tester, find.text('Book an appointment'));
      await capture(
        tester,
        'paused-booking',
        'Package booking action on paused plan → actual eligibility block',
        route: '/services/episodes/service-episode/booking',
      );
      if (find.text('Close').evaluate().isNotEmpty) {
        await closeDialog(tester);
      }
      await tap(tester, find.text('Back').first);
      await tap(tester, find.text('Back').first);
      await tap(tester, find.text('Back').first);
      await capture(
        tester,
        'owned-home-return',
        'Return through package and catalog → home',
        route: '/more',
      );
      await tester.pumpWidget(const SizedBox());
    });
    testWidgets(
      'current pending service order open failure and resume $compact',
      (tester) async {
        narrow = compact;
        await mount(tester, prepare: (t) => t.order = t.newOrder());
        await enter(tester, 'pending');
        await capture(
          tester,
          'pending-catalog',
          'Pending order grouped before available packages',
          route: '/services',
        );
        await tap(tester, find.text('Continue to payment'));
        await capture(
          tester,
          'pending-package',
          'Pending order → package resume footer',
        );
        transport.readGates[orderPath] = Completer<void>();
        await tap(tester, find.text('Continue to payment'));
        await capture(
          tester,
          'pending-order-opening',
          'Resume existing order with GET pending → opening label',
        );
        transport.failingReads.add(orderPath);
        transport.readGates.remove(orderPath)!.complete();
        await settle(tester);
        await capture(
          tester,
          'pending-order-error',
          'Existing order GET 503 → package Snackbar',
        );
        await tester.pump(const Duration(seconds: 5));
        await settle(tester);
        await capture(
          tester,
          'pending-order-error-dismissed',
          'Open order feedback timeout → resume available',
        );
        transport.failingReads.clear();
        await tap(tester, find.text('Continue to payment'));
        await capture(
          tester,
          'pending-order-resumed',
          'Retry existing order → sandbox card form',
        );
        await closeDialog(tester);
        await capture(
          tester,
          'pending-order-closed',
          'Close payment form without paying → order remains resumable',
        );
        await tap(tester, find.text('Back').first);
        await capture(
          tester,
          'pending-catalog-return',
          'Pending package Back → catalog',
          route: '/services',
        );
        await tap(tester, find.text('Back').first);
        await capture(
          tester,
          'pending-home-return',
          'Catalog Back → home',
          route: '/more',
        );
        expect(transport.requests, isEmpty);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
