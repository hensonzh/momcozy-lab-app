import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/baby/baby_record.dart';
import 'package:momcozy_flutter_app/domain/shared/local_date.dart';
import 'package:momcozy_flutter_app/domain/shared/product_failure.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_records_page.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import '../../support/momcozy_test_fonts.dart';
import 'baby_test_repositories.dart';

class _PagedRecords extends BabyTestRecords {
  bool failMore = false;
  Completer<void>? moreGate;
  final offsets = <int>[];
  @override
  Future<BabyRecordPage> list({
    required String babyId,
    required LocalDate startDate,
    required LocalDate endDate,
    required String timezone,
    BabyRecordKind? kind,
    int offset = 0,
    int limit = 100,
  }) async {
    offsets.add(offset);
    if (offset > 0) {
      await moreGate?.future;
      if (failMore) throw const ProductFailure(ProductFailureKind.offline);
    }
    return super.list(
      babyId: babyId,
      startDate: startDate,
      endDate: endDate,
      timezone: timezone,
      kind: kind,
      offset: offset,
      limit: limit,
    );
  }
}

void main() {
  setUpAll(loadMomCozyTestFonts);
  for (final (width, scale) in [(390.0, 1.0), (320.0, 2.0)]) {
    testWidgets(
      'record redesign keeps paging recovery and filters $width/$scale',
      (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repo = _PagedRecords()
          ..values = [
            for (var i = 0; i < 51; i++)
              BabyFeedingRecord(
                id: 'feed-$i',
                babyId: 'baby',
                occurredAt: babyTestNow.subtract(Duration(minutes: i)),
                method: BabyFeedingMethod.expressedMilk,
                volumeMl: 50 + i.toDouble(),
                version: 1,
              ),
          ];
        var back = 0;
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
            home: BabyRecordsPage(
              babyId: 'baby',
              profiles: BabyTestProfiles(),
              repository: repo,
              timezoneProvider: () async => 'Asia/Shanghai',
              now: () => babyTestNow,
              onBack: () => back++,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget<Text>(find.text('Luna 的记录')).style!.fontFamily,
          'NotoSansSCHome',
        );
        Future<void> capture(String state) async {
          expect(tester.takeException(), isNull);
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              '../../goldens/design_system/baby-records-current-$state-${width.toInt()}-${scale.toInt()}x.png',
            ),
          );
        }

        Future<void> reach(Finder f, {double delta = 500}) async {
          if (f.evaluate().isEmpty) {
            await tester.scrollUntilVisible(
              f,
              delta,
              scrollable: find.byType(Scrollable).first,
              maxScrolls: 80,
            );
          }
          await tester.ensureVisible(f);
          await tester.pumpAndSettle();
        }

        await capture('list');
        await reach(find.text('加载更多'));
        repo.failMore = true;
        await tester.tap(find.text('加载更多'));
        await tester.pumpAndSettle();
        expect(repo.offsets.last, 50);
        expect(find.text('重试'), findsOneWidget);
        await reach(find.text('重试'));
        await capture('page-error');
        repo.failMore = false;
        repo.moreGate = Completer<void>();
        await tester.tap(find.text('重试'));
        await tester.pump();
        expect(find.text('正在载入…'), findsOneWidget);
        await capture('page-loading');
        repo.moreGate!.complete();
        await tester.pumpAndSettle();
        await reach(find.text('瓶喂母乳 · 100 ml'));
        await capture('page-recovered');
        expect(find.text('加载更多'), findsNothing);
        await reach(find.text('睡眠'), delta: -600);
        await tester.tap(find.text('睡眠'));
        await tester.pumpAndSettle();
        await reach(find.text('本月还没有睡眠记录'));
        await capture('empty');
        await reach(find.byTooltip('上个月'), delta: -300);
        await tester.tap(find.byTooltip('上个月'));
        await tester.pumpAndSettle();
        expect(find.text('2026年8月'), findsOneWidget);
        await capture('month');
        await tester.tap(find.text('返回'));
        await tester.pumpAndSettle();
        expect(back, 1);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
