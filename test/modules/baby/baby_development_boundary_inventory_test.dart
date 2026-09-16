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
        'test/goldens/ui_inventory/baby-development-boundaries-$state-$variant.png';
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/ui_inventory/baby-development-boundaries-$state-$variant.png',
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
      'test': 'test/modules/baby/baby_development_boundary_inventory_test.dart',
    };
    previous = source;
    final output = Platform.environment['MOMCOZY_UI_INVENTORY_DIR'];
    if (output != null) {
      final file = File(
        '$output/journeys/baby-development-boundaries-$state-$variant.json',
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
    testWidgets('inventory development boundaries ${narrow ? '320/2x' : '393/1x'}', (
      tester,
    ) async {
      await mount(tester, width: narrow ? 320 : 393, scale: narrow ? 2 : 1);
      await capture(
        tester,
        'home-entry',
        'More → Baby before date and save boundaries',
      );
      await tap(tester, find.text('记录发育观察'));
      final firstGroup = find.byWidgetPredicate(
        (w) =>
            w is ChoiceField &&
            w.title == babyDevelopmentItems['looks-at-face'],
      );
      await tap(
        tester,
        find.descendant(of: firstGroup, matching: find.text('观察到')),
      );
      await capture(
        tester,
        'one-selected',
        'Choose observed for one behavior only',
      );
      await tap(tester, find.text('2026-09-13'));
      final date = find.byType(DatePickerDialog);
      final strings = MaterialLocalizations.of(tester.element(date));
      Finder button(String label) =>
          find.descendant(of: date, matching: find.text(label));
      await capture(
        tester,
        'date-open',
        'Open observation date: birth 8/22 through today 9/13',
      );
      if (find
          .byTooltip(strings.inputDateModeButtonLabel)
          .evaluate()
          .isNotEmpty) {
        await tap(tester, find.byTooltip(strings.inputDateModeButtonLabel));
      }
      for (final (name, value, error) in [
        ('format', 'invalid', strings.invalidDateFormatLabel),
        (
          'before-birth',
          strings.formatCompactDate(DateTime(2026, 8, 21)),
          strings.dateOutOfRangeLabel,
        ),
        (
          'future',
          strings.formatCompactDate(DateTime(2026, 9, 14)),
          strings.dateOutOfRangeLabel,
        ),
      ]) {
        await tester.enterText(
          find.descendant(of: date, matching: find.byType(TextFormField)),
          value,
        );
        FocusManager.instance.primaryFocus?.unfocus();
        await tap(tester, button(strings.okButtonLabel));
        expect(date, findsOneWidget);
        expect(find.text(error), findsOneWidget);
        expect(editor(tester).recordedOn.toString(), '2026-09-13');
        expect(transport.records, isEmpty);
        await capture(
          tester,
          'date-$name-rejected',
          'Submit $name date → picker validation, draft date unchanged',
        );
      }
      await tester.enterText(
        find.descendant(of: date, matching: find.byType(TextFormField)),
        strings.formatCompactDate(DateTime(2026, 8, 22)),
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tap(tester, button(strings.okButtonLabel));
      expect(editor(tester).recordedOn.toString(), '2026-08-22');
      await capture(
        tester,
        'birth-selected',
        'Confirm birth date → earliest valid observation date',
      );
      await tap(tester, find.text('2026-08-22'));
      if (find
          .byTooltip(strings.calendarModeButtonLabel)
          .evaluate()
          .isNotEmpty) {
        await tap(tester, find.byTooltip(strings.calendarModeButtonLabel));
      }
      if (narrow) {
        expect(
          tester.widget<DatePickerDialog>(date).initialEntryMode,
          DatePickerEntryMode.inputOnly,
        );
        await capture(
          tester,
          'birth-input-only',
          'Reopen birth date at large text → input-only picker without month navigation',
        );
      } else {
        await capture(
          tester,
          'birth-calendar',
          'Reopen birth date and switch to calendar',
        );
        await tap(tester, find.byTooltip(strings.nextMonthTooltip));
        await capture(tester, 'next-month', 'Next month → September calendar');
        await tap(tester, find.byTooltip(strings.previousMonthTooltip));
        await capture(
          tester,
          'previous-month',
          'Previous month → August calendar',
        );
      }
      await tap(tester, button(strings.cancelButtonLabel));
      expect(editor(tester).recordedOn.toString(), '2026-08-22');
      await capture(
        tester,
        'calendar-cancel',
        'Cancel month browsing → birth date and choice retained',
      );
      transport.writeGate = Completer<void>();
      await tester.ensureVisible(find.byKey(const ValueKey('baby-save')));
      await tester.tap(find.byKey(const ValueKey('baby-save')));
      await tester.pump();
      expect(editor(tester).busy, isTrue);
      await capture(
        tester,
        'save-pending',
        'Save single observation → request pending',
      );
      await tester.tap(find.byTooltip('关闭记录'), warnIfMissed: false);
      await tester.pump();
      expect(editor(tester).busy, isTrue);
      await capture(
        tester,
        'pending-close-blocked',
        'Tap disabled close → saving editor remains',
      );
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(editor(tester).busy, isTrue);
      expect(find.text('离开这次记录？'), findsNothing);
      await capture(
        tester,
        'pending-back-blocked',
        'Platform Back during save → editor remains without discard dialog',
      );
      transport.writeGate!.complete();
      await tester.pumpAndSettle();
      expect(transport.records, hasLength(1));
      final observation = transport.records.single['observation'] as Map;
      expect(observation['item_id'], 'looks-at-face');
      expect(observation['recorded_on'], '2026-08-22');
      await capture(
        tester,
        'single-saved',
        'Response acknowledged → exactly one observation on birth date',
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tap(tester, find.text('记录发育观察'));
      expect(editor(tester).development, isEmpty);
      await tap(
        tester,
        find.descendant(of: firstGroup, matching: find.text('不确定')),
      );
      transport.writeGate = null;
      transport.failWrite = true;
      await tap(tester, find.byKey(const ValueKey('baby-save')));
      expect(editor(tester).uncertain, isTrue);
      expect(transport.records, hasLength(1));
      await capture(
        tester,
        'save-unconfirmed',
        'Second draft save fails 503 → unconfirmed result',
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('离开'), findsOneWidget);
      await capture(
        tester,
        'unconfirmed-back-confirm',
        'Platform Back on unconfirmed save → uncertainty discard confirmation',
      );
      await tap(tester, find.text('离开'));
      expect(find.byType(BabyRecordEditor), findsNothing);
      expect(transport.records, hasLength(1));
      await capture(
        tester,
        'unconfirmed-left',
        'Choose leave → Baby without acknowledged second write',
      );
      transport.failWrite = false;
      await tap(tester, find.text('记录发育观察'));
      expect(editor(tester).development, isEmpty);
      expect(editor(tester).uncertain, isFalse);
      expect(editor(tester).recordedOn.toString(), '2026-09-13');
      await capture(
        tester,
        'reopened-clean',
        'Reopen after unconfirmed leave → fresh empty editable draft dated today',
      );
      await tap(tester, find.byTooltip('关闭记录'));
      await tap(tester, find.text('More'));
      await capture(
        tester,
        'more-return',
        'Close unchanged editor → More',
        route: '/more',
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
}
