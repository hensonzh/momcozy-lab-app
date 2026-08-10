import 'dart:async';
import 'dart:collection';

typedef MotionRealtimeEventSender =
    Future<void> Function(Map<String, Object?> event);

const _cozyMateIdentityInstructions =
    '你始终以 CozyMate 的同一身份回应用户，延续 App 主对话中温和、自然、直接的语气。'
    '不要自称独立教练，也不要提及内部模型、智能体分工、角色切换或结果交接。';

class MotionRealtimeResponseQueue {
  MotionRealtimeResponseQueue({required this.sendEvent});

  final MotionRealtimeEventSender sendEvent;
  final Queue<_PendingResponse> _pending = Queue<_PendingResponse>();
  Future<void> _operations = Future<void>.value();
  bool _responseActive = false;
  bool _cancelSent = false;
  bool _closed = false;
  int _clientEventSequence = 0;
  String? _activeContextId;
  String? _activeCoalesceKey;
  String? _activeCreateEventId;
  final Map<String, String> _pendingControlEventIds = {};

  String? get activeContextId => _activeContextId;

  Future<void> enqueue(
    String instruction, {
    bool interrupt = false,
    bool exact = false,
  }) {
    return _serialize(() async {
      if (_closed || instruction.trim().isEmpty) return;
      final speech = exact
          ? _PendingResponse.exactSpeech(instruction.trim())
          : _PendingResponse.naturalGuidance(instruction.trim());
      if (interrupt) {
        _pending
          ..clear()
          ..addFirst(speech);
        if (_responseActive) {
          if (!_cancelSent) {
            _cancelSent = true;
            await _sendCancelAndClear();
          }
          return;
        }
      } else {
        _pending.addLast(speech);
      }
      await _sendNextIfIdle();
    });
  }

  Future<void> enqueueModelTurn(
    String instructions, {
    String? contextId,
    String? coalesceKey,
    bool interruptActive = false,
  }) {
    return _serialize(() async {
      if (_closed || instructions.trim().isEmpty) return;
      final normalizedKey = coalesceKey?.trim();
      if (normalizedKey?.isNotEmpty == true) {
        _pending.removeWhere(
          (response) => response.coalesceKey == normalizedKey,
        );
      }
      final response = _PendingResponse.modelTurn(
        instructions.trim(),
        contextId: contextId,
        coalesceKey: normalizedKey?.isNotEmpty == true ? normalizedKey : null,
      );
      if (interruptActive &&
          _responseActive &&
          _activeCoalesceKey == response.coalesceKey &&
          response.coalesceKey != null) {
        _pending.addFirst(response);
        if (!_cancelSent) {
          _cancelSent = true;
          await _sendCancelAndClear();
        }
        return;
      }
      _pending.addLast(response);
      await _sendNextIfIdle();
    });
  }

  Future<void> interrupt() {
    return _serialize(() async {
      if (_closed) return;
      _pending.clear();
      if (_responseActive && !_cancelSent) {
        _cancelSent = true;
        await _sendCancelAndClear();
      }
    });
  }

  Future<void> handleServerEvent(Map<Object?, Object?> event) {
    return _serialize(() async {
      if (_closed) return;
      switch (event['type']?.toString()) {
        case 'response.created':
          _responseActive = true;
        case 'response.done':
          _resetActiveResponse();
          await _sendNextIfIdle();
        case 'error':
          await _handleServerError(event);
      }
    });
  }

  Future<void> close() {
    return _serialize(() async {
      _closed = true;
      _pending.clear();
      _resetActiveResponse();
    });
  }

  Future<void> _sendNextIfIdle() async {
    if (_closed || _responseActive || _pending.isEmpty) return;
    final next = _pending.removeFirst();
    _responseActive = true;
    _activeContextId = next.contextId;
    _activeCoalesceKey = next.coalesceKey;
    final createEventId = _nextClientEventId('response-create');
    _activeCreateEventId = createEventId;
    final responseInstructions = next.exactSpeech
        ? '请只说下面这句中文，不要添加其他内容：${next.instructions}'
        : next.modelTurn
        ? '默认使用简体中文回答；只有用户明确要求使用其他语言时才切换。'
              '不要因为口音、语气词或孤立的外语词切换语言。'
              '所有开场、动作指导、工具提示和结果保持同一语言。\n'
              '${next.instructions}'
        : '请用自然、简短的中文表达下面这条过程指导。保持事实和动作要求不变，'
              '不要逐字朗读提示词，不要添加诊断或新的要求：${next.instructions}';
    try {
      await sendEvent({
        'event_id': createEventId,
        'type': 'response.create',
        'response': {
          'output_modalities': ['audio'],
          'instructions':
              '$_cozyMateIdentityInstructions\n$responseInstructions',
        },
      });
    } catch (_) {
      _resetActiveResponse();
      rethrow;
    }
  }

  Future<void> _sendCancelAndClear() async {
    final cancelEventId = _nextClientEventId('response-cancel');
    final clearEventId = _nextClientEventId('audio-clear');
    _pendingControlEventIds[cancelEventId] = 'response.cancel';
    _pendingControlEventIds[clearEventId] = 'output_audio_buffer.clear';
    await sendEvent({'event_id': cancelEventId, 'type': 'response.cancel'});
    await sendEvent({
      'event_id': clearEventId,
      'type': 'output_audio_buffer.clear',
    });
  }

  Future<void> _handleServerError(Map<Object?, Object?> event) async {
    final rawError = event['error'];
    final error = rawError is Map
        ? Map<Object?, Object?>.from(rawError)
        : const <Object?, Object?>{};
    final correlatedEventId =
        error['event_id']?.toString() ?? event['event_id']?.toString();
    if (correlatedEventId == null || correlatedEventId.isEmpty) return;
    if (correlatedEventId == _activeCreateEventId) {
      _resetActiveResponse();
      await _sendNextIfIdle();
      return;
    }
    final controlType = _pendingControlEventIds.remove(correlatedEventId);
    if (controlType == 'response.cancel' && _isNoActiveResponseError(error)) {
      // OpenAI documents this race as safe: the response ended between the
      // local state check and response.cancel. Release the local slot instead
      // of treating the still-healthy Realtime session as disconnected.
      _resetActiveResponse();
      await _sendNextIfIdle();
    }
  }

  bool _isNoActiveResponseError(Map<Object?, Object?> error) {
    final diagnostic = [
      error['code'],
      error['type'],
      error['message'],
    ].whereType<Object>().join(' ').toLowerCase();
    return diagnostic.contains('response_cancel_not_active') ||
        diagnostic.contains('no active response') ||
        diagnostic.contains('no response to cancel');
  }

  void _resetActiveResponse() {
    _responseActive = false;
    _cancelSent = false;
    _activeContextId = null;
    _activeCoalesceKey = null;
    _activeCreateEventId = null;
    _pendingControlEventIds.clear();
  }

  String _nextClientEventId(String kind) =>
      'motion-$kind-${++_clientEventSequence}';

  Future<void> _serialize(Future<void> Function() operation) {
    final result = _operations.then((_) => operation());
    _operations = result.catchError((Object _) {});
    return result;
  }
}

class _PendingResponse {
  const _PendingResponse._(
    this.instructions, {
    required this.exactSpeech,
    required this.modelTurn,
    this.contextId,
    this.coalesceKey,
  });

  const _PendingResponse.exactSpeech(String instructions)
    : this._(instructions, exactSpeech: true, modelTurn: false);

  const _PendingResponse.naturalGuidance(String instructions)
    : this._(instructions, exactSpeech: false, modelTurn: false);

  const _PendingResponse.modelTurn(
    String instructions, {
    String? contextId,
    String? coalesceKey,
  }) : this._(
         instructions,
         exactSpeech: false,
         modelTurn: true,
         contextId: contextId,
         coalesceKey: coalesceKey,
       );

  final String instructions;
  final bool exactSpeech;
  final bool modelTurn;
  final String? contextId;
  final String? coalesceKey;
}
