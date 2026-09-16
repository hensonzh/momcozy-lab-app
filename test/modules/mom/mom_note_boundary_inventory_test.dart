import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/native/p0_platform_interfaces.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/modules/mom/presentation/lactation_panel.dart';
import 'package:momcozy_flutter_app/modules/mom/presentation/mom_home_sections.dart';
import 'package:momcozy_flutter_app/modules/mom/application/lactation_controller.dart';
import 'package:momcozy_flutter_app/modules/mom/presentation/mother_diary_editor.dart';
import '../../support/mom_inventory_transport.dart';
import '../../support/fixture_api_transport.dart';
import '../../support/fake_agent_voice.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);
  late MomInventoryTransport transport;
  late MomCozyRuntimeController runtime;
  late GoRouter router;
  String? previous;
  late String variant;
  Future<void> mount(
    WidgetTester tester, {
    void Function(MomInventoryTransport)? prepare,
    bool loading = false,
    double width = 393,
    double scale = 1,
  }) async {
    previous = null;
    FlutterSecureStorage.setMockInitialValues({});
    tester.view.physicalSize = Size(width, 844);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    variant = '${width.toInt()}-${scale.toInt()}x';
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    transport = MomInventoryTransport();
    prepare?.call(transport);
    const session = MomCozySession(
      status: MomCozySessionStatus.authenticated,
      userId: 'inventory-user',
      babyId: 'inventory-baby',
      locale: 'zh-CN',
      accessToken: 'fixture-access',
      refreshToken: 'fixture-refresh',
    );
    runtime = MomCozyRuntimeController(
      MomCozyApiRuntime(
        jsonTransport: transport,
        multipartTransport: FixtureApiMultipartTransport({}),
        agentVoicePlaybackPlayer: ImmediateAgentVoicePlaybackPlayer(),
        session: session,
        supportsSessionAutoRefresh: false,
        now: () => inventoryMomNow,
        timezoneProvider: () async => 'Asia/Shanghai',
      ),
    );
    final store = MemoryMomCozySessionStore(session);
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
        'assets/images/mom_home/cozymate_avatar.png',
        'assets/images/mom_home/expert_group.png',
        'assets/images/mom/milk-hero.png',
      ]) {
        await precacheImage(
          AssetImage(asset),
          tester.element(find.byType(MaterialApp)),
        );
      }
    });
    await tester.tap(find.text('Me'));
    if (loading) {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    } else {
      await tester.pumpAndSettle();
    }
    expect(router.state.uri.path, '/me');
    addTearDown(() async {
      for (final gate in transport.readGates.values) {
        if (!gate.isCompleted) gate.complete();
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
        scrollable: find.byType(Scrollable).last,
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
    String route = '/me',
  }) async {
    // Commit edits and finish the input hint's fade without settling spinners.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(router.state.uri.path, route);
    expect(tester.takeException(), isNull);
    final source =
        'test/goldens/ui_inventory/mom-note-boundary-$state-$variant.png';
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/ui_inventory/mom-note-boundary-$state-$variant.png',
      ),
    );
    final row = {
      'source': source,
      'previous_source': previous,
      'route': route,
      'trigger': action,
      'root_entry': 'Authenticated More → tap Me bottom navigation',
      'evidence':
          'Actual MomCozyFlutterApp/createMomCozyRouter, production repositories and codecs, isolated in-memory HTTP data, fixed clock and timezone',
      'test': 'test/modules/mom/mom_note_boundary_inventory_test.dart',
    };
    previous = source;
    final output = Platform.environment['MOMCOZY_UI_INVENTORY_DIR'];
    if (output != null) {
      if (Platform.environment['MOMCOZY_UI_INVENTORY_LONG'] == '1' &&
          (state.endsWith('note-scroll-start') ||
              state.endsWith('note-scroll-end'))) {
        final metadata =
            jsonDecode(File('$output/$source.json').readAsStringSync())
                as Map<String, dynamic>;
        final long = metadata['long_capture'] as Map<String, dynamic>;
        expect(long['status'], 'complete-measured-scroll-stitch');
        expect(long['nested_editable_contents_expanded'], false);
        expect(long['nested_editable_scrolls'], hasLength(1));
      }
      final file = File(
        '$output/journeys/mom-note-boundary-$state-$variant.json',
      );
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(row)}\n',
      );
    }
  }

  Future<void> closePanel(WidgetTester tester) async {
    final close = find.byTooltip('关闭泌乳记录');
    if (close.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        close,
        -250,
        scrollable: find
            .descendant(
              of: find.byType(LactationPanel),
              matching: find.byType(Scrollable),
            )
            .first,
      );
    }
    await tap(tester, close);
  }

  LactationDraft draft(WidgetTester tester) => tester
      .widget<LactationPanel>(find.byType(LactationPanel))
      .controller
      .draft!;
  Future<void> input(WidgetTester tester, Finder target, String text) async {
    await tester.ensureVisible(target);
    await tester.enterText(target, text);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
  }

  String bodyNote(WidgetTester tester) => tester
      .widget<MotherDiaryEditor>(find.byType(MotherDiaryEditor))
      .controller
      .draft
      .body
      .note;
  String fieldValue(WidgetTester tester, Finder field) => tester
      .widget<EditableText>(
        find.descendant(of: field, matching: find.byType(EditableText)),
      )
      .controller
      .text;

  Future<void> scrollNote(
    WidgetTester tester,
    Finder field, {
    required bool toEnd,
  }) async {
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    final scroll = find.descendant(
      of: field,
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(scroll).position;
    expect(position.maxScrollExtent, greaterThan(0));
    await tester.drag(
      scroll,
      Offset(0, (position.maxScrollExtent + 500) * (toEnd ? -1 : 1)),
    );
    await tester.pumpAndSettle();
    expect(
      position.pixels,
      closeTo(toEnd ? position.maxScrollExtent : position.minScrollExtent, .5),
    );
  }

  for (final narrow in [false, true]) {
    testWidgets('inventory note boundaries ${narrow ? '320/2x' : '393/1x'}', (
      tester,
    ) async {
      await mount(tester, width: narrow ? 320 : 393, scale: narrow ? 2 : 1);
      await capture(tester, 'home-entry', 'More → Me → initial home');
      await tap(tester, find.text('身体与精力'));
      final body = find.widgetWithText(TextFormField, '今天身体最想告诉你什么？');
      await tap(tester, body);
      await capture(
        tester,
        'body-empty',
        'Body editor → focus empty optional note',
      );
      final full = '开始${'记录' * 998}完成';
      await input(tester, body, full.substring(0, 1999));
      expect(bodyNote(tester).length, 1999);
      await capture(
        tester,
        'body-1999',
        'Enter body note one character below limit → 1999/2000',
      );
      await input(tester, body, full);
      expect(bodyNote(tester), full);
      await capture(
        tester,
        'body-2000',
        'Enter body note at limit → 2000/2000',
      );
      await input(tester, body, '$full超');
      expect(fieldValue(tester, body), full);
      expect(bodyNote(tester), full);
      await capture(
        tester,
        'body-overflow-truncated',
        'Attempt 2001 body characters → formatter retains first 2000',
      );
      await scrollNote(tester, body, toEnd: false);
      await capture(
        tester,
        'body-note-scroll-start',
        'Drag body note to start → 开始',
      );
      await scrollNote(tester, body, toEnd: true);
      await capture(
        tester,
        'body-note-scroll-end',
        'Drag body note to end → 完成',
      );
      expect(fieldValue(tester, body), full);
      expect(transport.diaries, isEmpty);
      await tap(tester, find.text('保存今天的记录'));
      expect(transport.diaries, hasLength(1));
      expect(find.text('今天的记录已保存'), findsOneWidget);
      await capture(
        tester,
        'body-saved',
        'Save body note at maximum → success feedback',
      );
      await tap(tester, find.byTooltip('关闭记录'));
      await capture(
        tester,
        'body-home',
        'Close saved body note → home counts 1/3; body headline remains 待记录',
      );
      await tap(tester, find.text('身体与精力'));
      await tap(tester, body);
      expect(bodyNote(tester), full);
      expect(fieldValue(tester, body), full);
      await capture(
        tester,
        'body-reopened',
        'Reopen saved body note → all 2000 characters retained',
      );
      await input(tester, body, '');
      expect(bodyNote(tester), isEmpty);
      await capture(
        tester,
        'body-cleared',
        'Clear saved body note in draft → 0/2000',
      );
      await tap(tester, find.byTooltip('关闭记录'));
      await capture(
        tester,
        'body-discard-confirm',
        'Close cleared body note → discard confirmation',
      );
      await tap(tester, find.text('放弃修改'));
      expect(transport.diaries.values.single['version'], 1);
      await capture(
        tester,
        'body-retained',
        'Discard cleared draft → saved body note remains',
      );
      if (find.byType(MomLactationCard).evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          find.byType(MomLactationCard),
          -250,
          scrollable: find.byType(Scrollable).first,
        );
      }
      await tap(
        tester,
        find.descendant(
          of: find.byType(MomLactationCard),
          matching: find.byType(FilledButton),
        ),
      );
      await tap(tester, find.text('补充感受与备注'));
      final milk = find.widgetWithText(TextFormField, '备注（可选）');
      await tap(tester, milk);
      await capture(
        tester,
        'milk-empty',
        'Open lactation optional note → empty',
      );
      await input(tester, milk, full.substring(0, 1999));
      expect(draft(tester).note.length, 1999);
      await capture(
        tester,
        'milk-1999',
        'Enter lactation note one character below limit → 1999/2000',
      );
      await input(tester, milk, full);
      expect(draft(tester).note, full);
      await capture(
        tester,
        'milk-2000',
        'Enter lactation note at limit → 2000/2000',
      );
      await input(tester, milk, '$full超');
      expect(fieldValue(tester, milk), full);
      expect(draft(tester).note, full);
      await capture(
        tester,
        'milk-overflow-truncated',
        'Attempt 2001 lactation characters → formatter retains first 2000',
      );
      await scrollNote(tester, milk, toEnd: false);
      await capture(
        tester,
        'milk-note-scroll-start',
        'Drag lactation note to start → 开始',
      );
      await scrollNote(tester, milk, toEnd: true);
      await capture(
        tester,
        'milk-note-scroll-end',
        'Drag lactation note to end → 完成',
      );
      expect(fieldValue(tester, milk), full);
      expect(transport.records, isEmpty);
      await tap(tester, find.text('保存这次记录'));
      expect(transport.records, hasLength(1));
      expect((transport.records.single['observation'] as Map)['note'], full);
      await capture(
        tester,
        'milk-saved-long-note',
        'Save maximum note without optional measurement → long record list',
      );
      await tap(
        tester,
        find.byKey(const ValueKey('lactation-edit-inventory-milk-1')),
      );
      expect(draft(tester).note, full);
      await tap(tester, milk);
      expect(fieldValue(tester, milk), full);
      await capture(
        tester,
        'milk-reopened',
        'Edit saved lactation → all 2000 characters retained',
      );
      await input(tester, milk, '');
      expect(draft(tester).note, isEmpty);
      await capture(
        tester,
        'milk-cleared',
        'Clear maximum lactation note in draft → 0/2000',
      );
      await tap(tester, find.text('取消'));
      await capture(
        tester,
        'milk-discard-confirm',
        'Cancel cleared lactation note → discard confirmation',
      );
      await tap(tester, find.text('离开'));
      expect(transport.records.single['version'], 1);
      await capture(
        tester,
        'milk-retained',
        'Discard cleared note → original long record remains',
      );
      await closePanel(tester);
      await capture(tester, 'home-return', 'Close lactation list → home');
      await tap(tester, find.text('More'));
      await capture(
        tester,
        'more-return',
        'Bottom More → original tab',
        route: '/more',
      );
      await tester.pumpWidget(const SizedBox());
    });
  }
}
