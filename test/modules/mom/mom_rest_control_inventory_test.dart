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
import 'package:momcozy_flutter_app/modules/mom/presentation/diary_labels.dart';
import 'package:momcozy_flutter_app/shared/widgets/choice_field.dart';
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
        'test/goldens/ui_inventory/mom-rest-control-$state-$variant.png';
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/ui_inventory/mom-rest-control-$state-$variant.png',
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
      'test': 'test/modules/mom/mom_rest_control_inventory_test.dart',
    };
    previous = source;
    final output = Platform.environment['MOMCOZY_UI_INVENTORY_DIR'];
    if (output != null) {
      final file = File(
        '$output/journeys/mom-rest-control-$state-$variant.json',
      );
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(row)}\n',
      );
    }
  }

  Finder field<T extends Enum>(String title) => find.byWidgetPredicate(
    (widget) => widget is ChoiceField<T> && widget.title == title,
    description: 'Rest choice field: $title',
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
        'Rest / $title → select ${option.value}',
      );
    }
  }

  for (final narrow in [false, true]) {
    testWidgets(
      'inventory Mom rest controls ${narrow ? '320/2x' : '393/1x all options'}',
      (tester) async {
        await mount(tester, width: narrow ? 320 : 393, scale: narrow ? 2 : 1);
        await capture(tester, 'home-entry', 'More → Me → initial home');
        await tap(tester, find.text('昨夜休息'));
        await capture(
          tester,
          'empty',
          'Home Rest card → empty quick rest editor',
        );
        await exercise(
          tester,
          'duration',
          '昨夜大约睡了多久',
          sleepTotalLabels,
          exhaustive: !narrow,
        );
        await exercise(
          tester,
          'interruptions',
          '夜里大约被打断几次',
          interruptionsLabels,
          exhaustive: !narrow,
        );
        await exercise(
          tester,
          'recovery',
          '今天醒来时感觉怎样',
          recoveryLabels,
          exhaustive: !narrow,
        );
        await tap(tester, find.text('补充休息情况'));
        await capture(tester, 'optional-open', 'Expand rest optional fields');
        await exercise(
          tester,
          'stretch',
          '最长一段完整休息',
          stretchLabels,
          exhaustive: !narrow,
        );
        await exercise(
          tester,
          'day-rest',
          '今天有没有一段不被打扰的休息',
          dayRestLabels,
          exhaustive: !narrow,
        );
        await exercise(
          tester,
          'resleep',
          '醒来后容易再睡着吗',
          resleepLabels,
          exhaustive: !narrow,
        );
        await exercise(
          tester,
          'disruption',
          '影响休息的原因',
          disruptionLabels,
          exhaustive: !narrow,
        );
        for (final option
            in narrow
                ? [disruptionLabels.entries.last]
                : disruptionLabels.entries) {
          final title = '影响休息的原因';
          await tap(
            tester,
            find.descendant(
              of: field(title),
              matching: find.text(option.value),
            ),
          );
          expect(
            tester.widget<ChoiceField>(field(title)).selected,
            isNot(contains(option.key)),
          );
          await capture(
            tester,
            'disruption-clear-${option.key.name}',
            'Deselect rest disruption ${option.value}',
          );
        }
        expect(tester.widget<ChoiceField>(field('影响休息的原因')).selected, isEmpty);
        await choose(tester, '影响休息的原因', disruptionLabels.entries.first);
        await capture(
          tester,
          'disruption-restored',
          'Select feeding disruption after clearing all',
        );
        await tap(
          tester,
          find.descendant(
            of: field('昨夜大约睡了多久'),
            matching: find.text(sleepTotalLabels.values.last),
          ),
        );
        expect(tester.widget<ChoiceField>(field('昨夜大约睡了多久')).selected, isEmpty);
        await capture(
          tester,
          'duration-cleared',
          'Tap selected sleep duration again → no duration selected',
        );
        await choose(tester, '昨夜大约睡了多久', sleepTotalLabels.entries.elementAt(1));
        await capture(
          tester,
          'duration-restored',
          'Select 3–4 hours after clearing duration',
        );
        await tap(tester, find.text('补充休息情况'));
        await capture(
          tester,
          'optional-collapsed',
          'Collapse filled optional rest fields → filled indicator retained',
        );
        expect(transport.diaries, isEmpty);
        await tap(tester, find.text('保存今天的记录'));
        expect(find.text('今天的记录已保存'), findsOneWidget);
        expect(transport.diaries, hasLength(1));
        final editor = tester.widget<MotherDiaryEditor>(
          find.byType(MotherDiaryEditor),
        );
        expect(editor.controller.draft.rest.disruptions, {
          disruptionLabels.keys.first,
        });
        expect(
          editor.controller.draft.rest.total,
          sleepTotalLabels.keys.elementAt(1),
        );
        await capture(
          tester,
          'saved',
          'Save complete rest record through production repository → saved feedback',
        );
        await tap(tester, find.byTooltip('关闭记录'));
        await capture(
          tester,
          'home-refreshed',
          'Close saved rest editor → home shows 3–4 hours and one completed group',
        );
        expect(find.text('3–4 小时'), findsOneWidget);
        if (find.textContaining('今日完成 1/3').evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            find.textContaining('今日完成 1/3'),
            -180,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
        }
        expect(find.textContaining('今日完成 1/3'), findsOneWidget);
        await tap(tester, find.text('昨夜休息'));
        await capture(
          tester,
          'reopened',
          'Home Rest card → persisted rest record reopened',
        );
        await tap(tester, find.text('补充休息情况'));
        await capture(
          tester,
          'reopened-optional',
          'Expand persisted optional rest values',
        );
        expect(tester.widget<ChoiceField>(field('影响休息的原因')).selected, {
          disruptionLabels.keys.first,
        });
        await tap(tester, find.byTooltip('关闭记录'));
        await capture(
          tester,
          'home-return',
          'Close unchanged rest record → home without discard prompt',
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
