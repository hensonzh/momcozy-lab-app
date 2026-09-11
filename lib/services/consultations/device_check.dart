import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

/// Local preview only. These tracks are never published to a room.
class ConsultationDeviceCheck extends ChangeNotifier {
  ConsultationDeviceCheck({
    Future<lk.LocalVideoTrack> Function()? createVideo,
    Future<lk.LocalAudioTrack> Function()? createAudio,
  }) : _createVideo = createVideo ?? lk.LocalVideoTrack.createCameraTrack,
       _createAudio = createAudio ?? lk.LocalAudioTrack.create;
  final Future<lk.LocalVideoTrack> Function() _createVideo;
  final Future<lk.LocalAudioTrack> Function() _createAudio;
  lk.LocalVideoTrack? video;
  lk.LocalAudioTrack? _audio;
  lk.AudioVisualizer? _visualizer;
  lk.EventsListener<lk.AudioVisualizerEvent>? _listener;
  bool busy = false, microphoneAvailable = false;
  double microphoneLevel = 0;
  String? cameraError, microphoneError;
  bool _disposed = false;
  int _generation = 0;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> start() async {
    if (_disposed || busy) return;
    busy = true;
    await close();
    if (_disposed) {
      busy = false;
      return;
    }
    final generation = ++_generation;
    cameraError = microphoneError = null;
    _notify();
    try {
      try {
        final track = await _createVideo();
        if (_disposed || generation != _generation) {
          await _release(track);
          return;
        }
        video = track;
      } catch (_) {
        cameraError = '未能使用摄像头，请检查权限或设备。';
      }
      _notify();
      if (_disposed || generation != _generation) return;
      try {
        final track = await _createAudio();
        if (_disposed || generation != _generation) {
          await _release(track);
          return;
        }
        _audio = track;
        await track.start();
        if (_disposed || generation != _generation) {
          await _release(track);
          return;
        }
        microphoneAvailable = true;
        final visualizer = lk.createVisualizer(
          track,
          options: const lk.AudioVisualizerOptions(barCount: 5),
        );
        _visualizer = visualizer;
        _listener = visualizer.createListener()
          ..on<lk.AudioVisualizerEvent>((event) {
            final values = event.event
                .whereType<num>()
                .map((value) => value.toDouble())
                .toList();
            microphoneLevel = values.isEmpty
                ? 0
                : values.reduce((a, b) => a > b ? a : b).clamp(0, 1);
            _notify();
          });
        try {
          await visualizer.start();
        } catch (_) {
          microphoneError = '麦克风已允许使用，当前设备暂不支持显示输入音量。';
        }
      } catch (_) {
        microphoneError = '未能使用麦克风，请检查权限或设备。';
      }
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> close() async {
    ++_generation;
    final listener = _listener,
        visualizer = _visualizer,
        audio = _audio,
        camera = video;
    _listener = null;
    _visualizer = null;
    _audio = null;
    video = null;
    microphoneAvailable = false;
    microphoneLevel = 0;
    try {
      await listener?.dispose();
    } catch (_) {
      /* Continue releasing device tracks. */
    }
    if (visualizer != null) {
      try {
        await visualizer.stop();
      } catch (_) {
        /* Track cleanup must continue if the level meter failed. */
      }
      try {
        await visualizer.dispose();
      } catch (_) {
        /* Continue releasing device tracks. */
      }
    }
    if (audio != null) await _release(audio);
    if (camera != null) await _release(camera);
    _notify();
  }

  Future<void> _release(lk.Track track) async {
    try {
      await track.stop();
    } catch (_) {
      /* Dispose still releases the remaining resources. */
    }
    try {
      await track.dispose();
    } catch (_) {
      /* A failed device must not prevent other tracks from closing. */
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(close());
    super.dispose();
  }
}
