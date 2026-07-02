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
  });
}
