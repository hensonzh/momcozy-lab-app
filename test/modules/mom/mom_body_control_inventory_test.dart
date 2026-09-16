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
import 'package:momcozy_flutter_app/modules/mom/presentation/mother_diary_editor.dart';
import 'package:momcozy_flutter_app/modules/mom/presentation/mom_home_sections.dart';
import 'package:momcozy_flutter_app/modules/mom/presentation/diary_labels.dart';
import 'package:momcozy_flutter_app/shared/widgets/choice_field.dart';
import 'package:momcozy_flutter_app/domain/mother/mother_diary.dart';
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
        'test/goldens/ui_inventory/mom-body-control-$state-$variant.png';
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/ui_inventory/mom-body-control-$state-$variant.png',
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
      'test': 'test/modules/mom/mom_body_control_inventory_test.dart',
    };
    previous = source;
    final output = Platform.environment['MOMCOZY_UI_INVENTORY_DIR'];
    if (output != null) {
      final file = File(
        '$output/journeys/mom-body-control-$state-$variant.json',
      );
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(row)}\n',
      );
    }
  }

  Finder field<T extends Enum>(String title) => find.byWidgetPredicate(
    (widget) => widget is ChoiceField<T> && widget.title == title,
    description: 'Body choice field: $title',
  );

  Future<void> choose<T extends Enum>(
    WidgetTester tester,
    String title,
    MapEntry<T, String> option,
  ) async {
    await tap(
      tester,
      find.descendant(of: field<T>(title), matching: find.text(option.value)),
    );
    expect(
      tester.widget<ChoiceField<T>>(field<T>(title)).selected,
      contains(option.key),
    );
  }

  Future<void> exercise<T extends Enum>(
    WidgetTester tester,
    String slug,
    String title,
    Map<T, String> options, {
    required bool exhaustive,
  }) async {
    for (final option
        in exhaustive ? options.entries : [options.entries.last]) {
      await choose(tester, title, option);
      await capture(
        tester,
        '$slug-${option.key.name}',
        'Body / $title → select ${option.value}',
      );
    }
  }

  Future<void> clearChoice<T extends Enum>(
    WidgetTester tester,
    String title,
    MapEntry<T, String> option,
  ) async {
    await tap(
      tester,
      find.descendant(of: field<T>(title), matching: find.text(option.value)),
    );
    expect(
      tester.widget<ChoiceField<T>>(field<T>(title)).selected,
      isNot(contains(option.key)),
    );
  }

  MotherBody currentBody(WidgetTester tester) => tester
      .widget<MotherDiaryEditor>(find.byType(MotherDiaryEditor))
      .controller
      .draft
      .body;

  for (final narrow in [false, true]) {
    testWidgets(
      'inventory Mom body controls ${narrow ? '320/2x' : '393/1x all options'}',
      (tester) async {
        await mount(tester, width: narrow ? 320 : 393, scale: narrow ? 2 : 1);
        await capture(tester, 'home-entry', 'More → Me → initial home');
        await tap(tester, find.text('身体与精力'));
        await capture(
          tester,
          'empty',
          'Home Body card → empty quick body editor',
        );
        await exercise(
          tester,
          'energy',
          '今天身体的电量',
          energyLabels,
          exhaustive: !narrow,
        );
        await clearChoice(tester, '今天身体的电量', energyLabels.entries.last);
        expect(currentBody(tester).energy, isNull);
        await capture(
          tester,
          'energy-cleared',
          'Tap selected energy again → cleared',
        );
        await choose(tester, '今天身体的电量', energyLabels.entries.first);
        await capture(
          tester,
          'energy-restored',
          'Choose energized after clearing',
        );
        await exercise(
          tester,
          'site',
          '今天哪里最需要照顾？',
          siteLabels,
          exhaustive: !narrow,
        );
        await exercise(
          tester,
          'severity',
          '这种不适有多难受？',
          severityLabels,
          exhaustive: !narrow,
        );
        await clearChoice(tester, '这种不适有多难受？', severityLabels.entries.last);
        await capture(
          tester,
          'severity-cleared',
          'Tap selected severity again → cleared',
        );
        await choose(tester, '这种不适有多难受？', severityLabels.entries.last);
        await capture(
          tester,
          'severity-restored',
          'Restore discomfort severity',
        );
        await exercise(
          tester,
          'impact',
          '这种不适影响到你了吗？',
          bodyImpactLabels,
          exhaustive: !narrow,
        );
        await clearChoice(tester, '这种不适影响到你了吗？', bodyImpactLabels.entries.last);
        await capture(
          tester,
          'impact-cleared',
          'Tap selected discomfort impact again → cleared',
        );
        await choose(tester, '这种不适影响到你了吗？', bodyImpactLabels.entries.last);
        await capture(tester, 'impact-restored', 'Restore discomfort impact');
        for (final option
            in narrow ? [siteLabels.entries.last] : siteLabels.entries) {
          await clearChoice(tester, '今天哪里最需要照顾？', option);
          await capture(
            tester,
            'site-clear-${option.key.name}',
            'Deselect discomfort site ${option.value}',
          );
        }
        expect(currentBody(tester).discomfortSites, isEmpty);
        expect(currentBody(tester).severity, isNull);
        expect(currentBody(tester).impact, isNull);
        expect(field('这种不适有多难受？'), findsNothing);
        expect(field('这种不适影响到你了吗？'), findsNothing);
        await choose(tester, '今天哪里最需要照顾？', siteLabels.entries.first);
        expect(
          tester.widget<ChoiceField>(field('这种不适有多难受？')).selected,
          isEmpty,
        );
        expect(
          tester.widget<ChoiceField>(field('这种不适影响到你了吗？')).selected,
          isEmpty,
        );
        await capture(
          tester,
          'site-restored-dependent-empty',
          'Reselect first discomfort site → dependent severity and impact return empty',
        );
        await choose(tester, '这种不适有多难受？', severityLabels.entries.first);
        await choose(tester, '这种不适影响到你了吗？', bodyImpactLabels.entries.first);
        await capture(
          tester,
          'dependent-refilled',
          'Fill returned severity and impact',
        );
        await exercise(
          tester,
          'trend',
          '和昨天相比，身体感觉',
          trendLabels,
          exhaustive: !narrow,
        );
        await clearChoice(tester, '和昨天相比，身体感觉', trendLabels.entries.last);
        await capture(
          tester,
          'trend-cleared',
          'Tap selected body trend again → cleared',
        );
        await choose(tester, '和昨天相比，身体感觉', trendLabels.entries.first);
        await capture(
          tester,
          'trend-restored',
          'Select better trend after clearing',
        );
        await tap(tester, find.text('如厕与盆底'));
        await capture(
          tester,
          'optional-open',
          'Expand toileting and pelvic floor options',
        );
        await exercise(
          tester,
          'urination',
          '排尿',
          urinationLabels,
          exhaustive: !narrow,
        );
        await clearChoice(tester, '排尿', urinationLabels.entries.last);
        await capture(
          tester,
          'urination-cleared',
          'Tap selected urination again → cleared',
        );
        await choose(tester, '排尿', urinationLabels.entries.first);
        await capture(
          tester,
          'urination-restored',
          'Select normal urination after clearing',
        );
        await exercise(tester, 'bowel', '排便', bowelLabels, exhaustive: !narrow);
        await clearChoice(tester, '排便', bowelLabels.entries.last);
        await capture(
          tester,
          'bowel-cleared',
          'Tap selected bowel again → cleared',
        );
        await choose(tester, '排便', bowelLabels.entries.first);
        await capture(
          tester,
          'bowel-restored',
          'Select smooth bowel after clearing',
        );
        await tap(tester, find.text('如厕与盆底'));
        await capture(
          tester,
          'optional-collapsed',
          'Collapse filled toileting options',
        );
        final note = find.byType(TextFormField);
        await tap(tester, note);
        await tester.enterText(note, '今天休息后身体轻松了一些。');
        await tester.pumpAndSettle();
        await capture(
          tester,
          'note-entered',
          'Enter body note → visible value and character count',
        );
        await tester.enterText(note, '');
        await tester.pumpAndSettle();
        expect(currentBody(tester).note, isEmpty);
        await capture(
          tester,
          'note-cleared',
          'Clear body note → empty value and character count',
        );
        await tester.enterText(note, '测试记录：休息后感觉轻松。');
        await tester.pumpAndSettle();
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await capture(
          tester,
          'note-restored',
          'Enter final body note and leave input',
        );
        expect(transport.diaries, isEmpty);
        await tap(tester, find.text('保存今天的记录'));
        expect(find.text('今天的记录已保存'), findsOneWidget);
        expect(transport.diaries, hasLength(1));
        await capture(
          tester,
          'saved',
          'Save body through production repository → success feedback',
        );
        await tap(tester, find.byTooltip('关闭记录'));
        await capture(
          tester,
          'home-refreshed',
          'Close saved body editor → home displays updated body summary',
        );
        await tester.scrollUntilVisible(
          find.byType(MomLactationCard),
          -220,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(find.byType(MomLactationCard));
        await tester.pumpAndSettle();
        await capture(
          tester,
          'home-unrecorded-lactation-visible',
          'Scroll refreshed home to unrecorded lactation card after saving body data',
        );
        await tap(tester, find.text('身体与精力'));
        expect(currentBody(tester).energy, energyLabels.keys.first);
        expect(currentBody(tester).discomfortSites, {siteLabels.keys.first});
        expect(currentBody(tester).severity, severityLabels.keys.first);
        expect(currentBody(tester).impact, bodyImpactLabels.keys.first);
        expect(currentBody(tester).trend, trendLabels.keys.first);
        expect(currentBody(tester).urination, urinationLabels.keys.first);
        expect(currentBody(tester).bowel, bowelLabels.keys.first);
        expect(currentBody(tester).note, '测试记录：休息后感觉轻松。');
        await capture(
          tester,
          'reopened',
          'Reopen Body → assert all saved values',
        );
        await tap(tester, find.text('如厕与盆底'));
        await capture(
          tester,
          'reopened-optional',
          'Expand persisted toileting values',
        );
        await tap(tester, find.byTooltip('关闭记录'));
        await capture(
          tester,
          'home-return',
          'Close unchanged record without discard prompt → home',
        );
        await tap(tester, find.text('More'));
        await capture(
          tester,
          'more-return',
          'Bottom More → original tab',
          route: '/more',
        );
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
