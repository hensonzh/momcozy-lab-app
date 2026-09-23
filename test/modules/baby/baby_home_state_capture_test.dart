import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/mom_bottom_navigation.dart';
import 'package:momcozy_flutter_app/domain/baby/baby_profile.dart';
import 'package:momcozy_flutter_app/domain/baby/baby_record.dart';
import 'package:momcozy_flutter_app/domain/shared/local_date.dart';
import 'package:momcozy_flutter_app/modules/baby/application/baby_home_controller.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_design.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_home_page.dart';
import 'package:momcozy_flutter_app/domain/shared/product_failure.dart';

import '../../support/momcozy_test_fonts.dart';
import 'baby_test_repositories.dart';

class _BlockedRecords extends BabyTestRecords {
  final gate = Completer<void>();

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
    await gate.future;
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

  @override
  Future<List<BabyGrowthRecord>> latestGrowth(String babyId) async {
    await gate.future;
    return super.latestGrowth(babyId);
  }
}

BabyProfile _profile({
  String name = 'Luna',
  BabySex sex = BabySex.female,
  bool missingBirthDate = false,
}) => BabyProfile(
  id: 'baby',
  name: name,
  birthDate: missingBirthDate ? null : LocalDate(2026, 8, 18),
  sex: sex,
  version: 1,
);

List<BabyRecord> _recordedValues({
  bool feeding = true,
  bool daily = true,
  bool growth = true,
}) => [
  if (feeding)
    BabyFeedingRecord(
      id: 'feeding',
      babyId: 'baby',
      occurredAt: DateTime.utc(2026, 9, 8, 9),
      method: BabyFeedingMethod.expressedMilk,
      volumeMl: 60,
    ),
  if (daily)
    BabyDailyStatusRecord(
      id: 'daily',
      babyId: 'baby',
      recordedOn: LocalDate(2026, 9, 8),
      timezone: 'Asia/Shanghai',
      savedAt: DateTime.utc(2026, 9, 8, 9),
      mentalState: BabyMentalState.content,
      wetCount: 1,
      stoolCount: 1,
    ),
  if (growth)
    for (final metric in GrowthMetric.values)
      BabyGrowthRecord(
        id: metric.name,
        babyId: 'baby',
        recordedOn: LocalDate(2026, 9, 8),
        timezone: 'Asia/Shanghai',
        metric: metric,
        value: metric == GrowthMetric.weight
            ? 4.2
            : metric == GrowthMetric.length
            ? 54
            : 36,
      ),
];

void main() {
  setUpAll(() async {
    await loadMomCozyTestFonts();
    await (FontLoader(
      'BabyNotoSans',
    )..addFont(rootBundle.load('assets/fonts/BabyNotoSans-VF.ttf'))).load();
  });

  Future<void> capture(
    WidgetTester tester, {
    required String name,
    required double width,
    required double height,
    required BabyHomeController controller,
    bool settle = true,
    double? scrollOffset,
    String? metric,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: BabyDesign.theme(ThemeData()),
        home: RepaintBoundary(
          key: key,
          child: Scaffold(
            body: BabyHomePage(controller: controller, onAsk: (_) {}),
            bottomNavigationBar: const MomCozyBottomNavigation(
              location: '/baby',
            ),
          ),
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 250)),
      );
      await tester.pump();
    } else {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }
    if (scrollOffset != null) {
      final scroll = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      scroll.position.jumpTo(
        scrollOffset.clamp(0, scroll.position.maxScrollExtent),
      );
      await tester.pumpAndSettle();
    }
    if (metric != null) {
      await tester.tap(find.text(metric).last);
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      final image =
          await (key.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 1);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final out = Directory('build/figma-comparison/home-states')
        ..createSync(recursive: true);
      File(
        '${out.path}/$name.png',
      ).writeAsBytesSync(data!.buffer.asUint8List());
      image.dispose();
    });
    await tester.pumpWidget(const SizedBox());
  }

  BabyHomeController controller({
    required BabyTestProfiles profiles,
    required BabyTestRecords records,
  }) => BabyHomeController(
    profileRepository: profiles,
    recordRepository: records,
    timezoneProvider: () async => 'Asia/Shanghai',
    deliveryDateProvider: () async => LocalDate(2026, 8, 18),
    now: () => DateTime.utc(2026, 9, 8, 10),
  );

  testWidgets('Figma Baby home state captures', (tester) async {
    // Warm navigation assets before the first capture. Image.asset futures can
    // otherwise finish after the first settled frame in the test environment.
    await tester.pumpWidget(
      MaterialApp(
        home: const Scaffold(
          bottomNavigationBar: MomCozyBottomNavigation(location: '/baby'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 300));

    await capture(
      tester,
      name: 'home-no-profile',
      width: 390,
      height: 844,
      controller: controller(
        profiles: BabyTestProfiles()..values = [],
        records: BabyTestRecords(),
      ),
    );
    await capture(
      tester,
      name: 'home-loading',
      width: 390,
      height: 1153,
      settle: false,
      controller: controller(
        profiles: BabyTestProfiles(),
        records: _BlockedRecords(),
      ),
    );
    await capture(
      tester,
      name: 'home-empty',
      width: 390,
      height: 1294,
      controller: controller(
        profiles: BabyTestProfiles(),
        records: BabyTestRecords(),
      ),
    );
    await capture(
      tester,
      name: 'home-missing-profile',
      width: 390,
      height: 1178,
      controller: controller(
        profiles: BabyTestProfiles()
          ..values = [
            _profile(sex: BabySex.unspecified, missingBirthDate: true),
          ],
        records: BabyTestRecords(),
      ),
    );
    await capture(
      tester,
      name: 'home-long-name',
      width: 390,
      height: 1294,
      controller: controller(
        profiles: BabyTestProfiles()
          ..values = [_profile(name: 'Luna Care Care Care Care CCC')],
        records: BabyTestRecords(),
      ),
    );
    await capture(
      tester,
      name: 'home-error',
      width: 390,
      height: 1398,
      controller: controller(
        profiles: BabyTestProfiles(),
        records: BabyTestRecords()
          ..loadFailure = const ProductFailure(ProductFailureKind.unavailable),
      ),
    );
    await capture(
      tester,
      name: 'home-recent-mental',
      width: 393,
      height: 844,
      controller: controller(
        profiles: BabyTestProfiles(),
        records: BabyTestRecords()..values = _recordedValues(growth: false),
      ),
    );
    await capture(
      tester,
      name: 'home-growth-saved',
      width: 393,
      height: 844,
      scrollOffset: 474,
      controller: controller(
        profiles: BabyTestProfiles(),
        records: BabyTestRecords()..values = _recordedValues(),
      ),
    );
    for (final entry in {
      'home-growth-weight': ('体重', 474.0),
      'home-growth-length': ('身长', 474.0),
      'home-growth-head': ('头围', 474.0),
    }.entries) {
      await capture(
        tester,
        name: entry.key,
        width: 393,
        height: 844,
        scrollOffset: entry.value.$2,
        metric: entry.value.$1,
        controller: controller(
          profiles: BabyTestProfiles(),
          records: BabyTestRecords()..values = _recordedValues(),
        ),
      );
    }

    // Re-capture after the other states have primed the shared navigation
    // artwork cache; this keeps the no-profile fixture equivalent to a real
    // device where the bottom-nav assets are already available.
    await capture(
      tester,
      name: 'home-no-profile',
      width: 390,
      height: 844,
      controller: controller(
        profiles: BabyTestProfiles()..values = [],
        records: BabyTestRecords(),
      ),
    );
  });
}
