import 'dart:convert';

enum MotionVoiceCommandType {
  confirmRecalibration,
  repeatInstruction,
  stopAssessment,
  continueAssessment,
  confirmFinish,
}

class MotionVoiceCommand {
  const MotionVoiceCommand({
    required this.type,
    required this.callId,
    this.reason,
    this.userAudioItemId,
  });

  final MotionVoiceCommandType type;
  final String callId;
  final String? reason;
  final String? userAudioItemId;

  MotionVoiceCommand withUserAudioItemId(String? value) {
    return MotionVoiceCommand(
      type: type,
      callId: callId,
      reason: reason,
      userAudioItemId: value,
    );
  }
}

String? completedUserAudioItemIdFromServerEvent(Map<Object?, Object?> event) {
  final eventType = event['type']?.toString();
  if (eventType != 'conversation.item.added' &&
      eventType != 'conversation.item.created' &&
      eventType != 'conversation.item.done') {
    return null;
  }
  final rawItem = event['item'];
  if (rawItem is! Map ||
      rawItem['type']?.toString() != 'message' ||
      rawItem['role']?.toString() != 'user') {
    return null;
  }
  final content = rawItem['content'];
  if (content is! List ||
      !content.any(
        (part) => part is Map && part['type']?.toString() == 'input_audio',
      )) {
    return null;
  }
  final itemId = rawItem['id']?.toString().trim() ?? '';
  return itemId.isEmpty ? null : itemId;
}

List<MotionVoiceCommand> motionVoiceCommandsFromServerEvent(
  Map<Object?, Object?> event,
) {
  final type = event['type']?.toString();
  if (type == 'response.function_call_arguments.done') {
    final command = _commandFromFunctionCall(event);
    return command == null ? const [] : [command];
  }
  if (type != 'response.done') return const [];
  final response = event['response'];
  if (response is! Map) return const [];
  final output = response['output'];
  if (output is! List) return const [];
  return [
    for (final item in output)
      if (item is Map) ?_commandFromFunctionCall(item),
  ];
}

MotionVoiceCommand? _commandFromFunctionCall(Map<Object?, Object?> item) {
  final itemType = item['type']?.toString();
  if (itemType != null &&
      itemType != 'function_call' &&
      itemType != 'response.function_call_arguments.done') {
    return null;
  }
  if (item['name']?.toString() != 'motion_client_command') return null;
  final callId = item['call_id']?.toString().trim() ?? '';
  final arguments = item['arguments']?.toString() ?? '';
  if (callId.isEmpty || arguments.isEmpty || arguments.length > 4096) {
    return null;
  }
  Object? decoded;
  try {
    decoded = jsonDecode(arguments);
  } on FormatException {
    return null;
  }
  if (decoded is! Map) return null;
  final command = switch (decoded['command']?.toString()) {
    'confirm_recalibration' => MotionVoiceCommandType.confirmRecalibration,
    'repeat_instruction' => MotionVoiceCommandType.repeatInstruction,
    'stop_assessment' => MotionVoiceCommandType.stopAssessment,
    'continue_assessment' => MotionVoiceCommandType.continueAssessment,
    'confirm_finish' => MotionVoiceCommandType.confirmFinish,
    _ => null,
  };
  final rawReason = decoded['reason']?.toString();
  final reason =
      const {
        'user_requested',
        'discomfort',
        'pain',
        'dizziness',
        'numbness',
        'breathing_difficulty',
        'other',
      }.contains(rawReason)
      ? rawReason
      : null;
  return command == null
      ? null
      : MotionVoiceCommand(type: command, callId: callId, reason: reason);
}
