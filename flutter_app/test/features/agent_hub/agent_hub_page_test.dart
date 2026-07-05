import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_client.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_event.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_io_transport.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_run_state.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_runner.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_page.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_voice.dart';

import '../../support/fixture_reader.dart';

void main() {
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
    await tester.pumpAndSettle();

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
    await tester.pumpAndSettle();

    expect(client.requests.single.message, 'Send text only');
    expect(client.requests.single.images, isEmpty);
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

    expect(find.byKey(const ValueKey('agent-voice-status')), findsOneWidget);

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

    expect(coordinator.activeSource, AgentVoicePlaybackSource.autoReply);
    expect(coordinator.activeId, 'msg-reply-text-001');
    expect(find.text('正在播放语音'), findsOneWidget);
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

    expect(find.text('正在生成回复'), findsOneWidget);
    expect(find.text('Partial answer'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('agent-stop-button')));
    await tester.pump();

    expect(find.text('已停止本次回复'), findsOneWidget);
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

    expect(find.text('正在生成回复'), findsOneWidget);

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

  testWidgets(
    'Agent Hub renders user-facing tool progress from stream events',
    (tester) async {
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

      expect(find.byKey(const ValueKey('agent-work-panel')), findsOneWidget);
      expect(find.text('泵奶记录已读取'), findsOneWidget);
      expect(find.text('已生成分析卡片'), findsWidgets);
      expect(find.text('需要确认后继续'), findsOneWidget);
      expect(
        find.text('I found two sessions today and prepared a draft analysis.'),
        findsOneWidget,
      );
      expect(find.textContaining('pump_session_summary_query'), findsNothing);
      expect(find.textContaining('{"ok"'), findsNothing);
    },
  );

  testWidgets('Agent Hub renders and confirms production action cards', (
    tester,
  ) async {
    const actionId = '11111111-1111-1111-1111-111111111111';
    final connector = _RecordingActionConnector();
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
          actionClient: actionClient,
        ),
      ),
    );

    expect(find.text('待确认'), findsWidgets);
    expect(find.text('等待确认后继续'), findsOneWidget);
    expect(find.byKey(const ValueKey('agent-action-panel')), findsOneWidget);
    expect(find.byKey(ValueKey('agent-action-card-$actionId')), findsOneWidget);
    expect(find.text('创建支持工单'), findsOneWidget);
    expect(find.text('将当前问题提交给人工支持团队'), findsOneWidget);

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
    expect(find.text('已确认'), findsOneWidget);
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

    expect(find.byKey(const ValueKey('agent-work-panel')), findsOneWidget);
    expect(find.text('成长记录暂时无法读取'), findsOneWidget);
    expect(find.text('失败'), findsOneWidget);
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

    await tester.tap(
      find.byKey(const ValueKey('agent-artifact-action-resource-card-1')),
    );
    await tester.pump();

    expect(actions.last.kind, 'media');
    expect(actions.last.value, '/media/a.png');
    expect(actions.last.routePath, '/media-viewer');
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

      expect(find.text('正在生成回复'), findsOneWidget);

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
      expect(find.text('正在生成回复'), findsNothing);
    },
  );
}

Widget _host(Widget child) {
  return MaterialApp(
    theme: momCozyTheme(),
    debugShowCheckedModeBanner: false,
    home: Scaffold(body: SafeArea(child: child)),
  );
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

class _RetryAgentStreamClient implements AgentStreamClient {
  final requests = <AgentStreamRequest>[];

  @override
  Stream<AgentStreamEvent> stream(AgentStreamRequest request) async* {
    requests.add(request);
    await Future<void>.delayed(Duration.zero);

    if (requests.length == 1) {
      yield AgentStreamEvent(const {
        'type': 'message.delta',
        'thread_id': 'thread-demo',
        'run_id': 'run-first',
        'message_id': 'msg-first',
        'payload': {'text': 'Partial answer'},
      });
      throw StateError('socket closed');
    }

    yield AgentStreamEvent(const {
      'type': 'message.delta',
      'thread_id': 'thread-demo',
      'run_id': 'run-retry',
      'message_id': 'msg-retry',
      'payload': {'text': 'Retried answer'},
    });
    yield AgentStreamEvent(const {
      'type': 'run.completed',
      'thread_id': 'thread-demo',
      'run_id': 'run-retry',
      'message_id': 'msg-retry',
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
