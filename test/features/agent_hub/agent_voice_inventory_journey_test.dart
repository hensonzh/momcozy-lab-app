import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_page.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_runtime.dart';
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
import '../../support/agent_inventory_transport.dart';
import '../../support/fixture_api_transport.dart';
import '../../support/agent_voice_inventory_player.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);
  setUpAll(() => WidgetController.hitTestWarningShouldBeFatal = true);
  late AgentInventoryTransport transport;
  late MomCozyRuntimeController runtime;
  late GoRouter router;
  String? previous;
  late InventoryVoicePlayer player;
  bool failClipboard = false;
  Future<void> frame(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  }

  Future<void> mount(
    WidgetTester tester, {
    void Function(AgentInventoryTransport)? prepare,
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
    player = InventoryVoicePlayer();
    transport = AgentInventoryTransport();
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
        agentVoicePlaybackPlayer: player,
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
          onArtifactAction: (action) =>
              dispatchAgentArtifactAction(context, action),
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
      await frame(tester);
    }
    expect(router.state.uri.path, '/');
    addTearDown(() async {
      for (final gate in transport.readGates.values) {
        if (!gate.isCompleted) gate.complete();
      }
      if (transport.writeGate case final gate? when !gate.isCompleted) {
        gate.complete();
      }
      await player.stop();
      transport.disposeStreams();
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
        'test/goldens/ui_inventory/agent-voice-journey-$state-$suffix.png';
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/ui_inventory/agent-voice-journey-$state-$suffix.png',
      ),
    );
    final row = {
      'source': source,
      'previous_source': previous,
      'route': route,
      'trigger': action,
      'root_entry': 'Authenticated More → tap Cozymate bottom navigation',
      'evidence':
          'Actual MomCozyFlutterApp/createMomCozyRouter/AgentHubPage via public agentHubBuilder; production SSE parser, runner with default retries, cancel client and profile repository; isolated SSE/control HTTP and controllable playback player at public runtime boundary. Voice coordinator, error notice, speaking avatar and replay handlers are production components; no sound output or provider latency measured. History disabled as in default local build; no remote model request.',
      'test': 'test/features/agent_hub/agent_voice_inventory_journey_test.dart',
    };
    previous = source;
    final output = Platform.environment['MOMCOZY_UI_INVENTORY_DIR'];
    if (output != null) {
      final file = File(
        '$output/journeys/agent-voice-journey-$state-$suffix.json',
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

  final toggle = find.byKey(const ValueKey('agent-auto-voice-button'));
  final replay = find.widgetWithText(TextButton, '播放回复');
  final notice = find.text('语音暂时无法播放，你可以继续阅读回复。');
  final speaking = find.byWidgetPredicate(
    (w) => w is Semantics && w.properties.label == '语音播报已启动（AI 合成语音）',
  );
  Future<void> away(WidgetTester tester, String prefix) async {
    await tap(tester, find.byKey(const ValueKey('bottom-nav-more')));
    await capture(
      tester,
      '$prefix-away',
      'Tap More during voice journey',
      route: '/more',
    );
    await tap(tester, find.byKey(const ValueKey('bottom-nav-cozymate')));
    await capture(
      tester,
      '$prefix-return',
      'Tap Cozymate → restored conversation',
    );
  }

  for (final narrow in [false, true]) {
    testWidgets(
      'inventory voice greeting recovery ${narrow ? "320/2" : "393/1"}',
      (tester) async {
        await mount(
          tester,
          width: narrow ? 320 : 393,
          textScale: narrow ? 2 : 1,
        );
        await frame(tester);
        expect(player.plays, hasLength(1));
        expect(speaking, findsOneWidget);
        await capture(
          tester,
          'greeting-playing',
          'More → Cozymate automatically starts greeting playback',
        );
        player.plays.last.completeError(
          StateError('isolated private voice error'),
        );
        await frame(tester);
        expect(notice, findsOneWidget);
        expect(
          find.textContaining('isolated private voice error'),
          findsNothing,
        );
        await capture(
          tester,
          'greeting-failed',
          'Greeting player fails → safe notice and replay',
        );
        await tap(tester, replay);
        expect(player.plays, hasLength(2));
        expect(player.texts.last, player.texts.first);
        expect(transport.requests, isEmpty);
        expect(notice, findsNothing);
        await capture(
          tester,
          'greeting-replaying',
          'Tap replay → greeting restarts without a chat request',
        );
        player.plays.last.complete();
        await frame(tester);
        expect(speaking, findsNothing);
        await capture(
          tester,
          'greeting-finished',
          'Greeting player completes → speaking indicator ends',
        );
        await away(tester, 'greeting-finished');
      },
    );
    testWidgets(
      'inventory voice stream error replay and disable ${narrow ? "320/2" : "393/1"}',
      (tester) async {
        await mount(
          tester,
          width: narrow ? 320 : 393,
          textScale: narrow ? 2 : 1,
        );
        player.plays.last.complete();
        await frame(tester);
        await send(tester, '请朗读这段回复。');
        await capture(
          tester,
          'reply-waiting',
          'Send typed message → waiting for first reply',
        );
        transport.emit(0, 'message.delta', 1, {'text': '一次关注一个变化。'});
        await frame(tester);
        expect(player.sessions, hasLength(1));
        expect(speaking, findsOneWidget);
        await capture(
          tester,
          'reply-stream-playing',
          'First SSE delta → realtime voice session and speaking avatar',
        );
        player.sessions.last.fail();
        await frame(tester);
        expect(notice, findsOneWidget);
        expect(tester.widget<TextButton>(replay).onPressed, isNull);
        await capture(
          tester,
          'reply-stream-failed',
          'Player fails during reply → replay disabled until run ends',
        );
        const answer = '一次关注一个变化。';
        await finish(tester, 0, answer, first: 2);
        expect(tester.widget<TextButton>(replay).onPressed, isNotNull);
        await capture(
          tester,
          'reply-ended-failed',
          'SSE reply completes → replay becomes available',
        );
        await tap(tester, replay);
        expect(player.sessions, hasLength(2));
        expect(player.sessions.last.text, answer);
        expect(player.sessions.last.finished, isTrue);
        expect(transport.requests, hasLength(1));
        await capture(
          tester,
          'reply-replaying',
          'Tap replay → read completed reply without regenerating',
        );
        await tap(tester, toggle);
        expect(player.sessions.last.cancelled, isTrue);
        expect(find.byTooltip('开启实时语音播报'), findsOneWidget);
        await capture(
          tester,
          'reply-off',
          'Turn voice off → active session cancelled',
        );
        await tap(tester, toggle);
        expect(player.sessions, hasLength(2));
        expect(find.byTooltip('关闭实时语音播报'), findsOneWidget);
        await capture(
          tester,
          'reply-on',
          'Turn voice back on → no automatic restart of completed reply',
        );
        await away(tester, 'reply-on');
      },
    );
  }
  testWidgets('inventory voice notice keyboard dismiss and new conversation', (
    tester,
  ) async {
    await mount(tester, width: 320, textScale: 2);
    player.plays.last.completeError(StateError('isolated failure'));
    await frame(tester);
    await tester.tap(input);
    await tester.enterText(input, '保留未发送的草稿');
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await capture(
      tester,
      'keyboard-failed',
      'Focus input with unsent draft → 300dp keyboard inset and voice notice',
    );
    await tap(tester, find.byTooltip('关闭语音提示'));
    expect(notice, findsNothing);
    expect(tester.widget<TextField>(input).controller!.text, '保留未发送的草稿');
    await capture(
      tester,
      'keyboard-dismissed',
      'Dismiss voice notice → draft remains and composer expands',
    );
    tester.view.resetViewInsets();
    tester.testTextInput.hide();
    FocusManager.instance.primaryFocus?.unfocus();
    await frame(tester);
    await tap(tester, find.byTooltip('新建会话'));
    expect(tester.widget<TextField>(input).controller!.text, isEmpty);
    expect(player.plays, hasLength(2));
    await capture(
      tester,
      'new-greeting-playing',
      'New conversation clears draft and starts fresh greeting',
    );
    await tap(tester, toggle);
    expect(player.plays.last.isCompleted, isTrue);
    await capture(
      tester,
      'new-greeting-off',
      'Turn voice off during fresh greeting → stop',
    );
    await away(tester, 'new-greeting-off');
    expect(find.byTooltip('开启实时语音播报'), findsOneWidget);
  });
  testWidgets('inventory voice active reply tab navigation and completion', (
    tester,
  ) async {
    await mount(tester);
    player.plays.last.complete();
    await frame(tester);
    await send(tester, '请读完这段文字。');
    await finish(tester, 0, '这是用于页面盘点的播放示例，尚未结束音频播放。');
    expect(player.sessions, hasLength(1));
    await capture(
      tester,
      'completed-text-playing',
      'Reply text completes while audio remains active',
    );
    await away(tester, 'active-audio');
    expect(player.sessions.single.cancelled, isFalse);
    expect(speaking, findsOneWidget);
    expect(player.sessions, hasLength(1));
    player.sessions.single.completion.complete();
    await frame(tester);
    expect(speaking, findsNothing);
    await capture(
      tester,
      'reply-audio-completed',
      'Original audio session completes after tab return → speaking indicator stops',
    );
  });
  testWidgets('inventory voice later text recovers a failed realtime session', (
    tester,
  ) async {
    await mount(tester);
    player.plays.last.complete();
    await frame(tester);
    await send(tester, '请按顺序朗读。');
    transport.emit(0, 'message.delta', 1, {'text': '第一段测试文字。'});
    await frame(tester);
    player.sessions.single.fail();
    await frame(tester);
    await capture(
      tester,
      'later-text-failed',
      'Realtime player fails after first paragraph',
    );
    transport.emit(0, 'message.delta', 2, {'text': '第二段测试文字。'});
    await frame(tester);
    expect(player.sessions, hasLength(2));
    expect(player.sessions.last.text, '第二段测试文字。');
    expect(notice, findsNothing);
    await capture(
      tester,
      'later-text-recovered',
      'Next SSE delta automatically starts a new player with only the new suffix',
    );
    await finish(tester, 0, '第一段测试文字。第二段测试文字。', first: 3);
    expect(player.sessions.last.finished, isTrue);
    player.sessions.last.fail();
    await frame(tester);
    await capture(
      tester,
      'later-text-terminal-failed',
      'Playback fails after reply finishes → replay entire reply is available',
    );
    await tap(tester, replay);
    expect(player.sessions.last.text, '第一段测试文字。第二段测试文字。');
    expect(transport.requests, hasLength(1));
    await capture(
      tester,
      'later-text-full-replay',
      'Tap replay → both paragraphs submitted to playback',
    );
    player.sessions.last.completion.complete();
    await frame(tester);
    await capture(
      tester,
      'later-text-full-finished',
      'Replayed audio completes successfully',
    );
  });
}
