import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/motion_voice_command.dart';

void main() {
  test(
    'parses bounded client commands from the official response.done shape',
    () {
      final commands = motionVoiceCommandsFromServerEvent({
        'type': 'response.done',
        'response': {
          'output': [
            {
              'type': 'function_call',
              'name': 'motion_client_command',
              'call_id': 'call-1',
              'arguments': '{"command":"confirm_recalibration"}',
            },
          ],
        },
      });

      expect(commands, hasLength(1));
      expect(commands.single.callId, 'call-1');
      expect(commands.single.type, MotionVoiceCommandType.confirmRecalibration);
    },
  );

  test('supports argument completion events and rejects unknown commands', () {
    final stop = motionVoiceCommandsFromServerEvent({
      'type': 'response.function_call_arguments.done',
      'name': 'motion_client_command',
      'call_id': 'call-2',
      'arguments': '{"command":"stop_assessment","reason":"discomfort"}',
    }).single;
    expect(stop.type, MotionVoiceCommandType.stopAssessment);
    expect(stop.reason, 'discomfort');

    expect(
      motionVoiceCommandsFromServerEvent({
        'type': 'response.function_call_arguments.done',
        'name': 'motion_client_command',
        'call_id': 'call-3',
        'arguments': '{"command":"upload_video"}',
      }),
      isEmpty,
    );
  });

  test('recognizes a completed user audio item for manual model response', () {
    expect(
      completedUserAudioItemIdFromServerEvent({
        'type': 'conversation.item.done',
        'item': {
          'id': 'item-user-1',
          'type': 'message',
          'role': 'user',
          'content': [
            {'type': 'input_audio'},
          ],
        },
      }),
      'item-user-1',
    );
    expect(
      completedUserAudioItemIdFromServerEvent({
        'type': 'conversation.item.done',
        'item': {
          'id': 'item-assistant-1',
          'type': 'message',
          'role': 'assistant',
          'content': [
            {'type': 'output_audio'},
          ],
        },
      }),
      isNull,
    );
  });
}
