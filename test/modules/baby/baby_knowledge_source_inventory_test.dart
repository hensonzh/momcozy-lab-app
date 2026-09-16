import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../support/fake_agent_voice.dart';
import '../../support/fixture_api_transport.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:momcozy_flutter_app/modules/baby/application/baby_knowledge_content.dart';
import 'package:momcozy_flutter_app/domain/baby/baby_record.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/native/p0_platform_interfaces.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_design_system.dart';
import '../../support/baby_inventory_transport.dart';
import 'package:momcozy_flutter_app/shared/widgets/knowledge_banner.dart';
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
        'test/goldens/ui_inventory/baby-knowledge-source-$state-$variant.png';
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/ui_inventory/baby-knowledge-source-$state-$variant.png',
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
      'test': 'test/modules/baby/baby_knowledge_source_inventory_test.dart',
    };
    previous = source;
    final output = Platform.environment['MOMCOZY_UI_INVENTORY_DIR'];
    if (output != null) {
      final file = File(
        '$output/journeys/baby-knowledge-source-$state-$variant.json',
      );
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(row)}\n',
      );
    }
  }

  for (final narrow in [false, true]) {
    testWidgets('inventory Baby knowledge sources ${narrow ? '320/2x' : '393/1x'}', (
      tester,
    ) async {
      final calls = <Map<String, Object?>>[];
      var result = true, throws = false;
      Completer<bool>? gate;
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'launch');
            calls.add(Map<String, Object?>.from(call.arguments as Map));
            if (throws) {
              throw PlatformException(code: 'inventory_browser_unavailable');
            }
            return gate == null ? result : await gate.future;
          });
      addTearDown(() {
        if (gate case final g? when !g.isCompleted) g.complete(false);
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      await mount(tester, width: narrow ? 320 : 393, scale: narrow ? 2 : 1);
      for (final topic in [
        BabyKnowledgeTopic.feedingCues,
        BabyKnowledgeTopic.feeding,
        BabyKnowledgeTopic.sleep,
        BabyKnowledgeTopic.diaper,
        BabyKnowledgeTopic.growth,
        BabyKnowledgeTopic.development,
      ]) {
        transport.records.clear();
        final occurred = transport.clock.subtract(const Duration(hours: 12));
        final observation = switch (topic) {
          BabyKnowledgeTopic.feedingCues => null,
          BabyKnowledgeTopic.feeding => <String, Object?>{
            'kind': 'feeding',
            'method': 'formula',
            'volume_ml': 90,
            'occurred_at': occurred.toIso8601String(),
            'note': '',
          },
          BabyKnowledgeTopic.sleep => <String, Object?>{
            'kind': 'sleep',
            'occurred_at': occurred.toIso8601String(),
            'ended_at': occurred
                .add(const Duration(hours: 1))
                .toIso8601String(),
            'note': '',
          },
          BabyKnowledgeTopic.diaper => <String, Object?>{
            'kind': 'diaper',
            'diaper_kind': 'wet',
            'occurred_at': occurred.toIso8601String(),
            'signs': <String>[],
            'note': '',
          },
          BabyKnowledgeTopic.growth => <String, Object?>{
            'kind': 'growth',
            'recorded_on': '2026-09-12',
            'timezone': 'Asia/Shanghai',
            'metric': 'weight',
            'value': 3.8,
          },
          BabyKnowledgeTopic.development => <String, Object?>{
            'kind': 'development',
            'recorded_on': '2026-09-12',
            'timezone': 'Asia/Shanghai',
            'item_id': babyDevelopmentItems.keys.first,
            'status': 'observed',
          },
        };
        if (observation != null) {
          transport.create('inventory-baby', observation);
        }
        final homeScroll = find.byType(Scrollable).first;
        while (tester.state<ScrollableState>(homeScroll).position.pixels > 0) {
          await tester.drag(homeScroll, const Offset(0, 600));
          await tester.pumpAndSettle();
        }
        final readsBeforeRefresh = transport.getPaths.length;
        await tester.drag(homeScroll, const Offset(0, 500));
        await tester.pumpAndSettle();
        expect(transport.getPaths.length, greaterThan(readsBeforeRefresh));
        final article = tester
            .widget<KnowledgeBanner>(find.byType(KnowledgeBanner))
            .article;
        expect(article.title, babyKnowledgeArticles[topic]!.title);
        await capture(
          tester,
          '${topic.name}-home',
          'Pull to refresh with ${topic.name} data → production-selected knowledge card',
        );
        await tap(tester, find.byType(KnowledgeBanner));
        await capture(
          tester,
          '${topic.name}-detail',
          'Tap ${topic.name} knowledge card → complete article',
        );
        final before = calls.length;
        await tap(tester, find.text(article.source!.label));
        expect(calls.length, before + 1);
        expect(calls.last['url'], article.source!.url);
        expect(calls.last['useWebView'], isFalse);
        await capture(
          tester,
          '${topic.name}-source-dispatched',
          'Tap ${article.source!.label} → platform accepts external URL; host does not render browser',
        );
        if (topic == BabyKnowledgeTopic.feedingCues) {
          result = false;
          await tap(tester, find.text(article.source!.label));
          expect(find.text('暂时无法打开来源链接'), findsOneWidget);
          await capture(
            tester,
            'source-false-error',
            'External launcher returns false → source error Snackbar',
          );
          await tester.pump(const Duration(seconds: 5));
          await tester.pumpAndSettle();
          throws = true;
          await tap(tester, find.text(article.source!.label));
          expect(find.text('暂时无法打开来源链接'), findsOneWidget);
          await capture(
            tester,
            'source-exception-error',
            'PlatformException → same error feedback; article remains',
          );
          throws = false;
          await tap(tester, find.text('关闭'));
          await capture(
            tester,
            'source-error-dialog-closed',
            'Close article while Snackbar remains → Baby home',
          );
          await tester.pump(const Duration(seconds: 5));
          await tester.pumpAndSettle();
          await tap(tester, find.byType(KnowledgeBanner));
          gate = Completer<bool>();
          await tester.ensureVisible(find.text(article.source!.label));
          await tester.tap(find.text(article.source!.label));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 250));
          await capture(
            tester,
            'source-pending',
            'External dispatch response pending → article remains interactive',
          );
          await tap(tester, find.text('关闭'));
          await capture(
            tester,
            'source-pending-closed',
            'Close article before launcher resolves → Baby home',
          );
          gate.complete(false);
          await tester.pumpAndSettle();
          expect(find.text('暂时无法打开来源链接'), findsNothing);
          await capture(
            tester,
            'source-late-failure',
            'Late failure after dialog disposal → no stale Snackbar',
          );
          gate = null;
          result = true;
        } else {
          await tap(tester, find.text('关闭'));
          await capture(
            tester,
            '${topic.name}-return',
            'Close ${topic.name} article → Baby home',
          );
        }
      }
      expect(calls, hasLength(9));
      expect(
        transport.mutationPaths.where((p) => p.contains('/runs')),
        isEmpty,
      );
      await tap(tester, find.text('More'));
      await capture(
        tester,
        'more-return',
        'Baby → More after all six knowledge topics',
        route: '/more',
      );
      await tester.pumpWidget(const SizedBox());
    });
  }
}
