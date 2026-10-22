@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/domain/baby/baby_record.dart';
import 'package:momcozy_flutter_app/domain/shared/local_date.dart';
import 'package:momcozy_flutter_app/features/app_pages/chat_first_baby_page.dart';
import 'package:momcozy_flutter_app/features/app_pages/chat_first_mother_page.dart';
import 'package:momcozy_flutter_app/features/onboarding/domain/chat_first_onboarding.dart';
import 'package:momcozy_flutter_app/modules/baby/application/baby_home_controller.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';

import '../../modules/baby/baby_test_repositories.dart';
import '../../support/fixture_api_transport.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);

  testWidgets('mom overview shows profile, state and recorded pumping', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final transport = FixtureApiJsonTransportByPath({
      '/v1/profile/me-experience': {
        'profile': {
          'age': 31,
          'delivery_count': 1,
          'actual_delivery_date': '2026-10-12',
          'gestation_weeks': 38,
          'gestation_days': 0,
          'baby_count': 1,
        },
        'concerns': const <Object>[],
        'records': const <Object>[],
      },
      '/v1/records/pumping': const {'items': <Object>[]},
      '/v1/records/milk-trends': {
        'items': [
          for (var day = 16; day <= 22; day++)
            {
              'date': '2026-10-$day',
              'pumped_milk_volume_ml': 0,
              'pumping_count': 0,
              'measured_only': true,
              'complete': true,
            },
        ],
      },
    });
    final runtime = MomCozyApiRuntime(
      jsonTransport: transport,
      session: const MomCozySession(
        status: MomCozySessionStatus.authenticated,
        userId: 'owner',
        babyId: '',
        locale: 'zh-CN',
        accessToken: 'token',
      ),
      now: () => DateTime.utc(2026, 10, 22, 8),
      timezoneProvider: () async => 'Asia/Shanghai',
    );
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: momCozyTheme(),
        home: Scaffold(
          body: ChatFirstMotherPage(runtime: runtime, role: FamilyRole.mother),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../goldens/chat_first/mother-overview-390.png'),
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('baby overview identifies current baby and recorded today', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final records = BabyTestRecords()
      ..values = [
        BabyFeedingRecord(
          id: 'f1',
          babyId: 'baby',
          occurredAt: babyTestNow.subtract(const Duration(hours: 1)),
          method: BabyFeedingMethod.formula,
          volumeMl: 90,
        ),
        BabyDailyStatusRecord(
          id: 'd1',
          babyId: 'baby',
          recordedOn: LocalDate(2026, 9, 8),
          timezone: 'UTC',
          savedAt: babyTestNow,
          wetCount: 5,
          stoolCount: 2,
        ),
      ];
    final controller = BabyHomeController(
      profileRepository: BabyTestProfiles(),
      recordRepository: records,
      timezoneProvider: () async => 'UTC',
      now: () => babyTestNow,
      selectedBabyId: 'baby',
    );
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: momCozyTheme(),
        home: Scaffold(
          body: ChatFirstBabyPage(
            controller: controller,
            onOpenDetails: () async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../goldens/chat_first/baby-overview-390.png'),
    );
    await tester.pumpWidget(const SizedBox());
  });
}
