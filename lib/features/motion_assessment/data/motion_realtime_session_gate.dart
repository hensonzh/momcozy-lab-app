import 'dart:async';

/// Treats a Realtime connection as usable only after signaling, transport,
/// model startup and the remote audio path are all confirmed.
class MotionRealtimeSessionGate {
  final Completer<Object?> _settled = Completer<Object?>();
  bool _dataChannelOpen = false;
  bool _peerConnected = false;
  bool _remoteAudioTrackReady = false;
  bool _sessionCreated = false;
  Object? _failure;

  bool get isReady =>
      _failure == null &&
      _dataChannelOpen &&
      _peerConnected &&
      _remoteAudioTrackReady &&
      _sessionCreated;

  Object? get failure => _failure;

  Future<void> get ready async {
    final failure = await _settled.future;
    if (failure != null) throw failure;
  }

  void markDataChannelOpen() {
    if (_settled.isCompleted) return;
    _dataChannelOpen = true;
    _completeIfReady();
  }

  void markPeerConnected() {
    if (_settled.isCompleted) return;
    _peerConnected = true;
    _completeIfReady();
  }

  void markRemoteAudioTrackReady() {
    if (_settled.isCompleted) return;
    _remoteAudioTrackReady = true;
    _completeIfReady();
  }

  void handleServerEvent(Map<Object?, Object?> event) {
    if (_settled.isCompleted) return;
    switch (event['type']?.toString()) {
      case 'session.created':
        _sessionCreated = true;
        _completeIfReady();
      case 'error':
        final rawError = event['error'];
        final error = rawError is Map
            ? Map<Object?, Object?>.from(rawError)
            : const <Object?, Object?>{};
        fail(
          StateError(
            error['message']?.toString() ??
                'Realtime model session failed before it became ready.',
          ),
        );
    }
  }

  void fail(Object error) {
    if (_settled.isCompleted) return;
    _failure = error;
    _settled.complete(error);
  }

  void _completeIfReady() {
    if (isReady && !_settled.isCompleted) _settled.complete(null);
  }
}
