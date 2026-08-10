import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/data/motion_realtime_playback_tracker.dart';

void main() {
  test('follows the unified WebRTC output audio buffer lifecycle', () {
    final tracker = MotionRealtimePlaybackTracker();

    expect(
      tracker.handleEventType('output_audio_buffer.started'),
      MotionRealtimePlaybackTransition.speaking,
    );
    expect(tracker.handleEventType('response.output_audio.done'), isNull);
    expect(tracker.handleEventType('response.done'), isNull);
    expect(
      tracker.handleEventType('output_audio_buffer.stopped'),
      MotionRealtimePlaybackTransition.listening,
    );
  });

  test('keeps compatibility with data-channel audio delta events', () {
    final tracker = MotionRealtimePlaybackTracker();

    expect(
      tracker.handleEventType('response.output_audio.delta'),
      MotionRealtimePlaybackTransition.speaking,
    );
    expect(
      tracker.handleEventType('response.done'),
      MotionRealtimePlaybackTransition.listening,
    );
  });
}
