import 'dart:async';

import 'agent_stream_client.dart';
import 'agent_stream_event.dart';
import 'agent_stream_run_state.dart';

class AgentStreamReconnectPolicy {
  const AgentStreamReconnectPolicy({
    this.maxFollowWindowReconnects = 30,
    this.maxTransportReconnects = 3,
    this.maxActiveStatusReconciliations = 1,
    this.transportRetryBaseDelay = const Duration(milliseconds: 200),
  }) : assert(maxFollowWindowReconnects >= 0),
       assert(maxTransportReconnects >= 0),
       assert(maxActiveStatusReconciliations >= 0);

  const AgentStreamReconnectPolicy.disabled()
    : maxFollowWindowReconnects = 0,
      maxTransportReconnects = 0,
      maxActiveStatusReconciliations = 0,
      transportRetryBaseDelay = Duration.zero;

  final int maxFollowWindowReconnects;
  final int maxTransportReconnects;
  final int maxActiveStatusReconciliations;
  final Duration transportRetryBaseDelay;

  bool get enabled =>
      maxFollowWindowReconnects > 0 ||
      maxTransportReconnects > 0 ||
      maxActiveStatusReconciliations > 0;

  Duration transportRetryDelay(int retryIndex) {
    if (transportRetryBaseDelay == Duration.zero) return Duration.zero;
    final multiplier = 1 << retryIndex.clamp(0, 3);
    return transportRetryBaseDelay * multiplier;
  }
}

class AgentStreamConnectionException implements Exception {
  const AgentStreamConnectionException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'AgentStreamConnectionException($message)';
}

class AgentStreamRunner {
  const AgentStreamRunner(
    this.client, {
    this.reconnectPolicy = const AgentStreamReconnectPolicy.disabled(),
    this.runStatusReader,
  });

  final AgentStreamClient client;
  final AgentStreamReconnectPolicy reconnectPolicy;
  final AgentRunStatusReader? runStatusReader;

  Stream<AgentStreamRunState> run(
    AgentStreamRequest request, {
    AgentStreamRunState? initialState,
  }) {
    var cancelled = false;
    final cancellation = Completer<void>();
    StreamIterator<AgentStreamEvent>? activeIterator;
    late final StreamController<AgentStreamRunState> controller;

    Future<void> pump() async {
      var state = initialState ?? const AgentStreamRunState().start();
      var streamRequest = request;
      var followWindowReconnects = 0;
      var transportReconnects = 0;
      var activeStatusReconciliations = 0;
      controller.add(state);

      try {
        while (!cancelled && state.isActive) {
          Object? streamError;
          var madeProgress = false;
          final iterator = StreamIterator(client.stream(streamRequest));
          activeIterator = iterator;
          var iteratorFinished = false;
          try {
            while (!cancelled && await iterator.moveNext()) {
              if (cancelled) return;
              final nextState = state.applyEvent(iterator.current);
              if (identical(nextState, state)) continue;
              madeProgress = true;
              state = nextState;
              controller.add(state);
              if (!state.isActive) return;
            }
            iteratorFinished = true;
          } catch (error) {
            iteratorFinished = true;
            if (!cancelled) streamError = error;
          } finally {
            if (identical(activeIterator, iterator)) {
              activeIterator = null;
              if (!iteratorFinished) await iterator.cancel();
            }
          }

          if (cancelled || !state.isActive) return;
          if (!reconnectPolicy.enabled) {
            state = streamError != null
                ? state.markDisconnected(streamError)
                : state.hasCompletedAssistantMessage
                ? state.finishVisibleReply()
                : state.markDisconnected(
                    StateError('Agent stream ended before a terminal event.'),
                  );
            controller.add(state);
            return;
          }

          final runId = state.runId?.trim();
          if (runId == null || runId.isEmpty) {
            state = state.markDisconnected(
              AgentStreamConnectionException(
                'The stream ended before the run identifier was received.',
                cause: streamError,
              ),
            );
            controller.add(state);
            return;
          }

          if (streamError != null && !_isRetryableFailure(streamError)) {
            state = state.markDisconnected(streamError);
            controller.add(state);
            return;
          }

          if (madeProgress) transportReconnects = 0;
          final reconnectLimitReached = streamError == null
              ? followWindowReconnects >=
                    reconnectPolicy.maxFollowWindowReconnects
              : transportReconnects >= reconnectPolicy.maxTransportReconnects;
          if (reconnectLimitReached) {
            final snapshot = await _readRunStatus(runId);
            if (cancelled) return;
            final terminalEvent = snapshot?.terminalEvent();
            if (terminalEvent != null) {
              state = state.applyEvent(terminalEvent);
              controller.add(state);
              return;
            }
            if (snapshot?.status.isActive == true &&
                activeStatusReconciliations <
                    reconnectPolicy.maxActiveStatusReconciliations) {
              activeStatusReconciliations += 1;
              followWindowReconnects = 0;
              transportReconnects = 0;
            } else {
              state = state.markDisconnected(
                AgentStreamConnectionException(
                  'The connection ended before the run settled.',
                  cause: streamError,
                ),
              );
              controller.add(state);
              return;
            }
          } else if (streamError == null) {
            followWindowReconnects += 1;
            transportReconnects = 0;
          } else {
            final delay = reconnectPolicy.transportRetryDelay(
              transportReconnects,
            );
            transportReconnects += 1;
            if (delay > Duration.zero) {
              await Future.any<void>([
                Future<void>.delayed(delay),
                cancellation.future,
              ]);
              if (cancelled) return;
            }
          }

          streamRequest = request.resume(
            runId: runId,
            threadId: state.threadId,
            afterSequence: state.lastSequence ?? 0,
          );
        }
      } finally {
        if (!controller.isClosed) await controller.close();
      }
    }

    controller = StreamController<AgentStreamRunState>(
      sync: true,
      onListen: () => unawaited(pump()),
      onCancel: () async {
        cancelled = true;
        if (!cancellation.isCompleted) cancellation.complete();
        final iterator = activeIterator;
        activeIterator = null;
        await iterator?.cancel();
      },
    );
    return controller.stream;
  }

  Future<AgentRunStatusSnapshot?> _readRunStatus(String runId) async {
    final reader = runStatusReader;
    if (reader == null) return null;
    try {
      return await reader.read(runId);
    } catch (_) {
      return null;
    }
  }
}

bool _isRetryableFailure(Object error) =>
    error is AgentStreamRetryableFailure && error.isRetryable;
