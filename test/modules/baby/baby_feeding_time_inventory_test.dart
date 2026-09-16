import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../support/fake_agent_voice.dart';
import '../../support/fixture_api_transport.dart';
import 'package:flutter/material.dart';
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
        'test/goldens/ui_inventory/baby-feeding-time-$state-$variant.png';
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/ui_inventory/baby-feeding-time-$state-$variant.png',
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
      'test': 'test/modules/baby/baby_feeding_time_inventory_test.dart',
    };
    previous = source;
    final output = Platform.environment['MOMCOZY_UI_INVENTORY_DIR'];
    if (output != null) {
      final file = File(
        '$output/journeys/baby-feeding-time-$state-$variant.json',
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
    testWidgets('inventory Baby feeding time ${narrow ? '320/2x' : '393/1x'}', (
      tester,
    ) async {
      await mount(tester, width: narrow ? 320 : 393, scale: narrow ? 2 : 1);
      await capture(tester, 'home-entry', 'More → Baby before time controls');
      await tap(tester, find.byType(BabyFeedingSummary));
      await tap(tester, find.text('亲喂'));
      await tap(tester, find.text('右侧'));
      final original = editor(tester).occurredAt;
      await capture(
        tester,
        'nursing-ready',
        'Choose nursing/right with optional duration empty',
      );
      final datePicker = find.byType(DatePickerDialog);
      final timePicker = find.byKey(const ValueKey('momcozy-time-picker'));
      final clockButton = find.widgetWithIcon(
        OutlinedButton,
        Icons.schedule_outlined,
      );
      final strings = MaterialLocalizations.of(
        tester.element(find.byType(BabyRecordEditor)),
      );
      Future<void> openDate() async => tap(tester, clockButton);
      Future<void> dateInput() async {
        if (find.byType(CalendarDatePicker).evaluate().isNotEmpty) {
          await tap(tester, find.byTooltip(strings.inputDateModeButtonLabel));
        }
      }

      Future<void> enterDate(DateTime value) async {
        await dateInput();
        final field = find.descendant(
          of: datePicker,
          matching: find.byType(TextFormField),
        );
        await tester.enterText(field, strings.formatCompactDate(value));
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
      }

      Future<void> confirm(Finder parent) async => tap(
        tester,
        find.descendant(of: parent, matching: find.text(strings.okButtonLabel)),
      );
      Future<void> cancel(Finder parent) async => tap(
        tester,
        find.descendant(
          of: parent,
          matching: find.text(strings.cancelButtonLabel),
        ),
      );
      Future<void> timeInput() async {
        if (find
            .byTooltip(strings.inputTimeModeButtonLabel)
            .evaluate()
            .isNotEmpty) {
          await tap(tester, find.byTooltip(strings.inputTimeModeButtonLabel));
        }
      }

      Future<void> enterTime(String hour, String minute) async {
        await timeInput();
        final fields = find.descendant(
          of: timePicker,
          matching: find.byType(TextFormField),
        );
        expect(fields, findsNWidgets(2));
        await tester.enterText(fields.at(0), hour);
        await tester.enterText(fields.at(1), minute);
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
      }

      await openDate();
      expect(
        tester.widget<DatePickerDialog>(datePicker).currentDate,
        DateTime(2026, 9, 13),
      );
      await capture(
        tester,
        'date-open',
        'Open occurred date; today follows fixed timezone clock',
      );
      await cancel(datePicker);
      expect(editor(tester).occurredAt, original);
      await capture(
        tester,
        'date-cancelled',
        'Cancel date → original instant unchanged',
      );
      await openDate();
      await enterDate(DateTime(2026, 9, 12));
      await capture(
        tester,
        'previous-day-input',
        'Enter previous date before confirmation',
      );
      await confirm(datePicker);
      expect(editor(tester).occurredAt, original);
      await capture(
        tester,
        'time-open',
        'Confirm date → time picker; editor instant still unchanged',
      );
      await cancel(timePicker);
      expect(editor(tester).occurredAt, original);
      await capture(
        tester,
        'time-cancelled',
        'Cancel second-stage time → selected date also discarded',
      );
      await openDate();
      await enterDate(DateTime(2026, 9, 14));
      await confirm(datePicker);
      expect(datePicker, findsOneWidget);
      expect(find.text(strings.dateOutOfRangeLabel), findsOneWidget);
      await capture(
        tester,
        'future-date-rejected',
        'Confirm tomorrow → date range validation, no time picker',
      );
      await enterDate(DateTime(2026, 9, 13));
      await confirm(datePicker);
      await enterTime('24', '60');
      await confirm(timePicker);
      expect(timePicker, findsOneWidget);
      expect(find.text(strings.invalidTimeLabel), findsWidgets);
      await capture(
        tester,
        'invalid-clock',
        'Confirm hour 24/minute 60 → invalid time; picker remains',
      );
      await enterTime('16', '01');
      await capture(
        tester,
        'future-minute-input',
        'Correct to 16:01 on today; one minute after current time',
      );
      await confirm(timePicker);
      expect(
        editor(tester).occurredAt.toUtc(),
        DateTime.utc(2026, 9, 13, 8, 1),
      );
      await capture(
        tester,
        'future-minute-selected',
        'Confirm syntactically valid future minute into draft',
      );
      await saveInvalid(tester, 'future-minute-rejected', '发生时间不能晚于现在。');
      await openDate();
      await enterDate(DateTime(2026, 9, 13));
      await confirm(datePicker);
      await enterTime('16', '00');
      await confirm(timePicker);
      expect(editor(tester).occurredAt.toUtc(), DateTime.utc(2026, 9, 13, 8));
      expect(editor(tester).validation, isNull);
      await capture(
        tester,
        'current-minute-restored',
        'Select exactly now → future validation cleared',
      );
      await tap(tester, find.byKey(const ValueKey('baby-save')));
      expect(find.byType(BabyRecordEditor), findsNothing);
      expect(transport.records, hasLength(1));
      Map<String, Object?> observation() =>
          transport.records.single['observation'] as Map<String, Object?>;
      expect(observation()['duration_minutes'], isNull);
      expect(observation()['side'], 'right');
      await capture(
        tester,
        'optional-duration-saved',
        'Save nursing at current minute without duration → one count',
      );
      await tap(tester, find.text('查看全部记录'));
      const history = '/babies/inventory-baby/records';
      await capture(
        tester,
        'optional-duration-history',
        'Open history → saved nursing without invented duration',
        route: history,
      );
      await tap(tester, find.text('编辑'));
      expect(editor(tester).duration, isEmpty);
      expect(editor(tester).occurredAt.toUtc(), DateTime.utc(2026, 9, 13, 8));
      await capture(
        tester,
        'optional-duration-reopened',
        'Reopen history → empty optional duration and current instant persisted',
        route: history,
      );
      await input(tester, 'nursing-duration', '1');
      await tap(tester, find.byKey(const ValueKey('baby-save')));
      expect(observation()['duration_minutes'], 1);
      expect(transport.records.single['version'], 2);
      await capture(
        tester,
        'minimum-duration-saved',
        'Save minimum one-minute duration in history',
        route: history,
      );
      await dismissSavedNotice(tester);
      await tap(tester, find.text('编辑'));
      expect(editor(tester).duration, '1');
      await tap(tester, find.text('瓶喂母乳'));
      await input(tester, 'feeding-volume', '1000');
      await capture(
        tester,
        'maximum-volume-ready',
        'Change to expressed milk; enter maximum 1000 ml',
        route: history,
      );
      await tap(tester, find.byKey(const ValueKey('baby-save')));
      expect(observation()['method'], 'expressed_milk');
      expect(observation()['volume_ml'], 1000);
      expect(observation()['duration_minutes'], isNull);
      expect(observation()['side'], isNull);
      expect(transport.records.single['version'], 3);
      await capture(
        tester,
        'maximum-volume-saved',
        'Save maximum bottle volume; nursing fields removed',
        route: history,
      );
      await dismissSavedNotice(tester);
      await tap(tester, find.text('编辑'));
      expect(editor(tester).volume, '1000.0');
      await capture(
        tester,
        'maximum-volume-reopened',
        'Reopen and verify 1000 ml persisted',
        route: history,
      );
      await tap(tester, find.byTooltip('关闭记录'));
      await tap(tester, find.text('返回'));
      await capture(
        tester,
        'home-volume-refreshed',
        'Return Baby → actual 1000 ml home summary',
      );
      await tap(tester, find.text('More'));
      await capture(
        tester,
        'more-return',
        'Baby → More after time and valid-boundary chain',
        route: '/more',
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
}
