import 'package:flutter/material.dart';
import '../../../../domain/care/care_plan.dart';
import '../../../../domain/care/clinical_note.dart';
import '../../../../domain/shared/local_date.dart';
import '../../../../shared/design_system/momcozy_design_system.dart';
import '../../../../shared/mutation_key.dart';
import '../../../../shared/zoned_time.dart';
import '../application/documentation_controller.dart';

class DocumentationField extends StatelessWidget {
  const DocumentationField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.lines = 1,
    this.maxLength,
    this.hint,
  });
  final String label, value;
  final String? hint;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final int lines;
  final int? maxLength;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: TextFormField(
      initialValue: value,
      onChanged: onChanged,
      readOnly: !enabled,
      minLines: lines,
      maxLines: lines + 3,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        alignLabelWithHint: true,
        counterText: '',
        filled: true,
        fillColor: enabled ? MomCozyColors.card : MomCozyColors.secondary,
      ),
      style: const TextStyle(fontSize: 14, height: 1.7),
    ),
  );
}

class ClinicalNoteEditor extends StatelessWidget {
  const ClinicalNoteEditor({
    super.key,
    required this.content,
    required this.enabled,
    required this.onChanged,
  });
  final ClinicalNoteContent content;
  final bool enabled;
  final ValueChanged<ClinicalNoteContent> onChanged;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      DocumentationField(
        label: 'S · 主观描述',
        hint: '用户原话',
        value: content.subjective,
        enabled: enabled,
        lines: 4,
        maxLength: 8000,
        onChanged: (text) => onChanged(content.copyWith(subjective: text)),
      ),
      DocumentationField(
        label: 'O · 客观观察',
        hint: '观察',
        value: content.objective,
        enabled: enabled,
        lines: 3,
        maxLength: 8000,
        onChanged: (text) => onChanged(content.copyWith(objective: text)),
      ),
      DocumentationField(
        label: 'A · 专业评估',
        hint: '评估',
        value: content.assessment,
        enabled: enabled,
        lines: 3,
        maxLength: 8000,
        onChanged: (text) => onChanged(content.copyWith(assessment: text)),
      ),
      DocumentationField(
        label: 'P · 行动计划',
        hint: '下一步',
        value: content.plan,
        enabled: enabled,
        lines: 3,
        maxLength: 8000,
        onChanged: (text) => onChanged(content.copyWith(plan: text)),
      ),
    ],
  );
}

class CarePlanEditor extends StatelessWidget {
  const CarePlanEditor({super.key, required this.controller});
  final DocumentationController controller;
  @override
  Widget build(BuildContext context) {
    final plan = controller.plan;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DocumentationField(
          label: '方案标题',
          value: plan.title,
          enabled: controller.editable,
          maxLength: 120,
          onChanged: (text) =>
              controller.changePlan(plan.copyWith(title: text)),
        ),
        DocumentationField(
          label: '服务目标（每行一项，最多 6 项）',
          value: plan.goals.join('\n'),
          enabled: controller.editable,
          lines: 3,
          onChanged: (text) => controller.changePlan(
            plan.copyWith(goals: text.isEmpty ? [] : text.split('\n')),
          ),
        ),
        DocumentationField(
          label: '给用户的总结',
          value: plan.summary,
          enabled: controller.editable,
          lines: 3,
          maxLength: 3000,
          onChanged: (text) =>
              controller.changePlan(plan.copyWith(summary: text)),
        ),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '行动任务 · ${plan.tasks.length} 项',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            TextButton.icon(
              onPressed: controller.editable && plan.tasks.length < 12
                  ? () => controller.changePlan(
                      plan.copyWith(
                        tasks: [
                          ...plan.tasks,
                          CarePlanTaskContent(sourceKey: newMutationKey()),
                        ],
                      ),
                    )
                  : null,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('添加任务'),
            ),
          ],
        ),
        if (plan.tasks.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('添加与用户共同确认的行动任务。'),
          ),
        for (final task in plan.tasks)
          _PlanTaskEditor(
            key: ValueKey(task.sourceKey),
            task: task,
            enabled: controller.editable,
            timezone: controller.data!.appointment.timezone,
            onChanged: (value) => controller.changePlan(
              controller.plan.copyWith(
                tasks: controller.plan.tasks
                    .map(
                      (item) =>
                          item.sourceKey == value.sourceKey ? value : item,
                    )
                    .toList(),
              ),
            ),
            onRemove: () => controller.changePlan(
              controller.plan.copyWith(
                tasks: controller.plan.tasks
                    .where((value) => value.sourceKey != task.sourceKey)
                    .toList(),
              ),
            ),
          ),
      ],
    );
  }
}

class _PlanTaskEditor extends StatelessWidget {
  const _PlanTaskEditor({
    super.key,
    required this.task,
    required this.enabled,
    required this.timezone,
    required this.onChanged,
    required this.onRemove,
  });
  final CarePlanTaskContent task;
  final bool enabled;
  final String timezone;
  final ValueChanged<CarePlanTaskContent> onChanged;
  final VoidCallback onRemove;
  Future<void> _date(BuildContext context) async {
    final today = dateInTimezone(DateTime.now(), timezone);
    final selected = task.scheduledDate ?? today;
    final result = await showDatePicker(
      context: context,
      initialDate: DateTime(selected.year, selected.month, selected.day),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      helpText: '安排任务日期',
    );
    if (result != null && context.mounted) {
      onChanged(task.copyWith(scheduledDate: LocalDate.fromDateTime(result)));
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 12, bottom: 8),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      border: Border.all(color: MomCozyColors.border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            onPressed: enabled ? onRemove : null,
            tooltip: '移除这项任务',
            icon: const Icon(Icons.close, size: 18),
          ),
        ),
        DocumentationField(
          label: '任务标题',
          value: task.title,
          enabled: enabled,
          maxLength: 160,
          onChanged: (text) => onChanged(task.copyWith(title: text)),
        ),
        DocumentationField(
          label: '具体怎么做',
          value: task.description,
          enabled: enabled,
          lines: 2,
          maxLength: 1000,
          onChanged: (text) => onChanged(task.copyWith(description: text)),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final category = DocumentationField(
              label: '任务类别',
              hint: '例如：观察',
              value: task.category,
              enabled: enabled,
              maxLength: 64,
              onChanged: (text) => onChanged(task.copyWith(category: text)),
            );
            final due = DocumentationField(
              label: '时间说明',
              hint: '例如：下一次喂养时',
              value: task.dueLabel,
              enabled: enabled,
              maxLength: 80,
              onChanged: (text) => onChanged(task.copyWith(dueLabel: text)),
            );
            return constraints.maxWidth < 520
                ? Column(children: [category, due])
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: category),
                      const SizedBox(width: 16),
                      Expanded(child: due),
                    ],
                  );
          },
        ),
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: enabled ? () => _date(context) : null,
              icon: const Icon(Icons.calendar_today_outlined, size: 16),
              label: Text(task.scheduledDate?.toString() ?? '安排日期（可选）'),
            ),
            if (task.scheduledDate != null)
              TextButton(
                onPressed: enabled
                    ? () => onChanged(task.copyWith(clearDate: true))
                    : null,
                child: const Text('清除日期'),
              ),
          ],
        ),
      ],
    ),
  );
}
