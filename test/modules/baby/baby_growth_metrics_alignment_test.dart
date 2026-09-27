import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/baby/baby_record.dart';
import 'package:momcozy_flutter_app/domain/shared/local_date.dart';
import 'package:momcozy_flutter_app/modules/baby/application/baby_home_controller.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_overview_cards.dart';

import 'baby_test_repositories.dart';

void main() {
  for (final width in [320.0, 393.0, 430.0]) {
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
          final valueTops = [
            for (final item in values.evaluate())
              tester.getTopLeft(find.byElementPredicate((e) => e == item)).dy,
          ];
          expect(valueTops.map((v) => v.round()).toSet(), hasLength(1));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
