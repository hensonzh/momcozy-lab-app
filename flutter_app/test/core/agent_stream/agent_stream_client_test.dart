import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_client.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_event.dart';

import '../../support/fixture_reader.dart';

void main() {
  group('AgentStreamClient', () {
    test(
      'normalizes SSE and WebSocket transports into the same event stream',
      () async {
        const request = AgentStreamRequest(
          userId: 'demo-user',
          message: 'Review my pumping pattern.',
        );
        final expected = parseAgentJsonl(
          readMigrationFixture('ag_ui/text_stream_basic.jsonl'),
        );
        final sseClient = SseAgentStreamClient(
          FixtureAgentStreamTransport([
            readMigrationFixture('ag_ui/text_stream_basic.eventstream'),
          ]),
        );
        final websocketFrames = parseJsonlMaps(
          readMigrationFixture('ag_ui/text_stream_basic.websocket.jsonl'),
        ).map((frame) => stringField(frame, 'frame') ?? '');
        final webSocketClient = WebSocketAgentStreamClient(
          FixtureAgentStreamTransport(websocketFrames),
        );

        final sseEvents = await sseClient.stream(request).toList();
        final websocketEvents = await webSocketClient.stream(request).toList();

        expect(
          sseEvents.map((event) => event.raw),
          expected.map((event) => event.raw),
        );
        expect(
          websocketEvents.map((event) => event.raw),
          expected.map((event) => event.raw),
        );
      },
    );

    test(
      'keeps transport chunks ordered and exposes terminal events',
      () async {
        const request = AgentStreamRequest(
          userId: 'demo-user',
          message: 'Create a plan.',
          threadId: 'thread-1',
        );
        final client = JsonlAgentStreamClient(
          FixtureAgentStreamTransport([
            jsonEncode(readFixtureMap('ag_ui/run_started.json')),
            readMigrationFixture('ag_ui/tool_call_lifecycle.jsonl'),
            jsonEncode(readFixtureMap('ag_ui/run_error.json')),
          ]),
        );

        final events = await client.stream(request).toList();

        expect(events.first.type, 'RUN_STARTED');
        expect(events.last.type, 'RUN_ERROR');
        expect(events.last.isTerminal, isTrue);
        expect(
          events.where((event) => event.mergeKey.startsWith('tool:')),
          isNotEmpty,
        );
        expect(request.toMap(), {
          'userId': 'demo-user',
          'message': 'Create a plan.',
          'threadId': 'thread-1',
        });
      },
    );
  });
}
