import 'package:flutter/foundation.dart';
import '../../domain/care/consultation_room.dart';

enum ConsultationMediaState {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

abstract class ConsultationMedia extends ChangeNotifier {
  ConsultationMediaState get state;
  bool get microphoneOn;
  bool get cameraOn;
  bool get sandbox;
  bool get busy;
  bool get weakNetwork;
  bool get audioPlaybackBlocked;
  String? get error;
  Future<void> connect(
    ConsultationCredentials? credentials, {
    required VideoProvider provider,
  });
  Future<void> disconnect();
  Future<void> toggleMicrophone();
  Future<void> toggleCamera();
  Future<void> enableAudio();
}
