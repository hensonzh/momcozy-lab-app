import 'dart:async';
import 'package:livekit_client/livekit_client.dart' as lk;
import '../../domain/care/consultation_room.dart';
import 'consultation_media.dart';

class LiveKitConsultationMedia extends ConsultationMedia {
  lk.Room? room;
  lk.EventsListener<lk.RoomEvent>? _listener;
  bool _disposed = false;
  int _generation = 0;
  @override
  ConsultationMediaState state = ConsultationMediaState.disconnected;
  @override
  bool sandbox = false;
  @override
  bool busy = false;
  @override
  String? error;
  @override
  bool get microphoneOn =>
      room?.localParticipant?.isMicrophoneEnabled() ?? false;
  @override
  bool get cameraOn => room?.localParticipant?.isCameraEnabled() ?? false;
  @override
  bool get weakNetwork =>
      room?.localParticipant?.connectionQuality == lk.ConnectionQuality.poor;
  @override
  bool get audioPlaybackBlocked => room != null && !room!.canPlaybackAudio;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  Future<void> connect(
    ConsultationCredentials? credentials, {
    required VideoProvider provider,
  }) async {
    await disconnect();
    if (_disposed) return;
    final generation = ++_generation;
    sandbox = provider == VideoProvider.sandbox;
    error = null;
    if (sandbox) {
      state = ConsultationMediaState.connected;
      _notify();
      return;
    }
    if (provider != VideoProvider.livekit ||
        credentials?.serverUrl == null ||
        credentials?.token == null) {
      throw StateError('Video credentials unavailable');
    }
    state = ConsultationMediaState.connecting;
    _notify();
    final current = lk.Room(
      roomOptions: const lk.RoomOptions(adaptiveStream: true, dynacast: true),
    );
    room = current;
    current.addListener(_notify);
    _listener = current.createListener()
      ..on<lk.RoomReconnectingEvent>((_) {
        state = ConsultationMediaState.reconnecting;
        _notify();
      })
      ..on<lk.RoomResumingEvent>((_) {
        state = ConsultationMediaState.reconnecting;
        _notify();
      })
      ..on<lk.RoomReconnectedEvent>((_) {
        state = ConsultationMediaState.connected;
        _notify();
      })
      ..on<lk.RoomDisconnectedEvent>((_) {
        state = ConsultationMediaState.disconnected;
        _notify();
      });
    try {
      await current.connect(credentials!.serverUrl!, credentials.token!);
      if (_disposed || generation != _generation) return;
      state = ConsultationMediaState.connected;
      _notify();
      await _changeDevice(() async {
        await current.localParticipant?.setMicrophoneEnabled(true);
        await current.localParticipant?.setCameraEnabled(true);
      });
    } catch (_) {
      if (generation == _generation && !_disposed) {
        error = '视频连接未能建立，请检查网络后重试。';
        await disconnect();
      }
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    ++_generation;
    final current = room;
    room = null;
    current?.removeListener(_notify);
    final listener = _listener;
    _listener = null;
    await listener?.dispose();
    if (current != null) {
      try {
        await current.disconnect();
      } finally {
        await current.dispose();
      }
    }
    state = ConsultationMediaState.disconnected;
    _notify();
  }

  Future<void> _changeDevice(Future<void> Function() change) async {
    if (_disposed || sandbox || busy) return;
    busy = true;
    error = null;
    _notify();
    try {
      await change();
    } catch (_) {
      error = '未能开启摄像头或麦克风，请检查设备权限后重试。';
    } finally {
      busy = false;
      _notify();
    }
  }

  @override
  Future<void> toggleMicrophone() => _changeDevice(() async {
    await room?.localParticipant?.setMicrophoneEnabled(!microphoneOn);
  });
  @override
  Future<void> toggleCamera() => _changeDevice(() async {
    await room?.localParticipant?.setCameraEnabled(!cameraOn);
  });
  @override
  Future<void> enableAudio() => _changeDevice(() async {
    await room?.startAudio();
  });
  @override
  void dispose() {
    _disposed = true;
    unawaited(disconnect());
    super.dispose();
  }
}
