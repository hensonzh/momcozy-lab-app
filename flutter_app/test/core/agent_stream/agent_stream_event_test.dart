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
  });
}
