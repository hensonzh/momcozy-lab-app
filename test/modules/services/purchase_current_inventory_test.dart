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
    String route = '/services/feeding-confidence',
  }) async {
    // Commit edits and finish the input hint's fade without settling spinners.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(router.state.uri.path, route);
    expect(tester.takeException(), isNull);
    final source =
        'test/goldens/ui_inventory/purchase-current-$state-$variant.png';
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/ui_inventory/purchase-current-$state-$variant.png',
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
      'test': 'test/modules/services/purchase_current_inventory_test.dart',
    };
    previous = source;
    final output = Platform.environment['MOMCOZY_UI_INVENTORY_DIR'];
    if (output != null) {
      final file = File(
        '$output/journeys/purchase-current-$state-$variant.json',
      );
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(row)}\n',
      );
    }
  }

  Future<void> openFirstAvailablePlan(WidgetTester tester) async {
    for (
      var i = 0;
      i < 30 && find.text('View plans →').hitTestable().evaluate().isEmpty;
      i++
    ) {
      await tester.drag(find.byType(ListView).last, const Offset(0, -240));
      await settle(tester);
    }
    await tap(tester, find.text('View plans →').hitTestable().first);
  }

  Future<void> entry(WidgetTester tester, String chain) async {
    await mount(tester);
    await capture(
      tester,
      '$chain-home',
      'More before purchase',
      route: '/more',
    );
    await tap(tester, find.byType(MomExpertPlanEntry));
    await capture(
      tester,
      '$chain-catalog',
      'More expert support → catalog',
      route: '/services',
    );
    await openFirstAvailablePlan(tester);
    await capture(
      tester,
      '$chain-package',
      'Catalog → feeding confidence package',
    );
    await tap(tester, find.text('Purchase'));
  }

  Future<void> region(WidgetTester tester, String value) async {
    await tap(tester, find.byType(DropdownButtonFormField<String>));
    await tap(tester, find.text(value).last);
  }

  Future<void> ready(WidgetTester tester) async {
    await region(tester, 'California (CA)');
    await tap(tester, find.byType(CheckboxListTile));
  }

  Future<void> card(WidgetTester tester, String chain) async {
    await entry(tester, chain);
    await ready(tester);
    await tap(tester, find.text('Confirm and continue'));
    await capture(
      tester,
      '$chain-card',
      'Eligibility confirmed → sandbox card form',
    );
    expect(transport.order, isNotNull);
  }

  Future<void> edit(WidgetTester tester, int field, String text) async {
    await tester.ensureVisible(find.byType(TextFormField).at(field));
    await settle(tester);
    await tester.enterText(find.byType(TextFormField).at(field), text);
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester);
  }

  Future<void> returnHome(WidgetTester tester, String chain) async {
    await tap(tester, find.text('Back').first);
    await capture(
      tester,
      '$chain-catalog-return',
      'Package Back → catalog',
      route: '/services',
    );
    await tap(tester, find.text('Back').first);
    await capture(
      tester,
      '$chain-home-return',
      'Catalog Back → Me',
      route: '/more',
    );
    await tester.pumpWidget(const SizedBox());
  }

  const payPath = '/v1/care/orders/service-order/sandbox-payment';
  const orderPath = '/v1/care/orders/service-order';
  for (final compact in [false, true]) {
    testWidgets(
      'current purchase eligibility rejection create retry $compact',
      (tester) async {
        narrow = compact;
        await entry(tester, 'eligibility');
        await capture(
          tester,
          'eligibility-empty',
          'Purchase → untouched eligibility',
        );
        await tap(tester, find.byType(DropdownButtonFormField<String>));
        await capture(tester, 'region-menu', 'Open available state choices');
        await tap(tester, find.text('New York (NY)').last);
        await capture(
          tester,
          'unsupported-state',
          'Select NY → local unsupported state notice',
        );
        await tap(tester, find.byType(CheckboxListTile));
        await capture(
          tester,
          'unsupported-acknowledged',
          'Acknowledge unsupported state → still disabled',
        );
        await region(tester, 'California (CA)');
        await capture(
          tester,
          'eligibility-ready',
          'Supported CA retains acknowledgement → can continue',
        );
        await tap(tester, find.byType(CheckboxListTile));
        await capture(
          tester,
          'acknowledgement-removed',
          'Uncheck acknowledgement → continue disabled',
        );
        await tap(tester, find.byType(CheckboxListTile));
        transport.allowPurchase = false;
        await tap(tester, find.text('Confirm and continue'));
        await capture(
          tester,
          'server-ineligible',
          'Server rejects otherwise supported state → no order',
        );
        expect(transport.order, isNull);
        await region(tester, 'New York (NY)');
        await region(tester, 'California (CA)');
        transport.allowPurchase = true;
        transport.writeGate = Completer<void>();
        await tap(tester, find.text('Confirm and continue'));
        await capture(
          tester,
          'eligibility-pending',
          'Eligibility POST held → confirmation busy',
        );
        await tester.binding.handlePopRoute();
        await settle(tester);
        await capture(
          tester,
          'eligibility-back-blocked',
          'Framework back during confirmation → dialog retained',
        );
        transport.failingWrites.add('/v1/care/eligibility');
        transport.writeGate!.complete();
        await tester.pumpAndSettle();
        await capture(
          tester,
          'eligibility-error',
          'Eligibility POST 503 → retry notice',
        );
        transport.failingWrites.clear();
        transport.failingWrites.add('/v1/care/orders');
        await tap(tester, find.text('Try again'));
        await capture(
          tester,
          'create-error',
          'Eligibility accepted, create order POST 503 → retained form',
        );
        transport.failingWrites.clear();
        await tap(tester, find.text('Try again'));
        await capture(
          tester,
          'create-recovered',
          'Retry same create key → card form',
        );
        final creates = transport.requests
            .where((r) => r['path'] == '/v1/care/orders')
            .toList();
        expect(creates, hasLength(2));
        expect(creates.first['headers'], creates.last['headers']);
        await tap(tester, find.byTooltip('Close purchase'));
        await capture(
          tester,
          'unpaid-closed',
          'Close card form → resumable package',
        );
        await returnHome(tester, 'eligibility');
      },
    );
    testWidgets(
      'current purchase fields decline verification success $compact',
      (tester) async {
        narrow = compact;
        await card(tester, 'validation');
        for (var i = 0; i < 4; i++) {
          await edit(tester, i, '');
        }
        await tap(tester, find.text('Pay \$219'));
        await capture(
          tester,
          'fields-invalid',
          'Submit four empty fields → four inline errors',
        );
        expect(find.text('Enter a 16-digit test card number'), findsOneWidget);
        expect(find.text('Use MM/YY format'), findsOneWidget);
        expect(find.text('Enter 3–4 digits'), findsOneWidget);
        expect(find.text('Enter a ZIP code'), findsOneWidget);
        expect(transport.requests.where((r) => r['path'] == payPath), isEmpty);
        await edit(tester, 0, '1111111111111111');
        await edit(tester, 1, '12/34');
        await edit(tester, 2, '123');
        await edit(tester, 3, '94107');
        await tap(tester, find.text('Pay \$219'));
        await capture(
          tester,
          'unknown-test-card',
          'Valid field formats but unrecognized sandbox card → guidance',
        );
        expect(transport.requests.where((r) => r['path'] == payPath), isEmpty);
        await edit(tester, 0, '4000 0000 0000 9995');
        await tap(tester, find.text('Pay \$219'));
        await capture(
          tester,
          'declined',
          'Declined test card → payment failure and editable form',
        );
        expect(transport.order!['status'], 'failed');
        await edit(tester, 0, '4000 0025 0000 3155');
        await tap(tester, find.text('Pay \$219'));
        await capture(
          tester,
          'challenge',
          'Challenge card → locked fields and 3D Secure actions',
        );
        expect(
          tester.widget<EditableText>(find.byType(EditableText).first).readOnly,
          isTrue,
        );
        transport.writeGate = Completer<void>();
        await tap(tester, find.text('Confirm verification'));
        await capture(
          tester,
          'challenge-pending',
          'Confirm challenge → verification response pending',
        );
        transport.writeGate!.complete();
        await tester.pumpAndSettle();
        await capture(
          tester,
          'verified-success',
          'Verification succeeds → benefits and booking actions',
        );
        expect(transport.episode, isNotNull);
        await tap(tester, find.text('Book an appointment'));
        await capture(
          tester,
          'success-booking',
          'Success CTA → booking precheck',
          route: '/services/episodes/service-episode/booking',
        );
        await tap(tester, find.byTooltip('Close booking check'));
        await tap(tester, find.text('Back').first);
        await capture(
          tester,
          'success-booking-return',
          'Close precheck and Back → owned package',
        );
        expect(transport.appointment, isNull);
        await returnHome(tester, 'validation');
      },
    );
    testWidgets('current purchase uncertain payment retry query $compact', (
      tester,
    ) async {
      narrow = compact;
      await card(tester, 'uncertain');
      transport.writeGate = Completer<void>();
      await tap(tester, find.text('Pay \$219'));
      await capture(
        tester,
        'payment-pending',
        'Payment POST held → processing and disabled fields',
      );
      await tester.binding.handlePopRoute();
      await settle(tester);
      await capture(
        tester,
        'payment-back-blocked',
        'Framework Back during payment → dialog retained',
      );
      transport.failingWrites.add(payPath);
      transport.writeGate!.complete();
      await tester.pumpAndSettle();
      await capture(
        tester,
        'payment-uncertain',
        'Payment POST 503 → uncertain outcome and retry/query',
      );
      expect(
        tester.widget<EditableText>(find.byType(EditableText).first).readOnly,
        isTrue,
      );
      transport.failingWrites.clear();
      transport.readGates[orderPath] = Completer<void>();
      await tap(tester, find.text('Check status'));
      await capture(
        tester,
        'query-pending',
        'Query uncertain order → GET pending',
      );
      transport.failingReads.add(orderPath);
      transport.readGates[orderPath]!.complete();
      await tester.pumpAndSettle();
      await capture(
        tester,
        'query-error',
        'Order GET 503 → preserve uncertain outcome',
      );
      transport.failingReads.clear();
      await tap(tester, find.text('Try payment again'));
      await capture(
        tester,
        'same-payment-recovered',
        'Retry retained payment outcome → paid benefits',
      );
      final pays = transport.requests
          .where((r) => r['path'] == payPath)
          .toList();
      expect(pays, hasLength(2));
      expect(pays.first['body'], pays.last['body']);
      await tap(tester, find.text('Book later'));
      await capture(
        tester,
        'later-booking',
        'Book later → owned package without appointment',
      );
      expect(transport.appointment, isNull);
      await returnHome(tester, 'uncertain');
    });
    testWidgets(
      'current purchase cancelled challenge reconciling and entitlement sync $compact',
      (tester) async {
        narrow = compact;
        await card(tester, 'reconcile');
        await edit(tester, 0, '4000 0025 0000 3155');
        await tap(tester, find.text('Pay \$219'));
        await capture(
          tester,
          'challenge-to-cancel',
          'Bank challenge before cancellation',
        );
        await tap(tester, find.text('Cancel payment'));
        await capture(
          tester,
          'challenge-cancelled',
          'Cancel challenge → cancelled order without benefits',
        );
        expect(transport.episode, isNull);
        await tap(tester, find.text('Back to plan'));
        await capture(
          tester,
          'cancelled-package',
          'Cancelled order → purchase available again',
        );
        await tap(tester, find.text('Purchase'));
        await ready(tester);
        await tap(tester, find.text('Confirm and continue'));
        await capture(
          tester,
          'replacement-card',
          'New purchase after cancellation → distinct order',
        );
        expect(transport.order!['id'], 'service-order-2');
        transport.paymentStatusOverride = 'processing';
        await tap(tester, find.text('Pay \$219'));
        await capture(
          tester,
          'processing',
          'Server processing → query instead of duplicate payment',
        );
        transport.order!['status'] = 'reconciling';
        await tap(tester, find.text('Check status'));
        await capture(
          tester,
          'reconciling',
          'Query returns reconciliation → confirmation notice',
        );
        transport.order!['status'] = 'paid';
        await tap(tester, find.text('Check status'));
        await capture(
          tester,
          'paid-awaiting-benefits',
          'Paid but no episode → synchronizing benefits',
        );
        expect(find.text('Book an appointment'), findsNothing);
        transport.episode = transport.newEpisode();
        await tap(tester, find.text('Check status'));
        await capture(
          tester,
          'benefits-synced',
          'Query returns episode → success',
        );
        await tap(tester, find.text('Book later'));
        await capture(tester, 'synced-package', 'Book later → owned package');
        await returnHome(tester, 'reconcile');
      },
    );
    testWidgets(
      'current purchase plain cancellation and reconciliation completion $compact',
      (tester) async {
        narrow = compact;
        await card(tester, 'cancel');
        await tap(tester, find.text('Cancel payment'));
        await capture(
          tester,
          'plain-cancelled',
          'Cancel before submitting card → cancelled order',
        );
        await tap(tester, find.text('Back to plan'));
        await capture(
          tester,
          'plain-cancel-return',
          'Cancelled payment Back → package',
        );
        await tap(tester, find.text('Purchase'));
        await ready(tester);
        await tap(tester, find.text('Confirm and continue'));
        transport.paymentStatusOverride = 'reconciling';
        await tap(tester, find.text('Pay \$219'));
        await capture(
          tester,
          'simulation-incomplete',
          'Sandbox reconciliation before explicit completion',
        );
        transport.paymentStatusOverride = null;
        await tap(tester, find.text('Complete simulated payment'));
        await capture(
          tester,
          'simulation-completed',
          'Complete simulated payment → success',
        );
        await tap(tester, find.text('Book later'));
        await capture(
          tester,
          'simulation-package',
          'Close success → owned package',
        );
        await returnHome(tester, 'cancel');
      },
    );
  }
}
