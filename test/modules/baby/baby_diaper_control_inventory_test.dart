import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../support/fake_agent_voice.dart';
import '../../support/fixture_api_transport.dart';
import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/domain/baby/baby_record.dart';
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
import 'package:momcozy_flutter_app/shared/widgets/choice_field.dart';

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
        'test/goldens/ui_inventory/baby-diaper-controls-$state-$variant.png';
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/ui_inventory/baby-diaper-controls-$state-$variant.png',
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
      'test': 'test/modules/baby/baby_diaper_control_inventory_test.dart',
    };
    previous = source;
    final output = Platform.environment['MOMCOZY_UI_INVENTORY_DIR'];
    if (output != null) {
      final file = File(
        '$output/journeys/baby-diaper-controls-$state-$variant.json',
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
      'inventory Baby diaper controls ${narrow ? '320/2x' : '393/1x'}',
      (tester) async {
        await mount(tester, width: narrow ? 320 : 393, scale: narrow ? 2 : 1);
        await capture(
          tester,
          'home-entry',
          'More → Baby before diaper controls',
        );
        await tap(
          tester,
          find.byWidgetPredicate(
            (widget) => widget is BabyStatusCard && widget.label == '尿湿',
          ),
        );
        expect(editor(tester).kind, BabyRecordKind.diaper);
        expect(editor(tester).diaperKind, DiaperKind.wet);
        await capture(
          tester,
          'wet-open',
          'Tap wet status card → wet diaper selected',
        );
        Finder choice<T extends Enum>(String label) => find.descendant(
          of: find.byType(ChoiceField<T>),
          matching: find.text(label),
        );
        await tap(tester, choice<DiaperKind>('尿湿'));
        expect(editor(tester).diaperKind, isNull);
        await saveInvalid(tester, 'kind-required', '先选择这次换到的尿布。');
        await tap(tester, choice<DiaperKind>('便便'));
        await capture(
          tester,
          'dirty-selected',
          'Choose dirty diaper → optional stool controls appear',
        );
        for (final (label, value) in [
          ('黄色', StoolColor.yellow),
          ('黄褐色', StoolColor.yellowBrown),
          ('绿色', StoolColor.green),
          ('棕色', StoolColor.brown),
          ('黑色', StoolColor.black),
          ('红色', StoolColor.red),
          ('灰白 / 很浅', StoolColor.pale),
          ('不确定', StoolColor.unsure),
        ]) {
          await tap(tester, choice<StoolColor>(label));
          expect(editor(tester).stoolColor, value);
          await capture(
            tester,
            'color-${value.name}',
            'Select stool color $label',
          );
        }
        await tap(tester, choice<StoolColor>('不确定'));
        expect(editor(tester).stoolColor, isNull);
        await capture(
          tester,
          'color-cleared',
          'Tap selected unsure color → optional color cleared',
        );
        await tap(tester, choice<StoolColor>('黄色'));
        for (final (label, value) in [
          ('水样', StoolConsistency.watery),
          ('稀软', StoolConsistency.loose),
          ('糊状', StoolConsistency.pasty),
          ('成形', StoolConsistency.formed),
          ('干硬', StoolConsistency.hard),
          ('不确定', StoolConsistency.unsure),
        ]) {
          await tap(tester, choice<StoolConsistency>(label));
          expect(editor(tester).stoolConsistency, value);
          await capture(
            tester,
            'consistency-${value.name}',
            'Select stool consistency $label',
          );
        }
        await tap(tester, choice<StoolConsistency>('不确定'));
        expect(editor(tester).stoolConsistency, isNull);
        await capture(
          tester,
          'consistency-cleared',
          'Tap selected unsure consistency → optional consistency cleared',
        );
        await tap(tester, choice<StoolConsistency>('稀软'));
        await tap(tester, choice<StoolSign>('看到血丝 / 血迹'));
        expect(editor(tester).stoolSigns, {StoolSign.blood});
        await capture(
          tester,
          'sign-blood',
          'Select blood sign → one selected observation',
        );
        await tap(tester, choice<StoolSign>('看到黏液'));
        expect(editor(tester).stoolSigns, {StoolSign.blood, StoolSign.mucus});
        await capture(
          tester,
          'sign-both',
          'Select mucus as well → both observations selected',
        );
        await tap(tester, choice<StoolSign>('看到血丝 / 血迹'));
        expect(editor(tester).stoolSigns, {StoolSign.mucus});
        await capture(
          tester,
          'sign-mucus',
          'Deselect blood → mucus remains selected',
        );
        await tap(tester, choice<StoolSign>('看到黏液'));
        expect(editor(tester).stoolSigns, isEmpty);
        await capture(
          tester,
          'sign-cleared',
          'Deselect mucus → no observations selected',
        );
        await tap(tester, choice<StoolSign>('看到黏液'));
        await tap(tester, find.text('补充备注'));
        await capture(tester, 'note-expanded', 'Expand optional diaper note');
        await input(
          tester,
          'note-diaper',
          '  Morning change\nNo extra details  ',
        );
        await capture(
          tester,
          'note-filled',
          'Enter multiline diaper note with surrounding whitespace',
        );
        await tap(tester, find.text('补充备注'));
        await tap(tester, choice<DiaperKind>('尿湿'));
        expect(find.byType(ChoiceField<StoolColor>), findsNothing);
        expect(editor(tester).stoolColor, StoolColor.yellow);
        expect(editor(tester).stoolConsistency, StoolConsistency.loose);
        expect(editor(tester).stoolSigns, {StoolSign.mucus});
        await capture(
          tester,
          'wet-hides-stool',
          'Switch to wet → stool controls hidden; draft retained',
        );
        await tap(tester, choice<DiaperKind>('尿湿和便便'));
        expect(editor(tester).diaperKind, DiaperKind.both);
        expect(editor(tester).stoolColor, StoolColor.yellow);
        expect(editor(tester).stoolConsistency, StoolConsistency.loose);
        expect(editor(tester).stoolSigns, {StoolSign.mucus});
        await capture(
          tester,
          'both-restores-stool',
          'Choose wet and dirty → original stool selections restored',
        );
        await tap(tester, find.byKey(const ValueKey('baby-save')));
        expect(transport.records, hasLength(1));
        Map<String, Object?> observation() =>
            transport.records.single['observation'] as Map<String, Object?>;
        expect(observation()['diaper_kind'], 'both');
        expect(observation()['color'], 'yellow');
        expect(observation()['consistency'], 'loose');
        expect(observation()['signs'], ['mucus']);
        expect(observation()['note'], 'Morning change\nNo extra details');
        await capture(
          tester,
          'both-saved',
          'Save combined diaper → one record with stool fields and trimmed note',
        );
        await tap(tester, find.text('查看全部记录'));
        const history = '/babies/inventory-baby/records';
        await tap(tester, find.text('尿便'));
        await capture(
          tester,
          'both-history',
          'History diaper tab → combined diaper facts',
          route: history,
        );
        await tap(tester, find.text('编辑'));
        expect(editor(tester).diaperKind, DiaperKind.both);
        expect(editor(tester).stoolColor, StoolColor.yellow);
        expect(editor(tester).stoolConsistency, StoolConsistency.loose);
        expect(editor(tester).stoolSigns, {StoolSign.mucus});
        await capture(
          tester,
          'both-reopened',
          'Edit combined diaper → all saved optional fields restored',
          route: history,
        );
        await tap(tester, choice<DiaperKind>('尿湿'));
        await capture(
          tester,
          'edit-wet',
          'Change saved combined diaper to wet → stool controls hidden',
          route: history,
        );
        await tap(tester, find.byKey(const ValueKey('baby-save')));
        expect(observation()['diaper_kind'], 'wet');
        expect(observation()['color'], isNull);
        expect(observation()['consistency'], isNull);
        expect(observation()['signs'], isEmpty);
        expect(transport.records.single['version'], 2);
        await capture(
          tester,
          'wet-history-saved',
          'Save wet type → stool fields omitted from returned record',
          route: history,
        );
        await dismissSavedNotice(tester);
        await tap(tester, find.text('编辑'));
        expect(editor(tester).stoolColor, isNull);
        expect(editor(tester).stoolConsistency, isNull);
        expect(editor(tester).stoolSigns, isEmpty);
        await tap(tester, choice<DiaperKind>('便便'));
        await capture(
          tester,
          'dirty-optional-empty',
          'Reopen wet then switch dirty → no stale saved stool selections',
          route: history,
        );
        await tap(tester, find.byKey(const ValueKey('baby-save')));
        expect(observation()['diaper_kind'], 'dirty');
        expect(observation()['color'], isNull);
        expect(observation()['consistency'], isNull);
        expect(observation()['signs'], isEmpty);
        expect(transport.records.single['version'], 3);
        await capture(
          tester,
          'dirty-optional-saved',
          'Save dirty diaper with optional color/consistency/signs empty',
          route: history,
        );
        await dismissSavedNotice(tester);
        await tap(tester, find.text('编辑'));
        expect(editor(tester).diaperKind, DiaperKind.dirty);
        expect(editor(tester).stoolColor, isNull);
        await capture(
          tester,
          'dirty-optional-reopened',
          'Reopen dirty diaper → empty optional values persisted',
          route: history,
        );
        await tap(tester, find.byTooltip('关闭记录'));
        expect(find.text('继续填写'), findsNothing);
        await tap(tester, find.text('返回'));
        await capture(
          tester,
          'home-dirty-only',
          'Return Baby → dirty count updated, wet count removed',
        );
        await tap(tester, find.text('More'));
        await capture(
          tester,
          'more-return',
          'Baby → More after diaper controls',
          route: '/more',
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }
}
