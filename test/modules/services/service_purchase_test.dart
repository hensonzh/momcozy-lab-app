import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:momcozy_flutter_app/core/routing/external_url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/care/care_episode.dart';
import 'package:momcozy_flutter_app/domain/care/care_order.dart';
import 'package:momcozy_flutter_app/domain/care/service_package.dart';
import 'package:momcozy_flutter_app/domain/shared/product_failure.dart';
import 'package:momcozy_flutter_app/modules/services/application/service_purchase_controller.dart';
import 'package:momcozy_flutter_app/modules/services/presentation/service_purchase_dialog.dart';
import 'package:momcozy_flutter_app/services/care/care_api_repository.dart';
import 'package:momcozy_flutter_app/services/care/care_codec.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_design_system.dart';
import '../../support/fixture_api_transport.dart';
import '../../support/momcozy_test_fonts.dart';

final _now = DateTime.utc(2026, 9, 8, 10);
ServiceCatalog _catalog({PaymentMode mode = PaymentMode.sandbox}) {
  final json = Map<String, Object?>.from(
    jsonDecode(
          File(
            'test/fixtures/product_baseline/care_catalog.json',
          ).readAsStringSync(),
        )
        as Map,
  );
  json['available_regions'] = ['CA'];
  json['payment_mode'] = mode.name;
  return readServiceCatalog(json);
}

Map<String, Object?> _orderJson({int version = 1, String status = 'pending'}) =>
    {
      'id': 'order',
      'package_id': 'feeding-confidence',
      'price_minor': 21900,
      'duration_days': 7,
      'total_sessions': 2,
      'currency': 'USD',
      'payment_mode': 'sandbox',
      'region': 'CA',
      'version': version,
      'status': status,
      'created_at': _now.toIso8601String(),
      'updated_at': _now.toIso8601String(),
    };
CareOrder _order({
  int version = 1,
  CareOrderStatus status = CareOrderStatus.pending,
}) => readCareOrder(
  _orderJson(version: version, status: orderStatusWire.write(status)!),
);
const _episode = CareEpisode(
  id: 'episode',
  orderId: 'order',
  packageId: 'feeding-confidence',
  status: CareEpisodeStatus.active,
  stage: CareStage.preparation,
  totalSessions: 2,
  remainingSessions: 2,
  version: 1,
);

void main() {
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('purchase states and booking result at $width / $scale', (
        tester,
      ) async {
        final repository = _Repository();
        final controller = ServicePurchaseController(
          repository: repository,
          packageId: 'feeding-confidence',
          now: () => _now,
        );
        addTearDown(controller.dispose);
        CareEpisode? result;
        await _mountPurchase(
          tester,
          controller,
          width: width,
          scale: scale,
          onResult: (value) => result = value,
        );
        await _region(tester, 'California (CA)');
        await _capture(tester, 'eligibility', width, scale);
        expect(
          tester
              .widget<FilledButton>(find.widgetWithText(FilledButton, '确认并继续'))
              .onPressed,
          isNull,
        );
        await _region(tester, 'New York (NY)');
        await tester.ensureVisible(find.byType(CheckboxListTile));
        await tester.tap(find.byType(CheckboxListTile));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<FilledButton>(find.widgetWithText(FilledButton, '确认并继续'))
              .onPressed,
          isNull,
        );
        expect(repository.createKeys, isEmpty);
        await _capture(tester, 'unavailable', width, scale);
        await _region(tester, 'California (CA)');
        await _click(tester, '确认并继续');
        expect(repository.createKeys, hasLength(1));
        await _capture(tester, 'payment', width, scale);
        await tester.enterText(
          find.byType(TextFormField).first,
          '4000 0000 0000 9995',
        );
        await _click(tester, '支付 \$219');
        expect(controller.purchase!.order.status, CareOrderStatus.failed);
        expect(controller.purchase!.episode, isNull);
        await _capture(tester, 'failed', width, scale);
        await tester.ensureVisible(find.byType(TextFormField).first);
        await tester.enterText(
          find.byType(TextFormField).first,
          '4000 0025 0000 3155',
        );
        await _click(tester, '支付 \$219');
        expect(
          controller.purchase!.order.status,
          CareOrderStatus.requiresAction,
        );
        expect(
          tester.widget<TextField>(find.byType(TextField).first).readOnly,
          isTrue,
        );
        await _capture(tester, 'challenge', width, scale);
        await _click(tester, '确认验证');
        expect(controller.purchase!.episode, _episode);
        expect(find.byType(TextFormField), findsNothing);
        await _capture(tester, 'success', width, scale);
        await _click(tester, '开始预约');
        expect(result, _episode);
        expect(find.byType(ServicePurchaseDialog), findsNothing);
        expect(repository.outcomes, [
          SandboxPaymentOutcome.declined,
          SandboxPaymentOutcome.requiresAction,
          SandboxPaymentOutcome.succeeded,
        ]);
      });
    }
  }

  testWidgets(
    'Stripe uses order mode, reports launch failure and queries returned benefits',
    (tester) async {
      final repository = _StripeRepository();
      final launcher = _Launcher();
      final controller = ServicePurchaseController(
        repository: repository,
        packageId: 'feeding-confidence',
        purchase: repository.current,
      );
      addTearDown(controller.dispose);
      await _mountPurchase(tester, controller, launcher: launcher);
      expect(find.byType(TextFormField), findsNothing);
      await _click(tester, '打开 Stripe Checkout');
      expect(launcher.opened, hasLength(1));
      expect(find.text('暂时无法打开支付页面，请重试或查询订单结果。'), findsOneWidget);
      await _capture(tester, 'stripe-launch-error', 390, 1);
      repository.failCheckout = true;
      await _click(tester, '打开 Stripe Checkout');
      expect(launcher.opened, hasLength(1));
      expect(controller.checkoutUrl, isNull);
      repository.failCheckout = false;
      launcher.throws = true;
      await _click(tester, '打开 Stripe Checkout');
      expect(find.text('暂时无法打开支付页面，请重试或查询订单结果。'), findsOneWidget);
      repository.current = Purchase(
        order: readCareOrder({
          ..._orderJson(status: 'paid'),
          'payment_mode': 'stripe',
        }),
        episode: _episode,
      );
      await _click(tester, '我已完成付款，查询结果');
      expect(repository.purchaseCalls, 1);
      expect(find.text('购买成功'), findsOneWidget);
      expect(find.text('打开 Stripe Checkout'), findsNothing);
      expect(find.text('暂时无法打开支付页面，请重试或查询订单结果。'), findsNothing);
      expect(repository.outcomes, isEmpty);
      await _click(tester, '稍后预约');
      expect(find.byType(ServicePurchaseDialog), findsNothing);
    },
  );

  testWidgets(
    'pending payment blocks back and uncertain retry keeps original card and outcome',
    (tester) async {
      final repository = _Repository();
      final controller = ServicePurchaseController(
        repository: repository,
        packageId: 'feeding-confidence',
        purchase: repository.current,
      );
      addTearDown(controller.dispose);
      await _mountPurchase(
        tester,
        controller,
        width: 320,
        height: 568,
        scale: 2,
      );
      await tester.enterText(find.byType(TextFormField).first, '12');
      tester.view.viewInsets = const FakeViewPadding(bottom: 250);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      await _click(tester, '支付 \$219');
      expect(find.text('请填写 16 位测试卡号'), findsOneWidget);
      expect(repository.outcomes, isEmpty);
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(TextFormField).first);
      await tester.enterText(
        find.byType(TextFormField).first,
        '4242 4242 4242 4242',
      );
      final pending = Completer<Purchase>();
      repository.nextPayment = pending.future;
      await _click(tester, '支付 \$219');
      expect(controller.busy, isTrue);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(ServicePurchaseDialog), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) => widget is IconButton && widget.tooltip == '关闭购买',
              ),
            )
            .onPressed,
        isNull,
      );
      pending.completeError(const ProductFailure(ProductFailureKind.offline));
      await tester.pumpAndSettle();
      expect(controller.uncertainPayment, isTrue);
      final field = tester.widget<TextFormField>(
        find.byType(TextFormField).first,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField).first).readOnly,
        isTrue,
      );
      expect(field.controller!.text, '4242 4242 4242 4242');
      repository.nextPayment = null;
      await _click(tester, '重试这笔付款');
      expect(repository.outcomes, [
        SandboxPaymentOutcome.succeeded,
        SandboxPaymentOutcome.succeeded,
      ]);
      expect(find.text('购买成功'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final mode in [PaymentMode.sandbox, PaymentMode.stripe]) {
    testWidgets('cancelled $mode purchase has no payment entry', (
      tester,
    ) async {
      final controller = ServicePurchaseController(
        repository: _Repository(),
        packageId: 'feeding-confidence',
        purchase: Purchase(
          order: readCareOrder({
            ..._orderJson(status: 'cancelled'),
            'payment_mode': mode.name,
          }),
        ),
      );
      addTearDown(controller.dispose);
      await _mountPurchase(tester, controller);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.text('打开 Stripe Checkout'), findsNothing);
      await _click(tester, '返回方案');
      expect(find.byType(ServicePurchaseDialog), findsNothing);
    });
  }

  test('existing backend stripe catalog and order modes decode', () {
    expect(_catalog(mode: PaymentMode.stripe).paymentMode, PaymentMode.stripe);
    expect(
      readCareOrder({..._orderJson(), 'payment_mode': 'stripe'}).paymentMode,
      PaymentMode.stripe,
    );
  });

  test('failed checkout refresh clears the previous destination', () async {
    final repository = _StripeRepository();
    final controller = ServicePurchaseController(
      repository: repository,
      packageId: 'feeding-confidence',
      purchase: repository.current,
    );
    addTearDown(controller.dispose);
    await controller.startStripeCheckout();
    expect(controller.checkoutUrl, isNotNull);
    repository.failCheckout = true;
    await controller.startStripeCheckout();
    expect(controller.checkoutUrl, isNull);
    expect(controller.failure, isNotNull);
  });
  testWidgets(
    'paid order without returned benefits only offers result lookup',
    (tester) async {
      final catalog = _catalog();
      final controller = ServicePurchaseController(
        repository: _Repository(),
        packageId: 'feeding-confidence',
        purchase: Purchase(order: _order(status: CareOrderStatus.paid)),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: momCozyTheme(),
          home: ServicePurchaseDialog(
            controller: controller,
            package: catalog.packages.first,
            catalog: catalog,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNothing);
      expect(find.text('查询结果'), findsOneWidget);
    },
  );

  test(
    'repository posts no price, owner or card data and carries mutation identity',
    () async {
      final transport = FixtureApiJsonTransport({
        'order': _orderJson(),
        'episode': null,
      });
      final repository = CareApiRepository(transport: transport);
      await repository.createOrder(
        eligibilityId: 'eligible',
        idempotencyKey: 'purchase-key',
      );
      expect(transport.lastBody, {'eligibility_id': 'eligible'});
      expect(transport.lastHeaders, {'Idempotency-Key': 'purchase-key'});
      await repository.sandboxPayment(
        'order',
        expectedVersion: 1,
        outcome: SandboxPaymentOutcome.requiresAction,
      );
      expect(transport.lastPath, '/v1/care/orders/order/sandbox-payment');
      expect(transport.lastBody, {
        'expected_version': 1,
        'outcome': 'requires_action',
      });
    },
  );

  test(
    'eligibility needs acknowledgement, failed order creation retains its key, and duplicate taps create once',
    () async {
      final repository = _Repository();
      final controller = ServicePurchaseController(
        repository: repository,
        packageId: 'feeding-confidence',
        now: () => _now,
        mutationKey: () => 'purchase-key',
      );
      addTearDown(controller.dispose);
      controller.setRegion('CA');
      await controller.confirmEligibility();
      expect(repository.eligibilityCalls, 0);
      controller.acknowledge(true);
      final wait = Completer<Purchase>();
      repository.nextCreate = wait.future;
      final first = controller.confirmEligibility();
      await Future<void>.delayed(Duration.zero);
      await controller.confirmEligibility();
      expect(repository.createKeys, ['purchase-key']);
      wait.completeError(const ProductFailure(ProductFailureKind.offline));
      await first;
      expect(controller.purchase, isNull);
      expect(controller.failure?.kind, ProductFailureKind.offline);
      repository.nextCreate = null;
      await controller.confirmEligibility();
      expect(controller.purchase!.order.id, 'order');
      expect(repository.createKeys, ['purchase-key', 'purchase-key']);
      expect(repository.eligibilityCalls, 1);
    },
  );

  test(
    'unconfirmed payment retries original outcome and restores the authoritative purchase',
    () async {
      final repository = _Repository();
      final controller = ServicePurchaseController(
        repository: repository,
        packageId: 'feeding-confidence',
        purchase: Purchase(order: _order()),
      );
      addTearDown(controller.dispose);
      final pending = Completer<Purchase>();
      repository.nextPayment = pending.future;
      final first = controller.pay(SandboxPaymentOutcome.succeeded);
      expect(controller.busy, isTrue);
      await controller.pay(SandboxPaymentOutcome.declined);
      expect(repository.outcomes, hasLength(1));
      pending.completeError(const ProductFailure(ProductFailureKind.offline));
      await first;
      expect(controller.uncertainPayment, isTrue);
      repository.nextPayment = null;
      await controller.pay(SandboxPaymentOutcome.declined);
      expect(repository.outcomes, [
        SandboxPaymentOutcome.succeeded,
        SandboxPaymentOutcome.succeeded,
      ]);
      expect(controller.purchase!.episode!.id, 'episode');
      expect(controller.purchase!.order.version, 2);
      expect(controller.uncertainPayment, isFalse);
    },
  );

  testWidgets(
    'purchase confirms region, handles test verification, then exposes a saved service',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _Repository();
      final catalog = _catalog();
      final controller = ServicePurchaseController(
        repository: repository,
        packageId: 'feeding-confidence',
        now: () => _now,
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) =>
              ColoredBox(color: MomCozyColors.background, child: child!),
          theme: momCozyTheme(),
          home: ServicePurchaseDialog(
            controller: controller,
            package: catalog.packages.first,
            catalog: catalog,
          ),
        ),
      );
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('California (CA)').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.tap(find.text('确认并继续'));
      await tester.pumpAndSettle();
      expect(find.text('测试模式 · 模拟支付，不会产生真实扣款'), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField).first,
        '4000 0025 0000 3155',
      );
      await tester.ensureVisible(find.text('支付 \$219'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('支付 \$219'));
      await tester.pumpAndSettle();
      expect(controller.purchase!.order.status, CareOrderStatus.requiresAction);
      await tester.tap(find.text('确认验证'));
      await tester.pumpAndSettle();
      expect(find.text('购买成功'), findsOneWidget);
      expect(find.text('开始预约'), findsOneWidget);
      expect(controller.purchase!.episode!.remainingSessions, 2);
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('sandbox checkout renders at $width / $scale', (
        tester,
      ) async {
        await loadMomCozyTestFonts();
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final catalog = _catalog();
        final controller = ServicePurchaseController(
          repository: _Repository(),
          packageId: 'feeding-confidence',
          purchase: Purchase(order: _order()),
        );
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          RepaintBoundary(
            key: const ValueKey('capture'),
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: ColoredBox(
                  color: MomCozyColors.background,
                  child: child!,
                ),
              ),
              debugShowCheckedModeBanner: false,
              theme: momCozyTheme(),
              home: ServicePurchaseDialog(
                controller: controller,
                package: catalog.packages.first,
                catalog: catalog,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (scale == 1) {
          await expectLater(
            find.byKey(const ValueKey('capture')),
            matchesGoldenFile(
              '../../goldens/product_baseline/purchase-${width.toInt()}.png',
            ),
          );
        }
        if (scale == 2) {
          for (var step = 0; step < 8; step++) {
            await tester.drag(
              find.byType(Scrollable).first,
              const Offset(0, -400),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
        }
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}

class _Repository implements CareRepository {
  Purchase current = Purchase(order: _order());
  int eligibilityCalls = 0, purchaseCalls = 0;
  final createKeys = <String>[];
  final outcomes = <SandboxPaymentOutcome>[];
  Future<Purchase>? nextCreate, nextPayment;
  @override
  Future<ServiceCatalog> catalog() async => _catalog();
  @override
  Future<CareOverview> overview() async => CareOverview(
    orders: [current.order],
    episodes: [if (current.episode != null) current.episode!],
  );
  @override
  Future<ServiceEligibility> checkEligibility({
    required String packageId,
    required String region,
  }) async {
    eligibilityCalls++;
    return ServiceEligibility(
      id: 'eligible',
      packageId: packageId,
      region: region,
      eligible: region == 'CA',
      expiresAt: _now.add(const Duration(minutes: 30)),
      reason: region == 'CA' ? '' : 'region_unavailable',
    );
  }

  @override
  Future<Purchase> createOrder({
    required String eligibilityId,
    required String idempotencyKey,
  }) async {
    createKeys.add(idempotencyKey);
    return nextCreate ?? current;
  }

  @override
  Future<Purchase> purchase(String orderId) async {
    purchaseCalls++;
    return current;
  }

  @override
  Future<Purchase> sandboxPayment(
    String orderId, {
    required int expectedVersion,
    required SandboxPaymentOutcome outcome,
  }) async {
    outcomes.add(outcome);
    if (nextPayment != null) return nextPayment!;
    final status = switch (outcome) {
      SandboxPaymentOutcome.succeeded => CareOrderStatus.paid,
      SandboxPaymentOutcome.declined => CareOrderStatus.failed,
      SandboxPaymentOutcome.requiresAction => CareOrderStatus.requiresAction,
      SandboxPaymentOutcome.reconciling => CareOrderStatus.reconciling,
      SandboxPaymentOutcome.cancelled => CareOrderStatus.cancelled,
    };
    current = Purchase(
      order: _order(version: expectedVersion + 1, status: status),
      episode: status == CareOrderStatus.paid ? _episode : null,
    );
    return current;
  }
}

class _StripeRepository extends _Repository
    implements StripeCheckoutRepository {
  _StripeRepository() {
    current = Purchase(
      order: readCareOrder({..._orderJson(), 'payment_mode': 'stripe'}),
    );
  }
  bool failCheckout = false;
  @override
  Future<StripeCheckout> stripeCheckout(String orderId) async {
    if (failCheckout) throw const ProductFailure(ProductFailureKind.offline);
    return StripeCheckout(
      url: Uri.parse('https://checkout.stripe.com/c/pay/test'),
      purchase: current,
    );
  }
}

class _Launcher implements ExternalUrlLauncher {
  final opened = <Uri>[];
  bool succeeds = false, throws = false;
  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    if (throws) throw StateError('launcher unavailable');
    return succeeds;
  }
}

Future<void> _mountPurchase(
  WidgetTester tester,
  ServicePurchaseController controller, {
  double width = 390,
  double height = 844,
  double scale = 1,
  ExternalUrlLauncher? launcher,
  ValueChanged<CareEpisode?>? onResult,
}) async {
  await loadMomCozyTestFonts();
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final catalog = _catalog();
  await tester.pumpWidget(
    RepaintBoundary(
      key: const ValueKey('capture'),
      child: MaterialApp(
        theme: momCozyTheme(),
        debugShowCheckedModeBanner: false,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () async {
                  final result = await showDialog<CareEpisode>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => ServicePurchaseDialog(
                      controller: controller,
                      package: catalog.packages.first,
                      catalog: catalog,
                      urlLauncher: launcher ?? _Launcher(),
                    ),
                  );
                  onResult?.call(result);
                },
                child: const Text('打开购买'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('打开购买'));
  await tester.pumpAndSettle();
}

Future<void> _click(WidgetTester tester, String text) async {
  await tester.pumpAndSettle();
  await Scrollable.ensureVisible(
    tester.element(find.text(text)),
    alignment: .5,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

Future<void> _region(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
  await tester.tap(find.byType(DropdownButtonFormField<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> _capture(
  WidgetTester tester,
  String name,
  double width,
  double scale,
) async {
  expect(tester.takeException(), isNull);
  if (scale == 1 || width == 320) {
    await expectLater(
      find.byKey(const ValueKey('capture')),
      matchesGoldenFile(
        '../../goldens/design_system/purchase-$name-${width.toInt()}${scale == 2 ? '-2x' : ''}.png',
      ),
    );
  }
}
