/// Local microphone capture and playback only. This contract deliberately has
/// no upload or Agent request operation.
abstract interface class ChatFirstCryAudioSession {
  Stream<Duration> get positionStream;
  Stream<bool> get playingStream;

  Future<void> start();
  Future<Duration> stop();
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> clear();
  Future<void> dispose();
}

typedef ChatFirstCryAudioFactory = ChatFirstCryAudioSession Function();

class ChatFirstCryPermissionException implements Exception {
  const ChatFirstCryPermissionException();
}
