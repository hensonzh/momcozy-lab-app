import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/care/care_episode.dart';
import 'package:momcozy_flutter_app/domain/care/care_order.dart';
import 'package:momcozy_flutter_app/domain/care/service_package.dart';
import 'package:momcozy_flutter_app/modules/services/presentation/service_catalog_page.dart';
import 'package:momcozy_flutter_app/services/care/care_codec.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import '../../support/momcozy_test_fonts.dart';
import 'service_catalog_states_test.dart' as fixture;

class _Repository extends fixture.CatalogFixture {
  Completer<void>? readGate;
  CareOverview view = const CareOverview(orders: [], episodes: []);
  bool longCopy = false;
  @override
  Future<CareOverview> overview() async => view;
  @override
  Future<ServiceCatalog> catalog() async {
    await readGate?.future;
    final catalog = await super.catalog();
    if (!longCopy) return catalog;
    final json =
        jsonDecode(
              File(
                'test/fixtures/product_baseline/care_catalog.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    (json['packages'] as List).first.addAll({
      'name': '持续喂养支持与个性化泌乳陪伴计划',
      'price_minor': 123456789,
      'currency': 'CAD',
    });
    json['providers'] = [
      {
        'user_id': 'expert',
        'display_name': 'Alexandra Catherine · IBCLC 专家',
        'timezone': 'America/Toronto',
        'regions': ['CA'],
        'languages': ['English', '中文', 'Français'],
        'bio': '提供个性化喂养支持，结合家庭安排讨论可持续的计划。' * 5,
        'sandbox': true,
      },
    ];
    return readServiceCatalog(json);
  }
}

CareEpisode _episode(CareEpisodeStatus status) => CareEpisode(
  id: 'episode',
  orderId: 'paid',
  packageId: 'feeding-confidence',
  status: status,
  stage: CareStage.followUp,
  totalSessions: 3,
  remainingSessions: 1,
  version: 2,
);
void main() {
  setUpAll(loadMomCozyTestFonts);
  for (final size in [(393.0, 1.0), (320.0, 2.0)]) {
    final (width, scale) = size;
    final suffix = '${width.toInt()}-${scale.toInt()}x';
    Future<void> mount(
      WidgetTester tester,
      _Repository repo, {
      ValueChanged<ServicePackage>? onSelect,
    }) async {
      tester.view.physicalSize = Size(width, 844);
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
          home: ServiceCatalogPage(
            repository: repo,
            onSelect: onSelect ?? (_) {},
            onBack: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    Future<void> shot(WidgetTester tester, String state) async {
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          '../../goldens/ui_refactor/catalog-$state-$suffix.png',
        ),
      );
    }

    Future<void> reveal(
      WidgetTester tester,
      Finder target, {
      double delta = -240,
    }) async {
      for (var i = 0; i < 40 && target.hitTestable().evaluate().isEmpty; i++) {
        await tester.drag(find.byType(ListView), Offset(0, delta));
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      expect(target.hitTestable(), findsWidgets);
    }

    testWidgets(
      'catalog initial failure empty and pull refresh recovery $suffix',
      (tester) async {
        final repo = _Repository()..readGate = Completer<void>();
        await mount(tester, repo);
        expect(find.text('查看方案 →'), findsNothing);
        await shot(tester, 'loading');
        repo.offline = true;
        repo.readGate!.complete();
        await tester.pumpAndSettle();
        await shot(tester, 'initial-error');
        repo.offline = false;
        repo.empty = true;
        await tester.tap(find.text('重试'));
        await tester.pumpAndSettle();
        await reveal(tester, find.text('暂无可用的服务方案'));
        await shot(tester, 'empty');
        repo.empty = false;
        await tester.drag(find.byType(ListView), const Offset(0, 2500));
        await tester.pumpAndSettle();
        await tester.drag(find.byType(ListView), const Offset(0, 500));
        await tester.pumpAndSettle();
        await reveal(tester, find.text('喂养安心'));
        expect(repo.createCalls, 0);
        expect(repo.paymentCalls, 0);
      },
    );
    testWidgets(
      'pending order wins and refresh reveals ongoing plan without duplicate package $suffix',
      (tester) async {
        final repo = _Repository();
        repo.view = CareOverview(
          orders: [repo.order],
          episodes: [_episode(CareEpisodeStatus.active)],
        );
        ServicePackage? opened;
        await mount(tester, repo, onSelect: (p) => opened = p);
        await tester.pumpAndSettle();
        expect(find.text('我的陪伴计划'), findsNothing);
        await reveal(tester, find.text('继续付款'));
        await shot(tester, 'pending-order');
        await tester.tap(find.text('继续付款'));
        await tester.pumpAndSettle();
        expect(opened?.id, 'feeding-confidence');
        expect(repo.purchaseReads, 0);
        repo.view = CareOverview(
          orders: [],
          episodes: [_episode(CareEpisodeStatus.paused)],
        );
        await tester.drag(find.byType(ListView), const Offset(0, 4000));
        await tester.pumpAndSettle();
        await tester.drag(find.byType(ListView), const Offset(0, 500));
        await tester.pumpAndSettle();
        await reveal(tester, find.text('查看我的服务'));
        expect(find.text('继续付款'), findsNothing);
        expect(find.text('服务已暂停'), findsOneWidget);
        expect(find.text('当前阶段 · 持续跟进'), findsOneWidget);
        expect(find.text('剩余 1 / 3 次咨询'), findsOneWidget);
        expect(find.text('喂养安心'), findsOneWidget);
        await reveal(tester, find.text('我的陪伴计划'), delta: 240);
        await shot(tester, 'paused-plan');
        await reveal(tester, find.text('查看我的服务'));
        await tester.tap(find.text('查看我的服务'));
        expect(opened?.id, 'feeding-confidence');
        expect(repo.createCalls, 0);
        expect(repo.paymentCalls, 0);
      },
    );
    testWidgets(
      'long names currency and provider biography stay scrollable $suffix',
      (tester) async {
        final repo = _Repository()..longCopy = true;
        ServicePackage? opened;
        await mount(tester, repo, onSelect: (p) => opened = p);
        await tester.pumpAndSettle();
        await shot(tester, 'discovery');
        await reveal(tester, find.text('了解团队'));
        await tester.tap(find.text('了解团队'));
        await tester.pumpAndSettle();
        await shot(tester, 'long-team');
        final dialogScroll = find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(Scrollable),
        );
        await tester.scrollUntilVisible(
          find.text('预约确认前，你会看到并确认本次具体专家。'),
          240,
          scrollable: dialogScroll,
        );
        await tester.pumpAndSettle();
        await shot(tester, 'team-bottom');
        await tester.tap(find.text('关闭'));
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsNothing);
        await reveal(tester, find.text('CAD 1234567.89'));
        await shot(tester, 'long-price');
        await reveal(tester, find.text('查看方案 →').first);
        await tester.tap(find.text('查看方案 →').first);
        await tester.pumpAndSettle();
        expect(opened?.id, 'feeding-confidence');
        expect(opened?.currency, 'CAD');
        expect(opened?.priceMinor, 123456789);
      },
    );
  }
}
