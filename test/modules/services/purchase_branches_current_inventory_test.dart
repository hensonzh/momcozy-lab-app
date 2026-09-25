import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  late _PurchaseBranchTransport transport;
  late MomCozyRuntimeController runtime;
  late GoRouter router;
  String? previous;
  final launches = <MethodCall>[];
  var launchAllowed = false, launchThrows = false;
  Completer<bool>? launchGate;
  const channel = MethodChannel('plugins.flutter.io/url_launcher');
  var narrow = false;
  late String variant;
  Future<void> mount(
    WidgetTester tester, {
    void Function(_PurchaseBranchTransport)? prepare,
    bool loading = false,
  }) async {
    previous = null;
    launches.clear();
    launchAllowed = false;
    launchThrows = false;
    launchGate = null;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      expect(call.method, 'launch');
      launches.add(call);
      if (launchThrows) throw PlatformException(code: 'unavailable');
      return launchGate == null ? launchAllowed : await launchGate!.future;
    });
    addTearDown(() {
      if (launchGate != null && !launchGate!.isCompleted) {
        launchGate!.complete(false);
      }
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      );
    });
    variant = narrow ? '320-2x' : '393-1x';
    tester.platformDispatcher.textScaleFactorTestValue = narrow ? 2 : 1;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    FlutterSecureStorage.setMockInitialValues({});
    tester.view.physicalSize = Size(narrow ? 320 : 393, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    transport = _PurchaseBranchTransport();
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
        (launchGate != null && !launchGate!.isCompleted) ||
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
        'test/goldens/ui_inventory/purchase-branches-current-$state-$variant.png';
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/ui_inventory/purchase-branches-current-$state-$variant.png',
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
      'test':
          'test/modules/services/purchase_branches_current_inventory_test.dart',
    };
    previous = source;
    final output = Platform.environment['MOMCOZY_UI_INVENTORY_DIR'];
    if (output != null) {
      final file = File(
        '$output/journeys/purchase-branches-current-$state-$variant.json',
      );
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(row)}\n',
      );
    }
  }

  Future<void> entry(
    WidgetTester tester,
    String chain, {
    bool stripe = false,
  }) async {
    await mount(
      tester,
      prepare: (t) {
        t.stripe = stripe;
        if (stripe) {
          t.responsesByPath['/v1/care/catalog']!['payment_mode'] = 'stripe';
        }
      },
    );
    await capture(
      tester,
      '$chain-home',
      'More before conditional purchase',
      route: '/more',
    );
    await tap(tester, find.byType(MomExpertPlanEntry));
    await capture(
      tester,
      '$chain-catalog',
      'More Expert support → catalog',
      route: '/services',
    );
    for (
      var i = 0;
      i < 30 && find.text('View plans →').hitTestable().evaluate().isEmpty;
      i++
    ) {
      await tester.drag(find.byType(ListView).last, const Offset(0, -240));
      await settle(tester);
    }
    await tap(tester, find.text('View plans →').hitTestable().first);
    await capture(tester, '$chain-package', 'Catalog → package');
    await tap(tester, find.text('Purchase'));
  }

  Future<void> ready(WidgetTester tester) async {
    await tap(tester, find.byType(DropdownButtonFormField<String>));
    await tap(tester, find.text('California (CA)').last);
    await tap(tester, find.byType(CheckboxListTile));
  }

  Future<void> card(
    WidgetTester tester,
    String chain, {
    bool stripe = false,
  }) async {
    await entry(tester, chain, stripe: stripe);
    await ready(tester);
    await tap(tester, find.text('Confirm and continue'));
    await capture(
      tester,
      '$chain-payment',
      'Eligibility → configured payment mode',
    );
  }

  Future<void> back(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await settle(tester);
  }

  Future<void> finish(WidgetTester tester, String chain) async {
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
      'Catalog Back → More',
      route: '/more',
    );
    await tester.pumpWidget(const SizedBox());
  }

  const orderPath = '/v1/care/orders/service-order';
  const payPath = '$orderPath/sandbox-payment';
  const checkoutPath = '$orderPath/checkout';
  for (final compact in [false, true]) {
    testWidgets(
      'current purchase idle dismissal and reopened verification $compact',
      (tester) async {
        narrow = compact;
        await entry(tester, 'resume');
        await capture(
          tester,
          'eligibility-idle',
          'Untouched eligibility before dismissal',
        );
        await tester.tapAt(const Offset(5, 5));
        await settle(tester);
        await capture(
          tester,
          'eligibility-outside-retained',
          'Outside click → non-dismissible purchase remains',
        );
        await back(tester);
        await capture(
          tester,
          'eligibility-back-dismissed',
          'Framework Back while idle → package',
        );
        expect(transport.order, isNull);
        await tap(tester, find.text('Purchase'));
        await ready(tester);
        await tap(tester, find.text('Confirm and continue'));
        await capture(
          tester,
          'new-card',
          'Create order → editable sandbox form',
        );
        await tester.ensureVisible(find.byType(TextFormField).first);
        await settle(tester);
        await tester.enterText(
          find.byType(TextFormField).first,
          '4000 0025 0000 3155',
        );
        await tap(tester, find.text('Pay \$219'));
        await capture(
          tester,
          'submitted-challenge',
          'Submitted card → challenge with locked fields',
        );
        await tap(tester, find.byTooltip('Close purchase'));
        await capture(
          tester,
          'challenge-closed',
          'Close challenge → resumable package',
        );
        await tap(tester, find.text('Continue to payment'));
        await capture(
          tester,
          'challenge-reopened',
          'Reopen requiresAction order → verification without card fields',
        );
        expect(find.byType(TextFormField), findsNothing);
        await back(tester);
        await capture(
          tester,
          'challenge-back-dismissed',
          'Idle framework Back → resumable package',
        );
        await tap(tester, find.text('Continue to payment'));
        await tap(tester, find.text('Confirm verification'));
        await capture(
          tester,
          'reopened-challenge-success',
          'Confirm reopened challenge → paid episode',
        );
        await tap(tester, find.byTooltip('Close purchase'));
        await capture(tester, 'success-close', 'Success Close → owned package');
        expect(transport.appointment, isNull);
        await finish(tester, 'resume');
      },
    );
    testWidgets('current purchase order and payment business errors $compact', (
      tester,
    ) async {
      narrow = compact;
      await entry(tester, 'errors');
      await ready(tester);
      final messages = {
        401: 'Your session has expired. Sign in again to continue.',
        403: 'This account cannot access this order.',
        409:
            'The order status has changed. Check the latest status before continuing.',
        422: 'Check your information and try again.',
      };
      transport.failingWrites.add('/v1/care/orders');
      for (final row in messages.entries) {
        transport.failureStatus = row.key;
        await tap(tester, find.text('Confirm and continue'));
        await capture(
          tester,
          'create-${row.key}',
          'Create HTTP ${row.key} → specific business error',
        );
        expect(find.text(row.value), findsOneWidget);
        expect(transport.order, isNull);
      }
      transport.failingWrites.clear();
      await tap(tester, find.text('Try again'));
      await capture(
        tester,
        'create-business-recovered',
        'Retry creation after rejected responses → same order form',
      );
      transport.failingWrites.add(payPath);
      for (final row in messages.entries) {
        transport.failureStatus = row.key;
        await tap(tester, find.text('Pay \$219'));
        await capture(
          tester,
          'payment-${row.key}',
          'Payment HTTP ${row.key} → specific error and query action',
        );
        expect(find.text(row.value), findsOneWidget);
        expect(
          tester.widget<EditableText>(find.byType(EditableText).first).readOnly,
          isFalse,
        );
      }
      transport.failingWrites.clear();
      await tap(tester, find.text('Check status'));
      await capture(
        tester,
        'business-query-recovered',
        'Query actual pending order → error cleared',
      );
      await tap(tester, find.text('Cancel payment'));
      await capture(
        tester,
        'business-cancelled',
        'Cancel recovered pending order → no benefits',
      );
      await tap(tester, find.text('Back to plan'));
      await finish(tester, 'errors');
    });
    testWidgets(
      'current Stripe checkout failure launch pending and query $compact',
      (tester) async {
        narrow = compact;
        await card(tester, 'stripe', stripe: true);
        expect(find.byType(TextFormField), findsNothing);
        transport.writeGate = Completer<void>();
        await tap(tester, find.text('Open Stripe Checkout'));
        await capture(
          tester,
          'checkout-pending',
          'Checkout POST pending → preparing and close disabled',
        );
        await back(tester);
        await capture(
          tester,
          'checkout-back-blocked',
          'Framework Back during checkout preparation → retained',
        );
        transport.failingWrites.add(checkoutPath);
        transport.writeGate!.complete();
        await tester.pumpAndSettle();
        await capture(
          tester,
          'checkout-error',
          'Checkout POST 503 → order notice and retry',
        );
        expect(launches, isEmpty);
        transport.failingWrites.clear();
        await tap(tester, find.text('Open Stripe Checkout'));
        await capture(
          tester,
          'launch-rejected',
          'Checkout URL returned, platform refuses launch → explicit opening error',
        );
        expect(launches, hasLength(1));
        expect(
          (launches.last.arguments as Map)['url'],
          'https://checkout.stripe.com/c/pay/inventory-only',
        );
        launchThrows = true;
        await tap(tester, find.text('Open Stripe Checkout'));
        expect(launches, hasLength(2));
        expect(find.text('Payment page did not open'), findsOneWidget);
        launchThrows = false;
        launchGate = Completer<bool>();
        await tap(tester, find.text('Open Stripe Checkout'));
        await capture(
          tester,
          'launch-pending',
          'Platform launch request pending → processing controls',
        );
        await back(tester);
        await capture(
          tester,
          'launch-back-blocked',
          'Framework Back while opening external URL → retained',
        );
        launchGate!.complete(true);
        await tester.pumpAndSettle();
        await capture(
          tester,
          'launch-accepted',
          'Platform reports URL opened → App ready for query, no payment inferred',
        );
        expect(find.text('Payment page did not open'), findsNothing);
        expect(transport.order!['status'], 'pending');
        transport.readGates[orderPath] = Completer<void>();
        await tap(tester, find.text('I have paid · Check status'));
        await capture(
          tester,
          'stripe-query-pending',
          'Return/query from external payment → order GET pending',
        );
        transport.failingReads.add(orderPath);
        transport.readGates[orderPath]!.complete();
        await tester.pumpAndSettle();
        await capture(
          tester,
          'stripe-query-error',
          'Order query 503 → retry retained',
        );
        transport.failingReads.clear();
        transport.order!['status'] = 'cancelled';
        await tap(tester, find.text('Check status'));
        await capture(
          tester,
          'stripe-cancelled',
          'Query cancelled external payment → no service benefits',
        );
        expect(transport.episode, isNull);
        await tap(tester, find.text('Back to plan'));
        await capture(
          tester,
          'stripe-cancel-return',
          'Cancelled Stripe order → package',
        );
        await tap(tester, find.text('Purchase'));
        await ready(tester);
        await tap(tester, find.text('Confirm and continue'));
        await capture(
          tester,
          'stripe-repurchase',
          'Repurchase after cancellation → new Stripe order',
        );
        transport.order!['status'] = 'failed';
        await tap(tester, find.text('I have paid · Check status'));
        await capture(
          tester,
          'stripe-failed',
          'Query returns failed → reopen checkout or query',
        );
        transport.order!['status'] = 'processing';
        await tap(tester, find.text('I have paid · Check status'));
        await capture(
          tester,
          'stripe-processing',
          'Query processing → only query, no sandbox completion',
        );
        expect(find.text('Complete simulated payment'), findsNothing);
        transport.order!['status'] = 'paid';
        await tap(tester, find.text('Check status'));
        await capture(
          tester,
          'stripe-syncing',
          'Stripe paid without episode → entitlement sync',
        );
        transport.episode = transport.newEpisode();
        await tap(tester, find.text('Check status'));
        await capture(
          tester,
          'stripe-success',
          'Query paid episode → success and booking actions',
        );
        await tap(tester, find.text('Book later'));
        await capture(tester, 'stripe-owned', 'Book later → owned package');
        expect(
          transport.requests.where(
            (r) => (r['path'] as String).endsWith('/sandbox-payment'),
          ),
          isEmpty,
        );
        await finish(tester, 'stripe');
      },
    );
  }
}

class _PurchaseBranchTransport extends ServiceInventoryTransport {
  bool stripe = false;
  @override
  Map<String, Object?> newOrder([String status = 'pending']) => {
    ...super.newOrder(status),
    'payment_mode': stripe ? 'stripe' : 'sandbox',
  };
  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    if (!path.endsWith('/checkout')) {
      return super.postJson(path, body: body, headers: headers);
    }
    requests.add({
      'path': path,
      'body': Map<String, Object?>.from(body),
      'headers': Map<String, String>.from(headers),
    });
    mutationPaths.add(path);
    await writeGate?.future;
    check(failWrite || failingWrites.contains(path));
    return {
      'checkout_url': 'https://checkout.stripe.com/c/pay/inventory-only',
      'purchase': purchase,
    };
  }
}
