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
    this.quickReplies = const <String>[],
    this.completedAssistantMessageReceived = false,
    this._seenReplayKeys = const <String>{},
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
  final List<String> quickReplies;
  final bool completedAssistantMessageReceived;
  final Set<String> _seenReplayKeys;
  final int? lastSequence;
  final String? errorMessage;
  final bool cancelAcknowledged;
  final int? cancelStatusCode;

  bool get isActive =>
      phase == AgentStreamRunPhase.streaming ||
      phase == AgentStreamRunPhase.cancelRequested;

  bool get hasCompletedAssistantMessage =>
      completedAssistantMessageReceived ||
      events.any(_isAssistantCompletedMessage);

  Set<String> get seenReplayKeys => Set<String>.unmodifiable(_seenReplayKeys);

  bool get isAwaitingVisibleReply => isActive && !hasCompletedAssistantMessage;

  bool get blocksComposer =>
      isActive || phase == AgentStreamRunPhase.waitingForConfirmation;

  bool get canRetry =>
      phase == AgentStreamRunPhase.error ||
      phase == AgentStreamRunPhase.disconnected;

  AgentStreamRunState start() {
    return const AgentStreamRunState(phase: AgentStreamRunPhase.streaming);
  }

  AgentStreamRunState finishVisibleReply() {
    if (!isActive || !hasCompletedAssistantMessage) return this;
    return copyWith(phase: AgentStreamRunPhase.finished);
  }

  AgentStreamRunState applyEvent(AgentStreamEvent event) {
    if (!_canApplyEvent(event)) return this;
    if (_hasSeenReplayKey(event)) return this;

    final type = event.type;
    final nextEvents = _shouldRetainEvent(event)
        ? List<AgentStreamEvent>.unmodifiable([...events, event])
        : events;
    final nextText = _nextTextContent(event);
    final nextProvisionalText = _nextProvisionalTextContent(event);
    final nextQuickReplies = _nextQuickReplies(event);
    final nextCompletedAssistantMessage =
        hasCompletedAssistantMessage || _isAssistantCompletedMessage(event);
    final nextSeenReplayKeys = _recordReplayKey(event);
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
        quickReplies: nextQuickReplies,
        completedAssistantMessageReceived: nextCompletedAssistantMessage,
        seenReplayKeys: nextSeenReplayKeys,
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
        quickReplies: nextQuickReplies,
        completedAssistantMessageReceived: nextCompletedAssistantMessage,
        seenReplayKeys: nextSeenReplayKeys,
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
        quickReplies: nextQuickReplies,
        completedAssistantMessageReceived: nextCompletedAssistantMessage,
        seenReplayKeys: nextSeenReplayKeys,
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
        quickReplies: nextQuickReplies,
        completedAssistantMessageReceived: nextCompletedAssistantMessage,
        seenReplayKeys: nextSeenReplayKeys,
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
      quickReplies: nextQuickReplies,
      completedAssistantMessageReceived: nextCompletedAssistantMessage,
      seenReplayKeys: nextSeenReplayKeys,
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
      return event.completedText ?? textContent;
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

  List<String> _nextQuickReplies(AgentStreamEvent event) {
    final replies = event.quickReplies;
    if (replies.isEmpty) return quickReplies;
    if (event.type == 'message.completed' && event.role != 'user') {
      return replies;
    }
    return quickReplies;
  }

  bool _hasSeenReplayKey(AgentStreamEvent event) {
    final replayKey = event.replayKey;
    if (replayKey == null || replayKey.isEmpty) return false;
    if (_seenReplayKeys.contains(replayKey)) return true;
    return _seenReplayKeys.isEmpty &&
        events.any((seen) => seen.replayKey == replayKey);
  }

  Set<String> _recordReplayKey(AgentStreamEvent event) {
    final replayKey = event.replayKey;
    if (replayKey == null || replayKey.isEmpty) return _seenReplayKeys;
    if (_seenReplayKeys.contains(replayKey)) return _seenReplayKeys;

    if (_seenReplayKeys.isEmpty) {
      return _replayKeysFromEvents(events)..add(replayKey);
    }

    _seenReplayKeys.add(replayKey);
    return _seenReplayKeys;
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
    List<String>? quickReplies,
    bool? completedAssistantMessageReceived,
    Set<String>? seenReplayKeys,
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
      quickReplies: quickReplies ?? this.quickReplies,
      completedAssistantMessageReceived:
          completedAssistantMessageReceived ??
          this.completedAssistantMessageReceived,
      seenReplayKeys: seenReplayKeys ?? _seenReplayKeys,
      lastSequence: lastSequence ?? this.lastSequence,
      errorMessage: errorMessage ?? this.errorMessage,
      cancelAcknowledged: cancelAcknowledged ?? this.cancelAcknowledged,
      cancelStatusCode: cancelStatusCode ?? this.cancelStatusCode,
    );
  }

  Map<String, Object?> toMap() => {
    'phase': phase.name,
    if (events.isNotEmpty)
      'events': events.map((event) => event.raw).toList(growable: false),
    if (_hasValue(threadId)) 'threadId': threadId,
    if (_hasValue(runId)) 'runId': runId,
    if (_hasValue(messageId)) 'messageId': messageId,
    if (textContent.isNotEmpty) 'textContent': textContent,
    if (provisionalTextContent.isNotEmpty)
      'provisionalTextContent': provisionalTextContent,
    if (quickReplies.isNotEmpty) 'quickReplies': quickReplies,
    if (hasCompletedAssistantMessage) 'completedAssistantMessageReceived': true,
    if (_seenReplayKeys.isNotEmpty)
      'seenReplayKeys': _seenReplayKeys.toList(growable: false),
    if (lastSequence != null) 'lastSequence': lastSequence,
    if (_hasValue(errorMessage)) 'errorMessage': errorMessage,
    if (cancelAcknowledged) 'cancelAcknowledged': cancelAcknowledged,
    if (cancelStatusCode != null) 'cancelStatusCode': cancelStatusCode,
  };

  static AgentStreamRunState fromMap(Map<String, Object?> map) {
    final events = _eventsFromRawList(map['events']);
    final mappedQuickReplies = _strings(
      map['quickReplies'] ?? map['quick_replies'],
    );
    final seenReplayKeys = {
      ..._strings(map['seenReplayKeys'] ?? map['seen_replay_keys']),
      ..._replayKeysFromEvents(events),
    };
    return AgentStreamRunState(
      phase: _phaseFromName(_string(map['phase'])),
      events: events,
      threadId: _string(map['threadId']) ?? _string(map['thread_id']),
      runId: _string(map['runId']) ?? _string(map['run_id']),
      messageId: _string(map['messageId']) ?? _string(map['message_id']),
      textContent: _string(map['textContent']) ?? '',
      provisionalTextContent: _string(map['provisionalTextContent']) ?? '',
      toolEvents: _indexedEvents(events, (event) => event.toolCallId),
      artifactEvents: _indexedEvents(events, (event) => event.artifactId),
      actionEvents: _indexedEvents(events, (event) => event.actionId),
      quickReplies: mappedQuickReplies.isNotEmpty
          ? mappedQuickReplies
          : _latestQuickReplies(events),
      completedAssistantMessageReceived:
          map['completedAssistantMessageReceived'] == true ||
          map['completed_assistant_message_received'] == true ||
          events.any(_isAssistantCompletedMessage),
      seenReplayKeys: seenReplayKeys,
      lastSequence: _int(map['lastSequence']) ?? _int(map['last_sequence']),
      errorMessage: _string(map['errorMessage']) ?? _string(map['error']),
      cancelAcknowledged: map['cancelAcknowledged'] == true,
      cancelStatusCode:
          _int(map['cancelStatusCode']) ?? _int(map['cancel_status_code']),
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

bool _shouldRetainEvent(AgentStreamEvent event) {
  return event.type != 'message.delta';
}

bool _isAssistantCompletedMessage(AgentStreamEvent event) {
  return event.type == 'message.completed' && event.role != 'user';
}

Set<String> _replayKeysFromEvents(List<AgentStreamEvent> events) {
  final replayKeys = <String>{};
  for (final event in events) {
    final replayKey = event.replayKey;
    if (replayKey != null && replayKey.isNotEmpty) replayKeys.add(replayKey);
  }
  return replayKeys;
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

bool _hasValue(String? value) => value != null && value.trim().isNotEmpty;

String? _string(Object? value) => value is String ? value : null;

int? _int(Object? value) {
  if (value is int) return value;
  if (value is String) return int.tryParse(value.trim());
  return null;
}

List<String> _strings(Object? value) {
  if (value is! List) return const <String>[];
  final strings = <String>[];
  final seen = <String>{};
  for (final item in value) {
    final text = item?.toString().trim() ?? '';
    if (text.isEmpty || seen.contains(text)) continue;
    seen.add(text);
    strings.add(text);
  }
  return List<String>.unmodifiable(strings);
}

List<String> _latestQuickReplies(List<AgentStreamEvent> events) {
  for (final event in events.reversed) {
    final replies = event.quickReplies;
    if (replies.isNotEmpty) return replies;
  }
  return const <String>[];
}

AgentStreamRunPhase _phaseFromName(String? value) {
  for (final phase in AgentStreamRunPhase.values) {
    if (phase.name == value) return phase;
  }
  return AgentStreamRunPhase.idle;
}

List<AgentStreamEvent> _eventsFromRawList(Object? rawEvents) {
  if (rawEvents is! List) return const <AgentStreamEvent>[];
  final events = <AgentStreamEvent>[];
  for (final rawEvent in rawEvents) {
    if (rawEvent is Map) {
      events.add(AgentStreamEvent(Map<String, Object?>.from(rawEvent)));
    }
  }
  return List<AgentStreamEvent>.unmodifiable(events);
}

Map<String, AgentStreamEvent> _indexedEvents(
  List<AgentStreamEvent> events,
  String? Function(AgentStreamEvent event) keyOf,
) {
  final indexed = <String, AgentStreamEvent>{};
  for (final event in events) {
    final key = keyOf(event)?.trim();
    if (key != null && key.isNotEmpty) indexed[key] = event;
  }
  return Map<String, AgentStreamEvent>.unmodifiable(indexed);
}
