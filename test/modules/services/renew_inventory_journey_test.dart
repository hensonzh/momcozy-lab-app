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
import '../../support/renew_inventory_transport.dart';
import 'package:momcozy_flutter_app/modules/services/presentation/service_renew_page.dart';
import '../../support/fixture_api_transport.dart';
import '../../support/fake_agent_voice.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);
  setUpAll(() => WidgetController.hitTestWarningShouldBeFatal = true);
  late RenewInventoryTransport transport;
  late MomCozyRuntimeController runtime;
  late GoRouter router;
  String? previous;
  Future<void> mount(
    WidgetTester tester, {
    void Function(RenewInventoryTransport)? prepare,
    bool loading = false,
    double width = 393,
    double textScale = 1,
  }) async {
    previous = null;
    FlutterSecureStorage.setMockInitialValues({});
    tester.view.physicalSize = Size(width, 844);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    transport = RenewInventoryTransport();
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
    await tester.tap(find.text('Me'));
    if (loading) {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    } else {
      await tester.pumpAndSettle();
    }
    expect(router.state.uri.path, '/me');
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
      final scrollable = find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.restorationId != 'editable' &&
                (widget.axisDirection == AxisDirection.down ||
                    widget.axisDirection == AxisDirection.up),
          )
          .last;
      // ListView may have disposed an earlier header. Search from the top
      // using pointer gestures before walking toward a later lazy child.
      for (
        var attempt = 0;
        attempt < 20 &&
            tester.state<ScrollableState>(scrollable).position.pixels > 0;
        attempt++
      ) {
        await tester.drag(scrollable, const Offset(0, 600));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      }
      await tester.scrollUntilVisible(target, 300, scrollable: scrollable);
    } else {
      await tester.ensureVisible(target);
    }
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // A focused field can schedule its own scroll after ensureVisible. Recheck
    // the actual hit target after layout, retaining fatal missed-hit checks.
    for (
      var attempt = 0;
      attempt < 3 && target.hitTestable().evaluate().isEmpty;
      attempt++
    ) {
      await tester.ensureVisible(target);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }
    await tester.tap(target);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  }

  Future<void> capture(
    WidgetTester tester,
    String state,
    String action, {
    String route = '/services/episodes/completed-episode/renew',
  }) async {
    // Commit edits and finish the input hint's fade without settling spinners.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(router.state.uri.path, route);
    expect(tester.takeException(), isNull);
    final width = tester.view.physicalSize.width.round();
    final scale = tester.platformDispatcher.textScaleFactor;
    final suffix = '$width${scale == 1 ? '' : '-${scale.round()}x'}';
    final source = 'test/goldens/ui_inventory/renew-journey-$state-$suffix.png';
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/ui_inventory/renew-journey-$state-$suffix.png',
      ),
    );
    final row = {
      'source': source,
      'previous_source': previous,
      'route': route,
      'trigger': action,
      'root_entry': 'Authenticated More → tap Me bottom navigation',
      'evidence':
          'Actual MomCozyFlutterApp/createMomCozyRouter, production home/timeline/renew/purchase pages and repositories; isolated HTTP with completed original service preserved independently; fixed clock and timezone, no remote order/payment',
      'test': 'test/modules/services/renew_inventory_journey_test.dart',
    };
    previous = source;
    final output = Platform.environment['MOMCOZY_UI_INVENTORY_DIR'];
    if (output != null) {
      final file = File('$output/journeys/renew-journey-$state-$suffix.json');
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(row)}\n',
      );
    }
  }

  const progressRoute = '/services/episodes/completed-episode';
  const renewRoute = '$progressRoute/renew';
  Future<void> entry(WidgetTester tester, {VoidCallback? beforeRenew}) async {
    await tap(tester, find.text('服务进度 ›'));
    expect(router.state.uri.path, progressRoute);
    await capture(
      tester,
      'completed-progress',
      'More → Me → completed service progress; continue support CTA',
      route: progressRoute,
    );
    beforeRenew?.call();
    await tap(tester, find.text('继续支持'));
    expect(router.state.uri.path, renewRoute);
  }

  Future<void> frame(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  Future<void> createOrder(WidgetTester tester) async {
    await tap(tester, find.text('选择').first);
    await tap(tester, find.byType(DropdownButtonFormField<String>));
    await tap(tester, find.text('California (CA)').last);
    await tap(tester, find.byType(CheckboxListTile));
    await tap(tester, find.text('确认并继续'));
  }

  Future<void> refresh(WidgetTester tester) async {
    final scroll = find
        .descendant(
          of: find.byType(ServiceRenewPage),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.drag(scroll, const Offset(0, 1200));
    await tester.pumpAndSettle();
    await tester.drag(scroll, const Offset(0, 450));
    await frame(tester);
  }

  for (final size in [(393.0, 1.0), (320.0, 2.0)]) {
    testWidgets(
      'inventory completed service renewal purchase and return ${size.$1}',
      (tester) async {
        await mount(tester, width: size.$1, textScale: size.$2);
        await entry(tester);
        await capture(
          tester,
          'list',
          'Completed timeline continue support → original package highlighted in actual renewal route',
        );
        await tap(tester, find.text('选择').first);
        await capture(
          tester,
          'eligibility',
          'Choose highlighted package → existing purchase eligibility dialog',
        );
        await tap(tester, find.byTooltip('关闭购买'));
        expect(transport.order, isNull);
        await capture(
          tester,
          'selection-cancelled',
          'Close eligibility → selected card retained without creating an order',
        );
        await createOrder(tester);
        await capture(
          tester,
          'payment',
          'Choose state and confirm → new sandbox order and card form',
        );
        await tester.enterText(
          find.byType(TextFormField).first,
          '4242 4242 4242 4242',
        );
        await tap(tester, find.text('支付 \$219'));
        expect(transport.order!['status'], 'paid');
        expect(transport.completedEpisode['status'], 'completed');
        await capture(
          tester,
          'paid',
          'Sandbox payment succeeds → new service; original remains completed',
        );
        await tap(tester, find.text('开始预约'));
        await capture(
          tester,
          'booking',
          'Purchase success → actual new service booking/precheck',
          route: '/services/episodes/service-episode/booking',
        );
        await tap(tester, find.byTooltip('关闭预约前确认'));
        await tap(tester, find.text('返回'));
        await capture(
          tester,
          'purchase-return',
          'Booking back → renewal list now offers view current service',
        );
        await tap(tester, find.text('查看我的服务'));
        await capture(
          tester,
          'active-progress',
          'View current service → actual newly purchased progress',
          route: '/services/episodes/service-episode',
        );
        await tap(tester, find.text('返回'));
        await capture(
          tester,
          'active-return',
          'New service progress back → renewal list',
        );
        await tap(tester, find.text('返回'));
        await capture(
          tester,
          'completed-return',
          'Renewal back → original completed service timeline',
          route: progressRoute,
        );
        await finish(tester);
      },
    );

    testWidgets(
      'inventory completed service pending order read and cancel ${size.$1}',
      (tester) async {
        await mount(
          tester,
          width: size.$1,
          textScale: size.$2,
          prepare: (t) => t.pendingOrder(),
        );
        await entry(tester);
        await capture(
          tester,
          'pending-listed',
          'Completed service renew → pending matching order exposes continue payment',
        );
        const path = '/v1/care/orders/service-order';
        transport.readGates[path] = Completer<void>();
        await tap(tester, find.text('继续付款'));
        await capture(
          tester,
          'order-loading',
          'Continue payment → order read pending, package buttons disabled',
        );
        transport.failingReads.add(path);
        transport.readGates.remove(path)!.complete();
        await frame(tester);
        final list = find
            .descendant(
              of: find.byType(ServiceRenewPage),
              matching: find.byType(Scrollable),
            )
            .first;
        // The inline error is above the package card and may be unbuilt after
        // scrolling to its CTA on a narrow screen. Return using real gestures.
        while (tester.state<ScrollableState>(list).position.pixels > 0) {
          await tester.drag(list, const Offset(0, 600));
          await tester.pumpAndSettle();
        }
        expect(find.text('暂时无法打开订单，请重新选择方案重试。'), findsOneWidget);
        await capture(
          tester,
          'order-error',
          'Order read fails → scroll to top → inline open error and selectable packages',
        );
        transport.failingReads.clear();
        await tap(tester, find.text('继续付款'));
        await capture(
          tester,
          'order-resumed',
          'Retry package → existing payment dialog without creating duplicate order',
        );
        await tap(tester, find.byTooltip('关闭购买'));
        await capture(
          tester,
          'pending-closed',
          'Close payment → pending order stays resumable',
        );
        expect(
          transport.requests.where((r) => r['path'] == '/v1/care/orders'),
          isEmpty,
        );
        await finish(tester);
      },
    );
  }

  testWidgets('inventory renewal loading retry empty and refresh', (
    tester,
  ) async {
    await mount(tester);
    await entry(
      tester,
      beforeRenew: () =>
          transport.readGates['/v1/care/catalog'] = Completer<void>(),
    );
    await capture(tester, 'loading', 'Continue support → catalog HTTP pending');
    transport.failingReads.add('/v1/care/catalog');
    transport.readGates.remove('/v1/care/catalog')!.complete();
    await frame(tester);
    await capture(tester, 'load-error', 'Catalog error → retry');
    transport.failingReads.clear();
    final packages = transport.responsesByPath['/v1/care/catalog']!['packages'];
    transport.responsesByPath['/v1/care/catalog']!['packages'] = [];
    await tap(tester, find.text('重试'));
    await capture(
      tester,
      'empty',
      'Retry returns no packages → empty support list',
    );
    transport.responsesByPath['/v1/care/catalog']!['packages'] = packages;
    await tap(tester, find.text('刷新方案'));
    await capture(
      tester,
      'empty-refreshed',
      'Refresh plans → catalog restored',
    );
    transport.responsesByPath['/v1/care/catalog']!['payment_mode'] = 'disabled';
    await refresh(tester);
    await tester.pumpAndSettle();
    expect(find.text('暂未开放购买'), findsWidgets);
    await capture(
      tester,
      'purchase-disabled',
      'Pull to refresh receives disabled payment mode → buttons disabled',
    );
    await finish(tester);
  });
}
