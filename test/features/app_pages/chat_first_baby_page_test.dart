import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:momcozy_flutter_app/domain/baby/baby_profile.dart';
import 'package:momcozy_flutter_app/domain/baby/baby_record.dart';
import 'package:momcozy_flutter_app/domain/shared/local_date.dart';
import 'package:momcozy_flutter_app/domain/shared/product_failure.dart';
import 'package:momcozy_flutter_app/features/app_pages/chat_first_baby_page.dart';
import 'package:momcozy_flutter_app/modules/baby/application/baby_home_controller.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_profile_editor.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_growth_curve.dart';

import '../../modules/baby/baby_test_repositories.dart';

void main() {
  BabyHomeController controller(
    BabyTestProfiles profiles,
    BabyTestRecords records, {
    String selectedBabyId = '',
  }) => BabyHomeController(
    profileRepository: profiles,
    recordRepository: records,
    timezoneProvider: () async => 'UTC',
    now: () => babyTestNow,
    selectedBabyId: selectedBabyId,
  );

  Widget host(
    BabyHomeController c, {
    Future<void> Function()? onOpenDetails,
    Future<void> Function(String)? onBabySelected,
  }) => MaterialApp(
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    supportedLocales: const [Locale('en', 'US')],
    home: Scaffold(
      body: ChatFirstBabyPage(
        controller: c,
        onOpenDetails: onOpenDetails ?? () async {},
        onBabySelected: onBabySelected,
      ),
    ),
  );

  testWidgets('selected baby shows recorded today, seven days and growth', (
    tester,
  ) async {
    final records = BabyTestRecords()
      ..values = [
        BabyFeedingRecord(
          id: 'feeding-1',
          babyId: 'baby',
          occurredAt: babyTestNow.subtract(const Duration(hours: 1)),
          method: BabyFeedingMethod.formula,
          volumeMl: 90,
        ),
        BabyFeedingRecord(
          id: 'feeding-yesterday',
          babyId: 'baby',
          occurredAt: babyTestNow.subtract(const Duration(days: 1)),
          method: BabyFeedingMethod.formula,
          volumeMl: 80,
        ),
        BabySleepRecord(
          id: 'sleep-1',
          babyId: 'baby',
          occurredAt: babyTestNow.subtract(const Duration(hours: 3)),
          endedAt: babyTestNow.subtract(const Duration(hours: 2)),
        ),
        BabyGrowthRecord(
          id: 'weight-1',
          babyId: 'baby',
          recordedOn: LocalDate(2026, 9, 7),
          timezone: 'UTC',
          metric: GrowthMetric.weight,
          value: 3.8,
        ),
        BabyGrowthRecord(
          id: 'weight-2',
          babyId: 'baby',
          recordedOn: LocalDate(2026, 9, 1),
          timezone: 'UTC',
          metric: GrowthMetric.weight,
          value: 3.5,
        ),
      ];
    var opens = 0;
    await tester.pumpWidget(
      host(
        controller(BabyTestProfiles(), records, selectedBabyId: 'baby'),
        onOpenDetails: () async => opens++,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Luna'), findsOneWidget);
    expect(find.text('女孩 · 出生 21 天 · 出生日期 2026-08-18'), findsOneWidget);
    expect(find.text('今日照护'), findsOneWidget);
    expect(find.text('喂养记录'), findsOneWidget);
    expect(find.text('湿尿布记录'), findsOneWidget);
    expect(find.text('脏尿布记录'), findsOneWidget);
    expect(find.text('睡眠记录'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('baby-record-action')));
    await tester.pumpAndSettle();
    expect(opens, 1);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('baby-care-2026-09-07')),
      180,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('chat-first-baby-page')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    final yesterday = find.byKey(const ValueKey('baby-care-2026-09-07'));
    expect(
      find.descendant(of: yesterday, matching: find.text('1 次喂养')),
      findsOneWidget,
    );
    expect(find.text('未记录'), findsWidgets);
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, '尿布'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '尿布'));
    await tester.pumpAndSettle();
    final todayRow = find.byKey(const ValueKey('baby-care-2026-09-08'));
    expect(
      find.descendant(of: todayRow, matching: find.text('未记录')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('逐笔测量'),
      180,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('chat-first-baby-page')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('3.8 kg'), findsOneWidget);
    expect(find.text('3.5 kg'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('after six months uses latest measurement, not an old curve', (
    tester,
  ) async {
    final profiles = BabyTestProfiles()
      ..values = [
        BabyProfile(
          id: 'baby',
          name: 'Luna',
          birthDate: LocalDate(2026, 1, 1),
          sex: BabySex.female,
        ),
      ];
    final records = BabyTestRecords()
      ..values = [
        BabyGrowthRecord(
          id: 'recent',
          babyId: 'baby',
          recordedOn: LocalDate(2026, 9, 7),
          timezone: 'UTC',
          metric: GrowthMetric.weight,
          value: 8.2,
        ),
      ];
    await tester.pumpWidget(
      host(controller(profiles, records, selectedBabyId: 'baby')),
    );
    await tester.pumpAndSettle();
    final scrollable = find
        .descendant(
          of: find.byKey(const ValueKey('chat-first-baby-page')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('baby-growth-latest')),
      200,
      scrollable: scrollable,
    );
    expect(find.textContaining('8.2 kg'), findsOneWidget);
    expect(find.textContaining('前 6 个月'), findsOneWidget);
    expect(find.byType(BabyGrowthCurve), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('empty owner can create a baby with Chinese profile labels', (
    tester,
  ) async {
    final profiles = BabyTestProfiles()..values = [];
    final records = BabyTestRecords();
    await tester.pumpWidget(host(controller(profiles, records)));
    await tester.pumpAndSettle();
    expect(find.text('当前账号还没有宝宝资料'), findsOneWidget);
    expect(find.textContaining('小满'), findsNothing);
    await tester.tap(find.text('添加宝宝资料'));
    await tester.pumpAndSettle();
    expect(find.byType(BabyProfileEditor), findsOneWidget);
    expect(find.text('宝宝称呼'), findsOneWidget);
    expect(find.text('女孩'), findsOneWidget);
    expect(find.text('Save baby profile'), findsNothing);
    await tester.enterText(find.byType(TextField).first, '小安');
    await tester.tap(find.text('选择出生日期'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('确定').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('女孩'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存宝宝资料'));
    await tester.pumpAndSettle();
    expect(find.byType(BabyProfileEditor), findsNothing);
    expect(find.text('小安'), findsOneWidget);
    expect(profiles.values.single.name, '小安');
    expect(records.values, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('failed owner read is not presented as an empty baby account', (
    tester,
  ) async {
    final profiles = _FailingProfiles();
    await tester.pumpWidget(host(controller(profiles, BabyTestRecords())));
    await tester.pumpAndSettle();
    expect(find.text('暂时无法加载宝宝资料'), findsOneWidget);
    expect(find.text('当前账号还没有宝宝资料'), findsNothing);
    profiles.fail = false;
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(find.text('Luna'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'switching real baby profiles keeps the selected owner record scope',
    (tester) async {
      final profiles = BabyTestProfiles()
        ..values = [
          babyTestProfile,
          const BabyProfile(id: 'baby-2', name: '小可', sex: BabySex.male),
        ];
      final selected = <String>[];
      await tester.pumpWidget(
        host(
          controller(profiles, BabyTestRecords(), selectedBabyId: 'baby'),
          onBabySelected: (id) async => selected.add(id),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('baby-switch')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('小可').last);
      await tester.pumpAndSettle();
      expect(find.text('小可'), findsOneWidget);
      expect(find.text('男孩 · 未填写出生日期'), findsOneWidget);
      expect(selected.last, 'baby-2');
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'compact large-text baby overview keeps both detail actions reachable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final profiles = BabyTestProfiles()
        ..values = [
          const BabyProfile(
            id: 'baby',
            name: '一个非常长但确实由当前账号保存的宝宝名字',
            sex: BabySex.female,
          ),
        ];
      var opens = 0;
      await tester.pumpWidget(
        host(
          controller(profiles, BabyTestRecords(), selectedBabyId: 'baby'),
          onOpenDetails: () async => opens++,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final details = find.byKey(const ValueKey('baby-full-details'));
      final edit = find.widgetWithText(TextButton, '编辑宝宝资料');
      await tester.scrollUntilVisible(
        details,
        180,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('chat-first-baby-page')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(edit, findsOneWidget);
      expect(find.text('查看完整记录与管理'), findsOneWidget);
      expect(tester.getSize(edit).height, greaterThanOrEqualTo(48));
      expect(tester.getSize(details).height, greaterThanOrEqualTo(48));
      await tester.tap(details);
      await tester.pumpAndSettle();
      expect(opens, 1);
      await tester.tap(edit);
      await tester.pumpAndSettle();
      expect(find.byType(BabyProfileEditor), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

class _FailingProfiles extends BabyTestProfiles {
  bool fail = true;

  @override
  Future<List<BabyProfile>> list() async {
    if (fail) throw const ProductFailure(ProductFailureKind.offline);
    return super.list();
  }
}
