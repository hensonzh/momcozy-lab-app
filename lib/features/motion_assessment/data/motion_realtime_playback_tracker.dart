enum MotionRealtimePlaybackTransition { speaking, listening }

/// Tracks Realtime playback without assuming that WebRTC audio is delivered as
/// base64 delta events. Unified WebRTC sessions use output_audio_buffer events
/// while the actual audio travels over the remote media track.
class MotionRealtimePlaybackTracker {
  bool _outputBufferPlaying = false;

  MotionRealtimePlaybackTransition? handleEventType(String type) {
    switch (type) {
      case 'output_audio_buffer.started':
        _outputBufferPlaying = true;
        return MotionRealtimePlaybackTransition.speaking;
      case 'response.audio.delta':
      case 'response.output_audio.delta':
        return MotionRealtimePlaybackTransition.speaking;
      case 'output_audio_buffer.stopped':
      case 'output_audio_buffer.cleared':
        _outputBufferPlaying = false;
        return MotionRealtimePlaybackTransition.listening;
      case 'response.done':
      case 'response.audio.done':
      case 'response.output_audio.done':
        return _outputBufferPlaying
            ? null
            : MotionRealtimePlaybackTransition.listening;
      default:
        return null;
    }
  }

  void reset() {
    _outputBufferPlaying = false;
  }
}
