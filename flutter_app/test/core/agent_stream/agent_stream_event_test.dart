import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_event.dart';

import '../../support/fixture_reader.dart';

void main() {
  group('Agent stream fixtures', () {
    test(
      'parse the same logical text stream from JSONL, SSE, and WebSocket frames',
      () {
        final jsonl = parseAgentJsonl(
          readMigrationFixture('ag_ui/text_stream_basic.jsonl'),
        );
        final sse = parseAgentEventStream(
          readMigrationFixture('ag_ui/text_stream_basic.eventstream'),
        );
        final websocket = parseAgentWebSocketFixtureJsonl(
          readMigrationFixture('ag_ui/text_stream_basic.websocket.jsonl'),
        );

        expect(sse.map((event) => event.raw), jsonl.map((event) => event.raw));
        expect(
          websocket.map((event) => event.raw),
          jsonl.map((event) => event.raw),
        );
        expect(
          jsonl.map((event) => event.textDelta).whereType<String>().join(),
          ('I can help you review today\'s pumping pattern.'),
        );
      },
    );

    test('cover the required domain event types and stable merge keys', () {
      final events = <AgentStreamEvent>[
        AgentStreamEvent(readFixtureMap('ag_ui/run_started.json')),
        ...parseAgentJsonl(
          readMigrationFixture('ag_ui/text_stream_basic.jsonl'),
        ),
        ...parseAgentJsonl(
          readMigrationFixture('ag_ui/tool_call_lifecycle.jsonl'),
        ),
        AgentStreamEvent(readFixtureMap('ag_ui/activity_snapshot.json')),
        AgentStreamEvent(readFixtureMap('ag_ui/rich_text_artifact.json')),
        AgentStreamEvent(readFixtureMap('ag_ui/run_error.json')),
      ];
      final types = events.map((event) => event.type).toSet();

      expect(
        types,
        containsAll(<String>[
          'RUN_STARTED',
          'CUSTOM',
          'ACTIVITY_SNAPSHOT',
          'TOOL_CALL_START',
          'TOOL_CALL_ARGS',
          'TOOL_CALL_END',
          'TOOL_CALL_RESULT',
          'TEXT_MESSAGE_START',
          'TEXT_MESSAGE_CONTENT',
          'TEXT_MESSAGE_END',
          'RUN_FINISHED',
          'RUN_ERROR',
        ]),
      );
      expect(events.every((event) => event.mergeKey.isNotEmpty), isTrue);
      expect(
        events.where((event) => event.isTerminal).map((event) => event.type),
        containsAll(['RUN_FINISHED', 'RUN_ERROR']),
      );
    });
  });
}
