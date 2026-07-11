import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'agent_stream_event.dart';

const _appendOnlyTextStreamSchemaVersion = 'append-only.v1';
const _maxPendingTextSegments = 64;
const _unsetCopyValue = Object();

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
    this.textStreamId,
    this.nextTextSegmentIndex = 0,
    this.pendingTextSegments = const <int, AgentStreamEvent>{},
    this.textIntegrityErrorCode,
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
  final String? textStreamId;
  final int nextTextSegmentIndex;
  final Map<int, AgentStreamEvent> pendingTextSegments;
  final String? textIntegrityErrorCode;
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

  bool get hasTextSegmentGap => pendingTextSegments.isNotEmpty;

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
    final textUpdate = _nextTextStream(event);
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

    final nextState = copyWith(
      phase: AgentStreamRunPhase.streaming,
      events: nextEvents,
      threadId: nextThreadId,
      runId: nextRunId,
      messageId: nextMessageId,
      textContent: textUpdate.textContent,
      provisionalTextContent: textUpdate.provisionalTextContent,
      textStreamId: textUpdate.textStreamId,
      nextTextSegmentIndex: textUpdate.nextSegmentIndex,
      pendingTextSegments: textUpdate.pendingSegments,
      textIntegrityErrorCode: textUpdate.integrityErrorCode,
      toolEvents: nextToolEvents,
      artifactEvents: nextArtifactEvents,
      actionEvents: nextActionEvents,
      quickReplies: nextQuickReplies,
      completedAssistantMessageReceived: nextCompletedAssistantMessage,
      seenReplayKeys: nextSeenReplayKeys,
      lastSequence: nextSequence,
    );

    if (type == 'run.completed') {
      return nextState.copyWith(phase: AgentStreamRunPhase.finished);
    }
    if (type == 'run.cancelled') {
      return nextState.copyWith(
        phase: AgentStreamRunPhase.cancelled,
        cancelAcknowledged: true,
      );
    }
    if (type == 'run.waiting_for_confirmation') {
      return nextState.copyWith(
        phase: AgentStreamRunPhase.waitingForConfirmation,
      );
    }
    if (type == 'run.failed' || type == 'error') {
      return nextState.copyWith(
        phase: AgentStreamRunPhase.error,
        errorMessage:
            stringField(event.raw, 'message') ??
            stringField(event.payload, 'message') ??
            stringField(event.raw, 'code') ??
            stringField(event.payload, 'code') ??
            'Agent stream error.',
      );
    }
    return nextState;
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

  _TextStreamUpdate _nextTextStream(AgentStreamEvent event) {
    if (event.type == 'message.delta') {
      if (event.streamSchemaVersion == _appendOnlyTextStreamSchemaVersion) {
        return _applyIndexedTextDelta(event);
      }
      final delta = event.textDelta ?? '';
      return _TextStreamUpdate(
        textContent: '$textContent$delta',
        provisionalTextContent: event.isTransient
            ? '$provisionalTextContent$delta'
            : provisionalTextContent,
        textStreamId: textStreamId,
        nextSegmentIndex: nextTextSegmentIndex,
        pendingSegments: pendingTextSegments,
        integrityErrorCode: textIntegrityErrorCode,
      );
    }
    if (event.type == 'message.completed' && event.role != 'user') {
      final completedText = event.completedText ?? '';
      final completedStreamId = event.messageStreamId;
      final hasConflict =
          textContent.isNotEmpty &&
          completedText.isNotEmpty &&
          !completedText.startsWith(textContent);
      final hasStreamIdConflict =
          textStreamId != null &&
          completedStreamId != null &&
          textStreamId != completedStreamId;
      final nextText = _finalizedTextContent(textContent, completedText);
      final integrityError = hasConflict
          ? 'completed_text_mismatch'
          : hasStreamIdConflict
          ? 'message_stream_id_mismatch'
          : _completedIntegrityError(event, nextText, nextTextSegmentIndex);
      final completedSegmentCount = event.segmentCount;
      return _TextStreamUpdate(
        textContent: nextText,
        provisionalTextContent: '',
        textStreamId: textStreamId ?? completedStreamId,
        nextSegmentIndex:
            completedSegmentCount != null &&
                completedSegmentCount > nextTextSegmentIndex
            ? completedSegmentCount
            : nextTextSegmentIndex,
        pendingSegments: const <int, AgentStreamEvent>{},
        integrityErrorCode: integrityError,
      );
    }
    return _TextStreamUpdate(
      textContent: textContent,
      provisionalTextContent: provisionalTextContent,
      textStreamId: textStreamId,
      nextSegmentIndex: nextTextSegmentIndex,
      pendingSegments: pendingTextSegments,
      integrityErrorCode: textIntegrityErrorCode,
    );
  }

  _TextStreamUpdate _applyIndexedTextDelta(AgentStreamEvent event) {
    final segmentIndex = event.segmentIndex;
    final incomingStreamId = event.messageStreamId;
    if (segmentIndex == null || segmentIndex < 0 || incomingStreamId == null) {
      return _currentTextUpdate('segment_metadata_missing');
    }
    if (textStreamId != null && textStreamId != incomingStreamId) {
      return _currentTextUpdate('message_stream_id_mismatch');
    }
    if (segmentIndex < nextTextSegmentIndex) {
      return _currentTextUpdate(textIntegrityErrorCode);
    }

    final pending = Map<int, AgentStreamEvent>.from(pendingTextSegments);
    if (!pending.containsKey(segmentIndex)) {
      if (pending.length >= _maxPendingTextSegments) {
        return _currentTextUpdate('segment_buffer_overflow');
      }
      pending[segmentIndex] = event;
    }

    var nextText = textContent;
    var nextProvisionalText = provisionalTextContent;
    var expectedIndex = nextTextSegmentIndex;
    String? integrityError;
    while (true) {
      final nextEvent = pending[expectedIndex];
      if (nextEvent == null) break;
      final delta = nextEvent.textDelta ?? '';
      final candidate = '$nextText$delta';
      integrityError = _segmentIntegrityError(nextEvent, candidate);
      if (integrityError != null) {
        pending.remove(expectedIndex);
        break;
      }
      pending.remove(expectedIndex);
      nextText = candidate;
      if (nextEvent.isTransient) {
        nextProvisionalText = '$nextProvisionalText$delta';
      }
      expectedIndex += 1;
    }
    if (integrityError == null && pending.isNotEmpty) {
      integrityError = 'segment_gap';
    }

    return _TextStreamUpdate(
      textContent: nextText,
      provisionalTextContent: nextProvisionalText,
      textStreamId: textStreamId ?? incomingStreamId,
      nextSegmentIndex: expectedIndex,
      pendingSegments: Map<int, AgentStreamEvent>.unmodifiable(pending),
      integrityErrorCode: integrityError,
    );
  }

  _TextStreamUpdate _currentTextUpdate(String? integrityErrorCode) {
    return _TextStreamUpdate(
      textContent: textContent,
      provisionalTextContent: provisionalTextContent,
      textStreamId: textStreamId,
      nextSegmentIndex: nextTextSegmentIndex,
      pendingSegments: pendingTextSegments,
      integrityErrorCode: integrityErrorCode,
    );
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
    Object? textStreamId = _unsetCopyValue,
    int? nextTextSegmentIndex,
    Map<int, AgentStreamEvent>? pendingTextSegments,
    Object? textIntegrityErrorCode = _unsetCopyValue,
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
      textStreamId: identical(textStreamId, _unsetCopyValue)
          ? this.textStreamId
          : textStreamId as String?,
      nextTextSegmentIndex: nextTextSegmentIndex ?? this.nextTextSegmentIndex,
      pendingTextSegments: pendingTextSegments ?? this.pendingTextSegments,
      textIntegrityErrorCode: identical(textIntegrityErrorCode, _unsetCopyValue)
          ? this.textIntegrityErrorCode
          : textIntegrityErrorCode as String?,
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
    if (_hasValue(textStreamId)) 'textStreamId': textStreamId,
    if (nextTextSegmentIndex > 0) 'nextTextSegmentIndex': nextTextSegmentIndex,
    if (pendingTextSegments.isNotEmpty)
      'pendingTextSegments': pendingTextSegments.map(
        (index, event) => MapEntry(index.toString(), event.raw),
      ),
    if (_hasValue(textIntegrityErrorCode))
      'textIntegrityErrorCode': textIntegrityErrorCode,
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
      textStreamId:
          _string(map['textStreamId']) ?? _string(map['text_stream_id']),
      nextTextSegmentIndex: _nonNegativeInt(
        map['nextTextSegmentIndex'] ?? map['next_text_segment_index'],
      ),
      pendingTextSegments: _pendingTextSegmentsFromMap(
        map['pendingTextSegments'] ?? map['pending_text_segments'],
      ),
      textIntegrityErrorCode:
          _string(map['textIntegrityErrorCode']) ??
          _string(map['text_integrity_error_code']),
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

class _TextStreamUpdate {
  const _TextStreamUpdate({
    required this.textContent,
    required this.provisionalTextContent,
    required this.textStreamId,
    required this.nextSegmentIndex,
    required this.pendingSegments,
    required this.integrityErrorCode,
  });

  final String textContent;
  final String provisionalTextContent;
  final String? textStreamId;
  final int nextSegmentIndex;
  final Map<int, AgentStreamEvent> pendingSegments;
  final String? integrityErrorCode;
}

String _finalizedTextContent(String currentText, String? completedText) {
  final completed = completedText ?? '';
  if (completed.isEmpty) return currentText;
  if (currentText.isEmpty) return completed;
  if (completed.startsWith(currentText)) {
    return '$currentText${completed.substring(currentText.length)}';
  }
  return currentText;
}

String? _segmentIntegrityError(AgentStreamEvent event, String candidateText) {
  final expectedBytes = event.prefixUtf8Bytes;
  final expectedHash = event.prefixSha256?.trim().toLowerCase();
  if (expectedBytes == null || expectedHash == null || expectedHash.isEmpty) {
    return 'segment_integrity_metadata_missing';
  }
  final encodedText = utf8.encode(candidateText);
  if (encodedText.length != expectedBytes) {
    return 'prefix_length_mismatch';
  }
  if (_bytesSha256(encodedText) != expectedHash) {
    return 'prefix_hash_mismatch';
  }
  return null;
}

String? _completedIntegrityError(
  AgentStreamEvent event,
  String completedText,
  int receivedSegmentCount,
) {
  if (event.streamSchemaVersion != _appendOnlyTextStreamSchemaVersion) {
    return null;
  }
  final expectedSegments = event.segmentCount;
  final expectedBytes = event.contentUtf8Bytes;
  final expectedHash = event.contentSha256?.trim().toLowerCase();
  if (expectedSegments == null ||
      expectedBytes == null ||
      expectedHash == null ||
      expectedHash.isEmpty) {
    return 'completed_integrity_metadata_missing';
  }
  if (expectedSegments < receivedSegmentCount) {
    return 'completed_segment_count_mismatch';
  }
  final encodedText = utf8.encode(completedText);
  if (encodedText.length != expectedBytes) {
    return 'completed_length_mismatch';
  }
  if (_bytesSha256(encodedText) != expectedHash) {
    return 'completed_hash_mismatch';
  }
  return null;
}

String _bytesSha256(List<int> bytes) => sha256.convert(bytes).toString();

Map<int, AgentStreamEvent> _pendingTextSegmentsFromMap(Object? value) {
  if (value is! Map) return const <int, AgentStreamEvent>{};
  final pending = <int, AgentStreamEvent>{};
  for (final entry in value.entries) {
    final index = int.tryParse(entry.key.toString());
    final raw = entry.value;
    if (index == null || raw is! Map) continue;
    pending[index] = AgentStreamEvent(Map<String, Object?>.from(raw));
  }
  return Map<int, AgentStreamEvent>.unmodifiable(pending);
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

int _nonNegativeInt(Object? value) {
  final parsed = _int(value) ?? 0;
  return parsed < 0 ? 0 : parsed;
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
