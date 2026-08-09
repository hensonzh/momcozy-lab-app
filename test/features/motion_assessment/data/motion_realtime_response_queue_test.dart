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
    'observes an already-active server response before local guidance',
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

  test('creates a model turn with the latest semantic snapshot', () async {
    final events = <Map<String, Object?>>[];
    final queue = MotionRealtimeResponseQueue(
      sendEvent: (event) async => events.add(event),
    );

    await queue.enqueueModelTurn(
      '基于最新端侧快照回答。motion_assessment.context.v2 sequence=18',
    );

    expect(events, hasLength(1));
    expect(
      _instructions(events.single),
      contains('motion_assessment.context.v2'),
    );
    expect(_instructions(events.single), contains('默认使用简体中文'));
    expect(_instructions(events.single), contains('用户明确要求'));
    expect(_instructions(events.single), isNot(contains('请只说下面这句')));
  });

  test(
    'user speech cancels the active response without adding speech',
    () async {
      final events = <Map<String, Object?>>[];
      final queue = MotionRealtimeResponseQueue(
        sendEvent: (event) async => events.add(event),
      );

      await queue.enqueueModelTurn('回答用户');
      await queue.interrupt();
      await queue.interrupt();

      expect(events.map((event) => event['type']), [
        'response.create',
        'response.cancel',
      ]);
      await queue.handleServerEvent({
        'type': 'response.done',
        'response': {'status': 'cancelled'},
      });
      expect(events, hasLength(2));
    },
  );
}

String _instructions(Map<String, Object?> event) {
  final response = Map<String, Object?>.from(event['response']! as Map);
  return response['instructions']! as String;
}
