import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../support/fake_agent_voice.dart';
import '../../support/fixture_api_transport.dart';
import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/shared/widgets/zoned_datetime_field.dart';
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
        'test/goldens/ui_inventory/baby-sleep-controls-$state-$variant.png';
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/ui_inventory/baby-sleep-controls-$state-$variant.png',
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
      'test': 'test/modules/baby/baby_sleep_control_inventory_test.dart',
    };
    previous = source;
    final output = Platform.environment['MOMCOZY_UI_INVENTORY_DIR'];
    if (output != null) {
      final file = File(
        '$output/journeys/baby-sleep-controls-$state-$variant.json',
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
      'inventory Baby sleep controls ${narrow ? '320/2x' : '393/1x'}',
      (tester) async {
        await mount(tester, width: narrow ? 320 : 393, scale: narrow ? 2 : 1);
        await capture(
          tester,
          'home-entry',
          'More → Baby before sleep controls',
        );
        final sleepCard = find.byWidgetPredicate(
          (w) => w is BabyStatusCard && w.label == '睡眠',
        );
        await tap(tester, sleepCard);
        await capture(
          tester,
          'new-open',
          'Tap sleep status → start now, optional wake empty',
        );
        final strings = MaterialLocalizations.of(
          tester.element(find.byType(BabyRecordEditor)),
        );
        final datePicker = find.byType(DatePickerDialog);
        final timePicker = find.byKey(const ValueKey('momcozy-time-picker'));
        const startLabel = '入睡时间', endLabel = '醒来时间（可不填）';
        Future<void> openDate(String label) async {
          final field = find.byWidgetPredicate(
            (w) => w is ZonedDateTimeField && w.label == label,
          );
          await tap(
            tester,
            find.descendant(of: field, matching: find.byType(OutlinedButton)),
          );
        }

        Future<void> confirm(Finder parent) async => tap(
          tester,
          find.descendant(
            of: parent,
            matching: find.text(strings.okButtonLabel),
          ),
        );
        Future<void> cancel(Finder parent) async => tap(
          tester,
          find.descendant(
            of: parent,
            matching: find.text(strings.cancelButtonLabel),
          ),
        );
        Future<void> setClock(String label, String hour, String minute) async {
          await openDate(label);
          await confirm(datePicker);
          if (find
              .byTooltip(strings.inputTimeModeButtonLabel)
              .evaluate()
              .isNotEmpty) {
            await tap(tester, find.byTooltip(strings.inputTimeModeButtonLabel));
          }
          final fields = find.descendant(
            of: timePicker,
            matching: find.byType(TextFormField),
          );
          expect(fields, findsNWidgets(2));
          await tester.enterText(fields.at(0), hour);
          await tester.enterText(fields.at(1), minute);
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
          await confirm(timePicker);
        }

        await openDate(startLabel);
        await capture(tester, 'start-date', 'Open sleep start date picker');
        await confirm(datePicker);
        await capture(
          tester,
          'start-time',
          'Confirm date → sleep start time picker',
        );
        await cancel(timePicker);
        expect(editor(tester).sleepStartedAt.toUtc(), inventoryBabyNow);
        await capture(
          tester,
          'start-cancelled',
          'Cancel start clock → original start retained',
        );
        await setClock(startLabel, '16', '01');
        await capture(
          tester,
          'start-future',
          'Choose start one minute in future',
        );
        await saveInvalid(tester, 'start-future-rejected', '发生时间不能晚于现在。');
        await setClock(startLabel, '15', '00');
        expect(
          editor(tester).sleepStartedAt.toUtc(),
          DateTime.utc(2026, 9, 13, 7),
        );
        await capture(
          tester,
          'start-past',
          'Correct start to 15:00, validation cleared',
        );
        await openDate(endLabel);
        await capture(
          tester,
          'wake-date-empty',
          'Open empty wake date → current date',
        );
        await confirm(datePicker);
        await capture(
          tester,
          'wake-time-empty',
          'Confirm wake date → current clock, not yet committed',
        );
        await cancel(timePicker);
        expect(editor(tester).sleepEndedAt, isNull);
        await capture(
          tester,
          'wake-cancelled',
          'Cancel wake clock → optional wake remains empty',
        );
        for (final (state, hour, minute) in [
          ('equal', '15', '00'),
          ('before', '14', '59'),
          ('future', '16', '01'),
        ]) {
          await setClock(endLabel, hour, minute);
          await capture(
            tester,
            'wake-$state',
            'Select wake $hour:$minute before validation',
          );
          await saveInvalid(
            tester,
            'wake-$state-rejected',
            '醒来时间需要晚于入睡时间，且不能晚于现在。',
          );
        }
        await setClock(endLabel, '16', '00');
        expect(editor(tester).sleepEndedAt!.toUtc(), inventoryBabyNow);
        expect(editor(tester).validation, isNull);
        await capture(
          tester,
          'wake-valid',
          'Choose valid wake at current time → validation cleared',
        );
        await tap(tester, find.text('清除时间'));
        expect(editor(tester).sleepEndedAt, isNull);
        await capture(
          tester,
          'wake-cleared',
          'Clear wake → active sleep save action restored',
        );
        await tap(tester, find.text('补充备注'));
        await capture(tester, 'note-expanded', 'Expand optional sleep note');
        await input(tester, 'note-sleep', '  Resting quietly\nWindow closed  ');
        await capture(
          tester,
          'note-filled',
          'Enter short sleep note with surrounding spaces and newline',
        );
        await tap(tester, find.text('补充备注'));
        await capture(
          tester,
          'note-collapsed',
          'Collapse filled note → value retained',
        );
        await tap(tester, find.byKey(const ValueKey('baby-save')));
        Map<String, Object?> observation() =>
            transport.records.single['observation'] as Map<String, Object?>;
        expect(transport.records, hasLength(1));
        expect(observation()['ended_at'], isNull);
        expect(observation()['note'], 'Resting quietly\nWindow closed');
        await capture(
          tester,
          'active-saved',
          'Save active sleep with empty wake → home active record',
        );
        await dismissSavedNotice(tester);
        await tester.scrollUntilVisible(
          find.text('Luna'),
          -400,
          scrollable: find.byType(Scrollable).first,
          maxScrolls: 30,
        );
        await tap(tester, sleepCard);
        expect(editor(tester).hasActiveSleep, isTrue);
        await capture(
          tester,
          'active-open',
          'Tap active sleep → compact status and record wake now',
        );
        await tap(tester, find.text('调整时间和备注'));
        await capture(
          tester,
          'active-expanded',
          'Expand active sleep times and saved note',
        );
        await tap(tester, find.text('收起时间和备注'));
        await capture(
          tester,
          'active-collapsed',
          'Collapse time and note controls without modifying record',
        );
        await tap(tester, find.text('调整时间和备注'));
        await setClock(endLabel, '15', '30');
        await capture(
          tester,
          'active-manual-wake',
          'Choose manual wake 15:30 in active editor',
        );
        await tap(tester, find.text('清除时间'));
        await capture(
          tester,
          'active-wake-cleared',
          'Clear manual wake → record wake now action restored',
        );
        await tap(tester, find.byKey(const ValueKey('baby-save')));
        expect(observation()['ended_at'], inventoryBabyNow.toIso8601String());
        expect(transport.records.single['version'], 2);
        await capture(
          tester,
          'completed-now',
          'Record wake now → same record updated, one hour complete',
        );
        await dismissSavedNotice(tester);
        await tap(tester, find.text('查看全部记录'));
        await tap(tester, find.text('睡眠'));
        const history = '/babies/inventory-baby/records';
        await capture(
          tester,
          'history-completed',
          'History sleep tab → completed record with start/end and note',
          route: history,
        );
        await tap(tester, find.text('编辑'));
        await capture(
          tester,
          'history-editor',
          'Edit completed sleep → start, wake and note restored',
          route: history,
        );
        await tap(tester, find.text('清除时间'));
        expect(editor(tester).editing, isTrue);
        await capture(
          tester,
          'history-wake-cleared',
          'Clear saved wake in history editor → draft becomes open interval',
          route: history,
        );
        await tap(tester, find.byKey(const ValueKey('baby-save')));
        expect(observation()['ended_at'], isNull);
        expect(transport.records.single['version'], 3);
        await capture(
          tester,
          'history-active-saved',
          'Save history edit with no wake → active interval persisted',
          route: history,
        );
        await dismissSavedNotice(tester);
        await tap(tester, find.text('编辑'));
        expect(editor(tester).hasActiveSleep, isTrue);
        expect(editor(tester).sleepEndedAt, isNull);
        await capture(
          tester,
          'history-active-reopened',
          'Reopen active interval from history → editable times visible',
          route: history,
        );
        await tap(tester, find.byTooltip('关闭记录'));
        expect(find.text('继续填写'), findsNothing);
        await tap(tester, find.text('返回'));
        await capture(
          tester,
          'home-active-return',
          'Return Baby → reopened sleep shown as active',
        );
        await tap(tester, find.text('More'));
        await capture(
          tester,
          'more-return',
          'Baby → More after sleep control chain',
          route: '/more',
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }
}
