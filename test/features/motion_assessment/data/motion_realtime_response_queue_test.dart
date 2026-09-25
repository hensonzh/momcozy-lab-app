import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/data/motion_realtime_response_queue.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/data/motion_realtime_voice.dart';

void main() {
  test('bounds routine assessment guidance to short spoken turns', () {
    expect(
      motionGuidanceTurnInstructions('assessment_started'),
      contains('at most two sentences'),
    );
    expect(
      motionGuidanceTurnInstructions('capture_countdown'),
      contains('Stand still. Three, two, one, start.'),
    );
    expect(
      motionGuidanceTurnInstructions('front_view_required'),
      contains('Face the camera and relax your shoulders.'),
    );
    expect(
      motionGuidanceTurnInstructions('framing_incomplete'),
      contains('under 12 words'),
    );
  });

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
        'output_audio_buffer.clear',
      ]);

      await queue.handleServerEvent({
        'type': 'response.done',
        'response': {'status': 'cancelled'},
      });

      expect(events.map((event) => event['type']), [
        'response.create',
        'response.cancel',
        'output_audio_buffer.clear',
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
      '基于最新端侧快照回答。motion_assessment.context.v3 sequence=18',
    );

    expect(events, hasLength(1));
    expect(
      _instructions(events.single),
      contains('motion_assessment.context.v3'),
    );
    expect(_instructions(events.single), contains('Use English for every response'));
    expect(_instructions(events.single), contains('even if the user asks for another language'));
    expect(_instructions(events.single), isNot(contains('Say only the following line')));
  });

  test('keeps every Realtime response in the Momcozy AI identity', () async {
    final events = <Map<String, Object?>>[];
    final queue = MotionRealtimeResponseQueue(
      sendEvent: (event) async => events.add(event),
    );

    await queue.enqueueModelTurn('回答用户刚才的问题');

    final instructions = _instructions(events.single);
    expect(instructions, contains('the same Momcozy AI identity'));
    expect(instructions, contains('main app conversation'));
    expect(instructions, contains('Do not introduce yourself as a separate coach'));
    expect(instructions, contains('mention internal models'));
  });

  test(
    'keeps each model turn bound to its triggering user audio item',
    () async {
      final events = <Map<String, Object?>>[];
      final queue = MotionRealtimeResponseQueue(
        sendEvent: (event) async => events.add(event),
      );

      await queue.enqueueModelTurn('回答第一轮用户语音', contextId: 'audio-1');
      await queue.enqueueModelTurn('回答第二轮用户语音', contextId: 'audio-2');

      expect(queue.activeContextId, 'audio-1');
      await queue.handleServerEvent({
        'type': 'response.done',
        'response': {'status': 'completed'},
      });
      expect(queue.activeContextId, 'audio-2');
    },
  );

  test('coalesces stale pending guidance and keeps the newest state', () async {
    final events = <Map<String, Object?>>[];
    final queue = MotionRealtimeResponseQueue(
      sendEvent: (event) async => events.add(event),
    );

    await queue.enqueueModelTurn('正在播报的指导');
    await queue.enqueueModelTurn('请进入画面', coalesceKey: 'assessment-guidance');
    await queue.enqueueModelTurn('现在请保持侧身', coalesceKey: 'assessment-guidance');

    await queue.handleServerEvent({
      'type': 'response.done',
      'response': {'status': 'completed'},
    });

    final creates = events
        .where((event) => event['type'] == 'response.create')
        .toList();
    expect(creates, hasLength(2));
    expect(_instructions(creates.last), contains('现在请保持侧身'));
    expect(_instructions(creates.last), isNot(contains('请进入画面')));
  });

  test('a newer state can cancel active guidance in the same lane', () async {
    final events = <Map<String, Object?>>[];
    final queue = MotionRealtimeResponseQueue(
      sendEvent: (event) async => events.add(event),
    );

    await queue.enqueueModelTurn('请进入画面', coalesceKey: 'assessment-guidance');
    await queue.enqueueModelTurn(
      '检测到多人，请先暂停',
      coalesceKey: 'assessment-guidance',
      interruptActive: true,
    );

    expect(events.map((event) => event['type']), [
      'response.create',
      'response.cancel',
      'output_audio_buffer.clear',
    ]);
    await queue.handleServerEvent({
      'type': 'response.done',
      'response': {'status': 'cancelled'},
    });
    expect(_instructions(events.last), contains('检测到多人'));
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
        'output_audio_buffer.clear',
      ]);
      await queue.handleServerEvent({
        'type': 'response.done',
        'response': {'status': 'cancelled'},
      });
      expect(events, hasLength(3));
    },
  );

  test('normal guidance is phrased naturally instead of exact TTS', () async {
    final events = <Map<String, Object?>>[];
    final queue = MotionRealtimeResponseQueue(
      sendEvent: (event) async => events.add(event),
    );

    await queue.enqueue('请自然侧身并目视前方');

    expect(_instructions(events.single), contains('natural, concise English'));
    expect(_instructions(events.single), isNot(contains('Say only the following line')));
  });

  test(
    'releases the active slot when response.create cannot be sent',
    () async {
      final events = <Map<String, Object?>>[];
      var failNext = true;
      final queue = MotionRealtimeResponseQueue(
        sendEvent: (event) async {
          if (failNext) {
            failNext = false;
            throw StateError('data channel closed');
          }
          events.add(event);
        },
      );

      await expectLater(queue.enqueue('发送失败的提示'), throwsStateError);
      await queue.enqueue('重试后的提示');

      expect(events, hasLength(1));
      expect(_instructions(events.single), contains('重试后的提示'));
    },
  );

  test(
    'continues after a stale response.cancel receives a safe server error',
    () async {
      final events = <Map<String, Object?>>[];
      final queue = MotionRealtimeResponseQueue(
        sendEvent: (event) async => events.add(event),
      );

      await queue.enqueue('正在播放的提示');
      await queue.enqueue('下一条提示', interrupt: true);

      final cancel = events.singleWhere(
        (event) => event['type'] == 'response.cancel',
      );
      expect(cancel['event_id'], isA<String>());

      await queue.handleServerEvent({
        'type': 'error',
        'error': {
          'event_id': cancel['event_id'],
          'code': 'response_cancel_not_active',
          'message': 'There is no active response to cancel.',
        },
      });

      final creates = events
          .where((event) => event['type'] == 'response.create')
          .toList();
      expect(creates, hasLength(2));
      expect(_instructions(creates.last), contains('下一条提示'));
    },
  );
}

String _instructions(Map<String, Object?> event) {
  final response = Map<String, Object?>.from(event['response']! as Map);
  return response['instructions']! as String;
}
