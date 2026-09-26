import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_client.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_event.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_io_transport.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_run_state.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_runner.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_interaction_store.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_page.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_conversation.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_document_input.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_image_input.dart';
import 'package:momcozy_flutter_app/features/agent_hub/presentation/agent_file_previews.dart';
import 'package:momcozy_flutter_app/features/agent_hub/presentation/agent_image_previews.dart';
import 'package:momcozy_flutter_app/features/media/domain/media_upload.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import '../../support/fixture_reader.dart';

void main() {
  late _FakeVideoPlayerPlatform videoPlayerPlatform;

  setUp(() {
    videoPlayerPlatform = _FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = videoPlayerPlatform;
  });

  test('Agent Hub animated avatar videos exist in the bundled asset tree', () {
    for (final asset in [MomCozyAssets.agentThinkingAvatar]) {
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

  testWidgets(
    'notification conversation target opens the requested owned thread',
    (tester) async {
      const state = AgentStreamRunState(
        phase: AgentStreamRunPhase.finished,
        threadId: 'notification-thread',
        runId: 'notification-run',
        textContent: 'Saved conversation update',
      );
      final repository = _SequencedConversationRepository([
        _conversationHistory(state),
      ]);
      await tester.pumpWidget(
        _host(
          AgentHubPage(
            initialConversationId: 'notification-thread',
            conversationRepository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(repository.loadCalls, 1);
      expect(find.text('Saved conversation update'), findsOneWidget);
    },
  );

  testWidgets('Momcozy AI keeps the idle conversation free of service menus', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const AgentHubPage()));

    for (final key in [
      'agent-conversation-history-button',
      'agent-new-session-button',
      'agent-auto-voice-button',
    ]) {
      expect(find.byKey(ValueKey(key)), findsNothing);
    }
    expect(
      find.byKey(const ValueKey('agent-attachment-button')),
      findsOneWidget,
    );
    expect(find.text('Cozymate'), findsNothing);
    expect(find.text('母婴健康 · 日程 · 泌乳计划'), findsNothing);
    expect(find.byKey(const ValueKey('agent-v3-service-health')), findsNothing);
    expect(
      find.byKey(const ValueKey('agent-v3-service-schedule')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('agent-v3-service-lactation-plan')),
      findsNothing,
    );
    expect(find.text('我可以帮你'), findsNothing);
    expect(find.textContaining('健康建议不替代专业诊断'), findsNothing);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('agent-composer-input')))
          .controller
          ?.text,
      isEmpty,
    );
  });

  testWidgets('design shortcuts send through the existing conversation runner', (
    tester,
  ) async {
    final client = _ControllableAgentStreamClient();
    addTearDown(client.dispose);
    await tester.pumpWidget(
      _host(AgentHubPage(runner: AgentStreamRunner(client))),
    );
    await tester.tap(find.text('Milk supply insights'));
    await tester.pump();
    expect(
      client.requests.single.message,
      'I would like to understand my milk supply and feeding. Start by asking me the most important question.',
    );
    expect(find.text(client.requests.single.message), findsOneWidget);
    final recovery = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('Postpartum recovery check-in'),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(recovery.onPressed, isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'phase one ignores legacy action previews and keeps the composer usable',
    (tester) async {
      await tester.pumpWidget(
        _host(
          AgentHubPage(
            state: AgentStreamRunState(
              phase: AgentStreamRunPhase.waitingForConfirmation,
              textContent: '请确认是否删除任务。',
              events: [
                AgentStreamEvent(const {
                  'type': 'action.confirmation_required',
                  'action_id': 'schedule-delete-1',
                  'payload': {
                    'action_type': 'schedule_task_delete',
                    'summary': '删除匹配到的吸奶任务',
                    'preview_payload': {
                      'title': '删除下午 2 点吸奶任务',
                      'target': '吸奶任务',
                      'before': '2026-08-07 14:00',
                      'after': 'Delete',
                      'date': '2026-08-07',
                      'timezone': 'Asia/Shanghai',
                      'impact_scope': '仅此任务',
                    },
                  },
                }),
              ],
            ),
          ),
        ),
      );

      expect(find.text('日程删除'), findsNothing);
      expect(find.text('删除下午 2 点吸奶任务'), findsNothing);
      expect(
        find.text(
          'This action is not supported in this version. You can keep asking questions.',
        ),
        findsWidgets,
      );
      final composer = find.byKey(const ValueKey('agent-composer-input'));
      expect(tester.widget<TextField>(composer).enabled, isTrue);
      await tester.enterText(composer, '继续聊聊');
      expect(tester.widget<TextField>(composer).controller!.text, '继续聊聊');
    },
  );

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
                'payload': {'label': 'Let me think…'},
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
    final greetingRect = tester.getRect(
      find.textContaining("Hi, I'm Momcozy AI."),
    );

    expect(greetingRect.top - chatRect.top, lessThan(120));
  });

  testWidgets(
    'Agent Hub forwards a replay-safe record change application event once',
    (tester) async {
      final client = _ControllableAgentStreamClient();
      final applicationEvents = <AgentStreamEvent>[];
      addTearDown(client.dispose);

      await tester.pumpWidget(
        _host(
          AgentHubPage(
            runner: AgentStreamRunner(client),
            onApplicationEvent: applicationEvents.add,
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('agent-composer-input')),
        '记录刚刚吸出的 90 毫升',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('agent-send-button')));
      await tester.pump();

      final event = AgentStreamEvent(const {
        'event_id': 'evt-pumping-record-changed',
        'type': 'records.pumping.changed',
        'thread_id': 'thread-pumping-record-changed',
        'run_id': 'run-pumping-record-changed',
        'sequence': 1,
        'payload': {
          'operation': 'created',
          'record_id': 'pumping-record-001',
          'resource_type': 'pumping_record',
          'source': 'agent_action',
        },
      });
      client.emit(0, event);
      client.emit(0, event);
      await tester.pump();
      await tester.pump();

      expect(applicationEvents.map((event) => event.type), [
        'records.pumping.changed',
      ]);
    },
  );

  testWidgets('Agent Hub distinguishes backend run failure from disconnect', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const AgentRunTranscript(
          state: AgentStreamRunState(
            phase: AgentStreamRunPhase.error,
            errorMessage: 'tool_failed',
          ),
        ),
      ),
    );

    expect(find.text('No response this time.'), findsOneWidget);
    expect(
      find.text('Could not complete the request. Please try again later.'),
      findsOneWidget,
    );
    expect(find.textContaining('Connection lost'), findsNothing);
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

  testWidgets('Agent Hub reuses avatar video across TickerMode changes', (
    tester,
  ) async {
    const state = AgentStreamRunState(
      phase: AgentStreamRunPhase.streaming,
      messageId: 'msg-ticker-reuse',
      textContent: 'Still responding.',
    );

    await tester.pumpWidget(
      _host(const AgentHubPage(state: state), tickersEnabled: true),
    );
    await tester.pump();
    await tester.pump();

    expect(videoPlayerPlatform.createdAssets, [
      MomCozyAssets.agentThinkingAvatar,
    ]);

    await tester.pumpWidget(
      _host(const AgentHubPage(state: state), tickersEnabled: false),
    );
    await tester.pump();

    expect(videoPlayerPlatform.disposedIds, isEmpty);
    expect(videoPlayerPlatform.pausedIds, isNotEmpty);

    await tester.pumpWidget(
      _host(const AgentHubPage(state: state), tickersEnabled: true),
    );
    await tester.pump();

    expect(videoPlayerPlatform.createdAssets, [
      MomCozyAssets.agentThinkingAvatar,
    ]);
    expect(videoPlayerPlatform.playedIds.length, greaterThanOrEqualTo(2));
  });

  testWidgets('Agent Hub virtualizes long history messages', (tester) async {
    tester.view.physicalSize = const Size(390, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final history = List<AgentHubHistoryMessage>.generate(200, (index) {
      return AgentHubHistoryMessage(
        role: index.isEven
            ? AgentHubHistoryRole.user
            : AgentHubHistoryRole.assistant,
        content: '历史消息 $index：这是一段用于验证长历史懒构建的内容，需要足够长来占据一点垂直空间。',
      );
    });

    await tester.pumpWidget(_host(AgentHubPage(historyMessages: history)));

    expect(find.byKey(const ValueKey('agent-history-panel')), findsOneWidget);
    expect(find.byKey(const ValueKey('agent-history-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('agent-history-199')), findsNothing);
  });

  testWidgets('Agent Hub hides a persisted motion assessment system trigger', (
    tester,
  ) async {
    final store = _MemoryAgentHubInteractionStateStore(
      const AgentHubInteractionSnapshot(
        runState: AgentStreamRunState(
          phase: AgentStreamRunPhase.finished,
          threadId: 'thread-motion-feedback',
          textContent: 'Your head and neck assessment feedback is ready.',
        ),
        historyMessages: [
          AgentHubHistorySnapshot(
            role: 'user',
            content:
                '[系统流程触发]用户刚完成体态动态评估。请调用 '
                'motion_assessment_result.read。',
          ),
        ],
      ),
    );

    await tester.pumpWidget(_host(AgentHubPage(interactionStateStore: store)));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('[系统流程触发]'), findsNothing);
    expect(
      find.text(
        'Your head and neck assessment feedback is ready.',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(store.snapshot?.historyMessages, isEmpty);
  });

  testWidgets(
    'Agent Hub applies cold-start auto-send after restoring the thread',
    (tester) async {
      final client = _FixtureAgentStreamClient(const []);
      final store = _MemoryAgentHubInteractionStateStore(
        const AgentHubInteractionSnapshot(
          runState: AgentStreamRunState(
            phase: AgentStreamRunPhase.finished,
            threadId: 'thread-restored-before-prefill',
            textContent: '上一轮回复',
          ),
          historyMessages: [
            AgentHubHistorySnapshot(role: 'user', content: '上一轮问题'),
          ],
        ),
      );

      await tester.pumpWidget(
        _host(
          AgentHubPage(
            runner: AgentStreamRunner(client),
            interactionStateStore: store,
            initialComposerText: '继续分析',
            initialAutoSend: true,
          ),
        ),
      );
      await _pumpUntil(tester, () => client.requests.isNotEmpty);

      expect(client.requests, hasLength(1));
      expect(client.requests.single.message, '继续分析');
      expect(client.requests.single.threadId, 'thread-restored-before-prefill');
    },
  );

  testWidgets('Agent Hub does not overwrite history while restore is pending', (
    tester,
  ) async {
    final store = _DeferredAgentHubInteractionStateStore();

    await tester.pumpWidget(_host(AgentHubPage(interactionStateStore: store)));
    await tester.pump();
    await tester.pumpWidget(_host(const SizedBox.shrink()));
    await tester.pump();

    expect(store.writeCount, 0);
    expect(store.clearCount, 0);

    store.completeRead(
      const AgentHubInteractionSnapshot(
        historyMessages: [
          AgentHubHistorySnapshot(role: 'user', content: '仍应保留'),
        ],
      ),
    );
    await tester.pump();
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

  testWidgets('Agent Hub dismisses the keyboard after the run is accepted', (
    tester,
  ) async {
    final client = _FixtureAgentStreamClient([
      AgentStreamEvent(const {
        'event_id': 'evt-keyboard-started',
        'thread_id': 'thread-keyboard',
        'run_id': 'run-keyboard',
        'message_id': 'message-keyboard',
        'sequence': 1,
        'type': 'run.started',
      }),
    ]);

    await tester.pumpWidget(
      _host(AgentHubPage(runner: AgentStreamRunner(client))),
    );

    final input = find.byKey(const ValueKey('agent-composer-input'));
    await tester.tap(input);
    await tester.enterText(input, '帮我看看今天的记录');
    await tester.pump();

    expect(_composerHasFocus(tester), isTrue);

    await tester.tap(find.byKey(const ValueKey('agent-send-button')));
    await tester.pumpAndSettle();

    expect(client.requests, hasLength(1));
    expect(_composerHasFocus(tester), isFalse);
  });

  testWidgets('Agent Hub keeps the keyboard open when send is not accepted', (
    tester,
  ) async {
    final client = _FailingAgentStreamClient(
      StateError('SocketException: connection refused'),
    );

    await tester.pumpWidget(
      _host(AgentHubPage(runner: AgentStreamRunner(client))),
    );

    final input = find.byKey(const ValueKey('agent-composer-input'));
    await tester.tap(input);
    await tester.enterText(input, '网络失败时继续编辑');
    await tester.pump();

    expect(_composerHasFocus(tester), isTrue);

    await tester.tap(find.byKey(const ValueKey('agent-send-button')));
    await tester.pumpAndSettle();

    expect(client.requests, hasLength(1));
    expect(_composerHasFocus(tester), isTrue);
  });

  testWidgets('Agent quick replies match the product chrome', (tester) async {
    final selected = <String>[];

    await tester.pumpWidget(
      _host(
        AgentQuickRepliesBar(
          replies: const ['Keep talking', 'Tell me more', 'Try another topic'],
          onSelected: selected.add,
        ),
      ),
    );

    expect(find.byKey(const ValueKey('agent-quick-replies')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('agent-quick-replies-title-line')),
      findsOneWidget,
    );
    expect(
      tester.getSize(
        find.byKey(const ValueKey('agent-quick-replies-title-line')),
      ),
      const Size(16, 1),
    );
    expect(find.text('You might ask'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsNWidgets(3));
    expect(find.byType(InkWell), findsNWidgets(3));

    await tester.tap(find.byKey(const ValueKey('agent-quick-reply-1')));
    await tester.pump();

    expect(selected, ['Tell me more']);
  });

  testWidgets('long English quick replies wrap at 320px and 2x', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    const longReply =
        'Could we discuss how to make pumping more comfortable during my return to work?';
    final selected = <String>[];

    await tester.pumpWidget(
      _host(
        SingleChildScrollView(
          child: AgentQuickRepliesBar(
            replies: const [
              longReply,
              'Review feeding notes',
              'Ask another question',
            ],
            onSelected: selected.add,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final text = find.descendant(
      of: find.byKey(const ValueKey('agent-quick-reply-0')),
      matching: find.text(longReply),
    );
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: text, matching: find.byType(RichText)),
    );
    expect(paragraph.didExceedMaxLines, isFalse);
    await tester.ensureVisible(
      find.byKey(const ValueKey('agent-quick-reply-0')),
    );
    await tester.tap(find.byKey(const ValueKey('agent-quick-reply-0')));
    expect(selected, [longReply]);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Agent quick replies render only for legacy three item payloads',
    (tester) async {
      await tester.pumpWidget(
        _host(
          AgentQuickRepliesBar(
            replies: const ['Keep talking', 'Tell me more'],
            onSelected: (_) {},
          ),
        ),
      );

      expect(find.byKey(const ValueKey('agent-quick-replies')), findsNothing);
      expect(find.text('You might ask'), findsNothing);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    },
  );

  testWidgets('Agent Hub hides generated quick replies from legacy payloads', (
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
          'text': 'I have finished organizing the notes.',
          'workflow_reply': {
            'workflow_state_id': '7f4df45b-c88f-4a1a-9810-d4f8e66ab4f5',
            'workflow_type': 'lactation_support',
            'revision': 4,
            'step_token': 'opaque-step-token',
          },
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
          requestBuilder: (message) => AgentStreamRequest(
            message: message,
            idempotencyKey: 'request-${message.length}',
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

    expect(find.text('I have finished organizing the notes.'), findsOneWidget);
    expect(find.byKey(const ValueKey('agent-quick-replies')), findsNothing);
    expect(find.byKey(const ValueKey('agent-quick-reply-0')), findsNothing);
    expect(find.text('You might ask'), findsNothing);
    expect(find.text('继续聊这个'), findsNothing);
    expect(client.requests, hasLength(1));
    expect(recordedClientEvents, isEmpty);
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

      final sentText = find.byWidgetPredicate(
        (widget) => widget is Text && widget.data == 'nihao',
      );
      expect(sentText, findsOneWidget);
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('agent-composer-input')),
            )
            .controller!
            .text,
        'nihao',
      );
      expect(find.textContaining("Hi, I'm Momcozy AI."), findsOneWidget);
      expect(find.textContaining('No response this time.'), findsOneWidget);
      expect(
        find.text(
          'No network connection. Check your connection and try again.',
        ),
        findsOneWidget,
      );

      final chatRect = tester.getRect(
        find.byKey(const ValueKey('agent-chat-scroll-view')),
      );
      final greetingRect = tester.getRect(
        find.textContaining("Hi, I'm Momcozy AI."),
      );
      final userRect = tester.getRect(sentText);
      final errorRect = tester.getRect(
        find.textContaining('No response this time.'),
      );
      final retryRect = tester.getRect(
        find.byKey(const ValueKey('agent-retry-button')),
      );
      expect(greetingRect.top - chatRect.top, lessThan(120));
      expect(userRect.top, greaterThan(greetingRect.bottom));
      expect(errorRect.top, greaterThan(userRect.bottom));
      expect(retryRect.bottom, lessThanOrEqualTo(chatRect.bottom));
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
    final mediaRepository = _FakeAgentImageMediaRepository();

    await tester.pumpWidget(
      _host(
        AgentHubPage(
          runner: AgentStreamRunner(client),
          mediaRepository: mediaRepository,
          pickImage: (_) async => AgentStreamImageInput(
            dataUrl: '',
            localBytes: base64Decode(
              'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=',
            ),
            mimeType: 'image/png',
            name: 'pump-display.png',
            size: 68,
            detail: 'low',
          ),
        ),
      ),
    );

    final composerTopBeforeMenu = tester.getTopLeft(
      find.byKey(const ValueKey('agent-composer-surface')),
    );
    await tester.tap(find.byKey(const ValueKey('agent-attachment-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('agent-attachment-menu')), findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Photos'), findsOneWidget);
    expect(find.text('Files'), findsOneWidget);
    expect(find.text('拍照'), findsNothing);
    expect(find.text('上传'), findsNothing);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('agent-composer-surface'))),
      composerTopBeforeMenu,
    );

    await tester.tap(find.byKey(const ValueKey('agent-attachment-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('agent-attachment-menu')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('agent-attachment-button')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('agent-attachment-photo-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('agent-image-attachment-chip')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('agent-image-attachment-0')),
      findsOneWidget,
    );
    expect(find.text('pump-display.png'), findsOneWidget);

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
      client.requests.single.images.single.fileId,
      '0ea4b76d-2bc4-4ab8-91b7-3b24df53c518',
    );
    expect(client.requests.single.images.single.dataUrl, isEmpty);
    expect(mediaRepository.uploadedFiles.single.bytes, isNotEmpty);
    expect(mediaRepository.deletedFileIds, isEmpty);
    expect(
      find.byKey(const ValueKey('agent-image-attachment-chip')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('agent-sent-image-0')), findsOneWidget);
    expect(find.text('点击查看'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('agent-sent-image-0')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('agent-sent-image-close')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('agent-sent-image-close')));
    await tester.pumpAndSettle();
  });

  testWidgets('Agent Hub uploads and sends a PDF file attachment', (
    tester,
  ) async {
    final client = _FixtureAgentStreamClient(
      parseAgentJsonl(
        readMigrationFixture('agent_events/text_stream_basic.jsonl'),
      ),
    );
    final mediaRepository = _FakeAgentImageMediaRepository();

    await tester.pumpWidget(
      _host(
        AgentHubPage(
          runner: AgentStreamRunner(client),
          mediaRepository: mediaRepository,
          pickDocument: () async => AgentHubLocalDocument(
            bytes: Uint8List.fromList('%PDF-1.4\nfixture'.codeUnits),
            mimeType: 'application/pdf',
            name: 'checkup-report.pdf',
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('agent-attachment-button')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('agent-attachment-file-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('agent-file-attachment-chip')),
      findsOneWidget,
    );
    expect(find.byType(AgentComposerFileAttachment), findsOneWidget);
    expect(find.text('checkup-report.pdf'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('agent-send-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(client.requests.single.message, 'Please review this file');
    expect(client.requests.single.images, isEmpty);
    expect(client.requests.single.files, hasLength(1));
    expect(client.requests.single.files.single.name, 'checkup-report.pdf');
    expect(
      client.requests.single.files.single.fileId,
      '0ea4b76d-2bc4-4ab8-91b7-3b24df53c518',
    );
    expect(mediaRepository.uploadedFiles.single.mimeType, 'application/pdf');
    expect(find.byKey(const ValueKey('agent-sent-file-0')), findsOneWidget);
  });

  testWidgets('Agent Hub deletes an abandoned upload when it is removed', (
    tester,
  ) async {
    final mediaRepository = _FakeAgentImageMediaRepository();
    await tester.pumpWidget(
      _host(
        AgentHubPage(
          runner: AgentStreamRunner(
            _FixtureAgentStreamClient(const <AgentStreamEvent>[]),
          ),
          mediaRepository: mediaRepository,
          pickImage: (_) async => const AgentStreamImageInput(
            dataUrl:
                'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=',
            mimeType: 'image/png',
            name: 'discard-me.png',
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('agent-attachment-button')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('agent-attachment-photo-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('agent-remove-image-button')));
    await tester.pumpAndSettle();

    expect(mediaRepository.deletedFileIds, [
      '0ea4b76d-2bc4-4ab8-91b7-3b24df53c518',
    ]);
  });

  testWidgets(
    'Agent Hub removes locally while cleanup waits and resumes after reopening',
    (tester) async {
      final gate = Completer<void>();
      final media = _FakeAgentImageMediaRepository(
        deleteFailure: StateError('unavailable'),
        deleteGate: gate,
      );
      final store = _MemoryAgentHubInteractionStateStore();
      await tester.pumpWidget(
        _host(
          AgentHubPage(
            interactionStateStore: store,
            mediaRepository: media,
            pickImage: (_) async => const AgentStreamImageInput(
              dataUrl:
                  'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=',
              mimeType: 'image/png',
              name: 'draft.png',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final input = find.byKey(const ValueKey('agent-composer-input'));
      await tester.enterText(input, 'Keep my draft');
      await tester.tap(find.byKey(const ValueKey('agent-attachment-button')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('agent-attachment-photo-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('agent-remove-image-button')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('agent-image-attachment-chip')),
        findsNothing,
      );
      expect(tester.widget<TextField>(input).controller!.text, 'Keep my draft');
      expect(tester.widget<TextField>(input).enabled, isNot(false));
      expect(store.snapshot!.attachedImages, isEmpty);
      expect(store.snapshot!.pendingAttachmentCleanupIds, media.deletedFileIds);
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(store.snapshot!.pendingAttachmentCleanupIds, hasLength(1));
      expect(store.snapshot!.hasConversationHistory, isFalse);

      media.deleteFailure = null;
      media.deleteGate = null;
      await tester.pumpWidget(
        _host(
          AgentHubPage(interactionStateStore: store, mediaRepository: media),
        ),
      );
      await tester.pumpAndSettle();
      expect(media.deletedFileIds, hasLength(2));
      expect(media.deleteKeys.toSet(), hasLength(1));
      expect(store.snapshot?.pendingAttachmentCleanupIds ?? [], isEmpty);
      expect(
        find.byKey(const ValueKey('agent-image-attachment-chip')),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Agent Hub keeps camera and gallery image sources distinct', (
    tester,
  ) async {
    final sources = <AgentImageInputSource>[];
    await tester.pumpWidget(
      _host(
        AgentHubPage(
          runner: AgentStreamRunner(_NeverEndingAgentStreamClient()),
          pickImage: (source) async {
            sources.add(source);
            return AgentStreamImageInput(
              dataUrl:
                  'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=',
              mimeType: 'image/png',
              name: '${source.name}.png',
            );
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('agent-attachment-button')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('agent-attachment-camera-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('agent-attachment-button')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('agent-attachment-photo-button')),
    );
    await tester.pumpAndSettle();

    expect(sources, [
      AgentImageInputSource.camera,
      AgentImageInputSource.gallery,
    ]);
    expect(
      find.byKey(const ValueKey('agent-image-attachment-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('agent-image-attachment-1')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('agent-remove-image-button')));
    await tester.pump();

    expect(find.text('gallery.png'), findsOneWidget);
    expect(find.byType(AgentComposerImageAttachment), findsOneWidget);
    expect(
      tester
          .widget<AgentComposerImageAttachment>(
            find.byType(AgentComposerImageAttachment),
          )
          .image
          .name,
      'gallery.png',
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
          pickImage: (_) async => const AgentStreamImageInput(
            dataUrl: 'data:image/png;base64,fixture',
            mimeType: 'image/png',
            name: 'before-send.png',
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('agent-attachment-button')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('agent-attachment-photo-button')),
    );
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
          pickImage: (_) async => const AgentStreamImageInput(
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
    await tester.tap(find.byKey(const ValueKey('agent-attachment-button')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('agent-attachment-photo-button')),
    );
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
          pickImage: (_) async => const AgentStreamImageInput(
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
    expect(find.text('retained-across-tab.png'), findsOneWidget);
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
    expect(find.byKey(const ValueKey('agent-run-status-line')), findsNothing);
    expect(find.text('Thinking…'), findsNothing);
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
    expect(
      find.text('Connection interrupted. You can try again.'),
      findsOneWidget,
    );
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
          pickImage: (_) async => const AgentStreamImageInput(
            dataUrl: 'data:image/png;base64,fixture',
            mimeType: 'image/png',
            name: 'only-image.png',
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('agent-attachment-button')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('agent-attachment-camera-button')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('agent-send-button')));
    await tester.pumpAndSettle();

    expect(client.requests.single.message, 'Please look at this image');
    expect(client.requests.single.images.single.name, 'only-image.png');
  });

  testWidgets('Agent Hub applies initial composer prefill', (tester) async {
    final client = _ControllableAgentStreamClient();
    await tester.pumpWidget(
      _host(
        AgentHubPage(
          runner: AgentStreamRunner(client),
          initialComposerText: '我想调整今天的吸乳排期',
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(client.requests, isEmpty);

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
    await tester.pump();

    expect(client.requests, hasLength(1));
  });

  testWidgets(
    'Agent Hub starts hidden motion-result feedback without a fake user bubble',
    (tester) async {
      final client = _ControllableAgentStreamClient();
      addTearDown(client.dispose);

      await tester.pumpWidget(
        _host(
          AgentHubPage(
            runner: AgentStreamRunner(client),
            initialAutoRunRequest: const AgentHubAutoRunRequest(
              requestMessage: '请读取刚完成的体态评估并给出简短反馈。',
              idempotencyKey: 'motion-assessment-feedback:assessment-1',
              metadata: {
                'source': 'motion_assessment_completion',
                'assessment_id': 'assessment-1',
              },
            ),
          ),
        ),
      );
      await _pumpUntil(tester, () => client.requests.isNotEmpty);

      expect(client.requests, hasLength(1));
      expect(client.requests.single.idempotencyKey, endsWith('assessment-1'));
      expect(client.requests.single.metadata['assessment_id'], 'assessment-1');
      expect(find.text('请读取刚完成的体态评估并给出简短反馈。'), findsNothing);
      client.emit(
        0,
        AgentStreamEvent(const {
          'event_id': 'hidden-failure',
          'type': 'run.failed',
          'run_id': 'hidden-run',
          'sequence': 1,
          'payload': {'code': 'runtime_error'},
        }),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('agent-composer-input')),
            )
            .controller!
            .text,
        isEmpty,
      );
    },
  );

  testWidgets(
    'Agent Hub refreshes the source conversation for durable motion feedback',
    (tester) async {
      const sourceState = AgentStreamRunState(
        phase: AgentStreamRunPhase.finished,
        threadId: 'thread-source',
        runId: 'run-source',
        textContent: 'Let’s begin the assessment.',
      );
      const feedbackState = AgentStreamRunState(
        phase: AgentStreamRunPhase.finished,
        threadId: 'thread-source',
        runId: 'run-feedback',
        textContent:
            'Your head and neck posture looked steady during this assessment. Consider a gentle relaxation break each day.',
      );
      final repository = _SequencedConversationRepository([
        _conversationHistory(sourceState),
        _conversationHistory(feedbackState),
      ]);

      await tester.pumpWidget(
        _host(
          AgentHubPage(
            state: sourceState,
            conversationRepository: repository,
            externalConversationRefreshInterval: Duration.zero,
            externalConversationRefreshAttempts: 3,
          ),
        ),
      );
      await tester.pumpWidget(
        _host(
          AgentHubPage(
            state: sourceState,
            conversationRepository: repository,
            externalConversationRefreshKey: 'motion:assessment-1',
            externalConversationRefreshInterval: Duration.zero,
            externalConversationRefreshAttempts: 3,
          ),
        ),
      );
      await _pumpUntil(
        tester,
        () => find.text(feedbackState.textContent).evaluate().isNotEmpty,
      );

      expect(repository.loadCalls, 2);
      expect(find.text(feedbackState.textContent), findsOneWidget);
    },
  );

  testWidgets(
    'durable motion feedback keeps refreshing with a visible pending state',
    (tester) async {
      const sourceState = AgentStreamRunState(
        phase: AgentStreamRunPhase.finished,
        threadId: 'thread-source',
        runId: 'run-source',
        textContent: 'Let’s begin the assessment.',
      );
      const feedbackState = AgentStreamRunState(
        phase: AgentStreamRunPhase.finished,
        threadId: 'thread-source',
        runId: 'run-feedback',
        textContent: 'Your assessment feedback is ready.',
      );
      final repository = _SequencedConversationRepository([
        _conversationHistory(sourceState),
        _conversationHistory(sourceState),
        _conversationHistory(feedbackState),
      ]);

      await tester.pumpWidget(
        _host(
          AgentHubPage(
            state: sourceState,
            conversationRepository: repository,
            externalConversationRefreshKey: 'motion:assessment-durable',
            externalConversationRefreshInterval: const Duration(seconds: 1),
            externalConversationRefreshAttempts: 1,
            externalConversationRefreshUntilFound: true,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(const ValueKey('motion-feedback-pending')),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 2));
      await _pumpUntil(
        tester,
        () => find.text(feedbackState.textContent).evaluate().isNotEmpty,
      );

      expect(repository.loadCalls, greaterThan(1));
      expect(
        find.byKey(const ValueKey('motion-feedback-pending')),
        findsNothing,
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

    expect(find.text('Response stopped'), findsOneWidget);
  });

  testWidgets(
    'Agent Hub keeps failed copy button-free and accepts the next turn',
    (tester) async {
      final client = _ControllableAgentStreamClient();
      addTearDown(client.dispose);

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

      client.emit(
        0,
        AgentStreamEvent(const {
          'event_id': 'failed-first-turn',
          'type': 'run.failed',
          'thread_id': 'thread-terminal-followup',
          'run_id': 'run-failed-first',
          'sequence': 1,
          'payload': {'code': 'runtime_error'},
        }),
      );
      await tester.pump();

      expect(find.text('No response this time.'), findsOneWidget);
      expect(find.byKey(const ValueKey('agent-retry-button')), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey('agent-composer-input')),
        'Second turn',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('agent-send-button')));
      await tester.pump();

      expect(client.requests, hasLength(2));
      expect(client.requests.last.runId, isNull);
      expect(client.requests.last.threadId, 'thread-terminal-followup');

      client.emit(
        1,
        AgentStreamEvent(const {
          'event_id': 'second-turn-message',
          'type': 'message.completed',
          'thread_id': 'thread-terminal-followup',
          'run_id': 'run-second',
          'message_id': 'message-second',
          'sequence': 1,
          'payload': {'role': 'assistant', 'text': 'Second turn response.'},
        }),
      );
      client.emit(
        1,
        AgentStreamEvent(const {
          'event_id': 'second-turn-completed',
          'type': 'run.completed',
          'thread_id': 'thread-terminal-followup',
          'run_id': 'run-second',
          'sequence': 2,
        }),
      );
      await _pumpFrames(tester, 4);

      expect(find.text('Second turn response.'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('agent-assistant-avatar-thinking')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('agent-assistant-avatar-static')),
        findsWidgets,
      );
    },
  );

  testWidgets('Agent Hub settles server cancel before starting the next turn', (
    tester,
  ) async {
    final client = _ControllableAgentStreamClient();
    final cancelConnector = _DeferredCancelConnector();
    addTearDown(client.dispose);

    await tester.pumpWidget(
      _host(
        AgentHubPage(
          runner: AgentStreamRunner(client),
          cancelClient: AgentStreamCancelClient(
            endpoint: AgentStreamEndpoint(
              uri: Uri.parse('http://127.0.0.1:8769/v1/agent/runs'),
            ),
            connector: cancelConnector,
          ),
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
        'event_id': 'cancel-first-started',
        'type': 'run.started',
        'thread_id': 'thread-cancel-followup',
        'run_id': 'run-cancel-first',
        'sequence': 1,
      }),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('agent-stop-button')));
    await tester.pump();
    await cancelConnector.called.future;

    expect(find.text('Requesting server cancellation'), findsOneWidget);
    expect(find.text('Response stopped'), findsNothing);
    expect(find.byKey(const ValueKey('agent-retry-button')), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('agent-composer-input')),
      'Second turn after cancel',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('agent-send-button')));
    await tester.pump();

    expect(client.requests, hasLength(1));

    cancelConnector.complete();
    await _pumpFrames(tester, 4);

    expect(client.requests, hasLength(2));
    expect(client.requests.last.runId, isNull);
    expect(client.requests.last.threadId, 'thread-cancel-followup');

    client.emit(
      1,
      AgentStreamEvent(const {
        'event_id': 'cancel-followup-message',
        'type': 'message.completed',
        'thread_id': 'thread-cancel-followup',
        'run_id': 'run-after-cancel',
        'message_id': 'message-after-cancel',
        'sequence': 1,
        'payload': {
          'role': 'assistant',
          'text': 'Response after cancellation.',
        },
      }),
    );
    client.emit(
      1,
      AgentStreamEvent(const {
        'event_id': 'cancel-followup-completed',
        'type': 'run.completed',
        'thread_id': 'thread-cancel-followup',
        'run_id': 'run-after-cancel',
        'sequence': 2,
      }),
    );
    await _pumpFrames(tester, 4);

    expect(find.text('Response after cancellation.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('agent-assistant-avatar-thinking')),
      findsNothing,
    );
  });

  testWidgets('Agent Hub does not claim server cancellation after a 401', (
    tester,
  ) async {
    final client = _ControllableAgentStreamClient();
    final cancelConnector = _RecordingCancelConnector(
      response: const AgentStreamControlHttpResponse(
        statusCode: 401,
        body: '{"error":{"code":"authentication_required"}}',
      ),
    );
    addTearDown(client.dispose);

    await tester.pumpWidget(
      _host(
        AgentHubPage(
          runner: AgentStreamRunner(client),
          cancelClient: AgentStreamCancelClient(
            endpoint: AgentStreamEndpoint(
              uri: Uri.parse('http://127.0.0.1:8010/v1/agent/runs'),
            ),
            onUnauthorized: () async => false,
            connector: cancelConnector,
          ),
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('agent-composer-input')),
      'Cancel this run',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('agent-send-button')));
    await tester.pump();
    client.emit(
      0,
      AgentStreamEvent(const {
        'event_id': 'cancel-unauthorized-started',
        'type': 'run.started',
        'thread_id': 'thread-cancel-unauthorized',
        'run_id': 'run-cancel-unauthorized',
        'sequence': 1,
      }),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('agent-stop-button')));
    await cancelConnector.called.future;
    await _pumpFrames(tester, 4);

    expect(
      find.text('Stopped on this device. Server cancellation not confirmed'),
      findsOneWidget,
    );
    expect(find.text('Response stopped'), findsNothing);
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

  testWidgets(
    'Agent Hub queues a follow-up after completed text until run terminal',
    (tester) async {
      final client = _ControllableAgentStreamClient();
      final cancelConnector = _RecordingCancelConnector();
      final cancelClient = AgentStreamCancelClient(
        endpoint: AgentStreamEndpoint(
          uri: Uri.parse('http://127.0.0.1:8769/v1/agent/runs'),
        ),
        connector: cancelConnector,
      );
      addTearDown(client.dispose);

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
          'event_id': 'followup-message-completed',
          'type': 'message.completed',
          'thread_id': 'thread-followup-completed',
          'run_id': 'run-followup-completed',
          'message_id': 'msg-followup-completed',
          'sequence': 1,
          'payload': {
            'role': 'assistant',
            'text': 'Analysis is ready.',
            'workflow_reply': {
              'workflow_state_id': '7f4df45b-c88f-4a1a-9810-d4f8e66ab4f5',
              'workflow_type': 'device_unboxing',
              'revision': 2,
              'step_token': 'device-step-token',
            },
          },
        }),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('agent-device-workflow-actions')),
        findsNothing,
      );

      await tester.enterText(
        find.byKey(const ValueKey('agent-composer-input')),
        'Second turn',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('agent-send-button')));
      await tester.pump();

      expect(client.requests, hasLength(1));
      expect(cancelConnector.called.isCompleted, isFalse);

      client.emit(
        0,
        AgentStreamEvent(const {
          'event_id': 'followup-run-completed',
          'type': 'run.completed',
          'thread_id': 'thread-followup-completed',
          'run_id': 'run-followup-completed',
          'sequence': 2,
        }),
      );
      await _pumpFrames(tester, 4);

      expect(client.requests, hasLength(2));
      expect(client.requests.last.message, 'Second turn');
      expect(client.requests.last.threadId, 'thread-followup-completed');
      expect(client.requests.last.metadata['workflow_reply'], {
        'workflow_state_id': '7f4df45b-c88f-4a1a-9810-d4f8e66ab4f5',
        'workflow_type': 'device_unboxing',
        'revision': 2,
        'step_token': 'device-step-token',
      });
      expect(cancelConnector.called.isCompleted, isFalse);
      expect(find.text('Analysis is ready.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Agent Hub bounds follow-up handoff when the terminal event is missing',
    (tester) async {
      final client = _ControllableAgentStreamClient();
      final cancelConnector = _RecordingCancelConnector();
      final cancelClient = AgentStreamCancelClient(
        endpoint: AgentStreamEndpoint(
          uri: Uri.parse('http://127.0.0.1:8769/v1/agent/runs'),
        ),
        connector: cancelConnector,
      );
      addTearDown(client.dispose);

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
          'event_id': 'missing-terminal-message',
          'type': 'message.completed',
          'thread_id': 'thread-missing-terminal',
          'run_id': 'run-missing-terminal',
          'message_id': 'msg-missing-terminal',
          'sequence': 1,
          'payload': {'role': 'assistant', 'text': 'Analysis is ready.'},
        }),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('agent-composer-input')),
        'Continue after timeout',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('agent-send-button')));
      await tester.pump();

      expect(client.requests, hasLength(1));
      await tester.pump(const Duration(seconds: 2));
      await _pumpFrames(tester, 4);

      expect(cancelConnector.called.isCompleted, isTrue);
      expect(
        cancelConnector.uri?.path,
        '/v1/agent/runs/run-missing-terminal/cancel',
      );
      expect(client.requests, hasLength(2));
      expect(client.requests.last.message, 'Continue after timeout');
      expect(client.requests.last.threadId, 'thread-missing-terminal');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'phase one sends the queued follow-up after unsupported confirmation',
    (tester) async {
      final client = _ControllableAgentStreamClient();
      addTearDown(client.dispose);

      await tester.pumpWidget(
        _host(AgentHubPage(runner: AgentStreamRunner(client))),
      );
      final composer = find.byKey(const ValueKey('agent-composer-input'));
      await tester.enterText(composer, 'First turn');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('agent-send-button')));
      await tester.pump();
      client.emit(
        0,
        AgentStreamEvent(const {
          'event_id': 'confirmation-handoff-message',
          'type': 'message.completed',
          'thread_id': 'thread-confirmation-handoff',
          'run_id': 'run-confirmation-handoff',
          'message_id': 'msg-confirmation-handoff',
          'sequence': 1,
          'payload': {'role': 'assistant', 'text': 'Please confirm next.'},
        }),
      );
      await tester.pump();
      await tester.enterText(composer, 'Keep this draft');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('agent-send-button')));
      await tester.pump();

      client.emit(
        0,
        AgentStreamEvent(const {
          'event_id': 'confirmation-handoff-waiting',
          'type': 'run.waiting_for_confirmation',
          'thread_id': 'thread-confirmation-handoff',
          'run_id': 'run-confirmation-handoff',
          'sequence': 2,
        }),
      );
      await _pumpFrames(tester, 4);

      expect(client.requests, hasLength(2));
      expect(client.requests.last.message, 'Keep this draft');
      expect(tester.widget<TextField>(composer).enabled, isTrue);
      expect(find.byKey(const ValueKey('agent-action-panel')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Agent Hub smooths live deltas while preserving complete run text',
    (tester) async {
      final client = _ControllableAgentStreamClient();
      addTearDown(client.dispose);
      await tester.pumpWidget(
        _host(
          AgentHubPage(runner: AgentStreamRunner(client)),
          tickersEnabled: true,
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('agent-composer-input')),
        'typing test',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('agent-send-button')));
      await tester.pump();
      const answer = 'Hello. What would you like to talk about today?';
      client.emit(
        0,
        AgentStreamEvent(const {
          'type': 'message.delta',
          'run_id': 'typing-run',
          'message_id': 'typing-message',
          'payload': {'text': answer},
        }),
      );
      await tester.pump();
      expect(find.text(answer), findsNothing);
      expect(find.text('H'), findsOneWidget);
      expect(
        tester
            .widget<AgentRunTranscript>(find.byType(AgentRunTranscript))
            .state
            .textContent,
        answer,
      );
      await tester.pump(const Duration(milliseconds: 72));
      final shown = tester
          .widget<AgentRunTranscript>(find.byType(AgentRunTranscript))
          .visibleText!;
      expect(shown.length, greaterThan(1));
      expect(answer, startsWith(shown));
      client.emit(
        0,
        AgentStreamEvent(const {
          'type': 'message.completed',
          'run_id': 'typing-run',
          'message_id': 'typing-message',
          'payload': {'role': 'assistant', 'content': answer},
        }),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text(answer), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Agent Hub renders repeated streaming text deltas immediately', (
    tester,
  ) async {
    final client = _ControllableAgentStreamClient();
    addTearDown(client.dispose);

    await tester.pumpWidget(
      _host(AgentHubPage(runner: AgentStreamRunner(client))),
    );

    await tester.enterText(
      find.byKey(const ValueKey('agent-composer-input')),
      'Stream slowly',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('agent-send-button')));
    await tester.pump();

    client.emit(
      0,
      AgentStreamEvent(const {
        'type': 'message.delta',
        'thread_id': 'thread-coalesce',
        'run_id': 'run-coalesce',
        'message_id': 'msg-coalesce',
        'payload': {'text': 'Hel'},
      }),
    );
    await tester.pump();

    expect(find.text('Hel'), findsOneWidget);
    final pageShellBeforeSecondDelta = tester.widget<ColoredBox>(
      find.byKey(const ValueKey('agent-hub-page')),
    );

    client.emit(
      0,
      AgentStreamEvent(const {
        'type': 'message.delta',
        'thread_id': 'thread-coalesce',
        'run_id': 'run-coalesce',
        'message_id': 'msg-coalesce',
        'payload': {'text': 'lo'},
      }),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Hello'), findsOneWidget);
    final pageShellAfterSecondDelta = tester.widget<ColoredBox>(
      find.byKey(const ValueKey('agent-hub-page')),
    );
    expect(
      identical(pageShellBeforeSecondDelta, pageShellAfterSecondDelta),
      isTrue,
    );
  });

  testWidgets('Agent Hub throttles active run snapshot writes during deltas', (
    tester,
  ) async {
    final client = _ControllableAgentStreamClient();
    final store = _MemoryAgentHubInteractionStateStore();
    addTearDown(client.dispose);

    await tester.pumpWidget(
      _host(
        AgentHubPage(
          runner: AgentStreamRunner(client),
          interactionStateStore: store,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('agent-composer-input')),
      'Stream persistently',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('agent-send-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));
    store.writeCount = 0;

    for (final text in ['Hel', 'lo', '!']) {
      client.emit(
        0,
        AgentStreamEvent({
          'event_id': 'delta:persist-$text',
          'type': 'message.delta',
          'thread_id': 'thread-persist',
          'run_id': 'run-persist',
          'message_id': 'msg-persist',
          'payload': {'text': text},
        }),
      );
    }
    await tester.pump();
    await tester.pump();

    expect(find.text('Hello!'), findsOneWidget);
    expect(store.writeCount, 0);

    await tester.pump(const Duration(milliseconds: 500));
    expect(store.writeCount, 0);

    await tester.pump(const Duration(milliseconds: 300));
    expect(store.writeCount, 0);

    await tester.pump(const Duration(milliseconds: 250));
    expect(store.writeCount, 1);
    expect(store.snapshot?.runState.textContent, 'Hello!');
  });

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
    expect(find.text('Response stopped'), findsOneWidget);
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

    expect(
      find.text('Connection interrupted. You can try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('socket closed'), findsNothing);
    expect(find.byKey(const ValueKey('agent-retry-button')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('agent-retry-button')));
    await tester.pumpAndSettle();

    expect(client.requests, hasLength(2));
    expect(client.requests.first.message, 'Retry my request');
    expect(client.requests.last.message, 'Retry my request');
    expect(client.requests.last.runId, 'run-first');
    expect(client.requests.last.afterSequence, 2);
    expect(find.text('Partial answer completed.'), findsOneWidget);
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

    expect(find.text('Request timed out. Try again later.'), findsOneWidget);
    expect(find.byKey(const ValueKey('agent-retry-button')), findsOneWidget);
    expect(find.textContaining('TimeoutException'), findsNothing);
    expect(find.textContaining('agent request timeout'), findsNothing);
  });

  testWidgets(
    'Agent Hub reuses the turn idempotency key when run creation is retried',
    (tester) async {
      final client = _RetryBeforeRunCreatedAgentStreamClient();

      await tester.pumpWidget(
        _host(AgentHubPage(runner: AgentStreamRunner(client))),
      );

      await tester.enterText(
        find.byKey(const ValueKey('agent-composer-input')),
        '帮我整理泌乳支持信息',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('agent-send-button')));
      await tester.pumpAndSettle();

      expect(client.requests, hasLength(1));
      expect(client.requests.single.runId, isNull);
      expect(client.requests.single.idempotencyKey, isNotEmpty);
      expect(find.text('Request timed out. Try again later.'), findsOneWidget);
      expect(find.byKey(const ValueKey('agent-retry-button')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('agent-retry-button')));
      await tester.pumpAndSettle();

      expect(client.requests, hasLength(2));
      expect(client.requests.last.runId, isNull);
      expect(
        client.requests.last.idempotencyKey,
        client.requests.first.idempotencyKey,
      );
      expect(find.text('Your lactation support form is open.'), findsOneWidget);
    },
  );

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

    expect(
      find.text('No network connection. Check your connection and try again.'),
      findsOneWidget,
    );
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
      'Check my device status',
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('agent-send-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('agent-work-panel')), findsNothing);
    expect(find.text('处理进度'), findsNothing);
    expect(find.text('已生成设备状态说明'), findsNothing);
    expect(
      find.text('I checked the device status and prepared the next step.'),
      findsOneWidget,
    );
    expect(find.textContaining('devices.pump_status.read'), findsNothing);
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
                  'tool_call_id': 'call-device-status',
                  'tool_name': 'devices.pump_status.read',
                },
              }),
              AgentStreamEvent(const {
                'type': 'tool.completed',
                'thread_id': 'thread-tool',
                'run_id': 'run-tool',
                'payload': {
                  'tool_call_id': 'call-device-status',
                  'tool_name': 'devices.pump_status.read',
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

  testWidgets(
    'phase one ignores legacy action cards regardless of visibility',
    (tester) async {
      await tester.pumpWidget(
        _host(
          AgentHubPage(
            state: AgentStreamRunState(
              phase: AgentStreamRunPhase.finished,
              textContent: '动作处理完成。',
              events: [
                AgentStreamEvent(const {
                  'type': 'action.applied',
                  'action_id': 'action-direct-hidden',
                  'payload': {
                    'action_id': 'action-direct-hidden',
                    'action_status': 'applied',
                    'title': '直接执行动作',
                    'user_visible': false,
                    'requires_confirmation': false,
                  },
                }),
                AgentStreamEvent(const {
                  'type': 'action.applied',
                  'action_id': 'action-implicit-applied',
                  'payload': {
                    'action_id': 'action-implicit-applied',
                    'action_status': 'applied',
                    'title': '普通已应用动作',
                  },
                }),
                AgentStreamEvent(const {
                  'type': 'action.confirmation_required',
                  'action_id': 'action-visible-confirmation',
                  'payload': {
                    'action_id': 'action-visible-confirmation',
                    'action_status': 'confirmation_required',
                    'title': '高风险确认动作',
                    'user_visible': true,
                    'requires_confirmation': true,
                  },
                }),
              ],
            ),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('agent-action-panel')), findsNothing);
      expect(
        find.byKey(
          const ValueKey('agent-action-card-action-visible-confirmation'),
        ),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('agent-action-card-action-direct-hidden')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('agent-action-card-action-implicit-applied')),
        findsNothing,
      );
      expect(find.text('高风险确认动作'), findsNothing);
      expect(find.text('直接执行动作'), findsNothing);
      expect(find.text('普通已应用动作'), findsNothing);
    },
  );

  testWidgets('phase one restores legacy waiting state without locking input', (
    tester,
  ) async {
    const actionId = '22222222-2222-2222-2222-222222222222';
    final store = _MemoryAgentHubInteractionStateStore(
      AgentHubInteractionSnapshot(
        runState: AgentStreamRunState(
          phase: AgentStreamRunPhase.waitingForConfirmation,
          threadId: 'thread-restore',
          runId: 'run-restore',
          textContent: 'Please confirm before sending this to expert support.',
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

    final client = _FixtureAgentStreamClient(const []);
    await tester.pumpWidget(
      _host(
        AgentHubPage(
          interactionStateStore: store,
          runner: AgentStreamRunner(client),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Please confirm before sending this to expert support.'),
      findsOneWidget,
    );
    expect(find.text('等待确认后继续'), findsNothing);
    expect(
      find.text(
        'This action is not supported in this version. You can keep asking questions.',
      ),
      findsWidgets,
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('agent-composer-input')))
          .enabled,
      isTrue,
    );
    expect(find.byKey(ValueKey('agent-action-card-$actionId')), findsNothing);
    expect(find.text('提交人工支持'), findsNothing);
    expect(find.byKey(const ValueKey('agent-retry-button')), findsNothing);
    expect(client.requests, isEmpty);
  });

  testWidgets('Agent Hub replay does not revive an applied-only action card', (
    tester,
  ) async {
    final store = _MemoryAgentHubInteractionStateStore(
      AgentHubInteractionSnapshot(
        runState: AgentStreamRunState.fromMap({
          'phase': 'finished',
          'textContent': 'The action has already been completed.',
          'events': [
            {
              'event_id': 'evt-replay-applied-only',
              'type': 'action.applied',
              'action_id': 'action-replay-applied-only',
              'payload': {
                'action_id': 'action-replay-applied-only',
                'action_status': 'applied',
                'title': '不应恢复的动作卡',
              },
            },
          ],
        }),
      ),
    );

    await tester.pumpWidget(_host(AgentHubPage(interactionStateStore: store)));
    await tester.pumpAndSettle();

    expect(find.text('The action has already been completed.'), findsOneWidget);
    expect(find.byKey(const ValueKey('agent-action-panel')), findsNothing);
    expect(find.text('不应恢复的动作卡'), findsNothing);
    expect(find.text('已应用'), findsNothing);
  });

  testWidgets('Agent Hub does not archive an unpublished failed artifact', (
    tester,
  ) async {
    final artifactEvent = AgentStreamEvent(
      readFixtureMap('agent_events/rich_text_artifact.json'),
    );
    final store = _MemoryAgentHubInteractionStateStore();
    final client = _ControllableAgentStreamClient();
    addTearDown(client.dispose);

    await tester.pumpWidget(
      _host(
        AgentHubPage(
          runner: AgentStreamRunner(client),
          interactionStateStore: store,
          state: AgentStreamRunState(
            phase: AgentStreamRunPhase.error,
            artifactEvents: {'care-note-001': artifactEvent},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('agent-composer-input')),
      'Continue',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('agent-send-button')));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final archivedAssistant = store.snapshot!.historyMessages.firstWhere(
      (message) => message.role == 'assistant',
    );
    expect(
      archivedAssistant.runState?.artifactEvents ??
          const <String, AgentStreamEvent>{},
      isEmpty,
    );
    expect(
      (archivedAssistant.runState?.events ?? const <AgentStreamEvent>[]).where(
        (event) => event.type.startsWith('artifact.'),
      ),
      isEmpty,
    );
  });

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

  testWidgets('Agent Hub wraps long content on compact mobile viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final longText = List.filled(
      6,
      'There are several pumping notes today. We can review the amounts from each side, comfort, timing, and your baby’s feeding together.',
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
              'title': 'Continue',
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
    expect(
      find.textContaining('There are several pumping notes today'),
      findsWidgets,
    );
    expect(find.text('长内容建议'), findsNothing);

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
    expect(
      find.text('Connection interrupted. You can try again.'),
      findsOneWidget,
    );
    expect(find.text('socket closed'), findsNothing);
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

      expect(find.byKey(const ValueKey('agent-run-status-line')), findsNothing);
      expect(find.text('Thinking…'), findsNothing);

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
## A few ways to support postpartum recovery

### 1. Physical recovery
- **Notice changes in bleeding**: Ask your clinician about any concerns.
- **Rest when you can**: Try to rest while your baby sleeps.

1. Note how you feel today.
2. Review [care suggestions](https://example.com/care).

> After a few days of notes, we can look at what has changed.

You can also track your `temperature`.

```text
milk_total: 120ml
```

| Item | Status |
| --- | --- |
| Sleep | Not recorded |
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
    expect(
      find.text(
        'A few ways to support postpartum recovery',
        findRichText: true,
      ),
      findsOneWidget,
    );
    final markdownStyles = tester
        .widget<MarkdownBody>(find.byType(MarkdownBody))
        .styleSheet!;
    expect(markdownStyles.p!.height, 1.65);
    expect(markdownStyles.h2!.fontSize, 18);
    expect(markdownStyles.h2!.height, 1.4);
    expect(markdownStyles.a!.decoration, TextDecoration.underline);
    expect(
      find.text('1. Physical recovery', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('Notice changes in bleeding', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('Rest when you can', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('Note how you feel today', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('care suggestions', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('After a few days of notes', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('temperature', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('milk_total: 120ml'), findsOneWidget);
    expect(find.text('Item'), findsOneWidget);
    expect(find.text('Sleep'), findsOneWidget);
  });

  testWidgets('Agent Hub keeps markdown rendering stable while streaming', (
    tester,
  ) async {
    const markdown =
        '## Preparing your notes\n- **Important**: Please wait for the full answer.';

    await tester.pumpWidget(
      _host(
        const AgentHubPage(
          state: AgentStreamRunState(
            phase: AgentStreamRunPhase.streaming,
            textContent: markdown,
          ),
        ),
      ),
    );

    expect(find.byType(MarkdownBody), findsOneWidget);
    expect(find.textContaining('##'), findsNothing);
    expect(find.textContaining('**'), findsNothing);
    expect(
      find.text('Preparing your notes', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('Important', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('Agent Hub shows no copy until an approved tool status arrives', (
    tester,
  ) async {
    final state = AgentStreamRunState(
      phase: AgentStreamRunPhase.streaming,
      events: [
        AgentStreamEvent({
          'type': 'run.progress',
          'payload': {'label': "Checking today's records…"},
        }),
      ],
    );

    await tester.pumpWidget(_host(AgentHubPage(state: state)));
    expect(find.byKey(const ValueKey('agent-run-status-line')), findsNothing);
    expect(find.text('Thinking…'), findsNothing);

    final withToolStatus = state.applyEvent(
      AgentStreamEvent({
        'type': 'run.progress',
        'payload': {
          'phase': 'tool_status',
          'call_id': 'records-1',
          'outcome': 'running',
          'user_facing_status': {
            'running': '正在核对与你的问题相关的记录。',
            'success': '已核对相关记录，正在结合你的情况分析。',
            'failure': '暂时无法读取相关记录。',
          },
        },
      }),
    );
    await tester.pumpWidget(_host(AgentHubPage(state: withToolStatus)));
    expect(find.byKey(const ValueKey('agent-run-status-line')), findsOneWidget);
    expect(find.text('正在核对与你的问题相关的记录。'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('agent-run-status-title-sweep')),
      findsOneWidget,
    );
  });

  testWidgets('legacy Chinese progress text never reaches the status line', (
    tester,
  ) async {
    final state = AgentStreamRunState(
      phase: AgentStreamRunPhase.streaming,
      events: [
        AgentStreamEvent({'type': 'run.started'}),
        AgentStreamEvent({
          'type': 'run.progress',
          'payload': {'label': '正在处理请求'},
        }),
      ],
    );

    await tester.pumpWidget(_host(AgentHubPage(state: state)));

    expect(find.text('正在处理请求'), findsNothing);
    expect(find.text('Thinking…'), findsNothing);
  });

  testWidgets('Agent Hub does not invent context-ready status copy', (
    tester,
  ) async {
    final state = AgentStreamRunState(
      phase: AgentStreamRunPhase.streaming,
      events: [
        AgentStreamEvent({'type': 'run.started'}),
        AgentStreamEvent({
          'type': 'run.progress',
          'payload': {'phase': 'context_ready'},
        }),
      ],
    );

    await tester.pumpWidget(_host(AgentHubPage(state: state)));
    expect(find.byKey(const ValueKey('agent-run-status-line')), findsNothing);
    expect(find.text('我看一下你的信息'), findsNothing);
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
            'semantic': {
              'label': 'Putting together a response…',
              'surface': 'status_bar',
            },
          },
        }),
      ],
    );

    await tester.pumpWidget(_host(AgentHubPage(state: state)));

    expect(find.text('Thinking…'), findsNothing);
    expect(find.text('Putting together a response…'), findsNothing);
    expect(find.text('正在处理请求。'), findsNothing);
  });

  testWidgets('Agent Hub ignores retired visibility-only semantic metadata', (
    tester,
  ) async {
    final state = AgentStreamRunState(
      phase: AgentStreamRunPhase.streaming,
      events: [
        AgentStreamEvent({'type': 'run.started'}),
        AgentStreamEvent({
          'type': 'run.progress',
          'payload': {
            'semantic': {'label': '不应通过旧字段展示', 'visibility': 'status'},
          },
        }),
      ],
    );

    await tester.pumpWidget(_host(AgentHubPage(state: state)));

    expect(find.text('不应通过旧字段展示'), findsNothing);
    expect(find.text('Thinking…'), findsNothing);
  });

  testWidgets('Agent Hub keeps thinking note semantic out of status line', (
    tester,
  ) async {
    final state = AgentStreamRunState(
      phase: AgentStreamRunPhase.streaming,
      events: [
        AgentStreamEvent({'type': 'run.started'}),
        AgentStreamEvent({
          'type': 'run.progress',
          'payload': {
            'label': 'Let me think…',
            'semantic': {'label': 'Let me think…', 'surface': 'thinking_note'},
          },
        }),
      ],
    );

    await tester.pumpWidget(_host(AgentHubPage(state: state)));
    expect(find.byKey(const ValueKey('agent-run-status-line')), findsNothing);
    expect(find.byKey(const ValueKey('agent-thinking-note')), findsNothing);
  });

  testWidgets('Agent Hub does not invent status from model reasoning', (
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

    expect(find.byKey(const ValueKey('agent-run-status-line')), findsNothing);
    expect(find.byKey(const ValueKey('agent-thinking-note')), findsNothing);
    expect(find.text('Let me think…'), findsNothing);
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
    expect(find.byKey(const ValueKey('agent-run-status-line')), findsNothing);
  });

  testWidgets(
    'Agent Hub ignores tool semantic labels without approved status',
    (tester) async {
      final state =
          const AgentStreamRunState(
            phase: AgentStreamRunPhase.streaming,
          ).applyEvent(
            AgentStreamEvent({
              'type': 'tool.started',
              'payload': {
                'tool_call_id': 'tool-milk-status',
                'tool_name': 'records.milk_status.read',
                'label': '奶量状态',
                'semantic': {
                  'label': 'Checking your milk supply records…',
                  'surface': 'work_item',
                  'lifecycle': 'running',
                },
              },
            }),
          );

      await tester.pumpWidget(_host(AgentHubPage(state: state)));

      expect(find.byKey(const ValueKey('agent-run-status-line')), findsNothing);
      expect(find.text('正在读取奶量状态'), findsNothing);
      expect(find.text('Checking your milk supply records…'), findsNothing);
    },
  );

  testWidgets(
    'Agent Hub keeps a fast tool completion ahead of immediate generic progress',
    (tester) async {
      final now = DateTime.now().toUtc();
      final state = AgentStreamRunState(
        phase: AgentStreamRunPhase.streaming,
        events: [
          AgentStreamEvent({
            'type': 'tool.completed',
            'created_at': now
                .subtract(const Duration(milliseconds: 100))
                .toIso8601String(),
            'payload': {
              'tool_call_id': 'tool-milk-status',
              'semantic': {
                'label': "I've checked your milk supply records.",
                'surface': 'work_item',
                'lifecycle': 'completed',
                'merge_key': 'tool:tool-milk-status',
                'priority': 70,
              },
            },
          }),
          AgentStreamEvent({
            'type': 'run.progress',
            'created_at': now.toIso8601String(),
            'payload': {
              'semantic': {
                'label': 'Working on the next step…',
                'surface': 'status_bar',
                'lifecycle': 'running',
                'merge_key': 'progress:model_followup',
                'priority': 55,
              },
            },
          }),
        ],
      );

      await tester.pumpWidget(_host(AgentHubPage(state: state)));

      expect(find.text("I've checked your milk supply records."), findsNothing);
      expect(find.text('Thinking…'), findsNothing);
      expect(find.text('Working on the next step…'), findsNothing);
    },
  );

  testWidgets('Agent loop status copy is vertically and horizontally aligned', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AgentRunStatusLine(title: 'I have your message.'),
            AgentThinkingNote(title: 'Let me think…'),
          ],
        ),
      ),
    );

    final statusLine = tester.widget<Container>(
      find.byKey(const ValueKey('agent-run-status-line')),
    );
    final thinkingPadding = tester.widget<Padding>(
      find
          .ancestor(
            of: find.byKey(const ValueKey('agent-thinking-note')),
            matching: find.byType(Padding),
          )
          .first,
    );
    final statusTextLeft = tester
        .getTopLeft(find.text('I have your message.'))
        .dx;
    final thinkingTextLeft = tester.getTopLeft(find.text('Let me think…')).dx;

    expect(statusLine.padding, const EdgeInsets.symmetric(vertical: 4));
    expect(
      tester.widget<Text>(find.text('I have your message.')).style?.fontSize,
      13,
    );
    expect(
      tester.widget<Text>(find.text('I have your message.')).style?.fontWeight,
      FontWeight.w500,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('agent-run-status-line')),
        matching: find.byType(Row),
      ),
      findsNothing,
    );
    expect(thinkingPadding.padding, EdgeInsets.zero);
    expect(statusTextLeft, closeTo(thinkingTextLeft, 0.1));
  });

  testWidgets(
    'status stays inside avatar height and leaves no gap when hidden',
    (tester) async {
      for (final width in [320.0, 393.0]) {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          _host(
            const AgentHubPage(
              state: AgentStreamRunState(
                phase: AgentStreamRunPhase.streaming,
                textContent: '正在整理今天的记录。',
              ),
            ),
          ),
        );
        await tester.pump();
        final avatar = tester.getRect(
          find.byKey(const ValueKey('agent-assistant-avatar')),
        );
        expect(
          find.byKey(const ValueKey('agent-run-status-line')),
          findsNothing,
        );
        expect(avatar.width, greaterThan(0));
        await tester.pumpWidget(
          _host(
            const AgentHubPage(
              state: AgentStreamRunState(
                phase: AgentStreamRunPhase.finished,
                textContent: '今天的记录整理好了。',
              ),
            ),
          ),
        );
        await tester.pump();
        expect(
          find.byKey(const ValueKey('agent-run-status-line')),
          findsNothing,
        );
        final bubble = tester.getRect(
          find.byKey(const ValueKey('agent-assistant-bubble')),
        );
        final finishedAvatar = tester.getRect(
          find.byKey(const ValueKey('agent-assistant-avatar')),
        );
        expect(bubble.top, closeTo(finishedAvatar.top, 0.1));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );

  testWidgets('Agent thinking note stays event-driven until cleared', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        AgentHubPage(
          state: AgentStreamRunState(
            phase: AgentStreamRunPhase.streaming,
            events: [
              AgentStreamEvent({'type': 'run.started'}),
              AgentStreamEvent({
                'type': 'run.progress',
                'payload': {
                  'phase': 'model_reasoning',
                  'label': 'Let me think…',
                },
              }),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Thinking…'), findsNothing);

    await tester.pump(const Duration(milliseconds: 2201));

    expect(find.text('Thinking…'), findsNothing);
  });

  testWidgets(
    'Agent Hub ignores non-semantic tool and artifact status fallbacks',
    (tester) async {
      await tester.pumpWidget(
        _host(
          AgentHubPage(
            state: AgentStreamRunState(
              phase: AgentStreamRunPhase.streaming,
              events: [
                AgentStreamEvent({'type': 'run.started'}),
                AgentStreamEvent({
                  'type': 'tool.completed',
                  'payload': {
                    'tool_call_id': 'tool-read-001',
                    'tool_name': 'devices.pump_status.read',
                  },
                }),
                AgentStreamEvent({
                  'type': 'artifact.created',
                  'payload': {
                    'artifact_id': 'artifact-note-001',
                    'artifact_type': 'rich_text',
                  },
                }),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Working on the next step…'), findsNothing);
      expect(find.byKey(const ValueKey('agent-run-status-line')), findsNothing);
    },
  );

  testWidgets('Agent Hub renders after-tool status and thinking note', (
    tester,
  ) async {
    final state = AgentStreamRunState(
      phase: AgentStreamRunPhase.streaming,
      events: [
        AgentStreamEvent({'type': 'run.started'}),
        AgentStreamEvent({
          'type': 'run.progress',
          'payload': {
            'phase': 'model_followup',
            'label': 'Working on the next step…',
            'semantic': {
              'label': 'Working on the next step…',
              'surface': 'status_bar',
            },
          },
        }),
        AgentStreamEvent({
          'type': 'run.progress',
          'payload': {
            'phase': 'model_reasoning_after_tool',
            'label': 'Let me think…',
            'semantic': {'label': 'Let me think…', 'surface': 'thinking_note'},
          },
        }),
      ],
    );

    await tester.pumpWidget(_host(AgentHubPage(state: state)));
    expect(find.byKey(const ValueKey('agent-run-status-line')), findsNothing);
    expect(find.byKey(const ValueKey('agent-thinking-note')), findsNothing);
  });

  testWidgets('Agent Hub renders artifact and action semantic status', (
    tester,
  ) async {
    AgentStreamRunState stateWith(AgentStreamEvent event) =>
        AgentStreamRunState(
          phase: AgentStreamRunPhase.streaming,
          events: [
            AgentStreamEvent({'type': 'run.started'}),
            event,
          ],
        );

    await tester.pumpWidget(
      _host(
        AgentHubPage(
          state: stateWith(
            AgentStreamEvent({
              'type': 'artifact.created',
              'payload': {
                'semantic': {
                  'label': 'Your lactation support plan is ready.',
                  'surface': 'artifact',
                },
              },
            }),
          ),
        ),
      ),
    );

    expect(find.text('Your lactation support plan is ready.'), findsNothing);
    expect(find.text('Thinking…'), findsNothing);

    await tester.pumpWidget(
      _host(
        AgentHubPage(
          state: stateWith(
            AgentStreamEvent({
              'type': 'action.confirmation_required',
              'payload': {
                'semantic': {
                  'label': 'Please confirm before I continue.',
                  'surface': 'action',
                },
              },
            }),
          ),
        ),
      ),
    );

    expect(find.text('Please confirm before I continue.'), findsNothing);
    expect(find.text('Thinking…'), findsNothing);
  });

  testWidgets('Agent Hub does not render failed semantic status', (
    tester,
  ) async {
    final state = AgentStreamRunState(
      phase: AgentStreamRunPhase.error,
      events: [
        AgentStreamEvent({
          'type': 'run.failed',
          'payload': {
            'semantic': {
              'label': '这轮暂时没处理好',
              'surface': 'status_bar',
              'lifecycle': 'failed',
            },
          },
        }),
      ],
    );

    await tester.pumpWidget(_host(AgentHubPage(state: state)));

    expect(find.byKey(const ValueKey('agent-run-status-line')), findsNothing);
    expect(find.text('这轮暂时没处理好'), findsNothing);
    expect(find.text('No response this time.'), findsOneWidget);
  });

  testWidgets('Agent Hub treats hidden semantic as authoritative', (
    tester,
  ) async {
    final state = AgentStreamRunState(
      phase: AgentStreamRunPhase.streaming,
      events: [
        AgentStreamEvent({'type': 'run.started'}),
        AgentStreamEvent({
          'type': 'run.progress',
          'payload': {
            'label': '这段载荷文案不应展示',
            'semantic': {'label': '内部完成事件', 'surface': 'hidden'},
          },
        }),
      ],
    );

    await tester.pumpWidget(_host(AgentHubPage(state: state)));

    expect(find.text('这段载荷文案不应展示'), findsNothing);
    expect(find.text('内部完成事件'), findsNothing);
    expect(find.text('Thinking…'), findsNothing);
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
          'payload': {'label': 'Putting together a response…'},
        }),
      ],
    );

    await tester.pumpWidget(_host(AgentHubPage(state: state)));

    expect(find.byKey(const ValueKey('agent-thinking-note')), findsNothing);
    expect(find.byKey(const ValueKey('agent-run-status-line')), findsNothing);
  });

  testWidgets('Agent Hub switches status copy after reply text starts', (
    tester,
  ) async {
    final state = AgentStreamRunState(
      phase: AgentStreamRunPhase.streaming,
      textContent: 'I can suggest a first step.',
      events: [
        AgentStreamEvent({'type': 'run.started'}),
        AgentStreamEvent({
          'type': 'run.progress',
          'payload': {'phase': 'model_reasoning'},
        }),
      ],
    );

    await tester.pumpWidget(_host(AgentHubPage(state: state)));

    expect(find.text('I can suggest a first step.'), findsOneWidget);
    expect(find.byKey(const ValueKey('agent-thinking-note')), findsNothing);
    expect(find.byKey(const ValueKey('agent-run-status-line')), findsNothing);
  });

  testWidgets(
    'Agent Hub shows no copy until tool status and hides it on first token',
    (tester) async {
      final client = _ControllableAgentStreamClient();
      addTearDown(client.dispose);

      await tester.pumpWidget(
        _host(AgentHubPage(runner: AgentStreamRunner(client))),
      );

      await tester.enterText(
        find.byKey(const ValueKey('agent-composer-input')),
        '帮我生成泌乳支持表单',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('agent-send-button')));
      await tester.pump();

      client.emit(
        0,
        AgentStreamEvent({
          'event_id': 'evt-run-queued',
          'type': 'run.queued',
          'thread_id': 'thread-progress',
          'run_id': 'run-progress',
          'sequence': 1,
          'payload': {'label': 'I have your message.'},
        }),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('agent-run-status-line')), findsNothing);
      expect(find.text('Thinking…'), findsNothing);

      client.emit(
        0,
        AgentStreamEvent({
          'event_id': 'evt-user-message-completed',
          'type': 'message.completed',
          'thread_id': 'thread-progress',
          'run_id': 'run-progress',
          'message_id': 'msg-user',
          'sequence': 2,
          'payload': {'role': 'user'},
        }),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('agent-run-status-line')), findsNothing);
      expect(find.text('Thinking…'), findsNothing);

      client.emit(
        0,
        AgentStreamEvent({
          'event_id': 'evt-progress-before-token',
          'type': 'run.progress',
          'thread_id': 'thread-progress',
          'run_id': 'run-progress',
          'sequence': 3,
          'payload': {'label': 'Preparing your lactation intake form…'},
        }),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const ValueKey('agent-run-status-line')), findsNothing);

      client.emit(
        0,
        AgentStreamEvent({
          'event_id': 'evt-tool-status',
          'type': 'run.progress',
          'thread_id': 'thread-progress',
          'run_id': 'run-progress',
          'sequence': 4,
          'payload': {
            'phase': 'tool_status',
            'call_id': 'records-1',
            'outcome': 'running',
            'user_facing_status': {
              'running': '正在核对与你的问题相关的记录。',
              'success': '已核对相关记录，正在结合你的情况分析。',
              'failure': '暂时无法读取相关记录。',
            },
          },
        }),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('正在核对与你的问题相关的记录。'), findsOneWidget);

      client.emit(
        0,
        AgentStreamEvent({
          'event_id': 'evt-first-token',
          'type': 'message.delta',
          'thread_id': 'thread-progress',
          'run_id': 'run-progress',
          'message_id': 'msg-progress',
          'sequence': 5,
          'payload': {'text': 'I can help'},
        }),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('I can help'), findsOneWidget);
      expect(find.byKey(const ValueKey('agent-run-status-line')), findsNothing);

      client.emit(
        0,
        AgentStreamEvent({
          'event_id': 'evt-assistant-message-completed',
          'type': 'message.completed',
          'thread_id': 'thread-progress',
          'run_id': 'run-progress',
          'message_id': 'msg-progress',
          'sequence': 6,
          'payload': {
            'role': 'assistant',
            'text': 'I can help. I have organized the notes.',
          },
        }),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.text('I can help. I have organized the notes.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('agent-run-status-line')), findsNothing);
    },
  );

  testWidgets(
    'Agent Hub ignores queued and started labels before tool status',
    (tester) async {
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

      expect(find.byKey(const ValueKey('agent-run-status-line')), findsNothing);
    },
  );
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
  for (final key in ['agent-attachment-button', 'agent-send-button']) {
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
    find.byKey(const ValueKey('agent-attachment-button')),
  );
  final sendRect = tester.getRect(
    find.byKey(const ValueKey('agent-send-button')),
  );

  expect(imageRect.center.dy, closeTo(surfaceRect.center.dy, 0.5));
  expect(sendRect.center.dy, closeTo(surfaceRect.center.dy, 0.5));
  expect(imageRect.center.dy, closeTo(sendRect.center.dy, 0.5));
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

bool _composerHasFocus(WidgetTester tester) {
  return tester
      .widget<EditableText>(find.byType(EditableText))
      .focusNode
      .hasFocus;
}

AgentConversationHistory _conversationHistory(AgentStreamRunState state) {
  final now = DateTime.utc(2026, 8, 10);
  return AgentConversationHistory(
    thread: AgentConversationSummary(
      id: state.threadId!,
      title: '头颈姿态评估',
      status: 'active',
      createdAt: now,
      updatedAt: now,
    ),
    messages: const [],
    currentState: state,
  );
}

class _SequencedConversationRepository implements AgentConversationRepository {
  @override
  Future<AgentConversationHistory?> loadLatestConversation() async => null;

  _SequencedConversationRepository(this.histories);

  final List<AgentConversationHistory> histories;
  int loadCalls = 0;

  @override
  Future<AgentConversationHistory> loadConversation(
    String threadId, {
    int? beforeSequence,
    int limit = 20,
  }) async {
    final index = loadCalls.clamp(0, histories.length - 1);
    loadCalls += 1;
    return histories[index];
  }
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
  int writeCount = 0;
  int clearCount = 0;

  @override
  Future<AgentHubInteractionSnapshot?> read() async => snapshot;

  @override
  Future<void> write(AgentHubInteractionSnapshot snapshot) async {
    writeCount += 1;
    this.snapshot = snapshot;
  }

  @override
  Future<void> clear() async {
    clearCount += 1;
    snapshot = null;
  }
}

class _DeferredAgentHubInteractionStateStore
    implements AgentHubInteractionStateStore {
  final Completer<AgentHubInteractionSnapshot?> _read = Completer();
  int writeCount = 0;
  int clearCount = 0;

  @override
  Future<AgentHubInteractionSnapshot?> read() => _read.future;

  void completeRead(AgentHubInteractionSnapshot? snapshot) {
    if (!_read.isCompleted) _read.complete(snapshot);
  }

  @override
  Future<void> write(AgentHubInteractionSnapshot snapshot) async {
    writeCount += 1;
  }

  @override
  Future<void> clear() async {
    clearCount += 1;
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
      'type': 'message.delta',
      'thread_id': 'thread-demo',
      'run_id': 'run-first',
      'message_id': 'msg-first',
      'sequence': 3,
      'payload': {'text': ' completed.'},
    });
    yield AgentStreamEvent(const {
      'event_id': 'evt-retry-4',
      'type': 'message.completed',
      'thread_id': 'thread-demo',
      'run_id': 'run-first',
      'message_id': 'msg-first',
      'sequence': 4,
      'payload': {'text': 'Partial answer completed.'},
    });
    yield AgentStreamEvent(const {
      'event_id': 'evt-retry-5',
      'type': 'run.completed',
      'thread_id': 'thread-demo',
      'run_id': 'run-first',
      'message_id': 'msg-first',
      'sequence': 5,
    });
  }
}

class _RetryBeforeRunCreatedAgentStreamClient implements AgentStreamClient {
  final requests = <AgentStreamRequest>[];

  @override
  Stream<AgentStreamEvent> stream(AgentStreamRequest request) async* {
    requests.add(request);
    await Future<void>.delayed(Duration.zero);

    if (requests.length == 1) {
      throw TimeoutException('run create timeout');
    }

    yield AgentStreamEvent(const {
      'event_id': 'evt-run-created-1',
      'type': 'run.queued',
      'thread_id': 'thread-created',
      'run_id': 'run-created',
      'sequence': 1,
      'payload': {'label': 'I have your message.'},
    });
    yield AgentStreamEvent(const {
      'event_id': 'evt-run-created-2',
      'type': 'message.completed',
      'thread_id': 'thread-created',
      'run_id': 'run-created',
      'message_id': 'msg-created',
      'sequence': 2,
      'payload': {
        'role': 'assistant',
        'text': 'Your lactation support form is open.',
      },
    });
    yield AgentStreamEvent(const {
      'event_id': 'evt-run-created-3',
      'type': 'run.completed',
      'thread_id': 'thread-created',
      'run_id': 'run-created',
      'sequence': 3,
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
  _RecordingCancelConnector({
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
    Duration? timeout,
  }) async {
    this.uri = uri;
    this.headers = headers;
    this.body = body;
    if (!called.isCompleted) called.complete();
    return response;
  }
}

class _DeferredCancelConnector implements AgentStreamControlHttpConnector {
  final called = Completer<void>();
  final _response = Completer<AgentStreamControlHttpResponse>();

  void complete() {
    if (_response.isCompleted) return;
    _response.complete(
      const AgentStreamControlHttpResponse(statusCode: 200, body: '{}'),
    );
  }

  @override
  Future<AgentStreamControlHttpResponse> post(
    Uri uri, {
    required Map<String, String> headers,
    required String body,
    Duration? timeout,
  }) {
    if (!called.isCompleted) called.complete();
    return _response.future;
  }
}

class _FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  var _nextPlayerId = 1;
  final createdAssets = <String>[];
  final playedIds = <int>[];
  final pausedIds = <int>[];
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
    pausedIds.add(playerId);
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

class _FakeAgentImageMediaRepository implements MediaRepository {
  _FakeAgentImageMediaRepository({this.deleteFailure, this.deleteGate});

  Object? deleteFailure;
  Completer<void>? deleteGate;
  final uploadedFiles = <ApiUploadFile>[];
  final deletedFileIds = <String>[];
  final deleteKeys = <String?>[];

  @override
  Future<UploadedMediaFile> uploadFile({
    required ApiUploadFile file,
    String? idempotencyKey,
  }) async {
    uploadedFiles.add(file);
    return const UploadedMediaFile(
      id: '0ea4b76d-2bc4-4ab8-91b7-3b24df53c518',
      name: 'pump-display.png',
      sizeBytes: 68,
      extension: 'png',
      mimeType: 'image/png',
    );
  }

  @override
  Future<void> deleteFile({
    required String fileId,
    String? idempotencyKey,
  }) async {
    deletedFileIds.add(fileId);
    deleteKeys.add(idempotencyKey);
    await deleteGate?.future;
    final failure = deleteFailure;
    if (failure != null) throw failure;
  }
}
