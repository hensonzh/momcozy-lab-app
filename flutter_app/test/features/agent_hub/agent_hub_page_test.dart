import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/app/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_client.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_event.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_io_transport.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_run_state.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_runner.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_interaction_store.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_page.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_voice.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import '../../support/fixture_reader.dart';

void main() {
  late _FakeVideoPlayerPlatform videoPlayerPlatform;

  setUp(() {
    videoPlayerPlatform = _FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = videoPlayerPlatform;
  });

  test('Agent Hub animated avatar videos exist in the bundled asset tree', () {
    for (final asset in [
      MomCozyAssets.agentThinkingAvatar,
      MomCozyAssets.agentSpeakingAvatar,
    ]) {
      expect(asset.endsWith('.mp4'), isTrue, reason: '$asset should use MP4');
      final file = File(asset);
      expect(file.existsSync(), isTrue, reason: '$asset should be committed');
      expect(file.lengthSync(), greaterThan(0));
      expect(
        File(asset.replaceFirst('.mp4', '.gif')).existsSync(),
        isFalse,
        reason: '$asset should replace the old GIF avatar asset',
      );
    }
  });

  testWidgets('Agent Hub renders idle composer state', (tester) async {
    await tester.pumpWidget(_host(const AgentHubPage()));

    expect(find.byKey(const ValueKey('agent-hub-page')), findsOneWidget);
    expect(find.textContaining('嗨，我是 CozyMate'), findsOneWidget);
    expect(find.textContaining('你希望我怎么称呼你？'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('agent-auto-voice-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('agent-new-session-button')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('agent-composer-input')), findsOneWidget);
    expect(find.byKey(const ValueKey('agent-image-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('agent-voice-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('agent-send-button')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('agent-assistant-avatar-static')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('agent-assistant-avatar-thinking')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('agent-assistant-avatar-speaking')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('agent-response-light-rail')),
      findsNothing,
    );

    final imageButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('agent-image-button')),
    );
    expect(imageButton.onPressed, isNull);
    final voiceButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('agent-voice-button')),
    );
    expect(voiceButton.onPressed, isNull);
    final sendButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('agent-send-button')),
    );
    expect(sendButton.onPressed, isNull);
    _expectComposerControlsInsideSurface(tester);
    _expectComposerControlsVerticallyCentered(tester);
    _expectComposerInputVerticallyCentered(tester);
    _expectComposerSendButtonBreathesVertically(tester);
  });

  testWidgets('Agent Hub shows loop light rail while preparing a reply', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        AgentHubPage(
          state: AgentStreamRunState(
            phase: AgentStreamRunPhase.streaming,
            events: [
              AgentStreamEvent({
                'type': 'run.progress',
                'payload': {'label': '我想一下'},
              }),
            ],
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('agent-response-light-rail')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('agent-response-light-rail-loop')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('agent-response-light-rail-replying')),
      findsNothing,
    );
  });

  testWidgets('Agent Hub switches light rail to replying once text streams', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const AgentHubPage(
          state: AgentStreamRunState(
            phase: AgentStreamRunPhase.streaming,
            textContent: '我整理好了，先看这个方案。',
          ),
        ),
        tickersEnabled: true,
      ),
    );

    expect(
      find.byKey(const ValueKey('agent-response-light-rail')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('agent-response-light-rail-replying')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('agent-response-light-rail-loop')),
      findsNothing,
    );
  });

  testWidgets('Agent Hub keeps the idle greeting near the transcript top', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_host(const AgentHubPage()));

    final chatRect = tester.getRect(
      find.byKey(const ValueKey('agent-chat-scroll-view')),
    );
    final greetingRect = tester.getRect(find.textContaining('嗨，我是 CozyMate'));

    expect(greetingRect.top - chatRect.top, lessThan(120));
  });

  testWidgets('Agent Hub marks active assistant avatar as thinking', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const AgentHubPage(
          state: AgentStreamRunState(
            phase: AgentStreamRunPhase.streaming,
            messageId: 'msg-thinking',
            textContent: 'I am checking your records.',
          ),
        ),
        tickersEnabled: true,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey('agent-assistant-avatar-thinking-media')),
      findsOneWidget,
    );
    expect(videoPlayerPlatform.createdAssets, [
      MomCozyAssets.agentThinkingAvatar,
    ]);
    expect(videoPlayerPlatform.loopingById.values, contains(true));
    expect(videoPlayerPlatform.volumeById.values, contains(0));
    expect(
      MomCozyAssets.agentThinkingAvatar,
      isNot(MomCozyAssets.agentAwakenAvatar),
    );
    expect(
      find.byKey(const ValueKey('agent-assistant-avatar-thinking')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('agent-assistant-avatar-speaking')),
      findsNothing,
    );
  });

  testWidgets('Agent Hub restores history and starts a new local session', (
    tester,
  ) async {
    var newSessionStarted = false;

    await tester.pumpWidget(
      _host(
        AgentHubPage(
          historyMessages: const [
            AgentHubHistoryMessage(
              role: AgentHubHistoryRole.user,
              content: '昨天晚上左侧奶量偏低',
            ),
            AgentHubHistoryMessage(
              role: AgentHubHistoryRole.assistant,
              content: '我建议你先观察舒适度和间隔。',
            ),
          ],
          pickImage: () async => const AgentStreamImageInput(
            dataUrl: 'data:image/png;base64,fixture',
            mimeType: 'image/png',
            name: 'staged-before-new-session.png',
          ),
          onNewSession: () => newSessionStarted = true,
        ),
      ),
    );

    expect(find.byKey(const ValueKey('agent-history-panel')), findsOneWidget);
    expect(find.text('历史会话'), findsNothing);
    expect(find.text('昨天晚上左侧奶量偏低'), findsOneWidget);
    expect(find.text('我建议你先观察舒适度和间隔。'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('agent-composer-input')),
      '开始新的问题',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('agent-image-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('agent-photo-menu')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('agent-photo-upload-button')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('agent-image-attachment-chip')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('agent-new-session-button')));
    await tester.pump();

    expect(newSessionStarted, isTrue);
    expect(find.byKey(const ValueKey('agent-history-panel')), findsNothing);
    expect(find.textContaining('嗨，我是 CozyMate'), findsOneWidget);
    expect(find.byKey(const ValueKey('agent-photo-menu')), findsNothing);
    expect(
      find.byKey(const ValueKey('agent-image-attachment-chip')),
      findsNothing,
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('agent-composer-input')))
          .controller
          ?.text,
      '',
    );
  });

  testWidgets('Agent Hub plays greeting voice for a manual new session', (
    tester,
  ) async {
    final coordinator = AgentVoicePlaybackCoordinator();
    final player = _PageFakeVoicePlaybackPlayer();

    await tester.pumpWidget(
      _host(
        AgentHubPage(
          historyMessages: const [
            AgentHubHistoryMessage(
              role: AgentHubHistoryRole.assistant,
              content: '上一轮建议。',
            ),
          ],
          voicePlaybackCoordinator: coordinator,
          voicePlaybackPlayer: player,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('agent-new-session-button')));
    await tester.pump();

    expect(coordinator.activeSource, AgentVoicePlaybackSource.greeting);
    expect(coordinator.activeId, 'agent-default-greeting');
    expect(find.textContaining('嗨，我是 CozyMate'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('agent-assistant-avatar-speaking')),
      findsOneWidget,
    );

    player.complete();
    await tester.pump();
    await tester.pump();

    expect(coordinator.activeId, isNull);
    expect(
      find.byKey(const ValueKey('agent-assistant-avatar-static')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('agent-assistant-avatar-speaking')),
      findsNothing,
    );
  });

  testWidgets('Agent Hub keeps greeting avatar static without a voice player', (
    tester,
  ) async {
    final coordinator = AgentVoicePlaybackCoordinator();

    await tester.pumpWidget(
      _host(
        AgentHubPage(
          historyMessages: const [
            AgentHubHistoryMessage(
              role: AgentHubHistoryRole.assistant,
              content: '上一轮建议。',
            ),
          ],
          voicePlaybackCoordinator: coordinator,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('agent-new-session-button')));
    await tester.pump();

    expect(coordinator.activeId, isNull);
    expect(find.textContaining('嗨，我是 CozyMate'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('agent-assistant-avatar-static')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('agent-assistant-avatar-speaking')),
      findsNothing,
    );
  });

  testWidgets('Agent Hub does not play greeting voice when auto voice is off', (
    tester,
  ) async {
    final coordinator = AgentVoicePlaybackCoordinator();

    await tester.pumpWidget(
      _host(
        AgentHubPage(
          historyMessages: const [
            AgentHubHistoryMessage(
              role: AgentHubHistoryRole.assistant,
              content: '上一轮建议。',
            ),
          ],
          voicePlaybackCoordinator: coordinator,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('agent-auto-voice-button')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('agent-new-session-button')));
    await tester.pump();

    expect(coordinator.activeId, isNull);
    expect(find.textContaining('嗨，我是 CozyMate'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('agent-assistant-avatar-speaking')),
      findsNothing,
    );
  });

  testWidgets('Agent Hub cancels greeting voice when the user sends a turn', (
    tester,
  ) async {
    final coordinator = AgentVoicePlaybackCoordinator();
    final player = _PageFakeVoicePlaybackPlayer();
    final client = _ControllableAgentStreamClient();

    await tester.pumpWidget(
      _host(
        AgentHubPage(
          runner: AgentStreamRunner(client),
          historyMessages: const [
            AgentHubHistoryMessage(
              role: AgentHubHistoryRole.assistant,
              content: '上一轮建议。',
            ),
          ],
          voicePlaybackCoordinator: coordinator,
          voicePlaybackPlayer: player,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('agent-new-session-button')));
    await tester.pump();

    expect(coordinator.activeSource, AgentVoicePlaybackSource.greeting);
    expect(
      find.byKey(const ValueKey('agent-assistant-avatar-speaking')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('agent-composer-input')),
      '开始正式对话',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('agent-send-button')));
    await tester.pump();

    expect(client.requests, hasLength(1));
    expect(client.requests.single.message, '开始正式对话');
    expect(coordinator.activeId, isNull);
    expect(player.stopCount, 1);
    expect(
      find.byKey(const ValueKey('agent-assistant-avatar-speaking')),
      findsNothing,
    );
  });

  testWidgets('Agent Hub disables new session while a run is active', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const AgentHubPage(
          state: AgentStreamRunState(phase: AgentStreamRunPhase.streaming),
        ),
      ),
    );

    final button = tester.widget<IconButton>(
      find.byKey(const ValueKey('agent-new-session-button')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('Agent Hub sends composer text through the injected runner', (
    tester,
  ) async {
    final client = _FixtureAgentStreamClient(
      parseAgentJsonl(
        readMigrationFixture('agent_events/text_stream_basic.jsonl'),
      ),
    );

    await tester.pumpWidget(
      _host(AgentHubPage(runner: AgentStreamRunner(client))),
    );

    await tester.enterText(
      find.byKey(const ValueKey('agent-composer-input')),
      'Review my pumping pattern',
    );
    await tester.pump();

    final sendButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('agent-send-button')),
    );
    expect(sendButton.onPressed, isNotNull);
    _expectComposerControlsInsideSurface(tester);
    _expectComposerControlsVerticallyCentered(tester);
    _expectComposerInputVerticallyCentered(tester);
    _expectComposerSendButtonBreathesVertically(tester);

    await tester.tap(find.byKey(const ValueKey('agent-send-button')));
    await tester.pumpAndSettle();

    expect(client.requests.single.message, 'Review my pumping pattern');
    expect(client.requests.single.threadId, isNull);
    expect(find.text('Review my pumping pattern'), findsOneWidget);
    expect(
      find.text('I can help you review today\'s pumping pattern.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('agent-composer-input')))
          .controller
          ?.text,
      '',
    );
  });

  testWidgets('Agent Hub renders quick replies as selectable chips', (
    tester,
  ) async {
    final client = _FixtureAgentStreamClient([
      AgentStreamEvent(const {
        'event_id': 'evt-quick-message',
        'type': 'message.completed',
        'thread_id': 'thread-quick',
        'run_id': 'run-quick',
        'message_id': 'msg-quick',
        'sequence': 1,
        'payload': {
          'role': 'assistant',
          'text': '我整理好了。',
          'quick_replies': [
            {'text': '继续聊这个'},
            {'text': '给我更多细节'},
            {'text': '换个方向'},
          ],
        },
      }),
      AgentStreamEvent(const {
        'event_id': 'evt-quick-completed',
        'type': 'run.completed',
        'thread_id': 'thread-quick',
        'run_id': 'run-quick',
        'message_id': 'msg-quick',
        'sequence': 2,
      }),
    ]);
    final recordedClientEvents = <Map<String, Object?>>[];

    await tester.pumpWidget(
      _host(
        AgentHubPage(
          runner: AgentStreamRunner(client),
          clientEventClient: AgentStreamClientEventClient(
            recorder: recordedClientEvents.add,
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('agent-composer-input')),
      '给我一些建议',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('agent-send-button')));
    await tester.pumpAndSettle();

    expect(find.text('我整理好了。'), findsOneWidget);
    expect(find.byKey(const ValueKey('agent-quick-replies')), findsOneWidget);
    expect(find.byKey(const ValueKey('agent-quick-reply-0')), findsOneWidget);
    expect(find.text('继续聊这个'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('agent-quick-reply-0')));
    await tester.pumpAndSettle();

    expect(client.requests, hasLength(2));
    expect(client.requests.last.message, '继续聊这个');
    expect(recordedClientEvents, hasLength(1));
    expect(recordedClientEvents.single['event_type'], 'ui.quick_reply.clicked');
    expect(recordedClientEvents.single['label'], '继续聊这个');
    expect(
      recordedClientEvents.single['metadata'],
      containsPair('quick_reply_text', '继续聊这个'),
    );
  });

  testWidgets('Agent Hub reuses backend thread id across follow-up turns', (
    tester,
  ) async {
    final client = _FixtureAgentStreamClient(
      parseAgentJsonl(
        readMigrationFixture('agent_events/text_stream_basic.jsonl'),
      ),
    );

    await tester.pumpWidget(
      _host(AgentHubPage(runner: AgentStreamRunner(client))),
    );

    await tester.enterText(
      find.byKey(const ValueKey('agent-composer-input')),
      'First turn',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('agent-send-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.enterText(
      find.byKey(const ValueKey('agent-composer-input')),
      'Follow up',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('agent-send-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(client.requests, hasLength(2));
    expect(client.requests.first.threadId, isNull);
    expect(client.requests.last.threadId, 'thread-fixture-001');
    expect(client.requests.last.message, 'Follow up');
    expect(
      find.text('I can help you review today\'s pumping pattern.'),
      findsNWidgets(2),
    );
  });

  testWidgets(
    'Agent Hub preserves the visible greeting before a failed sent turn',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _host(
          AgentHubPage(
            runner: AgentStreamRunner(
              _FailingAgentStreamClient(
                StateError(
                  'SocketException: Failed host lookup: api.momcozy.test',
                ),
              ),
            ),
          ),
        ),
      );

      await tester.enterText(
        find.byKey(const ValueKey('agent-composer-input')),
        'nihao',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('agent-send-button')));
      await tester.pumpAndSettle();

      expect(find.text('nihao'), findsOneWidget);
      expect(find.textContaining('嗨，我是 CozyMate'), findsOneWidget);
      expect(find.textContaining('这次没有拿到回复'), findsOneWidget);
      expect(find.text('网络不可用，请检查连接后重试'), findsOneWidget);

      final chatRect = tester.getRect(
        find.byKey(const ValueKey('agent-chat-scroll-view')),
      );
      final greetingRect = tester.getRect(find.textContaining('嗨，我是 CozyMate'));
      final userRect = tester.getRect(find.text('nihao'));
      final errorRect = tester.getRect(find.textContaining('这次没有拿到回复'));
      final retryRect = tester.getRect(
        find.byKey(const ValueKey('agent-retry-button')),
      );
      expect(greetingRect.top - chatRect.top, lessThan(120));
      expect(userRect.top, greaterThan(greetingRect.bottom));
      expect(errorRect.top, greaterThan(userRect.bottom));
      expect(retryRect.top - chatRect.top, lessThan(360));
    },
  );

  testWidgets('Agent Hub keeps send disabled for empty runner input', (
    tester,
  ) async {
    final client = _FixtureAgentStreamClient(
      parseAgentJsonl(
        readMigrationFixture('agent_events/text_stream_basic.jsonl'),
      ),
    );

    await tester.pumpWidget(
      _host(AgentHubPage(runner: AgentStreamRunner(client))),
    );

    final sendButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('agent-send-button')),
    );
    expect(sendButton.onPressed, isNull);

    await tester.tap(
      find.byKey(const ValueKey('agent-send-button')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    expect(client.requests, isEmpty);
  });

  testWidgets('Agent Hub attaches image input to the next request', (
    tester,
  ) async {
    final client = _FixtureAgentStreamClient(
      parseAgentJsonl(
        readMigrationFixture('agent_events/text_stream_basic.jsonl'),
      ),
    );

    await tester.pumpWidget(
      _host(
        AgentHubPage(
          runner: AgentStreamRunner(client),
          pickImage: () async => const AgentStreamImageInput(
            dataUrl:
                'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=',
            mimeType: 'image/png',
            name: 'pump-display.png',
            size: 68,
            detail: 'low',
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('agent-image-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('agent-photo-menu')), findsOneWidget);
    expect(find.text('拍照'), findsOneWidget);
    expect(find.text('上传'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('agent-image-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('agent-photo-menu')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('agent-image-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('agent-photo-upload-button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('agent-image-attachment-chip')),
      findsOneWidget,
    );
    expect(find.text('图片 1'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('agent-composer-input')),
      'Review this display',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('agent-send-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(client.requests.single.message, 'Review this display');
    expect(client.requests.single.images, hasLength(1));
    expect(client.requests.single.images.single.name, 'pump-display.png');
    expect(
      find.byKey(const ValueKey('agent-image-attachment-chip')),
      findsNothing,
    );
  });

  testWidgets('Agent Hub removes image attachment before sending', (
    tester,
  ) async {
    final client = _FixtureAgentStreamClient(
      parseAgentJsonl(
        readMigrationFixture('agent_events/text_stream_basic.jsonl'),
      ),
    );

    await tester.pumpWidget(
      _host(
        AgentHubPage(
          runner: AgentStreamRunner(client),
          pickImage: () async => const AgentStreamImageInput(
            dataUrl: 'data:image/png;base64,fixture',
            mimeType: 'image/png',
            name: 'before-send.png',
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('agent-image-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('agent-photo-upload-button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('agent-image-attachment-chip')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('agent-send-button')))
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.byKey(const ValueKey('agent-remove-image-button')));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('agent-image-attachment-chip')),
      findsNothing,
    );
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('agent-send-button')))
          .onPressed,
      isNull,
    );

    await tester.enterText(
      find.byKey(const ValueKey('agent-composer-input')),
      'Send text only',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('agent-send-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(client.requests.single.message, 'Send text only');
    expect(client.requests.single.images, isEmpty);
  });

  testWidgets('Agent Hub restores draft and image attachment by cache key', (
    tester,
  ) async {
    final cacheKey = Object();
    final client = _FixtureAgentStreamClient(
      parseAgentJsonl(
        readMigrationFixture('agent_events/text_stream_basic.jsonl'),
      ),
    );

    await tester.pumpWidget(
      _host(
        AgentHubPage(
          stateCacheKey: cacheKey,
          runner: AgentStreamRunner(client),
          pickImage: () async => const AgentStreamImageInput(
            dataUrl: 'data:image/png;base64,fixture',
            mimeType: 'image/png',
            name: 'retained-across-tab.png',
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('agent-composer-input')),
      '跨模块回来继续问',
    );
    await tester.tap(find.byKey(const ValueKey('agent-image-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('agent-photo-upload-button')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('agent-image-attachment-chip')),
      findsOneWidget,
    );

    await tester.pumpWidget(_host(const SizedBox.shrink()));
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      _host(
        AgentHubPage(
          stateCacheKey: cacheKey,
          runner: AgentStreamRunner(client),
          pickImage: () async => const AgentStreamImageInput(
            dataUrl: 'data:image/png;base64,fixture',
            mimeType: 'image/png',
            name: 'retained-across-tab.png',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('agent-composer-input')))
          .controller
          ?.text,
      '跨模块回来继续问',
    );
    expect(
      find.byKey(const ValueKey('agent-image-attachment-chip')),
      findsOneWidget,
    );
    expect(find.text('图片 1'), findsOneWidget);
  });

  testWidgets('Agent Hub clears cached active runs when restored', (
    tester,
  ) async {
    final cacheKey = Object();
    final client = _NeverEndingAgentStreamClient();
    addTearDown(client.dispose);

    await tester.pumpWidget(
      _host(
        AgentHubPage(
          stateCacheKey: cacheKey,
          runner: AgentStreamRunner(client),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('agent-composer-input')),
      '生成今日建议',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('agent-send-button')));
    await tester.pump();
    await tester.pump();

    expect(client.requests, hasLength(1));
    expect(find.byKey(const ValueKey('agent-run-status-line')), findsOneWidget);
    expect(find.text('我已经收到你的消息啦～'), findsOneWidget);
    expect(find.byKey(const ValueKey('agent-stop-button')), findsOneWidget);

    await tester.pumpWidget(_host(const SizedBox.shrink()));
    await tester.pump();

    await tester.pumpWidget(
      _host(
        AgentHubPage(
          stateCacheKey: cacheKey,
          runner: AgentStreamRunner(client),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('agent-run-status-line')), findsNothing);
    expect(find.byKey(const ValueKey('agent-stop-button')), findsNothing);
    expect(find.text('连接中断，请重试'), findsOneWidget);
    expect(find.byKey(const ValueKey('agent-retry-button')), findsOneWidget);
  });

  testWidgets('Agent Hub sends image-only request with legacy prompt', (
    tester,
  ) async {
    final client = _FixtureAgentStreamClient(
      parseAgentJsonl(
        readMigrationFixture('agent_events/text_stream_basic.jsonl'),
      ),
    );

    await tester.pumpWidget(
      _host(
        AgentHubPage(
          runner: AgentStreamRunner(client),
          pickImage: () async => const AgentStreamImageInput(
            dataUrl: 'data:image/png;base64,fixture',
            mimeType: 'image/png',
            name: 'only-image.png',
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('agent-image-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('agent-photo-camera-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('agent-send-button')));
    await tester.pumpAndSettle();

    expect(client.requests.single.message, '请看这张图片');
    expect(client.requests.single.images.single.name, 'only-image.png');
  });

  testWidgets('Agent Hub applies initial composer prefill', (tester) async {
    await tester.pumpWidget(
      _host(const AgentHubPage(initialComposerText: '我想调整今天的吸乳排期')),
    );

    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('agent-composer-input')))
          .controller
          ?.text,
      '我想调整今天的吸乳排期',
    );
  });

  testWidgets('Agent Hub can auto-send an initial composer prefill once', (
    tester,
  ) async {
    final client = _ControllableAgentStreamClient();

    await tester.pumpWidget(
      _host(
        AgentHubPage(
          runner: AgentStreamRunner(client),
          initialComposerText: '我想调整今天的吸乳排期',
          initialAutoSend: true,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(client.requests, hasLength(1));
    expect(client.requests.single.message, '我想调整今天的吸乳排期');
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('agent-composer-input')))
          .controller
          ?.text,
      isEmpty,
    );

    await tester.pumpWidget(
      _host(
        AgentHubPage(
          runner: AgentStreamRunner(client),
          initialComposerText: '我想调整今天的吸乳排期',
          initialAutoSend: true,
        ),
      ),
    );
    await tester.pump();

    expect(client.requests, hasLength(1));
  });

  testWidgets('Agent Hub voice input fills composer without sending', (
    tester,
  ) async {
    final client = _FixtureAgentStreamClient(
      parseAgentJsonl(
        readMigrationFixture('agent_events/text_stream_basic.jsonl'),
      ),
    );

    await tester.pumpWidget(
      _host(
        AgentHubPage(
          runner: AgentStreamRunner(client),
          voiceInput: () async {
            await Future<void>.delayed(Duration.zero);
            return '今天左侧奶量偏低';
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('agent-voice-button')));
    await tester.pump();
    final holdGesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('agent-voice-hold-button'))),
    );
    await tester.pump();
    expect(find.textContaining('我在听'), findsOneWidget);
    await holdGesture.up();
    await tester.pumpAndSettle();

    expect(client.requests, isEmpty);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('agent-composer-input')))
          .controller
          ?.text,
      '今天左侧奶量偏低',
    );
    expect(find.byKey(const ValueKey('agent-voice-status')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('agent-send-button')));
    await tester.pumpAndSettle();

    expect(client.requests.single.message, '今天左侧奶量偏低');
  });

  testWidgets('Agent Hub voice button enters hold mode before transcription', (
    tester,
  ) async {
    var voiceCaptures = 0;
    final client = _FixtureAgentStreamClient(
      parseAgentJsonl(
        readMigrationFixture('agent_events/text_stream_basic.jsonl'),
      ),
    );

    await tester.pumpWidget(
      _host(
        AgentHubPage(
          runner: AgentStreamRunner(client),
          voiceInput: () async {
            voiceCaptures += 1;
            return '语音草稿';
          },
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('agent-composer-input')),
      '原始草稿',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('agent-voice-button')));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('agent-voice-hold-button')),
      findsOneWidget,
    );
    expect(find.text('按住说话'), findsOneWidget);
    expect(find.text('原始草稿'), findsNothing);
    expect(voiceCaptures, 0);

    final holdGesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('agent-voice-hold-button'))),
    );
    await tester.pump();
    expect(find.textContaining('我在听'), findsOneWidget);
    await holdGesture.up();
    await tester.pumpAndSettle();

    expect(voiceCaptures, 1);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('agent-composer-input')))
          .controller
          ?.text,
      '语音草稿',
    );
    expect(client.requests, isEmpty);
  });

  testWidgets('Agent Hub surfaces denied microphone permission', (
    tester,
  ) async {
    final client = _FixtureAgentStreamClient(
      parseAgentJsonl(
        readMigrationFixture('agent_events/text_stream_basic.jsonl'),
      ),
    );
    final recorder = _PageFakeVoiceRecorder(
      initialPermission: AgentVoiceInputPermissionState.unknown,
      requestResult: AgentVoiceInputPermissionState.denied,
    );

    await tester.pumpWidget(
      _host(
        AgentHubPage(
          runner: AgentStreamRunner(client),
          voiceInputController: AgentVoiceInputController(
            recorder: recorder,
            transcriber: _PageFakeVoiceTranscriber('ignored'),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('agent-voice-button')));
    await tester.pump();
    final holdGesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('agent-voice-hold-button'))),
    );
    await tester.pump();
    await holdGesture.up();
    await tester.pumpAndSettle();

    expect(find.text('麦克风权限未开启'), findsOneWidget);
    expect(recorder.calls, ['permissionState', 'requestPermission']);
    expect(client.requests, isEmpty);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('agent-composer-input')))
          .controller
          ?.text,
      '',
    );
  });

  testWidgets('Agent Hub starts auto voice playback after finished reply', (
    tester,
  ) async {
    final coordinator = AgentVoicePlaybackCoordinator();
    final player = _PageFakeVoicePlaybackPlayer();
    final client = _FixtureAgentStreamClient(
      parseAgentJsonl(
        readMigrationFixture('agent_events/text_stream_basic.jsonl'),
      ),
    );

    await tester.pumpWidget(
      _host(
        AgentHubPage(
          runner: AgentStreamRunner(client),
          voicePlaybackCoordinator: coordinator,
          voicePlaybackPlayer: player,
        ),
        tickersEnabled: true,
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('agent-composer-input')),
      'Read this aloud',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('agent-send-button')));
    await _pumpUntil(
      tester,
      () => coordinator.activeSource == AgentVoicePlaybackSource.autoReply,
    );
    await _pumpFrames(tester, 3);

    expect(coordinator.activeSource, AgentVoicePlaybackSource.autoReply);
    expect(coordinator.activeId, 'msg-reply-text-001');
    expect(find.text('正在播放语音'), findsNothing);
    expect(find.byKey(const ValueKey('agent-voice-status')), findsNothing);
    expect(
      find.byKey(const ValueKey('agent-assistant-avatar-speaking')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('agent-assistant-avatar-speaking-media')),
      findsOneWidget,
    );
    expect(
      videoPlayerPlatform.createdAssets,
      contains(MomCozyAssets.agentSpeakingAvatar),
    );
    expect(
      MomCozyAssets.agentSpeakingAvatar,
      isNot(MomCozyAssets.agentAwakenAvatar),
    );
    expect(
      find.byKey(const ValueKey('agent-assistant-avatar-thinking')),
      findsNothing,
    );
  });

  testWidgets('Agent Hub sends generated reply chunks to the voice player', (
    tester,
  ) async {
    final coordinator = AgentVoicePlaybackCoordinator();
    final player = _PageFakeVoicePlaybackPlayer();
    final client = _FixtureAgentStreamClient(
      parseAgentJsonl(
        readMigrationFixture('agent_events/text_stream_basic.jsonl'),
      ),
    );

    await tester.pumpWidget(
      _host(
        AgentHubPage(
          runner: AgentStreamRunner(client),
          voicePlaybackCoordinator: coordinator,
          voicePlaybackPlayer: player,
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('agent-composer-input')),
      'Read this aloud',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('agent-send-button')));
    await tester.pumpAndSettle();

    expect(player.playedTexts, ['I can help']);
    expect(coordinator.activeSource, AgentVoicePlaybackSource.autoReply);

    player.complete();
    await tester.pump();
    await tester.pump();

    expect(player.playedTexts, [
      'I can help',
      " you review today's pumping pattern.",
    ]);
    expect(coordinator.activeSource, AgentVoicePlaybackSource.autoReply);

    player.complete();
    await tester.pump();
    await tester.pump();

    expect(coordinator.activeSource, isNull);
    expect(
      find.byKey(const ValueKey('agent-assistant-avatar-speaking')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('agent-assistant-avatar-speaking-media')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('agent-assistant-avatar-static')),
      findsWidgets,
    );
  });

  testWidgets('Agent Hub starts voice as soon as reply text is generated', (
    tester,
  ) async {
    final coordinator = AgentVoicePlaybackCoordinator();
    final player = _PageFakeVoicePlaybackPlayer();
    final client = _ControllableAgentStreamClient();
    addTearDown(client.dispose);

    await tester.pumpWidget(
      _host(
        AgentHubPage(
          runner: AgentStreamRunner(client),
          voicePlaybackCoordinator: coordinator,
          voicePlaybackPlayer: player,
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('agent-composer-input')),
      'Read this aloud after completion',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('agent-send-button')));
    await tester.pump();

    client.emit(
      0,
      AgentStreamEvent({
        'event_id': 'evt-voice-order-delta',
        'type': 'message.delta',
        'thread_id': 'thread-voice-order',
        'run_id': 'run-voice-order',
        'message_id': 'msg-voice-order',
        'sequence': 1,
        'payload': {'text': 'Draft answer'},
      }),
    );
    await tester.pump();
    await tester.pump();

    expect(player.playedTexts, ['Draft answer']);
    expect(coordinator.activeSource, AgentVoicePlaybackSource.autoReply);
    expect(find.text('Draft answer', findRichText: true), findsOneWidget);

    client.emit(
      0,
      AgentStreamEvent({
        'event_id': 'evt-voice-order-completed',
        'type': 'message.completed',
        'thread_id': 'thread-voice-order',
        'run_id': 'run-voice-order',
        'message_id': 'msg-voice-order',
        'sequence': 2,
        'payload': {'text': 'Draft answer ready.'},
      }),
    );
    await tester.pump();
    await tester.pump();

    expect(player.playedTexts, ['Draft answer']);
    expect(coordinator.activeSource, AgentVoicePlaybackSource.autoReply);
    expect(
      find.text('Draft answer ready.', findRichText: true),
      findsOneWidget,
    );

    player.complete();
    await tester.pump();
    await tester.pump();

    expect(player.playedTexts, ['Draft answer', ' ready.']);
    expect(coordinator.activeSource, AgentVoicePlaybackSource.autoReply);

    client.emit(
      0,
      AgentStreamEvent({
        'event_id': 'evt-voice-order-run-completed',
        'type': 'run.completed',
        'thread_id': 'thread-voice-order',
        'run_id': 'run-voice-order',
        'message_id': 'msg-voice-order',
        'sequence': 3,
        'payload': {'status': 'completed'},
      }),
    );
    await tester.pump();
    await tester.pump();

    expect(player.playedTexts, ['Draft answer', ' ready.']);
    expect(coordinator.activeSource, AgentVoicePlaybackSource.autoReply);
    expect(coordinator.activeId, 'msg-voice-order');
  });

  testWidgets(
    'Agent Hub keeps auto voice stable when message id arrives late',
    (tester) async {
      final coordinator = AgentVoicePlaybackCoordinator();
      final player = _PageFakeVoicePlaybackPlayer();
      final client = _ControllableAgentStreamClient();
      addTearDown(client.dispose);

      await tester.pumpWidget(
        _host(
          AgentHubPage(
            runner: AgentStreamRunner(client),
            voicePlaybackCoordinator: coordinator,
            voicePlaybackPlayer: player,
          ),
        ),
      );

      await tester.enterText(
        find.byKey(const ValueKey('agent-composer-input')),
        'Read this aloud while streaming',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('agent-send-button')));
      await tester.pump();

      client.emit(
        0,
        AgentStreamEvent({
          'event_id': 'evt-voice-late-id-delta',
          'type': 'message.delta',
          'thread_id': 'thread-voice-late-id',
          'run_id': 'run-voice-late-id',
          'sequence': 1,
          'payload': {'text': 'Draft answer'},
        }),
      );
      await tester.pump();
      await tester.pump();

      expect(player.playedTexts, ['Draft answer']);
      expect(player.stopCount, 0);
      expect(coordinator.activeSource, AgentVoicePlaybackSource.autoReply);
      expect(coordinator.activeId, 'run-voice-late-id');

      client.emit(
        0,
        AgentStreamEvent({
          'event_id': 'evt-voice-late-id-completed',
          'type': 'message.completed',
          'thread_id': 'thread-voice-late-id',
          'run_id': 'run-voice-late-id',
          'message_id': 'msg-voice-late-id',
          'sequence': 2,
          'payload': {'text': 'Draft answer ready.'},
        }),
      );
      await tester.pump();
      await tester.pump();

      expect(player.playedTexts, ['Draft answer']);
      expect(player.stopCount, 0);
      expect(coordinator.activeId, 'run-voice-late-id');
      expect(
        find.byKey(const ValueKey('agent-assistant-avatar-speaking')),
        findsOneWidget,
      );

      player.complete();
      await tester.pump();
      await tester.pump();

      expect(player.playedTexts, ['Draft answer', ' ready.']);
      expect(player.stopCount, 0);
      expect(coordinator.activeId, 'run-voice-late-id');
    },
  );

  testWidgets('Agent Hub cancels active auto voice when voice is disabled', (
    tester,
  ) async {
    final coordinator = AgentVoicePlaybackCoordinator();
    var playbackCancelled = false;
    final client = _FixtureAgentStreamClient(
      parseAgentJsonl(
        readMigrationFixture('agent_events/text_stream_basic.jsonl'),
      ),
    );

    await tester.pumpWidget(
      _host(
        AgentHubPage(
          runner: AgentStreamRunner(client),
          voicePlaybackCoordinator: coordinator,
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('agent-composer-input')),
      'Read this aloud',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('agent-send-button')));
    await tester.pumpAndSettle();

    coordinator.cancel();
    coordinator.request(
      id: 'msg-reply-text-001',
      source: AgentVoicePlaybackSource.autoReply,
      cancel: () => playbackCancelled = true,
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('agent-auto-voice-button')));
    await tester.pump();

    expect(playbackCancelled, isTrue);
    expect(coordinator.activeId, isNull);
    expect(find.text('正在播放语音'), findsNothing);
    expect(
      find.byKey(const ValueKey('agent-assistant-avatar-speaking')),
      findsNothing,
    );
  });

  testWidgets('Agent Hub keeps notification voice ahead of auto reply', (
    tester,
  ) async {
    final coordinator = AgentVoicePlaybackCoordinator();
    var notificationCancelled = false;
    coordinator.request(
      id: 'notification-1',
      source: AgentVoicePlaybackSource.notification,
      cancel: () => notificationCancelled = true,
    );
    final client = _FixtureAgentStreamClient(
      parseAgentJsonl(
        readMigrationFixture('agent_events/text_stream_basic.jsonl'),
      ),
    );

    await tester.pumpWidget(
      _host(
        AgentHubPage(
          runner: AgentStreamRunner(client),
          voicePlaybackCoordinator: coordinator,
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('agent-composer-input')),
      'Do not interrupt notification',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('agent-send-button')));
    await tester.pumpAndSettle();

    expect(notificationCancelled, isFalse);
    expect(coordinator.activeSource, AgentVoicePlaybackSource.notification);
    expect(coordinator.activeId, 'notification-1');
    expect(find.text('正在播放语音'), findsNothing);
  });

  testWidgets(
    'Agent Hub retries auto voice after notification voice becomes idle',
    (tester) async {
      final coordinator = AgentVoicePlaybackCoordinator();
      final player = _PageFakeVoicePlaybackPlayer();
      final notification = coordinator.request(
        id: 'notification-1',
        source: AgentVoicePlaybackSource.notification,
      );
      final client = _FixtureAgentStreamClient(
        parseAgentJsonl(
          readMigrationFixture('agent_events/text_stream_basic.jsonl'),
        ),
      );

      await tester.pumpWidget(
        _host(
          AgentHubPage(
            runner: AgentStreamRunner(client),
            voicePlaybackCoordinator: coordinator,
            voicePlaybackPlayer: player,
          ),
        ),
      );

      await tester.enterText(
        find.byKey(const ValueKey('agent-composer-input')),
        'Replay after notification',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('agent-send-button')));
      await tester.pumpAndSettle();

      expect(coordinator.activeSource, AgentVoicePlaybackSource.notification);
      expect(coordinator.activeId, 'notification-1');
      expect(find.text('正在播放语音'), findsNothing);

      notification.handle?.finish();
      await tester.pump();
      await tester.pump();

      expect(coordinator.activeSource, AgentVoicePlaybackSource.autoReply);
      expect(coordinator.activeId, 'msg-reply-text-001');
      expect(player.playedTexts, [
        "I can help you review today's pumping pattern.",
      ]);
      expect(find.text('正在播放语音'), findsNothing);
      expect(
        find.byKey(const ValueKey('agent-assistant-avatar-speaking')),
        findsOneWidget,
      );
    },
  );

  testWidgets('Agent Hub can locally stop an active run', (tester) async {
    await tester.pumpWidget(
      _host(
        const AgentHubPage(
          state: AgentStreamRunState(
            phase: AgentStreamRunPhase.streaming,
            textContent: 'Partial answer',
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('agent-run-status-line')), findsNothing);
    expect(find.text('Partial answer'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('agent-stop-button')));
    await tester.pump();

    expect(find.text('已停止本次回复'), findsOneWidget);
  });

  testWidgets(
    'Agent Hub sends follow-up content while interrupting an active run',
    (tester) async {
      final client = _ControllableAgentStreamClient();
      final cancelConnector = _RecordingCancelConnector();
      final cancelClient = AgentStreamCancelClient(
        endpoint: AgentStreamEndpoint(
          uri: Uri.parse('http://127.0.0.1:8769/v1/agent/runs'),
        ),
        connector: cancelConnector,
      );

      await tester.pumpWidget(
        _host(
          AgentHubPage(
            runner: AgentStreamRunner(client),
            cancelClient: cancelClient,
          ),
        ),
      );

      await tester.enterText(
        find.byKey(const ValueKey('agent-composer-input')),
        'First turn',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('agent-send-button')));
      await tester.pump();

      client.emit(
        0,
        AgentStreamEvent(const {
          'type': 'message.delta',
          'thread_id': 'thread-followup',
          'run_id': 'run-first',
          'message_id': 'msg-first',
          'payload': {'text': 'Partial first answer'},
        }),
      );
      await tester.pump();

      expect(client.requests, hasLength(1));
      expect(find.text('Partial first answer'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('agent-composer-input')),
            )
            .enabled,
        isTrue,
      );

      await tester.enterText(
        find.byKey(const ValueKey('agent-composer-input')),
        'Second turn',
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('agent-send-button')), findsOneWidget);
      expect(find.byKey(const ValueKey('agent-stop-button')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('agent-send-button')));
      await tester.pump();
      await cancelConnector.called.future;

      expect(client.requests, hasLength(2));
      expect(client.requests.last.message, 'Second turn');
      expect(client.requests.last.threadId, 'thread-followup');
      expect(cancelConnector.uri!.path, '/v1/agent/runs/run-first/cancel');
      expect(find.text('Partial first answer'), findsOneWidget);
    },
  );

  testWidgets('Agent Hub posts best-effort cancel for active runner', (
    tester,
  ) async {
    final cancelConnector = _RecordingCancelConnector();

    await tester.pumpWidget(
      _host(
        AgentHubPage(
          state: const AgentStreamRunState(
            phase: AgentStreamRunPhase.streaming,
            threadId: 'thread-demo',
            runId: 'run-demo',
            textContent: 'Partial answer',
          ),
          cancelClient: AgentStreamCancelClient(
            endpoint: AgentStreamEndpoint(
              uri: Uri.parse('http://127.0.0.1:8769/v1/agent/runs'),
            ),
            connector: cancelConnector,
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('agent-run-status-line')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('agent-stop-button')));
    await tester.pump();
    await cancelConnector.called.future;

    final body = jsonDecode(cancelConnector.body!) as Map<String, Object?>;
    expect(find.text('已停止本次回复'), findsOneWidget);
    expect(cancelConnector.uri!.path, '/v1/agent/runs/run-demo/cancel');
    expect(body['reason'], 'user_cancelled');
    expect(body.containsKey('user_id'), isFalse);
  });

  testWidgets('Agent Hub retries the last request after disconnect', (
    tester,
  ) async {
    final client = _RetryAgentStreamClient();

    await tester.pumpWidget(
      _host(AgentHubPage(runner: AgentStreamRunner(client))),
    );

    await tester.enterText(
      find.byKey(const ValueKey('agent-composer-input')),
      'Retry my request',
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('agent-send-button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('socket closed'), findsOneWidget);
    expect(find.byKey(const ValueKey('agent-retry-button')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('agent-retry-button')));
    await tester.pumpAndSettle();

    expect(client.requests, hasLength(2));
    expect(client.requests.first.message, 'Retry my request');
    expect(client.requests.last.message, 'Retry my request');
    expect(client.requests.last.runId, 'run-first');
    expect(client.requests.last.afterSequence, 2);
    expect(find.text('Retried answer'), findsOneWidget);
  });

  testWidgets('Agent Hub maps backend timeout to retryable copy', (
    tester,
  ) async {
    final client = _FailingAgentStreamClient(
      TimeoutException('agent request timeout'),
    );

    await tester.pumpWidget(
      _host(AgentHubPage(runner: AgentStreamRunner(client))),
    );

    await tester.enterText(
      find.byKey(const ValueKey('agent-composer-input')),
      'Check my records',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('agent-send-button')));
    await tester.pumpAndSettle();

    expect(find.text('请求超时，请稍后重试'), findsOneWidget);
    expect(find.byKey(const ValueKey('agent-retry-button')), findsOneWidget);
    expect(find.textContaining('TimeoutException'), findsNothing);
    expect(find.textContaining('agent request timeout'), findsNothing);
  });

  testWidgets('Agent Hub maps offline send failure to retryable copy', (
    tester,
  ) async {
    final client = _FailingAgentStreamClient(
      StateError('SocketException: Failed host lookup: api.momcozy.test'),
    );

    await tester.pumpWidget(
      _host(AgentHubPage(runner: AgentStreamRunner(client))),
    );

    await tester.enterText(
      find.byKey(const ValueKey('agent-composer-input')),
      'Send while offline',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('agent-send-button')));
    await tester.pumpAndSettle();

    expect(find.text('网络不可用，请检查连接后重试'), findsOneWidget);
    expect(find.byKey(const ValueKey('agent-retry-button')), findsOneWidget);
    expect(find.textContaining('SocketException'), findsNothing);
    expect(find.textContaining('api.momcozy.test'), findsNothing);
  });

  testWidgets('Agent Hub hides tool progress internals from stream events', (
    tester,
  ) async {
    final client = _FixtureAgentStreamClient(
      parseAgentJsonl(
        readMigrationFixture('agent_events/tool_call_lifecycle.jsonl'),
      ),
    );

    await tester.pumpWidget(
      _host(AgentHubPage(runner: AgentStreamRunner(client))),
    );

    await tester.enterText(
      find.byKey(const ValueKey('agent-composer-input')),
      'Review my pump sessions',
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('agent-send-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('agent-work-panel')), findsNothing);
    expect(find.text('处理进度'), findsNothing);
    expect(find.text('已生成分析卡片'), findsWidgets);
    expect(
      find.text('I found two sessions today and prepared a draft analysis.'),
      findsOneWidget,
    );
    expect(find.textContaining('pump_session_summary_query'), findsNothing);
    expect(find.textContaining('{"ok"'), findsNothing);
  });

  testWidgets('Agent Hub merges tool progress by payload tool call id', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        AgentHubPage(
          state: AgentStreamRunState(
            phase: AgentStreamRunPhase.finished,
            textContent: '已完成。',
            events: [
              AgentStreamEvent(const {
                'type': 'tool.started',
                'thread_id': 'thread-tool',
                'run_id': 'run-tool',
                'payload': {
                  'tool_call_id': 'call-pump-summary',
                  'tool_name': 'pump_session_summary_query',
                },
              }),
              AgentStreamEvent(const {
                'type': 'tool.completed',
                'thread_id': 'thread-tool',
                'run_id': 'run-tool',
                'payload': {
                  'tool_call_id': 'call-pump-summary',
                  'tool_name': 'pump_session_summary_query',
                },
              }),
            ],
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('agent-work-panel')), findsNothing);
    expect(find.text('处理进度'), findsNothing);
    expect(find.text('泵奶记录已读取'), findsNothing);
    expect(find.text('正在读取泵奶记录'), findsNothing);
  });

  testWidgets('Agent Hub renders and confirms production action cards', (
    tester,
  ) async {
    const actionId = '11111111-1111-1111-1111-111111111111';
    final connector = _RecordingActionConnector(
      response: AgentStreamControlHttpResponse(
        statusCode: 200,
        body: jsonEncode({
          'id': actionId,
          'run_id': 'run-action',
          'status': 'queued',
          'events': [
            {
              'type': 'action.queued',
              'thread_id': 'thread-action',
              'run_id': 'run-action',
              'action_id': actionId,
              'payload': {'status': 'queued'},
            },
            {
              'type': 'run.completed',
              'thread_id': 'thread-action',
              'run_id': 'run-action',
            },
          ],
        }),
      ),
    );
    final actionClient = AgentStreamActionClient(
      endpoint: AgentStreamEndpoint(
        uri: Uri.parse('http://127.0.0.1:8769/v1/agent/actions'),
        token: 'secret-token',
      ),
      connector: connector,
    );

    await tester.pumpWidget(
      _host(
        AgentHubPage(
          state: AgentStreamRunState(
            phase: AgentStreamRunPhase.waitingForConfirmation,
            textContent: '请确认是否创建支持工单。',
            events: [
              AgentStreamEvent(const {
                'type': 'action.confirmation_required',
                'thread_id': 'thread-action',
                'run_id': 'run-action',
                'action_id': actionId,
                'payload': {
                  'action_type': 'support_ticket_create',
                  'summary': '将当前问题提交给人工支持团队',
                  'preview_payload': {'title': '创建支持工单'},
                },
              }),
              AgentStreamEvent(const {
                'type': 'run.waiting_for_confirmation',
                'thread_id': 'thread-action',
                'run_id': 'run-action',
                'payload': {'pending_action_id': actionId},
              }),
            ],
          ),
          runner: AgentStreamRunner(_FixtureAgentStreamClient(const [])),
          actionClient: actionClient,
          pickImage: () async => const AgentStreamImageInput(
            dataUrl: 'data:image/png;base64,fixture',
            mimeType: 'image/png',
            name: 'blocked-during-confirmation.png',
          ),
          voiceInput: () async => '待确认时不能覆盖输入框',
        ),
      ),
    );

    expect(find.text('待确认'), findsWidgets);
    expect(find.text('等待确认后继续'), findsOneWidget);
    expect(find.byKey(const ValueKey('agent-action-panel')), findsOneWidget);
    expect(find.byKey(ValueKey('agent-action-card-$actionId')), findsOneWidget);
    expect(find.text('创建支持工单'), findsOneWidget);
    expect(find.text('将当前问题提交给人工支持团队'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('agent-composer-input')))
          .enabled,
      isFalse,
    );
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('agent-image-button')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('agent-voice-button')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('agent-send-button')))
          .onPressed,
      isNull,
    );

    await tester.tap(find.byKey(ValueKey('agent-action-confirm-$actionId')));
    await connector.called.future;
    await tester.pumpAndSettle();

    expect(connector.uri!.path, '/v1/agent/actions/$actionId/confirm');
    expect(
      connector.uri!.queryParameters,
      isNot(containsPair('token', anything)),
    );
    expect(
      connector.headers,
      containsPair('Authorization', 'Bearer secret-token'),
    );
    expect(
      connector.headers,
      containsPair('Idempotency-Key', 'agent-action-$actionId'),
    );
    expect(jsonDecode(connector.body!) as Map<String, Object?>, isEmpty);
    expect(find.text('等待确认后继续'), findsNothing);
    expect(find.text('已提交'), findsOneWidget);
    expect(
      find.byKey(ValueKey('agent-action-confirm-$actionId')),
      findsNothing,
    );
  });

  testWidgets('Agent Hub restores waiting action state from durable snapshot', (
    tester,
  ) async {
    const actionId = '22222222-2222-2222-2222-222222222222';
    final store = _MemoryAgentHubInteractionStateStore(
      AgentHubInteractionSnapshot(
        runState: AgentStreamRunState(
          phase: AgentStreamRunPhase.waitingForConfirmation,
          threadId: 'thread-restore',
          runId: 'run-restore',
          textContent: '请确认是否提交给人工支持。',
          lastSequence: 4,
          events: [
            AgentStreamEvent(const {
              'event_id': 'evt-action-restore',
              'type': 'action.confirmation_required',
              'thread_id': 'thread-restore',
              'run_id': 'run-restore',
              'action_id': actionId,
              'sequence': 3,
              'payload': {
                'summary': '恢复后仍可确认',
                'preview_payload': {'title': '提交人工支持'},
              },
            }),
            AgentStreamEvent(const {
              'event_id': 'evt-wait-restore',
              'type': 'run.waiting_for_confirmation',
              'thread_id': 'thread-restore',
              'run_id': 'run-restore',
              'sequence': 4,
            }),
          ],
        ),
        activeRequest: const AgentStreamRequest(
          message: '我需要人工帮助',
          locale: 'zh-CN',
        ),
      ),
    );

    await tester.pumpWidget(_host(AgentHubPage(interactionStateStore: store)));
    await tester.pumpAndSettle();

    expect(find.text('请确认是否提交给人工支持。'), findsOneWidget);
    expect(find.text('等待确认后继续'), findsOneWidget);
    expect(find.byKey(ValueKey('agent-action-card-$actionId')), findsOneWidget);
    expect(find.text('提交人工支持'), findsOneWidget);
  });

  testWidgets(
    'Agent Hub resumes stream after action confirmation and keeps backend terminal status',
    (tester) async {
      const actionId = '33333333-3333-3333-3333-333333333333';
      final connector = _RecordingActionConnector();
      final streamClient = _FixtureAgentStreamClient([
        AgentStreamEvent(const {
          'event_id': 'evt-action-applied',
          'type': 'action.applied',
          'thread_id': 'thread-action',
          'run_id': 'run-action',
          'action_id': actionId,
          'sequence': 3,
          'payload': {
            'status': 'applied',
            'summary': '已提交给人工支持团队',
            'preview_payload': {'title': '创建支持工单'},
          },
        }),
        AgentStreamEvent(const {
          'event_id': 'evt-action-final',
          'type': 'message.completed',
          'thread_id': 'thread-action',
          'run_id': 'run-action',
          'message_id': 'msg-action-final',
          'sequence': 4,
          'payload': {'role': 'assistant', 'text': '工单已经创建。'},
        }),
        AgentStreamEvent(const {
          'event_id': 'evt-action-run-completed',
          'type': 'run.completed',
          'thread_id': 'thread-action',
          'run_id': 'run-action',
          'message_id': 'msg-action-final',
          'sequence': 5,
        }),
      ]);
      final actionClient = AgentStreamActionClient(
        endpoint: AgentStreamEndpoint(
          uri: Uri.parse('http://127.0.0.1:8769/v1/agent/actions'),
          token: 'secret-token',
        ),
        connector: connector,
      );

      await tester.pumpWidget(
        _host(
          AgentHubPage(
            state: AgentStreamRunState(
              phase: AgentStreamRunPhase.waitingForConfirmation,
              threadId: 'thread-action',
              runId: 'run-action',
              lastSequence: 2,
              textContent: '请确认是否创建支持工单。',
              events: [
                AgentStreamEvent(const {
                  'event_id': 'evt-action-required',
                  'type': 'action.confirmation_required',
                  'thread_id': 'thread-action',
                  'run_id': 'run-action',
                  'action_id': actionId,
                  'sequence': 1,
                  'payload': {
                    'summary': '将当前问题提交给人工支持团队',
                    'preview_payload': {'title': '创建支持工单'},
                  },
                }),
                AgentStreamEvent(const {
                  'event_id': 'evt-action-wait',
                  'type': 'run.waiting_for_confirmation',
                  'thread_id': 'thread-action',
                  'run_id': 'run-action',
                  'sequence': 2,
                }),
              ],
            ),
            runner: AgentStreamRunner(streamClient),
            actionClient: actionClient,
          ),
        ),
      );

      await tester.tap(find.byKey(ValueKey('agent-action-confirm-$actionId')));
      await connector.called.future;
      await tester.pumpAndSettle();

      expect(streamClient.requests.single.runId, 'run-action');
      expect(streamClient.requests.single.threadId, 'thread-action');
      expect(streamClient.requests.single.afterSequence, 2);
      expect(find.text('工单已经创建。'), findsOneWidget);
      expect(find.text('已应用'), findsOneWidget);
      expect(find.text('已提交'), findsNothing);
    },
  );

  testWidgets('Agent Hub renders safe tool failure progress', (tester) async {
    await tester.pumpWidget(
      _host(
        AgentHubPage(
          state: AgentStreamRunState(
            phase: AgentStreamRunPhase.streaming,
            textContent: '我会尽量继续整理。',
            events: [
              AgentStreamEvent(const {
                'type': 'tool.started',
                'thread_id': 'thread-tool-fail',
                'run_id': 'run-tool-fail',
                'tool_call_id': 'call_growth_fail',
                'payload': {'tool_name': 'growth_record_query'},
              }),
              AgentStreamEvent(const {
                'type': 'tool.failed',
                'thread_id': 'thread-tool-fail',
                'run_id': 'run-tool-fail',
                'tool_call_id': 'call_growth_fail',
                'payload': {
                  'tool_name': 'growth_record_query',
                  'message': 'database timeout for child profile',
                  'details': '{"childId":"baby-secret","error":"timeout"}',
                },
              }),
            ],
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('agent-work-panel')), findsNothing);
    expect(find.text('处理进度'), findsNothing);
    expect(find.text('成长记录暂时无法读取'), findsNothing);
    expect(find.text('失败'), findsNothing);
    expect(find.textContaining('growth_record_query'), findsNothing);
    expect(find.textContaining('database timeout'), findsNothing);
    expect(find.textContaining('baby-secret'), findsNothing);
  });

  testWidgets('Agent Hub renders safe artifact cards from stream events', (
    tester,
  ) async {
    final artifactEvent = AgentStreamEvent(
      readFixtureMap('agent_events/rich_text_artifact.json'),
    );

    await tester.pumpWidget(
      _host(
        AgentHubPage(
          state: AgentStreamRunState(
            phase: AgentStreamRunPhase.finished,
            textContent: 'I prepared a draft plan.',
            events: [artifactEvent],
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('agent-artifact-panel')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('agent-artifact-card-milk-plan-001')),
      findsOneWidget,
    );
    expect(find.text('Milk supply plan'), findsOneWidget);
    expect(find.text('Draft'), findsOneWidget);
    expect(
      find.text('Draft card generated from safe artifact payload.'),
      findsOneWidget,
    );
    expect(find.text('Review flange comfort'), findsWidgets);
    expect(find.text('Track two more pumping sessions'), findsWidgets);
    expect(find.text('打开结果卡片'), findsOneWidget);
    expect(find.textContaining('milk_plan_preview_create'), findsNothing);
    expect(find.textContaining('{"'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('agent-artifact-action-milk-plan-001-0')),
    );
    await tester.pump();
  });

  testWidgets('Agent Hub renders legacy ag-ui artifact actions', (
    tester,
  ) async {
    final event = AgentStreamEvent({
      'type': 'artifact.created',
      'thread_id': 'thread-ag-ui-artifact',
      'run_id': 'run-ag-ui-artifact',
      'artifact_id': 'rich-text-wrapper',
      'payload': {
        'artifact_type': 'rich_text',
        'rich_text': {
          'action': [
            {
              'kind': 'ag_ui_artifact',
              'artifact_type': 'form',
              'artifact_id': 'birth-info-form',
              'form': {
                'id': 'birth_journey_basic_info_intake',
                'title': '孕周与基本情况',
                'fields': [
                  {
                    'id': 'current_week',
                    'label': '当前孕周',
                    'type': 'text',
                    'required': true,
                    'default_value': '孕25周',
                  },
                ],
              },
            },
            {
              'kind': 'ag_ui_artifact',
              'artifact_type': 'card',
              'artifact_id': 'birth-journey-card',
              'card': {
                'card_type': 'birth_journey_plan_card',
                'schema_version': '1.0',
                'card_json': {
                  'title': '孕期计划',
                  'todo_plan': {
                    'periods': [
                      {
                        'title': '孕 25-27 周',
                        'items': [
                          {'title': '做糖耐检查（OGTT）'},
                        ],
                      },
                    ],
                  },
                },
              },
            },
          ],
        },
      },
    });

    await tester.pumpWidget(
      _host(
        AgentHubPage(
          state: AgentStreamRunState(
            phase: AgentStreamRunPhase.finished,
            textContent: '我准备好了两个结果。',
            events: [event],
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('agent-artifact-card-birth-info-form')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('agent-artifact-birth-journey-card')),
      findsOneWidget,
    );
    expect(find.text('孕周与基本情况'), findsOneWidget);
    expect(find.text('当前孕周'), findsOneWidget);
    expect(find.text('孕期计划'), findsOneWidget);
    expect(find.text('孕 25-27 周'), findsOneWidget);
    expect(find.text('做糖耐检查（OGTT）'), findsOneWidget);
    expect(find.text('打开说明内容'), findsNothing);
  });

  testWidgets('Agent Hub renders specialized legacy artifact cards', (
    tester,
  ) async {
    final state = AgentStreamRunState(
      phase: AgentStreamRunPhase.finished,
      textContent: '我整理好了这些卡片。',
      events: [
        AgentStreamEvent({
          'type': 'artifact.created',
          'artifact_id': 'milk-plan-card',
          'payload': {
            'artifact_type': 'milk_plan_card',
            'card': {
              'card_type': 'milk_plan_card',
              'schema_version': '1.0',
              'card_json': {
                'title': '追奶计划',
                'sections': [
                  {
                    'id': 'target',
                    'title': '目标',
                    'tone': 'normal',
                    'items': ['当前每日奶量约 549 ml，目标约 709.2 ml。'],
                  },
                  {
                    'id': 'plan',
                    'title': '计划',
                    'tone': 'info',
                    'metrics': [
                      {'label': '周期', 'value': '3 天', 'detail': '从明天开始'},
                    ],
                    'items': ['新增 1 个吸奶任务。'],
                  },
                ],
              },
            },
          },
        }),
        AgentStreamEvent({
          'type': 'artifact.created',
          'artifact_id': 'birth-journey-card',
          'payload': {
            'artifact_type': 'birth_journey_plan_card',
            'card': {
              'card_type': 'birth_journey_plan_card',
              'schema_version': '1.0',
              'card_json': {
                'title': '孕期计划',
                'owner': {'current_week': '孕25周', 'birth_path': '顺产'},
                'todo_plan': {
                  'periods': [
                    {
                      'title': '孕 25-27 周',
                      'subtitle': '重点完成糖耐和血压复查。',
                      'status': 'current',
                      'items': [
                        {
                          'title': '做糖耐检查（OGTT）',
                          'priority_label': '重要',
                          'reason': '需要连续处理预约、空腹和抽血。',
                          'steps': ['确认检查时间', '检查结束后及时吃第一餐'],
                        },
                      ],
                    },
                  ],
                },
              },
            },
          },
        }),
        AgentStreamEvent({
          'type': 'artifact.created',
          'artifact_id': 'birth-plan-card',
          'payload': {
            'artifact_type': 'birth_plan_card',
            'card': {
              'card_type': 'birth_plan_card',
              'schema_version': '1.0',
              'card_json': {
                'title': '分娩沟通单',
                'communication': ['希望先解释每一步'],
                'pain_relief': ['优先尝试非药物缓解'],
                'questions_for_hospital': ['什么情况需要转剖宫产？'],
                'medical_notes': ['妊娠糖尿病史'],
              },
            },
          },
        }),
        AgentStreamEvent({
          'type': 'artifact.created',
          'artifact_id': 'hospital-bag-card',
          'payload': {
            'artifact_type': 'hospital_bag_card',
            'card': {
              'card_type': 'hospital_bag_card',
              'schema_version': '1.0',
              'card_json': {
                'title': '待产包',
                'packing_groups': [
                  {
                    'title': '妈妈住院包',
                    'items': [
                      {
                        'label': '产褥垫组合装',
                        'quantity': '1包',
                        'priority': 'must',
                        'reason': '产后前几天更换频繁',
                      },
                    ],
                  },
                ],
                'disclaimer': '以医院实际要求为准。',
              },
            },
          },
        }),
      ],
    );

    await tester.pumpWidget(_host(AgentHubPage(state: state)));

    expect(
      find.byKey(const ValueKey('agent-artifact-milk-plan-card')),
      findsOneWidget,
    );
    expect(find.text('目标'), findsOneWidget);
    expect(find.text('周期'), findsOneWidget);
    expect(find.text('3 天'), findsOneWidget);
    expect(find.text('新增 1 个吸奶任务。'), findsOneWidget);

    expect(
      find.byKey(const ValueKey('agent-artifact-birth-journey-card')),
      findsOneWidget,
    );
    expect(find.text('孕期'), findsOneWidget);
    expect(find.text('孕25周'), findsOneWidget);
    expect(find.text('孕 25-27 周'), findsOneWidget);
    expect(find.text('1 个事项'), findsOneWidget);
    expect(find.text('重要'), findsOneWidget);
    expect(find.text('检查结束后及时吃第一餐'), findsOneWidget);

    expect(
      find.byKey(const ValueKey('agent-artifact-birth-plan-card')),
      findsOneWidget,
    );
    expect(find.text('沟通卡片内容'), findsOneWidget);
    expect(find.text('疼痛缓解'), findsOneWidget);
    expect(find.text('希望先解释每一步'), findsOneWidget);
    expect(find.text('医疗或安全信息'), findsOneWidget);

    expect(
      find.byKey(const ValueKey('agent-artifact-hospital-bag-card')),
      findsOneWidget,
    );
    expect(find.text('物品清单'), findsOneWidget);
    expect(find.text('妈妈住院包'), findsOneWidget);
    expect(find.text('1项'), findsOneWidget);
    expect(find.text('1包'), findsOneWidget);
    expect(find.text('必备'), findsOneWidget);
    expect(find.text('产后前几天更换频繁'), findsOneWidget);
    expect(find.text('打开购物车'), findsOneWidget);
  });

  testWidgets('Agent Hub renders camelCase specialized artifact fields', (
    tester,
  ) async {
    final state = AgentStreamRunState(
      phase: AgentStreamRunPhase.finished,
      textContent: '我整理好了这些卡片。',
      events: [
        AgentStreamEvent({
          'type': 'artifact.created',
          'artifact_id': 'birth-journey-camel-card',
          'payload': {
            'artifact_type': 'birth_journey_plan_card',
            'card_json': {
              'title': '孕期计划',
              'owner': {'currentWeek': '孕26周', 'birthPath': '顺产'},
              'todoPlan': {
                'periods': [
                  {
                    'title': '孕 26-28 周',
                    'items': [
                      {
                        'title': '复查血压',
                        'priorityLabel': '建议',
                        'steps': ['记录早晚血压'],
                      },
                    ],
                  },
                ],
              },
            },
          },
        }),
        AgentStreamEvent({
          'type': 'artifact.created',
          'artifact_id': 'birth-plan-camel-card',
          'payload': {
            'artifact_type': 'birth_plan_card',
            'card_json': {
              'title': '分娩沟通单',
              'painRelief': ['优先尝试非药物缓解'],
              'medicalNotes': ['妊娠糖尿病史'],
            },
          },
        }),
        AgentStreamEvent({
          'type': 'artifact.created',
          'artifact_id': 'hospital-bag-camel-card',
          'payload': {
            'artifact_type': 'hospital_bag_card',
            'card_json': {
              'title': '待产包',
              'packingGroups': [
                {
                  'title': '妈妈住院包',
                  'items': [
                    {'label': '产褥垫组合装', 'quantity': '1包', 'priority': 'must'},
                  ],
                },
              ],
            },
          },
        }),
      ],
    );

    await tester.pumpWidget(_host(AgentHubPage(state: state)));

    expect(
      find.byKey(const ValueKey('agent-artifact-birth-journey-camel-card')),
      findsOneWidget,
    );
    expect(find.text('孕26周'), findsOneWidget);
    expect(find.text('顺产'), findsOneWidget);
    expect(find.text('孕 26-28 周'), findsOneWidget);
    expect(find.text('建议'), findsOneWidget);
    expect(find.text('记录早晚血压'), findsOneWidget);

    expect(
      find.byKey(const ValueKey('agent-artifact-birth-plan-camel-card')),
      findsOneWidget,
    );
    expect(find.text('疼痛缓解'), findsOneWidget);
    expect(find.text('优先尝试非药物缓解'), findsOneWidget);
    expect(find.text('医疗或安全信息'), findsOneWidget);
    expect(find.text('妊娠糖尿病史'), findsOneWidget);

    expect(
      find.byKey(const ValueKey('agent-artifact-hospital-bag-camel-card')),
      findsOneWidget,
    );
    expect(find.text('物品清单'), findsOneWidget);
    expect(find.text('妈妈住院包'), findsOneWidget);
    expect(find.text('产褥垫组合装'), findsOneWidget);
    expect(find.text('1包'), findsOneWidget);
    expect(find.text('必备'), findsOneWidget);
  });

  testWidgets('Agent Hub renders legacy service artifact envelopes', (
    tester,
  ) async {
    final actions = <AgentArtifactActionView>[];
    final client = _ControllableAgentStreamClient();
    addTearDown(client.dispose);
    final formEvent = AgentStreamEvent({
      'type': 'artifact.created',
      'thread_id': 'thread-legacy-artifact',
      'run_id': 'run-legacy-artifact',
      'artifact_id': 'hospital-bag-form',
      'payload': {
        'artifact_type': 'form',
        'form': {
          'id': 'hospital_bag_intake',
          'title': '信息采集',
          'fields': [
            {
              'id': 'due_date_or_week',
              'label': '基本信息｜预产期或当前孕周',
              'type': 'text',
              'required': true,
              'placeholder': '例如：38 周',
            },
            {
              'id': 'birth_path',
              'label': '生产信息｜分娩方式',
              'type': 'select',
              'required': true,
              'options': ['顺产', '剖宫产', '还不确定'],
            },
          ],
        },
      },
    });
    final planEvent = AgentStreamEvent({
      'type': 'artifact.created',
      'thread_id': 'thread-legacy-artifact',
      'run_id': 'run-legacy-artifact',
      'artifact_id': 'birth-plan-card',
      'payload': {
        'artifact_type': 'birth_journey_plan_card',
        'card': {
          'card_type': 'birth_journey_plan_card',
          'schema_version': '1.0',
          'card_json': {
            'title': '孕期计划',
            'todo_plan': {
              'periods': [
                {
                  'title': '当前阶段',
                  'items': [
                    {'title': '整理下次产检要问的问题'},
                    {'title': '开始整理待产包'},
                  ],
                },
              ],
            },
          },
        },
      },
    });
    final cartEvent = AgentStreamEvent({
      'type': 'artifact.created',
      'thread_id': 'thread-legacy-artifact',
      'run_id': 'run-legacy-artifact',
      'artifact_id': 'hospital-bag-cart',
      'payload': {
        'artifact_type': 'hospital_bag_card',
        'assistant_followup': {
          'kind': 'hospital_bag_cart',
          'message': '**[打开待产包购物车](/hospital-bag-cart)**',
        },
        'cart_update': {
          'action': 'reset_cart',
          'message': '已经帮你把待产包购物车恢复到默认清单了。',
          'groups': [
            {
              'title': '妈妈护理',
              'items': [
                {'name': '产褥垫组合装'},
                {'name': '一次性内裤'},
              ],
            },
          ],
          'totals': {'itemCount': 2, 'total': 101.02},
        },
      },
    });

    await tester.pumpWidget(
      _host(
        AgentHubPage(
          runner: AgentStreamRunner(client),
          state: AgentStreamRunState(
            phase: AgentStreamRunPhase.finished,
            textContent: '我整理好了。',
            events: [formEvent, planEvent, cartEvent],
          ),
          onArtifactAction: actions.add,
        ),
      ),
    );

    expect(find.text('信息采集'), findsOneWidget);
    final formFinder = find.byKey(
      const ValueKey('agent-artifact-form-hospital-bag-form'),
    );
    expect(formFinder, findsOneWidget);
    expect(find.text('基本信息'), findsOneWidget);
    expect(find.text('预产期或当前孕周'), findsOneWidget);
    expect(find.text('生产信息'), findsOneWidget);
    expect(find.text('分娩方式'), findsOneWidget);
    expect(find.text('必填'), findsWidgets);
    expect(find.text('顺产'), findsOneWidget);
    expect(find.text('孕期计划'), findsOneWidget);
    expect(find.text('当前阶段'), findsOneWidget);
    expect(find.text('2 个事项'), findsOneWidget);
    expect(find.text('整理下次产检要问的问题'), findsOneWidget);
    expect(find.text('开始整理待产包'), findsOneWidget);
    expect(find.text('已经帮你把待产包购物车恢复到默认清单了。'), findsWidgets);
    expect(find.text('妈妈护理：产褥垫组合装、一次性内裤'), findsOneWidget);
    expect(find.text('购物车合计：2 件｜101.02'), findsOneWidget);
    expect(find.text('打开待产包购物车'), findsOneWidget);

    await tester.tap(
      find.byKey(
        const ValueKey('agent-artifact-form-submit-hospital-bag-form'),
      ),
    );
    await tester.pump();

    expect(client.requests, isEmpty);
    expect(find.text('请补充：预产期或当前孕周、分娩方式'), findsOneWidget);

    await tester.enterText(
      find.descendant(of: formFinder, matching: find.byType(TextFormField)),
      '38 周',
    );
    await tester.pump();
    await tester.tap(find.text('顺产'));
    await tester.pump();
    await tester.tap(
      find.byKey(
        const ValueKey('agent-artifact-form-submit-hospital-bag-form'),
      ),
    );
    await tester.pump();

    expect(client.requests, hasLength(1));
    expect(client.requests.single.message, contains('confirmed_form_data'));
    expect(client.requests.single.message, contains('due_date_or_week'));
    expect(find.text('已提交信息采集表单'), findsOneWidget);

    final cartActionFinder = find.byKey(
      const ValueKey('agent-artifact-action-hospital-bag-cart-0'),
    );
    await tester.ensureVisible(cartActionFinder);
    await tester.pump();
    await tester.tap(cartActionFinder);
    await tester.pump();

    expect(actions.single.routePath, '/hospital-bag-cart');
  });

  testWidgets(
    'Agent Hub aligns grouped artifact form defaults other input and submit lock',
    (tester) async {
      final actions = <AgentArtifactActionView>[];
      final card = AgentArtifactCardView(
        id: 'form-alignment',
        title: '信息采集',
        formId: 'hospital_bag_intake',
        formFields: [
          const AgentArtifactFormFieldView(
            id: 'due_date_or_week',
            label: '基本信息｜预产期或当前孕周',
            type: 'text',
            required: true,
            defaultValue: '38 周',
            helpText: '可以填写日期或孕周。',
          ),
          const AgentArtifactFormFieldView(
            id: 'pregnancy_history',
            label: '生产信息｜孕产史',
            type: 'checkbox_group',
            required: true,
            options: ['一胎', '二胎', '其他'],
            allowOtherInput: true,
            otherPlaceholder: '请写明需要补充的信息',
            defaultValue: ['其他'],
          ),
        ],
      );

      await tester.pumpWidget(
        _host(
          SingleChildScrollView(
            child: AgentArtifactPanel(cards: [card], onAction: actions.add),
          ),
        ),
      );

      expect(find.text('基本信息'), findsOneWidget);
      expect(find.text('生产信息'), findsOneWidget);
      expect(find.text('预产期或当前孕周'), findsOneWidget);
      expect(find.text('孕产史'), findsOneWidget);
      expect(find.text('基本信息｜预产期或当前孕周'), findsNothing);
      expect(find.text('38 周'), findsOneWidget);
      expect(find.text('可以填写日期或孕周。'), findsOneWidget);
      final otherFinder = find.byKey(
        const ValueKey(
          'agent-artifact-form-other-form-alignment-pregnancy_history',
        ),
      );
      expect(otherFinder, findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('agent-artifact-form-submit-form-alignment')),
      );
      await tester.pump();

      expect(actions, isEmpty);
      expect(find.text('请填写：孕产史的其它内容'), findsOneWidget);

      await tester.enterText(otherFinder, '第一胎剖宫产');
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('agent-artifact-form-submit-form-alignment')),
      );
      await tester.pump();

      expect(actions, hasLength(1));
      expect(actions.single.value, contains('"due_date_or_week":"38 周"'));
      expect(
        actions.single.value,
        contains('"pregnancy_history":["其它：第一胎剖宫产"]'),
      );
      expect(find.text('已提交'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('agent-artifact-form-submit-form-alignment')),
      );
      await tester.pump();

      expect(actions, hasLength(1));
    },
  );

  testWidgets('Agent Hub treats legacy checkbox_group fields as multi-select', (
    tester,
  ) async {
    final client = _ControllableAgentStreamClient();
    addTearDown(client.dispose);
    final formEvent = AgentStreamEvent({
      'type': 'artifact.created',
      'thread_id': 'thread-checkbox-group',
      'run_id': 'run-checkbox-group',
      'artifact_id': 'packing-form',
      'payload': {
        'artifact_type': 'form',
        'form': {
          'id': 'packing_intake',
          'title': '待产包偏好',
          'fields': [
            {
              'id': 'packing_items',
              'label': '想加入的物品',
              'type': 'checkbox_group',
              'required': true,
              'options': ['奶瓶', '尿布', '湿巾'],
            },
          ],
        },
      },
    });

    await tester.pumpWidget(
      _host(
        AgentHubPage(
          runner: AgentStreamRunner(client),
          state: AgentStreamRunState(
            phase: AgentStreamRunPhase.finished,
            textContent: '请选择待产包物品。',
            events: [formEvent],
          ),
        ),
      ),
    );

    expect(find.text('奶瓶'), findsOneWidget);
    expect(find.text('尿布'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNWidgets(3));

    await tester.tap(find.text('奶瓶'));
    await tester.pump();
    await tester.tap(find.text('尿布'));
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('agent-artifact-form-submit-packing-form')),
    );
    await tester.pump();

    expect(client.requests, hasLength(1));
    expect(
      client.requests.single.message,
      contains('"packing_items":["奶瓶","尿布"]'),
    );
  });

  testWidgets('Agent Hub renders rich text card rows and button actions', (
    tester,
  ) async {
    final actions = <AgentArtifactActionView>[];
    final artifactEvent = AgentStreamEvent({
      'type': 'artifact.created',
      'thread_id': 'thread-resource',
      'run_id': 'run-resource',
      'message_id': 'msg-resource',
      'artifact_id': 'resource-card',
      'payload': {
        'artifact_type': 'rich_text',
        'rich_text': {
          'title': '资源',
          'content': '可以打开这些资料。',
          'button': [
            {'text': '打开文档', 'type': 'doc', 'value': '/docs/a.pdf'},
            {'text': '查看图片', 'type': 'media', 'value': '/media/a.png'},
          ],
          'card': [
            {
              'title': '参考',
              'content': [
                {'title': '指南', 'content': '泵奶姿势'},
              ],
            },
          ],
        },
      },
    });

    await tester.pumpWidget(
      _host(
        AgentHubPage(
          state: AgentStreamRunState(
            phase: AgentStreamRunPhase.finished,
            textContent: '这些资源可以参考。',
            events: [artifactEvent],
          ),
          onArtifactAction: actions.add,
        ),
      ),
    );

    expect(find.byKey(const ValueKey('agent-artifact-panel')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('agent-artifact-card-resource-card')),
      findsOneWidget,
    );
    expect(find.text('资源'), findsOneWidget);
    expect(find.text('可以打开这些资料。'), findsOneWidget);
    expect(find.text('参考'), findsOneWidget);
    expect(find.text('指南: 泵奶姿势'), findsOneWidget);
    expect(find.text('打开文档'), findsOneWidget);
    expect(find.text('查看图片'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('agent-artifact-action-resource-card-0')),
    );
    await tester.pump();

    expect(actions.single.kind, 'doc');
    expect(actions.single.value, '/docs/a.pdf');
    expect(actions.single.routePath, '/media-viewer');
    expect(actions.single.routeExtra, {
      'kind': 'pdf',
      'url': '/docs/a.pdf',
      'title': '打开文档',
    });

    await tester.tap(
      find.byKey(const ValueKey('agent-artifact-action-resource-card-1')),
    );
    await tester.pump();

    expect(actions.last.kind, 'media');
    expect(actions.last.value, '/media/a.png');
    expect(actions.last.routePath, '/media-viewer');
    expect(actions.last.routeExtra, {
      'kind': 'image',
      'url': '/media/a.png',
      'title': '查看图片',
    });
  });

  testWidgets('Agent Hub renders citation and reference links safely', (
    tester,
  ) async {
    final actions = <AgentArtifactActionView>[];
    final artifactEvent = AgentStreamEvent({
      'type': 'artifact.created',
      'thread_id': 'thread-citation',
      'run_id': 'run-citation',
      'message_id': 'msg-citation',
      'artifact_id': 'citation-card',
      'payload': {
        'artifact_type': 'rich_text',
        'rich_text': {
          'title': '参考资料',
          'content': '这些资料可以作为进一步阅读。',
          'citations': [
            {
              'index': 1,
              'title': 'CDC Breastfeeding',
              'url': 'https://www.cdc.gov/breastfeeding/mastitis',
            },
            {'displayText': 'ABM Protocol', 'href': '/guides/abm.pdf'},
          ],
        },
      },
    });

    await tester.pumpWidget(
      _host(
        AgentHubPage(
          state: AgentStreamRunState(
            phase: AgentStreamRunPhase.finished,
            textContent: '我找到两条参考资料。',
            events: [artifactEvent],
          ),
          onArtifactAction: actions.add,
        ),
      ),
    );

    expect(find.text('[1] CDC Breastfeeding'), findsOneWidget);
    expect(find.text('ABM Protocol'), findsOneWidget);
    expect(find.textContaining('https://www.cdc.gov'), findsNothing);
    expect(find.textContaining('/guides/abm.pdf'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('agent-artifact-action-citation-card-0')),
    );
    await tester.pump();

    expect(actions.single.kind, 'citation');
    expect(actions.single.value, 'https://www.cdc.gov/breastfeeding/mastitis');
    expect(actions.single.routePath, isNull);
  });

  testWidgets('Agent Hub wraps long content on compact mobile viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final longText = List.filled(
      6,
      '今天的泵奶记录很多，我需要把左右侧奶量、舒适度、间隔和宝宝喂养情况一起整理给你。',
    ).join();
    final artifactEvent = AgentStreamEvent({
      'type': 'artifact.created',
      'thread_id': 'thread-long-copy',
      'run_id': 'run-long-copy',
      'message_id': 'msg-long-copy',
      'artifact_id': 'long-copy-card',
      'payload': {
        'artifact_type': 'rich_text',
        'rich_text': {
          'title': '长内容建议',
          'content': longText,
          'card': [
            {
              'title': '下一步',
              'content': [
                {
                  'title': '观察重点',
                  'content': '连续记录三次泵奶后的舒适度和奶量变化，尤其关注左侧是否仍然明显偏低。',
                },
              ],
            },
          ],
        },
      },
    });

    await tester.pumpWidget(
      _host(
        AgentHubPage(
          state: AgentStreamRunState(
            phase: AgentStreamRunPhase.finished,
            textContent: longText,
            events: [artifactEvent],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('今天的泵奶记录很多'), findsWidgets);
    expect(find.text('长内容建议'), findsOneWidget);

    await tester.drag(
      find.byKey(const ValueKey('agent-hub-page')),
      const Offset(0, -280),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('Agent Hub renders disconnected partial response state', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const AgentHubPage(
          state: AgentStreamRunState(
            phase: AgentStreamRunPhase.disconnected,
            textContent: 'Partial answer',
            errorMessage: 'socket closed',
          ),
        ),
      ),
    );

    expect(find.text('Partial answer'), findsOneWidget);
    expect(find.text('socket closed'), findsOneWidget);
    expect(find.textContaining('WebSocket'), findsNothing);
    expect(find.textContaining('SSE'), findsNothing);
  });

  testWidgets(
    'Agent Hub renders streaming and finished states from run state',
    (tester) async {
      await tester.pumpWidget(
        _host(
          const AgentHubPage(
            state: AgentStreamRunState(
              phase: AgentStreamRunPhase.streaming,
              textContent: 'I can help ',
            ),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('agent-run-status-line')), findsNothing);
      expect(find.text('I can help'), findsOneWidget);

      await tester.pumpWidget(
        _host(
          const AgentHubPage(
            state: AgentStreamRunState(phase: AgentStreamRunPhase.streaming),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('agent-run-status-line')),
        findsOneWidget,
      );
      expect(find.text('我已经收到你的消息啦～'), findsOneWidget);

      await tester.pumpWidget(
        _host(
          const AgentHubPage(
            state: AgentStreamRunState(
              phase: AgentStreamRunPhase.finished,
              textContent: 'I can help you review today.',
            ),
          ),
        ),
      );

      expect(find.text('I can help you review today.'), findsOneWidget);
      expect(find.byKey(const ValueKey('agent-run-status-line')), findsNothing);
    },
  );

  testWidgets('Agent Hub renders assistant markdown without raw markers', (
    tester,
  ) async {
    const markdown = '''
## 产后恢复的几个关键方面

### 1. 身体恢复
- **恶露观察**：产后 4-6 周内会持续
- **休息充足**：尽量在宝宝睡觉时一起休息

1. 先记录今天的状态
2. 再查看[护理建议](https://example.com/care)

> 记录几天后，我可以帮你回顾变化。

`体温` 也可以一起记录。

```text
milk_total: 120ml
```

| 项目 | 状态 |
| --- | --- |
| 睡眠 | 待记录 |
''';

    await tester.pumpWidget(
      _host(
        const AgentHubPage(
          state: AgentStreamRunState(
            phase: AgentStreamRunPhase.finished,
            textContent: markdown,
          ),
        ),
      ),
    );

    expect(find.textContaining('##'), findsNothing);
    expect(find.textContaining('**'), findsNothing);
    expect(find.byType(MarkdownBody), findsOneWidget);
    expect(find.text('产后恢复的几个关键方面', findRichText: true), findsOneWidget);
    expect(find.text('1. 身体恢复', findRichText: true), findsOneWidget);
    expect(find.textContaining('恶露观察', findRichText: true), findsOneWidget);
    expect(find.textContaining('休息充足', findRichText: true), findsOneWidget);
    expect(find.textContaining('先记录今天的状态', findRichText: true), findsOneWidget);
    expect(find.textContaining('护理建议', findRichText: true), findsOneWidget);
    expect(find.textContaining('记录几天后', findRichText: true), findsOneWidget);
    expect(find.textContaining('体温', findRichText: true), findsOneWidget);
    expect(find.textContaining('milk_total: 120ml'), findsOneWidget);
    expect(find.text('项目'), findsOneWidget);
    expect(find.text('睡眠'), findsOneWidget);
  });

  testWidgets(
    'Agent Hub renders skill asset media links and opens viewer actions',
    (tester) async {
      final actions = <AgentArtifactActionView>[];
      const imageUrl =
          '/skill-assets/device-guidance/air1/images/air1_guide_parts_components.png';
      const pdfUrl =
          '/skill-assets/device-guidance/air1/quick-start/momcozy-air1-quick-start-guidance.pdf';
      const videoUrl =
          '/skill-assets/device-guidance/air1/videos/air1-operation-zh.mp4';
      const markdown =
          '''
先看 $imageUrl

[打开 PDF]($pdfUrl)

[打开视频]($videoUrl)

[打开购物车](/hospital-bag-cart)
''';

      await tester.pumpWidget(
        _host(
          AgentHubPage(
            state: const AgentStreamRunState(
              phase: AgentStreamRunPhase.finished,
              textContent: markdown,
            ),
            onArtifactAction: actions.add,
          ),
        ),
      );

      final imageFinder = find.byKey(
        ValueKey('agent-markdown-image-$imageUrl'),
      );
      expect(imageFinder, findsOneWidget);
      expect(find.text(imageUrl), findsNothing);

      await tester.tap(imageFinder);
      await tester.pump();

      expect(actions.single.routePath, '/media-viewer');
      expect(actions.single.routeExtra, {
        'kind': 'image',
        'url': imageUrl,
        'title': '查看图片',
      });

      await tester.tap(find.text('打开 PDF', findRichText: true));
      await tester.pump();

      expect(actions.last.routePath, '/media-viewer');
      expect(actions.last.routeExtra, {
        'kind': 'pdf',
        'url': pdfUrl,
        'title': '打开 PDF',
      });

      await tester.tap(find.text('打开视频', findRichText: true));
      await tester.pump();

      expect(actions.last.routePath, '/media-viewer');
      expect(actions.last.routeExtra, {
        'kind': 'video',
        'url': videoUrl,
        'title': '打开视频',
      });

      await tester.tap(find.text('打开购物车', findRichText: true));
      await tester.pump();

      expect(actions.last.routePath, '/hospital-bag-cart');
    },
  );

  testWidgets('Agent Hub status line uses progress events before final text', (
    tester,
  ) async {
    final state = AgentStreamRunState(
      phase: AgentStreamRunPhase.streaming,
      events: [
        AgentStreamEvent({
          'type': 'run.progress',
          'payload': {'label': '我在帮你检查今天的记录～'},
        }),
      ],
    );

    await tester.pumpWidget(_host(AgentHubPage(state: state)));

    expect(find.byKey(const ValueKey('agent-run-status-line')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('agent-run-status-line')),
        matching: find.text('我在帮你检查今天的记录～'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('agent-run-status-title-sweep')),
      findsOneWidget,
    );
  });

  testWidgets('Agent Hub status line prefers backend semantic labels', (
    tester,
  ) async {
    final state = AgentStreamRunState(
      phase: AgentStreamRunPhase.streaming,
      events: [
        AgentStreamEvent({
          'type': 'run.progress',
          'payload': {
            'label': '正在处理请求。',
            'semantic': {'label': '我想一下', 'visibility': 'status'},
          },
        }),
      ],
    );

    await tester.pumpWidget(_host(AgentHubPage(state: state)));

    expect(find.text('我想一下'), findsOneWidget);
    expect(find.text('正在处理请求。'), findsNothing);
  });

  testWidgets('Agent Hub renders model reasoning as a thinking note', (
    tester,
  ) async {
    final state = AgentStreamRunState(
      phase: AgentStreamRunPhase.streaming,
      events: [
        AgentStreamEvent({'type': 'run.started'}),
        AgentStreamEvent({
          'type': 'run.progress',
          'payload': {'phase': 'model_reasoning'},
        }),
      ],
    );

    await tester.pumpWidget(_host(AgentHubPage(state: state)));

    expect(find.byKey(const ValueKey('agent-run-status-line')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('agent-run-status-line')),
        matching: find.text('我已经收到你的消息啦～'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('agent-thinking-note')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('agent-thinking-note')),
        matching: find.text('我想一下'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Agent Hub clears thinking note on later progress phases', (
    tester,
  ) async {
    final state = AgentStreamRunState(
      phase: AgentStreamRunPhase.streaming,
      events: [
        AgentStreamEvent({'type': 'run.started'}),
        AgentStreamEvent({
          'type': 'run.progress',
          'payload': {'phase': 'model_reasoning'},
        }),
        AgentStreamEvent({
          'type': 'run.progress',
          'payload': {'phase': 'response_finalizing'},
        }),
      ],
    );

    await tester.pumpWidget(_host(AgentHubPage(state: state)));

    expect(find.byKey(const ValueKey('agent-thinking-note')), findsNothing);
    expect(find.byKey(const ValueKey('agent-run-status-line')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('agent-run-status-line')),
        matching: find.text('我在组织回复～'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Agent Hub clears thinking note on later labeled progress', (
    tester,
  ) async {
    final state = AgentStreamRunState(
      phase: AgentStreamRunPhase.streaming,
      events: [
        AgentStreamEvent({'type': 'run.started'}),
        AgentStreamEvent({
          'type': 'run.progress',
          'payload': {'phase': 'model_reasoning'},
        }),
        AgentStreamEvent({
          'type': 'run.progress',
          'payload': {'label': '我正在整理回复～'},
        }),
      ],
    );

    await tester.pumpWidget(_host(AgentHubPage(state: state)));

    expect(find.byKey(const ValueKey('agent-thinking-note')), findsNothing);
    expect(find.byKey(const ValueKey('agent-run-status-line')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('agent-run-status-line')),
        matching: find.text('我正在整理回复～'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Agent Hub accepts legacy agent status line fields', (
    tester,
  ) async {
    final state = AgentStreamRunState(
      phase: AgentStreamRunPhase.streaming,
      events: [
        AgentStreamEvent({
          'type': 'CUSTOM',
          'payload': {'agentStatusLine': '我在接收你的消息～'},
        }),
      ],
    );

    await tester.pumpWidget(_host(AgentHubPage(state: state)));

    expect(find.byKey(const ValueKey('agent-run-status-line')), findsOneWidget);
    expect(find.text('我在接收你的消息～'), findsOneWidget);
  });

  testWidgets('Agent Hub accepts legacy agent thinking title fields', (
    tester,
  ) async {
    final state = AgentStreamRunState(
      phase: AgentStreamRunPhase.streaming,
      events: [
        AgentStreamEvent({
          'type': 'CUSTOM',
          'payload': {'agentThinkingTitle': '我接着处理下一步'},
        }),
      ],
    );

    await tester.pumpWidget(_host(AgentHubPage(state: state)));

    expect(find.byKey(const ValueKey('agent-thinking-note')), findsOneWidget);
    expect(find.text('我接着处理下一步'), findsOneWidget);
  });

  testWidgets('Agent Hub hides thinking note after reply text starts', (
    tester,
  ) async {
    final state = AgentStreamRunState(
      phase: AgentStreamRunPhase.streaming,
      textContent: '好的，我先给你一个方向。',
      events: [
        AgentStreamEvent({'type': 'run.started'}),
        AgentStreamEvent({
          'type': 'run.progress',
          'payload': {'phase': 'model_reasoning'},
        }),
      ],
    );

    await tester.pumpWidget(_host(AgentHubPage(state: state)));

    expect(find.text('好的，我先给你一个方向。'), findsOneWidget);
    expect(find.byKey(const ValueKey('agent-thinking-note')), findsNothing);
    expect(find.byKey(const ValueKey('agent-run-status-line')), findsNothing);
  });

  testWidgets('Agent Hub keeps backend progress visible until first token', (
    tester,
  ) async {
    final client = _ControllableAgentStreamClient();
    addTearDown(client.dispose);

    await tester.pumpWidget(
      _host(AgentHubPage(runner: AgentStreamRunner(client))),
    );

    await tester.enterText(
      find.byKey(const ValueKey('agent-composer-input')),
      '帮我生成待产包',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('agent-send-button')));
    await tester.pump();

    client.emit(
      0,
      AgentStreamEvent({
        'event_id': 'evt-progress-before-token',
        'type': 'run.progress',
        'thread_id': 'thread-progress',
        'run_id': 'run-progress',
        'sequence': 1,
        'payload': {'label': '正在生成待产包信息采集表单'},
      }),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('agent-run-status-line')), findsOneWidget);
    expect(find.text('正在生成待产包信息采集表单'), findsOneWidget);

    client.emit(
      0,
      AgentStreamEvent({
        'event_id': 'evt-first-token',
        'type': 'message.delta',
        'thread_id': 'thread-progress',
        'run_id': 'run-progress',
        'message_id': 'msg-progress',
        'sequence': 2,
        'payload': {'text': '好的'},
      }),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('好的'), findsOneWidget);
    expect(find.byKey(const ValueKey('agent-run-status-line')), findsNothing);
  });

  testWidgets('Agent Hub status line uses queued and started events', (
    tester,
  ) async {
    final state = AgentStreamRunState(
      phase: AgentStreamRunPhase.streaming,
      events: [
        AgentStreamEvent({
          'type': 'run.queued',
          'payload': {'label': '正在排队准备'},
        }),
        AgentStreamEvent({'type': 'run.started'}),
      ],
    );

    await tester.pumpWidget(_host(AgentHubPage(state: state)));

    expect(find.byKey(const ValueKey('agent-run-status-line')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('agent-run-status-line')),
        matching: find.text('我已经收到你的消息啦～'),
      ),
      findsOneWidget,
    );
  });
}

Widget _host(Widget child, {bool tickersEnabled = false}) {
  return TickerMode(
    enabled: tickersEnabled,
    child: MaterialApp(
      theme: momCozyTheme(),
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: SafeArea(child: child)),
    ),
  );
}

Future<void> _pumpFrames(WidgetTester tester, int count) async {
  for (var i = 0; i < count; i += 1) {
    await tester.pump();
  }
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  int maxFrames = 80,
}) async {
  for (var i = 0; i < maxFrames; i += 1) {
    if (condition()) return;
    await tester.pump(const Duration(milliseconds: 16));
  }
  if (!condition()) {
    fail('Condition was not met after $maxFrames pumped frames.');
  }
}

void _expectComposerControlsInsideSurface(WidgetTester tester) {
  final surfaceRect = tester.getRect(
    find.byKey(const ValueKey('agent-composer-surface')),
  );
  for (final key in [
    'agent-image-button',
    'agent-voice-button',
    'agent-send-button',
  ]) {
    final rect = tester.getRect(find.byKey(ValueKey(key)));
    expect(rect.left, greaterThanOrEqualTo(surfaceRect.left));
    expect(rect.right, lessThanOrEqualTo(surfaceRect.right));
    expect(rect.top, greaterThanOrEqualTo(surfaceRect.top));
    expect(rect.bottom, lessThanOrEqualTo(surfaceRect.bottom));
  }
}

void _expectComposerSendButtonBreathesVertically(WidgetTester tester) {
  final surfaceRect = tester.getRect(
    find.byKey(const ValueKey('agent-composer-surface')),
  );
  final sendRect = tester.getRect(
    find.byKey(const ValueKey('agent-send-button')),
  );

  expect(sendRect.top - surfaceRect.top, greaterThanOrEqualTo(6));
  expect(surfaceRect.bottom - sendRect.bottom, greaterThanOrEqualTo(6));
}

void _expectComposerControlsVerticallyCentered(WidgetTester tester) {
  final surfaceRect = tester.getRect(
    find.byKey(const ValueKey('agent-composer-surface')),
  );
  final imageRect = tester.getRect(
    find.byKey(const ValueKey('agent-image-button')),
  );
  final voiceRect = tester.getRect(
    find.byKey(const ValueKey('agent-voice-button')),
  );
  final sendRect = tester.getRect(
    find.byKey(const ValueKey('agent-send-button')),
  );

  expect(imageRect.center.dy, closeTo(surfaceRect.center.dy, 0.5));
  expect(voiceRect.center.dy, closeTo(surfaceRect.center.dy, 0.5));
  expect(sendRect.center.dy, closeTo(surfaceRect.center.dy, 0.5));
  expect(imageRect.center.dy, closeTo(voiceRect.center.dy, 0.5));
  expect(sendRect.center.dy, closeTo(voiceRect.center.dy, 0.5));
}

void _expectComposerInputVerticallyCentered(WidgetTester tester) {
  final surfaceRect = tester.getRect(
    find.byKey(const ValueKey('agent-composer-surface')),
  );
  final inputRect = tester.getRect(
    find.byKey(const ValueKey('agent-composer-input')),
  );

  expect(inputRect.center.dy, closeTo(surfaceRect.center.dy, 1));
}

class _FixtureAgentStreamClient implements AgentStreamClient {
  _FixtureAgentStreamClient(this.events);

  final List<AgentStreamEvent> events;
  final requests = <AgentStreamRequest>[];

  @override
  Stream<AgentStreamEvent> stream(AgentStreamRequest request) async* {
    requests.add(request);
    for (final event in events) {
      await Future<void>.delayed(Duration.zero);
      yield event;
    }
  }
}

class _MemoryAgentHubInteractionStateStore
    implements AgentHubInteractionStateStore {
  _MemoryAgentHubInteractionStateStore([this.snapshot]);

  AgentHubInteractionSnapshot? snapshot;

  @override
  Future<AgentHubInteractionSnapshot?> read() async => snapshot;

  @override
  Future<void> write(AgentHubInteractionSnapshot snapshot) async {
    this.snapshot = snapshot;
  }

  @override
  Future<void> clear() async {
    snapshot = null;
  }
}

class _NeverEndingAgentStreamClient implements AgentStreamClient {
  final requests = <AgentStreamRequest>[];
  final _controller = StreamController<AgentStreamEvent>();

  @override
  Stream<AgentStreamEvent> stream(AgentStreamRequest request) {
    requests.add(request);
    return _controller.stream;
  }

  Future<void> dispose() => _controller.close();
}

class _ControllableAgentStreamClient implements AgentStreamClient {
  final requests = <AgentStreamRequest>[];
  final _controllers = <StreamController<AgentStreamEvent>>[];

  @override
  Stream<AgentStreamEvent> stream(AgentStreamRequest request) {
    requests.add(request);
    final controller = StreamController<AgentStreamEvent>();
    _controllers.add(controller);
    return controller.stream;
  }

  void emit(int runIndex, AgentStreamEvent event) {
    _controllers[runIndex].add(event);
  }

  Future<void> dispose() async {
    for (final controller in _controllers) {
      await controller.close();
    }
  }
}

class _RetryAgentStreamClient implements AgentStreamClient {
  final requests = <AgentStreamRequest>[];

  @override
  Stream<AgentStreamEvent> stream(AgentStreamRequest request) async* {
    requests.add(request);
    await Future<void>.delayed(Duration.zero);

    if (requests.length == 1) {
      yield AgentStreamEvent(const {
        'event_id': 'evt-retry-2',
        'type': 'message.delta',
        'thread_id': 'thread-demo',
        'run_id': 'run-first',
        'message_id': 'msg-first',
        'sequence': 2,
        'payload': {'text': 'Partial answer'},
      });
      throw StateError('socket closed');
    }

    yield AgentStreamEvent(const {
      'event_id': 'evt-retry-3',
      'type': 'message.completed',
      'thread_id': 'thread-demo',
      'run_id': 'run-first',
      'message_id': 'msg-first',
      'sequence': 3,
      'payload': {'text': 'Retried answer'},
    });
    yield AgentStreamEvent(const {
      'event_id': 'evt-retry-4',
      'type': 'run.completed',
      'thread_id': 'thread-demo',
      'run_id': 'run-first',
      'message_id': 'msg-first',
      'sequence': 4,
    });
  }
}

class _FailingAgentStreamClient implements AgentStreamClient {
  _FailingAgentStreamClient(this.error);

  final Object error;
  final requests = <AgentStreamRequest>[];

  @override
  Stream<AgentStreamEvent> stream(AgentStreamRequest request) async* {
    requests.add(request);
    await Future<void>.delayed(Duration.zero);
    throw error;
  }
}

class _RecordingCancelConnector implements AgentStreamControlHttpConnector {
  final called = Completer<void>();
  Uri? uri;
  Map<String, String>? headers;
  String? body;

  @override
  Future<AgentStreamControlHttpResponse> post(
    Uri uri, {
    required Map<String, String> headers,
    required String body,
  }) async {
    this.uri = uri;
    this.headers = headers;
    this.body = body;
    if (!called.isCompleted) called.complete();
    return const AgentStreamControlHttpResponse(statusCode: 200, body: '{}');
  }
}

class _RecordingActionConnector implements AgentStreamControlHttpConnector {
  _RecordingActionConnector({
    this.response = const AgentStreamControlHttpResponse(
      statusCode: 200,
      body: '{}',
    ),
  });

  final AgentStreamControlHttpResponse response;
  final called = Completer<void>();
  Uri? uri;
  Map<String, String>? headers;
  String? body;

  @override
  Future<AgentStreamControlHttpResponse> post(
    Uri uri, {
    required Map<String, String> headers,
    required String body,
  }) async {
    this.uri = uri;
    this.headers = headers;
    this.body = body;
    if (!called.isCompleted) called.complete();
    return response;
  }
}

class _PageFakeVoiceRecorder implements AgentVoiceRecorder {
  _PageFakeVoiceRecorder({
    this.initialPermission = AgentVoiceInputPermissionState.granted,
    this.requestResult = AgentVoiceInputPermissionState.granted,
  });

  final AgentVoiceInputPermissionState initialPermission;
  final AgentVoiceInputPermissionState requestResult;
  final List<String> calls = [];

  @override
  Future<AgentVoiceInputPermissionState> permissionState() async {
    calls.add('permissionState');
    return initialPermission;
  }

  @override
  Future<AgentVoiceInputPermissionState> requestPermission() async {
    calls.add('requestPermission');
    return requestResult;
  }

  @override
  Future<void> start() async {
    calls.add('start');
  }

  @override
  Future<AgentVoiceRecording?> stop() async {
    calls.add('stop');
    return const AgentVoiceRecording(
      name: 'speech.webm',
      mimeType: 'audio/webm',
      bytes: [1],
    );
  }

  @override
  Future<void> cancel() async {
    calls.add('cancel');
  }
}

class _PageFakeVoiceTranscriber implements AgentVoiceTranscriber {
  const _PageFakeVoiceTranscriber(this.text);

  final String? text;

  @override
  Future<String?> transcribe(AgentVoiceRecording recording) async => text;
}

class _PageFakeVoicePlaybackPlayer implements AgentVoicePlaybackPlayer {
  final playedTexts = <String>[];
  var stopCount = 0;
  Completer<void>? _active;

  @override
  Future<void> playText(String text) {
    playedTexts.add(text);
    _active = Completer<void>();
    return _active!.future;
  }

  @override
  Future<void> stop() async {
    stopCount += 1;
    complete();
  }

  void complete() {
    final active = _active;
    if (active != null && !active.isCompleted) {
      active.complete();
    }
  }
}

class _FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  var _nextPlayerId = 1;
  final createdAssets = <String>[];
  final playedIds = <int>[];
  final disposedIds = <int>[];
  final loopingById = <int, bool>{};
  final volumeById = <int, double>{};
  final _eventsById = <int, StreamController<VideoEvent>>{};

  @override
  Future<void> init() async {}

  @override
  Future<int?> create(DataSource dataSource) async {
    return _create(dataSource);
  }

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    return _create(options.dataSource);
  }

  Future<int> _create(DataSource dataSource) async {
    final playerId = _nextPlayerId++;
    createdAssets.add(dataSource.asset ?? dataSource.uri ?? '');
    late final StreamController<VideoEvent> events;
    events = StreamController<VideoEvent>.broadcast(
      onListen: () {
        scheduleMicrotask(() {
          if (!events.isClosed) {
            events.add(
              VideoEvent(
                eventType: VideoEventType.initialized,
                duration: const Duration(seconds: 1),
                size: const Size(32, 32),
              ),
            );
          }
        });
      },
    );
    _eventsById[playerId] = events;
    return playerId;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    return _eventsById[playerId]?.stream ?? const Stream<VideoEvent>.empty();
  }

  @override
  Widget buildView(int playerId) {
    return SizedBox.expand(key: ValueKey('fake-video-player-view-$playerId'));
  }

  @override
  Widget buildViewWithOptions(VideoViewOptions options) {
    return buildView(options.playerId);
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {
    loopingById[playerId] = looping;
  }

  @override
  Future<void> setVolume(int playerId, double volume) async {
    volumeById[playerId] = volume;
  }

  @override
  Future<void> play(int playerId) async {
    playedIds.add(playerId);
    _eventsById[playerId]?.add(
      VideoEvent(
        eventType: VideoEventType.isPlayingStateUpdate,
        isPlaying: true,
      ),
    );
  }

  @override
  Future<void> pause(int playerId) async {
    _eventsById[playerId]?.add(
      VideoEvent(
        eventType: VideoEventType.isPlayingStateUpdate,
        isPlaying: false,
      ),
    );
  }

  @override
  Future<void> seekTo(int playerId, Duration position) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Future<void> dispose(int playerId) async {
    disposedIds.add(playerId);
    await _eventsById.remove(playerId)?.close();
  }
}
