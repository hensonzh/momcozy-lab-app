import 'dart:async';
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
import 'package:momcozy_flutter_app/modules/mom/presentation/mom_home_sections.dart';
import 'package:momcozy_flutter_app/modules/services/presentation/expert_support_section.dart';
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
  Future<void> mount(
    WidgetTester tester, {
    void Function(MomInventoryTransport)? prepare,
    bool loading = false,
  }) async {
    previous = null;
    FlutterSecureStorage.setMockInitialValues({});
    tester.view.physicalSize = const Size(393, 844);
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
    final source = 'test/goldens/ui_inventory/mom-journey-$state-393.png';
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/ui_inventory/mom-journey-$state-393.png',
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
      'test': 'test/modules/mom/mom_inventory_journey_test.dart',
    };
    previous = source;
    final output = Platform.environment['MOMCOZY_UI_INVENTORY_DIR'];
    if (output != null) {
      final file = File('$output/journeys/mom-journey-$state.json');
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(row)}\n',
      );
    }
  }

  testWidgets(
    'inventory Mom lactation create edit delete restore and home refresh',
    (tester) async {
      await mount(tester);
      await capture(
        tester,
        'initial-home',
        'More → Me with no diary or milk records',
      );
      await tap(
        tester,
        find.descendant(
          of: find.byType(MomLactationCard),
          matching: find.byType(FilledButton),
        ),
      );
      await capture(
        tester,
        'milk-new-pump',
        'Home record lactation → new pump editor',
      );
      final measurement = find.byKey(
        const ValueKey('lactation-measurement-pump'),
      );
      await tester.enterText(measurement, '2001');
      await tap(tester, find.text('保存这次记录'));
      expect(transport.records, isEmpty);
      await capture(
        tester,
        'milk-invalid-volume',
        'Submit out of range pump volume → validation',
      );
      await tester.enterText(measurement, '80');
      await tap(tester, find.text('右侧'));
      await capture(tester, 'milk-filled', 'Enter 80 ml and select right side');
      transport.failWrite = true;
      await tap(tester, find.text('保存这次记录'));
      expect(find.text('保存结果还未确认，请重试这次保存。'), findsOneWidget);
      await capture(
        tester,
        'milk-save-error',
        'Save → HTTP failure, draft locked pending retry',
      );
      transport.failWrite = false;
      await tap(tester, find.text('重试保存'));
      expect(transport.records, hasLength(1));
      expect(find.text('这次记录已保存。'), findsOneWidget);
      await capture(
        tester,
        'milk-modal-saved',
        'Retry save → actual record list and saved feedback',
      );
      await tap(tester, find.byTooltip('关闭泌乳记录'));
      await capture(
        tester,
        'milk-home-refreshed',
        'Close saved panel → home displays 80 ml',
      );
      await tap(tester, find.text('查看记录 ›'));
      const milkRoute = '/me/lactation';
      await capture(
        tester,
        'milk-history',
        'Home View records → standalone lactation history/trend',
        route: milkRoute,
      );
      await tap(
        tester,
        find.byKey(const ValueKey('lactation-edit-inventory-milk-1')),
      );
      await capture(
        tester,
        'milk-history-edit',
        'History edit → record editor',
        route: milkRoute,
      );
      await tester.enterText(measurement, '95');
      await tap(tester, find.text('保存修改'));
      expect((transport.records.single['observation'] as Map)['volume_ml'], 95);
      await capture(
        tester,
        'milk-history-updated',
        'Save changed volume → refreshed history and update feedback',
        route: milkRoute,
      );
      await tap(
        tester,
        find.byKey(const ValueKey('lactation-delete-inventory-milk-1')),
      );
      expect(transport.records, isEmpty);
      await capture(
        tester,
        'milk-history-deleted',
        'Delete record directly → deletion feedback with undo',
        route: milkRoute,
      );
      transport.failWrite = true;
      await tap(tester, find.text('撤销'));
      await capture(
        tester,
        'milk-restore-error',
        'Undo → API failure preserves undo entry',
        route: milkRoute,
      );
      transport.failWrite = false;
      await tap(tester, find.text('撤销'));
      expect(transport.records, hasLength(1));
      await capture(
        tester,
        'milk-history-restored',
        'Retry undo → record restored',
        route: milkRoute,
      );
      await tap(tester, find.byTooltip('关闭泌乳记录'));
      await capture(
        tester,
        'milk-return-home',
        'Close history → original home refreshes 95 ml',
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'inventory Mom diary quick record tabs save and standalone details',
    (tester) async {
      await mount(tester);
      await tap(tester, find.text('身体与精力'));
      await capture(
        tester,
        'diary-body-empty',
        'Home body card → quick body record',
      );
      await tap(tester, find.text('保存今天的记录'));
      expect(transport.diaries, isEmpty);
      await capture(
        tester,
        'diary-empty-validation',
        'Save empty diary → validation',
      );
      await tap(tester, find.text('有力气'));
      await tap(tester, find.text('休息'));
      await capture(tester, 'diary-rest-empty', 'Quick diary → Rest tab');
      await tap(tester, find.text('5–6 小时'));
      await tap(tester, find.text('心情'));
      await capture(tester, 'diary-mood-empty', 'Quick diary → Mood tab');
      await tap(tester, find.text('还算平稳'));
      await tap(tester, find.byTooltip('关闭记录'));
      await capture(
        tester,
        'diary-discard-confirm',
        'Close unsaved three-section diary → discard confirmation',
      );
      await tap(tester, find.text('继续填写'));
      await capture(
        tester,
        'diary-draft-retained',
        'Continue editing → selected mood and other draft sections remain',
      );
      transport.failWrite = true;
      await tap(tester, find.text('保存今天的记录'));
      await capture(
        tester,
        'diary-save-error',
        'Save diary → API error preserves entries',
      );
      transport.failWrite = false;
      await tap(tester, find.text('保存今天的记录'));
      expect(transport.diaries, hasLength(1));
      await capture(
        tester,
        'diary-modal-saved',
        'Retry save → saved feedback in quick editor',
      );
      await tap(tester, find.byTooltip('关闭记录'));
      await capture(
        tester,
        'diary-home-complete',
        'Close editor → all three home status groups completed',
      );
      await tap(tester, find.text('今日已完成记录 ›'));
      const diaryRoute = '/me/diary';
      await capture(
        tester,
        'diary-detail-rest',
        'Completed daily status → standalone diary detail',
        route: diaryRoute,
      );
      await tap(tester, find.text('身体'));
      await capture(
        tester,
        'diary-detail-body',
        'Standalone diary → Body tab',
        route: diaryRoute,
      );
      await tap(tester, find.text('心情'));
      await capture(
        tester,
        'diary-detail-mood',
        'Standalone diary → Mood tab',
        route: diaryRoute,
      );
      await tap(tester, find.text('有点绷着'));
      await tap(tester, find.text('保存今天的记录'));
      expect(transport.diaries.values.single['version'], 2);
      await capture(
        tester,
        'diary-detail-updated',
        'Save changed mood → updated standalone diary',
        route: diaryRoute,
      );
      await tap(tester, find.byTooltip('关闭记录'));
      await capture(
        tester,
        'diary-return-home',
        'Close standalone diary → home reloads changed mood',
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('inventory Mom AI card to Cozymate draft and service catalog', (
    tester,
  ) async {
    await mount(tester);
    await tap(tester, find.byType(MomAiInsightCard));
    await capture(
      tester,
      'ai-context-draft',
      'Home AI card → Cozymate with prefilled prompt, not sent',
      route: '/',
    );
    expect(transport.postedBodies, isEmpty);
    expect(find.text('请结合我今天的记录，帮我了解恢复状态。'), findsOneWidget);
    await tap(tester, find.text('Me'));
    await tap(tester, find.byType(MomExpertPlanEntry));
    await capture(
      tester,
      'service-catalog',
      'Home expert companionship entry → real service catalog',
      route: '/services',
    );
    await tap(tester, find.text('返回'));
    await capture(
      tester,
      'service-return-home',
      'Service catalog Back → Mom home',
    );
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('inventory Mom nursing optional fields time picker and discard', (
    tester,
  ) async {
    await mount(tester);
    await tap(tester, find.text('查看记录 ›'));
    const route = '/me/lactation';
    await capture(
      tester,
      'milk-history-empty',
      'Home View records → empty standalone lactation history',
      route: route,
    );
    await tap(tester, find.text('添加一条'));
    await tap(tester, find.text('亲喂'));
    await capture(
      tester,
      'nursing-empty',
      'History Add → switch to nursing form',
      route: route,
    );
    final measure = find.byKey(const ValueKey('lactation-measurement-nurse'));
    await tester.enterText(measure, '241');
    await tap(tester, find.text('保存这次记录'));
    await capture(
      tester,
      'nursing-duration-invalid',
      'Submit duration over limit → validation',
      route: route,
    );
    await tester.enterText(measure, '12');
    await tap(tester, find.text('补充感受与备注'));
    await tap(tester, find.text('胀满'));
    await tester.enterText(
      find.widgetWithText(TextFormField, '备注（可选）'),
      '先记录这次感受',
    );
    await capture(
      tester,
      'nursing-optional-filled',
      'Expand feeling and notes → enter optional observation',
      route: route,
    );
    await tap(
      tester,
      find.widgetWithIcon(OutlinedButton, Icons.schedule_rounded),
    );
    await capture(
      tester,
      'nursing-time-picker',
      'Record time → time picker',
      route: route,
    );
    final strings = MaterialLocalizations.of(
      tester.element(find.byType(TimePickerDialog)),
    );
    await tap(tester, find.byTooltip(strings.inputTimeModeButtonLabel));
    await capture(
      tester,
      'nursing-time-input',
      'Time picker → keyboard time entry',
      route: route,
    );
    final fields = find.descendant(
      of: find.byType(TimePickerDialog),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(fields.first, '99');
    await tap(tester, find.text(strings.okButtonLabel));
    await capture(
      tester,
      'nursing-time-invalid',
      'Invalid hour → time picker error',
      route: route,
    );
    await tap(
      tester,
      find.descendant(
        of: find.byType(TimePickerDialog),
        matching: find.text(strings.cancelButtonLabel),
      ),
    );
    await tap(tester, find.text('取消'));
    await capture(
      tester,
      'nursing-cancel-confirm',
      'Cancel record → discard confirmation',
      route: route,
    );
    await tap(tester, find.text('继续填写'));
    await capture(
      tester,
      'nursing-cancel-retained',
      'Continue editing → all entered fields remain',
      route: route,
    );
    transport.writeGate = Completer<void>();
    await tester.tap(find.text('保存这次记录'));
    await tester.pump();
    await capture(
      tester,
      'nursing-saving',
      'Submit nursing while response pending → saving state',
      route: route,
    );
    transport.writeGate!.complete();
    await tester.pumpAndSettle();
    expect(transport.records, hasLength(1));
    expect(
      (transport.records.single['observation'] as Map)['duration_minutes'],
      12,
    );
    await capture(
      tester,
      'nursing-saved',
      'Response received → saved nursing history',
      route: route,
    );
    await tap(tester, find.text('添加一条'));
    await tap(tester, find.text('取消'));
    await tap(tester, find.text('离开'));
    await capture(
      tester,
      'nursing-new-discarded',
      'Cancel another new record and discard → existing history unchanged',
      route: route,
    );
    expect(transport.records, hasLength(1));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('inventory Mom optional diary sections and mood draft discard', (
    tester,
  ) async {
    await mount(tester);
    await tap(tester, find.text('身体与精力'));
    await tap(tester, find.text('腰背'));
    await capture(
      tester,
      'body-discomfort-expanded',
      'Select discomfort site → severity and impact questions appear',
    );
    await tap(tester, find.text('明显'));
    await tap(tester, find.text('有一点影响'));
    await tap(tester, find.text('如厕与盆底'));
    await capture(
      tester,
      'body-optional-expanded',
      'Expand optional toilet and pelvic floor questions',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '今天身体最想告诉你什么？'),
      '今天想多休息',
    );
    await capture(tester, 'body-note', 'Enter optional body note');
    await tap(tester, find.text('休息'));
    await tap(tester, find.text('补充休息情况'));
    await capture(
      tester,
      'rest-optional-expanded',
      'Rest tab → expand continuous rest, naps and interruption causes',
    );
    await tap(tester, find.text('心情'));
    await tap(tester, find.text('担心宝宝'));
    await tap(tester, find.text('喂养压力'));
    await capture(
      tester,
      'mood-multiple-pressures',
      'Mood tab → select two pressure sources',
    );
    await tap(tester, find.text('说不清楚').last);
    await capture(
      tester,
      'mood-exclusive-pressure',
      'Select unclear pressure → exclusive choice replaces selected sources',
    );
    await tap(tester, find.byTooltip('关闭记录'));
    await capture(
      tester,
      'diary-optional-discard-confirm',
      'Close optional diary draft → discard confirmation',
    );
    await tap(tester, find.text('放弃修改'));
    expect(transport.diaries, isEmpty);
    await capture(
      tester,
      'diary-discarded-home',
      'Confirm discard → home remains unrecorded',
    );
    await tap(tester, find.text('不错'));
    await capture(
      tester,
      'mood-quick-prefilled',
      'Home quick mood → diary with mood preselected, no write yet',
    );
    expect(transport.diaries, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'inventory Mom trend period toggles with recorded and missing days',
    (tester) async {
      await mount(
        tester,
        prepare: (t) {
          for (final day in [0, 1, 2, 4, 6, 7, 14, 20, 29]) {
            t.seedMilk({
              'method': 'pump',
              'side': 'left',
              'volume_ml': 60 + day * 3,
              'occurred_at': inventoryMomNow
                  .subtract(Duration(days: day))
                  .toIso8601String(),
            });
          }
        },
      );
      const route = '/me/lactation';
      await tap(tester, find.text('查看记录 ›'));
      await capture(
        tester,
        'trend-seven-days',
        'Home history → seven-day measured curve with gaps',
        route: route,
      );
      await tap(tester, find.text('30天'));
      await capture(
        tester,
        'trend-thirty-days',
        'Select 30 days → expanded period and older measurements',
        route: route,
      );
      await tap(tester, find.text('7天'));
      await capture(
        tester,
        'trend-seven-days-return',
        'Return to 7 days → shorter curve',
        route: route,
      );
      await tap(tester, find.byTooltip('关闭泌乳记录'));
      await capture(
        tester,
        'trend-return-home',
        'Close trend → today total independent of historical measurements',
      );
      expect(transport.mutationPaths, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('inventory Mom diary conflict reload and pending save', (
    tester,
  ) async {
    await mount(tester);
    await tap(tester, find.text('身体与精力'));
    await tap(tester, find.text('有力气'));
    transport.failWrite = true;
    transport.failureStatus = 409;
    await tap(tester, find.text('保存今天的记录'));
    await capture(
      tester,
      'diary-conflict',
      'Save returns version conflict → draft preserved',
    );
    await tap(tester, find.text('重新载入'));
    await capture(
      tester,
      'diary-conflict-reload-confirm',
      'Reload conflicting diary → explicit discard confirmation',
    );
    await tap(tester, find.text('继续填写'));
    await capture(
      tester,
      'diary-conflict-retained',
      'Keep draft after conflict → conflict and entered fields remain',
    );
    await tap(tester, find.text('重新载入'));
    transport.failWrite = false;
    await tap(tester, find.text('放弃修改'));
    await capture(
      tester,
      'diary-conflict-reloaded',
      'Confirm discard → reload latest empty diary',
    );
    await tap(tester, find.text('有力气'));
    transport.writeGate = Completer<void>();
    await tester.tap(find.text('保存今天的记录'));
    await tester.pump();
    await capture(
      tester,
      'diary-saving',
      'Submit replacement draft → controls disabled while pending',
    );
    expect(transport.diaries, isEmpty);
    transport.writeGate!.complete();
    await tester.pumpAndSettle();
    expect(transport.diaries, hasLength(1));
    await capture(
      tester,
      'diary-conflict-resolved',
      'Save response → persisted diary feedback',
    );
    await tap(tester, find.byTooltip('关闭记录'));
    await capture(
      tester,
      'diary-conflict-return-home',
      'Close saved diary → body state refreshed on home',
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('inventory Mom milk conflict uncertain close and failed delete', (
    tester,
  ) async {
    await mount(
      tester,
      prepare: (t) => t.seedMilk({
        'method': 'pump',
        'side': 'left',
        'volume_ml': 60,
        'occurred_at': inventoryMomNow.toIso8601String(),
      }),
    );
    const route = '/me/lactation';
    await tap(tester, find.text('查看记录 ›'));
    await tap(
      tester,
      find.byKey(const ValueKey('lactation-edit-inventory-milk-1')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('lactation-measurement-pump')),
      '70',
    );
    transport.failWrite = true;
    transport.failureStatus = 409;
    await tap(tester, find.text('保存修改'));
    await capture(
      tester,
      'milk-conflict',
      'Edit saved milk and receive conflict → draft preserved',
      route: route,
    );
    await tap(tester, find.text('重新载入'));
    await capture(
      tester,
      'milk-conflict-reload-confirm',
      'Reload conflicted milk → discard confirmation',
      route: route,
    );
    await tap(tester, find.text('离开'));
    await capture(
      tester,
      'milk-conflict-reloaded',
      'Discard conflict draft → latest saved list',
      route: route,
    );
    await tap(
      tester,
      find.byKey(const ValueKey('lactation-delete-inventory-milk-1')),
    );
    expect(transport.records, hasLength(1));
    await capture(
      tester,
      'milk-delete-failed',
      'Delete rejected → record stays visible with error',
      route: route,
    );
    transport.failureStatus = 503;
    await tap(tester, find.text('添加一条'));
    await tester.enterText(
      find.byKey(const ValueKey('lactation-measurement-pump')),
      '50',
    );
    await tap(tester, find.text('保存这次记录'));
    await capture(
      tester,
      'milk-uncertain-save',
      'Unavailable create response → uncertain result and retry controls',
      route: route,
    );
    await tap(tester, find.byTooltip('关闭泌乳记录'));
    await capture(
      tester,
      'milk-uncertain-leave-confirm',
      'Close uncertain record → reconciliation warning',
      route: route,
    );
    await tap(tester, find.text('继续填写'));
    transport.failWrite = false;
    await tap(tester, find.text('重试保存'));
    expect(transport.records, hasLength(2));
    await capture(
      tester,
      'milk-uncertain-retried',
      'Retry same pending save → saved list',
      route: route,
    );
    await tap(tester, find.byTooltip('关闭泌乳记录'));
    await capture(
      tester,
      'milk-uncertain-return-home',
      'Return from reconciled save → updated home total',
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'inventory Mom purchased home service progress and booking entry',
    (tester) async {
      await mount(tester, prepare: (t) => t.seedPlan());
      await tester.scrollUntilVisible(
        find.byType(ExpertServiceCard),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.byType(MomExpertPlanEntry), findsOneWidget);
      await capture(
        tester,
        'purchased-home',
        'Me with active plan → both catalog entry and owned service card',
      );
      await tap(tester, find.text('服务进度 ›'));
      await capture(
        tester,
        'purchased-progress',
        'Owned plan → actual service timeline route',
        route: '/services/episodes/inventory-episode',
      );
      await tap(tester, find.text('返回'));
      await capture(
        tester,
        'purchased-progress-return',
        'Timeline back → owned plan on home',
      );
      await tap(tester, find.text('预约咨询'));
      await capture(
        tester,
        'purchased-booking-precheck',
        'Book from home → actual booking route and suitability dialog',
        route: '/services/episodes/inventory-episode/booking',
      );
      await tap(tester, find.byTooltip('关闭预约前确认'));
      await capture(
        tester,
        'purchased-booking-cancel-precheck',
        'Cancel suitability check → booking page',
        route: '/services/episodes/inventory-episode/booking',
      );
      await tap(tester, find.text('返回'));
      await capture(
        tester,
        'purchased-booking-return',
        'Booking back → active plan unchanged',
      );
      expect(transport.mutationPaths, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('inventory Mom independent loading failures and retry', (
    tester,
  ) async {
    await mount(
      tester,
      loading: true,
      prepare: (t) {
        for (final path in [
          '/v1/profile/me',
          '/v1/profile/lactation',
          '/v1/mother/diary',
          '/v1/lactation/records',
        ]) {
          t.readGates[path] = Completer<void>();
        }
      },
    );
    await capture(
      tester,
      'home-loading',
      'Me tab entered with homepage data requests pending',
    );
    for (final gate in transport.readGates.values) {
      gate.complete();
    }
    await tester.pumpAndSettle();
    await capture(
      tester,
      'home-loaded-empty',
      'All requests resolve → initial cards',
    );
    transport.failingReads.add('/v1/mother/diary');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 400));
    await tester.pumpAndSettle();
    await capture(
      tester,
      'home-diary-partial-error',
      'Pull refresh → diary request fails while other modules remain available',
    );
    transport.failingReads.clear();
    await tap(tester, find.text('重试').first);
    await capture(
      tester,
      'home-partial-recovered',
      'Retry failed section → empty daily status restored',
    );
    transport.failingReads.add('/v1/lactation/records');
    await tap(tester, find.text('查看记录 ›'));
    await capture(
      tester,
      'milk-history-read-error',
      'Enter standalone lactation page → records request error',
      route: '/me/lactation',
    );
    transport.failingReads.clear();
    await tap(tester, find.text('重试'));
    await capture(
      tester,
      'milk-history-read-recovered',
      'Retry standalone records → empty history',
      route: '/me/lactation',
    );
    await tap(tester, find.byTooltip('关闭泌乳记录'));
    transport.failingReads.add('/v1/mother/diary');
    await tap(tester, find.text('身体与精力'));
    await capture(
      tester,
      'diary-read-error',
      'Open quick diary → independent diary load error',
    );
    transport.failingReads.clear();
    await tap(tester, find.text('重试'));
    await capture(
      tester,
      'diary-read-recovered',
      'Retry diary read → empty body form',
    );
    await tester.pumpWidget(const SizedBox());
  });
}
