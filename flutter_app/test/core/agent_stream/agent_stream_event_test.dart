import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_event.dart';

import '../../support/fixture_reader.dart';

void main() {
  group('Agent stream fixtures', () {
    test(
      'parse the same logical text stream from JSONL and SSE frames',
      () {
        final jsonl = parseAgentJsonl(
          readMigrationFixture('agent_events/text_stream_basic.jsonl'),
        );
        final sse = parseAgentEventStream(
          readMigrationFixture('agent_events/text_stream_basic.eventstream'),
        );

        expect(sse.map((event) => event.raw), jsonl.map((event) => event.raw));
        expect(
          jsonl
              .where((event) => event.type == 'message.delta')
              .map((event) => event.textDelta)
              .whereType<String>()
              .join(),
          'I can help you review today\'s pumping pattern.',
        );
      },
    );

    test('cover the required domain event types and stable merge keys', () {
      final events = <AgentStreamEvent>[
        AgentStreamEvent(readFixtureMap('agent_events/run_started.json')),
        ...parseAgentJsonl(
          readMigrationFixture('agent_events/text_stream_basic.jsonl'),
        ),
        ...parseAgentJsonl(
          readMigrationFixture('agent_events/tool_call_lifecycle.jsonl'),
        ),
        AgentStreamEvent(readFixtureMap('agent_events/rich_text_artifact.json')),
        AgentStreamEvent(readFixtureMap('agent_events/run_failed.json')),
      ];
      final types = events.map((event) => event.type).toSet();

      expect(
        types,
        containsAll(<String>[
          'run.started',
          'message.delta',
          'message.completed',
          'run.completed',
          'run.failed',
          'tool.started',
          'tool.completed',
          'artifact.created',
          'action.confirmation_required',
        ]),
      );
      expect(events.every((event) => event.mergeKey.isNotEmpty), isTrue);
      expect(
        events.where((event) => event.isTerminal).map((event) => event.type),
        containsAll(['run.completed', 'run.failed']),
      );
    });

    test('treats waiting for confirmation as a stable terminal stream event', () {
      final event = AgentStreamEvent(const {
        'type': 'run.waiting_for_confirmation',
        'thread_id': 'thread-action-001',
        'run_id': 'run-action-001',
        'sequence': 5,
      });

      expect(event.isTerminal, isTrue);
      expect(event.replayKey, 'sequence:run-action-001:5');
    });

    test('uses payload action ids as stable reducer keys', () {
      final event = AgentStreamEvent(const {
        'type': 'action.queued',
        'thread_id': 'thread-action-001',
        'run_id': 'run-action-001',
        'payload': {'action_id': 'action-support-001'},
      });

      expect(event.mergeKey, 'action:action-support-001');
    });

    test('exposes production reducer ids from raw or payload fields', () {
      final event = AgentStreamEvent(const {
        'event_id': 'evt-action-001',
        'type': 'action.applied',
        'thread_id': 'thread-action-001',
        'run_id': 'run-action-001',
        'sequence': '8',
        'payload': {
          'action_id': 'action-support-001',
          'tool_call_id': 'tool-support-001',
          'artifact_id': 'artifact-support-001',
          'cursor': '1720000000-0',
        },
      });

      expect(event.sequence, 8);
      expect(event.actionId, 'action-support-001');
      expect(event.toolCallId, 'tool-support-001');
      expect(event.artifactId, 'artifact-support-001');
      expect(event.cursor, '1720000000-0');
      expect(event.isTransient, isFalse);
    });

    test('recognizes transient message delta events', () {
      final event = AgentStreamEvent(const {
        'event_id': 'delta:1720000000-0',
        'type': 'message.delta',
        'thread_id': 'thread-stream-001',
        'run_id': 'run-stream-001',
        'transient': true,
        'cursor': '1720000000-0',
        'payload': {
          'delta': '正在生成',
          'message_stream_id': 'assistant',
        },
      });

      expect(event.isTransient, isTrue);
      expect(event.sequence, isNull);
      expect(event.textDelta, '正在生成');
      expect(event.replayKey, 'event:delta:1720000000-0');
    });
  });
}
