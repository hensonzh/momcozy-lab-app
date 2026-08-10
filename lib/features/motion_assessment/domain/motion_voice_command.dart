import 'dart:convert';

import 'package:momcozy_flutter_app/features/motion_assessment/domain/motion_assessment_capability.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/motion_assessment_plan.dart';

enum MotionVoiceCommandType {
  confirmRecalibration,
  repeatInstruction,
  stopAssessment,
  continueAssessment,
  confirmFinish,
  updateAssessmentPlan,
}

class MotionVoiceCommand {
  const MotionVoiceCommand({
    required this.type,
    required this.callId,
    this.reason,
    this.userAudioItemId,
    this.planMutation,
  });

  final MotionVoiceCommandType type;
  final String callId;
  final String? reason;
  final String? userAudioItemId;
  final MotionAssessmentPlanMutation? planMutation;

  MotionVoiceCommand withUserAudioItemId(String? value) {
    return MotionVoiceCommand(
      type: type,
      callId: callId,
      reason: reason,
      userAudioItemId: value,
      planMutation: planMutation,
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
  final functionName = item['name']?.toString() ?? '';
  if (functionName != 'motion_client_command' &&
      functionName != 'motion_assessment_plan') {
    return null;
  }
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
  if (functionName == 'motion_assessment_plan') {
    return _planCommand(decoded, callId: callId);
  }
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

MotionVoiceCommand? _planCommand(
  Map<Object?, Object?> decoded, {
  required String callId,
}) {
  final action = switch (decoded['action']?.toString()) {
    'replace' => MotionAssessmentPlanAction.replace,
    'add' => MotionAssessmentPlanAction.add,
    'remove' => MotionAssessmentPlanAction.remove,
    'confirm' => MotionAssessmentPlanAction.confirm,
    _ => null,
  };
  final rawTargets = decoded['targets'];
  final revision = decoded['expected_revision'];
  if (action == null ||
      rawTargets is! List ||
      rawTargets.length > MotionAssessmentTarget.values.length ||
      revision is! int ||
      revision < 0 ||
      revision > 1000000000) {
    return null;
  }
  final targets = <MotionAssessmentTarget>[];
  for (final raw in rawTargets) {
    final target = MotionAssessmentTargetValue.fromWireValue(
      raw?.toString() ?? '',
    );
    if (target == null) return null;
    if (!targets.contains(target)) targets.add(target);
  }
  return MotionVoiceCommand(
    type: MotionVoiceCommandType.updateAssessmentPlan,
    callId: callId,
    planMutation: MotionAssessmentPlanMutation(
      action: action,
      targets: List.unmodifiable(targets),
      expectedRevision: revision,
    ),
  );
}
