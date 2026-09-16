import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_page.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_runtime.dart';
import 'package:momcozy_flutter_app/core/routing/external_url_launcher.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_client.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_runner.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_io_transport.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/native/p0_platform_interfaces.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_design_system.dart';
import '../../support/mom_inventory_transport.dart';
import '../../support/agent_workflow_inventory_transport.dart';
import '../../support/fixture_api_transport.dart';
import '../../support/fake_agent_voice.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);
  setUpAll(() => WidgetController.hitTestWarningShouldBeFatal = true);
  late AgentWorkflowInventoryTransport transport;
  late MomCozyRuntimeController runtime;
  late GoRouter router;
  String? previous;
  late InventoryLinkLauncher launcher;
  bool failClipboard = false;
  Future<void> mount(
    WidgetTester tester, {
    void Function(AgentWorkflowInventoryTransport)? prepare,
    bool loading = false,
    double width = 393,
    double textScale = 1,
  }) async {
    previous = null;
    failClipboard = false;
    String? clipboard;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        if (failClipboard) {
          throw PlatformException(code: 'clipboard_unavailable');
        }
        clipboard = (call.arguments as Map)['text'] as String?;
      }
      if (call.method == 'Clipboard.getData') return {'text': clipboard};
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    FlutterSecureStorage.setMockInitialValues({});
    tester.view.physicalSize = Size(width, 844);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    launcher = InventoryLinkLauncher();
    transport = AgentWorkflowInventoryTransport();
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
      agentHubBuilder: (context, uri, extra, voice) {
        final api = MomCozyRuntimeScope.of(context);
        return AgentHubPage(
          key: const ValueKey('inventory-agent-page'),
          stateCacheKey: api,
          interactionStateStore: createSessionAgentHubInteractionStateStore(
            api.currentSession,
          ),
          runner: AgentStreamRunner(
            SseAgentStreamClient(transport),
            reconnectPolicy: const AgentStreamReconnectPolicy(),
            runStatusReader: transport,
          ),
          cancelClient: AgentStreamCancelClient(
            endpoint: AgentStreamEndpoint(
              uri: Uri.parse('https://inventory.invalid/v1/agent/runs'),
            ),
            connector: transport,
          ),
          actionClient: AgentStreamActionClient(
            endpoint: AgentStreamEndpoint(
              uri: Uri.parse('https://inventory.invalid/v1/agent/actions'),
            ),
            connector: transport,
          ),
          supportTicketSubmitter: api.supportTicketRepository.submit,
          greetingProfileLoader:
              api.agentHubProfileRepository.fetchGreetingProfile,
          requestBuilder: (message) =>
              buildSessionAgentHubRequest(message, session: api.currentSession),
          voicePlaybackCoordinator: voice,
          voicePlaybackPlayer: api.agentVoicePlaybackPlayer,
          mediaRepository: api.mediaRepository,
          pickImage: api.agentHubImagePicker,
          pickDocument: api.agentHubDocumentPicker,
          onApplicationEvent: api.handleAgentApplicationEvent,
          onArtifactAction: (action) => dispatchAgentArtifactAction(
            context,
            action,
            externalUrlLauncher: launcher,
          ),
        );
      },
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
    await tester.tap(find.text('Cozymate'));
    if (loading) {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    } else {
      await tester.pumpAndSettle();
    }
    expect(router.state.uri.path, '/');
    addTearDown(() async {
      for (final gate in transport.readGates.values) {
        if (!gate.isCompleted) gate.complete();
      }
      if (transport.writeGate case final gate? when !gate.isCompleted) {
        gate.complete();
      }
      launcher.release();
      transport.disposeStreams();
      router.dispose();
      runtime.dispose();
      await platform.dispose();
    });
  }

  Future<void> frame(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  }

  Future<void> tap(WidgetTester tester, Finder target) async {
    if (target.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        target,
        300,
        scrollable: find
            .byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.restorationId != 'editable' &&
                  (widget.axisDirection == AxisDirection.down ||
                      widget.axisDirection == AxisDirection.up),
            )
            .last,
      );
    } else {
      await tester.ensureVisible(target);
    }
    await frame(tester);
    await tester.tap(target);
    await frame(tester);
    expect(tester.takeException(), isNull);
  }

  Future<void> capture(
    WidgetTester tester,
    String state,
    String action, {
    String route = '/',
  }) async {
    // Commit edits and finish the input hint's fade without settling spinners.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(router.state.uri.path, route);
    expect(tester.takeException(), isNull);
    final suffix =
        '${tester.view.physicalSize.width.round()}${tester.platformDispatcher.textScaleFactor > 1 ? '-2x' : ''}';
    final source =
        'test/goldens/ui_inventory/agent-entry-journey-$state-$suffix.png';
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/ui_inventory/agent-entry-journey-$state-$suffix.png',
      ),
    );
    final row = {
      'source': source,
      'previous_source': previous,
      'route': route,
      'trigger': action,
      'root_entry': 'Authenticated More → tap Cozymate bottom navigation',
      'evidence':
          'Actual MomCozyFlutterApp/createMomCozyRouter/AgentHubPage via public agentHubBuilder; production SSE parser, runner with default retries, cancel client and profile repository; isolated SSE/control/ticket HTTP and voice dependencies; production artifact mapper and route dispatch; external launcher controlled at public interface. Motion page is not force mounted and no missing route is added. History disabled as in default local build; no remote model request.',
      'test': 'test/features/agent_hub/agent_entry_inventory_journey_test.dart',
    };
    previous = source;
    final output = Platform.environment['MOMCOZY_UI_INVENTORY_DIR'];
    if (output != null) {
      final file = File(
        '$output/journeys/agent-entry-journey-$state-$suffix.json',
      );
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(row)}\n',
      );
    }
  }

  final input = find.byKey(const ValueKey('agent-composer-input'));
  final sendButton = find.byKey(const ValueKey('agent-send-button'));
  Future<void> send(WidgetTester tester, String message) async {
    await tester.enterText(input, message);
    await tap(tester, sendButton);
  }

  Future<void> finish(
    WidgetTester tester,
    int index,
    String message, {
    int? run,
    int first = 1,
  }) async {
    transport.emit(index, 'message.completed', first, {
      'text': message,
    }, run: run);
    transport.emit(index, 'run.completed', first + 1, {}, run: run);
    await frame(tester);
  }

  Future<void> reveal(WidgetTester tester, Finder target) async {
    if (target.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        target,
        -180,
        scrollable: find.byType(Scrollable).first,
      );
    } else {
      await tester.ensureVisible(target);
    }
    await frame(tester);
  }

  for (final narrow in [false, true]) {
    for (final target in ['forward_head', 'posture_screen']) {
      testWidgets(
        'inventory artifact motion dead end $target ${narrow ? "320/2" : "393/1"}',
        (tester) async {
          await mount(
            tester,
            width: narrow ? 320 : 393,
            textScale: narrow ? 2 : 1,
          );
          await send(
            tester,
            target == 'forward_head' ? '我想看看头颈姿态。' : '我想做体态评估。',
          );
          transport.publish(0, 'artifact.created', 1, {
            'artifact_type': 'motion_assessment_card',
            'schema_version': 'v1',
            'artifact': {
              'id': 'motion-entry',
              'artifact_type': 'motion_assessment_card',
              'schema_version': 'v1',
              'payload': {
                'target': target,
                'user_goal': '查看当前姿态',
                'entry': {
                  'url': '/motion-assessment?target=$target',
                  'label': '开始评估',
                },
                'privacy': {
                  'video_upload_enabled': false,
                  'landmark_upload_enabled': false,
                },
              },
            },
          }, artifactId: 'motion-entry');
          await finish(tester, 0, '可以从评估卡片查看入口。', first: 2);
          await reveal(tester, find.text('开始评估'));
          await capture(
            tester,
            '$target-card',
            'Supported motion artifact arrives → normal card with start CTA',
          );
          await tap(tester, find.text('开始评估'));
          await tester.pumpAndSettle();
          expect(router.state.uri.path, '/');
          expect(find.text('开始评估'), findsOneWidget);
          expect(find.byType(SnackBar), findsNothing);
          expect(launcher.uris, isEmpty);
          expect(transport.requests, hasLength(1));
          await capture(
            tester,
            '$target-no-navigation',
            'Tap start assessment → dispatcher ignores unregistered /motion-assessment, no notice',
          );
          await tap(tester, find.byKey(const ValueKey('bottom-nav-more')));
          await capture(
            tester,
            '$target-away',
            'More tab after unhandled motion CTA',
            route: '/more',
          );
          await tap(tester, find.byKey(const ValueKey('bottom-nav-cozymate')));
          await reveal(tester, find.text('开始评估'));
          await capture(
            tester,
            '$target-return',
            'Cozymate tab → card retained, still no assessment page',
          );
        },
      );
    }
    testWidgets(
      'inventory artifact external link failure and retry ${narrow ? "320/2" : "393/1"}',
      (tester) async {
        await mount(
          tester,
          width: narrow ? 320 : 393,
          textScale: narrow ? 2 : 1,
        );
        await send(tester, '请给我一个参考资料入口。');
        transport.publish(0, 'artifact.created', 1, {
          'artifact_type': 'rich_text',
          'title': '参考资料',
          'content': '点击资料按钮打开外部浏览器。',
          'actions': [
            {
              'kind': 'open_url',
              'label': '打开资料',
              'value': 'https://example.invalid/inventory-guide',
            },
          ],
        }, artifactId: 'external-entry');
        await finish(tester, 0, '你可以从资料卡片继续查看。', first: 2);
        await reveal(tester, find.text('打开资料'));
        await capture(
          tester,
          'external-card',
          'External artifact link appears in the completed reply',
        );
        launcher.gate = Completer<bool>();
        await tap(tester, find.text('打开资料'));
        expect(
          launcher.uris.single.toString(),
          'https://example.invalid/inventory-guide',
        );
        await capture(
          tester,
          'external-pending',
          'Tap external link → launcher pending; card has no progress UI',
        );
        launcher.gate!.complete(false);
        await frame(tester);
        expect(find.text('无法打开链接，请稍后重试'), findsOneWidget);
        await capture(
          tester,
          'external-failed',
          'Launcher returns false → real Snackbar',
        );
        await tester.drag(find.byType(SnackBar), const Offset(0, 180));
        await frame(tester);
        await capture(
          tester,
          'external-dismissed',
          'Dismiss Snackbar → card remains actionable',
        );
        launcher.gate = null;
        launcher.throwOnOpen = true;
        await tap(tester, find.text('打开资料'));
        expect(find.text('无法打开链接，请稍后重试'), findsOneWidget);
        await capture(
          tester,
          'external-thrown',
          'Tap again, launcher throws → same safe Snackbar',
        );
        await tester.drag(find.byType(SnackBar), const Offset(0, 180));
        await frame(tester);
        launcher.throwOnOpen = false;
        await tap(tester, find.text('打开资料'));
        expect(find.byType(SnackBar), findsNothing);
        expect(launcher.uris, hasLength(3));
        await capture(
          tester,
          'external-accepted',
          'Tap again, launcher accepts → App remains on card; browser outside fixture scope',
        );
      },
    );
  }
}

class InventoryLinkLauncher implements ExternalUrlLauncher {
  final uris = <Uri>[];
  Completer<bool>? gate;
  bool throwOnOpen = false;
  @override
  Future<bool> open(Uri uri) async {
    uris.add(uri);
    if (throwOnOpen) throw StateError('isolated launcher failure');
    return gate == null ? true : await gate!.future;
  }

  void release() {
    if (gate case final g? when !g.isCompleted) g.complete(false);
  }
}
