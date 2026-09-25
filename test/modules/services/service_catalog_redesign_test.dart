import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
      'name':
          'Personalized Feeding and Lactation Support for Your Growing Family',
      'price_minor': 123456789,
      'currency': 'CAD',
    });
    json['providers'] = [
      {
        'user_id': 'expert',
        'display_name': 'Alexandra Catherine · IBCLC',
        'timezone': 'America/Toronto',
        'regions': ['CA'],
        'languages': ['English', '中文', 'Français'],
        'bio':
            'Personalized feeding support that helps your family build a practical, sustainable routine.' *
            5,
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
        if (scale == 2) {
          final title = tester.renderObject<RenderParagraph>(
            find.text('Expert support'),
          );
          expect(title.didExceedMaxLines, isFalse);
        }
        expect(find.text('View plans →'), findsNothing);
        await shot(tester, 'loading');
        repo.offline = true;
        repo.readGate!.complete();
        await tester.pumpAndSettle();
        await shot(tester, 'initial-error');
        repo.offline = false;
        repo.empty = true;
        await tester.tap(find.text('Try again'));
        await tester.pumpAndSettle();
        await reveal(tester, find.text('No service plans available'));
        await shot(tester, 'empty');
        repo.empty = false;
        await tester.drag(find.byType(ListView), const Offset(0, 2500));
        await tester.pumpAndSettle();
        await tester.drag(find.byType(ListView), const Offset(0, 500));
        await tester.pumpAndSettle();
        await reveal(tester, find.text('Feeding Confidence'));
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
        expect(find.text('My care plan'), findsNothing);
        await reveal(tester, find.text('Continue to payment'));
        await shot(tester, 'pending-order');
        await tester.tap(find.text('Continue to payment'));
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
        await reveal(tester, find.text('View my services'));
        expect(find.text('Continue to payment'), findsNothing);
        expect(find.text('Care paused'), findsOneWidget);
        expect(find.text('Current stage · Ongoing follow-up'), findsOneWidget);
        expect(find.text('1 of 3 consultations left'), findsOneWidget);
        expect(find.text('Feeding Confidence'), findsOneWidget);
        await reveal(tester, find.text('My care plan'), delta: 240);
        await shot(tester, 'paused-plan');
        await reveal(tester, find.text('View my services'));
        await tester.tap(find.text('View my services'));
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
        await reveal(tester, find.text('Meet the team'));
        await tester.tap(find.text('Meet the team'));
        await tester.pumpAndSettle();
        expect(find.text('English · Chinese · French'), findsOneWidget);
        await shot(tester, 'long-team');
        final dialogScroll = find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(Scrollable),
        );
        await tester.scrollUntilVisible(
          find.text('You will see and confirm your consultant before booking.'),
          240,
          scrollable: dialogScroll,
        );
        await tester.pumpAndSettle();
        await shot(tester, 'team-bottom');
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsNothing);
        await reveal(tester, find.text('CAD 1234567.89'));
        await shot(tester, 'long-price');
        await reveal(tester, find.text('View plans →').first);
        await tester.tap(find.text('View plans →').first);
        await tester.pumpAndSettle();
        expect(opened?.id, 'feeding-confidence');
        expect(opened?.currency, 'CAD');
        expect(opened?.priceMinor, 123456789);
      },
    );
  }
}
