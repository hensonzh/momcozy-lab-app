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
        'test/goldens/ui_inventory/mom-mood-control-$state-$variant.png';
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/ui_inventory/mom-mood-control-$state-$variant.png',
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
      'test': 'test/modules/mom/mom_mood_control_inventory_test.dart',
    };
    previous = source;
    final output = Platform.environment['MOMCOZY_UI_INVENTORY_DIR'];
    if (output != null) {
      final file = File(
        '$output/journeys/mom-mood-control-$state-$variant.json',
      );
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(row)}\n',
      );
    }
  }

  Finder field<T extends Enum>(String title) => find.byWidgetPredicate(
    (widget) => widget is ChoiceField<T> && widget.title == title,
    description: 'Mood choice field: $title',
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
        'Mood / $title → select ${option.value}',
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

  MotherMood currentMood(WidgetTester tester) => tester
      .widget<MotherDiaryEditor>(find.byType(MotherDiaryEditor))
      .controller
      .draft
      .mood;

  for (final narrow in [false, true]) {
    testWidgets(
      'inventory Mom mood controls ${narrow ? '320/2x' : '393/1x all options'}',
      (tester) async {
        await mount(tester, width: narrow ? 320 : 393, scale: narrow ? 2 : 1);
        await capture(tester, 'home-entry', 'More → Me → initial home');
        const quickOptions = {
          '不太好': MoodTone.low,
          '一般': MoodTone.unclear,
          '不错': MoodTone.steady,
        };
        for (final quick
            in narrow ? [quickOptions.entries.last] : quickOptions.entries) {
          await tap(tester, find.text(quick.key));
          expect(currentMood(tester).tone, quick.value);
          expect(transport.diaries, isEmpty);
          await capture(
            tester,
            'quick-${quick.value.name}',
            'Home quick mood ${quick.key} → prefilled draft without save',
          );
          await tap(tester, find.byTooltip('关闭记录'));
          await capture(
            tester,
            'quick-${quick.value.name}-discard-confirm',
            'Close quick ${quick.key} draft → discard confirmation',
          );
          await tap(tester, find.text('放弃修改'));
          expect(transport.diaries, isEmpty);
          await capture(
            tester,
            'quick-${quick.value.name}-discarded',
            'Discard quick ${quick.key} draft → home remains unrecorded',
          );
        }
        await tap(tester, find.text('今日心情'));
        await capture(
          tester,
          'empty',
          'Home Mood title → empty editor without preset',
        );
        await exercise(
          tester,
          'tone',
          '今天心里更接近哪一种',
          toneLabels,
          exhaustive: !narrow,
        );
        await clearChoice(tester, '今天心里更接近哪一种', toneLabels.entries.last);
        expect(currentMood(tester).tone, isNull);
        await capture(
          tester,
          'tone-cleared',
          'Tap selected mood tone again → no tone selected',
        );
        await choose(tester, '今天心里更接近哪一种', toneLabels.entries.first);
        await capture(
          tester,
          'tone-restored',
          'Choose steady mood after clearing',
        );
        await exercise(
          tester,
          'pressure',
          '什么一直占据着你的心？',
          pressureLabels,
          exhaustive: !narrow,
        );
        expect(currentMood(tester).pressures, {MoodPressure.unclear});
        await clearChoice(tester, '什么一直占据着你的心？', pressureLabels.entries.last);
        expect(currentMood(tester).pressures, isEmpty);
        await capture(
          tester,
          'pressure-exclusive-cleared',
          'Tap selected unclear pressure → empty pressure set',
        );
        await choose(tester, '什么一直占据着你的心？', pressureLabels.entries.last);
        await capture(
          tester,
          'pressure-exclusive-restored',
          'Restore exclusive unclear pressure',
        );
        await choose(tester, '什么一直占据着你的心？', pressureLabels.entries.first);
        expect(currentMood(tester).pressures, {pressureLabels.keys.first});
        await capture(
          tester,
          'pressure-exclusive-to-ordinary',
          'Select baby worry while unclear is selected → unclear removed',
        );
        final ordinary = pressureLabels.entries
            .where((e) => e.key != MoodPressure.unclear)
            .toList();
        if (!narrow) {
          for (final option in ordinary.skip(1)) {
            await choose(tester, '什么一直占据着你的心？', option);
            expect(
              currentMood(tester).pressures,
              isNot(contains(MoodPressure.unclear)),
            );
            await capture(
              tester,
              'pressure-refill-${option.key.name}',
              'Add ordinary pressure ${option.value} after exclusive transition',
            );
          }
          expect(
            currentMood(tester).pressures,
            ordinary.map((e) => e.key).toSet(),
          );
        }
        for (final option in narrow ? [ordinary.first] : ordinary) {
          await clearChoice(tester, '什么一直占据着你的心？', option);
          await capture(
            tester,
            'pressure-clear-${option.key.name}',
            'Deselect ordinary pressure ${option.value}',
          );
        }
        expect(currentMood(tester).pressures, isEmpty);
        await choose(tester, '什么一直占据着你的心？', ordinary.first);
        await capture(
          tester,
          'pressure-restored',
          'Choose baby worry after clearing all pressures',
        );
        await exercise(
          tester,
          'impact',
          '这份难受影响到你了吗？',
          moodImpactLabels,
          exhaustive: !narrow,
        );
        await clearChoice(tester, '这份难受影响到你了吗？', moodImpactLabels.entries.last);
        expect(currentMood(tester).impact, isNull);
        await capture(
          tester,
          'impact-cleared',
          'Tap selected mood impact → cleared',
        );
        await choose(tester, '这份难受影响到你了吗？', moodImpactLabels.entries.first);
        await capture(tester, 'impact-restored', 'Restore no impact');
        await exercise(
          tester,
          'support',
          '今天有人接住你吗？',
          supportLabels,
          exhaustive: !narrow,
        );
        await clearChoice(tester, '今天有人接住你吗？', supportLabels.entries.last);
        expect(currentMood(tester).support, isNull);
        await capture(
          tester,
          'support-cleared',
          'Tap selected support → cleared',
        );
        await choose(tester, '今天有人接住你吗？', supportLabels.entries.first);
        await capture(tester, 'support-restored', 'Restore supported');
        expect(transport.diaries, isEmpty);
        await tap(tester, find.text('保存今天的记录'));
        expect(transport.diaries, hasLength(1));
        expect(find.text('今天的记录已保存'), findsOneWidget);
        await capture(
          tester,
          'saved',
          'Save mood record through production repository → success feedback',
        );
        await tap(tester, find.byTooltip('关闭记录'));
        await capture(
          tester,
          'home-refreshed',
          'Close saved mood → refreshed home with steady mood',
        );
        await tap(tester, find.text('今日心情'));
        expect(currentMood(tester).tone, MoodTone.steady);
        expect(currentMood(tester).pressures, {MoodPressure.babyWorry});
        expect(currentMood(tester).impact, MoodImpact.none);
        expect(currentMood(tester).support, MoodSupport.supported);
        await capture(
          tester,
          'reopened',
          'Reopen mood by title → all four saved groups preserved',
        );
        await clearChoice(tester, '今天心里更接近哪一种', toneLabels.entries.first);
        await capture(
          tester,
          'saved-tone-cleared',
          'Clear saved mood tone in draft',
        );
        await clearChoice(tester, '什么一直占据着你的心？', ordinary.first);
        await capture(
          tester,
          'saved-pressure-cleared',
          'Clear saved pressure in draft',
        );
        await clearChoice(
          tester,
          '这份难受影响到你了吗？',
          moodImpactLabels.entries.first,
        );
        await capture(
          tester,
          'saved-impact-cleared',
          'Clear saved impact in draft',
        );
        await clearChoice(tester, '今天有人接住你吗？', supportLabels.entries.first);
        expect(currentMood(tester).isEmpty, isTrue);
        await capture(
          tester,
          'saved-all-cleared',
          'Clear last saved field → empty draft, persisted record remains',
        );
        await tap(tester, find.text('保存今天的记录'));
        expect(find.text('先记录一项今天的状态，再保存。'), findsOneWidget);
        expect(transport.diaries.values.single['version'], 1);
        await capture(
          tester,
          'empty-replacement-validation',
          'Attempt to save emptied existing diary → validation; saved version unchanged',
        );
        await tap(tester, find.byTooltip('关闭记录'));
        await capture(
          tester,
          'empty-replacement-discard-confirm',
          'Close cleared existing diary → discard confirmation',
        );
        await tap(tester, find.text('放弃修改'));
        await capture(
          tester,
          'home-retained',
          'Discard empty draft → home retains saved mood',
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
