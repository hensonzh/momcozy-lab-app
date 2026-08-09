import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/data/motion_realtime_response_queue.dart';

void main() {
  test(
    'waits for response.done before creating the next default response',
    () async {
      final events = <Map<String, Object?>>[];
      final queue = MotionRealtimeResponseQueue(
        sendEvent: (event) async => events.add(event),
      );

      await queue.enqueue('第一句');
      await queue.enqueue('第二句');

      expect(
        events.where((event) => event['type'] == 'response.create'),
        hasLength(1),
      );
      await queue.handleServerEvent({'type': 'response.output_audio.done'});
      expect(
        events.where((event) => event['type'] == 'response.create'),
        hasLength(1),
      );

      await queue.handleServerEvent({
        'type': 'response.done',
        'response': {'status': 'completed'},
      });

      final creates = events
          .where((event) => event['type'] == 'response.create')
          .toList();
      expect(creates, hasLength(2));
      expect(_instructions(creates.last), contains('第二句'));
    },
  );

  test(
    'interrupt cancels once and waits for cancelled response.done',
    () async {
      final events = <Map<String, Object?>>[];
      final queue = MotionRealtimeResponseQueue(
        sendEvent: (event) async => events.add(event),
      );

      await queue.enqueue('普通提示');
      await queue.enqueue('紧急提示', interrupt: true);

      expect(events.map((event) => event['type']), [
        'response.create',
        'response.cancel',
      ]);

      await queue.handleServerEvent({
        'type': 'response.done',
        'response': {'status': 'cancelled'},
      });

      expect(events.map((event) => event['type']), [
        'response.create',
        'response.cancel',
        'response.create',
      ]);
      expect(_instructions(events.last), contains('紧急提示'));
    },
  );

  test(
    'observes model responses created by VAD before sending local guidance',
    () async {
      final events = <Map<String, Object?>>[];
      final queue = MotionRealtimeResponseQueue(
        sendEvent: (event) async => events.add(event),
      );

      await queue.handleServerEvent({'type': 'response.created'});
      await queue.enqueue('等待用户语音响应完成');
      expect(events, isEmpty);

      await queue.handleServerEvent({
        'type': 'response.done',
        'response': {'status': 'completed'},
      });
      expect(events.single['type'], 'response.create');
    },
  );
}

String _instructions(Map<String, Object?> event) {
  final response = Map<String, Object?>.from(event['response']! as Map);
  return response['instructions']! as String;
}
