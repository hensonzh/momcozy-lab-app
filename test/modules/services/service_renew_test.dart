import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/care/care_episode.dart';
import 'package:momcozy_flutter_app/domain/care/care_order.dart';
import 'package:momcozy_flutter_app/domain/care/service_package.dart';
import 'package:momcozy_flutter_app/domain/shared/product_failure.dart';
import 'package:momcozy_flutter_app/services/care/care_codec.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import '../../support/momcozy_test_fonts.dart';
import 'package:momcozy_flutter_app/modules/services/presentation/service_renew_page.dart';

const _provider = CareProvider(
  id: 'expert',
  displayName: 'Test IBCLC',
  timezone: 'America/Los_Angeles',
  regions: ['CA'],
  languages: ['English'],
  bio: 'Test provider',
  sandbox: true,
);

final _now = DateTime.now().toUtc();
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

class _Repository implements CareRepository {
  bool listed = false, offline = false, empty = false, failRead = false;
  PaymentMode mode = PaymentMode.sandbox;
  Completer<void>? pendingRead, pendingCatalog;
  Purchase current = Purchase(order: _order());
  int eligibilityCalls = 0, purchaseCalls = 0;
  final createKeys = <String>[];
  final outcomes = <SandboxPaymentOutcome>[];
  Future<Purchase>? nextCreate, nextPayment;
  @override
  Future<ServiceCatalog> catalog() async {
    await pendingCatalog?.future;
    if (offline) throw const ProductFailure(ProductFailureKind.offline);
    final c = _catalog(mode: mode);
    return ServiceCatalog(
      packages: empty ? [] : c.packages,
      providers: [_provider],
      availableRegions: c.availableRegions,
      paymentMode: c.paymentMode,
    );
  }

  @override
  Future<CareOverview> overview() async => CareOverview(
    orders: [if (listed) current.order],
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
    listed = true;
    return nextCreate ?? current;
  }

  @override
  Future<Purchase> purchase(String orderId) async {
    purchaseCalls++;
    if (pendingRead != null) await pendingRead!.future;
    if (failRead) throw const ProductFailure(ProductFailureKind.offline);
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

Future<void> _mount(
  WidgetTester tester,
  _Repository repo, {
  double width = 390,
  double scale = 1,
  double height = 844,
  bool settle = true,
  VoidCallback? onBack,
  ValueChanged<CareEpisode>? onBook,
  ValueChanged<CareEpisode>? onProgress,
}) async {
  await loadMomCozyTestFonts();
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: momCozyTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: ServiceRenewPage(
        repository: repo,
        onBack: onBack ?? () {},
        onBook: onBook ?? (_) {},
        onProgress: onProgress ?? (_) {},
        episodeId: 'episode',
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

Future<void> click(WidgetTester tester, String label) async {
  final f = find.text(label).first;
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> shot(
  WidgetTester tester,
  String name,
  double width,
  double scale,
) async {
  expect(tester.takeException(), isNull);
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile(
      '../../goldens/design_system/renew-$name-${width.toInt()}${scale == 2 ? '-2x' : ''}.png',
    ),
  );
}

void main() {
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'renew selection opens existing eligibility flow $width/$scale',
        (tester) async {
          final repo = _Repository();
          await _mount(tester, repo, width: width, scale: scale);
          await shot(tester, 'list', width, scale);
          await click(tester, '选择');
          expect(find.text('购买前确认'), findsOneWidget);
          expect(repo.createKeys, isEmpty);
          await shot(tester, 'eligibility', width, scale);
          await tester.tap(find.byTooltip('关闭购买'));
          await tester.pumpAndSettle();
          await shot(tester, 'selected', width, scale);
          expect(repo.createKeys, isEmpty);
        },
      );
    }
  }
  testWidgets('renew pays through existing controller and opens new booking', (
    tester,
  ) async {
    final repo = _Repository();
    CareEpisode? booked;
    await _mount(tester, repo, onBook: (e) => booked = e);
    await click(tester, '选择');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('California (CA)').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await click(tester, '确认并继续');
    expect(repo.createKeys, hasLength(1));
    await click(tester, '支付 \$219');
    expect(repo.outcomes, [SandboxPaymentOutcome.succeeded]);
    await click(tester, '开始预约');
    expect(booked, _episode);
  });
  testWidgets(
    'pending order reopens without new purchase; retry locks duplicate taps',
    (tester) async {
      final repo = _Repository()
        ..listed = true
        ..failRead = true;
      await _mount(tester, repo);
      await shot(tester, 'pending-listed', 390, 1);
      await click(tester, '继续付款');
      expect(repo.purchaseCalls, 1);
      expect(find.text('暂时无法打开订单，请重新选择方案重试。'), findsOneWidget);
      await shot(tester, 'order-error', 390, 1);
      repo.failRead = false;
      repo.pendingRead = Completer<void>();
      await tester.ensureVisible(find.text('继续付款'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('继续付款'));
      await tester.pump();
      for (final button in tester.widgetList<FilledButton>(
        find.byType(FilledButton),
      )) {
        expect(button.onPressed, isNull);
      }
      expect(repo.purchaseCalls, 2);
      await shot(tester, 'order-loading', 390, 1);
      repo.pendingRead!.complete();
      await tester.pumpAndSettle();
      expect(find.text('支付 \$219'), findsOneWidget);
      expect(repo.createKeys, isEmpty);
      await tester.tap(find.byTooltip('关闭购买'));
      await tester.pumpAndSettle();
      // Returning from the payment sheet retains the list's previous offset.
      // The matching first package can be above the current lazy viewport.
      await tester.scrollUntilVisible(
        find.text('继续付款'),
        -250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('继续付款'), findsOneWidget);
      expect(repo.createKeys, isEmpty);
    },
  );
  testWidgets('ongoing service navigates without making a new order', (
    tester,
  ) async {
    final repo = _Repository()
      ..listed = true
      ..current = Purchase(
        order: _order(status: CareOrderStatus.paid),
        episode: _episode,
      );
    CareEpisode? opened;
    await _mount(tester, repo, onProgress: (e) => opened = e);
    await shot(tester, 'ongoing', 390, 1);
    await click(tester, '查看我的服务');
    expect(opened, _episode);
    expect(repo.createKeys, isEmpty);
    expect(repo.purchaseCalls, 0);
  });
  testWidgets('disabled purchase, empty catalog, offline retry are explicit', (
    tester,
  ) async {
    final repo = _Repository()..mode = PaymentMode.disabled;
    await _mount(tester, repo);
    await shot(tester, 'disabled', 390, 1);
    for (final b in tester.widgetList<FilledButton>(
      find.byType(FilledButton),
    )) {
      expect(b.onPressed, isNull);
    }
    repo.empty = true;
    await tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pumpAndSettle();
    expect(find.text('暂无可选的支持方案'), findsOneWidget);
    await shot(tester, 'empty', 390, 1);
    repo.offline = true;
    await click(tester, '刷新方案');
    await shot(tester, 'offline', 390, 1);
    repo.offline = false;
    repo.empty = false;
    repo.mode = PaymentMode.sandbox;
    await tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pumpAndSettle();
    expect(find.text('选择'), findsWidgets);
  });
  testWidgets(
    'short large catalog loads, scrolls and returns without ordering',
    (tester) async {
      final repo = _Repository()..pendingCatalog = Completer<void>();
      var backed = false;
      await _mount(
        tester,
        repo,
        width: 320,
        scale: 2,
        height: 568,
        settle: false,
        onBack: () => backed = true,
      );
      expect(find.text('正在读取支持方案'), findsOneWidget);
      await shot(tester, 'short-loading', 320, 2);
      repo.pendingCatalog!.complete();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('舒适哺乳支持'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await shot(tester, 'short-last-package', 320, 2);
      await tester.tap(find.byTooltip('返回'));
      expect(backed, isTrue);
      expect(repo.createKeys, isEmpty);
    },
  );
  for (final status in [
    CareEpisodeStatus.paused,
    CareEpisodeStatus.provisioningPending,
  ]) {
    testWidgets(
      'owned service remains reachable with purchase disabled $status',
      (tester) async {
        final e = CareEpisode(
          id: 'episode',
          orderId: 'order',
          packageId: 'feeding-confidence',
          status: status,
          stage: CareStage.followUp,
          totalSessions: 2,
          remainingSessions: 1,
          version: 2,
          assignedIbclcId: _provider.id,
        );
        final repo = _Repository()
          ..mode = PaymentMode.disabled
          ..listed = true
          ..current = Purchase(
            order: _order(status: CareOrderStatus.paid),
            episode: e,
          );
        CareEpisode? opened;
        await _mount(
          tester,
          repo,
          width: 320,
          scale: 2,
          height: 568,
          onProgress: (e) => opened = e,
        );
        expect(
          find.text(status == CareEpisodeStatus.paused ? '服务已暂停' : '已购服务'),
          findsOneWidget,
        );
        expect(find.text(_provider.displayName), findsOneWidget);
        expect(find.text('剩余 1 / 2 次咨询'), findsOneWidget);
        await click(tester, '查看我的服务');
        expect(opened, same(e));
        expect(repo.purchaseCalls, 0);
        expect(repo.createKeys, isEmpty);
        await shot(tester, 'short-owned-${status.name}', 320, 2);
      },
    );
  }
  testWidgets('refresh prevents selection until current catalog is ready', (
    tester,
  ) async {
    final repo = _Repository();
    await _mount(tester, repo);
    repo.pendingCatalog = Completer<void>();
    final refresh = tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    for (final b in tester.widgetList<FilledButton>(
      find.byType(FilledButton),
    )) {
      expect(b.onPressed, isNull);
    }
    expect(repo.createKeys, isEmpty);
    repo.pendingCatalog!.complete();
    await refresh;
    await tester.pumpAndSettle();
    await click(tester, '选择');
    expect(find.text('购买前确认'), findsOneWidget);
    expect(repo.createKeys, isEmpty);
  });
}
