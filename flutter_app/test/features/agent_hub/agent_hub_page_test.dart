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

import '../../support/fixture_reader.dart';

void main() {
  testWidgets('Agent Hub renders idle composer state', (tester) async {
    await tester.pumpWidget(_host(const AgentHubPage()));

    expect(find.byKey(const ValueKey('agent-hub-page')), findsOneWidget);
    expect(find.byKey(const ValueKey('agent-run-phase-badge')), findsOneWidget);
    expect(find.text('准备就绪'), findsOneWidget);
    expect(find.text('我在。'), findsOneWidget);
    expect(find.byKey(const ValueKey('agent-composer-input')), findsOneWidget);
    expect(find.byKey(const ValueKey('agent-image-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('agent-voice-button')), findsOneWidget);

    final sendButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('agent-send-button')),
    );
    final imageButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('agent-image-button')),
    );
    final voiceButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('agent-voice-button')),
    );
    expect(sendButton.onPressed, isNull);
    expect(imageButton.onPressed, isNull);
    expect(voiceButton.onPressed, isNull);
  });

  testWidgets('Agent Hub sends composer text through the injected runner', (
    tester,
  ) async {
    final client = _FixtureAgentStreamClient(
      parseAgentJsonl(readMigrationFixture('ag_ui/text_stream_basic.jsonl')),
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
    expect(client.requests.single.threadId, 'thread-demo');
    expect(find.text('已完成'), findsOneWidget);
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

  testWidgets('Agent Hub attaches image input to the next request', (
    tester,
  ) async {
    final client = _FixtureAgentStreamClient(
      parseAgentJsonl(readMigrationFixture('ag_ui/text_stream_basic.jsonl')),
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

  testWidgets('Agent Hub voice input fills composer without sending', (
    tester,
  ) async {
    final client = _FixtureAgentStreamClient(
      parseAgentJsonl(readMigrationFixture('ag_ui/text_stream_basic.jsonl')),
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

    expect(find.text('正在回复'), findsOneWidget);
    expect(find.text('Partial answer'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('agent-stop-button')));
    await tester.pump();

    expect(find.text('已停止'), findsOneWidget);
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
              uri: Uri.parse('http://127.0.0.1:8769/api/ag-ui-cancel'),
            ),
            connector: cancelConnector,
          ),
        ),
      ),
    );

    expect(find.text('正在回复'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('agent-stop-button')));
    await tester.pump();
    await cancelConnector.called.future;

    final body = jsonDecode(cancelConnector.body!) as Map<String, Object?>;
    expect(find.text('已停止'), findsOneWidget);
    expect(cancelConnector.uri!.path, '/api/ag-ui-cancel');
    expect(body['threadId'], 'thread-demo');
    expect(body['runId'], 'run-demo');
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

    expect(find.text('连接中断'), findsOneWidget);
    expect(find.textContaining('socket closed'), findsOneWidget);
    expect(find.byKey(const ValueKey('agent-retry-button')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('agent-retry-button')));
    await tester.pumpAndSettle();

    expect(client.requests, hasLength(2));
    expect(client.requests.first.message, 'Retry my request');
    expect(client.requests.last.message, 'Retry my request');
    expect(find.text('已完成'), findsOneWidget);
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

    expect(find.text('连接中断'), findsOneWidget);
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

    expect(find.text('连接中断'), findsOneWidget);
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
          readMigrationFixture('ag_ui/tool_call_lifecycle.jsonl'),
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
      expect(find.text('已生成分析卡片'), findsOneWidget);
      expect(find.text('需要确认后继续'), findsOneWidget);
      expect(
        find.text('I found two sessions today and prepared a draft analysis.'),
        findsOneWidget,
      );
      expect(find.textContaining('pump_session_summary_query'), findsNothing);
      expect(find.textContaining('{"ok"'), findsNothing);
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
                'type': 'TOOL_CALL_START',
                'thread_id': 'thread-tool-fail',
                'run_id': 'run-tool-fail',
                'tool_call_id': 'call_growth_fail',
                'tool_call_name': 'growth_record_query',
              }),
              AgentStreamEvent(const {
                'type': 'TOOL_CALL_FAILED',
                'thread_id': 'thread-tool-fail',
                'run_id': 'run-tool-fail',
                'tool_call_id': 'call_growth_fail',
                'tool_call_name': 'growth_record_query',
                'message': 'database timeout for child profile',
                'content': '{"childId":"baby-secret","error":"timeout"}',
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
      readFixtureMap('ag_ui/rich_text_artifact.json'),
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
    expect(find.text('Review flange comfort'), findsOneWidget);
    expect(find.text('Track two more pumping sessions'), findsOneWidget);
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
      'type': 'ARTIFACT_CREATED',
      'thread_id': 'thread-resource',
      'run_id': 'run-resource',
      'message_id': 'msg-resource',
      'artifact_id': 'resource-card',
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

    expect(find.text('连接中断'), findsOneWidget);
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

      expect(find.text('正在回复'), findsOneWidget);
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

      expect(find.text('已完成'), findsOneWidget);
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
        'type': 'TEXT_MESSAGE_CONTENT',
        'thread_id': 'thread-demo',
        'run_id': 'run-first',
        'message_id': 'msg-first',
        'delta': 'Partial answer',
      });
      throw StateError('socket closed');
    }

    yield AgentStreamEvent(const {
      'type': 'TEXT_MESSAGE_CONTENT',
      'thread_id': 'thread-demo',
      'run_id': 'run-retry',
      'message_id': 'msg-retry',
      'delta': 'Retried answer',
    });
    yield AgentStreamEvent(const {
      'type': 'RUN_FINISHED',
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
