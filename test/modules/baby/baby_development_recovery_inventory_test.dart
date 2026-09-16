import 'dart:async';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
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

class _RecoveryTransport extends BabyInventoryTransport {
  int? deleteError, restoreError;
  Never reject(int status) => throw ApiHttpException.fromBody({
    'http_status': status,
    'body': {
      'error': {'code': 'inventory_mutation_failure'},
    },
  });
  @override
  Future<Map<String, Object?>> deleteJson(
    String path, {
    Map<String, String> headers = const {},
  }) async {
    if (deleteError case final status?) reject(status);
    return super.deleteJson(path, headers: headers);
  }

  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    if (path.endsWith('/restore') && restoreError != null) {
      reject(restoreError!);
    }
    return super.postJson(path, body: body, headers: headers);
  }
}

void main() {
  setUpAll(loadMomCozyTestFonts);
  late _RecoveryTransport transport;
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
    transport = _RecoveryTransport();
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
        'test/goldens/ui_inventory/baby-development-recovery-$state-$variant.png';
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/ui_inventory/baby-development-recovery-$state-$variant.png',
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
      'test': 'test/modules/baby/baby_development_recovery_inventory_test.dart',
    };
    previous = source;
    final output = Platform.environment['MOMCOZY_UI_INVENTORY_DIR'];
    if (output != null) {
      final file = File(
        '$output/journeys/baby-development-recovery-$state-$variant.json',
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
    testWidgets('inventory development recovery ${narrow ? '320/2x' : '393/1x'}', (
      tester,
    ) async {
      await mount(tester, width: narrow ? 320 : 393, scale: narrow ? 2 : 1);
      await capture(
        tester,
        'home-entry',
        'More → Baby before history mutation recovery',
      );
      await tap(tester, find.text('记录发育观察'));
      final group = find.byWidgetPredicate(
        (w) =>
            w is ChoiceField &&
            w.title == babyDevelopmentItems['looks-at-face'],
      );
      await tap(tester, find.descendant(of: group, matching: find.text('观察到')));
      expect(
        editor(tester).development['looks-at-face'],
        DevelopmentStatus.observed,
      );
      await capture(tester, 'selected', 'Choose one observed behavior');
      await tap(tester, find.byKey(const ValueKey('baby-save')));
      final recordId = transport.records.single['id'];
      await capture(
        tester,
        'saved',
        'Save observation before history recovery',
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tap(tester, find.text('查看全部记录'));
      await tap(tester, find.text('发育观察'));
      const history = '/babies/inventory-baby/records';
      Future<void> snap(String name, String action) =>
          capture(tester, name, action, route: history);
      Future<void> requestDelete() async {
        await tap(tester, find.text('删除'));
        await tap(tester, find.widgetWithText(FilledButton, '删除'));
      }

      await snap('history', 'Open development history with one saved behavior');
      for (final code in [403, 409]) {
        transport.deleteError = code;
        await requestDelete();
        expect(transport.records.single['version'], 1);
        expect(find.text('操作结果还未确认，请重试确认后再修改其他记录。'), findsNothing);
        expect(
          tester
              .widget<TextButton>(find.widgetWithText(TextButton, '编辑'))
              .onPressed,
          isNotNull,
        );
        await snap(
          'delete-$code',
          'Delete returns HTTP $code → error, record retained and other edits enabled',
        );
        transport.deleteError = null;
        await tap(tester, find.text(code == 409 ? '重新载入' : '重试'));
        expect(transport.records.single['id'], recordId);
        await snap(
          'delete-$code-reload',
          'Retry confirmed HTTP $code failure → reload history without deleting',
        );
      }
      transport.failWrite = true;
      await requestDelete();
      expect(transport.records, hasLength(1));
      expect(find.text('操作结果还未确认，请重试确认后再修改其他记录。'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, '编辑'))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == '上个月',
              ),
            )
            .onPressed,
        isNull,
      );
      await snap(
        'delete-unconfirmed',
        'Delete fails 503 → unconfirmed mutation, record retained and month/edit locked',
      );
      transport.failWrite = false;
      transport.writeGate = Completer<void>();
      await tester.tap(find.text('重试'));
      await tester.pump();
      expect(transport.records, hasLength(1));
      await snap(
        'delete-pending',
        'Retry deletion with response pending → controls stay locked',
      );
      transport.writeGate!.complete();
      await tester.pumpAndSettle();
      expect(transport.records, isEmpty);
      expect(transport.deleted[recordId]!['version'], 2);
      await snap('deleted', 'Delete acknowledged → empty list and undo');
      transport.writeGate = null;
      for (final code in [403, 409]) {
        transport.restoreError = code;
        await tap(tester, find.text('撤销删除'));
        expect(transport.records, isEmpty);
        expect(find.text('操作结果还未确认，请重试确认后再修改其他记录。'), findsNothing);
        await snap(
          'restore-$code',
          'Undo returns HTTP $code → error and retained deletion receipt',
        );
        transport.restoreError = null;
        await tap(tester, find.text(code == 409 ? '重新载入' : '重试'));
        expect(transport.records, isEmpty);
        await snap(
          'restore-$code-reload',
          'Retry confirmed restore failure → reload empty history; undo remains',
        );
      }
      transport.failWrite = true;
      await tap(tester, find.text('撤销删除'));
      expect(transport.records, isEmpty);
      expect(find.text('操作结果还未确认，请重试确认后再修改其他记录。'), findsOneWidget);
      await snap(
        'restore-unconfirmed',
        'Undo fails 503 → unconfirmed restore with retry',
      );
      transport.failWrite = false;
      transport.writeGate = Completer<void>();
      await tester.tap(find.text('重试'));
      await tester.pump();
      await snap(
        'restore-pending',
        'Retry restore → response pending while empty list remains',
      );
      transport.writeGate!.complete();
      await tester.pumpAndSettle();
      expect(transport.records.single['id'], recordId);
      expect(transport.records.single['version'], 3);
      expect(find.text('撤销删除'), findsNothing);
      await snap(
        'restored',
        'Restore acknowledged → same record version 3, undo receipt cleared',
      );
      transport.writeGate = null;
      await requestDelete();
      expect(transport.records, isEmpty);
      await snap(
        'deleted-before-leave',
        'Delete restored record → version 4 receipt before leaving history',
      );
      await tap(tester, find.text('返回'));
      await capture(
        tester,
        'home-after-delete',
        'Leave history after deletion → Baby',
      );
      await tap(tester, find.text('查看全部记录'));
      await tap(tester, find.text('发育观察'));
      expect(find.text('撤销删除'), findsNothing);
      expect(transport.records, isEmpty);
      await snap(
        'reentered-empty',
        'Reenter development history → empty list without prior undo receipt',
      );
      await tap(tester, find.text('返回'));
      await tap(tester, find.text('More'));
      await capture(
        tester,
        'more-return',
        'Return More after mutation recovery',
        route: '/more',
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
}
