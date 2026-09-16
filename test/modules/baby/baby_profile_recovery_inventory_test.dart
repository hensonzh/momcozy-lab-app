import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:momcozy_flutter_app/domain/baby/baby_profile.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_profile_editor.dart';
import 'package:momcozy_flutter_app/modules/baby/application/baby_profile_controller.dart';
import 'package:momcozy_flutter_app/domain/shared/product_failure.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
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

class _ProfileTransport extends BabyInventoryTransport {
  Completer<void>? profileReadGate;
  int? profileReadError, profileWriteError;
  int writeAttempts = 0;
  Never reject(int status) => throw ApiHttpException.fromBody({
    'http_status': status,
    'body': {
      'error': {'code': 'inventory_profile_failure'},
    },
  });
  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) async {
    if (path == '/v1/babies') {
      await profileReadGate?.future;
      if (profileReadError case final status?) reject(status);
    }
    return super.getJson(path, query: query);
  }

  @override
  Future<Map<String, Object?>> putJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    if (path == '/v1/babies/inventory-baby') {
      writeAttempts++;
      if (profileWriteError case final status?) reject(status);
      if (body['expected_version'] != profiles.first['version']) reject(409);
    }
    return super.putJson(path, body: body, headers: headers);
  }
}

void main() {
  setUpAll(loadMomCozyTestFonts);
  late _ProfileTransport transport;
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
    transport = _ProfileTransport();
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
      if (transport.profileReadGate case final gate? when !gate.isCompleted) {
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
        'test/goldens/ui_inventory/baby-profile-recovery-$state-$variant.png';
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/ui_inventory/baby-profile-recovery-$state-$variant.png',
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
      'test': 'test/modules/baby/baby_profile_recovery_inventory_test.dart',
    };
    previous = source;
    final output = Platform.environment['MOMCOZY_UI_INVENTORY_DIR'];
    if (output != null) {
      final file = File(
        '$output/journeys/baby-profile-recovery-$state-$variant.json',
      );
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(row)}\n',
      );
    }
  }

  BabyProfileController profile(WidgetTester tester) => tester
      .widget<BabyProfileEditor>(find.byType(BabyProfileEditor))
      .controller;
  Future<void> edit(WidgetTester tester, String name) async {
    await tap(tester, find.text(name));
    await tap(tester, find.text('编辑当前宝宝资料'));
  }

  Future<void> input(WidgetTester tester, Finder field, String text) async {
    await tester.ensureVisible(field);
    await tester.enterText(field, text);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
  }

  for (final narrow in [false, true]) {
    testWidgets(
      'inventory Baby profile recovery ${narrow ? '320/2x' : '393/1x'}',
      (tester) async {
        await mount(tester, width: narrow ? 320 : 393, scale: narrow ? 2 : 1);
        await capture(
          tester,
          'home-entry',
          'More → Baby before profile recovery',
        );
        await edit(tester, 'Luna');
        final name = find.descendant(
          of: find.byType(BabyProfileEditor),
          matching: find.byType(TextField),
        );
        await input(tester, name, 'Luna local');
        await capture(
          tester,
          'local-draft',
          'Edit name locally; server version remains 1',
        );
        // A second client updates the server after this editor has read v1.
        transport.profiles.first.addAll({
          'name': 'Luna server',
          'version': 2,
          'feeding_mode': 'formula_feeding',
        });
        await tap(tester, find.text('保存宝宝资料'));
        expect(profile(tester).failure?.kind, ProductFailureKind.conflict);
        expect(profile(tester).name, 'Luna local');
        expect(profile(tester).uncertain, isFalse);
        await capture(
          tester,
          'conflict',
          'Save stale version → conflict, retain local draft and offer reload',
        );
        transport.profileReadGate = Completer<void>();
        await tester.ensureVisible(find.text('重新载入'));
        await tester.tap(find.text('重新载入'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        expect(profile(tester).busy, isTrue);
        expect(profile(tester).editable, isFalse);
        await capture(
          tester,
          'reload-pending',
          'Click reload while profile response pending → controls disabled',
        );
        transport.profileReadError = 503;
        transport.profileReadGate!.complete();
        await tester.pumpAndSettle();
        expect(profile(tester).failure?.kind, ProductFailureKind.unavailable);
        expect(profile(tester).name, 'Luna local');
        expect(profile(tester).editable, isTrue);
        expect(find.text('重新载入'), findsNothing);
        await capture(
          tester,
          'reload-unavailable',
          'Reload fails 503 → preserved local draft; reload action disappears',
        );
        transport.profileReadError = null;
        await tap(tester, find.text('保存宝宝资料'));
        expect(profile(tester).failure?.kind, ProductFailureKind.conflict);
        await capture(
          tester,
          'conflict-again',
          'Save stale draft again → conflict restores reload action',
        );
        await tap(tester, find.text('重新载入'));
        expect(profile(tester).failure, isNull);
        expect(profile(tester).name, 'Luna server');
        expect(profile(tester).feedingMode, FeedingMode.formula);
        expect(tester.widget<TextField>(name).controller!.text, 'Luna server');
        expect(profile(tester).dirty, isFalse);
        await capture(
          tester,
          'reload-current',
          'Reload succeeds → latest server name and feeding mode replace draft',
        );
        await input(tester, name, 'Luna forbidden');
        transport.profileWriteError = 403;
        await tap(tester, find.text('保存宝宝资料'));
        expect(profile(tester).failure?.kind, ProductFailureKind.forbidden);
        expect(profile(tester).editable, isTrue);
        expect(transport.profiles.first['name'], 'Luna server');
        await capture(
          tester,
          'save-forbidden',
          'Save returns 403 → access error, editable draft and no server update',
        );
        await tap(tester, find.byTooltip('关闭宝宝资料'));
        await capture(
          tester,
          'forbidden-discard-confirm',
          'Close rejected draft → discard confirmation',
        );
        await tap(tester, find.text('离开'));
        expect(find.byType(BabyProfileEditor), findsNothing);
        expect(find.text('Luna server'), findsOneWidget);
        await capture(
          tester,
          'forbidden-discarded',
          'Confirm leave → refreshed home shows server profile',
        );
        transport.profileWriteError = null;
        await edit(tester, 'Luna server');
        await input(tester, name, 'Luna pending');
        transport.failWrite = true;
        await tap(tester, find.text('保存宝宝资料'));
        expect(profile(tester).uncertain, isTrue);
        await capture(
          tester,
          'unconfirmed',
          'Save returns 503 → pending result and locked draft',
        );
        await tap(tester, find.byTooltip('关闭宝宝资料'));
        await capture(
          tester,
          'unconfirmed-leave-dialog',
          'Close pending save → uncertain-result warning',
        );
        await tap(tester, find.text('离开'));
        expect(find.byType(BabyProfileEditor), findsNothing);
        expect(transport.profiles.first['version'], 2);
        await capture(
          tester,
          'unconfirmed-left',
          'Confirm leave → home refreshes unchanged server profile',
        );
        transport.failWrite = false;
        await edit(tester, 'Luna server');
        expect(profile(tester).name, 'Luna server');
        expect(profile(tester).uncertain, isFalse);
        await capture(
          tester,
          'unconfirmed-reopened',
          'Reopen → persisted profile, no unconfirmed local draft',
        );
        await input(tester, name, 'Luna saved');
        transport.writeGate = Completer<void>();
        await tester.ensureVisible(find.text('保存宝宝资料'));
        await tester.tap(find.text('保存宝宝资料'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        expect(profile(tester).busy, isTrue);
        final attempts = transport.writeAttempts;
        await capture(
          tester,
          'save-pending',
          'Save response pending → disabled save, fields and close',
        );
        final close = find.byTooltip('关闭宝宝资料');
        await tester.tap(close, warnIfMissed: false);
        await tester.pump();
        await tester.binding.handlePopRoute();
        await tester.pump();
        expect(find.byType(BabyProfileEditor), findsOneWidget);
        expect(find.text('离开这次记录？'), findsNothing);
        expect(transport.writeAttempts, attempts);
        await capture(
          tester,
          'busy-close-blocked',
          'Tap disabled close then platform back → saving editor stays open',
        );
        transport.writeGate!.complete();
        await tester.pumpAndSettle();
        expect(find.byType(BabyProfileEditor), findsNothing);
        expect(transport.profiles.first['name'], 'Luna saved');
        expect(transport.profiles.first['version'], 3);
        await capture(
          tester,
          'saved',
          'Response acknowledged → refreshed home with version 3',
        );
        await edit(tester, 'Luna saved');
        expect(profile(tester).name, 'Luna saved');
        await capture(
          tester,
          'saved-reopened',
          'Reopen saved profile → confirmed name persisted',
        );
        await tap(tester, find.byTooltip('关闭宝宝资料'));
        await tap(tester, find.text('More'));
        await capture(
          tester,
          'more-return',
          'Close unchanged editor → More',
          route: '/more',
        );
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
