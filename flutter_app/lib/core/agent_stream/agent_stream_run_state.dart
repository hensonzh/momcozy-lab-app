import 'agent_stream_event.dart';

enum AgentStreamRunPhase {
  idle,
  streaming,
  waitingForConfirmation,
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
    this.provisionalTextContent = '',
    this.toolEvents = const <String, AgentStreamEvent>{},
    this.artifactEvents = const <String, AgentStreamEvent>{},
    this.actionEvents = const <String, AgentStreamEvent>{},
    this.lastSequence,
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
  final String provisionalTextContent;
  final Map<String, AgentStreamEvent> toolEvents;
  final Map<String, AgentStreamEvent> artifactEvents;
  final Map<String, AgentStreamEvent> actionEvents;
  final int? lastSequence;
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
    if (!_canApplyEvent(event)) return this;
    if (_hasSeenReplayKey(event)) return this;

    final type = event.type;
    final nextEvents = List<AgentStreamEvent>.unmodifiable([...events, event]);
    final nextText = _nextTextContent(event);
    final nextProvisionalText = _nextProvisionalTextContent(event);
    final nextThreadId = event.threadId ?? threadId;
    final nextRunId = event.runId ?? runId;
    final nextMessageId = event.messageId ?? messageId;
    final nextToolEvents = event.type.startsWith('tool.')
        ? _nextIndexedEvents(toolEvents, event.toolCallId, event)
        : toolEvents;
    final nextArtifactEvents = _nextIndexedEvents(
      artifactEvents,
      event.type.startsWith('artifact.') ? event.artifactId : null,
      event,
    );
    final nextActionEvents = _nextIndexedEvents(
      actionEvents,
      event.type.startsWith('action.') ? event.actionId : null,
      event,
    );
    final nextSequence = _maxSequence(lastSequence, event.sequence);

    if (type == 'run.completed') {
      return copyWith(
        phase: AgentStreamRunPhase.finished,
        events: nextEvents,
        threadId: nextThreadId,
        runId: nextRunId,
        messageId: nextMessageId,
        textContent: nextText,
        provisionalTextContent: nextProvisionalText,
        toolEvents: nextToolEvents,
        artifactEvents: nextArtifactEvents,
        actionEvents: nextActionEvents,
        lastSequence: nextSequence,
      );
    }

    if (type == 'run.cancelled') {
      return copyWith(
        phase: AgentStreamRunPhase.cancelled,
        events: nextEvents,
        threadId: nextThreadId,
        runId: nextRunId,
        messageId: nextMessageId,
        textContent: nextText,
        provisionalTextContent: nextProvisionalText,
        toolEvents: nextToolEvents,
        artifactEvents: nextArtifactEvents,
        actionEvents: nextActionEvents,
        lastSequence: nextSequence,
        cancelAcknowledged: true,
      );
    }

    if (type == 'run.waiting_for_confirmation') {
      return copyWith(
        phase: AgentStreamRunPhase.waitingForConfirmation,
        events: nextEvents,
        threadId: nextThreadId,
        runId: nextRunId,
        messageId: nextMessageId,
        textContent: nextText,
        provisionalTextContent: nextProvisionalText,
        toolEvents: nextToolEvents,
        artifactEvents: nextArtifactEvents,
        actionEvents: nextActionEvents,
        lastSequence: nextSequence,
      );
    }

    if (type == 'run.failed' || type == 'error') {
      return copyWith(
        phase: AgentStreamRunPhase.error,
        events: nextEvents,
        threadId: nextThreadId,
        runId: nextRunId,
        messageId: nextMessageId,
        textContent: nextText,
        provisionalTextContent: nextProvisionalText,
        toolEvents: nextToolEvents,
        artifactEvents: nextArtifactEvents,
        actionEvents: nextActionEvents,
        lastSequence: nextSequence,
        errorMessage:
            stringField(event.raw, 'message') ??
            stringField(event.payload, 'message') ??
            stringField(event.raw, 'code') ??
            stringField(event.payload, 'code') ??
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
      provisionalTextContent: nextProvisionalText,
      toolEvents: nextToolEvents,
      artifactEvents: nextArtifactEvents,
      actionEvents: nextActionEvents,
      lastSequence: nextSequence,
    );
  }

  bool _canApplyEvent(AgentStreamEvent event) {
    if (isActive) return true;
    if (phase != AgentStreamRunPhase.waitingForConfirmation) return false;
    return event.type.startsWith('action.') ||
        event.type == 'message.completed' ||
        event.type == 'run.completed' ||
        event.type == 'run.failed' ||
        event.type == 'run.cancelled';
  }

  String _nextTextContent(AgentStreamEvent event) {
    final type = event.type;
    if (type == 'message.delta') {
      return '$textContent${event.textDelta ?? ''}';
    }
    if (type == 'message.completed' && event.role != 'user') {
      return event.textDelta ?? textContent;
    }
    return textContent;
  }

  String _nextProvisionalTextContent(AgentStreamEvent event) {
    if (event.type == 'message.delta' && event.isTransient) {
      return '$provisionalTextContent${event.textDelta ?? ''}';
    }
    if (event.type == 'message.completed' && event.role != 'user') {
      return '';
    }
    return provisionalTextContent;
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
    String? provisionalTextContent,
    Map<String, AgentStreamEvent>? toolEvents,
    Map<String, AgentStreamEvent>? artifactEvents,
    Map<String, AgentStreamEvent>? actionEvents,
    int? lastSequence,
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
      provisionalTextContent:
          provisionalTextContent ?? this.provisionalTextContent,
      toolEvents: toolEvents ?? this.toolEvents,
      artifactEvents: artifactEvents ?? this.artifactEvents,
      actionEvents: actionEvents ?? this.actionEvents,
      lastSequence: lastSequence ?? this.lastSequence,
      errorMessage: errorMessage ?? this.errorMessage,
      cancelAcknowledged: cancelAcknowledged ?? this.cancelAcknowledged,
      cancelStatusCode: cancelStatusCode ?? this.cancelStatusCode,
    );
  }
}

Map<String, AgentStreamEvent> _nextIndexedEvents(
  Map<String, AgentStreamEvent> current,
  String? id,
  AgentStreamEvent event,
) {
  final normalizedId = id?.trim();
  if (normalizedId == null || normalizedId.isEmpty) return current;
  return Map<String, AgentStreamEvent>.unmodifiable({
    ...current,
    normalizedId: event,
  });
}

int? _maxSequence(int? current, int? next) {
  if (next == null) return current;
  if (current == null || next > current) return next;
  return current;
}

String? _stringifyError(Object? error) {
  if (error == null) return null;
  if (error is String) return error;
  return error.toString();
}
