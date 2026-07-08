import 'dart:convert';

enum AgentVoicePhase {
  idle,
  listening,
  transcribing,
  playing,
  cancelled,
  permissionDenied,
  error,
}

enum AgentVoiceInputPermissionState {
  unknown,
  granted,
  denied,
  permanentlyDenied,
}

enum AgentVoiceInputResultStatus { transcribed, empty, permissionDenied }

enum AgentVoicePlaybackSource {
  autoReply,
  greeting,
  notification,
  manualBubble,
}

enum AgentVoicePlaybackRequestStatus { started, blocked, rejected }

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

  AgentVoiceState markPermissionDenied(
    AgentVoiceInputPermissionState permissionState,
  ) {
    return AgentVoiceState(
      phase: AgentVoicePhase.permissionDenied,
      transcriptDraft: transcriptDraft,
      errorMessage: switch (permissionState) {
        AgentVoiceInputPermissionState.permanentlyDenied => '麦克风权限已关闭',
        _ => '麦克风权限未开启',
      },
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

class AgentVoiceRecording {
  const AgentVoiceRecording({
    required this.name,
    required this.mimeType,
    this.bytes = const <int>[],
    this.path,
    this.durationMs,
  });

  final String name;
  final String mimeType;
  final List<int> bytes;
  final String? path;
  final int? durationMs;

  int get sizeBytes => bytes.length;

  bool get isEmpty {
    return bytes.isEmpty && (path == null || path!.trim().isEmpty);
  }
}

abstract interface class AgentVoiceRecorder {
  Future<AgentVoiceInputPermissionState> permissionState();
  Future<AgentVoiceInputPermissionState> requestPermission();
  Future<void> start();
  Future<AgentVoiceRecording?> stop();
  Future<void> cancel();
}

abstract interface class AgentVoiceTranscriber {
  Future<String?> transcribe(AgentVoiceRecording recording);
}

class AgentVoiceInputResult {
  const AgentVoiceInputResult._({
    required this.status,
    this.text,
    this.permissionState,
  });

  factory AgentVoiceInputResult.fromText(String? text) {
    final trimmed = text?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return const AgentVoiceInputResult.empty();
    }
    return AgentVoiceInputResult._(
      status: AgentVoiceInputResultStatus.transcribed,
      text: trimmed,
    );
  }

  const AgentVoiceInputResult.empty()
    : this._(status: AgentVoiceInputResultStatus.empty);

  const AgentVoiceInputResult.permissionDenied(
    AgentVoiceInputPermissionState permissionState,
  ) : this._(
        status: AgentVoiceInputResultStatus.permissionDenied,
        permissionState: permissionState,
      );

  final AgentVoiceInputResultStatus status;
  final String? text;
  final AgentVoiceInputPermissionState? permissionState;
}

class AgentVoiceInputController {
  const AgentVoiceInputController({
    required this.recorder,
    required this.transcriber,
  });

  final AgentVoiceRecorder recorder;
  final AgentVoiceTranscriber transcriber;

  Future<AgentVoiceInputResult> captureAndTranscribe() async {
    final permission = await _ensurePermission();
    if (permission != AgentVoiceInputPermissionState.granted) {
      return AgentVoiceInputResult.permissionDenied(permission);
    }

    var recordingStarted = false;
    var recordingStopped = false;
    try {
      await recorder.start();
      recordingStarted = true;
      final recording = await recorder.stop();
      recordingStopped = true;
      if (recording == null || recording.isEmpty) {
        return const AgentVoiceInputResult.empty();
      }
      return AgentVoiceInputResult.fromText(
        await transcriber.transcribe(recording),
      );
    } catch (_) {
      if (recordingStarted && !recordingStopped) {
        await _cancelRecorderQuietly();
      }
      rethrow;
    }
  }

  Future<AgentVoiceInputPermissionState> _ensurePermission() async {
    final current = await recorder.permissionState();
    if (current == AgentVoiceInputPermissionState.granted ||
        current == AgentVoiceInputPermissionState.permanentlyDenied) {
      return current;
    }
    return recorder.requestPermission();
  }

  Future<void> _cancelRecorderQuietly() async {
    try {
      await recorder.cancel();
    } catch (_) {
      // Best-effort cleanup; preserve the original recording/transcription error.
    }
  }
}

class AgentVoicePlaybackRequestResult {
  const AgentVoicePlaybackRequestResult._({
    required this.status,
    this.handle,
    this.activeId,
    this.activeSource,
  });

  factory AgentVoicePlaybackRequestResult.started(
    AgentVoicePlaybackHandle handle,
  ) {
    return AgentVoicePlaybackRequestResult._(
      status: AgentVoicePlaybackRequestStatus.started,
      handle: handle,
    );
  }

  factory AgentVoicePlaybackRequestResult.blocked({
    required String activeId,
    required AgentVoicePlaybackSource activeSource,
  }) {
    return AgentVoicePlaybackRequestResult._(
      status: AgentVoicePlaybackRequestStatus.blocked,
      activeId: activeId,
      activeSource: activeSource,
    );
  }

  const AgentVoicePlaybackRequestResult.rejected()
    : this._(status: AgentVoicePlaybackRequestStatus.rejected);

  final AgentVoicePlaybackRequestStatus status;
  final AgentVoicePlaybackHandle? handle;
  final String? activeId;
  final AgentVoicePlaybackSource? activeSource;
}

class AgentVoicePlaybackHandle {
  AgentVoicePlaybackHandle._({
    required this.id,
    required this.source,
    required this.token,
    required this._coordinator,
  });

  final String id;
  final AgentVoicePlaybackSource source;
  final int token;
  final AgentVoicePlaybackCoordinator _coordinator;

  bool get isCurrent => _coordinator._active?.token == token;

  void finish() {
    if (!isCurrent) return;
    _coordinator._finishActive(runCancel: false);
  }

  bool cancel() {
    return _coordinator.cancel(handle: this);
  }
}

class AgentVoicePlaybackCoordinator {
  AgentVoicePlaybackCoordinator();

  _ActiveAgentVoicePlayback? _active;
  int _nextToken = 0;
  final Set<void Function()> _idleListeners = <void Function()>{};

  AgentVoicePlaybackSource? get activeSource => _active?.source;

  String? get activeId => _active?.id;

  AgentVoicePlaybackRequestResult request({
    required String id,
    required AgentVoicePlaybackSource source,
    void Function()? cancel,
    int? priority,
  }) {
    final playbackId = id.trim();
    if (playbackId.isEmpty) {
      return const AgentVoicePlaybackRequestResult.rejected();
    }

    final requestedPriority = priority ?? _sourcePriority(source);
    final current = _active;
    if (current != null) {
      if (requestedPriority < current.priority) {
        return AgentVoicePlaybackRequestResult.blocked(
          activeId: current.id,
          activeSource: current.source,
        );
      }
      _finishActive(runCancel: true, notifyIdle: false);
    }

    _nextToken += 1;
    final handle = AgentVoicePlaybackHandle._(
      id: playbackId,
      source: source,
      token: _nextToken,
      coordinator: this,
    );
    _active = _ActiveAgentVoicePlayback(
      id: playbackId,
      source: source,
      token: _nextToken,
      priority: requestedPriority,
      cancel: cancel,
    );
    return AgentVoicePlaybackRequestResult.started(handle);
  }

  bool cancel({
    AgentVoicePlaybackHandle? handle,
    Set<AgentVoicePlaybackSource> preserveSources =
        const <AgentVoicePlaybackSource>{},
  }) {
    final current = _active;
    if (current == null) return false;
    if (handle != null && handle.token != current.token) return false;
    if (preserveSources.contains(current.source)) return false;
    _finishActive(runCancel: true);
    return true;
  }

  void Function() subscribeIdle(void Function() listener) {
    _idleListeners.add(listener);
    return () {
      _idleListeners.remove(listener);
    };
  }

  void _finishActive({required bool runCancel, bool notifyIdle = true}) {
    final current = _active;
    if (current == null) return;
    _active = null;
    if (runCancel) current.cancel?.call();
    if (notifyIdle) {
      for (final listener in [..._idleListeners]) {
        listener();
      }
    }
  }
}

class _ActiveAgentVoicePlayback {
  const _ActiveAgentVoicePlayback({
    required this.id,
    required this.source,
    required this.token,
    required this.priority,
    this.cancel,
  });

  final String id;
  final AgentVoicePlaybackSource source;
  final int token;
  final int priority;
  final void Function()? cancel;
}

int _sourcePriority(AgentVoicePlaybackSource source) {
  return switch (source) {
    AgentVoicePlaybackSource.autoReply => 50,
    AgentVoicePlaybackSource.greeting => 70,
    AgentVoicePlaybackSource.notification => 90,
    AgentVoicePlaybackSource.manualBubble => 100,
  };
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
