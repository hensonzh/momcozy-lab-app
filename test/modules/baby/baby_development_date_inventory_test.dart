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
        'test/goldens/ui_inventory/baby-development-date-$state-$variant.png';
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/ui_inventory/baby-development-date-$state-$variant.png',
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
      'test': 'test/modules/baby/baby_development_date_inventory_test.dart',
    };
    previous = source;
    final output = Platform.environment['MOMCOZY_UI_INVENTORY_DIR'];
    if (output != null) {
      final file = File(
        '$output/journeys/baby-development-date-$state-$variant.json',
      );
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(row)}\n',
      );
    }
  }

  BabyRecordEditorController editor(WidgetTester tester) =>
      tester.widget<BabyRecordEditor>(find.byType(BabyRecordEditor)).controller;

  for (final narrow in [false, true]) {
    testWidgets('inventory development date ${narrow ? '320/2x' : '393/1x'}', (
      tester,
    ) async {
      await mount(tester, width: narrow ? 320 : 393, scale: narrow ? 2 : 1);
      await capture(tester, 'home-entry', 'More → Baby before date navigation');
      await tap(tester, find.text('记录发育观察'));
      await capture(tester, 'editor', 'Open development observation editor');
      await tap(tester, find.text('2026-09-13'));
      final picker = find.byType(DatePickerDialog);
      final strings = MaterialLocalizations.of(tester.element(picker));
      Finder button(String value) =>
          find.descendant(of: picker, matching: find.text(value));
      final field = find.descendant(
        of: picker,
        matching: find.byType(TextFormField),
      );
      Future<void> inputDate(DateTime value) async {
        await tester.enterText(field, strings.formatCompactDate(value));
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
      }

      expect(
        tester.widget<DatePickerDialog>(picker).firstDate,
        DateTime(2026, 8, 22),
      );
      await capture(
        tester,
        'known-birth-picker',
        'Open date with known birth → range Aug 22 through Sep 13',
      );
      if (narrow) {
        expect(
          tester.widget<DatePickerDialog>(picker).initialEntryMode,
          DatePickerEntryMode.inputOnly,
        );
        await inputDate(DateTime(2026, 9, 12));
        await capture(
          tester,
          'known-birth-input',
          'Large text input-only picker: enter Sep 12',
        );
      } else {
        await tap(
          tester,
          find.text(strings.formatMonthYear(DateTime(2026, 9))),
        );
        expect(find.byType(YearPicker), findsOneWidget);
        await capture(
          tester,
          'known-birth-years',
          'Tap calendar header → only birth/current year selectable',
        );
        await tap(
          tester,
          find.descendant(
            of: find.byType(YearPicker),
            matching: find.text(strings.formatYear(DateTime(2026))),
          ),
        );
        await capture(
          tester,
          'known-birth-year-selected',
          'Select 2026 → September calendar',
        );
        await tap(
          tester,
          find.descendant(
            of: find.byType(CalendarDatePicker),
            matching: find.text('12'),
          ),
        );
        await capture(
          tester,
          'known-birth-day-selected',
          'Tap day grid Sep 12 → selected, still awaiting confirmation',
        );
      }
      await tap(tester, button(strings.okButtonLabel));
      expect(editor(tester).recordedOn.toString(), '2026-09-12');
      await capture(
        tester,
        'known-birth-confirmed',
        'Confirm Sep 12 → observation draft date changes',
      );
      await tap(tester, find.byTooltip('关闭记录'));
      await capture(
        tester,
        'known-birth-discard',
        'Close date-modified draft → discard confirmation',
      );
      await tap(tester, find.text('离开'));
      await capture(
        tester,
        'known-birth-left',
        'Discard changed observation date → Baby, no records written',
      );
      expect(transport.records, isEmpty);
      await tester.scrollUntilVisible(
        find.text('Luna'),
        -400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await capture(tester, 'home-top', 'Scroll Baby back to profile header');
      await tap(tester, find.text('Luna'));
      await capture(tester, 'baby-switcher', 'Tap Luna → baby switcher');
      await tap(tester, find.text('编辑当前宝宝资料'));
      await capture(
        tester,
        'profile-editor',
        'Edit current baby profile through switcher',
      );
      await tap(tester, find.text('清除日期'));
      await capture(
        tester,
        'birth-cleared',
        'Clear birth date in profile draft',
      );
      await tap(tester, find.text('保存宝宝资料'));
      expect(transport.profiles.first['birth_date'], isNull);
      await capture(
        tester,
        'no-birth-home',
        'Save profile with no birth date → Baby',
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tap(tester, find.text('记录发育观察'));
      expect(editor(tester).baby.birthDate, isNull);
      await capture(
        tester,
        'no-birth-editor',
        'Open observation for baby without birth date',
      );
      await tap(tester, find.text('2026-09-13'));
      expect(
        tester.widget<DatePickerDialog>(picker).firstDate,
        DateTime(1900, 1, 1),
      );
      await capture(
        tester,
        'no-birth-picker',
        'No birth date → earliest selectable date Jan 1 1900',
      );
      if (narrow) {
        await inputDate(DateTime(2025, 9, 15));
        await capture(
          tester,
          'no-birth-input',
          'Large text input-only picker: enter Sep 15 2025',
        );
      } else {
        await tap(
          tester,
          find.text(strings.formatMonthYear(DateTime(2026, 9))),
        );
        await capture(
          tester,
          'no-birth-years',
          'Open year list without birth date → earlier years available',
        );
        await tap(
          tester,
          find.descendant(
            of: find.byType(YearPicker),
            matching: find.text(strings.formatYear(DateTime(2025))),
          ),
        );
        await capture(
          tester,
          'no-birth-year-selected',
          'Select 2025 → September calendar',
        );
        await tap(
          tester,
          find.descendant(
            of: find.byType(CalendarDatePicker),
            matching: find.text('15'),
          ),
        );
        await capture(
          tester,
          'no-birth-day-selected',
          'Select Sep 15 2025 on day grid',
        );
      }
      await tap(tester, button(strings.okButtonLabel));
      expect(editor(tester).recordedOn.toString(), '2025-09-15');
      await capture(
        tester,
        'no-birth-confirmed',
        'Confirm earlier year → no-birth observation draft accepts date',
      );
      await tap(tester, find.text('2025-09-15'));
      await capture(
        tester,
        'earlier-date-reopened',
        'Reopen picker at selected date Sep 15 2025',
      );
      if (!narrow) {
        await tap(tester, find.byTooltip(strings.inputDateModeButtonLabel));
        await capture(
          tester,
          'earlier-date-input-mode',
          'Switch reopened calendar to date text input',
        );
      }
      await inputDate(DateTime(1899, 12, 31));
      await tap(tester, button(strings.okButtonLabel));
      expect(find.text(strings.dateOutOfRangeLabel), findsOneWidget);
      expect(editor(tester).recordedOn.toString(), '2025-09-15');
      await capture(
        tester,
        'before-minimum-rejected',
        'Submit Dec 31 1899 → range validation, draft unchanged',
      );
      await inputDate(DateTime(1900, 1, 1));
      await tap(tester, button(strings.okButtonLabel));
      expect(editor(tester).recordedOn.toString(), '1900-01-01');
      await capture(
        tester,
        'minimum-confirmed',
        'Confirm Jan 1 1900 → accepted as draft, no observation saved',
      );
      await tap(tester, find.byTooltip('关闭记录'));
      await capture(
        tester,
        'minimum-discard',
        'Close minimum-date draft → discard confirmation',
      );
      await tap(tester, find.text('离开'));
      expect(transport.records, isEmpty);
      await capture(
        tester,
        'no-birth-left',
        'Discard date-only draft → Baby with no observations',
      );
      await tap(tester, find.text('More'));
      await capture(
        tester,
        'more-return',
        'Baby → More after date navigation; only isolated profile fixture changed',
        route: '/more',
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
}
