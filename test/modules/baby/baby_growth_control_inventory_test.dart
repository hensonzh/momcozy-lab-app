import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../support/fake_agent_voice.dart';
import '../../support/fixture_api_transport.dart';
import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/domain/baby/baby_record.dart';
import 'package:momcozy_flutter_app/shared/widgets/choice_field.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/native/p0_platform_interfaces.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_design_system.dart';
import '../../support/baby_inventory_transport.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_record_editor.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_overview_cards.dart';
import 'package:momcozy_flutter_app/modules/baby/application/baby_record_editor_controller.dart';
import '../../support/momcozy_test_fonts.dart';

MomCozyApiRuntime _runtime(
  BabyInventoryTransport t,
  MomCozySession s, {
  bool supportsPersistence = false,
}) => MomCozyApiRuntime(
  jsonTransport: t,
  multipartTransport: FixtureApiMultipartTransport({}),
  agentVoicePlaybackPlayer: ImmediateAgentVoicePlaybackPlayer(),
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
  late String variant;
  Future<void> mount(
    WidgetTester tester, {
    double width = 393,
    double scale = 1,
    bool empty = false,
    bool failRecords = false,
    bool loading = false,
  }) async {
    previous = null;
    FlutterSecureStorage.setMockInitialValues({});
    variant = '${width.toInt()}-${scale.toInt()}x';
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = Size(width, 844);
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
    final source =
        'test/goldens/ui_inventory/baby-growth-controls-$state-$variant.png';
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/ui_inventory/baby-growth-controls-$state-$variant.png',
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
      'test': 'test/modules/baby/baby_growth_control_inventory_test.dart',
    };
    previous = source;
    final output = Platform.environment['MOMCOZY_UI_INVENTORY_DIR'];
    if (output != null) {
      final file = File(
        '$output/journeys/baby-growth-controls-$state-$variant.json',
      );
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(row)}\n',
      );
    }
  }

  BabyRecordEditorController editor(WidgetTester tester) =>
      tester.widget<BabyRecordEditor>(find.byType(BabyRecordEditor)).controller;
  Future<void> input(WidgetTester tester, String key, String text) async {
    final field = find.byKey(ValueKey(key));
    await tester.ensureVisible(field);
    await tester.enterText(field, text);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
  }

  Future<void> saveInvalid(
    WidgetTester tester,
    String state,
    String validation,
  ) async {
    final before = transport.mutationPaths.length;
    await tap(tester, find.byKey(const ValueKey('baby-save')));
    expect(editor(tester).validation, validation);
    expect(find.text(validation), findsOneWidget);
    expect(transport.mutationPaths.length, before);
    await capture(tester, state, 'Tap save → $validation; no write request');
  }

  Future<void> dismissSavedNotice(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  for (final narrow in [false, true]) {
    testWidgets(
      'inventory Baby growth controls ${narrow ? '320/2x' : '393/1x'}',
      (tester) async {
        await mount(tester, width: narrow ? 320 : 393, scale: narrow ? 2 : 1);
        await capture(
          tester,
          'home-entry',
          'More → Baby before growth controls',
        );
        Finder metric(String label) => find.descendant(
          of: find.byType(BabyGrowthMetrics),
          matching: find.text(label),
        );
        for (final (label, id, value) in [
          ('身长', 'length', GrowthMetric.length),
          ('头围', 'head', GrowthMetric.headCircumference),
        ]) {
          await tap(tester, metric(label));
          expect(editor(tester).growthMetric, value);
          await capture(
            tester,
            '$id-entry',
            'Tap $label home card → matching measurement selected',
          );
          await tap(tester, find.byTooltip('关闭记录'));
          expect(find.text('继续填写'), findsNothing);
          await capture(
            tester,
            '$id-closed',
            'Close unchanged $label editor → home without confirmation',
          );
        }
        await tap(tester, metric('体重'));
        await capture(
          tester,
          'weight-entry',
          'Tap weight home card → weight selected',
        );
        await saveInvalid(tester, 'empty-rejected', '请至少填写一项测量数值。');
        const validation = '请检查测量数值和单位。体重为 kg，身长与头围为 cm。';
        for (final (id, value) in [
          ('malformed', 'oops'),
          ('zero', '0'),
          ('over', '50.1'),
        ]) {
          await input(tester, 'growth-weight', value);
          await capture(
            tester,
            'weight-$id',
            'Enter weight $value before save validation',
          );
          await saveInvalid(tester, 'weight-$id-rejected', validation);
        }
        await input(tester, 'growth-weight', '50');
        await tap(tester, find.text('身长').last);
        expect(find.text('体重 ✓'), findsOneWidget);
        await capture(
          tester,
          'length-empty',
          'Switch to length → completed weight indicator retained',
        );
        await input(tester, 'growth-length', '150.1');
        await tap(tester, find.text('头围').last);
        await capture(
          tester,
          'head-empty',
          'Switch to head circumference → hidden invalid length remains draft',
        );
        await tap(tester, find.byKey(const ValueKey('baby-save')));
        expect(editor(tester).growthMetric, GrowthMetric.length);
        expect(editor(tester).validation, validation);
        expect(transport.records, isEmpty);
        await capture(
          tester,
          'hidden-length-rejected',
          'Save from head tab → focus invalid length tab; no write',
        );
        await input(tester, 'growth-length', '150');
        await tap(tester, find.text('头围').last);
        await input(tester, 'growth-headCircumference', '150.1');
        await capture(
          tester,
          'head-over',
          'Enter head circumference above maximum',
        );
        await saveInvalid(tester, 'head-over-rejected', validation);
        await input(tester, 'growth-headCircumference', '150');
        await capture(
          tester,
          'three-maxima',
          'All three values at accepted client maxima; boundary fixture only',
        );
        final date = find.byType(DatePickerDialog);
        Future<void> openDate() async =>
            tap(tester, find.text(editor(tester).recordedOn.toString()));
        await openDate();
        final strings = MaterialLocalizations.of(tester.element(date));
        Finder buttons(String label) =>
            find.descendant(of: date, matching: find.text(label));
        await capture(
          tester,
          'date-open',
          'Open measurement date with birth-to-today range',
        );
        await tap(tester, buttons(strings.cancelButtonLabel));
        expect(editor(tester).recordedOn.toString(), '2026-09-13');
        await capture(
          tester,
          'date-cancelled',
          'Cancel date → today and three values retained',
        );
        Future<void> dateInput(String text) async {
          if (find
              .byTooltip(strings.inputDateModeButtonLabel)
              .evaluate()
              .isNotEmpty) {
            await tap(tester, find.byTooltip(strings.inputDateModeButtonLabel));
          }
          await tester.enterText(
            find.descendant(of: date, matching: find.byType(TextFormField)),
            text,
          );
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
          await tap(tester, buttons(strings.okButtonLabel));
        }

        await openDate();
        await dateInput(strings.formatCompactDate(DateTime(2026, 8, 21)));
        expect(date, findsOneWidget);
        await capture(
          tester,
          'date-before-birth',
          'Confirm date before birth → picker range error',
        );
        await dateInput(strings.formatCompactDate(DateTime(2026, 9, 14)));
        expect(date, findsOneWidget);
        await capture(
          tester,
          'date-future',
          'Confirm tomorrow → picker range error',
        );
        await dateInput(strings.formatCompactDate(DateTime(2026, 8, 22)));
        expect(date, findsNothing);
        expect(editor(tester).recordedOn.toString(), '2026-08-22');
        await capture(
          tester,
          'date-birth',
          'Confirm birth date → earliest date accepted in draft',
        );
        await openDate();
        await dateInput(strings.formatCompactDate(DateTime(2026, 9, 12)));
        await capture(
          tester,
          'date-previous-day',
          'Set yesterday for saved measurements',
        );
        await tap(tester, find.byKey(const ValueKey('baby-save')));
        expect(transport.records, hasLength(3));
        expect(
          transport.records.map((r) => (r['observation'] as Map)['value']),
          unorderedEquals([50.0, 150.0, 150.0]),
        );
        expect(
          transport.records.map(
            (r) => (r['observation'] as Map)['recorded_on'],
          ),
          everyElement('2026-09-12'),
        );
        await capture(
          tester,
          'maxima-saved',
          'Save atomic batch → three boundary fixture measurements shown on home',
        );
        await dismissSavedNotice(tester);
        await tap(tester, find.text('查看全部记录'));
        await tap(tester, find.text('生长'));
        const history = '/babies/inventory-baby/records';
        await capture(
          tester,
          'history',
          'Open growth history → three saved measurements',
          route: history,
        );
        await tap(tester, find.text('编辑').first);
        expect(editor(tester).growthMetric, GrowthMetric.weight);
        final choice = tester
            .widgetList<ChoiceField>(
              find.byWidgetPredicate((w) => w is ChoiceField),
            )
            .singleWhere((w) => w.title == '测量项目');
        expect(choice.options.keys, [GrowthMetric.weight]);
        expect(find.byKey(const ValueKey('growth-weight')), findsOneWidget);
        await capture(
          tester,
          'history-editor',
          'Edit saved weight → metric cannot change, original value restored',
          route: history,
        );
        await input(tester, 'growth-weight', '');
        await tap(tester, find.byKey(const ValueKey('baby-save')));
        expect(editor(tester).validation, '请至少填写一项测量数值。');
        expect(transport.records.first['version'], 1);
        await capture(
          tester,
          'history-empty-rejected',
          'Clear weight and save → required error; saved value unchanged',
          route: history,
        );
        await input(tester, 'growth-weight', ' 4.25 ');
        await capture(
          tester,
          'history-decimal',
          'Enter decimal weight with surrounding spaces',
          route: history,
        );
        await tap(tester, find.byKey(const ValueKey('baby-save')));
        expect(transport.records.first['version'], 2);
        expect((transport.records.first['observation'] as Map)['value'], 4.25);
        expect(transport.records, hasLength(3));
        await capture(
          tester,
          'history-saved',
          'Save edit → 4.25 kg, same record, two other measurements retained',
          route: history,
        );
        await dismissSavedNotice(tester);
        await tap(tester, find.text('编辑').first);
        expect(editor(tester).growthValues[GrowthMetric.weight], '4.25');
        await capture(
          tester,
          'history-reopened',
          'Reopen weight → trimmed parsed value persisted',
          route: history,
        );
        await tap(tester, find.byTooltip('关闭记录'));
        expect(find.text('继续填写'), findsNothing);
        await tap(tester, find.text('返回'));
        await capture(
          tester,
          'home-return',
          'Return Baby after history weight edit',
        );
        await tap(tester, find.text('More'));
        await capture(
          tester,
          'more-return',
          'Baby → More after growth control chain',
          route: '/more',
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }
}
