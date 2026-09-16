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
        'test/goldens/ui_inventory/baby-feeding-controls-$state-$variant.png';
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/ui_inventory/baby-feeding-controls-$state-$variant.png',
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
      'test': 'test/modules/baby/baby_feeding_control_inventory_test.dart',
    };
    previous = source;
    final output = Platform.environment['MOMCOZY_UI_INVENTORY_DIR'];
    if (output != null) {
      final file = File(
        '$output/journeys/baby-feeding-controls-$state-$variant.json',
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
    testWidgets('inventory Baby feeding controls ${narrow ? '320/2x' : '393/1x'}', (
      tester,
    ) async {
      await mount(tester, width: narrow ? 320 : 393, scale: narrow ? 2 : 1);
      await capture(tester, 'home-entry', 'More → Baby before adding feeding');
      await tap(tester, find.byType(BabyFeedingSummary));
      await tap(tester, find.text('亲喂'));
      expect(editor(tester).feedingMethod, BabyFeedingMethod.breastfeeding);
      await capture(
        tester,
        'nursing-selected',
        'Select nursing → side and optional duration appear',
      );
      await saveInvalid(tester, 'side-required', '请选择这次亲喂的侧别。');
      for (final (label, side) in [
        ('左侧', FeedingSide.left),
        ('右侧', FeedingSide.right),
        ('两侧', FeedingSide.both),
      ]) {
        await tap(tester, find.text(label));
        expect(editor(tester).feedingSide, side);
        await capture(
          tester,
          'side-${side.name}',
          'Tap $label → selected nursing side',
        );
      }
      await tap(tester, find.text('两侧'));
      expect(editor(tester).feedingSide, isNull);
      await saveInvalid(tester, 'side-deselected', '请选择这次亲喂的侧别。');
      await tap(tester, find.text('左侧'));
      for (final (value, state, message) in [
        ('0', 'duration-zero', '亲喂时长需要为 1–240 分钟，也可以留空。'),
        ('241', 'duration-over-limit', '亲喂时长需要为 1–240 分钟，也可以留空。'),
        ('1.5', 'duration-fraction', '亲喂时长请填写整数分钟。'),
      ]) {
        await input(tester, 'nursing-duration', value);
        await saveInvalid(tester, state, message);
      }
      await input(tester, 'nursing-duration', '240');
      await capture(
        tester,
        'duration-upper-bound',
        'Enter valid 240 minute upper bound → validation cleared',
      );
      await tap(tester, find.text('补充备注'));
      await capture(tester, 'note-expanded', 'Expand optional feeding note');
      await input(
        tester,
        'note-feeding',
        '  Quiet feeding\nObserved both sides  ',
      );
      await capture(
        tester,
        'note-filled',
        'Enter multiline note with boundary whitespace',
      );
      await tap(tester, find.text('补充备注'));
      expect(
        editor(tester).feedingNote,
        '  Quiet feeding\nObserved both sides  ',
      );
      await capture(
        tester,
        'note-collapsed',
        'Collapse note → filled marker and draft retained',
      );
      await tap(tester, find.text('瓶喂母乳'));
      expect(editor(tester).duration, '240');
      expect(editor(tester).feedingSide, FeedingSide.left);
      expect(find.byKey(const ValueKey('nursing-duration')), findsNothing);
      await capture(
        tester,
        'expressed-milk-selected',
        'Switch to expressed milk → volume replaces nursing controls; nursing draft retained',
      );
      for (final (value, state, message) in [
        ('0', 'volume-zero', '瓶喂量需要大于 0 且不超过 1000 ml，也可以留空。'),
        ('1001', 'volume-over-limit', '瓶喂量需要大于 0 且不超过 1000 ml，也可以留空。'),
        ('abc', 'volume-not-number', '请检查瓶喂量。'),
      ]) {
        await input(tester, 'feeding-volume', value);
        await saveInvalid(tester, state, message);
      }
      await input(tester, 'feeding-volume', '1000');
      await capture(
        tester,
        'volume-upper-bound',
        'Enter 1000 ml upper bound → validation cleared',
      );
      await tap(tester, find.text('配方奶'));
      expect(editor(tester).volume, '1000');
      await capture(
        tester,
        'formula-selected',
        'Switch expressed milk → formula; bottle volume retained',
      );
      await tap(tester, find.text('配方奶'));
      expect(editor(tester).feedingMethod, isNull);
      expect(find.byKey(const ValueKey('feeding-volume')), findsNothing);
      await saveInvalid(tester, 'method-deselected', '先选择这次的喂养方式。');
      await tap(tester, find.text('亲喂'));
      expect(editor(tester).duration, '240');
      expect(editor(tester).feedingSide, FeedingSide.left);
      await capture(
        tester,
        'nursing-draft-restored',
        'Reselect nursing → original side and duration return',
      );
      await tap(tester, find.byKey(const ValueKey('baby-save')));
      expect(find.byType(BabyRecordEditor), findsNothing);
      expect(transport.records, hasLength(1));
      Map<String, Object?> observation() =>
          transport.records.single['observation'] as Map<String, Object?>;
      expect(observation()['method'], 'breastfeeding');
      expect(observation()['side'], 'left');
      expect(observation()['duration_minutes'], 240);
      expect(observation()['volume_ml'], isNull);
      expect(observation()['note'], 'Quiet feeding\nObserved both sides');
      await capture(
        tester,
        'nursing-saved',
        'Save nursing → home refresh; dormant bottle value omitted and note trimmed',
      );
      await tap(tester, find.text('查看全部记录'));
      const history = '/babies/inventory-baby/records';
      await capture(
        tester,
        'nursing-history',
        'View all records → saved nursing with duration and note',
        route: history,
      );
      await tap(tester, find.text('编辑'));
      expect(editor(tester).duration, '240');
      expect(editor(tester).volume, isEmpty);
      expect(editor(tester).note, 'Quiet feeding\nObserved both sides');
      await capture(
        tester,
        'nursing-history-edit',
        'Edit saved nursing → persisted values, note expanded',
        route: history,
      );
      await tap(tester, find.text('配方奶'));
      await input(tester, 'feeding-volume', '90.5');
      await capture(
        tester,
        'edit-formula-decimal',
        'Change saved nursing to formula and enter decimal 90.5 ml',
        route: history,
      );
      await tap(tester, find.byKey(const ValueKey('baby-save')));
      expect(observation()['method'], 'formula');
      expect(observation()['volume_ml'], 90.5);
      expect(observation()['side'], isNull);
      expect(observation()['duration_minutes'], isNull);
      expect(transport.records.single['version'], 2);
      await capture(
        tester,
        'formula-history-saved',
        'Save type change → formula shown, nursing fields omitted',
        route: history,
      );
      await dismissSavedNotice(tester);
      await tap(tester, find.text('编辑'));
      expect(editor(tester).volume, '90.5');
      expect(editor(tester).duration, isEmpty);
      expect(editor(tester).feedingSide, isNull);
      await capture(
        tester,
        'formula-history-reopened',
        'Reopen saved formula → decimal restored, no stale nursing fields',
        route: history,
      );
      await input(tester, 'feeding-volume', '');
      await capture(
        tester,
        'optional-volume-cleared',
        'Clear optional bottle volume before saving',
        route: history,
      );
      await tap(tester, find.byKey(const ValueKey('baby-save')));
      expect(observation()['volume_ml'], isNull);
      expect(transport.records.single['version'], 3);
      await capture(
        tester,
        'optional-volume-saved',
        'Save formula without measured volume → count-only history',
        route: history,
      );
      await dismissSavedNotice(tester);
      await tap(tester, find.text('编辑'));
      expect(editor(tester).volume, isEmpty);
      await capture(
        tester,
        'optional-volume-reopened',
        'Reopen formula without volume → empty optional field persisted',
        route: history,
      );
      await tap(tester, find.byTooltip('关闭记录'));
      expect(find.text('继续填写'), findsNothing);
      await capture(
        tester,
        'unchanged-editor-closed',
        'Close unchanged saved record → no discard dialog',
        route: history,
      );
      await tap(tester, find.text('返回'));
      await capture(
        tester,
        'home-count-only',
        'History Back → home counts feeding without invented ml',
      );
      await tap(tester, find.text('More'));
      await capture(
        tester,
        'more-return',
        'Baby → More after feeding controls',
        route: '/more',
      );
      await tester.pumpWidget(const SizedBox());
    });
  }
}
