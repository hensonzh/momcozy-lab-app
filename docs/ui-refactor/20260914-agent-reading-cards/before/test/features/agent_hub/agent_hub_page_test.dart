import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
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
import 'package:momcozy_flutter_app/features/agent_hub/data/support_ticket_api_repository.dart';
import 'package:momcozy_flutter_app/features/agent_hub/data/voice_playback.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_conversation.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_document_input.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_hub_greeting.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_image_input.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_voice.dart';
import 'package:momcozy_flutter_app/features/agent_hub/presentation/agent_file_previews.dart';
import 'package:momcozy_flutter_app/features/agent_hub/presentation/agent_image_previews.dart';
import 'package:momcozy_flutter_app/features/media/domain/media_upload.dart';
import 'package:momcozy_flutter_app/features/media/presentation/product_asset_image.dart';
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

  testWidgets('Agent Hub renders idle composer state', (tester) async {
    await tester.pumpWidget(_host(const AgentHubPage()));

    expect(find.byKey(const ValueKey('agent-hub-page')), findsOneWidget);
    expect(find.textContaining('嗨，我是 Cozymate'), findsOneWidget);
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
    expect(
      find.byKey(const ValueKey('agent-attachment-button')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('agent-voice-button')), findsNothing);
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
      find.byKey(const ValueKey('agent-attachment-button')),
    );
    expect(imageButton.onPressed, isNull);
    final sendButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('agent-send-button')),
    );
    expect(sendButton.onPressed, isNull);
    _expectComposerControlsInsideSurface(tester);
    _expectComposerControlsVerticallyCentered(tester);
    _expectComposerInputVerticallyCentered(tester);
    _expectComposerSendButtonBreathesVertically(tester);
  });

  testWidgets('Cozymate keeps the idle conversation free of service menus', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const AgentHubPage()));

    expect(find.text('Cozymate'), findsOneWidget);
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

  testWidgets(
    'design shortcuts send through the existing conversation runner',
    (tester) async {
      final client = _ControllableAgentStreamClient();
      addTearDown(client.dispose);
      await tester.pumpWidget(
        _host(AgentHubPage(runner: AgentStreamRunner(client))),
      );
      await tester.tap(find.text('奶量分析'));
      await tester.pump();
      expect(client.requests.single.message, '帮我分析最近的奶量记录，告诉我可以先关注哪些变化。');
      expect(find.text(client.requests.single.message), findsOneWidget);
      final recovery = tester.widget<OutlinedButton>(
        find.ancestor(
          of: find.text('产后康复评估'),
          matching: find.byType(OutlinedButton),
        ),
      );
      expect(recovery.onPressed, isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('schedule actions expose authoritative preview details', (
    tester,
  ) async {
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
                    'after': '删除',
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

    expect(find.text('日程删除'), findsOneWidget);
    expect(find.text('对象：吸奶任务'), findsOneWidget);
    expect(find.text('原值：2026-08-07 14:00'), findsOneWidget);
    expect(find.text('变更后：删除'), findsOneWidget);
    expect(find.text('日期：2026-08-07'), findsOneWidget);
    expect(find.text('时区：Asia/Shanghai'), findsOneWidget);
    expect(find.text('影响范围：仅此任务'), findsOneWidget);
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
    final greetingRect = tester.getRect(find.textContaining('嗨，我是 Cozymate'));

    expect(greetingRect.top - chatRect.top, lessThan(120));
  });

  testWidgets('Agent Hub keeps a newly arrived form entry in the viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final client = _ControllableAgentStreamClient();
    addTearDown(client.dispose);
    final history = List<AgentHubHistoryMessage>.generate(
      12,
      (index) => AgentHubHistoryMessage(
        role: index.isEven
            ? AgentHubHistoryRole.user
            : AgentHubHistoryRole.assistant,
        content: '历史消息 $index：用于形成足够长的对话。',
      ),
    );

    await tester.pumpWidget(
      _host(
        AgentHubPage(
          runner: AgentStreamRunner(client),
          historyMessages: history,
        ),
        tickersEnabled: true,
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('agent-composer-input')),
      '帮我整理泌乳支持信息',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('agent-send-button')));
    await tester.pump();

    client.emit(
      0,
      AgentStreamEvent({
        'event_id': 'artifact-focus-event',
        'type': 'artifact.created',
        'thread_id': 'thread-artifact-focus',
        'run_id': 'run-artifact-focus',
        'artifact_id': 'artifact-focus-form',
        'sequence': 1,
        'payload': {
          'artifact_type': 'form',
          'schema_version': '1.0',
          'form': {
            'id': 'lactation_support_intake',
            'title': '信息采集',
            'fields': [
              for (var index = 0; index < 6; index++)
                {
                  'id': 'field_$index',
                  'label': '基本信息｜字段 ${index + 1}',
                  'type': 'text',
                  'required': true,
                },
            ],
          },
        },
      }),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const ValueKey('agent-artifact-panel')), findsNothing);

    client.emit(
      0,
      AgentStreamEvent(const {
        'event_id': 'artifact-focus-text-event',
        'type': 'message.delta',
        'thread_id': 'thread-artifact-focus',
        'run_id': 'run-artifact-focus',
        'message_id': 'message-artifact-focus',
        'sequence': 2,
        'payload': {'text': '我先说明一下，再请你补充这些信息。'},
      }),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    client.emit(
      0,
      AgentStreamEvent(const {
        'event_id': 'artifact-focus-completed-event',
        'type': 'message.completed',
        'thread_id': 'thread-artifact-focus',
        'run_id': 'run-artifact-focus',
        'message_id': 'message-artifact-focus',
        'sequence': 3,
        'payload': {'role': 'assistant', 'content': '我先说明一下，再请你补充这些信息。'},
      }),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final chatRect = tester.getRect(
      find.byKey(const ValueKey('agent-chat-scroll-view')),
    );
    final artifactRect = tester.getRect(
      find.byKey(const ValueKey('agent-artifact-panel')),
    );
    expect(artifactRect.top, greaterThan(chatRect.top));
    expect(artifactRect.bottom, lessThanOrEqualTo(chatRect.bottom));
  });

  testWidgets('Agent Hub publishes a pure artifact on assistant completion', (
    tester,
  ) async {
    final artifactEvent = AgentStreamEvent(
      readFixtureMap('agent_events/rich_text_artifact.json'),
    );

    await tester.pumpWidget(
      _host(
        AgentHubPage(
          state: AgentStreamRunState(
            phase: AgentStreamRunPhase.streaming,
            artifactEvents: {'care-note-001': artifactEvent},
            completedAssistantMessageReceived: true,
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('agent-artifact-panel')), findsOneWidget);
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

  testWidgets('Agent Hub keeps a textless failed artifact unpublished', (
    tester,
  ) async {
    final artifactEvent = AgentStreamEvent(
      readFixtureMap('agent_events/rich_text_artifact.json'),
    );

    await tester.pumpWidget(
      _host(
        AgentHubPage(
          state: AgentStreamRunState(
            phase: AgentStreamRunPhase.error,
            artifactEvents: {'care-note-001': artifactEvent},
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('agent-artifact-panel')), findsNothing);
  });

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

    expect(find.text('这次没有拿到回复。'), findsOneWidget);
    expect(find.text('服务执行失败，请稍后重试'), findsOneWidget);
    expect(find.textContaining('连接中断'), findsNothing);
  });

  testWidgets('Agent Hub keeps terminal failure and cancel replies text-only', (
    tester,
  ) async {
    for (final phase in <AgentStreamRunPhase>[
      AgentStreamRunPhase.error,
      AgentStreamRunPhase.cancelled,
    ]) {
      await tester.pumpWidget(
        _host(
          AgentRunTranscript(
            state: AgentStreamRunState(
              phase: phase,
              quickReplies: const ['快捷一', '快捷二', '快捷三'],
            ),
            canRetry: true,
            onRetry: () {},
            actionCards: const [
              AgentActionCardView(
                id: 'terminal-action',
                title: '不应展示的操作',
                status: 'confirmation_required',
              ),
            ],
            onConfirmAction: (_) {},
            onRejectAction: (_) {},
            onQuickReplySelected: (_) {},
          ),
        ),
      );

      expect(find.byKey(const ValueKey('agent-retry-button')), findsNothing);
      expect(find.byKey(const ValueKey('agent-quick-replies')), findsNothing);
      expect(find.text('不应展示的操作'), findsNothing);
    }
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

  testWidgets('Agent Hub caches thinking and speaking avatar videos', (
    tester,
  ) async {
    const state = AgentStreamRunState(
      phase: AgentStreamRunPhase.streaming,
      messageId: 'msg-mode-reuse',
      textContent: 'Switch avatar mode.',
    );

    await tester.pumpWidget(
      _host(const AgentRunTranscript(state: state), tickersEnabled: true),
    );
    await tester.pump();
    await tester.pump();
    expect(
      find.byKey(const ValueKey('agent-assistant-avatar-thinking-media')),
      findsOneWidget,
    );

    await tester.pumpWidget(
      _host(
        const AgentRunTranscript(
          state: state,
          activeVoicePlaybackId: 'msg-mode-reuse',
        ),
        tickersEnabled: true,
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(
      find.byKey(const ValueKey('agent-assistant-avatar-speaking-media')),
      findsOneWidget,
    );

    await tester.pumpWidget(
      _host(const AgentRunTranscript(state: state), tickersEnabled: true),
    );
    await tester.pump();

    expect(videoPlayerPlatform.createdAssets, [
      MomCozyAssets.agentThinkingAvatar,
      MomCozyAssets.agentSpeakingAvatar,
    ]);
    expect(videoPlayerPlatform.disposedIds, isEmpty);
  });

  testWidgets('Agent Hub restores history and starts a new local session', (
    tester,
  ) async {
    final mediaRepository = _FakeAgentImageMediaRepository();

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
          mediaRepository: mediaRepository,
          pickImage: (_) async => const AgentStreamImageInput(
            dataUrl:
                'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=',
            mimeType: 'image/png',
            name: 'staged-before-new-session.png',
          ),
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
    await tester.tap(find.byKey(const ValueKey('agent-attachment-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('agent-attachment-menu')), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('agent-attachment-photo-button')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('agent-image-attachment-chip')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('agent-new-session-button')));
    await tester.pump();

    expect(find.byKey(const ValueKey('agent-history-panel')), findsNothing);
    expect(find.textContaining('嗨，我是 Cozymate'), findsOneWidget);
    expect(find.byKey(const ValueKey('agent-attachment-menu')), findsNothing);
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
    expect(mediaRepository.deletedFileIds, [
      '0ea4b76d-2bc4-4ab8-91b7-3b24df53c518',
    ]);
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

  testWidgets('Agent Hub keeps links clickable in restored plain history', (
    tester,
  ) async {
    final actions = <AgentArtifactActionView>[];
    await tester.pumpWidget(
      _host(
        AgentHubPage(
          historyMessages: const [
            AgentHubHistoryMessage(
              role: AgentHubHistoryRole.assistant,
              content: '[查看专业资料](https://example.com/reference)',
            ),
          ],
          onArtifactAction: actions.add,
        ),
      ),
    );

    await tester.tap(find.text('查看专业资料', findRichText: true));
    await tester.pump();

    expect(
      actions.single.externalUri,
      Uri.parse('https://example.com/reference'),
    );
  });

  testWidgets('Agent Hub plays greeting voice on first open', (tester) async {
    final coordinator = AgentVoicePlaybackCoordinator();
    final player = _PageFakeVoicePlaybackPlayer();

    await tester.pumpWidget(
      _host(
        AgentHubPage(
          voicePlaybackCoordinator: coordinator,
          voicePlaybackPlayer: player,
        ),
      ),
    );
    await tester.pump();

    expect(coordinator.activeSource, AgentVoicePlaybackSource.greeting);
    expect(coordinator.activeId, 'agent-default-greeting');
    expect(player.playedTexts, isNotEmpty);
    expect(
      find.byKey(const ValueKey('agent-assistant-avatar-speaking')),
      findsOneWidget,
    );
  });

  testWidgets(
    'Agent Hub waits for cold-start restore before showing or playing greeting',
    (tester) async {
      final store = _DeferredAgentHubInteractionStateStore();
      final player = _PageFakeVoicePlaybackPlayer();

      await tester.pumpWidget(
        _host(
          AgentHubPage(
            interactionStateStore: store,
            voicePlaybackCoordinator: AgentVoicePlaybackCoordinator(),
            voicePlaybackPlayer: player,
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('嗨，我是 Cozymate'), findsNothing);
      expect(player.playedTexts, isEmpty);

      store.completeRead(
        const AgentHubInteractionSnapshot(
          runState: AgentStreamRunState(
            phase: AgentStreamRunPhase.finished,
            threadId: 'thread-cold-restore',
            textContent: '这是上一次的回复。',
          ),
          historyMessages: [
            AgentHubHistorySnapshot(role: 'user', content: '上一次的问题'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('上一次的问题'), findsOneWidget);
      expect(find.text('这是上一次的回复。', findRichText: true), findsOneWidget);
      expect(find.textContaining('嗨，我是 Cozymate'), findsNothing);
      expect(player.playedTexts, isEmpty);
    },
  );

  testWidgets(
    'Agent Hub ignores persisted local state without conversation history',
    (tester) async {
      final player = _PageFakeVoicePlaybackPlayer();
      final store = _MemoryAgentHubInteractionStateStore(
        const AgentHubInteractionSnapshot(
          composerText: '不应恢复的草稿',
          autoVoiceEnabled: false,
          activeRequest: AgentStreamRequest(message: '不应恢复的请求'),
        ),
      );

      await tester.pumpWidget(
        _host(
          AgentHubPage(
            interactionStateStore: store,
            voicePlaybackCoordinator: AgentVoicePlaybackCoordinator(),
            voicePlaybackPlayer: player,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final composer = tester.widget<TextField>(
        find.byKey(const ValueKey('agent-composer-input')),
      );
      expect(composer.controller?.text, isEmpty);
      expect(find.textContaining('嗨，我是 Cozymate'), findsOneWidget);
      expect(player.playedTexts, hasLength(1));
      expect(player.playedTexts.single, contains('嗨，我是 Cozymate'));
    },
  );

  testWidgets('Agent Hub hides a persisted motion assessment system trigger', (
    tester,
  ) async {
    final store = _MemoryAgentHubInteractionStateStore(
      const AgentHubInteractionSnapshot(
        runState: AgentStreamRunState(
          phase: AgentStreamRunPhase.finished,
          threadId: 'thread-motion-feedback',
          textContent: '你的头颈姿态评估反馈已经生成。',
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
    expect(find.text('你的头颈姿态评估反馈已经生成。', findRichText: true), findsOneWidget);
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

  testWidgets(
    'Agent Hub restores an interrupted durable run without restarting it',
    (tester) async {
      final client = _ControllableAgentStreamClient();
      final player = _PageFakeVoicePlaybackPlayer();
      final store = _MemoryAgentHubInteractionStateStore(
        const AgentHubInteractionSnapshot(
          runState: AgentStreamRunState(
            phase: AgentStreamRunPhase.streaming,
            threadId: 'thread-interrupted',
            runId: 'run-interrupted',
            textContent: '上一轮尚未完成的回复',
          ),
          activeRequest: AgentStreamRequest(message: '继续生成建议'),
        ),
      );
      addTearDown(client.dispose);

      await tester.pumpWidget(
        _host(
          AgentHubPage(
            runner: AgentStreamRunner(client),
            interactionStateStore: store,
            voicePlaybackCoordinator: AgentVoicePlaybackCoordinator(),
            voicePlaybackPlayer: player,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(client.requests, isEmpty);
      expect(find.text('上一轮尚未完成的回复'), findsOneWidget);
      expect(find.text('连接暂时中断，可重试'), findsOneWidget);
      expect(find.byKey(const ValueKey('agent-stop-button')), findsNothing);
      expect(find.byKey(const ValueKey('agent-retry-button')), findsOneWidget);
      expect(player.playedTexts, isEmpty);
    },
  );

  testWidgets('Agent Hub falls back to a fresh greeting when restore fails', (
    tester,
  ) async {
    final player = _PageFakeVoicePlaybackPlayer();

    await tester.pumpWidget(
      _host(
        AgentHubPage(
          interactionStateStore: _ThrowingAgentHubInteractionStateStore(),
          voicePlaybackCoordinator: AgentVoicePlaybackCoordinator(),
          voicePlaybackPlayer: player,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('嗨，我是 Cozymate'), findsOneWidget);
    expect(player.playedTexts, hasLength(1));
  });

  testWidgets('Agent Hub personalizes greeting text and voice from profile', (
    tester,
  ) async {
    final coordinator = AgentVoicePlaybackCoordinator();
    final player = _PageFakeVoicePlaybackPlayer();

    await tester.pumpWidget(
      _host(
        AgentHubPage(
          greetingProfileLoader: () async =>
              const AgentHubGreetingProfile(displayName: '小美', age: 29),
          voicePlaybackCoordinator: coordinator,
          voicePlaybackPlayer: player,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('嗨 小美'), findsOneWidget);
    expect(find.textContaining('你希望我怎么称呼你？'), findsNothing);
    expect(player.playedTexts, hasLength(1));
    expect(player.playedTexts.single, contains('嗨 小美'));

    player.complete();
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
    expect(find.textContaining('嗨，我是 Cozymate'), findsOneWidget);
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

  testWidgets(
    'Agent Hub clears durable history immediately for a new session',
    (tester) async {
      final store = _MemoryAgentHubInteractionStateStore(
        const AgentHubInteractionSnapshot(
          runState: AgentStreamRunState(
            phase: AgentStreamRunPhase.finished,
            threadId: 'thread-to-clear',
            textContent: '旧会话回复',
          ),
          historyMessages: [
            AgentHubHistorySnapshot(role: 'user', content: '旧会话问题'),
          ],
        ),
      );

      await tester.pumpWidget(
        _host(AgentHubPage(interactionStateStore: store)),
      );
      await tester.pumpAndSettle();
      store
        ..writeCount = 0
        ..clearCount = 0;

      await tester.tap(find.byKey(const ValueKey('agent-new-session-button')));
      await tester.pump();

      expect(store.clearCount, 1);
      expect(store.writeCount, 0);
      expect(store.snapshot, isNull);
      expect(find.textContaining('嗨，我是 Cozymate'), findsOneWidget);
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

  testWidgets('Agent Hub refreshes the profile for a manual new session', (
    tester,
  ) async {
    final coordinator = AgentVoicePlaybackCoordinator();
    final player = _PageFakeVoicePlaybackPlayer();
    var displayName = '小美';
    var loadCount = 0;

    await tester.pumpWidget(
      _host(
        AgentHubPage(
          greetingProfileLoader: () async {
            loadCount += 1;
            return AgentHubGreetingProfile(displayName: displayName, age: 29);
          },
          voicePlaybackCoordinator: coordinator,
          voicePlaybackPlayer: player,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('嗨 小美'), findsOneWidget);
    player.complete();
    await tester.pump();
    await tester.pump();

    displayName = '安安';
    await tester.tap(find.byKey(const ValueKey('agent-new-session-button')));
    await tester.pump();
    await tester.pump();

    expect(loadCount, 2);
    expect(find.textContaining('嗨 安安'), findsOneWidget);
    expect(find.textContaining('嗨 小美'), findsNothing);
    expect(player.playedTexts.last, contains('嗨 安安'));

    player.complete();
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
    expect(find.textContaining('嗨，我是 Cozymate'), findsOneWidget);
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
    expect(find.textContaining('嗨，我是 Cozymate'), findsOneWidget);
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
          replies: const ['继续聊这个', '给我更多细节', '换个方向'],
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
    expect(find.text('猜你想说'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsNWidgets(3));
    expect(find.byType(InkWell), findsNWidgets(3));

    await tester.tap(find.byKey(const ValueKey('agent-quick-reply-1')));
    await tester.pump();

    expect(selected, ['给我更多细节']);
  });

  testWidgets(
    'Agent quick replies render only for legacy three item payloads',
    (tester) async {
      await tester.pumpWidget(
        _host(
          AgentQuickRepliesBar(
            replies: const ['继续聊这个', '给我更多细节'],
            onSelected: (_) {},
          ),
        ),
      );

      expect(find.byKey(const ValueKey('agent-quick-replies')), findsNothing);
      expect(find.text('猜你想说'), findsNothing);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    },
  );

  testWidgets('Agent Hub suppresses quick replies while a form is actionable', (
    tester,
  ) async {
    final formEvent = AgentStreamEvent({
      'type': 'artifact.created',
      'artifact_id': 'quick-reply-form',
      'payload': {
        'artifact_type': 'form',
        'schema_version': '1.0',
        'form': {
          'id': 'lactation_support_intake',
          'title': '信息采集',
          'fields': [
            {'id': 'feeding_context', 'label': '基本信息｜泌乳目标', 'type': 'text'},
          ],
        },
      },
    });

    await tester.pumpWidget(
      _host(
        AgentRunTranscript(
          state: AgentStreamRunState(
            phase: AgentStreamRunPhase.finished,
            textContent: '请先补充信息。',
            quickReplies: const ['快捷一', '快捷二', '快捷三'],
            events: [formEvent],
          ),
          onArtifactAction: (_) {},
          onQuickReplySelected: (_) {},
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('agent-artifact-form-entry-quick-reply-form')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('agent-quick-replies')), findsNothing);
    expect(find.text('快捷一'), findsNothing);
  });

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
          'text': '我整理好了。',
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
    expect(find.byKey(const ValueKey('agent-quick-replies')), findsNothing);
    expect(find.byKey(const ValueKey('agent-quick-reply-0')), findsNothing);
    expect(find.text('猜你想说'), findsNothing);
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
      expect(find.textContaining('嗨，我是 Cozymate'), findsOneWidget);
      expect(find.textContaining('这次没有拿到回复'), findsOneWidget);
      expect(find.text('网络不可用，请检查连接后重试'), findsOneWidget);

      final chatRect = tester.getRect(
        find.byKey(const ValueKey('agent-chat-scroll-view')),
      );
      final greetingRect = tester.getRect(find.textContaining('嗨，我是 Cozymate'));
      final userRect = tester.getRect(sentText);
      final errorRect = tester.getRect(find.textContaining('这次没有拿到回复'));
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
    expect(find.text('相机'), findsOneWidget);
    expect(find.text('照片'), findsOneWidget);
    expect(find.text('文件'), findsOneWidget);
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

  testWidgets('Agent Hub locks draft actions while an attachment is pending', (
    tester,
  ) async {
    final pickCompleter = Completer<AgentStreamImageInput?>();
    final client = _FixtureAgentStreamClient(const <AgentStreamEvent>[]);

    await tester.pumpWidget(
      _host(
        AgentHubPage(
          runner: AgentStreamRunner(client),
          pickImage: (_) => pickCompleter.future,
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('agent-composer-input')),
      '保留这条草稿',
    );
    await tester.tap(find.byKey(const ValueKey('agent-attachment-button')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('agent-attachment-photo-button')),
    );
    await tester.pump();
    await tester.pump();

    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('agent-send-button')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const ValueKey('agent-new-session-button')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('agent-composer-input')))
          .enabled,
      isFalse,
    );
    expect(client.requests, isEmpty);

    pickCompleter.complete(
      const AgentStreamImageInput(
        dataUrl: 'data:image/png;base64,fixture',
        mimeType: 'image/png',
        name: 'pending-image.png',
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('agent-composer-input')))
          .controller
          ?.text,
      '保留这条草稿',
    );
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

    expect(client.requests.single.message, '请查看这个文件');
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
    'Agent Hub deletes draft attachments before a synthetic form request',
    (tester) async {
      final client = _ControllableAgentStreamClient();
      addTearDown(client.dispose);
      final mediaRepository = _FakeAgentImageMediaRepository();
      final formEvent = AgentStreamEvent(const {
        'type': 'artifact.created',
        'artifact_id': 'attachment-cleanup-form',
        'payload': {
          'artifact_type': 'form',
          'form': {
            'id': 'lactation_support_intake',
            'title': '信息采集',
            'fields': [
              {
                'id': 'feeding_context',
                'label': '泌乳目标',
                'type': 'text',
                'required': true,
                'default_value': '建立规律记录',
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
              textContent: '请补充信息。',
              events: [formEvent],
            ),
            mediaRepository: mediaRepository,
            pickImage: (_) async => const AgentStreamImageInput(
              dataUrl:
                  'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=',
              mimeType: 'image/png',
              name: 'discard-before-form.png',
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
      await tester.tap(
        find.byKey(
          const ValueKey('agent-artifact-form-entry-attachment-cleanup-form'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey('agent-artifact-form-submit-attachment-cleanup-form'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(mediaRepository.deletedFileIds, [
        '0ea4b76d-2bc4-4ab8-91b7-3b24df53c518',
      ]);
      expect(client.requests, hasLength(1));
      expect(client.requests.single.images, isEmpty);
      expect(client.requests.single.files, isEmpty);
      expect(
        find.byKey(const ValueKey('agent-image-attachment-chip')),
        findsNothing,
      );
    },
  );

  testWidgets('Agent Hub deletes draft attachments before a new session', (
    tester,
  ) async {
    final mediaRepository = _FakeAgentImageMediaRepository();
    await tester.pumpWidget(
      _host(
        AgentHubPage(
          mediaRepository: mediaRepository,
          pickImage: (_) async => const AgentStreamImageInput(
            dataUrl:
                'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=',
            mimeType: 'image/png',
            name: 'discard-before-new-session.png',
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
    await tester.tap(find.byKey(const ValueKey('agent-new-session-button')));
    await tester.pumpAndSettle();

    expect(mediaRepository.deletedFileIds, [
      '0ea4b76d-2bc4-4ab8-91b7-3b24df53c518',
    ]);
    expect(
      find.byKey(const ValueKey('agent-image-attachment-chip')),
      findsNothing,
    );
  });

  testWidgets(
    'Agent Hub never retains a draft reference after deletion succeeds',
    (tester) async {
      final mediaRepository = _FakeAgentImageMediaRepository();
      await tester.pumpWidget(
        _host(
          AgentHubPage(
            mediaRepository: mediaRepository,
            pickImage: (_) async => const AgentStreamImageInput(
              dataUrl:
                  'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=',
              mimeType: 'image/png',
              name: 'deleted-before-session-failure.png',
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
      await tester.tap(find.byKey(const ValueKey('agent-new-session-button')));
      await tester.pumpAndSettle();

      expect(mediaRepository.deletedFileIds, [
        '0ea4b76d-2bc4-4ab8-91b7-3b24df53c518',
      ]);
      expect(
        find.byKey(const ValueKey('agent-image-attachment-chip')),
        findsNothing,
      );
    },
  );

  testWidgets('Agent Hub preserves a draft when attachment deletion fails', (
    tester,
  ) async {
    final mediaRepository = _FakeAgentImageMediaRepository(
      deleteFailure: StateError('delete unavailable'),
    );
    await tester.pumpWidget(
      _host(
        AgentHubPage(
          mediaRepository: mediaRepository,
          pickImage: (_) async => const AgentStreamImageInput(
            dataUrl:
                'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=',
            mimeType: 'image/png',
            name: 'preserve-on-delete-failure.png',
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
    await tester.tap(find.byKey(const ValueKey('agent-new-session-button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('agent-image-attachment-chip')),
      findsOneWidget,
    );
    expect(find.text('附件清理失败，已保留草稿，请重试。'), findsOneWidget);
  });

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
    expect(find.text('连接暂时中断，可重试'), findsOneWidget);
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

    expect(client.requests.single.message, '请看这张图片');
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
        textContent: '我们开始评估吧。',
      );
      const feedbackState = AgentStreamRunState(
        phase: AgentStreamRunPhase.finished,
        threadId: 'thread-source',
        runId: 'run-feedback',
        textContent: '这次头颈姿态整体稳定，建议每天做一次轻柔放松。',
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
        textContent: '我们开始评估吧。',
      );
      const feedbackState = AgentStreamRunState(
        phase: AgentStreamRunPhase.finished,
        threadId: 'thread-source',
        runId: 'run-feedback',
        textContent: '评估反馈已经生成。',
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

  testWidgets('Agent Hub appends generated reply chunks to realtime voice', (
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

    expect(player.realtimeSessions, hasLength(1));
    final session = player.realtimeSessions.single;
    expect(session.appendedTexts, [
      'I can help',
      " you review today's pumping pattern.",
    ]);
    expect(session.finishCount, 1);
    expect(coordinator.activeSource, AgentVoicePlaybackSource.autoReply);

    session.complete();
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

    expect(player.realtimeSessions, hasLength(1));
    expect(player.realtimeSessions.single.appendedTexts, ['Draft answer']);
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

    expect(player.realtimeSessions, hasLength(1));
    expect(player.realtimeSessions.single.appendedTexts, [
      'Draft answer',
      ' ready.',
    ]);
    expect(player.realtimeSessions.single.finishCount, 1);
    expect(coordinator.activeSource, AgentVoicePlaybackSource.autoReply);
    expect(
      find.text('Draft answer ready.', findRichText: true),
      findsOneWidget,
    );

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

    expect(player.realtimeSessions.single.appendedTexts, [
      'Draft answer',
      ' ready.',
    ]);
    expect(player.realtimeSessions.single.finishCount, 1);
    expect(coordinator.activeSource, AgentVoicePlaybackSource.autoReply);
    expect(coordinator.activeId, 'msg-voice-order');
  });

  testWidgets('Agent Hub forwards media voice metadata to realtime playback', (
    tester,
  ) async {
    final client = _ControllableAgentStreamClient();
    final player = _PageFakeVoicePlaybackPlayer();
    addTearDown(client.dispose);

    await tester.pumpWidget(
      _host(
        AgentHubPage(
          runner: AgentStreamRunner(client),
          voicePlaybackCoordinator: AgentVoicePlaybackCoordinator(),
          voicePlaybackPlayer: player,
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('agent-composer-input')),
      '怎么安装阀门',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('agent-send-button')));
    await tester.pump();

    client.emit(
      0,
      AgentStreamEvent(const {
        'event_id': 'evt-media-voice-tool',
        'type': 'tool.completed',
        'thread_id': 'thread-media-voice',
        'run_id': 'run-media-voice',
        'tool_call_id': 'tool-media-voice',
        'sequence': 1,
        'payload': {
          'output_summary': {
            'media_voice': [
              {
                'media_id': '/v1/assets/asset-image?kind=image',
                'voice_policy': 'announce',
                'spoken_label': '我放了一张阀门安装方向图。',
              },
            ],
          },
        },
      }),
    );
    client.emit(
      0,
      AgentStreamEvent(const {
        'event_id': 'evt-media-voice-text',
        'type': 'message.delta',
        'thread_id': 'thread-media-voice',
        'run_id': 'run-media-voice',
        'message_id': 'message-media-voice',
        'sequence': 2,
        'payload': {'text': '请看 ![阀门安装方向](/v1/assets/asset-image?kind=image)。'},
      }),
    );
    await tester.pump();
    await tester.pump();

    expect(player.realtimeSessions, hasLength(1));
    final resolver = player.realtimeSessions.single.mediaNarrationResolver;
    expect(resolver, isNotNull);
    expect(
      resolver!(url: '/v1/assets/asset-image?kind=image', alt: '阀门安装方向'),
      '我放了一张阀门安装方向图。',
    );
  });

  testWidgets(
    'Agent Hub appends standalone media narration after a textless reply',
    (tester) async {
      final client = _ControllableAgentStreamClient();
      final player = _PageFakeVoicePlaybackPlayer();
      addTearDown(client.dispose);

      await tester.pumpWidget(
        _host(
          AgentHubPage(
            runner: AgentStreamRunner(client),
            voicePlaybackCoordinator: AgentVoicePlaybackCoordinator(),
            voicePlaybackPlayer: player,
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('agent-composer-input')),
        '给我看安装示意图',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('agent-send-button')));
      await tester.pump();

      client.emit(
        0,
        AgentStreamEvent(const {
          'event_id': 'evt-standalone-media-voice',
          'type': 'tool.completed',
          'thread_id': 'thread-standalone-media-voice',
          'run_id': 'run-standalone-media-voice',
          'tool_call_id': 'tool-standalone-media-voice',
          'sequence': 1,
          'payload': {
            'output_summary': {
              'media_voice': [
                {
                  'media_id': '/v1/assets/instructional-image',
                  'voice_policy': 'announce',
                  'spoken_label': '我放了一张安装方向图，你可以对照检查。',
                },
                {
                  'media_id': '/v1/assets/decorative-image',
                  'voice_policy': 'silent',
                  'spoken_label': '这句不应该播报。',
                },
              ],
            },
          },
        }),
      );
      await tester.pump();

      expect(player.realtimeSessions, isEmpty);

      client.emit(
        0,
        AgentStreamEvent(const {
          'event_id': 'evt-standalone-media-message-completed',
          'type': 'message.completed',
          'thread_id': 'thread-standalone-media-voice',
          'run_id': 'run-standalone-media-voice',
          'message_id': 'message-standalone-media-voice',
          'sequence': 2,
          'payload': {'role': 'assistant', 'text': ''},
        }),
      );
      client.emit(
        0,
        AgentStreamEvent(const {
          'event_id': 'evt-standalone-media-voice-completed',
          'type': 'run.completed',
          'thread_id': 'thread-standalone-media-voice',
          'run_id': 'run-standalone-media-voice',
          'sequence': 3,
        }),
      );
      await tester.pump();
      await tester.pump();

      expect(player.realtimeSessions, hasLength(1));
      expect(player.realtimeSessions.single.appendedTexts, [
        '我放了一张安装方向图，你可以对照检查。',
      ]);
      expect(player.realtimeSessions.single.finishCount, 1);
    },
  );

  testWidgets(
    'Agent Hub does not replay media narration already resolved from a URL',
    (tester) async {
      final client = _ControllableAgentStreamClient();
      final player = _PageFakeVoicePlaybackPlayer();
      addTearDown(client.dispose);

      await tester.pumpWidget(
        _host(
          AgentHubPage(
            runner: AgentStreamRunner(client),
            voicePlaybackCoordinator: AgentVoicePlaybackCoordinator(),
            voicePlaybackPlayer: player,
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('agent-composer-input')),
        '怎么安装阀门',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('agent-send-button')));
      await tester.pump();

      client.emit(
        0,
        AgentStreamEvent(const {
          'event_id': 'evt-deduped-media-voice-tool',
          'type': 'tool.completed',
          'thread_id': 'thread-deduped-media-voice',
          'run_id': 'run-deduped-media-voice',
          'tool_call_id': 'tool-deduped-media-voice',
          'sequence': 1,
          'payload': {
            'output_summary': {
              'media_voice': [
                {
                  'media_id': '/v1/assets/valve-image',
                  'voice_policy': 'announce',
                  'spoken_label': '我放了一张阀门安装方向图。',
                },
              ],
            },
          },
        }),
      );
      client.emit(
        0,
        AgentStreamEvent(const {
          'event_id': 'evt-deduped-media-voice-delta',
          'type': 'message.delta',
          'thread_id': 'thread-deduped-media-voice',
          'run_id': 'run-deduped-media-voice',
          'message_id': 'message-deduped-media-voice',
          'sequence': 2,
          'payload': {'text': '请看 /v1/assets/valve-image'},
        }),
      );
      await tester.pump();
      await tester.pump();

      final session = player.realtimeSessions.single;
      final resolver = session.mediaNarrationResolver!;

      client.emit(
        0,
        AgentStreamEvent(const {
          'event_id': 'evt-deduped-media-voice-completed',
          'type': 'message.completed',
          'thread_id': 'thread-deduped-media-voice',
          'run_id': 'run-deduped-media-voice',
          'message_id': 'message-deduped-media-voice',
          'sequence': 3,
          'payload': {'text': '请看 /v1/assets/valve-image'},
        }),
      );
      await tester.pump();
      await tester.pump();

      expect(session.appendedTexts, ['请看 /v1/assets/valve-image']);
      expect(session.flushCount, 1);
      expect(
        RegExp('我放了一张阀门安装方向图。').allMatches(session.filteredTexts.join(' ')),
        hasLength(1),
      );

      final filter = AgentVoiceTextStreamFilter(
        mediaNarrationResolver: resolver,
      );
      final firstFiltered = filter.push('请看 [阀门安装方向](/v1/assets/valve-image)。');
      final repeatedFiltered = filter.push(
        '再看 [阀门安装方向](/v1/assets/valve-image)。',
      );
      expect(firstFiltered, contains('我放了一张阀门安装方向图。'));
      expect(repeatedFiltered, isNot(contains('阀门安装方向')));
      expect(
        resolver(url: '/v1/assets/valve-image', alt: '阀门安装方向'),
        '我放了一张阀门安装方向图。',
      );
      expect(session.finishCount, 1);
    },
  );

  testWidgets(
    'Agent Hub speaks safe pure artifact copy without artifact actions',
    (tester) async {
      final client = _ControllableAgentStreamClient();
      final player = _PageFakeVoicePlaybackPlayer();
      addTearDown(client.dispose);

      await tester.pumpWidget(
        _host(
          AgentHubPage(
            runner: AgentStreamRunner(client),
            voicePlaybackCoordinator: AgentVoicePlaybackCoordinator(),
            voicePlaybackPlayer: player,
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('agent-composer-input')),
        '帮我整理泌乳支持信息',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('agent-send-button')));
      await tester.pump();

      client.emit(
        0,
        AgentStreamEvent(const {
          'event_id': 'evt-artifact-voice',
          'type': 'artifact.created',
          'thread_id': 'thread-artifact-voice',
          'run_id': 'run-artifact-voice',
          'artifact_id': 'artifact-voice',
          'sequence': 1,
          'payload': {
            'artifact_type': 'rich_text',
            'rich_text': {
              'title': '泌乳支持清单',
              'content': '我已经帮你整理好了。',
              'button': [
                {'label': '打开泌乳计划', 'action': 'navigate', 'value': '/schedule'},
              ],
            },
          },
        }),
      );
      await tester.pump();

      expect(player.realtimeSessions, isEmpty);

      client.emit(
        0,
        AgentStreamEvent(const {
          'event_id': 'evt-artifact-voice-message-completed',
          'type': 'message.completed',
          'thread_id': 'thread-artifact-voice',
          'run_id': 'run-artifact-voice',
          'sequence': 2,
          'payload': {'text': ''},
        }),
      );
      await tester.pump();
      await tester.pump();

      expect(player.realtimeSessions, hasLength(1));
      expect(player.realtimeSessions.single.appendedTexts, [
        '泌乳支持清单 我已经帮你整理好了。',
      ]);
      expect(
        player.realtimeSessions.single.appendedTexts.single,
        isNot(contains('打开泌乳计划')),
      );
      expect(
        player.realtimeSessions.single.appendedTexts.single,
        isNot(contains('/schedule')),
      );
      expect(player.realtimeSessions.single.finishCount, 1);

      player.realtimeSessions.single.complete();
      await tester.pump();
      await tester.pump();

      client.emit(
        0,
        AgentStreamEvent(const {
          'event_id': 'evt-artifact-voice-run-completed',
          'type': 'run.completed',
          'thread_id': 'thread-artifact-voice',
          'run_id': 'run-artifact-voice',
          'message_id': 'message-artifact-voice',
          'sequence': 3,
        }),
      );
      await tester.pump();
      await tester.pump();

      expect(player.realtimeSessions, hasLength(1));
      expect(player.realtimeSessions.single.appendedTexts, [
        '泌乳支持清单 我已经帮你整理好了。',
      ]);
    },
  );

  testWidgets(
    'Agent Hub does not repeat artifact copy when reply text is present',
    (tester) async {
      final player = _PageFakeVoicePlaybackPlayer();
      final client = _FixtureAgentStreamClient([
        AgentStreamEvent(const {
          'event_id': 'evt-artifact-with-text',
          'type': 'artifact.created',
          'thread_id': 'thread-artifact-with-text',
          'run_id': 'run-artifact-with-text',
          'artifact_id': 'artifact-with-text',
          'sequence': 1,
          'payload': {
            'artifact_type': 'rich_text',
            'rich_text': {'title': '泌乳支持清单', 'content': '我已经帮你整理好了。'},
          },
        }),
        AgentStreamEvent(const {
          'event_id': 'evt-artifact-with-text-delta',
          'type': 'message.delta',
          'thread_id': 'thread-artifact-with-text',
          'run_id': 'run-artifact-with-text',
          'message_id': 'message-artifact-with-text',
          'sequence': 2,
          'payload': {'text': '我已经根据你的情况整理好了。'},
        }),
        AgentStreamEvent(const {
          'event_id': 'evt-artifact-with-text-completed',
          'type': 'message.completed',
          'thread_id': 'thread-artifact-with-text',
          'run_id': 'run-artifact-with-text',
          'message_id': 'message-artifact-with-text',
          'sequence': 3,
          'payload': {'text': '我已经根据你的情况整理好了。'},
        }),
      ]);

      await tester.pumpWidget(
        _host(
          AgentHubPage(
            runner: AgentStreamRunner(client),
            voicePlaybackCoordinator: AgentVoicePlaybackCoordinator(),
            voicePlaybackPlayer: player,
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('agent-composer-input')),
        '帮我整理泌乳支持信息',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('agent-send-button')));
      await tester.pumpAndSettle();

      expect(player.realtimeSessions, hasLength(1));
      expect(player.realtimeSessions.single.appendedTexts, ['我已经根据你的情况整理好了。']);
      expect(player.realtimeSessions.single.finishCount, 1);
    },
  );

  testWidgets(
    'Agent Hub never replaces or replays spoken text on completed mismatch',
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
        'Keep the streamed reply',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('agent-send-button')));
      await tester.pump();

      client.emit(
        0,
        AgentStreamEvent(const {
          'event_id': 'evt-voice-mismatch-delta',
          'type': 'message.delta',
          'thread_id': 'thread-voice-mismatch',
          'run_id': 'run-voice-mismatch',
          'message_id': 'msg-voice-mismatch',
          'payload': {'text': 'Keep this reply.'},
        }),
      );
      await tester.pump();
      await tester.pump();

      client.emit(
        0,
        AgentStreamEvent(const {
          'event_id': 'evt-voice-mismatch-completed',
          'type': 'message.completed',
          'thread_id': 'thread-voice-mismatch',
          'run_id': 'run-voice-mismatch',
          'message_id': 'msg-voice-mismatch',
          'payload': {'role': 'assistant', 'text': 'Replacement reply.'},
        }),
      );
      await tester.pump();
      await tester.pump();

      expect(player.realtimeSessions, hasLength(1));
      expect(player.realtimeSessions.single.appendedTexts, [
        'Keep this reply.',
      ]);
      expect(player.realtimeSessions.single.finishCount, 1);
      expect(find.text('Keep this reply.', findRichText: true), findsOneWidget);
      expect(find.text('Replacement reply.', findRichText: true), findsNothing);
    },
  );

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

      expect(player.realtimeSessions, hasLength(1));
      expect(player.realtimeSessions.single.appendedTexts, ['Draft answer']);
      expect(player.stopCount, 1);
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

      expect(player.realtimeSessions, hasLength(1));
      expect(player.realtimeSessions.single.appendedTexts, [
        'Draft answer',
        ' ready.',
      ]);
      expect(player.realtimeSessions.single.finishCount, 1);
      expect(player.stopCount, 1);
      expect(coordinator.activeId, 'run-voice-late-id');
      expect(
        find.byKey(const ValueKey('agent-assistant-avatar-speaking')),
        findsOneWidget,
      );

      expect(player.realtimeSessions, hasLength(1));
      expect(player.stopCount, 1);
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
    'Agent Hub clears speaking avatar when notification interrupts auto voice',
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
        'Start auto voice',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('agent-send-button')));
      await tester.pump();

      client.emit(
        0,
        AgentStreamEvent({
          'event_id': 'evt-notification-interrupt-delta',
          'type': 'message.delta',
          'thread_id': 'thread-notification-interrupt',
          'run_id': 'run-notification-interrupt',
          'message_id': 'msg-notification-interrupt',
          'sequence': 1,
          'payload': {'text': 'Draft answer'},
        }),
      );
      await tester.pump();
      await tester.pump();

      expect(coordinator.activeSource, AgentVoicePlaybackSource.autoReply);
      expect(
        find.byKey(const ValueKey('agent-assistant-avatar-speaking')),
        findsOneWidget,
      );

      coordinator.request(
        id: 'notification-1',
        source: AgentVoicePlaybackSource.notification,
      );
      await tester.pump();
      await tester.pump();

      expect(coordinator.activeSource, AgentVoicePlaybackSource.notification);
      expect(player.realtimeSessions.single.cancelCount, 1);
      expect(
        find.byKey(const ValueKey('agent-assistant-avatar-speaking')),
        findsNothing,
      );
    },
  );

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
      expect(player.realtimeSessions, hasLength(1));
      expect(player.realtimeSessions.single.appendedTexts, [
        "I can help you review today's pumping pattern.",
      ]);
      expect(player.realtimeSessions.single.finishCount, 1);
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

    expect(find.byKey(const ValueKey('agent-run-status-line')), findsOneWidget);
    expect(find.text('正在组织答案～'), findsOneWidget);
    expect(find.text('Partial answer'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('agent-stop-button')));
    await tester.pump();

    expect(find.text('已停止本次回复'), findsOneWidget);
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

      expect(find.text('这次没有拿到回复。'), findsOneWidget);
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

    expect(find.text('正在请求服务端停止'), findsOneWidget);
    expect(find.text('已停止本次回复'), findsNothing);
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

    expect(find.text('本地已停止，服务端取消未确认'), findsOneWidget);
    expect(find.text('已停止本次回复'), findsNothing);
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
    'Agent Hub keeps queued text when the run starts awaiting confirmation',
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

      expect(client.requests, hasLength(1));
      expect(
        tester.widget<TextField>(composer).controller?.text,
        'Keep this draft',
      );
      expect(tester.widget<TextField>(composer).enabled, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Agent Hub releases visible running UI after completed assistant message',
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

      expect(find.byKey(const ValueKey('agent-stop-button')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('agent-response-light-rail')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('agent-assistant-avatar-thinking')),
        findsOneWidget,
      );

      client.emit(
        0,
        AgentStreamEvent(const {
          'type': 'message.completed',
          'thread_id': 'thread-visible-complete',
          'run_id': 'run-visible-complete',
          'message_id': 'msg-visible-complete',
          'payload': {
            'role': 'assistant',
            'text': 'Final answer',
            'quick_replies': [
              {'text': '继续聊这个'},
              {'text': '给我更多细节'},
              {'text': '换个方向'},
            ],
          },
        }),
      );
      await tester.pump();

      expect(find.text('Final answer'), findsOneWidget);
      expect(find.byKey(const ValueKey('agent-stop-button')), findsNothing);
      expect(find.byKey(const ValueKey('agent-send-button')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('agent-response-light-rail')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('agent-assistant-avatar-thinking')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('agent-assistant-avatar-static')),
        findsWidgets,
      );
      expect(find.byKey(const ValueKey('agent-quick-replies')), findsNothing);
      expect(find.text('猜你想说'), findsNothing);
      expect(find.text('继续聊这个'), findsNothing);
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const ValueKey('agent-new-session-button')),
            )
            .onPressed,
        isNotNull,
      );
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

    expect(find.byKey(const ValueKey('agent-run-status-line')), findsOneWidget);
    expect(find.text('正在组织答案～'), findsOneWidget);

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

    expect(find.text('连接暂时中断，可重试'), findsOneWidget);
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

    expect(find.text('请求超时，请稍后重试'), findsOneWidget);
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
      expect(find.text('请求超时，请稍后重试'), findsOneWidget);
      expect(find.byKey(const ValueKey('agent-retry-button')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('agent-retry-button')));
      await tester.pumpAndSettle();

      expect(client.requests, hasLength(2));
      expect(client.requests.last.runId, isNull);
      expect(
        client.requests.last.idempotencyKey,
        client.requests.first.idempotencyKey,
      );
      expect(find.text('泌乳支持信息表已打开。'), findsOneWidget);
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
      'Check my device status',
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('agent-send-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('agent-work-panel')), findsNothing);
    expect(find.text('处理进度'), findsNothing);
    expect(find.text('已生成设备状态说明'), findsWidgets);
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
          pickImage: (_) async => const AgentStreamImageInput(
            dataUrl: 'data:image/png;base64,fixture',
            mimeType: 'image/png',
            name: 'blocked-during-confirmation.png',
          ),
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
          .widget<IconButton>(
            find.byKey(const ValueKey('agent-attachment-button')),
          )
          .onPressed,
      isNull,
    );
    expect(find.byKey(const ValueKey('agent-voice-button')), findsNothing);
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

  testWidgets('Agent Hub renders only user-visible action cards', (
    tester,
  ) async {
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

    expect(find.byKey(const ValueKey('agent-action-panel')), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey('agent-action-card-action-visible-confirmation'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('agent-action-card-action-direct-hidden')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('agent-action-card-action-implicit-applied')),
      findsNothing,
    );
    expect(find.text('高风险确认动作'), findsOneWidget);
    expect(find.text('直接执行动作'), findsNothing);
    expect(find.text('普通已应用动作'), findsNothing);
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

  testWidgets('Agent Hub replay does not revive an applied-only action card', (
    tester,
  ) async {
    final store = _MemoryAgentHubInteractionStateStore(
      AgentHubInteractionSnapshot(
        runState: AgentStreamRunState.fromMap({
          'phase': 'finished',
          'textContent': '动作已经直接执行。',
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

    expect(find.text('动作已经直接执行。'), findsOneWidget);
    expect(find.byKey(const ValueKey('agent-action-panel')), findsNothing);
    expect(find.text('不应恢复的动作卡'), findsNothing);
    expect(find.text('已应用'), findsNothing);
  });

  testWidgets('Agent Hub restores historical artifacts from durable snapshot', (
    tester,
  ) async {
    final artifactEvent = _productionArtifactEvent(
      id: 'restored-history-note',
      type: 'rich_text',
      payload: {'title': '历史说明', 'content': '这张说明卡片来自上一次会话。'},
    );
    final historicalRunState =
        const AgentStreamRunState(phase: AgentStreamRunPhase.streaming)
            .applyEvent(artifactEvent)
            .copyWith(
              phase: AgentStreamRunPhase.finished,
              textContent: '这是上一次的计划。',
            );
    final store = _MemoryAgentHubInteractionStateStore(
      AgentHubInteractionSnapshot(
        historyMessages: [
          AgentHubHistorySnapshot(
            role: 'assistant',
            content: '这是上一次的计划。',
            runState: historicalRunState,
          ),
        ],
      ),
    );

    await tester.pumpWidget(_host(AgentHubPage(interactionStateStore: store)));
    await tester.pumpAndSettle();

    expect(find.text('这是上一次的计划。'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('agent-artifact-card-restored-history-note')),
      findsOneWidget,
    );
    expect(find.text('历史说明'), findsOneWidget);
    expect(find.text('这张说明卡片来自上一次会话。'), findsOneWidget);
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
      '继续',
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

  testWidgets('Agent Hub persists citations when archiving a reply', (
    tester,
  ) async {
    final store = _MemoryAgentHubInteractionStateStore();
    final client = _FixtureAgentStreamClient([
      AgentStreamEvent({
        'type': 'message.completed',
        'role': 'assistant',
        'message_id': 'assistant-next',
        'payload': {'text': '新的回复'},
      }),
      AgentStreamEvent({'type': 'run.completed', 'run_id': 'run-next'}),
    ]);
    final citationEvent = AgentStreamEvent({
      'type': 'CUSTOM',
      'name': 'momcozy.web_search.citations',
      'message_id': 'assistant-history-citation',
      'value': {
        'citations': [
          {
            'url': 'https://www.who.int/health-topics/breastfeeding',
            'title': 'WHO',
          },
        ],
      },
    });

    await tester.pumpWidget(
      _host(
        AgentHubPage(
          runner: AgentStreamRunner(client),
          interactionStateStore: store,
          state: AgentStreamRunState(
            phase: AgentStreamRunPhase.finished,
            messageId: 'assistant-history-citation',
            textContent: '这是带专业来源的回复。',
            events: [citationEvent],
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('agent-composer-input')),
      '继续',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('agent-send-button')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 300));

    final history = store.snapshot?.historyMessages ?? const [];
    expect(history, hasLength(2));
    final archivedAssistant = history.first;
    expect(archivedAssistant.role, 'assistant');
    expect(
      archivedAssistant.runState?.events.any(
        (event) => event.raw['name'] == 'momcozy.web_search.citations',
      ),
      isTrue,
    );
  });

  testWidgets('Agent Hub restores submitted historical forms as read-only', (
    tester,
  ) async {
    final formEvent = AgentStreamEvent({
      'event_id': 'restored-form-event',
      'type': 'artifact.created',
      'artifact_id': 'restored-form',
      'payload': {
        'artifact_type': 'form',
        'form': {
          'id': 'lactation_support_intake',
          'title': '历史信息采集',
          'submit_label': '确认',
          'fields': [
            {
              'id': 'feeding_context',
              'label': '泌乳目标',
              'type': 'text',
              'required': true,
            },
          ],
        },
      },
    });
    final historicalRunState =
        const AgentStreamRunState(phase: AgentStreamRunPhase.streaming)
            .applyEvent(formEvent)
            .copyWith(
              phase: AgentStreamRunPhase.finished,
              textContent: '请确认信息。',
            );
    final store = _MemoryAgentHubInteractionStateStore(
      AgentHubInteractionSnapshot(
        historyMessages: [
          AgentHubHistorySnapshot(
            role: 'assistant',
            content: '请确认信息。',
            runState: historicalRunState,
          ),
        ],
        formSubmissions: {
          'restored-form': AgentArtifactFormSubmission.submitted(
            values: const {'feeding_context': '38 周'},
          ),
        },
      ),
    );

    await tester.pumpWidget(
      _host(AgentHubPage(interactionStateStore: store), tickersEnabled: true),
    );
    await tester.pumpAndSettle();

    final entry = find.byKey(
      const ValueKey('agent-artifact-form-entry-restored-form'),
    );
    expect(entry, findsOneWidget);
    expect(find.text('已提交，可点击查看'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('agent-artifact-form-dialog-restored-form')),
      findsNothing,
    );

    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(find.text('38 周'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('agent-artifact-form-submit-restored-form')),
      findsNothing,
    );
    final input = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const ValueKey('agent-artifact-form-restored-form')),
        matching: find.byType(TextField),
      ),
    );
    expect(input.readOnly, isTrue);
  });

  testWidgets(
    'Agent Hub waits for final text then loads and auto-opens a new form once',
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
        '帮我整理泌乳支持信息',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('agent-send-button')));
      await tester.pump();
      expect(client.requests, hasLength(1));

      client.emit(
        0,
        AgentStreamEvent({
          'event_id': 'form-dialog-artifact',
          'type': 'artifact.created',
          'thread_id': 'thread-form-dialog',
          'run_id': 'run-form-dialog',
          'artifact_id': 'form-dialog-intake',
          'sequence': 1,
          'payload': {
            'artifact_type': 'form',
            'form': {
              'id': 'lactation_support_intake',
              'title': '泌乳支持信息采集',
              'fields': [
                {
                  'id': 'feeding_context',
                  'label': '泌乳目标',
                  'type': 'text',
                  'required': true,
                  'default_value': '32 周',
                },
              ],
            },
          },
        }),
      );
      await _pumpFrames(tester, 2);
      expect(
        find.byKey(
          const ValueKey('agent-artifact-form-entry-form-dialog-intake'),
        ),
        findsNothing,
      );

      client.emit(
        0,
        AgentStreamEvent(const {
          'event_id': 'form-dialog-delta',
          'type': 'message.delta',
          'thread_id': 'thread-form-dialog',
          'run_id': 'run-form-dialog',
          'message_id': 'message-form-dialog',
          'sequence': 2,
          'payload': {'text': '我先说明一下，再请你补充信息。'},
        }),
      );
      await _pumpFrames(tester, 2);
      expect(find.text('我先说明一下，再请你补充信息。'), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey('agent-artifact-form-entry-form-dialog-intake'),
        ),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('agent-artifact-form-form-dialog-intake')),
        findsNothing,
      );

      client.emit(
        0,
        AgentStreamEvent(const {
          'event_id': 'form-dialog-completed',
          'type': 'message.completed',
          'thread_id': 'thread-form-dialog',
          'run_id': 'run-form-dialog',
          'message_id': 'message-form-dialog',
          'sequence': 3,
          'payload': {'role': 'assistant', 'content': '我先说明一下，再请你补充信息。'},
        }),
      );
      await _pumpFrames(tester, 2);

      expect(
        find.byKey(
          const ValueKey('agent-artifact-form-entry-form-dialog-intake'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey(
            'agent-artifact-form-entry-loading-form-dialog-intake',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('agent-artifact-form-dialog-form-dialog-intake'),
        ),
        findsNothing,
      );

      await tester.pump(const Duration(milliseconds: 999));
      expect(
        find.byKey(
          const ValueKey('agent-artifact-form-dialog-form-dialog-intake'),
        ),
        findsNothing,
      );
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      expect(
        find.byKey(
          const ValueKey('agent-artifact-form-dialog-form-dialog-intake'),
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(
          const ValueKey('agent-artifact-form-cancel-form-dialog-intake'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(
          const ValueKey('agent-artifact-form-dialog-form-dialog-intake'),
        ),
        findsNothing,
      );
      await tester.pump(const Duration(seconds: 2));
      expect(
        find.byKey(
          const ValueKey('agent-artifact-form-dialog-form-dialog-intake'),
        ),
        findsNothing,
      );
    },
  );

  testWidgets('cancelled form dialog keeps its draft for manual reopen', (
    tester,
  ) async {
    var submitCount = 0;
    const card = AgentArtifactCardView(
      id: 'draft-form',
      title: '泌乳支持信息采集',
      description: '用于整理更适合你的泌乳支持计划。',
      formId: 'lactation_support_intake',
      presentationKind: AgentArtifactPresentationKind.form,
      formFields: [
        AgentArtifactFormFieldView(
          id: 'support_goal',
          label: '当前泌乳目标',
          type: 'text',
          required: true,
          defaultValue: '建立规律记录',
        ),
      ],
    );

    await tester.pumpWidget(
      _host(
        AgentArtifactPanel(
          cards: const [card],
          onFormSubmit: (_) async {
            submitCount += 1;
            return true;
          },
        ),
      ),
    );

    final entry = find.byKey(
      const ValueKey('agent-artifact-form-entry-draft-form'),
    );
    expect(entry, findsOneWidget);
    expect(
      find.byKey(const ValueKey('agent-artifact-form-draft-form')),
      findsNothing,
    );

    await tester.tap(entry);
    await tester.pumpAndSettle();
    final input = find.byKey(
      const ValueKey('agent-artifact-form-input-draft-form-support_goal--1'),
    );
    expect(input, findsOneWidget);
    await tester.enterText(input, '每天记录 4 次');
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('agent-artifact-form-cancel-draft-form')),
    );
    await tester.pumpAndSettle();

    expect(submitCount, 0);
    expect(
      find.byKey(const ValueKey('agent-artifact-form-dialog-draft-form')),
      findsNothing,
    );

    await tester.tap(entry);
    await tester.pumpAndSettle();
    final reopenedInput = tester.widget<TextFormField>(
      find.byKey(
        const ValueKey('agent-artifact-form-input-draft-form-support_goal--1'),
      ),
    );
    expect(
      reopenedInput.controller?.text ?? reopenedInput.initialValue,
      '每天记录 4 次',
    );

    await tester.enterText(input, '');
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('agent-artifact-form-cancel-draft-form')),
    );
    await tester.pumpAndSettle();
    await tester.tap(entry);
    await tester.pumpAndSettle();
    final clearedInput = tester.widget<TextFormField>(
      find.byKey(
        const ValueKey('agent-artifact-form-input-draft-form-support_goal--1'),
      ),
    );
    expect(clearedInput.controller?.text ?? clearedInput.initialValue, isEmpty);
  });

  testWidgets(
    'artifact form dialog blocks barrier and back dismissal while submitting',
    (tester) async {
      final attempts = <Completer<bool>>[];
      const card = AgentArtifactCardView(
        id: 'pending-form',
        title: '信息采集',
        presentationKind: AgentArtifactPresentationKind.form,
        formId: 'lactation_support_intake',
        formFields: [
          AgentArtifactFormFieldView(
            id: 'feeding_context',
            label: '泌乳目标',
            type: 'text',
            required: true,
            defaultValue: '建立规律记录',
          ),
        ],
      );

      await tester.pumpWidget(
        _host(
          AgentArtifactPanel(
            cards: const [card],
            onFormSubmit: (_) {
              final attempt = Completer<bool>();
              attempts.add(attempt);
              return attempt.future;
            },
          ),
        ),
      );
      await tester.tap(
        find.byKey(const ValueKey('agent-artifact-form-entry-pending-form')),
      );
      await tester.pumpAndSettle();

      final dialog = find.byKey(
        const ValueKey('agent-artifact-form-dialog-pending-form'),
      );
      final submit = find.byKey(
        const ValueKey('agent-artifact-form-submit-pending-form'),
      );
      await tester.tap(submit);
      await tester.pump();
      expect(attempts, hasLength(1));

      await tester.tapAt(const Offset(2, 2));
      await tester.pump();
      expect(dialog, findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(dialog, findsOneWidget);

      attempts.single.complete(false);
      await tester.pumpAndSettle();
      expect(find.text('提交失败，请重试'), findsOneWidget);

      await tester.tap(submit);
      await tester.pump();
      expect(attempts, hasLength(2));
      attempts.last.complete(true);
      await tester.pumpAndSettle();

      expect(dialog, findsNothing);
      expect(find.text('已提交，可点击查看'), findsOneWidget);
    },
  );

  testWidgets('artifact form dialog scrolls validation feedback into view', (
    tester,
  ) async {
    final card = AgentArtifactCardView(
      id: 'long-required-form',
      title: '恢复支持信息采集',
      presentationKind: AgentArtifactPresentationKind.form,
      formId: 'lactation_support_intake',
      formFields: [
        for (var index = 0; index < 12; index++)
          AgentArtifactFormFieldView(
            id: 'required_$index',
            label: '基本信息｜必填字段 ${index + 1}',
            type: 'text',
            required: true,
          ),
      ],
    );

    await tester.pumpWidget(
      _host(AgentArtifactPanel(cards: [card], onFormSubmit: (_) async => true)),
    );
    await tester.tap(
      find.byKey(
        const ValueKey('agent-artifact-form-entry-long-required-form'),
      ),
    );
    await tester.pumpAndSettle();

    final scrollView = find.byKey(
      const ValueKey('agent-artifact-form-scroll-long-required-form'),
    );
    final scrollController = tester
        .widget<SingleChildScrollView>(scrollView)
        .controller!;
    final position = scrollController.position;
    expect(position.pixels, 0);
    expect(position.maxScrollExtent, greaterThan(0));

    await tester.tap(
      find.byKey(
        const ValueKey('agent-artifact-form-submit-long-required-form'),
      ),
    );
    await tester.pumpAndSettle();

    final error = find.byKey(
      const ValueKey('agent-artifact-form-error-long-required-form'),
    );
    expect(error, findsOneWidget);
    expect(position.pixels, greaterThan(0));
    final scrollRect = tester.getRect(scrollView);
    final errorRect = tester.getRect(error);
    expect(errorRect.top, greaterThanOrEqualTo(scrollRect.top));
    expect(errorRect.bottom, lessThanOrEqualTo(scrollRect.bottom));
  });

  testWidgets(
    'artifact form dialog stacks long actions on narrow large-text screens',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const card = AgentArtifactCardView(
        id: 'responsive-form',
        title: '恢复支持信息采集',
        presentationKind: AgentArtifactPresentationKind.form,
        formId: 'recovery_support_intake',
        formSubmitLabel: '生成支持方案',
        formFields: [
          AgentArtifactFormFieldView(
            id: 'support_context',
            label: '主要支持场景',
            type: 'text',
            defaultValue: '居家恢复',
          ),
        ],
      );

      await tester.pumpWidget(
        _host(
          MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(1.6),
            ),
            child: AgentArtifactPanel(
              cards: const [card],
              onFormSubmit: (_) async => true,
            ),
          ),
        ),
      );
      await tester.tap(
        find.byKey(const ValueKey('agent-artifact-form-entry-responsive-form')),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final dialogRect = tester.getRect(
        find.byKey(
          const ValueKey('agent-artifact-form-dialog-responsive-form'),
        ),
      );
      final cancelRect = tester.getRect(
        find.byKey(
          const ValueKey('agent-artifact-form-cancel-responsive-form'),
        ),
      );
      final submitRect = tester.getRect(
        find.byKey(
          const ValueKey('agent-artifact-form-submit-responsive-form'),
        ),
      );
      expect(submitRect.top, greaterThan(cancelRect.bottom));
      expect(cancelRect.left, greaterThanOrEqualTo(dialogRect.left));
      expect(submitRect.right, lessThanOrEqualTo(dialogRect.right));
      expect(find.text('生成支持方案'), findsOneWidget);
    },
  );

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
          'type': 'message.delta',
          'thread_id': 'thread-action',
          'run_id': 'run-action',
          'message_id': 'msg-action-final',
          'sequence': 4,
          'payload': {'text': '\n\n工单已经创建。'},
        }),
        AgentStreamEvent(const {
          'event_id': 'evt-action-completed',
          'type': 'message.completed',
          'thread_id': 'thread-action',
          'run_id': 'run-action',
          'message_id': 'msg-action-final',
          'sequence': 5,
          'payload': {'role': 'assistant', 'text': '请确认是否创建支持工单。\n\n工单已经创建。'},
        }),
        AgentStreamEvent(const {
          'event_id': 'evt-action-run-completed',
          'type': 'run.completed',
          'thread_id': 'thread-action',
          'run_id': 'run-action',
          'message_id': 'msg-action-final',
          'sequence': 6,
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
      expect(find.textContaining('请确认是否创建支持工单。'), findsOneWidget);
      expect(find.textContaining('工单已经创建。'), findsOneWidget);
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
      find.byKey(const ValueKey('agent-artifact-card-care-note-001')),
      findsOneWidget,
    );
    expect(find.text('Care note'), findsOneWidget);
    expect(find.text('Ready'), findsOneWidget);
    expect(
      find.text('A concise note generated from a safe artifact payload.'),
      findsOneWidget,
    );
    expect(find.text('Review the device status'), findsOneWidget);
    expect(find.text('Open the next step when ready'), findsOneWidget);
    expect(find.text('打开结果卡片'), findsOneWidget);
    expect(find.textContaining('{"'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('agent-artifact-action-care-note-001-0')),
    );
    await tester.pump();
  });

  testWidgets('Agent Hub renders cards from indexed reducer events', (
    tester,
  ) async {
    final artifactEvent = AgentStreamEvent(
      readFixtureMap('agent_events/rich_text_artifact.json'),
    );
    final actionEvent = AgentStreamEvent(const {
      'type': 'action.confirmation_required',
      'action_id': 'action-indexed-001',
      'payload': {
        'action_id': 'action-indexed-001',
        'action_status': 'confirmation_required',
        'preview_payload': {'title': '确认索引动作'},
      },
    });

    await tester.pumpWidget(
      _host(
        AgentHubPage(
          state: AgentStreamRunState(
            phase: AgentStreamRunPhase.finished,
            textContent: 'I prepared indexed cards.',
            artifactEvents: {'care-note-001': artifactEvent},
            actionEvents: {'action-indexed-001': actionEvent},
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('agent-artifact-panel')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('agent-artifact-card-care-note-001')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('agent-action-panel')), findsOneWidget);
    expect(find.text('确认索引动作'), findsOneWidget);
  });

  testWidgets(
    'Agent Hub submits a support ticket without a second confirmation',
    (tester) async {
      final client = _ControllableAgentStreamClient();
      addTearDown(client.dispose);
      final submissions = <SupportTicketSubmitRequest>[];
      final ticketEvent = AgentStreamEvent({
        'type': 'artifact.created',
        'payload': {
          'artifact_id': 'support-ticket-1',
          'artifact_type': 'support_ticket_draft',
          'schema_version': '1.0',
          'status': 'created',
          'artifact': {
            'id': 'support-ticket-1',
            'artifact_type': 'support_ticket_draft',
            'schema_version': '1.0',
            'status': 'created',
            'payload': {
              'tool_name': 'support.ticket.propose',
              'submit_label': '确认并提交',
              'ticket': {
                'issue_type': 'malfunction',
                'issue_summary': '吸奶器无法启动',
                'product_model': 'Air1',
                'order_number': 'MC123',
                'purchase_channel': '官网',
                'urgency': 'normal',
              },
            },
          },
        },
      });

      await tester.pumpWidget(
        _host(
          AgentHubPage(
            runner: AgentStreamRunner(client),
            supportTicketSubmitter: (request) async {
              submissions.add(request);
              return const SupportTicketSubmitResult(
                ticketNumber: 'MC-123',
                status: 'open',
              );
            },
            state: AgentStreamRunState(
              phase: AgentStreamRunPhase.finished,
              threadId: 'thread-support-ticket',
              textContent: '请确认售后信息。',
              events: [ticketEvent],
            ),
          ),
        ),
      );

      expect(find.text('售后工单'), findsOneWidget);
      await tester.tap(
        find.byKey(
          const ValueKey('agent-artifact-form-entry-support-ticket-1'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('问题类型'), findsOneWidget);
      expect(find.text('问题描述'), findsOneWidget);
      expect(find.text('产品型号'), findsOneWidget);
      expect(find.text('订单号'), findsOneWidget);
      expect(find.text('购买渠道'), findsOneWidget);
      expect(find.text('紧急程度'), findsOneWidget);

      final submit = find.byKey(
        const ValueKey('agent-artifact-form-submit-support-ticket-1'),
      );
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(client.requests, isEmpty);
      expect(submissions, hasLength(1));
      expect(submissions.single.artifactId, 'support-ticket-1');
      expect(submissions.single.threadId, 'thread-support-ticket');
      expect(submissions.single.values['issue_summary'], '吸奶器无法启动');
      expect(
        submissions.single.idempotencyKey,
        startsWith('agent-form-submit-'),
      );
      expect(find.text('已提交售后工单'), findsOneWidget);
      expect(find.text('已提交，可点击查看'), findsOneWidget);
      expect(find.text('信息已确认'), findsNothing);
      expect(find.textContaining('人工客服团队会在 24 小时内主动联系你'), findsOneWidget);
    },
  );

  testWidgets(
    'Agent Hub keeps the support form retryable when submission fails',
    (tester) async {
      final client = _ControllableAgentStreamClient();
      addTearDown(client.dispose);
      final ticketEvent = AgentStreamEvent({
        'type': 'artifact.created',
        'artifact_id': 'support-ticket-failure',
        'artifact_type': 'support_ticket_draft',
        'submit_label': '确认并提交',
        'ticket': {
          'issue_type': 'malfunction',
          'issue_summary': '吸奶器无法启动',
          'product_model': 'Air1',
          'urgency': 'normal',
        },
      });

      await tester.pumpWidget(
        _host(
          AgentHubPage(
            runner: AgentStreamRunner(client),
            supportTicketSubmitter: (_) async => throw StateError('offline'),
            state: AgentStreamRunState(
              phase: AgentStreamRunPhase.finished,
              textContent: '请确认售后信息。',
              events: [ticketEvent],
            ),
          ),
        ),
      );

      await tester.tap(
        find.byKey(
          const ValueKey('agent-artifact-form-entry-support-ticket-failure'),
        ),
      );
      await tester.pumpAndSettle();
      final submit = find.byKey(
        const ValueKey('agent-artifact-form-submit-support-ticket-failure'),
      );
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(client.requests, isEmpty);
      expect(find.text('提交失败，请重试'), findsOneWidget);
      expect(find.text('确认并提交'), findsOneWidget);
      expect(find.text('已提交售后工单'), findsNothing);
    },
  );

  testWidgets(
    'Agent Hub aligns grouped artifact form defaults other input and submit lock',
    (tester) async {
      final actions = <AgentArtifactActionView>[];
      final card = AgentArtifactCardView(
        id: 'form-alignment',
        title: '信息采集',
        formId: 'lactation_support_intake',
        formFields: [
          const AgentArtifactFormFieldView(
            id: 'feeding_context',
            label: '基本信息｜泌乳目标',
            type: 'text',
            required: true,
            defaultValue: '建立规律记录',
            helpText: '请填写当前最关注的泌乳目标。',
          ),
          const AgentArtifactFormFieldView(
            id: 'support_preferences',
            label: '偏好信息｜支持方式',
            type: 'checkbox_group',
            required: true,
            options: ['图文指导', '提醒', '其他'],
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

      await tester.tap(
        find.byKey(const ValueKey('agent-artifact-form-entry-form-alignment')),
      );
      await tester.pumpAndSettle();
      expect(find.text('基本信息'), findsOneWidget);
      expect(find.text('偏好信息'), findsOneWidget);
      expect(find.text('泌乳目标'), findsOneWidget);
      expect(find.text('支持方式'), findsOneWidget);
      expect(find.text('基本信息｜泌乳目标'), findsNothing);
      expect(find.text('建立规律记录'), findsOneWidget);
      expect(find.text('请填写当前最关注的泌乳目标。'), findsOneWidget);
      expect(find.text('结果卡片'), findsNothing);
      final otherFinder = find.byKey(
        const ValueKey(
          'agent-artifact-form-other-form-alignment-support_preferences',
        ),
      );
      expect(otherFinder, findsOneWidget);

      final submitFinder = find.byKey(
        const ValueKey('agent-artifact-form-submit-form-alignment'),
      );
      await tester.ensureVisible(submitFinder);
      await tester.pump();
      await tester.tap(submitFinder);
      await tester.pump();

      expect(actions, isEmpty);
      expect(find.text('请填写：支持方式的其它内容'), findsOneWidget);

      await tester.enterText(otherFinder, '希望每天提醒');
      await tester.pump();
      await tester.ensureVisible(submitFinder);
      await tester.pump();
      await tester.tap(submitFinder);
      await tester.pump();

      expect(actions, hasLength(1));
      expect(actions.single.value, contains('"feeding_context":"建立规律记录"'));
      expect(
        actions.single.value,
        contains('"support_preferences":["其它：希望每天提醒"]'),
      );
      expect(find.text('已提交，可点击查看'), findsOneWidget);
    },
  );

  testWidgets(
    'Agent artifact form stays editable when submission is rejected',
    (tester) async {
      var attempts = 0;
      const card = AgentArtifactCardView(
        id: 'retryable-form',
        title: '信息采集',
        formId: 'lactation_support_intake',
        presentationKind: AgentArtifactPresentationKind.form,
        formFields: [
          AgentArtifactFormFieldView(
            id: 'feeding_context',
            label: '基本信息｜泌乳目标',
            type: 'text',
            required: true,
            defaultValue: '建立规律记录',
          ),
        ],
      );

      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 360,
            child: AgentArtifactPanel(
              cards: const [card],
              onFormSubmit: (_) async {
                attempts += 1;
                return attempts > 1;
              },
            ),
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('agent-artifact-form-entry-retryable-form')),
      );
      await tester.pumpAndSettle();
      final submitFinder = find.byKey(
        const ValueKey('agent-artifact-form-submit-retryable-form'),
      );
      expect(tester.getSize(submitFinder).height, greaterThanOrEqualTo(44));

      await tester.tap(submitFinder);
      await tester.pumpAndSettle();

      expect(attempts, 1);
      expect(find.text('提交失败，请重试'), findsOneWidget);
      expect(find.text('已提交'), findsNothing);

      await tester.tap(submitFinder);
      await tester.pumpAndSettle();

      expect(attempts, 2);
      expect(find.text('已提交，可点击查看'), findsOneWidget);
    },
  );

  testWidgets('Agent Hub restores form editing when run creation fails', (
    tester,
  ) async {
    final client = _FailingAgentStreamClient(StateError('run rejected'));
    final formEvent = AgentStreamEvent({
      'type': 'artifact.created',
      'artifact_id': 'retryable-run-form',
      'payload': {
        'artifact_type': 'form',
        'form': {
          'id': 'lactation_support_intake',
          'title': '信息采集',
          'fields': [
            {
              'id': 'feeding_context',
              'label': '泌乳目标',
              'type': 'text',
              'required': true,
              'default': '建立规律记录',
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
            textContent: '请确认信息。',
            events: [formEvent],
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(
        const ValueKey('agent-artifact-form-entry-retryable-run-form'),
      ),
    );
    await tester.pumpAndSettle();
    final submitFinder = find.byKey(
      const ValueKey('agent-artifact-form-submit-retryable-run-form'),
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(
          const ValueKey('agent-artifact-form-retryable-run-form'),
        ),
        matching: find.byType(TextFormField),
      ),
      '38 周',
    );
    await tester.ensureVisible(submitFinder);
    await tester.tap(submitFinder);
    await tester.pumpAndSettle();

    expect(client.requests, hasLength(1));
    expect(find.text('已提交'), findsNothing);
    expect(tester.widget<FilledButton>(submitFinder).onPressed, isNotNull);
  });

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
          'title': '泌乳用品偏好',
          'fields': [
            {
              'id': 'packing_items',
              'label': '想加入的物品',
              'type': 'checkbox_group',
              'required': true,
              'options': ['储奶袋', '乳垫', '清洁刷'],
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
            textContent: '请选择需要的泌乳用品。',
            events: [formEvent],
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('agent-artifact-form-entry-packing-form')),
    );
    await tester.pumpAndSettle();
    expect(find.text('储奶袋'), findsOneWidget);
    expect(find.text('乳垫'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.byType(Checkbox), findsNWidgets(3));

    await tester.tap(find.text('储奶袋'));
    await tester.pump();
    await tester.tap(find.text('乳垫'));
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('agent-artifact-form-submit-packing-form')),
    );
    await tester.pump();

    expect(client.requests, hasLength(1));
    final submission =
        client.requests.single.metadata['form_submission']!
            as Map<String, Object?>;
    expect(submission['values'], {
      'packing_items': ['储奶袋', '乳垫'],
    });
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
            {
              'text': '打开文档',
              'type': 'doc',
              'value': '/v1/assets/asset-doc?kind=pdf',
            },
            {
              'text': '查看图片',
              'type': 'media',
              'value': '/v1/assets/asset-image?kind=image',
            },
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
    expect(actions.single.value, '/v1/assets/asset-doc?kind=pdf');
    expect(actions.single.routePath, '/media-viewer');
    expect(actions.single.routeExtra, {
      'kind': 'pdf',
      'url': '/v1/assets/asset-doc?kind=pdf',
      'title': '打开文档',
    });

    await tester.tap(
      find.byKey(const ValueKey('agent-artifact-action-resource-card-1')),
    );
    await tester.pump();

    expect(actions.last.kind, 'media');
    expect(actions.last.value, '/v1/assets/asset-image?kind=image');
    expect(actions.last.routePath, '/media-viewer');
    expect(actions.last.routeExtra, {
      'kind': 'image',
      'url': '/v1/assets/asset-image?kind=image',
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
            {'title': '危险来源', 'url': 'javascript:alert(1)'},
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
    expect(find.text('危险来源'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('agent-artifact-action-citation-card-0')),
    );
    await tester.pump();

    expect(actions.single.kind, 'citation');
    expect(actions.single.value, 'https://www.cdc.gov/breastfeeding/mastitis');
    expect(actions.single.routePath, isNull);
    expect(
      actions.single.externalUri,
      Uri.parse('https://www.cdc.gov/breastfeeding/mastitis'),
    );
  });

  testWidgets('Agent Hub renders web search citations consistently', (
    tester,
  ) async {
    final actions = <AgentArtifactActionView>[];
    final citationEvent = AgentStreamEvent({
      'type': 'CUSTOM',
      'name': 'momcozy.web_search.citations',
      'message_id': 'assistant-citations',
      'value': {
        'citations': [
          {
            'url': 'https://www.cdc.gov/breastfeeding',
            'title': 'CDC Breastfeeding',
            'displayText': 'CDC 健康指南：cdc.gov/breastfeeding',
          },
          {
            'url': 'https://www.who.int/health-topics/breastfeeding',
            'title': 'WHO',
          },
        ],
      },
    });

    await tester.pumpWidget(
      _host(
        AgentHubPage(
          state: AgentStreamRunState(
            phase: AgentStreamRunPhase.finished,
            messageId: 'assistant-citations',
            textContent:
                '参考 [CDC](https://www.cdc.gov/breastfeeding)。\ncite turn1search5',
            events: [citationEvent],
          ),
          onArtifactAction: actions.add,
        ),
      ),
    );

    expect(find.text('专业信息源'), findsOneWidget);
    expect(find.text('CDC', findRichText: true), findsNothing);
    expect(find.textContaining('turn1search5'), findsNothing);
    expect(find.text('[1]', findRichText: true), findsWidgets);
    expect(find.text('CDC 健康指南：cdc.gov/breastfeeding'), findsOneWidget);
    expect(find.text('WHO 健康指南：who.int/health-topics/...'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('agent-citation-link-1')));
    await tester.pump();

    expect(actions, hasLength(1));
    expect(actions.single.kind, 'citation');
    expect(
      actions.single.externalUri,
      Uri.parse('https://www.cdc.gov/breastfeeding'),
    );
  });

  testWidgets('Agent Hub dispatches safe markdown links only', (tester) async {
    final actions = <AgentArtifactActionView>[];
    const markdown = '''
[查看护理资料](https://example.com/care)

[打开 Me](/me?day=today)

[危险链接](javascript:alert(1))
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

    await tester.tap(find.text('查看护理资料', findRichText: true));
    await tester.pump();
    expect(actions.single.externalUri, Uri.parse('https://example.com/care'));
    expect(actions.single.routePath, isNull);

    await tester.tap(find.text('打开 Me', findRichText: true));
    await tester.pump();
    expect(actions.last.routePath, '/me');
    expect(actions.last.value, '/me?day=today');
    expect(actions.last.externalUri, isNull);

    await tester.tap(find.text('危险链接', findRichText: true));
    await tester.pump();
    expect(actions, hasLength(2));
  });

  testWidgets('Agent Hub wraps long citations on narrow mobile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final citationEvent = AgentStreamEvent({
      'type': 'CUSTOM',
      'name': 'momcozy.web_search.citations',
      'value': {
        'citations': [
          {
            'url':
                'https://www.ncbi.nlm.nih.gov/books/NBK501922/long-reference-path',
            'title': 'NCBI',
            'displayText':
                '这是一条需要在窄屏上自然换行的专业医学资料：ncbi.nlm.nih.gov/books/NBK501922/long-reference-path',
          },
        ],
      },
    });

    await tester.pumpWidget(
      _host(
        AgentHubPage(
          state: AgentStreamRunState(
            phase: AgentStreamRunPhase.finished,
            textContent: '我整理好了参考来源。',
            events: [citationEvent],
          ),
          onArtifactAction: (_) {},
        ),
      ),
    );

    expect(find.byKey(const ValueKey('agent-citation-list')), findsOneWidget);
    expect(tester.takeException(), isNull);
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
    expect(find.text('连接暂时中断，可重试'), findsOneWidget);
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

      expect(
        find.byKey(const ValueKey('agent-run-status-line')),
        findsOneWidget,
      );
      expect(find.text('正在组织答案～'), findsOneWidget);
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
    final markdownStyles = tester
        .widget<MarkdownBody>(find.byType(MarkdownBody))
        .styleSheet!;
    expect(markdownStyles.p!.height, 1.65);
    expect(markdownStyles.h2!.fontSize, 17);
    expect(markdownStyles.h2!.height, 1.5);
    expect(markdownStyles.a!.decoration, TextDecoration.underline);
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

  testWidgets('Agent Hub keeps markdown rendering stable while streaming', (
    tester,
  ) async {
    const markdown = '## 正在整理\n- **重点**：先等我写完';

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
    expect(find.text('正在整理', findRichText: true), findsOneWidget);
    expect(find.textContaining('重点', findRichText: true), findsOneWidget);
  });

  testWidgets(
    'Agent Hub renders product asset media links and opens viewer actions',
    (tester) async {
      final actions = <AgentArtifactActionView>[];
      const imageUrl = '/v1/assets/asset-image?kind=image';
      const pdfUrl = '/v1/assets/asset-pdf?kind=pdf';
      const videoUrl = '/v1/assets/asset-video?kind=video';
      const markdown =
          '''
先看 ![查看图片]($imageUrl)

[打开 PDF]($pdfUrl)

[打开视频]($videoUrl)

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

      expect(actions, hasLength(3));
    },
  );

  testWidgets(
    'Agent Hub degrades retired skill assets without network or viewer actions',
    (tester) async {
      final actions = <AgentArtifactActionView>[];
      const legacyImage =
          '/skill-assets/device-guidance/air1/images/legacy-guide.png';
      const legacyPdf = '/skill-assets/device-guidance/air1/legacy-guide.pdf';
      const unstableExternalImage = 'https://cdn.example.test/legacy-guide.png';
      const markdown =
          '''
![Air1 对照图]($legacyImage)

![外部临时图]($unstableExternalImage)

[打开旧版说明书]($legacyPdf)
''';

      await tester.pumpWidget(
        _host(
          AgentHubPage(
            state: AgentStreamRunState(
              phase: AgentStreamRunPhase.finished,
              textContent: markdown,
              events: [
                AgentStreamEvent({
                  'type': 'artifact.created',
                  'artifact_id': 'retired-media',
                  'payload': {
                    'artifact_type': 'rich_text',
                    'rich_text': {
                      'title': '旧版资料',
                      'button': [
                        {'text': '打开旧版资料卡', 'type': 'doc', 'value': legacyPdf},
                      ],
                    },
                  },
                }),
              ],
            ),
            onArtifactAction: actions.add,
          ),
        ),
      );

      final imageFinder = find.byKey(
        const ValueKey('agent-markdown-image-$legacyImage'),
      );
      expect(imageFinder, findsOneWidget);
      expect(
        find.descendant(of: imageFinder, matching: find.byType(Image)),
        findsNothing,
      );
      expect(
        find.descendant(
          of: imageFinder,
          matching: find.byType(ProductAssetImage),
        ),
        findsNothing,
      );
      final externalImageFinder = find.byKey(
        const ValueKey('agent-markdown-image-$unstableExternalImage'),
      );
      expect(externalImageFinder, findsOneWidget);
      expect(
        find.descendant(of: externalImageFinder, matching: find.byType(Image)),
        findsNothing,
      );
      expect(find.text('图片暂不可用'), findsNWidgets(2));

      await tester.tap(imageFinder);
      await tester.pump();
      await tester.tap(externalImageFinder);
      await tester.pump();
      await tester.tap(find.text('打开旧版说明书', findRichText: true));
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('agent-artifact-action-retired-media-0')),
      );
      await tester.pump();

      expect(actions, isEmpty);
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

  testWidgets('Agent Hub uses the approved context-ready fallback copy', (
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

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('agent-run-status-line')),
        matching: find.text('我先理解一下你的需求～'),
      ),
      findsOneWidget,
    );
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
            'semantic': {'label': '我在组织回复～', 'surface': 'status_bar'},
          },
        }),
      ],
    );

    await tester.pumpWidget(_host(AgentHubPage(state: state)));

    expect(find.text('我在组织回复～'), findsOneWidget);
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
    expect(find.text('我已经收到你的消息啦～'), findsOneWidget);
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
            'label': '我想一下',
            'semantic': {'label': '我想一下', 'surface': 'thinking_note'},
          },
        }),
      ],
    );

    await tester.pumpWidget(_host(AgentHubPage(state: state)));

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('agent-run-status-line')),
        matching: find.text('我已经收到你的消息啦～'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('agent-thinking-note')),
        matching: find.text('我想一下'),
      ),
      findsOneWidget,
    );
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

  testWidgets('Agent Hub uses tool semantic labels for loop status', (
    tester,
  ) async {
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
                'label': '我先看看今天的奶量状态～',
                'surface': 'work_item',
                'lifecycle': 'running',
              },
            },
          }),
        );

    await tester.pumpWidget(_host(AgentHubPage(state: state)));

    expect(find.byKey(const ValueKey('agent-run-status-line')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('agent-run-status-line')),
        matching: find.text('我先看看今天的奶量状态～'),
      ),
      findsOneWidget,
    );
    expect(find.text('正在读取奶量状态'), findsNothing);
  });

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
                'label': '我看好今天的奶量状态啦',
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
                'label': '我接着处理下一步',
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

      expect(find.text('我看好今天的奶量状态啦'), findsOneWidget);
      expect(find.text('我接着处理下一步'), findsNothing);
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
            AgentRunStatusLine(title: '我已经收到你的消息啦～'),
            AgentThinkingNote(title: '我想一下'),
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
    final statusTextLeft = tester.getTopLeft(find.text('我已经收到你的消息啦～')).dx;
    final thinkingTextLeft = tester.getTopLeft(find.text('我想一下')).dx;

    expect(statusLine.padding, const EdgeInsets.symmetric(vertical: 4));
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
                'payload': {'phase': 'model_reasoning', 'label': '我想一下'},
              }),
            ],
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('agent-thinking-note')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2201));

    expect(find.byKey(const ValueKey('agent-thinking-note')), findsOneWidget);
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

      expect(find.text('我接着处理下一步'), findsNothing);
      expect(
        find.byKey(const ValueKey('agent-run-status-line')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('agent-run-status-line')),
          matching: find.text('我已经收到你的消息啦～'),
        ),
        findsOneWidget,
      );
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
            'label': '我接着处理下一步',
            'semantic': {'label': '我接着处理下一步', 'surface': 'status_bar'},
          },
        }),
        AgentStreamEvent({
          'type': 'run.progress',
          'payload': {
            'phase': 'model_reasoning_after_tool',
            'label': '我想一下',
            'semantic': {'label': '我想一下', 'surface': 'thinking_note'},
          },
        }),
      ],
    );

    await tester.pumpWidget(_host(AgentHubPage(state: state)));

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('agent-run-status-line')),
        matching: find.text('我接着处理下一步'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('agent-thinking-note')),
        matching: find.text('我想一下'),
      ),
      findsOneWidget,
    );
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
                'semantic': {'label': '泌乳支持计划已经生成啦', 'surface': 'artifact'},
              },
            }),
          ),
        ),
      ),
    );

    expect(find.text('泌乳支持计划已经生成啦'), findsOneWidget);

    await tester.pumpWidget(
      _host(
        AgentHubPage(
          state: stateWith(
            AgentStreamEvent({
              'type': 'action.confirmation_required',
              'payload': {
                'semantic': {'label': '我需要你确认一下，再继续处理', 'surface': 'action'},
              },
            }),
          ),
        ),
      ),
    );

    expect(find.text('我需要你确认一下，再继续处理'), findsOneWidget);
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
    expect(find.text('这次没有拿到回复。'), findsOneWidget);
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
    expect(find.text('我已经收到你的消息啦～'), findsOneWidget);
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

  testWidgets('Agent Hub switches status copy after reply text starts', (
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
    expect(find.byKey(const ValueKey('agent-run-status-line')), findsOneWidget);
    expect(find.text('正在组织答案～'), findsOneWidget);
  });

  testWidgets(
    'Agent Hub keeps status through user persistence and token streaming',
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
          'payload': {'label': '我已经收到你的消息啦～'},
        }),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('agent-run-status-line')),
        findsOneWidget,
      );
      expect(find.text('我已经收到你的消息啦～'), findsOneWidget);

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

      expect(
        find.byKey(const ValueKey('agent-run-status-line')),
        findsOneWidget,
      );
      expect(find.text('我已经收到你的消息啦～'), findsOneWidget);

      client.emit(
        0,
        AgentStreamEvent({
          'event_id': 'evt-progress-before-token',
          'type': 'run.progress',
          'thread_id': 'thread-progress',
          'run_id': 'run-progress',
          'sequence': 3,
          'payload': {'label': '正在生成泌乳支持信息采集表单'},
        }),
      );
      await tester.pump();

      expect(find.text('正在生成泌乳支持信息采集表单'), findsOneWidget);

      client.emit(
        0,
        AgentStreamEvent({
          'event_id': 'evt-first-token',
          'type': 'message.delta',
          'thread_id': 'thread-progress',
          'run_id': 'run-progress',
          'message_id': 'msg-progress',
          'sequence': 4,
          'payload': {'text': '好的'},
        }),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('好的'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('agent-run-status-line')),
        findsOneWidget,
      );
      expect(find.text('正在组织答案～'), findsOneWidget);

      client.emit(
        0,
        AgentStreamEvent({
          'event_id': 'evt-assistant-message-completed',
          'type': 'message.completed',
          'thread_id': 'thread-progress',
          'run_id': 'run-progress',
          'message_id': 'msg-progress',
          'sequence': 5,
          'payload': {'role': 'assistant', 'text': '好的，我已经整理好了。'},
        }),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('好的，我已经整理好了。'), findsOneWidget);
      expect(find.byKey(const ValueKey('agent-run-status-line')), findsNothing);
    },
  );

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

AgentStreamEvent _productionArtifactEvent({
  required String id,
  required String type,
  required Map<String, Object?> payload,
}) {
  return AgentStreamEvent({
    'type': 'artifact.created',
    'artifact_id': id,
    'payload': {
      'artifact_id': id,
      'artifact_type': type,
      'schema_version': 'v1',
      'artifact': {
        'id': id,
        'artifact_type': type,
        'schema_version': 'v1',
        'payload': payload,
      },
    },
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
  _SequencedConversationRepository(this.histories);

  final List<AgentConversationHistory> histories;
  int loadCalls = 0;

  @override
  Future<List<AgentConversationSummary>> listConversations({
    int limit = 50,
  }) async => const [];

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

class _ThrowingAgentHubInteractionStateStore
    implements AgentHubInteractionStateStore {
  @override
  Future<AgentHubInteractionSnapshot?> read() {
    return Future<AgentHubInteractionSnapshot?>.error(
      StateError('restore unavailable'),
    );
  }

  @override
  Future<void> write(AgentHubInteractionSnapshot snapshot) async {}

  @override
  Future<void> clear() async {}
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
      'payload': {'label': '我已经收到你的消息啦～'},
    });
    yield AgentStreamEvent(const {
      'event_id': 'evt-run-created-2',
      'type': 'message.completed',
      'thread_id': 'thread-created',
      'run_id': 'run-created',
      'message_id': 'msg-created',
      'sequence': 2,
      'payload': {'role': 'assistant', 'text': '泌乳支持信息表已打开。'},
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
    Duration? timeout,
  }) async {
    this.uri = uri;
    this.headers = headers;
    this.body = body;
    if (!called.isCompleted) called.complete();
    return response;
  }
}

class _PageFakeVoicePlaybackPlayer implements AgentVoicePlaybackPlayer {
  final playedTexts = <String>[];
  final realtimeSessions = <_PageFakeVoiceRealtimePlaybackSession>[];
  var stopCount = 0;
  Completer<void>? _active;

  @override
  Future<void> playText(String text) {
    playedTexts.add(text);
    _active = Completer<void>();
    return _active!.future;
  }

  @override
  AgentVoiceRealtimePlaybackSession startRealtimeSession({
    AgentVoiceMediaNarrationResolver? mediaNarrationResolver,
  }) {
    final session = _PageFakeVoiceRealtimePlaybackSession(
      mediaNarrationResolver: mediaNarrationResolver,
    );
    realtimeSessions.add(session);
    return session;
  }

  @override
  Future<void> stop() async {
    stopCount += 1;
    complete();
    for (final session in realtimeSessions.where(
      (session) => !session.isDone,
    )) {
      await session.cancel();
    }
  }

  void complete() {
    final active = _active;
    if (active != null && !active.isCompleted) {
      active.complete();
    }
  }
}

class _PageFakeVoiceRealtimePlaybackSession
    implements AgentVoiceRealtimePlaybackSession {
  _PageFakeVoiceRealtimePlaybackSession({this.mediaNarrationResolver})
    : _textFilter = AgentVoiceTextStreamFilter(
        mediaNarrationResolver: mediaNarrationResolver,
      );

  final AgentVoiceMediaNarrationResolver? mediaNarrationResolver;
  final AgentVoiceTextStreamFilter _textFilter;
  final appendedTexts = <String>[];
  final filteredTexts = <String>[];
  var flushCount = 0;
  var finishCount = 0;
  var cancelCount = 0;
  final Completer<void> _done = Completer<void>();

  bool get isDone => _done.isCompleted;

  @override
  Future<void> get done => _done.future;

  @override
  void append(String delta) {
    appendedTexts.add(delta);
    _recordFiltered(_textFilter.push(delta));
  }

  @override
  void flush() {
    flushCount += 1;
    _recordFiltered(_textFilter.flush());
  }

  @override
  void finish() {
    finishCount += 1;
    _recordFiltered(_textFilter.flush());
  }

  @override
  Future<void> cancel() async {
    cancelCount += 1;
    complete();
  }

  void complete() {
    if (!_done.isCompleted) _done.complete();
  }

  void fail(Object error) {
    if (!_done.isCompleted) _done.completeError(error);
  }

  void _recordFiltered(String text) {
    if (text.isNotEmpty) filteredTexts.add(text);
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
  _FakeAgentImageMediaRepository({this.deleteFailure});

  final Object? deleteFailure;
  final uploadedFiles = <ApiUploadFile>[];
  final deletedFileIds = <String>[];

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
    final failure = deleteFailure;
    if (failure != null) throw failure;
  }
}
