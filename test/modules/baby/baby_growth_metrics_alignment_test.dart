import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/baby/baby_record.dart';
import 'package:momcozy_flutter_app/domain/shared/local_date.dart';
import 'package:momcozy_flutter_app/modules/baby/application/baby_home_controller.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_overview_cards.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_home_page.dart';

import '../../support/momcozy_test_fonts.dart';
import 'baby_test_repositories.dart';

int linesFor(WidgetTester tester, Finder finder) {
  final text = tester.widget<Text>(finder);
  final painter = TextPainter(
    text: TextSpan(text: text.data, style: text.style),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: tester.getSize(finder).width);
  final lines = painter.computeLineMetrics().length;
  painter.dispose();
  return lines;
}

void main() {
  setUpAll(() async {
    await loadMomCozyTestFonts();
    await (FontLoader(
      'BabyNotoSans',
    )..addFont(rootBundle.load('assets/fonts/BabyNotoSans-VF.ttf'))).load();
  });
  for (final width in [320.0, 393.0, 430.0]) {
    testWidgets('today check-in cards stay side by side at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = BabyHomeController(
        profileRepository: BabyTestProfiles(),
        recordRepository: BabyTestRecords(),
        timezoneProvider: () async => 'Asia/Shanghai',
        now: () => babyTestNow,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BabyHomePage(controller: controller, onAsk: (_) {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text("Today's check-in"), 180);
      await tester.ensureVisible(find.byType(BabyStatusCard).first);
      await tester.pumpAndSettle();
      final cards = find.byType(BabyStatusCard);
      expect(cards, findsNWidgets(3));
      final bounds = [for (var i = 0; i < 3; i++) tester.getRect(cards.at(i))];
      expect(bounds.map((r) => r.top.round()).toSet(), hasLength(1));
      expect(bounds[0].right, lessThan(bounds[1].left));
      expect(bounds[1].right, lessThan(bounds[2].left));
      for (var i = 0; i < 3; i++) {
        final empty = find.descendant(
          of: cards.at(i),
          matching: find.text('No entry yet'),
        );
        expect(empty, findsOneWidget);
        expect(tester.widget<Text>(empty).maxLines, 1);
      }
      expect(tester.takeException(), isNull);
    });

    for (final recorded in [false, true]) {
      testWidgets(
        'growth cards share height and value baseline at $width (recorded: $recorded)',
        (tester) async {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final controller = BabyHomeController(
            profileRepository: BabyTestProfiles(),
            recordRepository: BabyTestRecords()
              ..values = recorded
                  ? [
                      for (final metric in GrowthMetric.values)
                        BabyGrowthRecord(
                          id: metric.name,
                          babyId: babyTestProfile.id,
                          recordedOn: LocalDate(2026, 9, 8),
                          timezone: 'Asia/Shanghai',
                          metric: metric,
                          value: metric == GrowthMetric.weight ? 4.2 : 54,
                        ),
                    ]
                  : [],
            timezoneProvider: () async => 'Asia/Shanghai',
            now: () => babyTestNow,
          );
          addTearDown(controller.dispose);
          await controller.load();
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: BabyGrowthMetrics(
                    controller: controller,
                    onRecord: (_) {},
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final cards = find.byType(InkWell);
          final bounds = [
            for (final card in cards.evaluate())
              tester.getRect(find.byElementPredicate((e) => e == card)),
          ];
          expect(bounds, hasLength(3));
          expect(bounds.map((r) => r.top).toSet(), hasLength(1));
          expect(bounds.map((r) => r.bottom).toSet(), hasLength(1));
          final values = recorded
              ? find.textContaining(RegExp(r'^(4\.2 kg|54 cm)$'))
              : find.text('No entry yet');
          expect(values, findsNWidgets(3));
          if (!recorded) {
            for (final item in values.evaluate()) {
              final text = find.byElementPredicate((e) => e == item);
              expect(linesFor(tester, text), 1);
            }
            final labels = <String>['Weight', 'Length', 'Head\ncircumference'];
            for (var i = 0; i < labels.length; i++) {
              final label = find.text(labels[i]);
              final value = find.byElementPredicate(
                (e) => e == values.evaluate().elementAt(i),
              );
              final distance =
                  tester.getTopLeft(value).dy - tester.getBottomLeft(label).dy;
              expect(distance, lessThanOrEqualTo(10));
            }
            expect(linesFor(tester, find.text('Head\ncircumference')), 2);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
