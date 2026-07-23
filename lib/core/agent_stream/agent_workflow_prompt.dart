class AgentWorkflowPrompt {
  const AgentWorkflowPrompt({
    required this.schemaVersion,
    required this.workflowType,
    required this.status,
    required this.phase,
    required this.currentStep,
    this.editableSteps = const <AgentWorkflowEditableStep>[],
    this.allowedCommands = const <String>{},
  });

  static const pregnancyPlanSchemaVersion =
      'pregnancy_plan_workflow_context.v1';
  static const pregnancyPlanWorkflowType = 'pregnancy_plan';

  final String schemaVersion;
  final String workflowType;
  final String status;
  final String phase;
  final AgentWorkflowStep currentStep;
  final List<AgentWorkflowEditableStep> editableSteps;
  final Set<String> allowedCommands;

  bool get isPregnancyPlan =>
      schemaVersion == pregnancyPlanSchemaVersion &&
      workflowType == pregnancyPlanWorkflowType;

  Map<String, Object?> toMap() => {
    'schema_version': schemaVersion,
    'workflow_type': workflowType,
    'status': status,
    'phase': phase,
    'current_step': currentStep.toMap(),
    if (editableSteps.isNotEmpty)
      'editable_steps': editableSteps
          .map((step) => step.toMap())
          .toList(growable: false),
    if (allowedCommands.isNotEmpty)
      'allowed_commands': allowedCommands.toList(growable: false),
  };

  static AgentWorkflowPrompt? tryParse(Object? value) {
    if (value is! Map) return null;
    final map = Map<String, Object?>.from(value);
    final schemaVersion = _string(map['schema_version']);
    final workflowType = _string(map['workflow_type']);
    if (schemaVersion != pregnancyPlanSchemaVersion ||
        workflowType != pregnancyPlanWorkflowType) {
      return null;
    }
    final currentStep = AgentWorkflowStep.tryParse(map['current_step']);
    if (currentStep == null) return null;

    final editableSteps = <AgentWorkflowEditableStep>[];
    final rawEditableSteps = map['editable_steps'];
    if (rawEditableSteps is List) {
      for (final value in rawEditableSteps.take(12)) {
        final step = AgentWorkflowEditableStep.tryParse(value);
        if (step != null) editableSteps.add(step);
      }
    }
    final allowedCommands = <String>{};
    final rawAllowedCommands = map['allowed_commands'];
    if (rawAllowedCommands is List) {
      for (final value in rawAllowedCommands.take(12)) {
        final command = _string(value);
        if (_pregnancyPlanCommands.contains(command)) {
          allowedCommands.add(command!);
        }
      }
    }
    return AgentWorkflowPrompt(
      schemaVersion: schemaVersion!,
      workflowType: workflowType!,
      status: _boundedString(map['status'], 32) ?? 'active',
      phase: _boundedString(map['phase'], 80) ?? '',
      currentStep: currentStep,
      editableSteps: List<AgentWorkflowEditableStep>.unmodifiable(
        editableSteps,
      ),
      allowedCommands: Set<String>.unmodifiable(allowedCommands),
    );
  }
}

class AgentWorkflowStep {
  const AgentWorkflowStep({
    required this.id,
    required this.kind,
    required this.question,
    required this.allowFreeText,
    this.options = const <AgentWorkflowOption>[],
  });

  final String id;
  final String kind;
  final String question;
  final bool allowFreeText;
  final List<AgentWorkflowOption> options;

  bool get isForm => kind == 'form';

  Map<String, Object?> toMap() => {
    'id': id,
    'kind': kind,
    'question': question,
    'allow_free_text': allowFreeText,
    if (options.isNotEmpty)
      'options': options
          .map((option) => option.toMap())
          .toList(growable: false),
  };

  static AgentWorkflowStep? tryParse(Object? value) {
    if (value is! Map) return null;
    final map = Map<String, Object?>.from(value);
    final id = _boundedString(map['id'], 120);
    final kind = _boundedString(map['kind'], 80);
    if (id == null || kind == null) return null;
    final options = <AgentWorkflowOption>[];
    final rawOptions = map['options'];
    if (rawOptions is List) {
      for (final value in rawOptions.take(12)) {
        final option = AgentWorkflowOption.tryParse(value);
        if (option != null) options.add(option);
      }
    }
    return AgentWorkflowStep(
      id: id,
      kind: kind,
      question: _boundedString(map['question'], 2000) ?? '',
      allowFreeText: map['allow_free_text'] == true,
      options: List<AgentWorkflowOption>.unmodifiable(options),
    );
  }
}

class AgentWorkflowOption {
  const AgentWorkflowOption({required this.id, required this.label});

  final String id;
  final String label;

  bool get requiresTextInput => id == 'submit_final_additional_info';

  Map<String, Object?> toMap() => {'id': id, 'label': label};

  static AgentWorkflowOption? tryParse(Object? value) {
    if (value is! Map) return null;
    final map = Map<String, Object?>.from(value);
    final id = _boundedString(map['id'], 120);
    final label = _boundedString(map['label'], 240);
    if (id == null || label == null) return null;
    return AgentWorkflowOption(id: id, label: label);
  }
}

class AgentWorkflowEditableStep {
  const AgentWorkflowEditableStep({
    required this.id,
    required this.label,
    required this.answer,
  });

  final String id;
  final String label;
  final String answer;

  Map<String, Object?> toMap() => {'id': id, 'label': label, 'answer': answer};

  static AgentWorkflowEditableStep? tryParse(Object? value) {
    if (value is! Map) return null;
    final map = Map<String, Object?>.from(value);
    final id = _boundedString(map['id'], 120);
    final label = _boundedString(map['label'], 240);
    if (id == null || label == null) return null;
    return AgentWorkflowEditableStep(
      id: id,
      label: label,
      answer: _boundedString(map['answer'], 240) ?? '',
    );
  }
}

class AgentWorkflowCommand {
  const AgentWorkflowCommand({
    required this.command,
    required this.optimisticText,
    this.stepId,
    this.choiceId,
    this.answer,
  });

  static const schemaVersion = 'pregnancy_plan_command.v1';

  final String command;
  final String optimisticText;
  final String? stepId;
  final String? choiceId;
  final String? answer;

  Map<String, Object?> toMap() => {
    'schema_version': schemaVersion,
    'workflow_type': AgentWorkflowPrompt.pregnancyPlanWorkflowType,
    'command': command,
    if (_hasValue(stepId)) 'step_id': stepId,
    if (_hasValue(choiceId)) 'choice_id': choiceId,
    if (_hasValue(answer)) 'answer': answer,
  };
}

const _pregnancyPlanCommands = <String>{
  'submit_form',
  'answer_current',
  'edit_answer',
  'pause',
  'resume',
  'abandon',
  'generate_plan',
};

String? _string(Object? value) {
  if (value is! String) return null;
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

String? _boundedString(Object? value, int maxLength) {
  final normalized = _string(value);
  if (normalized == null) return null;
  return normalized.length <= maxLength
      ? normalized
      : normalized.substring(0, maxLength);
}

bool _hasValue(String? value) => value?.trim().isNotEmpty == true;
