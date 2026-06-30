import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_client.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_event.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_run_state.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_runner.dart';

import '../../support/fixture_reader.dart';

void main() {
  group('AgentStreamRunner', () {
    test(
      'produces the same final state for SSE and WebSocket clients',
      () async {
        const request = AgentStreamRequest(
          userId: 'demo-user',
          message: 'Review my pumping pattern.',
        );
        final sseRunner = AgentStreamRunner(
          SseAgentStreamClient(
            FixtureAgentStreamTransport([
              readMigrationFixture('ag_ui/text_stream_basic.eventstream'),
            ]),
          ),
        );
        final websocketFrames = parseJsonlMaps(
          readMigrationFixture('ag_ui/text_stream_basic.websocket.jsonl'),
        ).map((frame) => stringField(frame, 'frame') ?? '');
        final websocketRunner = AgentStreamRunner(
          WebSocketAgentStreamClient(
            FixtureAgentStreamTransport(websocketFrames),
          ),
        );

        final sseStates = await sseRunner.run(request).toList();
        final websocketStates = await websocketRunner.run(request).toList();
        final sseFinal = sseStates.last;
        final websocketFinal = websocketStates.last;

        expect(sseStates.first.phase, AgentStreamRunPhase.streaming);
        expect(sseFinal.phase, AgentStreamRunPhase.finished);
        expect(websocketFinal.phase, AgentStreamRunPhase.finished);
        expect(websocketFinal.textContent, sseFinal.textContent);
        expect(websocketFinal.runId, sseFinal.runId);
      },
    );

    test(
      'maps transport errors to disconnected state with partial text',
      () async {
        final runner = AgentStreamRunner(
          JsonlAgentStreamClient(
            _FailingTransport([
              jsonEncode(readFixtureMap('ag_ui/run_started.json')),
              jsonEncode({
                'type': 'TEXT_MESSAGE_CONTENT',
                'thread_id': 'thread-fixture-001',
                'run_id': 'run-fixture-001',
                'message_id': 'msg-reply-001',
                'delta': 'Partial answer',
              }),
            ]),
          ),
        );

        final states = await runner.run(_request).toList();
        final disconnected = states.last;

        expect(disconnected.phase, AgentStreamRunPhase.disconnected);
        expect(disconnected.canRetry, isTrue);
        expect(disconnected.textContent, 'Partial answer');
        expect(disconnected.errorMessage, contains('socket closed'));
      },
    );

    test('marks streams without terminal events as disconnected', () async {
      final runner = AgentStreamRunner(
        JsonlAgentStreamClient(
          FixtureAgentStreamTransport([
            jsonEncode(readFixtureMap('ag_ui/run_started.json')),
          ]),
        ),
      );

      final states = await runner.run(_request).toList();

      expect(states.last.phase, AgentStreamRunPhase.disconnected);
      expect(
        states.last.errorMessage,
        contains('ended before a terminal event'),
      );
    });
  });
}

const _request = AgentStreamRequest(
  userId: 'demo-user',
  message: 'Review my pumping pattern.',
);

class _FailingTransport implements AgentStreamTransport {
  const _FailingTransport(this.seedFrames);

  final Iterable<String> seedFrames;

  @override
  Stream<String> frames(AgentStreamRequest request) async* {
    for (final frame in seedFrames) {
      yield frame;
    }
    throw StateError('socket closed');
  }
}
