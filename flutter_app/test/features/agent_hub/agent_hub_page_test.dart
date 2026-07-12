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
import 'package:momcozy_flutter_app/features/agent_hub/data/ibclc_consult_store.dart';
import 'package:momcozy_flutter_app/features/agent_hub/data/voice_playback.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_hub_greeting.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/birth_prep_profile_defaults.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/ibclc_consult.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_image_input.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_voice.dart';
import 'package:momcozy_flutter_app/features/agent_hub/presentation/agent_image_previews.dart';
import 'package:momcozy_flutter_app/features/hospital_bag/domain/hospital_bag_cart.dart';
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

  testWidgets('Agent Hub focuses a newly arrived artifact near viewport top', (
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
      '帮我准备待产包',
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
            'id': 'hospital_bag_intake',
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

    final chatRect = tester.getRect(
      find.byKey(const ValueKey('agent-chat-scroll-view')),
    );
    final artifactRect = tester.getRect(
      find.byKey(const ValueKey('agent-artifact-panel')),
    );
    expect(artifactRect.top, greaterThan(chatRect.top + 70));
    expect(artifactRect.top, lessThan(chatRect.top + chatRect.height * 0.55));
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
            artifactEvents: {'milk-plan-001': artifactEvent},
            completedAssistantMessageReceived: true,
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('agent-artifact-panel')), findsOneWidget);
  });

  testWidgets('Agent Hub ingests a cart artifact before publishing its card', (
    tester,
  ) async {
    final client = _ControllableAgentStreamClient();
    final cartUpdates = <HospitalBagCartArtifactSeed>[];
    addTearDown(client.dispose);

    await tester.pumpWidget(
      _host(
        AgentHubPage(
          runner: AgentStreamRunner(client),
          onHospitalBagCartUpdate: cartUpdates.add,
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('agent-composer-input')),
      '帮我整理待产包',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('agent-send-button')));
    await tester.pump();

    client.emit(
      0,
      AgentStreamEvent(const {
        'event_id': 'evt-pending-cart-artifact',
        'type': 'artifact.created',
        'thread_id': 'thread-pending-cart',
        'run_id': 'run-pending-cart',
        'artifact_id': 'pending-cart-artifact',
        'sequence': 1,
        'payload': {
          'artifact_type': 'hospital_bag_card',
          'assistant_followup': {
            'kind': 'hospital_bag_cart',
            'message': '已经为你整理好待产包购物车。',
          },
          'cart_update': {
            'action': 'reset_cart',
            'groups': [
              {
                'title': '妈妈护理',
                'items': [
                  {'name': '产褥垫组合装'},
                ],
              },
            ],
          },
        },
      }),
    );
    await tester.pump();

    expect(cartUpdates, hasLength(1));
    expect(find.byKey(const ValueKey('agent-artifact-panel')), findsNothing);

    client.emit(
      0,
      AgentStreamEvent(const {
        'event_id': 'evt-pending-cart-text',
        'type': 'message.delta',
        'thread_id': 'thread-pending-cart',
        'run_id': 'run-pending-cart',
        'message_id': 'message-pending-cart',
        'sequence': 2,
        'payload': {'text': '我已经根据你的情况整理好了。'},
      }),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey('agent-artifact-panel')), findsOneWidget);
    expect(cartUpdates, hasLength(1));
  });

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
            artifactEvents: {'milk-plan-001': artifactEvent},
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('agent-artifact-panel')), findsNothing);
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
          pickImage: (_) async => const AgentStreamImageInput(
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

  testWidgets(
    'Agent Hub injects late profile defaults without replacing user edits',
    (tester) async {
      final profileCompleter = Completer<AgentHubGreetingProfile>();
      final formEvent = _formArtifactEvent(
        id: 'profile-default-form',
        form: {
          'id': 'birth_journey_basic_info_intake',
          'title': '孕周与基本情况',
          'fields': [
            {'id': 'age', 'label': '年龄', 'type': 'number', 'required': false},
            {'id': 'birth_hospital', 'label': '建档/生产医院', 'type': 'text'},
          ],
        },
      );

      await tester.pumpWidget(
        _host(
          AgentHubPage(
            greetingProfileLoader: () => profileCompleter.future,
            state: AgentStreamRunState(
              phase: AgentStreamRunPhase.finished,
              textContent: '请确认基本信息。',
              events: [formEvent],
            ),
          ),
        ),
      );
      await tester.pump();

      final inputs = find.byType(TextFormField);
      expect(inputs, findsNWidgets(2));
      await tester.enterText(inputs.at(1), '我手动填的医院');
      await tester.pump();

      profileCompleter.complete(
        const AgentHubGreetingProfile(
          displayName: '小美',
          age: 31,
          birthPrepDefaults: BirthPrepProfileDefaults(
            age: 31,
            birthHospital: '资料中的医院',
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final textFields = tester.widgetList<TextFormField>(inputs).toList();
      expect(
        textFields[0].controller?.text ?? textFields[0].initialValue,
        '31',
      );
      expect(
        textFields[1].controller?.text ?? textFields[1].initialValue,
        '我手动填的医院',
      );
    },
  );

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
    expect(player.stopCount, 2);
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

  testWidgets('Agent quick replies match legacy web chrome', (tester) async {
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
          'id': 'hospital_bag_intake',
          'title': '信息采集',
          'fields': [
            {
              'id': 'due_date_or_week',
              'label': '基本信息｜预产期或当前孕周',
              'type': 'text',
            },
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

    expect(find.text('信息采集'), findsOneWidget);
    expect(find.byKey(const ValueKey('agent-quick-replies')), findsNothing);
    expect(find.text('快捷一'), findsNothing);
  });

  testWidgets('Agent Hub renders quick replies as selectable legacy pills', (
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
          pickImage: (_) async => const AgentStreamImageInput(
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
    expect(
      find.byKey(const ValueKey('agent-image-attachment-0')),
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
    expect(find.byKey(const ValueKey('agent-sent-image-0')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('agent-sent-image-0')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('agent-sent-image-close')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('agent-sent-image-close')));
    await tester.pumpAndSettle();
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

    await tester.tap(find.byKey(const ValueKey('agent-image-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('agent-photo-camera-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('agent-image-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('agent-photo-upload-button')));
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

    expect(find.text('图片 1'), findsOneWidget);
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
          pickImage: (_) async => const AgentStreamImageInput(
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

  testWidgets('Agent Hub keeps denied microphone permission internal', (
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

    expect(find.byKey(const ValueKey('agent-voice-status')), findsNothing);
    expect(find.text('麦克风权限未开启'), findsNothing);
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

  testWidgets('Agent Hub starts voice capture on press and stops on release', (
    tester,
  ) async {
    final recorder = _PageFakeVoiceRecorder();
    final transcriber = _PageFakeVoiceTranscriber('按住期间录到的语音');
    await tester.pumpWidget(
      _host(
        AgentHubPage(
          voiceInputController: AgentVoiceInputController(
            recorder: recorder,
            transcriber: transcriber,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('agent-voice-button')));
    await tester.pump();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('agent-voice-hold-button'))),
    );
    await tester.pump();

    expect(recorder.calls, ['permissionState', 'start']);
    expect(transcriber.recordings, isEmpty);

    await gesture.up();
    await tester.pumpAndSettle();

    expect(recorder.calls, ['permissionState', 'start', 'stop']);
    expect(transcriber.recordings, hasLength(1));
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('agent-composer-input')))
          .controller
          ?.text,
      '按住期间录到的语音',
    );
  });

  testWidgets(
    'Agent Hub honors release while microphone permission is pending',
    (tester) async {
      final permission = Completer<AgentVoiceInputPermissionState>();
      final recorder = _PageFakeVoiceRecorder(
        initialPermission: AgentVoiceInputPermissionState.unknown,
        permissionRequest: permission.future,
      );
      final transcriber = _PageFakeVoiceTranscriber('权限后完成的语音');
      await tester.pumpWidget(
        _host(
          AgentHubPage(
            voiceInputController: AgentVoiceInputController(
              recorder: recorder,
              transcriber: transcriber,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('agent-voice-button')));
      await tester.pump();
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('agent-voice-hold-button'))),
      );
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(recorder.calls, ['permissionState', 'requestPermission']);
      permission.complete(AgentVoiceInputPermissionState.granted);
      await tester.pumpAndSettle();

      expect(recorder.calls, [
        'permissionState',
        'requestPermission',
        'start',
        'stop',
      ]);
      expect(transcriber.recordings, hasLength(1));
    },
  );

  testWidgets('Agent Hub cancels voice capture on pointer cancellation', (
    tester,
  ) async {
    final recorder = _PageFakeVoiceRecorder();
    final transcriber = _PageFakeVoiceTranscriber('must not be used');
    await tester.pumpWidget(
      _host(
        AgentHubPage(
          voiceInputController: AgentVoiceInputController(
            recorder: recorder,
            transcriber: transcriber,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('agent-voice-button')));
    await tester.pump();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('agent-voice-hold-button'))),
    );
    await tester.pump();
    await gesture.cancel();
    await tester.pumpAndSettle();

    expect(recorder.calls, ['permissionState', 'start', 'cancel']);
    expect(transcriber.recordings, isEmpty);
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
          'safe_output': {
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
            'safe_output': {
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
          'event_id': 'evt-standalone-media-voice-completed',
          'type': 'run.completed',
          'thread_id': 'thread-standalone-media-voice',
          'run_id': 'run-standalone-media-voice',
          'sequence': 2,
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
            'safe_output': {
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
        '帮我整理待产包',
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
              'title': '待产包清单',
              'content': '我已经帮你整理好了。',
              'button': [
                {
                  'label': '打开待产包购物车',
                  'action': 'navigate',
                  'value': '/hospital-bag-cart',
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
        '待产包清单 我已经帮你整理好了。',
      ]);
      expect(
        player.realtimeSessions.single.appendedTexts.single,
        isNot(contains('打开待产包购物车')),
      );
      expect(
        player.realtimeSessions.single.appendedTexts.single,
        isNot(contains('/hospital-bag-cart')),
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
        '待产包清单 我已经帮你整理好了。',
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
            'rich_text': {'title': '待产包清单', 'content': '我已经帮你整理好了。'},
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
        '帮我整理待产包',
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
      expect(find.byKey(const ValueKey('agent-quick-replies')), findsOneWidget);
      expect(find.text('继续聊这个'), findsOneWidget);
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
          pickImage: (_) async => const AgentStreamImageInput(
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

  testWidgets('Agent Hub restores historical artifacts from durable snapshot', (
    tester,
  ) async {
    final artifactEvent = _productionArtifactEvent(
      id: 'restored-history-preview',
      type: 'milk_plan_preview',
      payload: {
        'title': '历史奶量计划',
        'summary': '这张卡片来自上一次会话。',
        'direction': 'maintain',
        'tasks': [
          {'title': '20:00 泵奶'},
        ],
      },
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
      find.byKey(
        const ValueKey('agent-artifact-milk-preview-restored-history-preview'),
      ),
      findsOneWidget,
    );
    expect(find.text('20:00 泵奶'), findsOneWidget);
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
            artifactEvents: {'milk-plan-001': artifactEvent},
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
          'id': 'hospital_bag_intake',
          'title': '历史信息采集',
          'submit_label': '确认',
          'fields': [
            {
              'id': 'due_date_or_week',
              'label': '预产期或当前孕周',
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
            values: const {'due_date_or_week': '38 周'},
          ),
        },
      ),
    );

    await tester.pumpWidget(_host(AgentHubPage(interactionStateStore: store)));
    await tester.pumpAndSettle();

    expect(find.text('38 周'), findsOneWidget);
    expect(find.text('已提交'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('agent-artifact-form-submit-restored-form')),
    );
    expect(button.onPressed, isNull);
    final input = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const ValueKey('agent-artifact-form-restored-form')),
        matching: find.byType(TextField),
      ),
    );
    expect(input.readOnly, isTrue);
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
            artifactEvents: {'milk-plan-001': artifactEvent},
            actionEvents: {'action-indexed-001': actionEvent},
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('agent-artifact-panel')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('agent-artifact-card-milk-plan-001')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('agent-action-panel')), findsOneWidget);
    expect(find.text('确认索引动作'), findsOneWidget);
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
    expect(find.text('必带'), findsOneWidget);
    expect(find.text('产后恶露量较多，用来垫床或替代普通卫生巾。'), findsOneWidget);
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
    expect(find.text('必带'), findsOneWidget);
  });

  testWidgets(
    'Agent Hub renders normalized legacy specialized card semantics',
    (tester) async {
      final fixture = readFixtureMap(
        'agent_artifacts/legacy_specialized_cards.json',
      );
      final events = (fixture['events'] as List<Object?>)
          .whereType<Map>()
          .map((event) => AgentStreamEvent(Map<String, Object?>.from(event)))
          .toList(growable: false);

      await tester.pumpWidget(
        _host(
          AgentHubPage(
            state: AgentStreamRunState(
              phase: AgentStreamRunPhase.finished,
              textContent: '我整理好了。',
              events: events,
            ),
          ),
        ),
      );

      expect(find.text('分娩沟通单'), findsOneWidget);
      expect(find.text('希望医护先解释每一步'), findsOneWidget);
      expect(find.text('出生后尽早肌肤接触'), findsOneWidget);
      expect(
        find.text('这份沟通单只用于沟通。请优先遵循医生和医院建议，尤其是因安全原因需要调整计划时。'),
        findsOneWidget,
      );
      expect(find.text('待产包'), findsOneWidget);
      expect(find.text('证件文件包'), findsOneWidget);
      expect(find.text('妈妈住院包'), findsOneWidget);
      expect(find.text('产后回家第一周用品'), findsOneWidget);
      expect(find.text('身份证'), findsOneWidget);
      expect(find.text('身份证及复印件'), findsNothing);
      expect(find.text('原件+复印件'), findsOneWidget);

      await tester.ensureVisible(find.text('妈妈住院包'));
      await tester.pump();
      await tester.tap(find.text('妈妈住院包'));
      await tester.pump();

      expect(find.text('根据住院天数准备，产后更换会更方便。'), findsOneWidget);
      expect(find.text('你是第一胎加上希望母乳喂养，数量已按这个情况调整'), findsOneWidget);
    },
  );

  testWidgets('Agent Hub renders every current production artifact family', (
    tester,
  ) async {
    final actions = <AgentArtifactActionView>[];
    final consultStore = IbclcConsultStore.inMemory(
      now: () => DateTime.utc(2026, 7, 11),
    );
    final state = AgentStreamRunState(
      phase: AgentStreamRunPhase.finished,
      textContent: '我整理好了。',
      threadId: 'thread-current',
      runId: 'run-current',
      events: [
        _productionArtifactEvent(
          id: 'ibclc-current',
          type: 'ibclc_consult_card',
          payload: {
            'title': 'IBCLC 咨询入口',
            'consult_id': 'consult-current',
            'reason': '含乳疼痛',
            'feeding_context': '左侧喂养后持续疼痛。',
            'urgency': 'soon',
            'consultant': {
              'name': 'Lin Zhao',
              'credentials': 'IBCLC, RN',
              'experience': '12 年经验',
              'bio': 'IBCLC 国际认证哺乳顾问，擅长含乳支持。',
            },
            'chat': {'label': '开始咨询', 'note': '将同步本轮哺乳背景'},
          },
        ),
        _productionArtifactEvent(
          id: 'milk-preview-current',
          type: 'milk_plan_preview',
          payload: {
            'title': '三天泵奶计划',
            'summary': '将晚间泵奶提前，先观察三天。',
            'direction': 'maintain',
            'days': 3,
            'tasks': [
              {'title': '20:00 泵奶', 'detail': '保持舒适档位'},
            ],
            'reminders': [
              {'title': '及时补水'},
            ],
          },
        ),
        _productionArtifactEvent(
          id: 'cart-current',
          type: 'hospital_bag_cart',
          payload: {
            'cart_update': {
              'message': '已经更新待产包购物车。',
              'groups': [
                {
                  'title': '妈妈护理',
                  'items': [
                    {'name': '产褥垫组合装'},
                    {'name': '一次性内裤'},
                  ],
                },
              ],
              'totals': {'item_count': 2, 'total': 101.02},
            },
          },
        ),
      ],
    );

    await tester.pumpWidget(
      _host(
        AgentHubPage(
          state: state,
          ibclcConsultStore: consultStore,
          onArtifactAction: actions.add,
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('agent-artifact-ibclc-ibclc-current')),
      findsOneWidget,
    );
    expect(find.text('含乳疼痛'), findsOneWidget);
    expect(find.text('左侧喂养后持续疼痛。'), findsOneWidget);
    expect(find.text('建议尽快咨询'), findsOneWidget);
    expect(find.text('Lin Zhao'), findsOneWidget);
    expect(find.text('IBCLC, RN'), findsOneWidget);
    expect(find.text('12 年经验'), findsOneWidget);
    expect(find.text('擅长含乳支持。'), findsOneWidget);
    expect(find.textContaining('隐私政策'), findsOneWidget);

    expect(
      find.byKey(
        const ValueKey('agent-artifact-milk-preview-milk-preview-current'),
      ),
      findsOneWidget,
    );
    expect(find.text('将晚间泵奶提前，先观察三天。'), findsOneWidget);
    expect(find.text('维持当前节奏'), findsOneWidget);
    expect(find.textContaining('20:00 泵奶'), findsOneWidget);
    expect(find.text('及时补水'), findsOneWidget);

    expect(
      find.byKey(const ValueKey('agent-artifact-cart-cart-current')),
      findsOneWidget,
    );
    expect(find.text('已经更新待产包购物车。'), findsOneWidget);
    expect(find.text('妈妈护理'), findsOneWidget);
    expect(find.text('产褥垫组合装'), findsOneWidget);
    expect(find.text('共 2 件'), findsOneWidget);

    final agreementFinder = find.byKey(
      const ValueKey('agent-ibclc-agreement-ibclc-current'),
    );
    await tester.scrollUntilVisible(
      agreementFinder,
      -240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(agreementFinder);
    await tester.pump();
    final consultFinder = find.byKey(
      const ValueKey('agent-ibclc-open-ibclc-current'),
    );
    await tester.tap(consultFinder);
    await tester.pump();

    expect(actions.single.routePath, '/ibclc-chat.html');
    final routeState = actions.single.routeExtra as IbclcConsultRouteState;
    expect(routeState.consultId, 'consult-current');
    expect(routeState.sourceArtifactId, 'ibclc-current');
    expect(routeState.threadId, 'thread-current');
    expect(routeState.runId, 'run-current');
    expect(routeState.returnPath, '/');
    expect(routeState.reason, '含乳疼痛');
    expect(routeState.feedingContext, '左侧喂养后持续疼痛。');

    await consultStore.markCompleted(routeState);
    await tester.pump();

    expect(find.text('咨询结束'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('agent-ibclc-agreement-ibclc-current')),
      findsNothing,
    );
  });

  testWidgets('Agent Hub restores the IBCLC return scroll offset', (
    tester,
  ) async {
    final consultStore = IbclcConsultStore.inMemory(
      now: () => DateTime.utc(2026, 7, 11),
    );
    final history = List<AgentHubHistoryMessage>.generate(
      32,
      (index) => AgentHubHistoryMessage(
        role: index.isEven
            ? AgentHubHistoryRole.user
            : AgentHubHistoryRole.assistant,
        content: '第 $index 条历史消息，用于验证咨询返回后的滚动锚点。',
      ),
    );

    await tester.pumpWidget(
      _host(
        AgentHubPage(historyMessages: history, ibclcConsultStore: consultStore),
      ),
    );
    await tester.pump();

    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    final position = scrollable.position;
    expect(position.maxScrollExtent, greaterThan(240));
    position.jumpTo(240);
    await tester.pump();
    const routeState = IbclcConsultRouteState(
      consultId: 'consult-scroll',
      sourceArtifactId: 'artifact-scroll',
      returnPath: '/',
      returnScrollOffset: 240,
    );
    consultStore.beginConsult(routeState);
    position.jumpTo(0);

    await consultStore.markCompleted(routeState);
    await tester.pump();
    await tester.pump();

    expect(position.pixels, closeTo(240, 0.1));
  });

  testWidgets('Agent Hub keeps the historical IBCLC run context', (
    tester,
  ) async {
    final actions = <AgentArtifactActionView>[];
    final historicalState = AgentStreamRunState(
      phase: AgentStreamRunPhase.finished,
      textContent: '可以开始咨询。',
      threadId: 'thread-history',
      runId: 'run-history',
      events: [
        _productionArtifactEvent(
          id: 'ibclc-history',
          type: 'ibclc_consult_card',
          payload: {
            'title': 'IBCLC 咨询入口',
            'consult_id': 'consult-history',
            'reason': '含乳疼痛',
          },
        ),
      ],
    );

    await tester.pumpWidget(
      _host(
        AgentHubPage(
          state: const AgentStreamRunState(
            phase: AgentStreamRunPhase.idle,
            threadId: 'thread-current',
            runId: 'run-current',
          ),
          historyMessages: [
            AgentHubHistoryMessage(
              role: AgentHubHistoryRole.assistant,
              content: '可以开始咨询。',
              runState: historicalState,
            ),
          ],
          ibclcConsultStore: IbclcConsultStore.inMemory(),
          onArtifactAction: actions.add,
        ),
      ),
    );
    await tester.pump();

    final agreement = find.byKey(
      const ValueKey('agent-ibclc-agreement-ibclc-history'),
    );
    await tester.ensureVisible(agreement);
    await tester.tap(agreement);
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('agent-ibclc-open-ibclc-history')),
    );
    await tester.pump();

    final routeState = actions.single.routeExtra as IbclcConsultRouteState;
    expect(routeState.consultId, 'consult-history');
    expect(routeState.threadId, 'thread-history');
    expect(routeState.runId, 'run-history');
  });

  testWidgets('Agent Hub keeps long journey and packing sections collapsible', (
    tester,
  ) async {
    final state = AgentStreamRunState(
      phase: AgentStreamRunPhase.finished,
      textContent: '计划已经整理好。',
      events: [
        AgentStreamEvent({
          'type': 'artifact.created',
          'artifact_id': 'journey-collapse',
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
                        {'title': '完成糖耐检查'},
                      ],
                    },
                    {
                      'title': '下一阶段',
                      'items': [
                        {'title': '整理待产包'},
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
          'artifact_id': 'bag-collapse',
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
                      {'label': '产褥垫'},
                    ],
                  },
                  {
                    'title': '宝宝用品',
                    'items': [
                      {'label': '婴儿连体衣'},
                    ],
                  },
                ],
              },
            },
          },
        }),
      ],
    );

    await tester.pumpWidget(_host(AgentHubPage(state: state)));

    expect(find.text('完成糖耐检查'), findsOneWidget);
    expect(find.text('整理待产包'), findsNothing);
    await tester.tap(find.text('下一阶段'));
    await tester.pump();
    expect(find.text('整理待产包'), findsOneWidget);

    expect(find.text('产褥垫'), findsOneWidget);
    expect(find.text('婴儿连体衣'), findsNothing);
    final babyGroupFinder = find.text('宝宝出院包');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -240));
    await tester.pumpAndSettle();
    await tester.tap(babyGroupFinder);
    await tester.pump();
    expect(find.text('婴儿连体衣'), findsOneWidget);
  });

  testWidgets('Agent Hub activates cart context from a final reply link', (
    tester,
  ) async {
    var activationCount = 0;

    await tester.pumpWidget(
      _host(
        AgentHubPage(
          state: const AgentStreamRunState(
            phase: AgentStreamRunPhase.finished,
            textContent: '已经整理好了。\n\n**[打开待产包购物车](/hospital-bag-cart)**',
          ),
          onHospitalBagCartContextRequired: () => activationCount += 1,
        ),
      ),
    );

    expect(activationCount, 1);
    await tester.pump();
    expect(activationCount, 1);
  });

  testWidgets(
    'Agent Hub confirms support ticket details without claiming ticket creation',
    (tester) async {
      final client = _ControllableAgentStreamClient();
      addTearDown(client.dispose);
      final ticketEvent = AgentStreamEvent({
        'type': 'artifact.created',
        'artifact_id': 'support-ticket-1',
        'artifact_type': 'support_ticket_draft',
        'submit_label': '确认并提交',
        'ticket': {
          'issue_type': 'malfunction',
          'issue_summary': '吸奶器无法启动',
          'product_model': 'Air1',
          'order_number': 'MC123',
          'purchase_channel': '官网',
          'urgency': 'normal',
        },
      });

      await tester.pumpWidget(
        _host(
          AgentHubPage(
            runner: AgentStreamRunner(client),
            state: AgentStreamRunState(
              phase: AgentStreamRunPhase.finished,
              textContent: '请确认售后信息。',
              events: [ticketEvent],
            ),
          ),
        ),
      );

      expect(find.text('售后工单'), findsOneWidget);
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
      await tester.pump();
      client.emit(
        0,
        AgentStreamEvent(const {
          'event_id': 'support-ticket-run-queued',
          'type': 'run.queued',
          'thread_id': 'thread-support-ticket',
          'run_id': 'run-support-ticket',
          'sequence': 1,
        }),
      );
      await tester.pump();

      expect(client.requests, hasLength(1));
      expect(client.requests.single.message, startsWith('我已确认售后信息'));
      expect(client.requests.single.message, contains('发起正式工单创建动作'));
      expect(
        client.requests.single.message,
        isNot(contains('confirmed_form_data')),
      );
      final submission =
          client.requests.single.metadata['form_submission']!
              as Map<String, Object?>;
      expect(submission['artifact_id'], 'support-ticket-1');
      expect(submission['form_id'], 'support_ticket');
      expect(
        (submission['values']! as Map<String, Object?>)['issue_summary'],
        '吸奶器无法启动',
      );
      expect(
        client.requests.single.idempotencyKey,
        startsWith('agent-form-submit-'),
      );
      expect(find.text('已确认售后信息'), findsOneWidget);
      expect(find.text('信息已确认'), findsOneWidget);
      expect(find.text('已提交售后工单'), findsNothing);
      expect(find.textContaining('人工客服团队会在 24 小时内'), findsNothing);
    },
  );

  testWidgets('Agent Hub renders legacy service artifact envelopes', (
    tester,
  ) async {
    final actions = <AgentArtifactActionView>[];
    final cartUpdates = <HospitalBagCartArtifactSeed>[];
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
          onHospitalBagCartUpdate: cartUpdates.add,
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
    expect(find.text('必填'), findsNothing);
    expect(find.text('*'), findsWidgets);
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    expect(find.text('孕期计划'), findsOneWidget);
    expect(find.text('当前阶段'), findsOneWidget);
    expect(find.text('2 个事项'), findsOneWidget);
    expect(find.text('整理下次产检要问的问题'), findsOneWidget);
    expect(find.text('开始整理待产包'), findsOneWidget);
    expect(find.text('已经帮你把待产包购物车恢复到默认清单了。'), findsWidgets);
    expect(find.text('妈妈护理'), findsOneWidget);
    expect(find.text('产褥垫组合装'), findsOneWidget);
    expect(find.text('一次性内裤'), findsOneWidget);
    expect(find.text('共 2 件'), findsOneWidget);
    expect(find.text('合计 101.02'), findsOneWidget);
    expect(find.text('打开购物车'), findsOneWidget);
    expect(cartUpdates, hasLength(1));
    expect(cartUpdates.single.snapshot.groups.single.items, hasLength(2));

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
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('顺产').last);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        const ValueKey('agent-artifact-form-submit-hospital-bag-form'),
      ),
    );
    await tester.pump();

    expect(client.requests, hasLength(1));
    expect(
      client.requests.single.message,
      isNot(contains('confirmed_form_data')),
    );
    expect(client.requests.single.message, isNot(contains('due_date_or_week')));
    expect(client.requests.single.metadata['form_submission'], {
      'artifact_id': 'hospital-bag-form',
      'form_id': 'hospital_bag_intake',
      'values': {'due_date_or_week': '38 周', 'birth_path': '顺产'},
    });
    expect(
      client.requests.single.idempotencyKey,
      startsWith('agent-form-submit-'),
    );
    client.emit(
      0,
      AgentStreamEvent(const {
        'event_id': 'hospital-bag-form-run-queued',
        'type': 'run.queued',
        'thread_id': 'thread-legacy-artifact',
        'run_id': 'run-hospital-bag-form',
        'sequence': 1,
      }),
    );
    await _pumpFrames(tester, 3);
    await tester.scrollUntilVisible(
      find.text('已提交信息采集表单'),
      -220,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('已提交信息采集表单'), findsOneWidget);
    expect(find.text('38 周'), findsOneWidget);
    expect(find.text('已提交'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(
              const ValueKey('agent-artifact-form-submit-hospital-bag-form'),
            ),
          )
          .onPressed,
      isNull,
    );
    expect(client.requests, hasLength(1));

    final cartActionFinder = find.byKey(
      const ValueKey('agent-artifact-cart-open-hospital-bag-cart'),
    );
    await tester.scrollUntilVisible(
      cartActionFinder,
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    await tester.tap(cartActionFinder);
    await tester.pump();

    expect(actions.single.routePath, '/hospital-bag-cart');
    expect(actions.single.routeExtra, isNull);
    expect(actions.single.hospitalBagCartSeed, isNotNull);
    expect(
      actions.single.hospitalBagCartSeed!.snapshot.groups.single.items,
      hasLength(2),
    );
  });

  testWidgets(
    'Agent Hub keeps pregnancy plan form analysis and proposal in one trusted multi-turn flow',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final client = _ControllableAgentStreamClient();
      addTearDown(client.dispose);
      final formEvent = AgentStreamEvent({
        'type': 'artifact.created',
        'thread_id': 'thread-pregnancy-flow',
        'run_id': 'run-pregnancy-form',
        'artifact_id': 'pregnancy-intake-form',
        'payload': {
          'artifact_type': 'form',
          'form': {
            'id': 'birth_journey_basic_info_intake',
            'title': '孕周与基本情况',
            'description': '先填写几项基础信息，后面我会按你的情况整理孕期计划。',
            'fields': [
              {
                'id': 'current_week',
                'label': '当前孕周或预产期',
                'type': 'text',
                'required': true,
                'default_value': '32周',
              },
              {
                'id': 'ivf',
                'label': '是否 IVF（体外受精）',
                'type': 'select',
                'required': true,
                'options': ['是', '否', '不确定/暂不说'],
                'default_value': '是',
              },
              {
                'id': 'fetus_count',
                'label': '单胎/双胎',
                'type': 'select',
                'required': true,
                'options': ['单胎', '双胎', '多胎', '不确定/暂不说'],
                'default_value': '双胎',
              },
              {
                'id': 'age',
                'label': '年龄',
                'type': 'number',
                'required': true,
                'default_value': 36,
              },
              {
                'id': 'first_birth',
                'label': '是否第一胎',
                'type': 'select',
                'required': true,
                'options': ['是', '否', '不确定/暂不说'],
                'default_value': '是',
              },
              {
                'id': 'birth_path',
                'label': '计划分娩方式',
                'type': 'select',
                'required': true,
                'options': ['顺产', '剖宫产', '还没确定'],
                'default_value': '顺产',
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
              textContent: '请先完成孕周与基本情况表单。',
              threadId: 'thread-pregnancy-flow',
              runId: 'run-pregnancy-form',
              events: [formEvent],
            ),
          ),
        ),
      );
      await tester.pump();

      final submit = find.byKey(
        const ValueKey('agent-artifact-form-submit-pregnancy-intake-form'),
      );
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pump();

      expect(client.requests, hasLength(1));
      final firstRequest = client.requests.single;
      expect(firstRequest.threadId, 'thread-pregnancy-flow');
      expect(firstRequest.message, isNot(contains('32周')));
      expect(firstRequest.message, isNot(contains('confirmed_form_data')));
      expect(firstRequest.metadata['form_submission'], {
        'artifact_id': 'pregnancy-intake-form',
        'form_id': 'birth_journey_basic_info_intake',
        'values': {
          'current_week': '32周',
          'ivf': '是',
          'fetus_count': '双胎',
          'age': 36,
          'first_birth': '是',
          'birth_path': '顺产',
        },
      });

      client.emit(
        0,
        AgentStreamEvent(const {
          'event_id': 'pregnancy-analysis-queued',
          'type': 'run.queued',
          'thread_id': 'thread-pregnancy-flow',
          'run_id': 'run-pregnancy-analysis',
          'sequence': 1,
        }),
      );
      client.emit(
        0,
        AgentStreamEvent(const {
          'event_id': 'pregnancy-analysis-message',
          'type': 'message.completed',
          'thread_id': 'thread-pregnancy-flow',
          'run_id': 'run-pregnancy-analysis',
          'message_id': 'message-pregnancy-analysis',
          'sequence': 2,
          'payload': {
            'role': 'assistant',
            'text':
                '双胎和 IVF 会影响复查节奏，我会把胎儿生长观察、孕周口径和入院准备适当前置。还有其他需要补充的信息吗？如果没有，我就基于目前的信息开始为你制定孕期计划啦。',
            'quick_replies': [
              {'text': '没有了，开始制定'},
              {'text': '我想补充一点'},
              {'text': '稍等我再看看'},
            ],
          },
        }),
      );
      client.emit(
        0,
        AgentStreamEvent(const {
          'event_id': 'pregnancy-analysis-completed',
          'type': 'run.completed',
          'thread_id': 'thread-pregnancy-flow',
          'run_id': 'run-pregnancy-analysis',
          'sequence': 3,
        }),
      );
      await _pumpFrames(tester, 4);

      expect(find.textContaining('双胎和 IVF 会影响复查节奏'), findsOneWidget);
      expect(find.text('已提交'), findsOneWidget);
      expect(find.byKey(const ValueKey('agent-quick-replies')), findsOneWidget);
      final noMore = find.byKey(const ValueKey('agent-quick-reply-0'));
      await tester.scrollUntilVisible(
        noMore,
        -220,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(noMore);
      await tester.pump();

      expect(client.requests, hasLength(2));
      expect(client.requests.last.message, '没有了，开始制定');
      expect(client.requests.last.threadId, 'thread-pregnancy-flow');

      const pregnancyActionId = 'action-pregnancy-plan';
      client.emit(
        1,
        AgentStreamEvent(const {
          'event_id': 'pregnancy-plan-action',
          'type': 'action.confirmation_required',
          'thread_id': 'thread-pregnancy-flow',
          'run_id': 'run-pregnancy-plan',
          'sequence': 1,
          'action_id': pregnancyActionId,
          'payload': {
            'action_type': 'pregnancy.plan.create',
            'action_status': 'confirmation_required',
            'target_type': 'plan',
            'side_effect_level': 'medium',
            'preview_payload': {'title': '孕期计划', 'summary': '从现在到生产前后的阶段计划与待办'},
          },
        }),
      );
      client.emit(
        1,
        AgentStreamEvent({
          'event_id': 'pregnancy-plan-artifact',
          'type': 'artifact.created',
          'thread_id': 'thread-pregnancy-flow',
          'run_id': 'run-pregnancy-plan',
          'sequence': 2,
          'artifact_id': 'pregnancy-plan-card',
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
                      'title': '当前阶段｜孕 32 周起',
                      'items': [
                        {
                          'title': '和产科确认个性化复查节奏',
                          'steps': ['确认孕周口径', '安排胎儿生长复查'],
                        },
                      ],
                    },
                  ],
                },
              },
            },
          },
        }),
      );
      client.emit(
        1,
        AgentStreamEvent(const {
          'event_id': 'pregnancy-plan-waiting',
          'type': 'run.waiting_for_confirmation',
          'thread_id': 'thread-pregnancy-flow',
          'run_id': 'run-pregnancy-plan',
          'sequence': 3,
          'payload': {'pending_action_id': pregnancyActionId},
        }),
      );
      await _pumpFrames(tester, 4);

      expect(find.text('孕期计划'), findsWidgets);
      expect(find.text('当前阶段｜孕 32 周起'), findsOneWidget);
      expect(find.text('和产科确认个性化复查节奏'), findsOneWidget);
      expect(find.text('确认孕周口径'), findsOneWidget);
      expect(find.byKey(const ValueKey('agent-action-panel')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('agent-action-card-$pregnancyActionId')),
        findsOneWidget,
      );
      expect(find.text('等待确认后继续'), findsOneWidget);
    },
  );

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
      expect(find.text('结果卡片'), findsNothing);
      final otherFinder = find.byKey(
        const ValueKey(
          'agent-artifact-form-other-form-alignment-pregnancy_history',
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
      expect(find.text('请填写：孕产史的其它内容'), findsOneWidget);

      await tester.enterText(otherFinder, '第一胎剖宫产');
      await tester.pump();
      await tester.ensureVisible(submitFinder);
      await tester.pump();
      await tester.tap(submitFinder);
      await tester.pump();

      expect(actions, hasLength(1));
      expect(actions.single.value, contains('"due_date_or_week":"38 周"'));
      expect(
        actions.single.value,
        contains('"pregnancy_history":["其它：第一胎剖宫产"]'),
      );
      expect(find.text('已提交'), findsOneWidget);

      await tester.tap(submitFinder);
      await tester.pump();

      expect(actions, hasLength(1));
    },
  );

  testWidgets(
    'Agent artifact form stays editable when submission is rejected',
    (tester) async {
      var attempts = 0;
      const card = AgentArtifactCardView(
        id: 'retryable-form',
        title: '信息采集',
        formId: 'hospital_bag_intake',
        presentationKind: AgentArtifactPresentationKind.form,
        formFields: [
          AgentArtifactFormFieldView(
            id: 'due_date_or_week',
            label: '基本信息｜预产期或当前孕周',
            type: 'text',
            required: true,
            defaultValue: '38 周',
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

      final submitFinder = find.byKey(
        const ValueKey('agent-artifact-form-submit-retryable-form'),
      );
      expect(tester.getSize(submitFinder).width, greaterThan(300));

      await tester.tap(submitFinder);
      await tester.pumpAndSettle();

      expect(attempts, 1);
      expect(find.text('提交失败，请重试'), findsOneWidget);
      expect(find.text('已提交'), findsNothing);

      await tester.tap(submitFinder);
      await tester.pumpAndSettle();

      expect(attempts, 2);
      expect(find.text('已提交'), findsOneWidget);
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
          'id': 'hospital_bag_intake',
          'title': '信息采集',
          'fields': [
            {
              'id': 'due_date_or_week',
              'label': '预产期或当前孕周',
              'type': 'text',
              'required': true,
              'default': '38 周',
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
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.byType(Checkbox), findsNWidgets(3));

    await tester.tap(find.text('奶瓶'));
    await tester.pump();
    await tester.tap(find.text('尿布'));
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
      'packing_items': ['奶瓶', '尿布'],
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

  testWidgets('Agent Hub renders web search citations like legacy web', (
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

[打开状态页](/status?day=today)

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

    await tester.tap(find.text('打开状态页', findRichText: true));
    await tester.pump();
    expect(actions.last.routePath, '/status');
    expect(actions.last.value, '/status?day=today');
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

  testWidgets('Agent Hub aligns context-ready fallback with legacy web copy', (
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
            'semantic': {
              'label': '我在组织回复～',
              'surface': 'status_bar',
              'visibility': 'status',
            },
          },
        }),
      ],
    );

    await tester.pumpWidget(_host(AgentHubPage(state: state)));

    expect(find.text('我在组织回复～'), findsOneWidget);
    expect(find.text('正在处理请求。'), findsNothing);
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
            'semantic': {
              'label': '我想一下',
              'surface': 'thinking_note',
              'visibility': 'hidden',
            },
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
    final state = AgentStreamRunState(
      phase: AgentStreamRunPhase.streaming,
      events: [
        AgentStreamEvent({
          'type': 'tool.started',
          'payload': {
            'tool_call_id': 'tool-milk-status',
            'tool_name': 'records.milk_status.read',
            'label': '奶量状态',
            'semantic': {
              'label': '我先看看今天的奶量状态～',
              'surface': 'status_bar',
              'lifecycle': 'running',
            },
          },
        }),
      ],
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
                    'tool_name': 'pump_session_summary_query',
                  },
                }),
                AgentStreamEvent({
                  'type': 'artifact.created',
                  'payload': {
                    'artifact_id': 'artifact-plan-001',
                    'artifact_type': 'milk_plan_card',
                  },
                }),
              ],
            ),
          ),
        ),
      );

      expect(find.text('我接着处理下一步'), findsNothing);
      expect(find.text('正在读取泵奶记录'), findsNothing);
      expect(find.text('泵奶记录已读取'), findsNothing);
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

  testWidgets('Agent Hub renders after-tool reasoning as thinking note', (
    tester,
  ) async {
    final state = AgentStreamRunState(
      phase: AgentStreamRunPhase.streaming,
      events: [
        AgentStreamEvent({'type': 'run.started'}),
        AgentStreamEvent({
          'type': 'run.progress',
          'payload': {
            'phase': 'model_reasoning_after_tool',
            'label': '我接着处理下一步',
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
        matching: find.text('我接着处理下一步'),
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

AgentStreamEvent _formArtifactEvent({
  required String id,
  required Map<String, Object?> form,
}) {
  return AgentStreamEvent({
    'type': 'artifact.created',
    'artifact_id': id,
    'payload': {'artifact_type': 'form', 'form': form},
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

bool _composerHasFocus(WidgetTester tester) {
  return tester
      .widget<EditableText>(find.byType(EditableText))
      .focusNode
      .hasFocus;
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
    this.permissionRequest,
  });

  final AgentVoiceInputPermissionState initialPermission;
  final AgentVoiceInputPermissionState requestResult;
  final Future<AgentVoiceInputPermissionState>? permissionRequest;
  final List<String> calls = [];

  @override
  Future<AgentVoiceInputPermissionState> permissionState() async {
    calls.add('permissionState');
    return initialPermission;
  }

  @override
  Future<AgentVoiceInputPermissionState> requestPermission() async {
    calls.add('requestPermission');
    return await permissionRequest ?? requestResult;
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
  _PageFakeVoiceTranscriber(this.text);

  final String? text;
  final List<AgentVoiceRecording> recordings = <AgentVoiceRecording>[];

  @override
  Future<String?> transcribe(AgentVoiceRecording recording) async {
    recordings.add(recording);
    return text;
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
