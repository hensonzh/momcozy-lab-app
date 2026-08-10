import 'dart:async';
import 'dart:collection';

typedef MotionRealtimeEventSender =
    Future<void> Function(Map<String, Object?> event);

class MotionRealtimeResponseQueue {
  MotionRealtimeResponseQueue({required this.sendEvent});

  final MotionRealtimeEventSender sendEvent;
  final Queue<_PendingResponse> _pending = Queue<_PendingResponse>();
  Future<void> _operations = Future<void>.value();
  bool _responseActive = false;
  bool _cancelSent = false;
  bool _closed = false;

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
            await sendEvent({'type': 'response.cancel'});
            await sendEvent({'type': 'output_audio_buffer.clear'});
          }
          return;
        }
      } else {
        _pending.addLast(speech);
      }
      await _sendNextIfIdle();
    });
  }

  Future<void> enqueueModelTurn(String instructions) {
    return _serialize(() async {
      if (_closed || instructions.trim().isEmpty) return;
      _pending.addLast(_PendingResponse.modelTurn(instructions.trim()));
      await _sendNextIfIdle();
    });
  }

  Future<void> interrupt() {
    return _serialize(() async {
      if (_closed) return;
      _pending.clear();
      if (_responseActive && !_cancelSent) {
        _cancelSent = true;
        await sendEvent({'type': 'response.cancel'});
        await sendEvent({'type': 'output_audio_buffer.clear'});
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
          _responseActive = false;
          _cancelSent = false;
          await _sendNextIfIdle();
      }
    });
  }

  Future<void> close() {
    return _serialize(() async {
      _closed = true;
      _pending.clear();
      _responseActive = false;
      _cancelSent = false;
    });
  }

  Future<void> _sendNextIfIdle() async {
    if (_closed || _responseActive || _pending.isEmpty) return;
    final next = _pending.removeFirst();
    _responseActive = true;
    try {
      await sendEvent({
        'type': 'response.create',
        'response': {
          'output_modalities': ['audio'],
          'instructions': next.exactSpeech
              ? '请只说下面这句中文，不要添加其他内容：${next.instructions}'
              : next.modelTurn
              ? '默认使用简体中文回答；只有用户明确要求使用其他语言时才切换。'
                    '不要因为口音、语气词或孤立的外语词切换语言。'
                    '所有开场、动作指导、工具提示和结果保持同一语言。\n'
                    '${next.instructions}'
              : '请用自然、简短的中文表达下面这条过程指导。保持事实和动作要求不变，'
                    '不要逐字朗读提示词，不要添加诊断或新的要求：${next.instructions}',
        },
      });
    } catch (_) {
      _responseActive = false;
      rethrow;
    }
  }

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
  });

  const _PendingResponse.exactSpeech(String instructions)
    : this._(instructions, exactSpeech: true, modelTurn: false);

  const _PendingResponse.naturalGuidance(String instructions)
    : this._(instructions, exactSpeech: false, modelTurn: false);

  const _PendingResponse.modelTurn(String instructions)
    : this._(instructions, exactSpeech: false, modelTurn: true);

  final String instructions;
  final bool exactSpeech;
  final bool modelTurn;
}
