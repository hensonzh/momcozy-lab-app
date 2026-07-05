import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_event.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_run_state.dart';

import '../../support/fixture_reader.dart';

void main() {
  group('AgentStreamRunState', () {
    test('accumulates streamed text and finishes on terminal events', () {
      var state = const AgentStreamRunState().start();

      for (final event in parseAgentJsonl(
        readMigrationFixture('agent_events/text_stream_basic.jsonl'),
      )) {
        state = state.applyEvent(event);
      }

      expect(state.phase, AgentStreamRunPhase.finished);
      expect(state.threadId, 'thread-fixture-001');
      expect(state.runId, 'run-fixture-text-001');
      expect(state.messageId, 'msg-reply-text-001');
      expect(state.lastSequence, 5);
      expect(
        state.textContent,
        'I can help you review today\'s pumping pattern.',
      );
      expect(state.canRetry, isFalse);
      expect(state.events.length, 5);

      final afterTerminal = state.applyEvent(
        AgentStreamEvent(readFixtureMap('agent_events/run_failed.json')),
      );

      expect(afterTerminal.phase, AgentStreamRunPhase.finished);
      expect(afterTerminal.events.length, 5);
    });

    test('preserves partial text and marks disconnect as retryable', () {
      var state = const AgentStreamRunState().start();
      final events = parseAgentJsonl(
        readMigrationFixture('agent_events/text_stream_basic.jsonl'),
      );

      for (final event in events.take(3)) {
        state = state.applyEvent(event);
      }

      state = state.markDisconnected(StateError('socket closed'));

      expect(state.phase, AgentStreamRunPhase.disconnected);
      expect(state.canRetry, isTrue);
      expect(state.textContent, 'I can help ');
      expect(state.errorMessage, contains('socket closed'));
    });

    test('deduplicates replayed events by event id or sequence', () {
      var state = const AgentStreamRunState().start();
      final replayedEvents = [
        const {
          'type': 'run.started',
          'thread_id': 'thread-fixture-001',
          'run_id': 'run-replay-001',
          'sequence': 1,
        },
        const {
          'type': 'message.delta',
          'thread_id': 'thread-fixture-001',
          'run_id': 'run-replay-001',
          'message_id': 'msg-replay-001',
          'sequence': 2,
          'payload': {'text': 'Already streamed '},
        },
        const {
          'type': 'message.delta',
          'thread_id': 'thread-fixture-001',
          'run_id': 'run-replay-001',
          'message_id': 'msg-replay-001',
          'sequence': 2,
          'payload': {'text': 'Already streamed '},
        },
        const {
          'event_id': 'evt-replay-003',
          'type': 'message.delta',
          'thread_id': 'thread-fixture-001',
          'run_id': 'run-replay-001',
          'message_id': 'msg-replay-001',
          'payload': {'text': 'only once.'},
        },
        const {
          'event_id': 'evt-replay-003',
          'type': 'message.delta',
          'thread_id': 'thread-fixture-001',
          'run_id': 'run-replay-001',
          'message_id': 'msg-replay-001',
          'payload': {'text': 'only once.'},
        },
        const {
          'type': 'run.completed',
          'thread_id': 'thread-fixture-001',
          'run_id': 'run-replay-001',
          'message_id': 'msg-replay-001',
          'sequence': 4,
        },
      ].map(AgentStreamEvent.new);

      for (final event in replayedEvents) {
        state = state.applyEvent(event);
      }

      expect(state.phase, AgentStreamRunPhase.finished);
      expect(state.textContent, 'Already streamed only once.');
      expect(state.events.length, 4);
    });

    test('tracks transient deltas until assistant completed replaces text', () {
      var state = const AgentStreamRunState().start();

      state = state.applyEvent(
        AgentStreamEvent(const {
          'event_id': 'delta:1720000000-0',
          'type': 'message.delta',
          'thread_id': 'thread-transient-001',
          'run_id': 'run-transient-001',
          'transient': true,
          'cursor': '1720000000-0',
          'payload': {'delta': '正在'},
        }),
      );
      state = state.applyEvent(
        AgentStreamEvent(const {
          'event_id': 'delta:1720000000-1',
          'type': 'message.delta',
          'thread_id': 'thread-transient-001',
          'run_id': 'run-transient-001',
          'transient': true,
          'cursor': '1720000000-1',
          'payload': {'delta': '生成'},
        }),
      );

      expect(state.textContent, '正在生成');
      expect(state.provisionalTextContent, '正在生成');
      expect(state.lastSequence, isNull);

      state = state.applyEvent(
        AgentStreamEvent(const {
          'event_id': 'evt-final-001',
          'type': 'message.completed',
          'thread_id': 'thread-transient-001',
          'run_id': 'run-transient-001',
          'message_id': 'msg-final-001',
          'sequence': 4,
          'payload': {
            'role': 'assistant',
            'text': '这是最终回复。',
          },
        }),
      );

      expect(state.textContent, '这是最终回复。');
      expect(state.provisionalTextContent, '');
      expect(state.lastSequence, 4);
    });

    test('keeps repeated text deltas when no replay key is present', () {
      var state = const AgentStreamRunState().start();

      for (final event in [
        const {
          'type': 'message.delta',
          'run_id': 'run-repeat-001',
          'message_id': 'msg-repeat-001',
          'payload': {'text': 'ha '},
        },
        const {
          'type': 'message.delta',
          'run_id': 'run-repeat-001',
          'message_id': 'msg-repeat-001',
          'payload': {'text': 'ha '},
        },
      ].map(AgentStreamEvent.new)) {
        state = state.applyEvent(event);
      }

      expect(state.textContent, 'ha ha ');
      expect(state.events.length, 2);
    });

    test('maps run error events to retryable error state', () {
      var state = const AgentStreamRunState().start();

      state = state.applyEvent(
        AgentStreamEvent(readFixtureMap('agent_events/run_failed.json')),
      );

      expect(state.phase, AgentStreamRunPhase.error);
      expect(state.canRetry, isTrue);
      expect(
        state.errorMessage,
        'The agent stream timed out before a final response.',
      );
    });

    test('preserves waiting-for-confirmation state without retry affordance', () {
      var state = const AgentStreamRunState().start();

      state = state.applyEvent(
        AgentStreamEvent(const {
          'type': 'message.completed',
          'thread_id': 'thread-action-001',
          'run_id': 'run-action-001',
          'message_id': 'msg-action-001',
          'payload': {'text': '请确认是否创建支持工单。'},
        }),
      );
      state = state.applyEvent(
        AgentStreamEvent(const {
          'type': 'run.waiting_for_confirmation',
          'thread_id': 'thread-action-001',
          'run_id': 'run-action-001',
          'message_id': 'msg-action-001',
          'payload': {'pending_action_id': 'action-support-001'},
        }),
      );

      expect(state.phase, AgentStreamRunPhase.waitingForConfirmation);
      expect(state.isActive, isFalse);
      expect(state.canRetry, isFalse);
      expect(state.textContent, '请确认是否创建支持工单。');
      expect(state.runId, 'run-action-001');
    });

    test('merges action events after waiting for confirmation', () {
      var state = const AgentStreamRunState().start();

      state = state.applyEvent(
        AgentStreamEvent(const {
          'type': 'action.confirmation_required',
          'thread_id': 'thread-action-001',
          'run_id': 'run-action-001',
          'sequence': 3,
          'payload': {
            'action_id': 'action-support-001',
            'action_status': 'confirmation_required',
            'action_type': 'support.ticket.create',
            'target_type': 'support_ticket',
            'preview_payload': {'title': '创建售后工单'},
          },
        }),
      );
      state = state.applyEvent(
        AgentStreamEvent(const {
          'type': 'run.waiting_for_confirmation',
          'thread_id': 'thread-action-001',
          'run_id': 'run-action-001',
          'sequence': 4,
          'payload': {'action_id': 'action-support-001'},
        }),
      );

      expect(state.phase, AgentStreamRunPhase.waitingForConfirmation);
      expect(
        state.actionEvents['action-support-001']?.type,
        'action.confirmation_required',
      );

      state = state.applyEvent(
        AgentStreamEvent(const {
          'type': 'action.queued',
          'thread_id': 'thread-action-001',
          'run_id': 'run-action-001',
          'sequence': 5,
          'payload': {
            'action_id': 'action-support-001',
            'action_status': 'confirmed',
            'action_type': 'support.ticket.create',
            'target_type': 'support_ticket',
          },
        }),
      );
      state = state.applyEvent(
        AgentStreamEvent(const {
          'type': 'action.applied',
          'thread_id': 'thread-action-001',
          'run_id': 'run-action-001',
          'sequence': 6,
          'payload': {
            'action_id': 'action-support-001',
            'action_status': 'applied',
            'action_type': 'support.ticket.create',
            'target_type': 'support_ticket',
          },
        }),
      );
      state = state.applyEvent(
        AgentStreamEvent(const {
          'type': 'run.completed',
          'thread_id': 'thread-action-001',
          'run_id': 'run-action-001',
          'sequence': 7,
          'payload': {'action_id': 'action-support-001'},
        }),
      );

      expect(state.phase, AgentStreamRunPhase.finished);
      expect(state.lastSequence, 7);
      expect(state.actionEvents['action-support-001']?.type, 'action.applied');
      expect(state.events.map((event) => event.type), [
        'action.confirmation_required',
        'run.waiting_for_confirmation',
        'action.queued',
        'action.applied',
        'run.completed',
      ]);
    });

    test('indexes tool and artifact lifecycle by stable ids', () {
      var state = const AgentStreamRunState().start();

      for (final event in [
        const {
          'type': 'tool.started',
          'thread_id': 'thread-tool-001',
          'run_id': 'run-tool-001',
          'sequence': 2,
          'payload': {'tool_call_id': 'tool-read-001'},
        },
        const {
          'type': 'tool.completed',
          'thread_id': 'thread-tool-001',
          'run_id': 'run-tool-001',
          'sequence': 3,
          'payload': {'tool_call_id': 'tool-read-001'},
        },
        const {
          'type': 'artifact.created',
          'thread_id': 'thread-tool-001',
          'run_id': 'run-tool-001',
          'sequence': 4,
          'payload': {
            'artifact_id': 'artifact-plan-001',
            'title': '今日计划',
          },
        },
      ].map(AgentStreamEvent.new)) {
        state = state.applyEvent(event);
      }

      expect(state.toolEvents['tool-read-001']?.type, 'tool.completed');
      expect(
        state.artifactEvents['artifact-plan-001']?.type,
        'artifact.created',
      );
      expect(state.lastSequence, 4);
    });

    test('keeps local cancel state even when backend cancel fails', () {
      var state = const AgentStreamRunState().start().requestCancel();

      state = state.applyCancelResult(
        acknowledged: false,
        statusCode: 503,
        error: 'cancel failed',
      );

      expect(state.phase, AgentStreamRunPhase.cancelled);
      expect(state.cancelAcknowledged, isFalse);
      expect(state.cancelStatusCode, 503);
      expect(state.errorMessage, 'cancel failed');
      expect(state.canRetry, isFalse);
    });

    test('records acknowledged cancel responses', () {
      var state = const AgentStreamRunState().start().requestCancel();

      state = state.applyCancelResult(acknowledged: true, statusCode: 404);

      expect(state.phase, AgentStreamRunPhase.cancelled);
      expect(state.cancelAcknowledged, isTrue);
      expect(state.cancelStatusCode, 404);
      expect(state.errorMessage, isNull);
    });

    test('serializes and restores stable replay state', () {
      var state = const AgentStreamRunState().start();
      final events = [
        const {
          'event_id': 'evt-action-1',
          'type': 'action.confirmation_required',
          'thread_id': 'thread-action',
          'run_id': 'run-action',
          'action_id': 'action-1',
          'sequence': 2,
          'payload': {
            'summary': '创建支持工单',
            'preview_payload': {'title': '提交人工支持'},
          },
        },
        const {
          'event_id': 'evt-wait-1',
          'type': 'run.waiting_for_confirmation',
          'thread_id': 'thread-action',
          'run_id': 'run-action',
          'sequence': 3,
        },
      ].map(AgentStreamEvent.new);

      for (final event in events) {
        state = state.applyEvent(event);
      }

      final restored = AgentStreamRunState.fromMap(state.toMap());

      expect(restored.phase, AgentStreamRunPhase.waitingForConfirmation);
      expect(restored.threadId, 'thread-action');
      expect(restored.runId, 'run-action');
      expect(restored.lastSequence, 3);
      expect(restored.events.length, 2);
      expect(restored.actionEvents, contains('action-1'));
      expect(restored.applyEvent(events.last).events.length, 2);
    });
  });
}
