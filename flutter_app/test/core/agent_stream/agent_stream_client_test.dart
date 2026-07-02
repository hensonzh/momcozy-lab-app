import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_client.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_event.dart';

import '../../support/fixture_reader.dart';

void main() {
  group('AgentStreamClient', () {
    test(
      'normalizes SSE and JSONL transports into the same event stream',
      () async {
        const request = AgentStreamRequest(
          message: 'Review my pumping pattern.',
        );
        final expected = parseAgentJsonl(
          readMigrationFixture('agent_events/text_stream_basic.jsonl'),
        );
        final sseClient = SseAgentStreamClient(
          FixtureAgentStreamTransport([
            readMigrationFixture('agent_events/text_stream_basic.eventstream'),
          ]),
        );
        final jsonlClient = JsonlAgentStreamClient(
          FixtureAgentStreamTransport([
            readMigrationFixture('agent_events/text_stream_basic.jsonl'),
          ]),
        );

        final sseEvents = await sseClient.stream(request).toList();
        final jsonlEvents = await jsonlClient.stream(request).toList();

        expect(
          sseEvents.map((event) => event.raw),
          expected.map((event) => event.raw),
        );
        expect(
          jsonlEvents.map((event) => event.raw),
          expected.map((event) => event.raw),
        );
      },
    );

    test(
      'keeps transport chunks ordered and stops after run finished',
      () async {
        const request = AgentStreamRequest(
          message: 'Create a plan.',
          threadId: 'thread-1',
        );
        final client = JsonlAgentStreamClient(
          FixtureAgentStreamTransport([
            jsonEncode(readFixtureMap('agent_events/run_started.json')),
            readMigrationFixture('agent_events/tool_call_lifecycle.jsonl'),
            '{malformed-after-terminal',
          ]),
        );

        final events = await client.stream(request).toList();

        expect(events.first.type, 'run.started');
        expect(events.last.type, 'run.completed');
        expect(events.last.isTerminal, isTrue);
        expect(
          events.where((event) => event.mergeKey.startsWith('tool:')),
          isNotEmpty,
        );
        expect(request.toMap(), {
          'message': 'Create a plan.',
          'threadId': 'thread-1',
          'locale': 'en-US',
        });
      },
    );

    test('stops after run error events', () async {
      const request = AgentStreamRequest(
        message: 'Create a plan.',
        threadId: 'thread-1',
      );
      final client = JsonlAgentStreamClient(
        FixtureAgentStreamTransport([
          jsonEncode(readFixtureMap('agent_events/run_started.json')),
          jsonEncode(readFixtureMap('agent_events/run_failed.json')),
          '{malformed-after-terminal',
        ]),
      );

      final events = await client.stream(request).toList();

      expect(events.map((event) => event.type), ['run.started', 'run.failed']);
      expect(events.last.isTerminal, isTrue);
    });
  });
}
