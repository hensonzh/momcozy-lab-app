import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_client.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_event.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_io_transport.dart';

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
