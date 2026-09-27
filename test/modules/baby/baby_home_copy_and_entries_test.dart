import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/modules/baby/application/baby_home_controller.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_home_page.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_growth_curve.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_record_editor.dart';

import 'baby_test_repositories.dart';

void main() {
  testWidgets(
    'Baby home uses consistent empty copy and card-only record entry',
    (tester) async {
      final home = BabyHomeController(
        profileRepository: BabyTestProfiles(),
        recordRepository: BabyTestRecords(),
        timezoneProvider: () async => 'Asia/Shanghai',
        now: () => babyTestNow,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BabyHomePage(controller: home, onAsk: (_) {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Not recorded yet'), findsNothing);
      expect(find.text('No entry yet'), findsWidgets);
      expect(find.text('Log'), findsNothing);

      await tester.tap(find.text('No entry yet').first);
      await tester.pumpAndSettle();
      expect(find.byType(BabyRecordEditor), findsOneWidget);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Growth'), 180);
      expect(find.text('Growth'), findsOneWidget);
      expect(find.text('Growth & development'), findsNothing);
      final segmented = find.descendant(
        of: find.byType(BabyGrowthCurve),
        matching: find.text('Head circumference'),
      );
      await tester.scrollUntilVisible(segmented, 180);
      final segmentedLabel = tester.widget<Text>(segmented);
      expect(segmentedLabel.textAlign, TextAlign.center);
    },
  );
}
