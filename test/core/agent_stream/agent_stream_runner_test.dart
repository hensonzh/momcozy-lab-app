import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_client.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_event.dart';
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
      'keeps non-retryable transport errors as a manual retry state',
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

    test(
      'automatically resumes the same run after a follow window ends',
      () async {
        final client = _SequencedAgentStreamClient([
          [
            _event(id: 'evt-run-started', type: 'run.started', sequence: 1),
            _event(id: 'delta:1-0', type: 'message.delta', text: '追奶'),
          ],
          [
            _event(id: 'delta:1-0', type: 'message.delta', text: '追奶'),
            _event(id: 'delta:2-0', type: 'message.delta', text: '计划'),
            _event(
              id: 'evt-message-completed',
              type: 'message.completed',
              sequence: 2,
              text: '追奶计划',
            ),
            _event(
              id: 'evt-waiting',
              type: 'run.waiting_for_confirmation',
              sequence: 3,
            ),
          ],
        ]);
        final runner = AgentStreamRunner(
          client,
          reconnectPolicy: const AgentStreamReconnectPolicy(
            transportRetryBaseDelay: Duration.zero,
          ),
        );

        final states = await runner.run(_request).toList();

        expect(states.last.phase, AgentStreamRunPhase.waitingForConfirmation);
        expect(states.last.textContent, '追奶计划');
        expect(states.last.errorMessage, isNull);
        expect(
          states.where((state) => state.textContent == '追奶'),
          hasLength(1),
        );
        expect(client.requests, hasLength(2));
        expect(client.requests.first.runId, isNull);
        expect(client.requests.last.runId, 'run-fixture-001');
        expect(client.requests.last.threadId, 'thread-fixture-001');
        expect(client.requests.last.afterSequence, 1);
      },
    );

    test(
      'keeps listening after message completion until the run is terminal',
      () async {
        final client = _SequencedAgentStreamClient([
          [
            _event(id: 'evt-run-started', type: 'run.started', sequence: 1),
            _event(
              id: 'evt-message-completed',
              type: 'message.completed',
              sequence: 2,
              text: 'Final answer',
            ),
          ],
          [_event(id: 'evt-run-completed', type: 'run.completed', sequence: 3)],
        ]);
        final runner = AgentStreamRunner(
          client,
          reconnectPolicy: const AgentStreamReconnectPolicy(
            transportRetryBaseDelay: Duration.zero,
          ),
        );

        final states = await runner.run(_request).toList();

        expect(states.last.phase, AgentStreamRunPhase.finished);
        expect(states.last.textContent, 'Final answer');
        expect(states.last.errorMessage, isNull);
      },
    );

    test(
      'resumes after a retryable transport failure without duplicating text',
      () async {
        final client = _SequencedAgentStreamClient(
          [
            [
              _event(id: 'evt-run-started', type: 'run.started', sequence: 1),
              _event(id: 'delta:1-0', type: 'message.delta', text: '正在分析'),
            ],
            [
              _event(id: 'delta:1-0', type: 'message.delta', text: '正在分析'),
              _event(
                id: 'evt-message-completed',
                type: 'message.completed',
                sequence: 2,
                text: '正在分析',
              ),
              _event(
                id: 'evt-run-completed',
                type: 'run.completed',
                sequence: 3,
              ),
            ],
          ],
          errors: const [_RetryableTestFailure(), null],
        );
        final runner = AgentStreamRunner(
          client,
          reconnectPolicy: const AgentStreamReconnectPolicy(
            transportRetryBaseDelay: Duration.zero,
          ),
        );

        final states = await runner.run(_request).toList();

        expect(states.last.phase, AgentStreamRunPhase.finished);
        expect(states.last.textContent, '正在分析');
        expect(client.requests, hasLength(2));
        expect(client.requests.last.runId, 'run-fixture-001');
        expect(client.requests.last.afterSequence, 1);
      },
    );

    test(
      'retries an uncertain run creation with the same idempotency key',
      () async {
        final client = _SequencedAgentStreamClient(
          [
            const <AgentStreamEvent>[],
            [
              _event(id: 'evt-run-started', type: 'run.started', sequence: 1),
              _event(
                id: 'evt-message-completed',
                type: 'message.completed',
                sequence: 2,
                text: '后端已完成的回复',
              ),
              _event(
                id: 'evt-run-completed',
                type: 'run.completed',
                sequence: 3,
              ),
            ],
          ],
          errors: const [_RetryableTestFailure(), null],
        );
        final runner = AgentStreamRunner(
          client,
          reconnectPolicy: const AgentStreamReconnectPolicy(
            maxTransportReconnects: 1,
            transportRetryBaseDelay: Duration.zero,
          ),
        );

        final states = await runner.run(_request).toList();

        expect(states.last.phase, AgentStreamRunPhase.finished);
        expect(states.last.textContent, '后端已完成的回复');
        expect(
          states.where(
            (state) => state.phase == AgentStreamRunPhase.disconnected,
          ),
          isEmpty,
        );
        expect(client.requests, hasLength(2));
        expect(client.requests.first.runId, isNull);
        expect(client.requests.last.runId, isNull);
        expect(client.requests.first.idempotencyKey, isNotEmpty);
        expect(
          client.requests.last.idempotencyKey,
          client.requests.first.idempotencyKey,
        );
      },
    );

    test(
      'replays a completed run from the start before settling without text',
      () async {
        final client = _SequencedAgentStreamClient([
          [
            _event(id: 'evt-run-started', type: 'run.started', sequence: 1),
            _event(id: 'evt-run-completed', type: 'run.completed', sequence: 3),
          ],
          [
            _event(id: 'evt-run-started', type: 'run.started', sequence: 1),
            _event(
              id: 'evt-message-completed',
              type: 'message.completed',
              sequence: 2,
              text: '补偿恢复后的完整回复',
            ),
            _event(id: 'evt-run-completed', type: 'run.completed', sequence: 3),
          ],
        ]);
        final runner = AgentStreamRunner(
          client,
          reconnectPolicy: const AgentStreamReconnectPolicy(
            transportRetryBaseDelay: Duration.zero,
          ),
        );

        final states = await runner.run(_request).toList();

        expect(states.last.phase, AgentStreamRunPhase.finished);
        expect(states.last.textContent, '补偿恢复后的完整回复');
        expect(
          states.where(
            (state) => state.phase == AgentStreamRunPhase.disconnected,
          ),
          isEmpty,
        );
        expect(client.requests, hasLength(2));
        expect(client.requests.last.runId, 'run-fixture-001');
        expect(client.requests.last.threadId, 'thread-fixture-001');
        expect(client.requests.last.afterSequence, 0);
      },
    );

    test(
      'does not reconnect after the run subscription is cancelled',
      () async {
        final client = _SequencedAgentStreamClient(
          [
            [_event(id: 'evt-run-started', type: 'run.started', sequence: 1)],
            [
              _event(
                id: 'evt-run-completed',
                type: 'run.completed',
                sequence: 2,
              ),
            ],
          ],
          errors: const [_RetryableTestFailure(), null],
        );
        final runner = AgentStreamRunner(
          client,
          reconnectPolicy: const AgentStreamReconnectPolicy(
            transportRetryBaseDelay: Duration(milliseconds: 100),
          ),
        );
        final subscription = runner.run(_request).listen((_) {});
        await Future<void>.delayed(const Duration(milliseconds: 20));

        await subscription.cancel();
        await Future<void>.delayed(const Duration(milliseconds: 120));

        expect(client.requests, hasLength(1));
      },
    );

    test(
      'replays persisted events when status is completed without final text',
      () async {
        final client = _SequencedAgentStreamClient([
          [_event(id: 'evt-run-started', type: 'run.started', sequence: 1)],
          [
            _event(id: 'evt-run-started', type: 'run.started', sequence: 1),
            _event(
              id: 'evt-message-completed',
              type: 'message.completed',
              sequence: 2,
              text: '状态补偿后的完整回复',
            ),
            _event(id: 'evt-run-completed', type: 'run.completed', sequence: 3),
          ],
        ]);
        final statusReader = _FixtureRunStatusReader(
          const AgentRunStatusSnapshot(
            runId: 'run-fixture-001',
            threadId: 'thread-fixture-001',
            status: AgentRunLifecycleStatus.completed,
          ),
        );
        final runner = AgentStreamRunner(
          client,
          runStatusReader: statusReader,
          reconnectPolicy: const AgentStreamReconnectPolicy(
            maxFollowWindowReconnects: 0,
            transportRetryBaseDelay: Duration.zero,
          ),
        );

        final states = await runner.run(_request).toList();

        expect(states.last.phase, AgentStreamRunPhase.finished);
        expect(states.last.textContent, '状态补偿后的完整回复');
        expect(
          states.where(
            (state) => state.phase == AgentStreamRunPhase.disconnected,
          ),
          isEmpty,
        );
        expect(statusReader.runIds, ['run-fixture-001']);
        expect(client.requests, hasLength(2));
        expect(client.requests.last.runId, 'run-fixture-001');
        expect(client.requests.last.afterSequence, 0);
      },
    );

    test(
      'reconciles a terminal server status after follow retries are exhausted',
      () async {
        final client = _SequencedAgentStreamClient([
          [
            _event(id: 'evt-run-started', type: 'run.started', sequence: 1),
            _event(
              id: 'evt-message-completed',
              type: 'message.completed',
              sequence: 2,
              text: '计划已生成',
            ),
          ],
        ]);
        final statusReader = _FixtureRunStatusReader(
          const AgentRunStatusSnapshot(
            runId: 'run-fixture-001',
            threadId: 'thread-fixture-001',
            status: AgentRunLifecycleStatus.completed,
          ),
        );
        final runner = AgentStreamRunner(
          client,
          runStatusReader: statusReader,
          reconnectPolicy: const AgentStreamReconnectPolicy(
            maxFollowWindowReconnects: 0,
            transportRetryBaseDelay: Duration.zero,
          ),
        );

        final states = await runner.run(_request).toList();

        expect(states.last.phase, AgentStreamRunPhase.finished);
        expect(states.last.textContent, '计划已生成');
        expect(statusReader.runIds, ['run-fixture-001']);
        expect(client.requests, hasLength(1));
      },
    );

    test(
      'continues the same run when reconciliation reports it active',
      () async {
        final client = _SequencedAgentStreamClient([
          [_event(id: 'evt-run-started', type: 'run.started', sequence: 1)],
          [
            _event(
              id: 'evt-message-completed',
              type: 'message.completed',
              sequence: 2,
              text: '继续执行后的回复',
            ),
            _event(id: 'evt-run-completed', type: 'run.completed', sequence: 3),
          ],
        ]);
        final statusReader = _FixtureRunStatusReader(
          const AgentRunStatusSnapshot(
            runId: 'run-fixture-001',
            threadId: 'thread-fixture-001',
            status: AgentRunLifecycleStatus.running,
          ),
        );
        final runner = AgentStreamRunner(
          client,
          runStatusReader: statusReader,
          reconnectPolicy: const AgentStreamReconnectPolicy(
            maxFollowWindowReconnects: 0,
            maxActiveStatusReconciliations: 1,
            transportRetryBaseDelay: Duration.zero,
          ),
        );

        final states = await runner.run(_request).toList();

        expect(states.last.phase, AgentStreamRunPhase.finished);
        expect(states.last.textContent, '继续执行后的回复');
        expect(client.requests, hasLength(2));
        expect(client.requests.last.runId, 'run-fixture-001');
        expect(client.requests.last.afterSequence, 1);
      },
    );

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
              'payload': {'text': 'Partial answer'},
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
      expect(states.last.textContent, 'Partial answer');
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

class _SequencedAgentStreamClient implements AgentStreamClient {
  _SequencedAgentStreamClient(this.attempts, {this.errors = const <Object?>[]});

  final List<List<AgentStreamEvent>> attempts;
  final List<Object?> errors;
  final requests = <AgentStreamRequest>[];

  @override
  Stream<AgentStreamEvent> stream(AgentStreamRequest request) async* {
    final attemptIndex = requests.length;
    requests.add(request);
    if (attemptIndex >= attempts.length) return;
    for (final event in attempts[attemptIndex]) {
      yield event;
    }
    if (attemptIndex < errors.length && errors[attemptIndex] != null) {
      throw errors[attemptIndex]!;
    }
  }
}

class _RetryableTestFailure implements AgentStreamRetryableFailure {
  const _RetryableTestFailure();

  @override
  bool get isRetryable => true;
}

class _FixtureRunStatusReader implements AgentRunStatusReader {
  _FixtureRunStatusReader(this.snapshot);

  final AgentRunStatusSnapshot snapshot;
  final runIds = <String>[];

  @override
  Future<AgentRunStatusSnapshot> read(String runId) async {
    runIds.add(runId);
    return snapshot;
  }
}

AgentStreamEvent _event({
  required String id,
  required String type,
  int? sequence,
  String? text,
}) {
  return AgentStreamEvent({
    'event_id': id,
    'type': type,
    'thread_id': 'thread-fixture-001',
    'run_id': 'run-fixture-001',
    'message_id': 'msg-reply-001',
    'sequence': ?sequence,
    'payload': {
      if (type == 'message.delta') 'text': text,
      if (type == 'message.completed') ...{'role': 'assistant', 'text': text},
    },
  });
}
