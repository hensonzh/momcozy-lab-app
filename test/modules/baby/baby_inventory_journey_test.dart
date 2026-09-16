import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/native/p0_platform_interfaces.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_overview_cards.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_design_system.dart';
import '../../support/baby_inventory_transport.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_record_editor.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_growth_curve.dart';
import 'package:momcozy_flutter_app/shared/widgets/knowledge_banner.dart';
import '../../support/momcozy_test_fonts.dart';

MomCozyApiRuntime _runtime(
  BabyInventoryTransport t,
  MomCozySession s, {
  bool supportsPersistence = false,
}) => MomCozyApiRuntime(
  jsonTransport: t,
  supportsSessionAutoRefresh: supportsPersistence,
  session: s,
  now: () => t.clock,
  timezoneProvider: () async => 'Asia/Shanghai',
);

class _Controller extends MomCozyRuntimeController {
  _Controller(this.transport, MomCozySession s)
    : super(_runtime(transport, s, supportsPersistence: true));
  final BabyInventoryTransport transport;
  @override
  void replaceRuntime(MomCozyApiRuntime value) =>
      super.replaceRuntime(_runtime(transport, value.session));
}

void main() {
  setUpAll(loadMomCozyTestFonts);
  late BabyInventoryTransport transport;
  late _Controller runtime;
  late GoRouter router;
  String? previous;
  Future<void> mount(
    WidgetTester tester, {
    bool empty = false,
    bool failRecords = false,
    bool loading = false,
  }) async {
    previous = null;
    tester.view.physicalSize = const Size(393, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    transport = BabyInventoryTransport();
    if (empty) transport.profiles.clear();
    transport.failRead = failRecords;
    if (loading) transport.readGate = Completer<void>();
    const session = MomCozySession(
      status: MomCozySessionStatus.authenticated,
      userId: 'inventory-user',
      babyId: 'inventory-baby',
      locale: 'zh-CN',
      accessToken: 'fixture-access',
      refreshToken: 'fixture-refresh',
    );
    runtime = _Controller(transport, session);
    final store = MemoryMomCozySessionStore(session);
    runtime.enableSessionAutoRefresh(store);
    final platform = FakeRouteIntentPlatform();
    router = createMomCozyRouter(
      initialLocation: '/more',
      runtimeController: runtime,
      sessionStore: store,
    );
    await tester.pumpWidget(
      MomCozyFlutterApp(
        router: router,
        runtimeController: runtime,
        sessionStore: store,
        routeIntentPlatform: platform,
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      // Long capture visits lazy children. Decode both local images before
      // comparing any viewport so later dialogs see the same loaded page.
      for (final asset in [
        MomCozyAssets.agentAvatar,
        'assets/images/me_baby_overview/nursery_camera_clean.png',
      ]) {
        await precacheImage(
          AssetImage(asset),
          tester.element(find.byType(MaterialApp)),
        );
      }
    });
    await tester.tap(find.text('Baby'));
    if (loading) {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    } else {
      await tester.pumpAndSettle();
    }
    expect(router.state.uri.path, '/baby');
    if (!empty) expect(find.text('Luna'), findsOneWidget);
    addTearDown(() async {
      if (transport.readGate case final gate? when !gate.isCompleted) {
        gate.complete();
      }
      if (transport.writeGate case final gate? when !gate.isCompleted) {
        gate.complete();
      }
      router.dispose();
      runtime.dispose();
      await platform.dispose();
    });
  }

  Future<void> tap(WidgetTester tester, Finder target) async {
    if (target.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        target,
        300,
        scrollable: find.byType(Scrollable).first,
      );
    } else {
      await tester.ensureVisible(target);
    }
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  Future<void> capture(
    WidgetTester tester,
    String state,
    String action, {
    String route = '/baby',
  }) async {
    // Commit edits and finish the input hint's fade without settling spinners.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(router.state.uri.path, route);
    expect(tester.takeException(), isNull);
    final source = 'test/goldens/ui_inventory/baby-journey-$state-393.png';
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/ui_inventory/baby-journey-$state-393.png',
      ),
    );
    final row = {
      'source': source,
      'previous_source': previous,
      'route': route,
      'trigger': action,
      'root_entry': 'Authenticated More → tap Baby bottom navigation',
      'evidence':
          'Actual MomCozyFlutterApp/createMomCozyRouter, production repositories and codecs, isolated in-memory HTTP data, fixed clock and timezone',
      'test': 'test/modules/baby/baby_inventory_journey_test.dart',
    };
    previous = source;
    final output = Platform.environment['MOMCOZY_UI_INVENTORY_DIR'];
    if (output != null) {
      final file = File('$output/journeys/baby-journey-$state.json');
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(row)}\n',
      );
    }
  }

  testWidgets(
    'inventory Baby feeding save edit delete restore and history filters',
    (tester) async {
      await mount(tester);
      await capture(
        tester,
        'empty-home',
        'More → Baby, owned profiles without records',
      );
      await tap(tester, find.byType(BabyFeedingSummary));
      await capture(
        tester,
        'feeding-empty',
        'Tap today feeding card → feeding editor',
      );
      await tap(tester, find.byKey(const ValueKey('baby-save')));
      await capture(
        tester,
        'feeding-validation',
        'Submit without feeding method → validation',
      );
      await tap(tester, find.text('瓶喂母乳'));
      await tester.enterText(
        find.byKey(const ValueKey('feeding-volume')),
        '80',
      );
      await capture(
        tester,
        'feeding-filled',
        'Select expressed milk and enter 80 ml',
      );
      transport.failWrite = true;
      await tap(tester, find.byKey(const ValueKey('baby-save')));
      await capture(
        tester,
        'feeding-save-error',
        'Save → HTTP 503 from isolated transport',
      );
      transport.failWrite = false;
      await tap(tester, find.byKey(const ValueKey('baby-save')));
      expect(transport.records, hasLength(1));
      await capture(
        tester,
        'feeding-saved',
        'Retry succeeds → home refresh and saved feedback',
      );
      await tap(tester, find.text('查看全部记录'));
      const history = '/babies/inventory-baby/records';
      await capture(
        tester,
        'history-feeding',
        'Saved home → View all records',
        route: history,
      );
      await tap(tester, find.text('编辑'));
      await capture(
        tester,
        'history-edit',
        'History → Edit saved feeding',
        route: history,
      );
      await tester.enterText(
        find.byKey(const ValueKey('feeding-volume')),
        '100',
      );
      await tap(tester, find.byKey(const ValueKey('baby-save')));
      expect(
        (transport.records.single['observation'] as Map)['volume_ml'],
        100,
      );
      await capture(
        tester,
        'history-edited',
        'Save edited volume → list and saved Snackbar',
        route: history,
      );
      await tap(tester, find.text('删除'));
      await capture(
        tester,
        'delete-confirm',
        'Record Delete → confirmation',
        route: history,
      );
      await tap(tester, find.text('保留'));
      await capture(
        tester,
        'delete-cancelled',
        'Keep record → same history record',
        route: history,
      );
      await tap(tester, find.text('删除'));
      await tap(tester, find.widgetWithText(FilledButton, '删除'));
      expect(transport.records, isEmpty);
      await capture(
        tester,
        'history-deleted',
        'Confirm deletion → empty list with undo',
        route: history,
      );
      await tap(tester, find.text('撤销删除'));
      expect(transport.records, hasLength(1));
      await capture(
        tester,
        'history-restored',
        'Undo deletion → restored record',
        route: history,
      );
      for (final kind in {
        '睡眠': 'sleep',
        '尿便': 'diaper',
        '生长': 'growth',
        '发育观察': 'development',
      }.entries) {
        await tap(tester, find.widgetWithText(TextButton, kind.key));
        await capture(
          tester,
          'history-${kind.value}-empty',
          'Tap ${kind.key} filter → empty category',
          route: history,
        );
      }
      await tap(tester, find.byTooltip('上个月'));
      await capture(
        tester,
        'history-previous-month',
        'Previous month → August',
        route: history,
      );
      await tap(tester, find.text('2026年8月'));
      await capture(
        tester,
        'history-month-picker',
        'Tap month → date picker',
        route: history,
      );
      await tap(tester, find.text('取消'));
      await tap(tester, find.byTooltip('下个月'));
      await tap(tester, find.text('数据来源'));
      await capture(
        tester,
        'history-source-expanded',
        'Expand data source and privacy explanation',
        route: history,
      );
      await tap(tester, find.text('返回'));
      await capture(
        tester,
        'returned-home',
        'History Back → Baby with refreshed 100 ml record',
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('inventory Baby profile switch editing and discard', (
    tester,
  ) async {
    await mount(tester);
    await tap(tester, find.text('Luna'));
    await capture(tester, 'switcher', 'Tap baby name → two-profile switcher');
    await tap(tester, find.text('Leo'));
    expect(runtime.currentSession.babyId, 'inventory-baby-2');
    await capture(
      tester,
      'switched-leo',
      'Choose Leo → second profile and independently empty records',
    );
    await tap(tester, find.text('Leo'));
    await tap(tester, find.text('编辑当前宝宝资料'));
    await capture(
      tester,
      'profile-existing',
      'Switcher → edit current profile',
    );
    await tester.enterText(find.byType(TextField).first, 'Leo edited');
    await tap(tester, find.byTooltip('关闭宝宝资料'));
    await capture(
      tester,
      'profile-discard-confirm',
      'Edit name then close → discard confirmation',
    );
    await tap(tester, find.text('继续填写'));
    await capture(
      tester,
      'profile-draft-preserved',
      'Continue editing → draft name preserved',
    );
    await tap(tester, find.text('保存宝宝资料'));
    expect(transport.profiles[1]['name'], 'Leo edited');
    await capture(
      tester,
      'profile-saved',
      'Save profile → updated home identity',
    );
    await tap(tester, find.text('Leo edited'));
    await tap(tester, find.text('添加宝宝'));
    await capture(tester, 'profile-new', 'Switcher → add baby');
    await tap(tester, find.text('保存宝宝资料'));
    await capture(
      tester,
      'profile-new-validation',
      'Save without baby name → required validation',
    );
    await tap(tester, find.byTooltip('关闭宝宝资料'));
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('inventory Baby sleep stool knowledge and growth interactions', (
    tester,
  ) async {
    await mount(tester);
    await tap(tester, find.byType(KnowledgeBanner));
    await capture(
      tester,
      'knowledge-detail',
      'Tap knowledge card → full educational article',
    );
    await tap(tester, find.text('关闭'));
    await tap(tester, find.byType(BabyStatusCard).first);
    await capture(
      tester,
      'sleep-start-editor',
      'Tap sleep summary → new active sleep editor',
    );
    await tap(tester, find.text('尿湿').last);
    await capture(tester, 'wet-tab', 'Within status editor → wet diaper tab');
    await tap(tester, find.text('便便').last);
    await capture(tester, 'stool-tab', 'Within status editor → stool tab');
    await tap(tester, find.text('红色'));
    await capture(
      tester,
      'stool-red',
      'Choose red stool color → recorded color and guidance',
    );
    await tap(tester, find.text('看到血丝 / 血迹'));
    await capture(tester, 'stool-blood', 'Select observed blood sign');
    await tap(tester, find.byTooltip('关闭记录'));
    await capture(
      tester,
      'record-discard',
      'Close dirty record → discard confirmation',
    );
    await tap(tester, find.text('离开'));
    expect(transport.records, isEmpty);
    await capture(
      tester,
      'record-discarded',
      'Confirm leave → no saved records',
    );
    await tap(tester, find.byType(BabyStatusCard).first);
    await tap(tester, find.byKey(const ValueKey('baby-save')));
    expect(transport.records, hasLength(1));
    await capture(
      tester,
      'sleep-started',
      'Start sleep → active sleep stored and home feedback',
    );
    await tap(tester, find.text('撤销'));
    expect(transport.records, isEmpty);
    await capture(
      tester,
      'home-save-undone',
      'Undo from save feedback → record removed',
    );
    await tester.scrollUntilVisible(
      find.text('Luna'),
      -400,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 30,
    );
    await tap(tester, find.byType(BabyStatusCard).first);
    await tap(tester, find.byKey(const ValueKey('baby-save')));
    transport.clock = transport.clock.add(const Duration(minutes: 45));
    await tester.scrollUntilVisible(
      find.text('Luna'),
      -400,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 30,
    );
    await tap(tester, find.byType(BabyStatusCard).first);
    await capture(
      tester,
      'sleep-active-editor',
      'Tap active sleep → record wake time action',
    );
    await tap(tester, find.text('调整时间和备注'));
    await capture(
      tester,
      'sleep-adjust',
      'Expand active sleep time and note controls',
    );
    await tap(tester, find.text('补充备注'));
    await tester.enterText(find.byKey(const ValueKey('note-sleep')), '醒来后安静');
    await capture(tester, 'sleep-note', 'Expand note and enter observation');
    await tap(tester, find.byKey(const ValueKey('baby-save')));
    expect(
      (transport.records.single['observation'] as Map)['ended_at'],
      isNotNull,
    );
    await capture(
      tester,
      'sleep-ended',
      'Save wake time → completed sleep and home refresh',
    );
    await tester.scrollUntilVisible(
      find.byType(BabyGrowthCurve),
      -300,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 30,
    );
    for (final metric in {
      '体重': 'weight',
      '身长': 'length',
      '头围': 'head',
    }.entries) {
      await tap(
        tester,
        find.descendant(
          of: find.byType(BabyGrowthCurve),
          matching: find.widgetWithText(TextButton, metric.key),
        ),
      );
      await capture(
        tester,
        'growth-curve-${metric.value}',
        'Switch growth curve to ${metric.key}',
      );
    }
    await tap(tester, find.text('记录发育观察'));
    await capture(
      tester,
      'development-editor',
      'Tap record developmental observation',
    );
    await tap(tester, find.text('不确定').first);
    await capture(
      tester,
      'development-unsure',
      'Select unsure observation status',
    );
    await tap(tester, find.byKey(const ValueKey('baby-save')));
    expect(transport.records, hasLength(2));
    expect(find.byType(BabyRecordEditor), findsNothing);
    await capture(
      tester,
      'development-saved',
      'Save observation → home with completion feedback',
    );
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'inventory Baby no profile creation and missing demographic data',
    (tester) async {
      await mount(tester, empty: true);
      await capture(tester, 'no-profile', 'More → Baby with no owned profile');
      await tap(tester, find.text('添加宝宝'));
      await capture(
        tester,
        'first-profile-form',
        'Empty page CTA → first baby form',
      );
      await tester.enterText(find.byType(TextField).first, 'Nova');
      await tap(tester, find.text('保存宝宝资料'));
      expect(transport.profiles.single['name'], 'Nova');
      await capture(
        tester,
        'first-profile-created',
        'Save minimum profile → new baby home with missing birth date and sex',
      );
      await tap(tester, find.text('完善资料'));
      await capture(
        tester,
        'growth-profile-entry',
        'Growth reference missing data → complete profile',
      );
      await tap(tester, find.text('暂未确定'));
      await capture(
        tester,
        'feeding-mode-menu',
        'Profile feeding mode → dropdown options',
      );
      await tap(tester, find.text('混合喂养').last);
      await capture(tester, 'feeding-mode-selected', 'Select mixed feeding');
      await tap(tester, find.byTooltip('关闭宝宝资料'));
      await tap(tester, find.text('离开'));
      expect(transport.profiles.single['feeding_mode'], 'unknown');
      await capture(
        tester,
        'profile-change-discarded',
        'Discard feeding-mode change → saved profile remains unchanged',
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('inventory Baby local record failure and pull refresh recovery', (
    tester,
  ) async {
    await mount(tester, failRecords: true);
    await capture(
      tester,
      'record-read-error',
      'More → Baby; record API fails, profile remains usable',
    );
    transport.failRead = false;
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 400));
    await tester.pumpAndSettle();
    await capture(
      tester,
      'record-read-recovered',
      'Pull to refresh → independently loaded empty records',
    );
    expect(
      transport.getPaths.where((p) => p.contains('/records')).length,
      greaterThan(3),
    );
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('inventory Baby loading and pending save states', (tester) async {
    await mount(tester, loading: true);
    expect(find.text('载入中…'), findsWidgets);
    await capture(
      tester,
      'records-loading',
      'Baby entered; profile ready while records requests are pending',
    );
    transport.readGate!.complete();
    await tester.pumpAndSettle();
    await capture(
      tester,
      'records-loaded',
      'Pending records resolve → empty cards and growth curve',
    );
    await tap(tester, find.byType(BabyFeedingSummary));
    await tap(tester, find.text('亲喂'));
    await tap(tester, find.text('左侧'));
    await capture(
      tester,
      'feeding-nursing-left',
      'Select nursing method and left side',
    );
    transport.writeGate = Completer<void>();
    await tester.tap(find.byKey(const ValueKey('baby-save')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('正在保存…'), findsOneWidget);
    await capture(
      tester,
      'record-saving',
      'Submit feeding while response pending → disabled save controls',
    );
    transport.writeGate!.complete();
    await tester.pumpAndSettle();
    expect(transport.records, hasLength(1));
    await capture(
      tester,
      'nursing-saved',
      'Server acknowledges nursing → home and saved feedback',
    );
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('inventory Baby growth batch date validation and undo recovery', (
    tester,
  ) async {
    await mount(tester);
    await tap(
      tester,
      find.descendant(
        of: find.byType(BabyGrowthMetrics),
        matching: find.text('体重'),
      ),
    );
    await capture(
      tester,
      'growth-empty',
      'Baby growth weight card → measurement editor',
    );
    await tap(tester, find.byKey(const ValueKey('baby-save')));
    expect(find.text('请至少填写一项测量数值。'), findsOneWidget);
    await capture(
      tester,
      'growth-empty-validation',
      'Save without measurements → required validation',
    );
    await tester.enterText(find.byKey(const ValueKey('growth-weight')), '0');
    await tap(tester, find.byKey(const ValueKey('baby-save')));
    await capture(
      tester,
      'growth-invalid-value',
      'Save zero weight → measurement range validation',
    );
    expect(transport.records, isEmpty);
    await tester.enterText(find.byKey(const ValueKey('growth-weight')), '4.2');
    await tap(tester, find.text('身长').last);
    await tester.enterText(find.byKey(const ValueKey('growth-length')), '54');
    await tap(tester, find.text('头围').last);
    await tester.enterText(
      find.byKey(const ValueKey('growth-headCircumference')),
      '36',
    );
    await capture(
      tester,
      'growth-three-values',
      'Fill weight, length and head circumference across measurement tabs',
    );
    await tap(tester, find.text('2026-09-13'));
    expect(
      tester
          .widget<DatePickerDialog>(find.byType(DatePickerDialog))
          .currentDate,
      DateUtils.dateOnly(transport.clock),
    );
    final strings = MaterialLocalizations.of(
      tester.element(find.byType(DatePickerDialog)),
    );
    await capture(
      tester,
      'growth-date-calendar',
      'Measurement date → calendar picker',
    );
    await tap(tester, find.byTooltip(strings.inputDateModeButtonLabel));
    await capture(
      tester,
      'growth-date-input',
      'Switch date picker to text input',
    );
    await tester.enterText(
      find.descendant(
        of: find.byType(DatePickerDialog),
        matching: find.byType(TextFormField),
      ),
      'invalid',
    );
    await tap(tester, find.text(strings.okButtonLabel));
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await capture(
      tester,
      'growth-date-invalid',
      'Confirm invalid date text → picker validation',
    );
    await tester.enterText(
      find.descendant(
        of: find.byType(DatePickerDialog),
        matching: find.byType(TextFormField),
      ),
      strings.formatCompactDate(DateTime(2026, 9, 12)),
    );
    await tap(tester, find.text(strings.okButtonLabel));
    await capture(
      tester,
      'growth-date-selected',
      'Choose previous measurement date → editor preserves all three values',
    );
    await tap(tester, find.byKey(const ValueKey('baby-save')));
    expect(transport.records, hasLength(3));
    expect(find.byType(BabyRecordEditor), findsNothing);
    expect(
      transport.records.map((r) => (r['observation'] as Map)['recorded_on']),
      everyElement('2026-09-12'),
    );
    await capture(
      tester,
      'growth-batch-saved',
      'Save → atomic measurement batch and home latest metrics',
    );
    transport.failWrite = true;
    await tap(tester, find.text('撤销'));
    expect(transport.records, hasLength(3));
    await capture(
      tester,
      'growth-undo-error',
      'Undo batch → API failure retains saved measurements and retry',
    );
    transport.failWrite = false;
    await tap(tester, find.text('重试确认撤销'));
    expect(transport.records, isEmpty);
    await capture(
      tester,
      'growth-batch-undone',
      'Retry undo → all three batch measurements removed',
    );
    await tap(tester, find.byTooltip('关闭保存提示'));
    await capture(
      tester,
      'growth-feedback-dismissed',
      'Dismiss undo feedback → empty latest measurements',
    );
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('inventory Baby history mutation failures privacy and return', (
    tester,
  ) async {
    await mount(tester);
    transport.create('inventory-baby', {
      'kind': 'feeding',
      'method': 'formula',
      'volume_ml': 90,
      'occurred_at': inventoryBabyNow.toIso8601String(),
      'note': '',
    });
    await tap(tester, find.text('查看全部记录'));
    const history = '/babies/inventory-baby/records';
    await capture(
      tester,
      'history-formula',
      'Baby → all records with existing formula record',
      route: history,
    );
    transport.failWrite = true;
    await tap(tester, find.text('删除'));
    await tap(tester, find.widgetWithText(FilledButton, '删除'));
    expect(transport.records, hasLength(1));
    await capture(
      tester,
      'history-delete-error',
      'Confirm deletion → service unavailable, record remains',
      route: history,
    );
    transport.failWrite = false;
    await tap(tester, find.text('重试'));
    expect(transport.records, isEmpty);
    await capture(
      tester,
      'history-delete-retry',
      'Retry unconfirmed deletion → deleted record and undo',
      route: history,
    );
    transport.failWrite = true;
    await tap(tester, find.text('撤销删除'));
    expect(transport.records, isEmpty);
    await capture(
      tester,
      'history-restore-error',
      'Undo deletion → service unavailable, restore retry state',
      route: history,
    );
    transport.failWrite = false;
    await tap(tester, find.text('重试'));
    expect(transport.records, hasLength(1));
    await capture(
      tester,
      'history-restore-retry',
      'Retry restore → original formula record returns',
      route: history,
    );
    await tap(tester, find.text('数据来源'));
    transport.responsesByPath.addAll({
      '/v1/care/catalog': {
        'packages': [],
        'providers': [],
        'available_regions': [],
        'payment_mode': 'disabled',
      },
      '/v1/care/overview': {'orders': [], 'episodes': []},
    });
    await tap(tester, find.text('隐私与授权'));
    await capture(
      tester,
      'history-privacy',
      'Record data source → Privacy and authorization with no service',
      route: '/privacy',
    );
    await tap(tester, find.text('返回'));
    await capture(
      tester,
      'privacy-return-history',
      'Privacy Back → same baby record history',
      route: history,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('inventory Baby history pagination loading failure recovery', (
    tester,
  ) async {
    await mount(tester);
    for (var i = 0; i < 51; i++) {
      transport.create('inventory-baby', {
        'kind': 'feeding',
        'method': 'expressed_milk',
        'volume_ml': 50 + i,
        'occurred_at': inventoryBabyNow
            .subtract(Duration(hours: i * 3))
            .toIso8601String(),
        'note': '记录 ${i + 1}',
      });
    }
    await tap(tester, find.text('查看全部记录'));
    const history = '/babies/inventory-baby/records';
    await capture(
      tester,
      'history-first-page',
      'Baby → monthly feeding history with 51 records, first 50 loaded',
      route: history,
    );
    transport.failRead = true;
    await tap(tester, find.text('加载更多'));
    await capture(
      tester,
      'history-more-error',
      'Load more → page failure keeps first page visible',
      route: history,
    );
    transport.failRead = false;
    transport.readGate = Completer<void>();
    await tester.tap(find.text('加载更多'));
    await tester.pump(const Duration(milliseconds: 100));
    await capture(
      tester,
      'history-more-loading',
      'Retry page load while response pending',
      route: history,
    );
    transport.readGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('加载更多'), findsNothing);
    expect(find.text('备注：记录 51'), findsOneWidget);
    await tester.ensureVisible(find.text('备注：记录 51'));
    await tester.pumpAndSettle();
    await capture(
      tester,
      'history-all-pages',
      'Second page resolves → all 51 records and no load more button',
      route: history,
    );
    await tester.pumpWidget(const SizedBox());
  });
}
