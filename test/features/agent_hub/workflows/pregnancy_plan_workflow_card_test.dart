import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_workflow_prompt.dart';
import 'package:momcozy_flutter_app/features/agent_hub/workflows/pregnancy_plan_workflow_card.dart';

void main() {
  testWidgets(
    'submits dedicated follow-up text as the current workflow answer',
    (tester) async {
      final commands = <AgentWorkflowCommand>[];
      await tester.pumpWidget(
        _testApp(
          prompt: _prompt(
            currentStep: const AgentWorkflowStep(
              id: 'followup:doctor_notes',
              kind: 'choice_or_text',
              question: '医生安排什么时候复查？',
              allowFreeText: true,
            ),
            allowedCommands: const {'answer_current', 'pause'},
          ),
          commands: commands,
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('pregnancy-plan-custom-answer')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('pregnancy-plan-scoped-text-input')),
        '下周三复查',
      );
      await tester.tap(
        find.byKey(const ValueKey('pregnancy-plan-submit-scoped-text')),
      );
      await tester.pumpAndSettle();

      expect(commands, hasLength(1));
      expect(commands.single.command, 'answer_current');
      expect(commands.single.stepId, 'followup:doctor_notes');
      expect(commands.single.choiceId, isNull);
      expect(commands.single.answer, '下周三复查');
    },
  );

  testWidgets('maps the paused card option to a resume command', (
    tester,
  ) async {
    final commands = <AgentWorkflowCommand>[];
    await tester.pumpWidget(
      _testApp(
        prompt: _prompt(
          status: 'paused',
          currentStep: const AgentWorkflowStep(
            id: 'workflow_paused',
            kind: 'paused',
            question: '孕期计划已暂停，随时可以从这里继续。',
            allowFreeText: false,
            options: [AgentWorkflowOption(id: 'resume', label: '继续孕期计划')],
          ),
          allowedCommands: const {'resume'},
        ),
        commands: commands,
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('pregnancy-plan-option-resume')),
    );
    await tester.pump();

    expect(commands, hasLength(1));
    expect(commands.single.command, 'resume');
    expect(commands.single.stepId, 'workflow_paused');
    expect(commands.single.choiceId, isNull);
  });

  testWidgets('maps a historical choice revision to edit_answer', (
    tester,
  ) async {
    final commands = <AgentWorkflowCommand>[];
    await tester.pumpWidget(
      _testApp(
        prompt: _prompt(
          currentStep: const AgentWorkflowStep(
            id: 'final_confirmation',
            kind: 'choice_or_text',
            question: '还有其他需要补充的信息吗？',
            allowFreeText: true,
          ),
          editableSteps: const [
            AgentWorkflowEditableStep(
              id: 'checkup_done',
              label: '是否做过产检',
              answer: '做过产检',
            ),
          ],
          allowedCommands: const {'answer_current', 'edit_answer'},
        ),
        commands: commands,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('pregnancy-plan-edit-history')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('pregnancy-plan-edit-checkup_done')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('还没做过').last);
    await tester.pumpAndSettle();

    expect(commands, hasLength(1));
    expect(commands.single.command, 'edit_answer');
    expect(commands.single.stepId, 'checkup_done');
    expect(commands.single.choiceId, 'confirm_no_checkup_yet');
    expect(commands.single.answer, isNull);
  });
}

Widget _testApp({
  required AgentWorkflowPrompt prompt,
  required List<AgentWorkflowCommand> commands,
}) {
  return MaterialApp(
    home: Scaffold(
      body: PregnancyPlanWorkflowCard(prompt: prompt, onCommand: commands.add),
    ),
  );
}

AgentWorkflowPrompt _prompt({
  required AgentWorkflowStep currentStep,
  String status = 'active',
  List<AgentWorkflowEditableStep> editableSteps =
      const <AgentWorkflowEditableStep>[],
  Set<String> allowedCommands = const <String>{},
}) {
  return AgentWorkflowPrompt(
    schemaVersion: AgentWorkflowPrompt.pregnancyPlanSchemaVersion,
    workflowType: AgentWorkflowPrompt.pregnancyPlanWorkflowType,
    status: status,
    phase: currentStep.id,
    currentStep: currentStep,
    editableSteps: editableSteps,
    allowedCommands: allowedCommands,
  );
}
