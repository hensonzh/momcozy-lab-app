import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/care/care_episode.dart';
import 'package:momcozy_flutter_app/domain/care/care_order.dart';
import 'package:momcozy_flutter_app/domain/care/service_package.dart';
import 'package:momcozy_flutter_app/modules/services/presentation/service_package_page.dart';
import '../../support/momcozy_test_fonts.dart';
import 'service_catalog_states_test.dart' as fixture;

class _Repository extends fixture.CatalogFixture {
  Completer<void>? gate;
  CareEpisode? episode;
  @override
  Future<ServiceCatalog> catalog() async {
    await gate?.future;
    return super.catalog();
  }

  @override
  Future<CareOverview> overview() async =>
      CareOverview(orders: [if (pending) order], episodes: [?episode]);
}

void main() {
  setUpAll(loadMomCozyTestFonts);
  for (final size in [(393.0, 1.0), (320.0, 2.0)]) {
    final (width, scale) = size;
    final suffix = '${width.toInt()}-${scale.toInt()}x';
    Future<void> mount(
      WidgetTester tester,
      _Repository repo, {
      ValueChanged<CareEpisode>? onBook,
      ValueChanged<CareEpisode>? onProgress,
    }) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        fixture.host(
          ServicePackagePage(
            repository: repo,
            packageId: 'feeding-confidence',
            onBack: () {},
            onBook: onBook ?? (_) {},
            onProgress: onProgress ?? (_) {},
          ),
          scale,
        ),
      );
      await tester.pump();
    }

    Future<void> shot(WidgetTester tester, String state) async {
      expect(tester.takeException(), isNull);
      final title =
          (tester.widget<AppBar>(find.byType(AppBar)).title! as Text).data!;
      final titleFinder = find.descendant(
        of: find.byType(AppBar),
        matching: find.text(title),
      );
      expect(
        tester.renderObject<RenderParagraph>(titleFinder).didExceedMaxLines,
        isFalse,
        reason: 'The service title must not ellipsize at $suffix',
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          '../../goldens/ui_refactor/package-$state-$suffix.png',
        ),
      );
    }

    testWidgets('package loading failure retry and missing state $suffix', (
      tester,
    ) async {
      final repo = _Repository()..gate = Completer<void>();
      await mount(tester, repo);
      expect(find.text('Purchase'), findsNothing);
      await shot(tester, 'loading');
      repo.offline = true;
      repo.gate!.complete();
      await tester.pumpAndSettle();
      await shot(tester, 'error');
      repo.offline = false;
      repo.empty = true;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Could not find this service plan'), findsOneWidget);
      expect(find.text('Purchase'), findsNothing);
      await shot(tester, 'missing');
      expect(repo.createCalls, 0);
    });

    testWidgets(
      'package ongoing plan preserves booking priority over pending order $suffix',
      (tester) async {
        final episode = CareEpisode(
          id: 'active',
          orderId: 'paid',
          packageId: 'feeding-confidence',
          status: CareEpisodeStatus.paused,
          stage: CareStage.followUp,
          totalSessions: 3,
          remainingSessions: 1,
          version: 2,
        );
        final repo = _Repository()
          ..pending = true
          ..episode = episode;
        CareEpisode? booked, progress;
        await mount(
          tester,
          repo,
          onBook: (e) => booked = e,
          onProgress: (e) => progress = e,
        );
        await tester.pumpAndSettle();
        expect(find.text('My care plan'), findsOneWidget);
        expect(find.text('Continue to payment'), findsNothing);
        await shot(tester, 'owned-top');
        await tester.tap(find.text('Book an appointment'));
        expect(booked, same(episode));
        final action = find.text('View service progress');
        for (
          var i = 0;
          i < 20 && action.hitTestable().evaluate().isEmpty;
          i++
        ) {
          await tester.drag(find.byType(ListView), const Offset(0, -220));
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(action);
        await tester.pumpAndSettle();
        expect(find.text('1 of 3 consultations left'), findsOneWidget);
        await shot(tester, 'owned-progress');
        await tester.tap(action);
        expect(progress, same(episode));
        expect(repo.purchaseReads, 0);
        expect(repo.createCalls, 0);
        expect(repo.paymentCalls, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
