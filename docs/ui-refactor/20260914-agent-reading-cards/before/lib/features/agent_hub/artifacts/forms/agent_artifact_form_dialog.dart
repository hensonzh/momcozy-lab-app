import 'dart:async';
import '../cards/agent_result_card.dart';

import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_motion.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/features/agent_hub/artifacts/agent_artifact_model.dart';
import 'package:momcozy_flutter_app/features/agent_hub/artifacts/forms/agent_artifact_form.dart';

const agentArtifactFormAutoOpenDelay = Duration(seconds: 1);

class AgentArtifactFormPresentationSession {
  final Map<String, Map<String, Object?>> _drafts =
      <String, Map<String, Object?>>{};
  final Set<String> _liveFormIds = <String>{};
  final Set<String> _autoPresentedFormIds = <String>{};
  String? _openDialogArtifactId;

  Map<String, Object?> draftFor(String artifactId) {
    return _drafts[artifactId] ?? const <String, Object?>{};
  }

  void saveDraft(String artifactId, Map<String, Object?> values) {
    _drafts[artifactId] = Map<String, Object?>.unmodifiable(values);
  }

  void registerLiveFormIds(Iterable<String> artifactIds) {
    _liveFormIds.addAll(artifactIds.where((id) => id.trim().isNotEmpty));
  }

  void seedExistingFormIds(Iterable<String> artifactIds) {
    _autoPresentedFormIds.addAll(
      artifactIds.where((id) => id.trim().isNotEmpty),
    );
  }

  bool claimAutoPresentation(String artifactId) {
    return _liveFormIds.contains(artifactId) &&
        _autoPresentedFormIds.add(artifactId);
  }

  bool tryOpenDialog(String artifactId) {
    if (_openDialogArtifactId != null) return false;
    _openDialogArtifactId = artifactId;
    return true;
  }

  void closeDialog(String artifactId) {
    if (_openDialogArtifactId == artifactId) _openDialogArtifactId = null;
  }

  void clear() {
    _drafts.clear();
    _liveFormIds.clear();
    _autoPresentedFormIds.clear();
    _openDialogArtifactId = null;
  }
}

class AgentArtifactFormEntry extends StatefulWidget {
  const AgentArtifactFormEntry({
    super.key,
    required this.card,
    this.onAction,
    this.onSubmit,
    this.submission,
    this.presentationSession,
    this.autoPresent = false,
  });

  final AgentArtifactCardView card;
  final ValueChanged<AgentArtifactActionView>? onAction;
  final AgentArtifactFormSubmitHandler? onSubmit;
  final AgentArtifactFormSubmission? submission;
  final AgentArtifactFormPresentationSession? presentationSession;
  final bool autoPresent;

  @override
  State<AgentArtifactFormEntry> createState() => _AgentArtifactFormEntryState();
}

class _AgentArtifactFormEntryState extends State<AgentArtifactFormEntry> {
  late AgentArtifactFormPresentationSession _session;
  late final ValueNotifier<AgentArtifactCardView> _dialogCardNotifier;
  late final ValueNotifier<AgentArtifactFormSubmission?>
  _dialogSubmissionNotifier;
  Timer? _autoOpenTimer;
  bool _loading = false;
  bool _opening = false;
  bool _locallySubmitted = false;

  @override
  void initState() {
    super.initState();
    _dialogCardNotifier = ValueNotifier<AgentArtifactCardView>(widget.card);
    _dialogSubmissionNotifier = ValueNotifier<AgentArtifactFormSubmission?>(
      widget.submission,
    );
    _configureSession();
    _scheduleAutoPresentation();
  }

  @override
  void didUpdateWidget(covariant AgentArtifactFormEntry oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.card, widget.card) ||
        !identical(oldWidget.submission, widget.submission)) {
      final card = widget.card;
      final submission = widget.submission;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || widget.card.id != card.id) return;
        _dialogCardNotifier.value = card;
        _dialogSubmissionNotifier.value = submission;
      });
    }
    var shouldScheduleAutoPresentation = false;
    if (oldWidget.presentationSession != widget.presentationSession) {
      _autoOpenTimer?.cancel();
      _configureSession();
      shouldScheduleAutoPresentation = true;
    }
    if (oldWidget.card.id != widget.card.id ||
        (!oldWidget.autoPresent && widget.autoPresent)) {
      _autoOpenTimer?.cancel();
      if (oldWidget.card.id != widget.card.id) _locallySubmitted = false;
      shouldScheduleAutoPresentation = true;
    }
    if (widget.submission?.isSubmitted == true) _locallySubmitted = true;
    if (shouldScheduleAutoPresentation) {
      _scheduleAutoPresentation();
    }
    if (widget.submission?.isSubmitted == true && _loading) {
      _autoOpenTimer?.cancel();
      _loading = false;
    }
  }

  @override
  void dispose() {
    _autoOpenTimer?.cancel();
    if (_opening) _session.closeDialog(widget.card.id);
    _dialogCardNotifier.dispose();
    _dialogSubmissionNotifier.dispose();
    super.dispose();
  }

  void _configureSession() {
    final provided = widget.presentationSession;
    _session = provided ?? AgentArtifactFormPresentationSession();
  }

  void _scheduleAutoPresentation() {
    if (!widget.autoPresent ||
        widget.submission != null ||
        !_session.claimAutoPresentation(widget.card.id)) {
      return;
    }
    _loading = true;
    _autoOpenTimer = Timer(agentArtifactFormAutoOpenDelay, () {
      _autoOpenTimer = null;
      if (!mounted) return;
      setState(() => _loading = false);
      final route = ModalRoute.of(context);
      if (!TickerMode.valuesOf(context).enabled ||
          (route != null && !route.isCurrent)) {
        return;
      }
      unawaited(_openDialog());
    });
  }

  Future<void> _openDialog() async {
    if (_loading || _opening || !_session.tryOpenDialog(widget.card.id)) return;
    setState(() => _opening = true);
    try {
      await showDialog<void>(
        context: context,
        animationStyle: MomCozyMotion.animationStyle(context),
        barrierDismissible: true,
        builder: (context) => ListenableBuilder(
          listenable: Listenable.merge([
            _dialogCardNotifier,
            _dialogSubmissionNotifier,
          ]),
          builder: (context, child) => AgentArtifactFormDialog(
            card: _dialogCardNotifier.value,
            onAction: widget.onAction,
            onSubmit: widget.onSubmit,
            submission:
                _dialogSubmissionNotifier.value ??
                (_locallySubmitted
                    ? AgentArtifactFormSubmission.submitted(
                        values: _session.draftFor(widget.card.id),
                      )
                    : null),
            initialDraftValues: _session.draftFor(widget.card.id),
            onDraftChanged: (values) =>
                _session.saveDraft(widget.card.id, values),
            onSubmitted: () {
              if (mounted) setState(() => _locallySubmitted = true);
            },
          ),
        ),
      );
    } finally {
      _session.closeDialog(widget.card.id);
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final submission =
        widget.submission ??
        (_locallySubmitted
            ? AgentArtifactFormSubmission.submitted(
                values: _session.draftFor(widget.card.id),
              )
            : null);
    final isSubmitting = submission?.isSubmitting == true;
    final isSubmitted = submission?.isSubmitted == true;
    final prefilledCount = _prefilledFieldCount(
      widget.card,
      _session.draftFor(widget.card.id),
    );
    final subtitle = _loading
        ? '正在准备表单…'
        : isSubmitting
        ? '正在提交，请稍候'
        : isSubmitted
        ? '已提交，可点击查看'
        : prefilledCount > 0
        ? '已预填 $prefilledCount 项 · 点击继续填写'
        : '点击填写信息';

    return Semantics(
      button: true,
      enabled: !_loading && !isSubmitting,
      excludeSemantics: true,
      label: '${widget.card.title}，$subtitle',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('agent-artifact-form-entry-${widget.card.id}'),
          onTap: _loading || isSubmitting ? null : _openDialog,
          borderRadius: BorderRadius.circular(12),
          child: AgentResultCard(
            title: widget.card.title,
            description: subtitle,
            icon: _loading || isSubmitting
                ? SizedBox.square(
                    key: ValueKey(
                      'agent-artifact-form-entry-loading-${widget.card.id}',
                    ),
                    dimension: 18,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: MomCozyColors.agentStrong,
                    ),
                  )
                : Icon(
                    isSubmitted
                        ? Icons.check_circle_outline_rounded
                        : Icons.assignment_outlined,
                    size: 18,
                    color: MomCozyColors.agentStrong,
                  ),
          ),
        ),
      ),
    );
  }
}

class AgentArtifactFormDialog extends StatefulWidget {
  const AgentArtifactFormDialog({
    super.key,
    required this.card,
    this.onAction,
    this.onSubmit,
    this.submission,
    this.initialDraftValues = const <String, Object?>{},
    this.onDraftChanged,
    this.onSubmitted,
  });

  final AgentArtifactCardView card;
  final ValueChanged<AgentArtifactActionView>? onAction;
  final AgentArtifactFormSubmitHandler? onSubmit;
  final AgentArtifactFormSubmission? submission;
  final Map<String, Object?> initialDraftValues;
  final ValueChanged<Map<String, Object?>>? onDraftChanged;
  final VoidCallback? onSubmitted;

  @override
  State<AgentArtifactFormDialog> createState() =>
      _AgentArtifactFormDialogState();
}

class _AgentArtifactFormDialogState extends State<AgentArtifactFormDialog> {
  final GlobalKey<AgentArtifactFormState> _formKey =
      GlobalKey<AgentArtifactFormState>();
  final ScrollController _scrollController = ScrollController();
  bool _submitting = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final accepted = await _formKey.currentState?.submit() ?? false;
    if (!mounted) return;
    if (accepted) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _submitting = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _formKey.currentState?.revealError();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Widget _buildCancelButton({
    required bool isSubmitted,
    required bool isSubmitting,
  }) {
    return OutlinedButton(
      key: ValueKey('agent-artifact-form-cancel-${widget.card.id}'),
      onPressed: isSubmitting ? null : () => Navigator.of(context).pop(),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(82, MomCozyLayout.buttonHeight),
      ),
      child: Text(isSubmitted ? '关闭' : '取消'),
    );
  }

  Widget _buildSubmitButton({
    required bool canSubmit,
    required bool isSubmitting,
  }) {
    return FilledButton.icon(
      key: ValueKey('agent-artifact-form-submit-${widget.card.id}'),
      onPressed: !canSubmit || isSubmitting ? null : _submit,
      style: FilledButton.styleFrom(
        minimumSize: const Size(96, MomCozyLayout.buttonHeight),
      ),
      icon: isSubmitting
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: MomCozyColors.card,
              ),
            )
          : const Icon(Icons.check_rounded, size: 18),
      label: Text(
        isSubmitting ? '提交中' : widget.card.formSubmitLabel ?? '提交',
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildFooterActions({
    required bool isSubmitted,
    required bool isSubmitting,
    required bool canSubmit,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useStackedLayout =
            constraints.maxWidth < 320 ||
            MediaQuery.textScalerOf(context).scale(14) > 17.5;
        final cancelButton = _buildCancelButton(
          isSubmitted: isSubmitted,
          isSubmitting: isSubmitting,
        );
        final submitButton = isSubmitted
            ? null
            : _buildSubmitButton(
                canSubmit: canSubmit,
                isSubmitting: isSubmitting,
              );

        if (useStackedLayout) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              cancelButton,
              if (submitButton != null) ...[
                const SizedBox(height: MomCozySpacing.compact),
                submitButton,
              ],
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            cancelButton,
            if (submitButton != null) ...[
              const SizedBox(width: MomCozySpacing.statusGap),
              Flexible(child: submitButton),
            ],
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isSubmitted = widget.submission?.isSubmitted == true;
    final isSubmitting = _submitting || widget.submission?.isSubmitting == true;
    final canSubmit = widget.onSubmit != null || widget.onAction != null;
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 9),
              child: Text(
                widget.card.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: '取消',
            onPressed: isSubmitting ? null : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, size: 20),
          ),
        ],
      ),
    );
    final form = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.card.description?.trim().isNotEmpty == true) ...[
            Text(
              widget.card.description!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: MomCozyColors.mutedForeground,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 24),
          ],
          AgentArtifactForm(
            key: _formKey,
            card: widget.card,
            onAction: widget.onAction,
            onSubmit: widget.onSubmit,
            submission: widget.submission,
            initialDraftValues: widget.initialDraftValues,
            onDraftChanged: widget.onDraftChanged,
            onSubmitted: widget.onSubmitted,
          ),
        ],
      ),
    );
    final footer = Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: _buildFooterActions(
        isSubmitted: isSubmitted,
        isSubmitting: isSubmitting,
        canSubmit: canSubmit,
      ),
    );
    const divider = Divider(height: 1, color: MomCozyColors.border);
    return PopScope(
      canPop: !isSubmitting,
      child: Dialog(
        key: ValueKey('agent-artifact-form-dialog-${widget.card.id}'),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MomCozyLayout.maxAppWidth,
            maxHeight: mediaQuery.size.height * .8,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // A keyboard or large text must not leave a fixed header/footer taller
              // than the remaining dialog. Keep the whole form reachable by scrolling.
              final scrollAll =
                  constraints.maxHeight < 400 ||
                  MediaQuery.textScalerOf(context).scale(14) > 17.5;
              if (scrollAll) {
                return SingleChildScrollView(
                  key: ValueKey('agent-artifact-form-scroll-${widget.card.id}'),
                  controller: _scrollController,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [header, divider, form, divider, footer],
                  ),
                );
              }
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  header,
                  divider,
                  Flexible(
                    child: SingleChildScrollView(
                      key: ValueKey(
                        'agent-artifact-form-scroll-${widget.card.id}',
                      ),
                      controller: _scrollController,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: form,
                    ),
                  ),
                  divider,
                  footer,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

int _prefilledFieldCount(
  AgentArtifactCardView card,
  Map<String, Object?> draft,
) {
  var count = 0;
  for (final field in card.formFields) {
    final value = draft.containsKey(field.id)
        ? draft[field.id]
        : field.defaultValue;
    if (_hasDisplayValue(value)) count += 1;
  }
  return count;
}

bool _hasDisplayValue(Object? value) {
  if (value == null) return false;
  if (value is String) return value.trim().isNotEmpty;
  if (value is Iterable) return value.isNotEmpty;
  return true;
}
