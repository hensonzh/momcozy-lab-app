import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_client.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_event.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_io_transport.dart';
import 'package:momcozy_flutter_app/core/network/api_envelope.dart';
import 'package:momcozy_flutter_app/core/privacy/log_redactor.dart';

import '../../support/fixture_reader.dart';

void main() {
  group('Agent stream IO transports', () {
    test(
      'SSE transport posts AG-UI payload with shared auth injection',
      () async {
        final connector = _RecordingSseConnector([
          readMigrationFixture('ag_ui/text_stream_basic.eventstream'),
        ]);
        final endpoint = AgentStreamEndpoint(
          uri: Uri.parse('http://127.0.0.1:8768/api/ag-ui?existing=1'),
          token: 'secret-token',
          headers: {'X-Client': 'flutter'},
        );
        final client = SseAgentStreamClient(
          AgentSseHttpTransport(
            endpoint: endpoint,
            payloadFactory: _payload,
            connector: connector,
          ),
        );

        final events = await client.stream(_request).toList();
        final postedBody = jsonDecode(connector.body!) as Map<String, Object?>;

        expect(events.last.type, 'RUN_FINISHED');
        expect(connector.uri!.queryParameters, {
          'existing': '1',
          'token': 'secret-token',
        });
        expect(connector.headers, containsPair('Accept', 'text/event-stream'));
        expect(
          connector.headers,
          containsPair('Content-Type', 'application/json'),
        );
        expect(
          connector.headers,
          containsPair('Authorization', 'Bearer secret-token'),
        );
        expect(connector.headers, containsPair('X-Client', 'flutter'));
        expect(postedBody['threadId'], 'thread-fixture-001');
        expect(postedBody['runId'], 'run-io-001');
        expect(
          endpoint.redactedLogContext().toString(),
          isNot(contains('secret-token')),
        );
      },
    );

    test(
      'WebSocket transport sends first-frame payload and closes on terminal event',
      () async {
        final websocketFrames =
            parseJsonlMaps(
                readMigrationFixture('ag_ui/text_stream_basic.websocket.jsonl'),
              ).map((frame) => stringField(frame, 'frame') ?? '').toList()
              ..add('{malformed-after-terminal');
        final connection = _RecordingWebSocketConnection(websocketFrames);
        final connector = _RecordingWebSocketConnector(connection);
        final client = WebSocketAgentStreamClient(
          AgentWebSocketTransport(
            endpoint: AgentStreamEndpoint(
              uri: Uri.parse('ws://127.0.0.1:8769/api/ag-ui-ws'),
              token: 'secret-token',
            ),
            payloadFactory: _payload,
            connector: connector,
          ),
        );

        final events = await client.stream(_request).toList();
        final sentPayload =
            jsonDecode(connection.sent.single) as Map<String, Object?>;

        expect(events.last.type, 'RUN_FINISHED');
        expect(connector.uri!.queryParameters['token'], 'secret-token');
        expect(
          connector.headers,
          containsPair('Authorization', 'Bearer secret-token'),
        );
        expect(sentPayload['threadId'], 'thread-fixture-001');
        expect(sentPayload['runId'], 'run-io-001');
        expect(connection.closeCount, 1);
      },
    );

    test(
      'cancel client posts AG-UI cancel body and accepts 2xx or 404',
      () async {
        final ack = readFixtureMap('ag_ui/cancel_ack.json');
        final connector = _RecordingControlHttpConnector(
          AgentStreamControlHttpResponse(
            statusCode: 200,
            body: jsonEncode(ack),
          ),
        );
        final client = AgentStreamCancelClient(
          endpoint: AgentStreamEndpoint(
            uri: Uri.parse('http://127.0.0.1:8769/api/ag-ui-cancel'),
            token: 'secret-token',
          ),
          connector: connector,
        );

        final result = await client.cancel(
          const AgentStreamCancelRequest(
            threadId: 'thread-fixture-001',
            runId: 'run-fixture-tool-001',
            userId: 'demo-user-fixture',
          ),
        );

        expect(result.acknowledged, isTrue);
        expect(result.statusCode, 200);
        expect(result.body, ack);
        expect(connector.uri!.queryParameters['token'], 'secret-token');
        expect(
          connector.headers,
          containsPair('Authorization', 'Bearer secret-token'),
        );
        expect(connector.headers, containsPair('Accept', 'application/json'));
        expect(
          connector.headers,
          containsPair('Content-Type', 'application/json'),
        );
        expect(jsonDecode(connector.body!) as Map<String, Object?>, {
          'threadId': 'thread-fixture-001',
          'runId': 'run-fixture-tool-001',
          'user_id': 'demo-user-fixture',
        });

        connector.nextResponse = const AgentStreamControlHttpResponse(
          statusCode: 404,
          body: '',
        );

        final alreadyClosed = await client.cancel(
          const AgentStreamCancelRequest(threadId: 'thread-fixture-001'),
        );

        expect(alreadyClosed.acknowledged, isTrue);
        expect(alreadyClosed.statusCode, 404);
      },
    );

    test('cancel client reports failures without throwing', () async {
      final connector = _RecordingControlHttpConnector(
        const AgentStreamControlHttpResponse(
          statusCode: 503,
          body: '{"message":"busy"}',
        ),
      );
      final client = AgentStreamCancelClient(
        endpoint: AgentStreamEndpoint(
          uri: Uri.parse('http://127.0.0.1:8769/api/ag-ui-cancel'),
        ),
        connector: connector,
      );

      final unavailable = await client.cancel(
        const AgentStreamCancelRequest(threadId: 'thread-fixture-001'),
      );

      expect(unavailable.acknowledged, isFalse);
      expect(unavailable.statusCode, 503);
      expect(unavailable.body, {'message': 'busy'});

      connector.nextError = StateError('network down');

      final networkFailure = await client.cancel(
        const AgentStreamCancelRequest(threadId: 'thread-fixture-001'),
      );

      expect(networkFailure.acknowledged, isFalse);
      expect(networkFailure.error, isA<StateError>());
    });

    test(
      'prewarm client posts hidden AG-UI payload and unwraps envelope responses',
      () async {
        final connector = _RecordingControlHttpConnector(
          AgentStreamControlHttpResponse(
            statusCode: 200,
            body: jsonEncode(_agentChatResponse('success')),
          ),
        );
        final client = AgentStreamPrewarmClient(
          endpoint: AgentStreamEndpoint(
            uri: Uri.parse('http://127.0.0.1:8769/api/ag-ui-prewarm'),
            token: 'secret-token',
          ),
          connector: connector,
        );

        final result = await client.prewarm(
          userId: 'demo-user-fixture',
          threadId: 'thread-fixture-001',
          runId: 'run-api-agent-001',
          messageId: 'msg-user-001',
          forwardedProps: {'source': 'runner-test'},
        );
        final postedBody = jsonDecode(connector.body!) as Map<String, Object?>;
        final message = (postedBody['messages']! as List).single as Map;
        final forwardedProps =
            postedBody['forwardedProps']! as Map<String, Object?>;

        expect(result.status, 'warmed');
        expect(result.threadId, 'thread-fixture-001');
        expect(result.runId, 'run-api-agent-001');
        expect(result.responseId, 'resp-fixture-001');
        expect(connector.uri!.queryParameters['token'], 'secret-token');
        expect(
          connector.headers,
          containsPair('Authorization', 'Bearer secret-token'),
        );
        expect(message['content'], agentStreamPrewarmMessage);
        expect(forwardedProps['prewarm'], isTrue);
        expect(forwardedProps['source'], 'runner-test');
      },
    );

    test(
      'prewarm client accepts legacy aliases and root object responses',
      () async {
        final connector = _RecordingControlHttpConnector(
          AgentStreamControlHttpResponse(
            statusCode: 200,
            body: jsonEncode(_agentChatResponse('legacy_alias')),
          ),
        );
        final client = AgentStreamPrewarmClient(
          endpoint: AgentStreamEndpoint(
            uri: Uri.parse('http://127.0.0.1:8769/api/ag-ui-prewarm'),
          ),
          connector: connector,
        );

        final legacy = await client.prewarm(
          userId: 'demo-user-fixture',
          threadId: 'thread-fixture-001',
          runId: 'run-api-agent-001',
          messageId: 'msg-user-001',
        );

        expect(legacy.threadId, 'thread-fixture-001');
        expect(legacy.runId, 'run-api-agent-001');
        expect(legacy.responseId, 'resp-fixture-001');

        connector.nextResponse = const AgentStreamControlHttpResponse(
          statusCode: 200,
          body: '{"status":"already_warm","thread_id":"thread-fixture-001"}',
        );

        final root = await client.prewarm(
          userId: 'demo-user-fixture',
          threadId: 'thread-fixture-001',
          runId: 'run-api-agent-002',
          messageId: 'msg-user-002',
        );

        expect(root.status, 'already_warm');
        expect(root.threadId, 'thread-fixture-001');
      },
    );

    test('prewarm client preserves business and HTTP failures', () async {
      final connector = _RecordingControlHttpConnector(
        AgentStreamControlHttpResponse(
          statusCode: 200,
          body: jsonEncode(_agentChatResponse('business_error')),
        ),
      );
      final client = AgentStreamPrewarmClient(
        endpoint: AgentStreamEndpoint(
          uri: Uri.parse('http://127.0.0.1:8769/api/ag-ui-prewarm'),
        ),
        connector: connector,
      );

      await expectLater(
        client.prewarm(
          userId: 'demo-user-fixture',
          threadId: 'thread-fixture-001',
          runId: 'run-api-agent-001',
          messageId: 'msg-user-001',
        ),
        throwsA(isA<ApiBusinessException>()),
      );

      connector.nextResponse = AgentStreamControlHttpResponse(
        statusCode: 502,
        body: jsonEncode(_agentChatResponse('http_error')),
      );

      await expectLater(
        client.prewarm(
          userId: 'demo-user-fixture',
          threadId: 'thread-fixture-001',
          runId: 'run-api-agent-001',
          messageId: 'msg-user-001',
        ),
        throwsA(isA<AgentStreamTransportException>()),
      );
    });

    test(
      'timing log client posts redaction-safe best-effort entries',
      () async {
        final connector = _RecordingControlHttpConnector(
          const AgentStreamControlHttpResponse(statusCode: 204, body: ''),
        );
        final client = AgentStreamTimingLogClient(
          endpoint: AgentStreamEndpoint(
            uri: Uri.parse('http://127.0.0.1:8769/api/ag-ui-timing-log'),
            token: 'secret-token',
          ),
          connector: connector,
        );

        final result = await client.post(
          const AgentStreamTimingLogEntry(
            source: 'flutter',
            stage: 'client.ws_open',
            runId: 'run-fixture-001',
            threadId: 'thread-fixture-001',
            clientTimingId: 'timing-001',
            userId: 'demo-user-fixture',
            elapsedMs: 42,
            clientTsMs: 1700000000000,
            metadata: {'transport': 'websocket'},
          ),
        );
        final body = jsonDecode(connector.body!) as Map<String, Object?>;
        final redactedBody = redactLogMap(body).toString();

        expect(result.sent, isTrue);
        expect(result.statusCode, 204);
        expect(connector.uri!.queryParameters['token'], 'secret-token');
        expect(
          connector.headers,
          containsPair('Authorization', 'Bearer secret-token'),
        );
        expect(body, containsPair('stage', 'client.ws_open'));
        expect(body, containsPair('run_id', 'run-fixture-001'));
        expect(body, containsPair('thread_id', 'thread-fixture-001'));
        expect(body, containsPair('user_id', 'demo-user-fixture'));
        expect(redactedBody, isNot(contains('thread-fixture-001')));
        expect(redactedBody, isNot(contains('demo-user-fixture')));
      },
    );

    test(
      'timing log client never throws for HTTP or network failures',
      () async {
        final connector = _RecordingControlHttpConnector(
          const AgentStreamControlHttpResponse(statusCode: 503, body: ''),
        );
        final client = AgentStreamTimingLogClient(
          endpoint: AgentStreamEndpoint(
            uri: Uri.parse('http://127.0.0.1:8769/api/ag-ui-timing-log'),
          ),
          connector: connector,
        );

        final httpFailure = await client.post(
          const AgentStreamTimingLogEntry(stage: 'client.ws_error'),
        );

        expect(httpFailure.sent, isFalse);
        expect(httpFailure.statusCode, 503);

        connector.nextError = StateError('network down');

        final networkFailure = await client.post(
          const AgentStreamTimingLogEntry(stage: 'client.ws_error'),
        );

        expect(networkFailure.sent, isFalse);
        expect(networkFailure.error, isA<StateError>());
      },
    );
  });
}

const _request = AgentStreamRequest(
  userId: 'demo-user-fixture',
  message: 'Review my pumping pattern.',
  threadId: 'thread-fixture-001',
  metadata: {'source': 'io-transport-test'},
);

Map<String, Object?> _payload(AgentStreamRequest request) {
  return buildAgentRunPayload(
    request,
    runId: 'run-io-001',
    messageId: 'msg-io-001',
  );
}

Map<String, Object?> _agentChatResponse(String variant) {
  final fixture = readFixtureMap('api/agent_chat/$variant.json');
  return Map<String, Object?>.from(fixture['response']! as Map);
}

class _RecordingSseConnector implements AgentStreamSseConnector {
  _RecordingSseConnector(this.seedFrames);

  final Iterable<String> seedFrames;
  Uri? uri;
  Map<String, String>? headers;
  String? body;

  @override
  Stream<String> post(
    Uri uri, {
    required Map<String, String> headers,
    required String body,
  }) async* {
    this.uri = uri;
    this.headers = headers;
    this.body = body;

    for (final frame in seedFrames) {
      yield frame;
    }
  }
}

class _RecordingWebSocketConnector implements AgentStreamWebSocketConnector {
  _RecordingWebSocketConnector(this.connection);

  final _RecordingWebSocketConnection connection;
  Uri? uri;
  Map<String, String>? headers;

  @override
  Future<AgentStreamWebSocketConnection> connect(
    Uri uri, {
    required Map<String, String> headers,
  }) async {
    this.uri = uri;
    this.headers = headers;
    return connection;
  }
}

class _RecordingWebSocketConnection implements AgentStreamWebSocketConnection {
  _RecordingWebSocketConnection(this.seedFrames);

  final Iterable<String> seedFrames;
  final sent = <String>[];
  var closeCount = 0;

  @override
  Stream<String> get frames async* {
    for (final frame in seedFrames) {
      yield frame;
    }
  }

  @override
  void send(String text) => sent.add(text);

  @override
  Future<void> close() async {
    closeCount += 1;
  }
}

class _RecordingControlHttpConnector
    implements AgentStreamControlHttpConnector {
  _RecordingControlHttpConnector(this.nextResponse);

  AgentStreamControlHttpResponse nextResponse;
  Object? nextError;
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

    final error = nextError;
    if (error != null) {
      nextError = null;
      throw error;
    }

    return nextResponse;
  }
}
