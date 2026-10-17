@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/baby/baby_record.dart';
import 'package:momcozy_flutter_app/domain/shared/local_date.dart';
import 'package:momcozy_flutter_app/features/app_pages/chat_first_baby_details_page.dart';
import 'package:momcozy_flutter_app/modules/baby/application/baby_home_controller.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';

import '../../modules/baby/baby_test_repositories.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);

  for (final (width, scale, empty) in [
    (390.0, 1.0, false),
    (320.0, 2.0, true),
  ]) {
    testWidgets('baby details saved and empty state $width/$scale', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final profiles = BabyTestProfiles();
      if (empty) profiles.values = [];
      final records = BabyTestRecords();
      if (!empty) {
        records.values = [
          BabyFeedingRecord(
            id: 'feeding-1',
            babyId: 'baby',
            occurredAt: babyTestNow.subtract(const Duration(hours: 1)),
            method: BabyFeedingMethod.formula,
            volumeMl: 75,
          ),
          BabyDailyStatusRecord(
            id: 'daily-1',
            babyId: 'baby',
            recordedOn: LocalDate(2026, 9, 8),
            timezone: 'UTC',
            savedAt: babyTestNow,
            wetCount: 2,
          ),
          BabyGrowthRecord(
            id: 'growth-1',
            babyId: 'baby',
            recordedOn: LocalDate(2026, 9, 7),
            timezone: 'UTC',
            metric: GrowthMetric.weight,
            value: 3.8,
          ),
        ];
      }
      final controller = BabyHomeController(
        profileRepository: profiles,
        recordRepository: records,
        timezoneProvider: () async => 'UTC',
        now: () => babyTestNow,
        selectedBabyId: 'baby',
      );
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: momCozyTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: Scaffold(
            body: ChatFirstBabyDetailsPage(
              controller: controller,
              onRecordSleep: (_) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Add your baby to get started'), findsNothing);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          '../../goldens/chat_first/baby-details-${empty ? 'empty-' : ''}${width.toInt()}-${scale.toInt()}x.png',
        ),
      );
      if (!empty) {
        await tester.tap(find.byKey(const ValueKey('baby-details-knowledge')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('baby-knowledge-topic-sleep')),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('仰卧'), findsWidgets);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            '../../goldens/chat_first/baby-knowledge-sleep-390-1x.png',
          ),
        );
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
}
