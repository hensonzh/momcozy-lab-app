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
        'test/goldens/ui_inventory/baby-development-management-$state-$variant.png';
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/ui_inventory/baby-development-management-$state-$variant.png',
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
      'test':
          'test/modules/baby/baby_development_management_inventory_test.dart',
    };
    previous = source;
    final output = Platform.environment['MOMCOZY_UI_INVENTORY_DIR'];
    if (output != null) {
      final file = File(
        '$output/journeys/baby-development-management-$state-$variant.json',
      );
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(row)}\n',
      );
    }
  }

  BabyRecordEditorController editor(WidgetTester tester) =>
      tester.widget<BabyRecordEditor>(find.byType(BabyRecordEditor)).controller;

  const ids = ['looks-at-face', 'responds-to-sound', 'lifts-head'];
  for (final subset in [
    [0],
    [1],
    [2],
    [0, 1],
    [0, 2],
    [1, 2],
  ]) {
    final caseId = subset.map((i) => ['face', 'sound', 'head'][i]).join('-');
    for (final narrow in [false, true]) {
      testWidgets(
        'inventory development management $caseId ${narrow ? '320/2x' : '393/1x'}',
        (tester) async {
          await mount(tester, width: narrow ? 320 : 393, scale: narrow ? 2 : 1);
          Future<void> snap(
            String name,
            String action, {
            String route = '/baby',
          }) => capture(tester, '$caseId-$name', action, route: route);
          await snap(
            'home-entry',
            'More → Baby before $caseId observation management',
          );
          await tap(tester, find.text('记录发育观察'));
          for (final i in subset) {
            final group = find.byWidgetPredicate(
              (w) =>
                  w is ChoiceField && w.title == babyDevelopmentItems[ids[i]],
            );
            final label = ['观察到', '暂未观察到', '不确定'][i];
            await tap(
              tester,
              find.descendant(of: group, matching: find.text(label)),
            );
            expect(
              editor(tester).development[ids[i]],
              DevelopmentStatus.values[i],
            );
            await snap(
              'selected-${ids[i]}',
              'Choose $label for ${babyDevelopmentItems[ids[i]]}; retain previous choices',
            );
          }
          expect(
            editor(tester).development.keys,
            unorderedEquals(subset.map((i) => ids[i])),
          );
          await tap(tester, find.byKey(const ValueKey('baby-save')));
          expect(transport.records, hasLength(subset.length));
          expect(
            transport.records.map((r) => (r['observation'] as Map)['item_id']),
            orderedEquals(subset.map((i) => ids[i])),
          );
          expect(
            transport.records.map((r) => (r['observation'] as Map)['status']),
            orderedEquals(
              subset.map((i) => ['observed', 'not_observed', 'unsure'][i]),
            ),
          );
          expect(find.text('撤销'), findsNothing);
          await snap(
            'saved',
            'Save $caseId → ${subset.length} observations, homepage feedback without undo',
          );
          await tester.pump(const Duration(seconds: 5));
          await tester.pumpAndSettle();
          await tap(tester, find.text('查看全部记录'));
          await tap(tester, find.text('发育观察'));
          const history = '/babies/inventory-baby/records';
          for (final i in subset) {
            expect(
              find.text(
                '${babyDevelopmentItems[ids[i]]} · ${['观察到', '暂未观察到', '不确定'][i]}',
              ),
              findsOneWidget,
            );
          }
          await snap(
            'history',
            'History development tab → $caseId records with each saved status',
            route: history,
          );
          if (subset.length == 1) {
            final id = transport.records.single['id'];
            await tap(tester, find.text('删除'));
            expect(find.text('删除这条记录？'), findsOneWidget);
            await snap(
              'delete-confirm',
              'Delete $caseId → record-specific confirmation',
              route: history,
            );
            await tap(tester, find.text('保留'));
            expect(transport.records.single['id'], id);
            expect(transport.records.single['version'], 1);
            await snap(
              'delete-kept',
              'Keep → original $caseId record unchanged',
              route: history,
            );
            await tap(tester, find.text('删除'));
            await tap(tester, find.widgetWithText(FilledButton, '删除'));
            expect(transport.records, isEmpty);
            expect(transport.deleted[id]!['version'], 2);
            await snap(
              'deleted',
              'Confirm delete → empty development history and undo action',
              route: history,
            );
            await tap(tester, find.text('撤销删除'));
            expect(transport.records.single['id'], id);
            expect(transport.records.single['version'], 3);
            expect(transport.deleted, isEmpty);
            await snap(
              'restored',
              'Undo delete → same $caseId record restored with version 3',
              route: history,
            );
            await tap(tester, find.text('编辑'));
            final i = subset.single;
            expect(
              editor(tester).development[ids[i]],
              DevelopmentStatus.values[i],
            );
            await snap(
              'restored-edit',
              'Edit restored $caseId → original behavior and status preserved',
              route: history,
            );
            await tap(tester, find.byTooltip('关闭记录'));
            await snap(
              'restored-edit-closed',
              'Close unchanged restored record → history without discard prompt',
              route: history,
            );
          }
          await tap(tester, find.text('返回'));
          await snap(
            'home-return',
            'History Back → Baby after $caseId management',
          );
          await tap(tester, find.text('More'));
          await snap(
            'more-return',
            'Baby → More after $caseId management',
            route: '/more',
          );
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        },
      );
    }
  }
}
