import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/data/motion_realtime_session_gate.dart';

void main() {
  test('is not ready until transport and OpenAI session are both ready', () {
    final gate = MotionRealtimeSessionGate();

    gate.markDataChannelOpen();
    expect(gate.isReady, isFalse);

    gate.handleServerEvent({'type': 'session.created'});
    expect(gate.isReady, isTrue);
  });

  test('also becomes ready when session.created arrives before open', () {
    final gate = MotionRealtimeSessionGate();

    gate.handleServerEvent({'type': 'session.created'});
    expect(gate.isReady, isFalse);

    gate.markDataChannelOpen();
    expect(gate.isReady, isTrue);
  });

  test('ignores unrelated lifecycle events while connecting', () {
    final gate = MotionRealtimeSessionGate();

    gate.markDataChannelOpen();
    gate.handleServerEvent({'type': 'rate_limits.updated'});

    expect(gate.isReady, isFalse);
  });

  test('surfaces a server error before the model session becomes ready', () {
    final gate = MotionRealtimeSessionGate();

    gate.markDataChannelOpen();
    gate.handleServerEvent({
      'type': 'error',
      'error': {'message': 'model unavailable'},
    });

    expect(gate.failure, isA<StateError>());
    expect(gate.isReady, isFalse);
  });
}
