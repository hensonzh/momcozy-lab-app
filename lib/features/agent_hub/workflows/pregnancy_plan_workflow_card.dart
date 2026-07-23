import 'dart:async';

import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_workflow_prompt.dart';

typedef AgentWorkflowCommandHandler =
    FutureOr<void> Function(AgentWorkflowCommand command);

class PregnancyPlanWorkflowCard extends StatelessWidget {
  const PregnancyPlanWorkflowCard({
    super.key,
    required this.prompt,
    required this.onCommand,
  });

  final AgentWorkflowPrompt prompt;
  final AgentWorkflowCommandHandler onCommand;

  @override
  Widget build(BuildContext context) {
    if (!prompt.isPregnancyPlan) return const SizedBox.shrink();
    final step = prompt.currentStep;
    final canEdit =
        prompt.allowedCommands.contains('edit_answer') &&
        prompt.editableSteps.isNotEmpty;

    return Material(
      key: const ValueKey('pregnancy-plan-workflow-card'),
      color: const Color(0xfffff8f8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xffeadde2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.calendar_month_rounded,
                  size: 19,
                  color: Color(0xffb45f79),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    prompt.status == 'paused' ? '孕期计划 · 已暂停' : '孕期计划',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: const Color(0xff6f4452),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (prompt.allowedCommands.contains('abandon'))
                  PopupMenuButton<String>(
                    key: const ValueKey('pregnancy-plan-more-actions'),
                    tooltip: '更多操作',
                    onSelected: (value) {
                      if (value == 'abandon') {
                        unawaited(_confirmAbandon(context));
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'abandon', child: Text('结束本次计划')),
                    ],
                    icon: const Icon(Icons.more_horiz_rounded, size: 20),
                  ),
              ],
            ),
            if (step.question.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                step.question,
                key: const ValueKey('pregnancy-plan-current-question'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.4,
                  color: const Color(0xff3f3038),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (step.isForm && step.question.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '请完成上方信息表，提交后会从这里继续。',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: const Color(0xff806d74)),
              ),
            ],
            if (step.options.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in step.options)
                    OutlinedButton(
                      key: ValueKey('pregnancy-plan-option-${option.id}'),
                      onPressed: () => _selectOption(context, option),
                      child: Text(option.label),
                    ),
                ],
              ),
            ],
            if (step.allowFreeText && step.id.startsWith('followup:')) ...[
              const SizedBox(height: 4),
              TextButton.icon(
                key: const ValueKey('pregnancy-plan-custom-answer'),
                onPressed: () => _submitCustomAnswer(context),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('填写其他答案'),
              ),
            ],
            if (canEdit) ...[
              const Divider(height: 24),
              ExpansionTile(
                key: const ValueKey('pregnancy-plan-edit-history'),
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('修改之前的回答'),
                children: [
                  for (final editableStep in prompt.editableSteps)
                    ListTile(
                      key: ValueKey('pregnancy-plan-edit-${editableStep.id}'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(editableStep.label),
                      subtitle: editableStep.answer.isEmpty
                          ? null
                          : Text(
                              editableStep.answer,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _editStep(context, editableStep),
                    ),
                ],
              ),
            ],
            if (prompt.allowedCommands.contains('pause')) ...[
              const SizedBox(height: 4),
              TextButton.icon(
                key: const ValueKey('pregnancy-plan-pause'),
                onPressed: () => onCommand(
                  AgentWorkflowCommand(
                    command: 'pause',
                    stepId: step.id,
                    optimisticText: '先暂停孕期计划',
                  ),
                ),
                icon: const Icon(Icons.pause_circle_outline_rounded, size: 18),
                label: const Text('先暂停，之后继续'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _selectOption(
    BuildContext context,
    AgentWorkflowOption option,
  ) async {
    if (option.requiresTextInput) {
      final answer = await _showTextAnswerDialog(
        context,
        title: '补充信息',
        hintText: '请输入你希望加入孕期计划的信息',
      );
      if (answer == null) return;
      await onCommand(
        AgentWorkflowCommand(
          command: 'answer_current',
          stepId: prompt.currentStep.id,
          choiceId: option.id,
          answer: answer,
          optimisticText: answer,
        ),
      );
      return;
    }
    final command = switch (option.id) {
      'resume' => 'resume',
      'generate_plan' => 'generate_plan',
      _ => 'answer_current',
    };
    await onCommand(
      AgentWorkflowCommand(
        command: command,
        stepId: prompt.currentStep.id,
        choiceId: command == 'answer_current' ? option.id : null,
        optimisticText: option.label,
      ),
    );
  }

  Future<void> _submitCustomAnswer(BuildContext context) async {
    final answer = await _showTextAnswerDialog(
      context,
      title: '填写回答',
      hintText: '只填写这个问题的答案',
    );
    if (answer == null) return;
    await onCommand(
      AgentWorkflowCommand(
        command: 'answer_current',
        stepId: prompt.currentStep.id,
        answer: answer,
        optimisticText: answer,
      ),
    );
  }

  Future<void> _editStep(
    BuildContext context,
    AgentWorkflowEditableStep editableStep,
  ) async {
    if (editableStep.id == 'basic_intake') {
      await onCommand(
        const AgentWorkflowCommand(
          command: 'edit_answer',
          stepId: 'basic_intake',
          optimisticText: '修改孕期基础信息',
        ),
      );
      return;
    }
    if (editableStep.id.startsWith('followup:')) {
      final answer = await _showTextAnswerDialog(
        context,
        title: '修改${editableStep.label}',
        hintText: '请输入新的回答',
        initialValue: editableStep.answer,
      );
      if (answer == null) return;
      await onCommand(
        AgentWorkflowCommand(
          command: 'edit_answer',
          stepId: editableStep.id,
          answer: answer,
          optimisticText: '修改${editableStep.label}：$answer',
        ),
      );
      return;
    }

    final editChoice = await _showHistoricalChoiceDialog(context, editableStep);
    if (editChoice == null) return;
    await onCommand(
      AgentWorkflowCommand(
        command: 'edit_answer',
        stepId: editableStep.id,
        choiceId: editChoice.choiceId,
        answer: editChoice.answer,
        optimisticText: '修改${editableStep.label}：${editChoice.label}',
      ),
    );
  }

  Future<_HistoricalEditChoice?> _showHistoricalChoiceDialog(
    BuildContext context,
    AgentWorkflowEditableStep step,
  ) {
    final choices = switch (step.id) {
      'checkup_done' => const [
        _HistoricalEditChoice('confirm_checkup_done', '做过产检'),
        _HistoricalEditChoice('confirm_no_checkup_yet', '还没做过'),
        _HistoricalEditChoice('confirm_checkup_unknown', '不确定'),
      ],
      'checkup_records' => const [
        _HistoricalEditChoice('skip_checkup_records', '暂不上传'),
      ],
      'final_confirmation' => const [
        _HistoricalEditChoice('confirm_ready_to_generate', '没有其他补充'),
        _HistoricalEditChoice(
          'submit_final_additional_info',
          '重新填写补充信息',
          requiresAnswer: true,
        ),
      ],
      _ => const <_HistoricalEditChoice>[],
    };
    return showDialog<_HistoricalEditChoice>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text('修改${step.label}'),
        children: [
          for (final choice in choices)
            SimpleDialogOption(
              onPressed: () async {
                if (!choice.requiresAnswer) {
                  Navigator.of(dialogContext).pop(choice);
                  return;
                }
                final answer = await _showTextAnswerDialog(
                  dialogContext,
                  title: '重新填写补充信息',
                  hintText: '请输入新的补充',
                  initialValue: step.answer == '没有其他补充' ? '' : step.answer,
                );
                if (answer == null || !dialogContext.mounted) return;
                Navigator.of(dialogContext).pop(choice.withAnswer(answer));
              },
              child: Text(choice.label),
            ),
          if (choices.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('这项内容请返回基础信息表修改。'),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmAbandon(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('结束本次孕期计划？'),
        content: const Text('已填写的流程状态将结束。以后仍可重新开始。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('确认结束'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await onCommand(
      AgentWorkflowCommand(
        command: 'abandon',
        stepId: prompt.currentStep.id,
        optimisticText: '结束本次孕期计划',
      ),
    );
  }
}

Future<String?> _showTextAnswerDialog(
  BuildContext context, {
  required String title,
  required String hintText,
  String initialValue = '',
}) {
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => _TextAnswerDialog(
      title: title,
      hintText: hintText,
      initialValue: initialValue,
    ),
  );
}

class _TextAnswerDialog extends StatefulWidget {
  const _TextAnswerDialog({
    required this.title,
    required this.hintText,
    required this.initialValue,
  });

  final String title;
  final String hintText;
  final String initialValue;

  @override
  State<_TextAnswerDialog> createState() => _TextAnswerDialogState();
}

class _TextAnswerDialogState extends State<_TextAnswerDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: const ValueKey('pregnancy-plan-scoped-text-input'),
        controller: _controller,
        autofocus: true,
        minLines: 2,
        maxLines: 5,
        maxLength: 2000,
        decoration: InputDecoration(hintText: widget.hintText),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const ValueKey('pregnancy-plan-submit-scoped-text'),
          onPressed: () {
            final answer = _controller.text.trim();
            if (answer.isNotEmpty) {
              Navigator.of(context).pop(answer);
            }
          },
          child: const Text('提交'),
        ),
      ],
    );
  }
}

class _HistoricalEditChoice {
  const _HistoricalEditChoice(
    this.choiceId,
    this.label, {
    this.requiresAnswer = false,
    this.answer,
  });

  final String choiceId;
  final String label;
  final bool requiresAnswer;
  final String? answer;

  _HistoricalEditChoice withAnswer(String value) => _HistoricalEditChoice(
    choiceId,
    value,
    requiresAnswer: requiresAnswer,
    answer: value,
  );
}
