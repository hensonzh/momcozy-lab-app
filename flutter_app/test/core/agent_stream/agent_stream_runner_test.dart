import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_client.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_run_state.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_runner.dart';

import '../../support/fixture_reader.dart';

void main() {
  group('AgentStreamRunner', () {
    test('produces the same final state for SSE and JSONL clients', () async {
      const request = AgentStreamRequest(message: 'Review my pumping pattern.');
      final sseRunner = AgentStreamRunner(
        SseAgentStreamClient(
          FixtureAgentStreamTransport([
            readMigrationFixture('agent_events/text_stream_basic.eventstream'),
          ]),
        ),
      );
      final jsonlRunner = AgentStreamRunner(
        JsonlAgentStreamClient(
          FixtureAgentStreamTransport([
            readMigrationFixture('agent_events/text_stream_basic.jsonl'),
          ]),
        ),
      );

      final sseStates = await sseRunner.run(request).toList();
      final jsonlStates = await jsonlRunner.run(request).toList();
      final sseFinal = sseStates.last;
      final jsonlFinal = jsonlStates.last;

      expect(sseStates.first.phase, AgentStreamRunPhase.streaming);
      expect(sseFinal.phase, AgentStreamRunPhase.finished);
      expect(jsonlFinal.phase, AgentStreamRunPhase.finished);
      expect(jsonlFinal.textContent, sseFinal.textContent);
      expect(jsonlFinal.runId, sseFinal.runId);
    });

    test(
      'maps transport errors to disconnected state with partial text',
      () async {
        final runner = AgentStreamRunner(
          JsonlAgentStreamClient(
            _FailingTransport([
              jsonEncode(readFixtureMap('agent_events/run_started.json')),
              jsonEncode({
                'type': 'message.delta',
                'thread_id': 'thread-fixture-001',
                'run_id': 'run-fixture-001',
                'message_id': 'msg-reply-001',
                'payload': {'text': 'Partial answer'},
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
            jsonEncode(readFixtureMap('agent_events/run_started.json')),
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

    test('continues from an existing state for replay resumes', () async {
      final runner = AgentStreamRunner(
        JsonlAgentStreamClient(
          FixtureAgentStreamTransport([
            jsonEncode({
              'event_id': 'evt-resume-3',
              'type': 'message.completed',
              'thread_id': 'thread-fixture-001',
              'run_id': 'run-fixture-001',
              'message_id': 'msg-reply-001',
              'sequence': 3,
              'payload': {'text': 'Final answer'},
            }),
            jsonEncode({
              'event_id': 'evt-resume-4',
              'type': 'run.completed',
              'thread_id': 'thread-fixture-001',
              'run_id': 'run-fixture-001',
              'message_id': 'msg-reply-001',
              'sequence': 4,
            }),
          ]),
        ),
      );

      final initialState = AgentStreamRunState(
        phase: AgentStreamRunPhase.streaming,
        threadId: 'thread-fixture-001',
        runId: 'run-fixture-001',
        messageId: 'msg-reply-001',
        textContent: 'Partial',
        lastSequence: 2,
        events: [
          AgentStreamEvent(const {
            'event_id': 'evt-resume-2',
            'type': 'message.delta',
            'thread_id': 'thread-fixture-001',
            'run_id': 'run-fixture-001',
            'message_id': 'msg-reply-001',
            'sequence': 2,
            'payload': {'text': 'Partial'},
          }),
        ],
      );

      final states = await runner
          .run(_request, initialState: initialState)
          .toList();

      expect(states.first.textContent, 'Partial');
      expect(states.last.phase, AgentStreamRunPhase.finished);
      expect(states.last.textContent, 'Final answer');
      expect(states.last.lastSequence, 4);
      expect(states.last.events.map((event) => event.eventId), [
        'evt-resume-2',
        'evt-resume-3',
        'evt-resume-4',
      ]);
    });

    test('does not mark confirmation waits as disconnected', () async {
      final runner = AgentStreamRunner(
        JsonlAgentStreamClient(
          FixtureAgentStreamTransport([
            jsonEncode(readFixtureMap('agent_events/run_started.json')),
            jsonEncode({
              'type': 'run.waiting_for_confirmation',
              'thread_id': 'thread-fixture-001',
              'run_id': 'run-fixture-001',
              'payload': {'pending_action_id': 'action-support-001'},
            }),
            '{malformed-after-waiting-terminal',
          ]),
        ),
      );

      final states = await runner.run(_request).toList();

      expect(states.last.phase, AgentStreamRunPhase.waitingForConfirmation);
      expect(states.last.errorMessage, isNull);
    });
  });
}

const _request = AgentStreamRequest(message: 'Review my pumping pattern.');

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
