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
    expect(
      motionVoiceCommandsFromServerEvent({
        'type': 'response.function_call_arguments.done',
        'name': 'motion_client_command',
        'call_id': 'call-2',
        'arguments': '{"command":"stop_assessment"}',
      }).single.type,
      MotionVoiceCommandType.stopAssessment,
    );

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
}
