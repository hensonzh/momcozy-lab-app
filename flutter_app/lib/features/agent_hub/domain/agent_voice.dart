import 'dart:convert';

enum AgentVoicePhase {
  idle,
  listening,
  transcribing,
  playing,
  cancelled,
  error,
}

class AgentVoiceState {
  const AgentVoiceState({
    this.phase = AgentVoicePhase.idle,
    this.transcriptDraft = '',
    this.playbackId,
    this.errorMessage,
  });

  final AgentVoicePhase phase;
  final String transcriptDraft;
  final String? playbackId;
  final String? errorMessage;

  bool get isInputActive {
    return phase == AgentVoicePhase.listening ||
        phase == AgentVoicePhase.transcribing;
  }

  bool get isPlaybackActive => phase == AgentVoicePhase.playing;

  AgentVoiceState startListening() {
    return const AgentVoiceState(phase: AgentVoicePhase.listening);
  }

  AgentVoiceState startTranscribing({String draft = ''}) {
    return AgentVoiceState(
      phase: AgentVoicePhase.transcribing,
      transcriptDraft: draft,
    );
  }

  AgentVoiceState applyTranscription(String text) {
    return AgentVoiceState(transcriptDraft: text.trim());
  }

  AgentVoiceState startPlayback(String playbackId) {
    return AgentVoiceState(
      phase: AgentVoicePhase.playing,
      playbackId: playbackId,
      transcriptDraft: transcriptDraft,
    );
  }

  AgentVoiceState cancelPlayback() {
    return AgentVoiceState(
      phase: AgentVoicePhase.cancelled,
      transcriptDraft: transcriptDraft,
    );
  }

  AgentVoiceState fail(Object error) {
    return AgentVoiceState(
      phase: AgentVoicePhase.error,
      transcriptDraft: transcriptDraft,
      errorMessage: error.toString(),
    );
  }
}

enum AgentVoiceSessionEventType { opened, audioChunk, completed, failed }

class AgentVoiceSessionEvent {
  const AgentVoiceSessionEvent({
    required this.type,
    this.sessionId,
    this.sequence,
    this.audioBytes = const <int>[],
    this.message,
  });

  final AgentVoiceSessionEventType type;
  final String? sessionId;
  final int? sequence;
  final List<int> audioBytes;
  final String? message;
}

class AgentVoiceSessionFrameFormatException implements Exception {
  const AgentVoiceSessionFrameFormatException(this.message);

  final String message;

  @override
  String toString() => 'AgentVoiceSessionFrameFormatException($message)';
}

class AgentVoiceSessionDisconnectedException implements Exception {
  const AgentVoiceSessionDisconnectedException({
    required this.code,
    required this.wasClean,
    this.reason,
  });

  final int code;
  final bool wasClean;
  final String? reason;

  @override
  String toString() {
    return 'AgentVoiceSessionDisconnectedException($code, wasClean: $wasClean)';
  }
}

AgentVoiceSessionEvent parseAgentVoiceSessionFrame(String frame) {
  final decoded = jsonDecode(frame);
  if (decoded is! Map) {
    throw const AgentVoiceSessionFrameFormatException(
      'Voice session frame must be an object.',
    );
  }
  final map = Map<String, Object?>.from(decoded);
  final type = _string(map['type'] ?? map['event'])?.trim().toLowerCase();
  final sequence = _int(map['sequence'] ?? map['seq']);
  final sessionId = _string(map['session_id'] ?? map['sessionId']);

  return switch (type) {
    'open' ||
    'opened' ||
    'session.open' ||
    'voice.session.opened' => AgentVoiceSessionEvent(
      type: AgentVoiceSessionEventType.opened,
      sessionId: sessionId,
      sequence: sequence,
    ),
    'audio' || 'audio.chunk' || 'voice.audio.chunk' => AgentVoiceSessionEvent(
      type: AgentVoiceSessionEventType.audioChunk,
      sessionId: sessionId,
      sequence: sequence,
      audioBytes: _audioBytes(map),
    ),
    'done' ||
    'complete' ||
    'completed' ||
    'audio.done' => AgentVoiceSessionEvent(
      type: AgentVoiceSessionEventType.completed,
      sessionId: sessionId,
      sequence: sequence,
    ),
    'error' || 'failed' || 'voice.error' => AgentVoiceSessionEvent(
      type: AgentVoiceSessionEventType.failed,
      sessionId: sessionId,
      sequence: sequence,
      message: _string(map['message'] ?? map['error']),
    ),
    _ => throw AgentVoiceSessionFrameFormatException(
      'Unsupported voice session frame type: $type',
    ),
  };
}

List<int> _audioBytes(Map<String, Object?> map) {
  final base64Value = _string(
    map['audio_base64'] ?? map['audioBase64'] ?? map['data'],
  );
  if (base64Value != null && base64Value.isNotEmpty) {
    return base64Decode(base64Value);
  }
  final bytes = map['bytes'];
  if (bytes is List) {
    return bytes.whereType<int>().toList(growable: false);
  }
  return const <int>[];
}

String? _string(Object? value) => value is String ? value : null;

int? _int(Object? value) => value is int ? value : null;
