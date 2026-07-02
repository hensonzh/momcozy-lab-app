import 'agent_stream_event.dart';

enum AgentStreamRunPhase {
  idle,
  streaming,
  finished,
  error,
  disconnected,
  cancelRequested,
  cancelled,
}

class AgentStreamRunState {
  const AgentStreamRunState({
    this.phase = AgentStreamRunPhase.idle,
    this.events = const <AgentStreamEvent>[],
    this.threadId,
    this.runId,
    this.messageId,
    this.textContent = '',
    this.errorMessage,
    this.cancelAcknowledged = false,
    this.cancelStatusCode,
  });

  final AgentStreamRunPhase phase;
  final List<AgentStreamEvent> events;
  final String? threadId;
  final String? runId;
  final String? messageId;
  final String textContent;
  final String? errorMessage;
  final bool cancelAcknowledged;
  final int? cancelStatusCode;

  bool get isActive =>
      phase == AgentStreamRunPhase.streaming ||
      phase == AgentStreamRunPhase.cancelRequested;

  bool get canRetry =>
      phase == AgentStreamRunPhase.error ||
      phase == AgentStreamRunPhase.disconnected;

  AgentStreamRunState start() {
    return const AgentStreamRunState(phase: AgentStreamRunPhase.streaming);
  }

  AgentStreamRunState applyEvent(AgentStreamEvent event) {
    if (!isActive) return this;
    if (_hasSeenReplayKey(event)) return this;

    final type = event.type;
    final nextEvents = List<AgentStreamEvent>.unmodifiable([...events, event]);
    final nextText = type == 'TEXT_MESSAGE_CONTENT'
        ? '$textContent${event.textDelta ?? ''}'
        : textContent;
    final nextThreadId = event.threadId ?? threadId;
    final nextRunId = event.runId ?? runId;
    final nextMessageId = event.messageId ?? messageId;

    if (type == 'RUN_FINISHED') {
      return copyWith(
        phase: AgentStreamRunPhase.finished,
        events: nextEvents,
        threadId: nextThreadId,
        runId: nextRunId,
        messageId: nextMessageId,
        textContent: nextText,
      );
    }

    if (type == 'RUN_ERROR' || type == 'RUN_FAILED' || type == 'ERROR') {
      return copyWith(
        phase: AgentStreamRunPhase.error,
        events: nextEvents,
        threadId: nextThreadId,
        runId: nextRunId,
        messageId: nextMessageId,
        textContent: nextText,
        errorMessage:
            stringField(event.raw, 'message') ??
            stringField(event.raw, 'code') ??
            'Agent stream error.',
      );
    }

    return copyWith(
      phase: AgentStreamRunPhase.streaming,
      events: nextEvents,
      threadId: nextThreadId,
      runId: nextRunId,
      messageId: nextMessageId,
      textContent: nextText,
    );
  }

  bool _hasSeenReplayKey(AgentStreamEvent event) {
    final replayKey = event.replayKey;
    if (replayKey == null || replayKey.isEmpty) return false;
    return events.any((seen) => seen.replayKey == replayKey);
  }

  AgentStreamRunState requestCancel() {
    if (!isActive) return this;
    return copyWith(phase: AgentStreamRunPhase.cancelRequested);
  }

  AgentStreamRunState applyCancelResult({
    required bool acknowledged,
    int? statusCode,
    Object? error,
  }) {
    if (phase != AgentStreamRunPhase.cancelRequested) return this;
    return copyWith(
      phase: AgentStreamRunPhase.cancelled,
      cancelAcknowledged: acknowledged,
      cancelStatusCode: statusCode,
      errorMessage: acknowledged ? null : _stringifyError(error),
    );
  }

  AgentStreamRunState markDisconnected(Object error) {
    if (!isActive) return this;
    return copyWith(
      phase: AgentStreamRunPhase.disconnected,
      errorMessage: _stringifyError(error),
    );
  }

  AgentStreamRunState copyWith({
    AgentStreamRunPhase? phase,
    List<AgentStreamEvent>? events,
    String? threadId,
    String? runId,
    String? messageId,
    String? textContent,
    String? errorMessage,
    bool? cancelAcknowledged,
    int? cancelStatusCode,
  }) {
    return AgentStreamRunState(
      phase: phase ?? this.phase,
      events: events ?? this.events,
      threadId: threadId ?? this.threadId,
      runId: runId ?? this.runId,
      messageId: messageId ?? this.messageId,
      textContent: textContent ?? this.textContent,
      errorMessage: errorMessage ?? this.errorMessage,
      cancelAcknowledged: cancelAcknowledged ?? this.cancelAcknowledged,
      cancelStatusCode: cancelStatusCode ?? this.cancelStatusCode,
    );
  }
}

String? _stringifyError(Object? error) {
  if (error == null) return null;
  if (error is String) return error;
  return error.toString();
}
