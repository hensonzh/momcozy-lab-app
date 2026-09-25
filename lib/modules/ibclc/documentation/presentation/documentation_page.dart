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
        'Reload this note?',
        const Text('Your unsaved changes will be lost.'),
        'Reload',
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
              child: const Text('Keep editing'),
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
          'Sign this note?',
          const Text(
            'Once signed, the note becomes read-only. To make changes, create a new revision and explain why.',
          ),
          'Sign note',
        ) &&
        mounted) {
      await controller.sign();
    }
  }

  Future<void> _publish() async {
    final plan = controller.plan;
    final confirmed = await _confirm(
      'Publish this care plan?',
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
              Text(
                'The following ${plan.tasks.length} action tasks will be published:',
              ),
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
      'Publish plan',
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
          title: Text('Clinical note · Revision ${note.revision}'),
          content: SizedBox(
            width: 720,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (note.amendmentReason.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        'Reason for revision: ${note.amendmentReason}',
                      ),
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
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not view this version. Reload and try again.'),
          ),
        );
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
                      label: const Text('Back to consultation'),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Consultation notes & plan',
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
                          label: Text('Clinical note'),
                        ),
                        ButtonSegment(
                          value: DocumentationTab.plan,
                          label: Text('Care plan'),
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
                      _notice(
                        'Submission has not been confirmed. Try this action again.',
                        warning: true,
                      ),
                    if (controller.data != null && !controller.data!.editable)
                      const ProductEmptyView(
                        title: 'Complete after the consultation',
                        description:
                            'After ending the consultation, you can save a clinical note and prepare a care plan.',
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
                      isNote
                          ? (signed ? 'Signed · Read-only' : 'Clinical note')
                          : 'Plan',
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
                                  : 'v${controller.data!.publication!.revision} · Published'),
                      ),
                    ),
                    if (isNote && signed)
                      OutlinedButton(
                        onPressed: controller.editable ? _amend : null,
                        child: const Text('Create revision'),
                      ),
                    if (isNote && !signed) ...[
                      OutlinedButton(
                        onPressed:
                            controller.noteEditable &&
                                (controller.noteDirty ||
                                    controller.data?.note == null)
                            ? controller.saveNote
                            : null,
                        child: const Text('Save draft'),
                      ),
                      FilledButton(
                        onPressed: controller.canSign ? _sign : null,
                        child: const Text('Sign note'),
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
                        child: const Text('Save plan'),
                      ),
                      FilledButton(
                        onPressed: controller.canPublish ? _publish : null,
                        child: Text(
                          controller.data?.publication == null
                              ? 'Publish plan'
                              : 'Publish new version',
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
            isNote
                ? 'Your clinical assessment and next steps for this consultation.'
                : 'Turn your clinical assessment into actions the client can take.',
            style: const TextStyle(color: MomCozyColors.mutedForeground),
          ),
          if (isNote ? controller.noteDirty : controller.planDirty)
            _notice('You have unsaved changes', warning: true),
          if (isNote && signed)
            _notice(
              'Signed notes stay read-only. Changes create a new revision and preserve the original.',
            ),
          if (!isNote && !signed)
            _notice(
              'Sign the current clinical note before publishing the care plan.',
              warning: true,
            ),
          if (!isNote && signed && !controller.plan.complete)
            _notice(
              'Complete the plan title, summary, goals, and each task before saving and publishing.',
              warning: true,
            ),
          if (!isNote &&
              controller.plan.complete &&
              !controller.plan.englishClientCopy)
            _notice(
              'Review the title, summary, goals, and task details in English before publishing. You can still save the draft.',
              warning: true,
            ),
          if (!isNote && controller.data?.publication != null)
            _notice(
              'The client currently sees version ${controller.data!.publication!.revision}. Saving a draft will not update it until you publish again.',
            ),
          if (isNote &&
              controller.data?.note?.amendmentReason.isNotEmpty == true)
            _notice(
              'Reason for revision: ${controller.data!.note!.amendmentReason}',
            ),
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
            const Text('Note versions'),
            Wrap(
              spacing: 8,
              children: [
                for (final revision in controller.data!.noteHistory)
                  TextButton(
                    onPressed: controller.busy
                        ? null
                        : () => _history(revision),
                    child: Text(
                      'Revision ${revision.revision} · ${revision.status == ClinicalNoteStatus.signed ? 'Signed' : 'Draft'}',
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
    title: const Text('Create clinical note revision'),
    content: SizedBox(
      width: 480,
      child: TextField(
        controller: reason,
        autofocus: true,
        minLines: 3,
        maxLines: 5,
        maxLength: 1000,
        decoration: const InputDecoration(
          labelText: 'Reason for revision',
          hintText: 'Explain what needs to be added or corrected',
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, reason.text),
        child: const Text('Create revision'),
      ),
    ],
  );
}
