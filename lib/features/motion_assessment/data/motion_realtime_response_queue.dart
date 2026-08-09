import 'dart:async';
import 'dart:collection';

typedef MotionRealtimeEventSender =
    Future<void> Function(Map<String, Object?> event);

class MotionRealtimeResponseQueue {
  MotionRealtimeResponseQueue({required this.sendEvent});

  final MotionRealtimeEventSender sendEvent;
  final Queue<_PendingSpeech> _pending = Queue<_PendingSpeech>();
  Future<void> _operations = Future<void>.value();
  bool _responseActive = false;
  bool _cancelSent = false;
  bool _closed = false;

  Future<void> enqueue(String instruction, {bool interrupt = false}) {
    return _serialize(() async {
      if (_closed || instruction.trim().isEmpty) return;
      final speech = _PendingSpeech(instruction.trim());
      if (interrupt) {
        _pending
          ..clear()
          ..addFirst(speech);
        if (_responseActive) {
          if (!_cancelSent) {
            _cancelSent = true;
            await sendEvent({'type': 'response.cancel'});
          }
          return;
        }
      } else {
        _pending.addLast(speech);
      }
      await _sendNextIfIdle();
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
          'instructions': '请只说下面这句中文，不要添加其他内容：${next.instruction}',
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

class _PendingSpeech {
  const _PendingSpeech(this.instruction);

  final String instruction;
}
