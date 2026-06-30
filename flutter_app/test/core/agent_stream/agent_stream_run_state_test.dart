import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_event.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_run_state.dart';

import '../../support/fixture_reader.dart';

void main() {
  group('AgentStreamRunState', () {
    test('accumulates streamed text and finishes on terminal events', () {
      var state = const AgentStreamRunState().start();

      for (final event in parseAgentJsonl(
        readMigrationFixture('ag_ui/text_stream_basic.jsonl'),
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
      expect(state.events.length, 6);

      final afterTerminal = state.applyEvent(
        AgentStreamEvent(readFixtureMap('ag_ui/run_error.json')),
      );

      expect(afterTerminal.phase, AgentStreamRunPhase.finished);
      expect(afterTerminal.events.length, 6);
    });

    test('preserves partial text and marks disconnect as retryable', () {
      var state = const AgentStreamRunState().start();
      final events = parseAgentJsonl(
        readMigrationFixture('ag_ui/text_stream_basic.jsonl'),
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

    test('maps run error events to retryable error state', () {
      var state = const AgentStreamRunState().start();

      state = state.applyEvent(
        AgentStreamEvent(readFixtureMap('ag_ui/run_error.json')),
      );

      expect(state.phase, AgentStreamRunPhase.error);
      expect(state.canRetry, isTrue);
      expect(
        state.errorMessage,
        'The agent stream timed out before a final response.',
      );
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
