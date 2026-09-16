import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:momcozy_flutter_app/domain/care/care_order.dart';
import 'package:momcozy_flutter_app/domain/care/service_package.dart';
import 'package:momcozy_flutter_app/domain/shared/product_failure.dart';
import 'package:momcozy_flutter_app/modules/services/presentation/service_catalog_page.dart';
import 'package:momcozy_flutter_app/modules/services/presentation/service_package_page.dart';
import 'package:momcozy_flutter_app/modules/services/presentation/service_purchase_dialog.dart';
import 'package:momcozy_flutter_app/services/care/care_codec.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import '../../support/momcozy_test_fonts.dart';

class CatalogFixture extends Fake implements CareRepository {
  final data = readServiceCatalog(
    Map<String, Object?>.from(
      jsonDecode(
            File(
              'test/fixtures/product_baseline/care_catalog.json',
            ).readAsStringSync(),
          )
          as Map,
    ),
  );
  bool offline = false, empty = false, pending = false;
  int purchaseReads = 0, createCalls = 0, paymentCalls = 0;
  Completer<Purchase>? purchaseGate;
  CareOrder get order => CareOrder(
    id: 'pending',
    packageId: data.packages.first.id,
    status: CareOrderStatus.pending,
    priceMinor: 21900,
    currency: 'USD',
    durationDays: 7,
    totalSessions: 2,
    paymentMode: PaymentMode.sandbox,
    region: 'CA',
    version: 1,
    createdAt: DateTime(2026, 9, 12),
    updatedAt: DateTime(2026, 9, 12),
  );
  @override
  Future<Purchase> createOrder({
    required String eligibilityId,
    required String idempotencyKey,
  }) async {
    createCalls++;
    throw StateError('Pre-purchase preview must not create an order');
  }

  @override
  Future<Purchase> sandboxPayment(
    String orderId, {
    required int expectedVersion,
    required SandboxPaymentOutcome outcome,
  }) async {
    paymentCalls++;
    throw StateError('Pre-purchase preview must not pay');
  }

  @override
  Future<ServiceCatalog> catalog() async {
    if (offline) throw const ProductFailure(ProductFailureKind.offline);
    return ServiceCatalog(
      packages: empty ? [] : data.packages,
      providers: data.providers,
      availableRegions: const ['CA'],
      paymentMode: data.paymentMode,
    );
  }

  @override
  Future<CareOverview> overview() async =>
      CareOverview(orders: [if (pending) order], episodes: const []);
  @override
  Future<Purchase> purchase(String id) async {
    purchaseReads++;
    return purchaseGate?.future ?? Purchase(order: order);
  }
}

Widget host(Widget child, [double scale = 1]) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: momCozyTheme(),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: child,
);

void main() {
  setUpAll(loadMomCozyTestFonts);
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'four catalog packages open the matching detail and purchase confirmation $width/$scale',
        (tester) async {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final repo = CatalogFixture();
          final router = GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => ServiceCatalogPage(
                  repository: repo,
                  onSelect: (p) => context.push('/services/${p.id}'),
                  onBack: () {},
                ),
              ),
              GoRoute(
                path: '/services/:id',
                builder: (context, state) => ServicePackagePage(
                  repository: repo,
                  packageId: state.pathParameters['id']!,
                  onBack: () => context.pop(),
                  onBook: (_) {},
                  onProgress: (_) {},
                ),
              ),
            ],
          );
          addTearDown(router.dispose);
          await tester.pumpWidget(
            MaterialApp.router(
              debugShowCheckedModeBanner: false,
              theme: momCozyTheme(),
              routerConfig: router,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
            ),
          );
          await tester.pumpAndSettle();
          Future<void> shot(String name) async {
            expect(tester.takeException(), isNull);
            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile(
                '../../goldens/design_system/catalog-state-$name-${width.toInt()}${scale == 2 ? '-2x' : ''}.png',
              ),
            );
          }

          await shot('list-top');
          for (final package in repo.data.packages) {
            await tester.scrollUntilVisible(
              find.text(package.name),
              300,
              scrollable: find.byType(Scrollable).first,
            );
            await tester.pumpAndSettle();
            final card = find.ancestor(
              of: find.text(package.name),
              matching: find.byWidgetPredicate(
                (w) => w.runtimeType.toString() == '_PackageCard',
              ),
            );
            final button = find.descendant(
              of: card,
              matching: find.text('查看方案 →'),
            );
            await tester.ensureVisible(button);
            await tester.pumpAndSettle();
            await tester.tap(button);
            await tester.pumpAndSettle();
            expect(find.text('${package.name}服务包'), findsOneWidget);
            expect(find.text(package.description), findsOneWidget);
            expect(
              find.text('${package.priceLabel} USD').hitTestable(),
              findsOneWidget,
            );
            await shot('${package.id}-top');
            for (final text in [
              ...package.expertServices,
              ...package.continuousServices,
            ]) {
              await tester.scrollUntilVisible(
                find.text(text),
                200,
                scrollable: find.byType(Scrollable).first,
              );
              await tester.pumpAndSettle();
              expect(find.text(text).hitTestable(), findsOneWidget);
            }
            await shot('${package.id}-bottom');
            await tester.tap(find.text('购买'));
            await tester.pumpAndSettle();
            expect(find.text('购买前确认'), findsOneWidget);
            expect(
              tester
                  .widget<ServicePurchaseDialog>(
                    find.byType(ServicePurchaseDialog),
                  )
                  .package
                  .id,
              package.id,
            );
            // Closing the pre-purchase confirmation never creates an order or starts payment.
            await tester.tap(find.byTooltip('关闭购买'));
            await tester.pumpAndSettle();
            await tester.tap(find.text('返回'));
            await tester.pumpAndSettle();
          }
          expect(repo.purchaseReads, 0);
          expect(repo.createCalls, 0);
          expect(repo.paymentCalls, 0);
        },
      );
    }
  }
  testWidgets(
    'catalog refresh failures remain visible and can recover without losing packages',
    (tester) async {
      final repo = CatalogFixture();
      await tester.pumpWidget(
        host(
          ServiceCatalogPage(repository: repo, onSelect: (_) {}, onBack: () {}),
        ),
      );
      await tester.pumpAndSettle();
      repo.offline = true;
      await tester.drag(find.byType(ListView), const Offset(0, 500));
      await tester.pumpAndSettle();
      expect(find.text('网络未连接，请连接后重试'), findsOneWidget);
      expect(find.text(repo.data.packages.first.name), findsOneWidget);
      repo.offline = false;
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(find.text('网络未连接，请连接后重试'), findsNothing);
    },
  );
  testWidgets('catalog with no packages explains empty state', (tester) async {
    final repo = CatalogFixture()..empty = true;
    await tester.pumpWidget(
      host(
        ServiceCatalogPage(repository: repo, onSelect: (_) {}, onBack: () {}),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('暂无可用的服务方案'), findsOneWidget);
  });
  testWidgets(
    'resuming an order shows busy state, blocks repeats and recovers read failure',
    (tester) async {
      final repo = CatalogFixture()
        ..pending = true
        ..purchaseGate = Completer<Purchase>();
      await tester.pumpWidget(
        host(
          ServicePackagePage(
            repository: repo,
            packageId: repo.data.packages.first.id,
            onBack: () {},
            onBook: (_) {},
            onProgress: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('继续付款'));
      await tester.pump();
      expect(find.text('正在打开…'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '正在打开…'))
            .onPressed,
        isNull,
      );
      expect(repo.purchaseReads, 1);
      repo.purchaseGate!.completeError(
        const ProductFailure(ProductFailureKind.offline),
      );
      await tester.pumpAndSettle();
      expect(find.text('暂时无法打开订单，请稍后重试'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '继续付款'))
            .onPressed,
        isNotNull,
      );
    },
  );
}
