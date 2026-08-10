import 'dart:async';

typedef MotionRealtimeContextSender =
    Future<void> Function(Map<String, Object?> snapshot);

/// Coalesces high-frequency on-device pose state into a bounded semantic feed.
/// Raw frames and landmarks never enter this publisher.
class MotionRealtimeContextPublisher {
  MotionRealtimeContextPublisher({
    required this.publish,
    this.minimumInterval = const Duration(milliseconds: 500),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final MotionRealtimeContextSender publish;
  final Duration minimumInterval;
  final DateTime Function() _now;

  Timer? _timer;
  DateTime? _lastPublishedAt;
  Map<String, Object?>? _pending;
  Future<void> _operations = Future<void>.value();
  bool _closed = false;

  void add(Map<String, Object?> snapshot, {bool force = false}) {
    if (_closed) return;
    _pending = Map<String, Object?>.unmodifiable(snapshot);
    if (force) {
      _timer?.cancel();
      _timer = null;
      _flush();
      return;
    }

    final lastPublishedAt = _lastPublishedAt;
    if (lastPublishedAt == null) {
      _flush();
      return;
    }
    final elapsed = _now().difference(lastPublishedAt);
    if (elapsed >= minimumInterval) {
      _flush();
      return;
    }
    _timer ??= Timer(minimumInterval - elapsed, () {
      _timer = null;
      _flush();
    });
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _timer?.cancel();
    _timer = null;
    _pending = null;
    await _operations;
  }

  void _flush() {
    if (_closed) return;
    final snapshot = _pending;
    if (snapshot == null) return;
    _pending = null;
    _lastPublishedAt = _now();
    final operation = _operations.then((_) => publish(snapshot));
    _operations = operation.catchError((Object _) {});
  }
}
