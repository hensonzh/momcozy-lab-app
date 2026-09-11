import 'package:flutter/material.dart';
import '../../../../domain/care/clinical_note.dart';
import '../../../../shared/design_system/momcozy_design_system.dart';
import '../../../../shared/widgets/confirm_discard.dart';
import '../../../../shared/widgets/product_feedback.dart';
import '../../../../shared/zoned_time.dart';
import '../application/documentation_controller.dart';
import 'documentation_editors.dart';

enum DocumentationTab { note, plan }

class DocumentationPage extends StatefulWidget {
  const DocumentationPage({
    super.key,
    required this.createController,
    required this.onBack,
    this.initialTab = DocumentationTab.note,
  });
  final DocumentationController Function() createController;
  final VoidCallback onBack;
  final DocumentationTab initialTab;
  @override
  State<DocumentationPage> createState() => _DocumentationPageState();
}

class _DocumentationPageState extends State<DocumentationPage> {
  late final controller = widget.createController();
  late var tab = widget.initialTab;
  bool _allowPop = false;
  @override
  void initState() {
    super.initState();
    controller.load();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _back() async {
    if (controller.busy) return;
    if ((controller.dirty || controller.uncertain) &&
        !await confirmDiscard(context, uncertainSave: controller.uncertain)) {
      return;
    }
    if (!mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onBack();
    });
  }

  Future<void> _reload() async {
    if (controller.uncertain) {
      await controller.retry();
      return;
    }
    if (controller.dirty) {
      final confirmed = await _confirm(
        '重新载入记录？',
        const Text('当前未保存的修改会被放弃。'),
        '重新载入',
      );
      if (!confirmed) return;
    }
    await controller.load(discardChanges: true);
  }

  Future<bool> _confirm(String title, Widget body, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: body,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('返回编辑'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;
  Future<void> _sign() async {
    if (await _confirm(
          '确认签署这条记录？',
          const Text('签署后内容会变为只读；如需修改，请创建新的修订并说明理由。'),
          '确认签署',
        ) &&
        mounted) {
      await controller.sign();
    }
  }

  Future<void> _publish() async {
    final plan = controller.plan;
    final confirmed = await _confirm(
      '发布这版护理方案？',
      SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(plan.title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Text(plan.summary),
              const SizedBox(height: 12),
              for (final goal in plan.goals) Text('• $goal'),
              const SizedBox(height: 16),
              Text('将发布 ${plan.tasks.length} 项行动任务：'),
              for (final task in plan.tasks)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${task.title} · ${task.dueLabel}\n${task.description}',
                  ),
                ),
            ],
          ),
        ),
      ),
      '确认发布',
    );
    if (confirmed && mounted) await controller.publish();
  }

  Future<void> _amend() async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => const _AmendDialog(),
    );
    if (result != null && mounted) await controller.amend(result);
  }

  Future<void> _history(ClinicalNoteRevision revision) async {
    try {
      final note = await controller.repository.noteRevision(
        controller.appointmentId,
        revision.id,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('专业记录 · 修订 ${note.revision}'),
          content: SizedBox(
            width: 720,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (note.amendmentReason.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text('修订理由：${note.amendmentReason}'),
                    ),
                  ClinicalNoteEditor(
                    content: note.content,
                    enabled: false,
                    onChanged: (_) {},
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('暂时无法查看此版本，请重新载入后重试')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => PopScope(
      canPop:
          _allowPop ||
          (!controller.dirty && !controller.uncertain && !controller.busy),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: MomCozyColors.background,
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextButton.icon(
                      onPressed: controller.busy ? null : _back,
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: const Text('返回咨询'),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '咨询记录与方案',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    if (controller.data case final data?)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${appointmentDay(data.appointment.startsAt, data.appointment.timezone)} · ${zonedRange(data.appointment.startsAt, data.appointment.endsAt, data.appointment.timezone)}',
                          style: const TextStyle(
                            color: MomCozyColors.mutedForeground,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    SegmentedButton<DocumentationTab>(
                      segments: const [
                        ButtonSegment(
                          value: DocumentationTab.note,
                          label: Text('专业记录'),
                        ),
                        ButtonSegment(
                          value: DocumentationTab.plan,
                          label: Text('护理方案'),
                        ),
                      ],
                      selected: {tab},
                      onSelectionChanged: (value) =>
                          setState(() => tab = value.single),
                    ),
                    const SizedBox(height: 20),
                    if (controller.loading || controller.busy)
                      const LinearProgressIndicator(),
                    if (controller.failure case final failure?)
                      ProductErrorView(
                        failure: failure,
                        preserveDraft: controller.dirty,
                        onRetry: controller.busy ? null : _reload,
                      ),
                    if (controller.validation case final validation?)
                      _notice(validation, warning: true),
                    if (controller.message case final message?)
                      _notice(message),
                    if (controller.uncertain)
                      _notice('提交结果尚未确认，请重试这次操作。', warning: true),
                    if (controller.data != null && !controller.data!.editable)
                      const ProductEmptyView(
                        title: '咨询结束后填写',
                        description: '结束本次咨询后，可保存专业记录并整理护理方案。',
                      ),
                    if (controller.data?.editable ?? false) _editor(context),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _editor(BuildContext context) {
    final signed = controller.data?.note?.status == ClinicalNoteStatus.signed;
    final isNote = tab == DocumentationTab.note;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: MomCozyColors.card,
        border: Border.all(color: MomCozyColors.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: Wrap(
              spacing: 24,
              runSpacing: 16,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isNote ? (signed ? '已签署 · 只读' : '专业记录') : '方案',
                      style: const TextStyle(
                        color: MomCozyColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isNote ? 'Clinical Note' : 'Care Plan',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Chip(
                      label: Text(
                        isNote
                            ? (signed
                                  ? 'Signed · ${controller.data!.note!.revision}'
                                  : 'Draft')
                            : (controller.data?.publication == null
                                  ? 'Draft'
                                  : 'v${controller.data!.publication!.revision} · 已发布'),
                      ),
                    ),
                    if (isNote && signed)
                      OutlinedButton(
                        onPressed: controller.editable ? _amend : null,
                        child: const Text('创建修订'),
                      ),
                    if (isNote && !signed) ...[
                      OutlinedButton(
                        onPressed:
                            controller.noteEditable &&
                                (controller.noteDirty ||
                                    controller.data?.note == null)
                            ? controller.saveNote
                            : null,
                        child: const Text('保存草稿'),
                      ),
                      FilledButton(
                        onPressed: controller.canSign ? _sign : null,
                        child: const Text('签署记录'),
                      ),
                    ],
                    if (!isNote) ...[
                      OutlinedButton(
                        onPressed:
                            controller.editable &&
                                (controller.planDirty ||
                                    controller.data?.plan == null)
                            ? controller.savePlan
                            : null,
                        child: const Text('保存方案'),
                      ),
                      FilledButton(
                        onPressed: controller.canPublish ? _publish : null,
                        child: Text(
                          controller.data?.publication == null
                              ? '发布方案'
                              : '发布新版本',
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isNote ? '本次咨询的专业判断与下一步。' : '把专业判断拆成用户可以完成的动作。',
            style: const TextStyle(color: MomCozyColors.mutedForeground),
          ),
          if (isNote ? controller.noteDirty : controller.planDirty)
            _notice('有未保存修改', warning: true),
          if (isNote && signed) _notice('已签署记录保持只读。修改会创建新修订，并保留原记录。'),
          if (!isNote && !signed) _notice('请先签署当前专业记录，再发布护理方案。', warning: true),
          if (!isNote && signed && !controller.plan.complete)
            _notice('请补全方案标题、总结、目标及每项任务的内容，再保存并发布。', warning: true),
          if (!isNote && controller.data?.publication != null)
            _notice(
              '用户目前可见 v${controller.data!.publication!.revision}。保存草稿后，需要再次发布才会更新用户的方案。',
            ),
          if (isNote &&
              controller.data?.note?.amendmentReason.isNotEmpty == true)
            _notice('修订理由：${controller.data!.note!.amendmentReason}'),
          const SizedBox(height: 24),
          if (isNote)
            ClinicalNoteEditor(
              key: ValueKey('note-${controller.noteEditorRevision}'),
              content: controller.note,
              enabled: controller.noteEditable,
              onChanged: controller.changeNote,
            ),
          if (!isNote)
            CarePlanEditor(
              key: ValueKey('plan-${controller.planEditorRevision}'),
              controller: controller,
            ),
          if (isNote && controller.data!.noteHistory.isNotEmpty) ...[
            const Divider(),
            const SizedBox(height: 12),
            const Text('记录版本'),
            Wrap(
              spacing: 8,
              children: [
                for (final revision in controller.data!.noteHistory)
                  TextButton(
                    onPressed: controller.busy
                        ? null
                        : () => _history(revision),
                    child: Text(
                      '修订 ${revision.revision} · ${revision.status == ClinicalNoteStatus.signed ? '已签署' : '草稿'}',
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _notice(String text, {bool warning = false}) => Semantics(
    liveRegion: true,
    child: Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: warning ? MomCozyColors.amberSoft : MomCozyColors.careSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text),
    ),
  );
}

class _AmendDialog extends StatefulWidget {
  const _AmendDialog();
  @override
  State<_AmendDialog> createState() => _AmendDialogState();
}

class _AmendDialogState extends State<_AmendDialog> {
  final reason = TextEditingController();
  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('创建专业记录修订'),
    content: SizedBox(
      width: 480,
      child: TextField(
        controller: reason,
        autofocus: true,
        minLines: 3,
        maxLines: 5,
        maxLength: 1000,
        decoration: const InputDecoration(
          labelText: '修订理由',
          hintText: '说明这次需要补充或更正的内容',
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, reason.text),
        child: const Text('创建修订'),
      ),
    ],
  );
}
