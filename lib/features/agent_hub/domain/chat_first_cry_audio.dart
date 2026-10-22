/// Local microphone capture and playback; the backend classifier receives
/// bytes only after an explicit user submission.
abstract interface class ChatFirstCryAudioSession {
  Stream<Duration> get positionStream;
  Stream<bool> get playingStream;

  Future<void> start();
  Future<Duration> stop();
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<List<int>> readRecording();
  Future<void> clear();
  Future<void> dispose();
}

typedef ChatFirstCryAudioFactory = ChatFirstCryAudioSession Function();

class ChatFirstCryPermissionException implements Exception {
  const ChatFirstCryPermissionException();
}
