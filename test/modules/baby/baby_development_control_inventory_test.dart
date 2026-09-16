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
        'test/goldens/ui_inventory/baby-development-controls-$state-$variant.png';
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/ui_inventory/baby-development-controls-$state-$variant.png',
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
      'test': 'test/modules/baby/baby_development_control_inventory_test.dart',
    };
    previous = source;
    final output = Platform.environment['MOMCOZY_UI_INVENTORY_DIR'];
    if (output != null) {
      final file = File(
        '$output/journeys/baby-development-controls-$state-$variant.json',
      );
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(row)}\n',
      );
    }
  }

  BabyRecordEditorController editor(WidgetTester tester) =>
      tester.widget<BabyRecordEditor>(find.byType(BabyRecordEditor)).controller;
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
    testWidgets('inventory Baby development controls ${narrow ? '320/2x' : '393/1x'}', (
      tester,
    ) async {
      await mount(tester, width: narrow ? 320 : 393, scale: narrow ? 2 : 1);
      await capture(
        tester,
        'home-entry',
        'More → Baby before developmental observation controls',
      );
      await tap(tester, find.text('记录发育观察'));
      await capture(
        tester,
        'editor-empty',
        'Tap developmental observation → three unselected behavior groups',
      );
      const required = '至少记录一项具体行为，拿不准可以选择“不确定”。';
      await saveInvalid(tester, 'required-error', required);
      Finder group(String id) => find.byWidgetPredicate(
        (w) => w is ChoiceField && w.title == babyDevelopmentItems[id],
      );
      Future<void> select(String id, String label) async => tap(
        tester,
        find.descendant(of: group(id), matching: find.text(label)),
      );
      for (final id in babyDevelopmentItems.keys) {
        for (final (label, value) in [
          ('观察到', DevelopmentStatus.observed),
          ('暂未观察到', DevelopmentStatus.notObserved),
          ('不确定', DevelopmentStatus.unsure),
        ]) {
          await select(id, label);
          expect(editor(tester).development[id], value);
          expect(editor(tester).validation, isNull);
          await capture(
            tester,
            '$id-${value.name}',
            'Select ${babyDevelopmentItems[id]} → $label',
          );
        }
        await select(id, '不确定');
        expect(editor(tester).development.containsKey(id), isFalse);
        await capture(
          tester,
          '$id-cleared',
          'Tap selected unsure again → clear ${babyDevelopmentItems[id]}',
        );
      }
      await saveInvalid(tester, 'all-cleared-rejected', required);
      for (final (id, label) in [
        ('looks-at-face', '观察到'),
        ('responds-to-sound', '暂未观察到'),
        ('lifts-head', '不确定'),
      ]) {
        await select(id, label);
        await capture(
          tester,
          'batch-$id',
          'Choose $label for ${babyDevelopmentItems[id]} while preserving other groups',
        );
      }
      await tap(tester, find.byTooltip('关闭记录'));
      await capture(
        tester,
        'discard-confirm',
        'Close dirty observation draft → discard confirmation',
      );
      await tap(tester, find.text('继续填写'));
      expect(editor(tester).development, hasLength(3));
      await capture(
        tester,
        'discard-retained',
        'Continue filling → three selections retained',
      );
      await tap(tester, find.text('2026-09-13'));
      final date = find.byType(DatePickerDialog);
      final strings = MaterialLocalizations.of(tester.element(date));
      Finder button(String label) =>
          find.descendant(of: date, matching: find.text(label));
      await capture(
        tester,
        'date-open',
        'Open observation date constrained by birth and today',
      );
      await tap(tester, button(strings.cancelButtonLabel));
      expect(editor(tester).recordedOn.toString(), '2026-09-13');
      await capture(
        tester,
        'date-cancelled',
        'Cancel observation date → date and statuses retained',
      );
      await tap(tester, find.text('2026-09-13'));
      if (find
          .byTooltip(strings.inputDateModeButtonLabel)
          .evaluate()
          .isNotEmpty) {
        await tap(tester, find.byTooltip(strings.inputDateModeButtonLabel));
      }
      await tester.enterText(
        find.descendant(of: date, matching: find.byType(TextFormField)),
        strings.formatCompactDate(DateTime(2026, 9, 12)),
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await capture(
        tester,
        'date-input',
        'Input yesterday before confirming observation date',
      );
      await tap(tester, button(strings.okButtonLabel));
      await capture(
        tester,
        'date-selected',
        'Confirm yesterday → all observations share selected date',
      );
      transport.failWrite = true;
      await tap(tester, find.byKey(const ValueKey('baby-save')));
      expect(editor(tester).uncertain, isTrue);
      expect(editor(tester).editable, isFalse);
      expect(transport.records, isEmpty);
      await capture(
        tester,
        'save-uncertain',
        'Batch POST fails 503 → unconfirmed save, draft locked and retry',
      );
      await tap(tester, find.byTooltip('关闭记录'));
      await capture(
        tester,
        'uncertain-close',
        'Close unconfirmed observation save → uncertainty warning',
      );
      await tap(tester, find.text('继续填写'));
      await capture(
        tester,
        'uncertain-retained',
        'Stay on unconfirmed draft without resubmitting',
      );
      transport.failWrite = false;
      transport.writeGate = Completer<void>();
      await tester.tap(find.byKey(const ValueKey('baby-save')));
      await tester.pump();
      expect(editor(tester).busy, isTrue);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('baby-save')))
            .onPressed,
        isNull,
      );
      await capture(
        tester,
        'saving',
        'Retry save → pending request and disabled saving action',
      );
      transport.writeGate!.complete();
      await tester.pumpAndSettle();
      expect(transport.records, hasLength(3));
      expect(
        transport.records.map((r) => (r['observation'] as Map)['status']),
        orderedEquals(['observed', 'not_observed', 'unsure']),
      );
      expect(
        transport.records.map((r) => (r['observation'] as Map)['recorded_on']),
        everyElement('2026-09-12'),
      );
      await capture(
        tester,
        'batch-saved',
        'Retry acknowledged → three dated observations saved together',
      );
      await dismissSavedNotice(tester);
      await tap(tester, find.text('查看全部记录'));
      await tap(tester, find.text('发育观察'));
      const history = '/babies/inventory-baby/records';
      await capture(
        tester,
        'history',
        'Open developmental history → each behavior and saved status',
        route: history,
      );
      for (final (index, id, label, wire) in [
        (0, 'looks-at-face', '暂未观察到', 'not_observed'),
        (1, 'responds-to-sound', '不确定', 'unsure'),
        (2, 'lifts-head', '观察到', 'observed'),
      ]) {
        await tap(tester, find.text('编辑').at(index));
        expect(editor(tester).development.keys, [id]);
        expect(
          tester
              .widgetList<ChoiceField>(
                find.byWidgetPredicate((w) => w is ChoiceField),
              )
              .map((w) => w.title),
          [babyDevelopmentItems[id]],
        );
        await capture(
          tester,
          'history-$id-open',
          'Edit ${babyDevelopmentItems[id]} → only original behavior available',
          route: history,
        );
        final selected = editor(tester).development[id]!;
        final originalLabel = switch (selected) {
          DevelopmentStatus.observed => '观察到',
          DevelopmentStatus.notObserved => '暂未观察到',
          DevelopmentStatus.unsure => '不确定',
        };
        await select(id, originalLabel);
        await tester.tap(find.byKey(const ValueKey('baby-save')));
        await tester.pumpAndSettle();
        expect(editor(tester).validation, required);
        expect(transport.records[index]['version'], 1);
        await capture(
          tester,
          'history-$id-cleared',
          'Clear original status and save → required validation; stored record unchanged',
          route: history,
        );
        await select(id, label);
        await capture(
          tester,
          'history-$id-changed',
          'Choose $label for this existing behavior',
          route: history,
        );
        await tap(tester, find.byKey(const ValueKey('baby-save')));
        expect(transport.records[index]['version'], 2);
        expect(
          (transport.records[index]['observation'] as Map)['status'],
          wire,
        );
        expect(transport.records, hasLength(3));
        await capture(
          tester,
          'history-$id-saved',
          'Save changed status → same record updated; other behaviors retained',
          route: history,
        );
        await dismissSavedNotice(tester);
      }
      await tap(tester, find.text('编辑').first);
      expect(
        editor(tester).development['looks-at-face'],
        DevelopmentStatus.notObserved,
      );
      await capture(
        tester,
        'history-reopened',
        'Reopen first edited behavior → saved status persists',
        route: history,
      );
      await tap(tester, find.byTooltip('关闭记录'));
      expect(find.text('继续填写'), findsNothing);
      await tap(tester, find.text('返回'));
      await capture(
        tester,
        'home-return',
        'Return Baby after developmental history edits',
      );
      await tap(tester, find.text('More'));
      await capture(
        tester,
        'more-return',
        'Baby → More after developmental observation chain',
        route: '/more',
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
}
