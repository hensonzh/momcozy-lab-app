import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/baby/baby_profile.dart';
import 'package:momcozy_flutter_app/domain/baby/baby_record.dart';
import 'package:momcozy_flutter_app/domain/shared/local_date.dart';
import 'package:momcozy_flutter_app/domain/shared/product_failure.dart';
import 'package:momcozy_flutter_app/features/app_pages/chat_first_baby_details_page.dart';
import 'package:momcozy_flutter_app/modules/baby/application/baby_home_controller.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_growth_curve.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_profile_editor.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_record_editor.dart';

import '../../modules/baby/baby_test_repositories.dart';

void main() {
  BabyHomeController controller(
    BabyTestProfiles profiles,
    BabyTestRecords records, {
    String selectedBabyId = 'baby',
  }) => BabyHomeController(
    profileRepository: profiles,
    recordRepository: records,
    timezoneProvider: () async => 'UTC',
    now: () => babyTestNow,
    selectedBabyId: selectedBabyId,
  );

  Widget host(
    BabyHomeController c, {
    Future<void> Function(String)? onBabySelected,
    Future<void> Function(String)? onRecordSleep,
    ValueChanged<String>? onAsk,
  }) => MaterialApp(
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    supportedLocales: const [Locale('en', 'US'), Locale('zh', 'CN')],
    home: Scaffold(
      body: ChatFirstBabyDetailsPage(
        controller: c,
        onBabySelected: onBabySelected,
        onRecordSleep: onRecordSleep,
        onAsk: onAsk ?? (_) {},
      ),
    ),
  );

  testWidgets(
    'general baby knowledge is available without a baby and only prefills a question',
    (tester) async {
      final profiles = BabyTestProfiles()..values = [];
      final records = BabyTestRecords();
      final questions = <String>[];
      await tester.pumpWidget(
        host(controller(profiles, records), onAsk: questions.add),
      );
      await tester.pumpAndSettle();
      expect(find.text('当前账号还没有宝宝资料'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('baby-details-knowledge')),
        140,
      );
      await tester.tap(find.byKey(const ValueKey('baby-details-knowledge')));
      await tester.pumpAndSettle();
      expect(find.text('宝宝安全睡眠'), findsOneWidget);
      expect(find.text('认识饥饿与吃饱信号'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('baby-knowledge-topic-development')),
        110,
        scrollable: find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.text('观察宝宝发育'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('baby-knowledge-topic-sleep')),
        -110,
        scrollable: find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.textContaining('根据当前宝宝'), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey('baby-knowledge-topic-sleep')),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('仰卧'), findsWidgets);
      expect(find.textContaining('CDC ·'), findsOneWidget);
      expect(find.textContaining('不依据当前宝宝的记录评估健康'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('baby-knowledge-ask')));
      await tester.pumpAndSettle();
      expect(questions, ['关于宝宝安全睡眠，我想了解哪些基本注意事项？']);
      expect(records.submissions, isEmpty);
      expect(profiles.values, isEmpty);
      expect(find.text('照护知识'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'knowledge stays generic when current baby records cannot be read',
    (tester) async {
      final records = BabyTestRecords()
        ..loadFailure = const ProductFailure(ProductFailureKind.offline);
      await tester.pumpWidget(host(controller(BabyTestProfiles(), records)));
      await tester.pumpAndSettle();
      expect(find.text('今日记录暂时无法读取'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('baby-details-knowledge')),
        150,
      );
      await tester.tap(find.byKey(const ValueKey('baby-details-knowledge')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('baby-knowledge-topic-diaper')),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('AAP HealthyChildren'), findsOneWidget);
      expect(find.textContaining('不依据当前宝宝的记录评估健康'), findsOneWidget);
      expect(find.text('今日湿尿布 0 次'), findsNothing);
      await tester.tap(find.byTooltip('关闭照护知识'));
      await tester.pumpAndSettle();
      expect(find.text('今日记录暂时无法读取'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('large-text knowledge topics and source remain reachable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final profiles = BabyTestProfiles()..values = [];
    await tester.pumpWidget(host(controller(profiles, BabyTestRecords())));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('baby-details-knowledge')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final knowledgeScroll = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(Scrollable),
    );
    final development = find.byKey(
      const ValueKey('baby-knowledge-topic-development'),
    );
    await tester.scrollUntilVisible(
      development,
      250,
      scrollable: knowledgeScroll,
    );
    await tester.drag(knowledgeScroll, const Offset(0, -220));
    await tester.pumpAndSettle();
    expect(tester.getCenter(development).dy, lessThan(640));
    await tester.tap(development);
    await tester.pumpAndSettle();
    expect(find.text('来源：CDC · Developmental Milestones'), findsOneWidget);
    final source = find.text('查看原始来源');
    await tester.ensureVisible(source);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('关闭照护知识'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('empty account can create a real baby without legacy English', (
    tester,
  ) async {
    final profiles = BabyTestProfiles()..values = [];
    await tester.pumpWidget(host(controller(profiles, BabyTestRecords())));
    await tester.pumpAndSettle();
    expect(find.text('当前账号还没有宝宝资料'), findsOneWidget);
    expect(find.text('Add your baby to get started'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('baby-details-add-empty')));
    await tester.pumpAndSettle();
    expect(find.byType(BabyProfileEditor), findsOneWidget);
    expect(find.text('宝宝称呼'), findsOneWidget);
    final semanticHandle = tester.ensureSemantics();
    final nameField = tester.getSemantics(find.byType(TextField).first);
    expect(nameField.label, contains('宝宝称呼'));
    expect(nameField.label, isNot(contains('出生日期')));
    semanticHandle.dispose();
    await tester.enterText(find.byType(TextField).first, '安安');
    await tester.tap(find.text('选择出生日期'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('女孩'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<BabyProfileEditor>(find.byType(BabyProfileEditor))
          .controller
          .canSave,
      isTrue,
    );
    await tester.tap(find.text('保存宝宝资料'));
    await tester.pumpAndSettle();
    expect(find.text('安安'), findsOneWidget);
    expect(profiles.values.single.name, '安安');
    expect(profiles.values.single.id, 'new-baby');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'baby-specific feeding is written only after a valid Chinese form',
    (tester) async {
      final records = BabyTestRecords();
      await tester.pumpWidget(host(controller(BabyTestProfiles(), records)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('baby-details-feeding')));
      await tester.pumpAndSettle();
      expect(find.text('记录喂养'), findsOneWidget);
      expect(find.byTooltip('关闭记录表单'), findsOneWidget);
      final semantics = tester.ensureSemantics();
      expect(
        tester
            .widgetList<Semantics>(find.byType(Semantics))
            .any((widget) => widget.properties.label == '喂养方式, 必填'),
        isTrue,
      );
      semantics.dispose();
      await tester.tap(find.text('瓶喂'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('配方奶'));
      await tester.pumpAndSettle();
      expect(find.text('Milk type'), findsNothing);
      expect(find.text('Amount bottle-fed'), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('feeding-volume')),
        '75',
      );
      await tester.pumpAndSettle();
      final form = tester.widget<BabyRecordEditor>(
        find.byType(BabyRecordEditor),
      );
      expect(form.controller.feedingMethod, BabyFeedingMethod.formula);
      expect(form.controller.volume, '75');
      expect(
        form.controller.canSave,
        isTrue,
        reason: form.controller.validation,
      );
      await tester.tap(find.byKey(const ValueKey('baby-save')));
      await tester.pumpAndSettle();
      final saved = records.values.whereType<BabyFeedingRecord>().single;
      expect(saved.babyId, 'baby');
      expect(saved.method, BabyFeedingMethod.formula);
      expect(saved.volumeMl, 75);
      expect(find.text('今天喂养 1 次'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'saved owner records appear, daily total edits in place and baby switch isolates data',
    (tester) async {
      final profiles = BabyTestProfiles()
        ..values = [
          babyTestProfile,
          const BabyProfile(id: 'baby-2', name: '小可', sex: BabySex.male),
        ];
      final records = BabyTestRecords()
        ..values = [
          BabyFeedingRecord(
            id: 'feed',
            babyId: 'baby',
            occurredAt: babyTestNow.subtract(const Duration(hours: 1)),
            method: BabyFeedingMethod.formula,
            volumeMl: 60,
          ),
          BabyDailyStatusRecord(
            id: 'daily',
            babyId: 'baby',
            recordedOn: LocalDate(2026, 9, 8),
            timezone: 'UTC',
            savedAt: babyTestNow,
            wetCount: 2,
            stoolCount: 1,
          ),
          BabyGrowthRecord(
            id: 'growth',
            babyId: 'baby',
            recordedOn: LocalDate(2026, 9, 7),
            timezone: 'UTC',
            metric: GrowthMetric.weight,
            value: 3.8,
          ),
          BabyFeedingRecord(
            id: 'other',
            babyId: 'baby-2',
            occurredAt: babyTestNow.subtract(const Duration(hours: 2)),
            method: BabyFeedingMethod.formula,
            volumeMl: 150,
          ),
        ];
      final selected = <String>[];
      await tester.pumpWidget(
        host(
          controller(profiles, records),
          onBabySelected: (id) async => selected.add(id),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Luna'), findsOneWidget);
      expect(find.text('今天喂养 1 次'), findsOneWidget);
      expect(find.text('今日湿尿布 2 次'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('baby-details-wet')),
        160,
      );
      await tester.tap(find.byKey(const ValueKey('baby-details-wet')));
      await tester.pumpAndSettle();
      expect(find.byType(BabyRecordEditor), findsOneWidget);
      expect(find.text('记录湿尿布'), findsOneWidget);
      final wet = find.byKey(const ValueKey('wet-count'));
      expect(tester.widget<TextFormField>(wet).initialValue, '2');
      await tester.enterText(wet, '4');
      await tester.tap(find.byKey(const ValueKey('baby-save')));
      await tester.pumpAndSettle();
      final saved = records.values.whereType<BabyDailyStatusRecord>().single;
      expect(saved.id, 'daily');
      expect(saved.wetCount, 4);
      expect(saved.stoolCount, 1);
      expect(find.text('今日湿尿布 4 次'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('baby-details-growth-weight')),
        170,
      );
      expect(find.text('3.8 kg · 2026-09-07'), findsOneWidget);
      await tester.scrollUntilVisible(find.byType(BabyGrowthCurve), 170);
      expect(find.text('生长趋势'), findsOneWidget);
      expect(find.text('Growth trends'), findsNothing);
      await tester.drag(find.byType(ListView).first, const Offset(0, 1500));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('baby-details-switch')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('小可').last);
      await tester.pumpAndSettle();
      expect(find.text('小可'), findsOneWidget);
      expect(find.text('今天喂养 1 次'), findsOneWidget);
      expect(find.text('今日湿尿布 4 次'), findsNothing);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('baby-details-growth-weight')),
        170,
      );
      expect(find.text('3.8 kg · 2026-09-07'), findsNothing);
      expect(selected.last, 'baby-2');
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('saved baby records can be edited, deleted and restored', (
    tester,
  ) async {
    final records = BabyTestRecords()
      ..values = [
        BabyFeedingRecord(
          id: 'managed-feed',
          babyId: 'baby',
          version: 3,
          occurredAt: babyTestNow.subtract(const Duration(hours: 1)),
          method: BabyFeedingMethod.formula,
          volumeMl: 60,
        ),
      ];
    await tester.pumpWidget(host(controller(BabyTestProfiles(), records)));
    await tester.pumpAndSettle();

    final menu = find.byKey(const ValueKey('baby-record-menu-managed-feed'));
    await tester.scrollUntilVisible(menu, 180);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑').last);
    await tester.pumpAndSettle();
    expect(find.byType(BabyRecordEditor), findsOneWidget);
    expect(find.text('记录喂养'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('feeding-volume')), '75');
    await tester.tap(find.byKey(const ValueKey('baby-save')));
    await tester.pumpAndSettle();
    final edited = records.values.whereType<BabyFeedingRecord>().single;
    expect(edited.id, 'managed-feed');
    expect(edited.version, 4);
    expect(edited.volumeMl, 75);

    await tester.scrollUntilVisible(menu, 180);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('baby-record-delete-confirm')));
    await tester.pumpAndSettle();
    expect(records.deleteVersions, [4]);
    expect(
      records.values.where((record) => record.id == 'managed-feed'),
      isEmpty,
    );
    expect(find.text('记录已删除'), findsOneWidget);

    await tester.tap(find.text('恢复'));
    await tester.pumpAndSettle();
    expect(records.restoreVersions, [5]);
    final restored = records.values.whereType<BabyFeedingRecord>().singleWhere(
      (record) => record.id == 'managed-feed',
    );
    expect(restored.version, 6);
    expect(restored.volumeMl, 75);
    expect(find.text('记录已恢复'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('record management opens the correct growth and sleep editors', (
    tester,
  ) async {
    final records = BabyTestRecords()
      ..values = [
        BabyGrowthRecord(
          id: 'managed-growth',
          babyId: 'baby',
          recordedOn: LocalDate(2026, 9, 7),
          timezone: 'UTC',
          metric: GrowthMetric.weight,
          value: 3.8,
        ),
        BabySleepRecord(
          id: 'managed-sleep',
          babyId: 'baby',
          occurredAt: babyTestNow.subtract(const Duration(hours: 3)),
          endedAt: babyTestNow.subtract(const Duration(hours: 2)),
        ),
      ];
    await tester.pumpWidget(host(controller(BabyTestProfiles(), records)));
    await tester.pumpAndSettle();

    final growthMenu = find.byKey(
      const ValueKey('baby-record-menu-managed-growth'),
    );
    await tester.scrollUntilVisible(growthMenu, 180);
    await tester.ensureVisible(growthMenu);
    await tester.pumpAndSettle();
    await tester.tap(growthMenu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑').last);
    await tester.pumpAndSettle();
    expect(find.text('记录生长'), findsOneWidget);
    expect(find.byKey(const ValueKey('growth-weight')), findsOneWidget);
    await tester.tap(find.byTooltip('关闭记录表单'));
    await tester.pumpAndSettle();

    final sleepMenu = find.byKey(
      const ValueKey('baby-record-menu-managed-sleep'),
    );
    await tester.scrollUntilVisible(sleepMenu, 180);
    await tester.ensureVisible(sleepMenu);
    await tester.pumpAndSettle();
    await tester.tap(sleepMenu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑').last);
    await tester.pumpAndSettle();
    expect(find.text('记录睡眠'), findsOneWidget);
    expect(find.byType(BabyRecordEditor), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('record read failure is not reported as zero and can retry', (
    tester,
  ) async {
    final records = BabyTestRecords()
      ..loadFailure = const ProductFailure(ProductFailureKind.offline);
    await tester.pumpWidget(host(controller(BabyTestProfiles(), records)));
    await tester.pumpAndSettle();
    expect(find.text('今日记录暂时无法读取'), findsOneWidget);
    expect(find.text('今天喂养 0 次'), findsNothing);
    expect(find.text('今日湿尿布 0 次'), findsNothing);
    records.loadFailure = null;
    await tester.tap(find.byKey(const ValueKey('baby-details-record-retry')));
    await tester.pumpAndSettle();
    expect(find.text('今天喂养 0 次'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('sleep action receives only the selected real baby ID', (
    tester,
  ) async {
    final received = <String>[];
    final records = BabyTestRecords()
      ..values = [
        BabySleepRecord(
          id: 'sleep-1',
          babyId: 'baby',
          occurredAt: babyTestNow.subtract(const Duration(hours: 3)),
          endedAt: babyTestNow.subtract(const Duration(hours: 2)),
        ),
      ];
    await tester.pumpWidget(
      host(
        controller(BabyTestProfiles(), records),
        onRecordSleep: (id) async => received.add(id),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('baby-details-sleep')),
      150,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('baby-details-sleep')),
    );
    await tester.pumpAndSettle();
    expect(find.text('今天睡眠 1 次'), findsOneWidget);
    final semantics = tester.ensureSemantics();
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('baby-details-sleep')))
          .flagsCollection
          .isButton,
      isTrue,
    );
    semantics.dispose();
    await tester.tap(find.byKey(const ValueKey('baby-details-sleep')));
    await tester.pumpAndSettle();
    expect(received, ['baby']);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('compact large text keeps baby management actions reachable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      host(controller(BabyTestProfiles(), BabyTestRecords())),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final edit = find.byKey(const ValueKey('baby-details-edit'));
    await tester.scrollUntilVisible(edit, 150);
    expect(tester.takeException(), isNull);
    expect(tester.getSize(edit).height, greaterThanOrEqualTo(48));
    await tester.tap(edit);
    await tester.pumpAndSettle();
    expect(find.byType(BabyProfileEditor), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
