import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/app/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/features/status/domain/birth_journey_plan.dart';
import 'package:momcozy_flutter_app/features/status/presentation/status_dashboard_controller.dart';

typedef BirthJourneyDelete = Future<bool> Function();
typedef BirthJourneyAgentPrompt = void Function(String prompt, {bool autoSend});

enum _TodoFeedback { blocked }

class BirthJourneyPlanDashboard extends StatefulWidget {
  const BirthJourneyPlanDashboard({
    super.key,
    required this.plan,
    required this.mutation,
    required this.onDeletePlan,
    required this.onAgentPrompt,
  });

  final ValueListenable<StatusResource<BirthJourneyPlan?>> plan;
  final ValueListenable<StatusMutationState> mutation;
  final BirthJourneyDelete onDeletePlan;
  final BirthJourneyAgentPrompt onAgentPrompt;

  @override
  State<BirthJourneyPlanDashboard> createState() =>
      _BirthJourneyPlanDashboardState();
}

class _BirthJourneyPlanDashboardState extends State<BirthJourneyPlanDashboard> {
  final _feedback = <String, _TodoFeedback>{};
  final _feedbackTimers = <String, Timer>{};
  String? _error;
  Timer? _blockedErrorTimer;

  @override
  void dispose() {
    for (final timer in _feedbackTimers.values) {
      timer.cancel();
    }
    _blockedErrorTimer?.cancel();
    super.dispose();
  }

  void _setFeedback(String key, _TodoFeedback feedback) {
    _feedbackTimers.remove(key)?.cancel();
    setState(() => _feedback[key] = feedback);
    _feedbackTimers[key] = Timer(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      setState(() => _feedback.remove(key));
      _feedbackTimers.remove(key);
    });
  }

  void _showBlocked(String itemId) {
    _setFeedback(itemId, _TodoFeedback.blocked);
    setState(() => _error = '当前还未到该阶段，暂不适合进行该事项');
    _blockedErrorTimer?.cancel();
    _blockedErrorTimer = Timer(const Duration(milliseconds: 2400), () {
      if (!mounted || _error != '当前还未到该阶段，暂不适合进行该事项') {
        return;
      }
      setState(() => _error = null);
    });
  }

  void _handoffTodo(BirthJourneyTodo item, bool completed) {
    setState(() => _error = null);
    final prompt = completed
        ? item.agentCompletionPrompt
        : '请把孕期计划事项【${item.title}】恢复为未完成，并继续帮我确认下一步。';
    widget.onAgentPrompt(prompt, autoSend: true);
  }

  Future<void> _openDetails() {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.38),
      builder: (sheetContext) => _BirthJourneyDetailSheet(
        plan: widget.plan,
        mutation: widget.mutation,
        onDeletePlan: widget.onDeletePlan,
        onClose: () => Navigator.of(sheetContext).pop(),
        onAgentPrompt: widget.onAgentPrompt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<StatusResource<BirthJourneyPlan?>>(
      valueListenable: widget.plan,
      builder: (context, resource, _) {
        final plan = resource.data;
        return Container(
          key: const ValueKey('status-birth-journey-card'),
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xfffbfefd),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xffd7e8e4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '孕期计划',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: MomCozyColors.foreground,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (resource.phase == StatusResourcePhase.data &&
                      plan == null)
                    _CreatePlanButton(
                      onPressed: () =>
                          widget.onAgentPrompt('帮我制定孕期计划', autoSend: false),
                    )
                  else
                    IconButton(
                      key: const ValueKey('status-birth-journey-detail-button'),
                      tooltip: '查看计划详情',
                      onPressed: _openDetails,
                      icon: const Icon(Icons.open_in_full, size: 18),
                      color: const Color(0xff4f8f87),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              if (resource.isLoading ||
                  resource.phase == StatusResourcePhase.initial) ...[
                const SizedBox(height: 8),
                Text(
                  '正在加载孕期计划',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xff385f5b),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              if (resource.hasError && resource.data == null) ...[
                const SizedBox(height: 10),
                const _PlanErrorMessage(text: '孕期计划暂时无法同步，请稍后重试'),
              ],
              if (plan != null) ...[
                const SizedBox(height: 12),
                if (plan.hasStructuredContent)
                  _PlanTimeline(
                    plan: plan,
                    updatingId: null,
                    feedback: _feedback,
                    onToggle: _handoffTodo,
                    onBlocked: _showBlocked,
                  )
                else
                  const _MissingPlanStructure(),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                _PlanErrorMessage(
                  key: const ValueKey('status-birth-journey-todo-error'),
                  text: _error!,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _PlanTimeline extends StatefulWidget {
  const _PlanTimeline({
    required this.plan,
    required this.updatingId,
    required this.feedback,
    required this.onToggle,
    required this.onBlocked,
    this.readOnly = false,
  });

  final BirthJourneyPlan plan;
  final String? updatingId;
  final Map<String, _TodoFeedback> feedback;
  final void Function(BirthJourneyTodo item, bool completed) onToggle;
  final ValueChanged<String> onBlocked;
  final bool readOnly;

  @override
  State<_PlanTimeline> createState() => _PlanTimelineState();
}

class _PlanTimelineState extends State<_PlanTimeline> {
  late final Set<String> _expanded = {
    for (var index = 0; index < widget.plan.periods.length; index += 1)
      if (_initiallyExpanded(widget.plan.periods[index], index))
        widget.plan.periods[index].id,
  };

  @override
  void didUpdateWidget(covariant _PlanTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    for (var index = 0; index < widget.plan.periods.length; index += 1) {
      final period = widget.plan.periods[index];
      final existed = oldWidget.plan.periods.any(
        (oldPeriod) => oldPeriod.id == period.id,
      );
      if (!existed && _initiallyExpanded(period, index)) {
        _expanded.add(period.id);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < widget.plan.periods.length; index += 1) ...[
          if (index > 0) const Divider(height: 1, color: Color(0xffdbece8)),
          _PlanPeriodSection(
            period: widget.plan.periods[index],
            index: index,
            expanded: _expanded.contains(widget.plan.periods[index].id),
            updatingId: widget.updatingId,
            feedback: widget.feedback,
            readOnly: widget.readOnly,
            onExpandedChanged: () {
              setState(() {
                if (!_expanded.remove(widget.plan.periods[index].id)) {
                  _expanded.add(widget.plan.periods[index].id);
                }
              });
            },
            onToggle: widget.onToggle,
            onBlocked: widget.onBlocked,
          ),
        ],
      ],
    );
  }
}

class _PlanPeriodSection extends StatelessWidget {
  const _PlanPeriodSection({
    required this.period,
    required this.index,
    required this.expanded,
    required this.updatingId,
    required this.feedback,
    required this.readOnly,
    required this.onExpandedChanged,
    required this.onToggle,
    required this.onBlocked,
  });

  final BirthJourneyPeriod period;
  final int index;
  final bool expanded;
  final String? updatingId;
  final Map<String, _TodoFeedback> feedback;
  final bool readOnly;
  final VoidCallback onExpandedChanged;
  final void Function(BirthJourneyTodo item, bool completed) onToggle;
  final ValueChanged<String> onBlocked;

  @override
  Widget build(BuildContext context) {
    final colors = _periodColors(period);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        children: [
          InkWell(
            key: ValueKey('status-birth-journey-period-${period.id}'),
            onTap: onExpandedChanged,
            borderRadius: BorderRadius.circular(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: colors.background,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: colors.border),
                  ),
                  child: Text(
                    (index + 1).toString().padLeft(2, '0'),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.foreground,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        period.title,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xff352820),
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          height: 1.25,
                        ),
                      ),
                      if (period.subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(period.subtitle, style: _smallPlanText(context)),
                      ],
                      if (!expanded) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${period.items.length} 个事项',
                          style: _smallPlanText(context).copyWith(
                            color: const Color(0xff5f918b),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.keyboard_arrow_down,
                    color: Color(0xff6f9c96),
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(36, 12, 0, 0),
              child: Column(
                children: [
                  for (
                    var itemIndex = 0;
                    itemIndex < period.items.length;
                    itemIndex += 1
                  ) ...[
                    _PlanTodoRow(
                      item: period.items[itemIndex],
                      index: itemIndex,
                      currentPeriod: period.isCurrent,
                      updating: updatingId == period.items[itemIndex].id,
                      feedback: feedback[period.items[itemIndex].id],
                      readOnly: readOnly,
                      onToggle: onToggle,
                      onBlocked: onBlocked,
                    ),
                    if (itemIndex != period.items.length - 1)
                      const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanTodoRow extends StatelessWidget {
  const _PlanTodoRow({
    required this.item,
    required this.index,
    required this.currentPeriod,
    required this.updating,
    required this.feedback,
    required this.readOnly,
    required this.onToggle,
    required this.onBlocked,
  });

  final BirthJourneyTodo item;
  final int index;
  final bool currentPeriod;
  final bool updating;
  final _TodoFeedback? feedback;
  final bool readOnly;
  final void Function(BirthJourneyTodo item, bool completed) onToggle;
  final ValueChanged<String> onBlocked;

  @override
  Widget build(BuildContext context) {
    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: item.completed
            ? Colors.white.withValues(alpha: 0.75)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: feedback == null
            ? null
            : Border.all(color: const Color(0xffe48a8a)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            enabled: currentPeriod && !readOnly && !updating,
            checked: item.completed,
            label: currentPeriod
                ? '${item.completed ? '取消完成' : '标记完成'}：${item.title}'
                : '当前还未到该阶段，暂不适合进行该事项：${item.title}',
            child: ExcludeSemantics(
              child: SizedBox(
                width: 22,
                height: 22,
                child: Checkbox(
                  key: ValueKey('status-birth-journey-todo-${item.id}'),
                  value: item.completed,
                  onChanged: readOnly || updating
                      ? null
                      : (value) {
                          if (!currentPeriod) {
                            onBlocked(item.id);
                            return;
                          }
                          onToggle(item, value ?? !item.completed);
                        },
                  activeColor: const Color(0xff4f8f87),
                  checkColor: Colors.white,
                  side: BorderSide(
                    color: currentPeriod
                        ? const Color(0xff8eb8b1)
                        : const Color(0xffd77b7b),
                    width: 2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (item.priorityLabel.isNotEmpty)
                      _PriorityLabel(label: item.priorityLabel),
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: item.completed
                            ? const Color(0xff8a7a72)
                            : const Color(0xff4f4540),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        height: 1.4,
                        decoration: item.completed
                            ? TextDecoration.lineThrough
                            : null,
                        decorationColor: const Color(0xff9dbfba),
                      ),
                    ),
                  ],
                ),
                if (item.reason.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.reason,
                    style: _smallPlanText(context).copyWith(
                      color: item.completed
                          ? const Color(0xff9b8d86)
                          : const Color(0xff7b6a61),
                    ),
                  ),
                ],
                if (item.steps.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  for (final step in item.steps) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(top: 5, right: 6),
                          decoration: const BoxDecoration(
                            color: Color(0xff8eb8b1),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Text(step, style: _smallPlanText(context)),
                        ),
                      ],
                    ),
                    if (step != item.steps.last) const SizedBox(height: 4),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
    if (feedback != _TodoFeedback.blocked) return content;
    return TweenAnimationBuilder<double>(
      key: ValueKey('blocked-${item.id}'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 280),
      builder: (context, value, child) {
        final offset = math.sin(value * math.pi * 6) * (1 - value) * 5;
        return Transform.translate(offset: Offset(offset, 0), child: child);
      },
      child: content,
    );
  }
}

class _BirthJourneyDetailSheet extends StatefulWidget {
  const _BirthJourneyDetailSheet({
    required this.plan,
    required this.mutation,
    required this.onDeletePlan,
    required this.onClose,
    required this.onAgentPrompt,
  });

  final ValueListenable<StatusResource<BirthJourneyPlan?>> plan;
  final ValueListenable<StatusMutationState> mutation;
  final BirthJourneyDelete onDeletePlan;
  final VoidCallback onClose;
  final BirthJourneyAgentPrompt onAgentPrompt;

  @override
  State<_BirthJourneyDetailSheet> createState() =>
      _BirthJourneyDetailSheetState();
}

class _BirthJourneyDetailSheetState extends State<_BirthJourneyDetailSheet> {
  var _confirmingDelete = false;
  var _deleting = false;
  String? _deleteError;

  Future<void> _delete() async {
    if (_deleting) return;
    setState(() {
      _deleting = true;
      _deleteError = null;
    });
    var deleted = false;
    try {
      deleted = await widget.onDeletePlan();
    } catch (_) {
      deleted = false;
    }
    if (!mounted) return;
    if (deleted) {
      widget.onClose();
      return;
    }
    setState(() {
      _deleting = false;
      _deleteError = widget.mutation.value.message ?? '删除孕期计划失败';
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_deleting,
      child: Container(
        key: const ValueKey('status-detail-birth-journey'),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: const BoxDecoration(
          color: MomCozyColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: MomCozyColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '孕期计划',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: MomCozyColors.foreground,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '关闭详情',
                  onPressed: _deleting ? null : widget.onClose,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Flexible(
              child: ValueListenableBuilder<StatusResource<BirthJourneyPlan?>>(
                valueListenable: widget.plan,
                builder: (context, resource, _) {
                  final plan = resource.data;
                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (resource.isLoading ||
                            resource.phase == StatusResourcePhase.initial)
                          const _PlanLoadingMessage()
                        else if (resource.hasError && plan == null)
                          const _PlanErrorMessage(text: '孕期计划暂时无法同步，请稍后重试')
                        else if (plan == null)
                          _PlanEmptyDetail(
                            onCreate: () {
                              widget.onClose();
                              widget.onAgentPrompt('帮我制定孕期计划', autoSend: false);
                            },
                          )
                        else ...[
                          if (plan.hasStructuredContent)
                            _PlanTimeline(
                              plan: plan,
                              updatingId: null,
                              feedback: const {},
                              readOnly: true,
                              onToggle: (_, _) {},
                              onBlocked: (_) {},
                            )
                          else
                            const _MissingPlanStructure(),
                          if (_deleteError != null) ...[
                            const SizedBox(height: 12),
                            _PlanErrorMessage(text: _deleteError!),
                          ],
                          const SizedBox(height: 12),
                          if (_confirmingDelete)
                            _DeleteConfirmation(
                              deleting: _deleting,
                              onCancel: () =>
                                  setState(() => _confirmingDelete = false),
                              onConfirm: _delete,
                            )
                          else
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                key: const ValueKey(
                                  'status-birth-journey-delete-button',
                                ),
                                onPressed: _deleting
                                    ? null
                                    : () => setState(
                                        () => _confirmingDelete = true,
                                      ),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 16,
                                ),
                                label: const Text('删除计划'),
                                style: TextButton.styleFrom(
                                  foregroundColor:
                                      MomCozyColors.mutedForeground,
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeleteConfirmation extends StatelessWidget {
  const _DeleteConfirmation({
    required this.deleting,
    required this.onCancel,
    required this.onConfirm,
  });

  final bool deleting;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('status-birth-journey-delete-confirmation'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.error.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '确认删除孕期计划？',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: MomCozyColors.foreground,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '删除后，宝宝和我页面不再展示这份计划。需要时可以重新生成。',
            style: _smallPlanText(
              context,
            ).copyWith(color: MomCozyColors.mutedForeground),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: deleting ? null : onCancel,
                  child: const Text('取消'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  key: const ValueKey(
                    'status-birth-journey-delete-confirm-button',
                  ),
                  onPressed: deleting ? null : onConfirm,
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  ),
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: Text(deleting ? '删除中' : '确认删除'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CreatePlanButton extends StatelessWidget {
  const _CreatePlanButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: FilledButton.icon(
        key: const ValueKey('status-pregnancy-plan-agent-button'),
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xff4f8f87),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.fromLTRB(6, 0, 12, 0),
          shape: const StadiumBorder(),
        ),
        icon: const CircleAvatar(
          radius: 10,
          backgroundImage: AssetImage(MomCozyAssets.agentAvatar),
        ),
        label: Text(
          '制定孕期计划',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _PriorityLabel extends StatelessWidget {
  const _PriorityLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final important = label == '重要';
    return Container(
      height: 20,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: important ? const Color(0xfffff0e4) : const Color(0xffeaf6f4),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: important ? const Color(0xffa95522) : const Color(0xff3f8178),
          fontSize: 10,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}

class _MissingPlanStructure extends StatelessWidget {
  const _MissingPlanStructure();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xfffffdfb),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffeadfd8)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.assignment_outlined,
            color: Color(0xff9b7a64),
            size: 28,
          ),
          const SizedBox(height: 8),
          Text(
            '这份计划缺少分层内容',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: MomCozyColors.foreground,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '当前缺少 todo_plan；可以重新制定一份完整计划。',
            textAlign: TextAlign.center,
            style: _smallPlanText(context),
          ),
        ],
      ),
    );
  }
}

class _PlanEmptyDetail extends StatelessWidget {
  const _PlanEmptyDetail({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            color: const Color(0xfffbf7ff),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xffe6d9fb)),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.assignment_outlined,
                color: Color(0xff7d64aa),
                size: 28,
              ),
              const SizedBox(height: 8),
              Text(
                '还没有孕期计划',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: MomCozyColors.foreground,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '生成后会在这里展示当前阶段、后续阶段和临产住院前的待办事项。',
                textAlign: TextAlign.center,
                style: _smallPlanText(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onCreate,
            icon: const CircleAvatar(
              radius: 10,
              backgroundImage: AssetImage(MomCozyAssets.agentAvatar),
            ),
            label: const Text('制定孕期计划'),
          ),
        ),
      ],
    );
  }
}

class _PlanLoadingMessage extends StatelessWidget {
  const _PlanLoadingMessage();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: MomCozyColors.muted.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '正在加载孕期计划…',
        textAlign: TextAlign.center,
        style: _smallPlanText(
          context,
        ).copyWith(color: MomCozyColors.mutedForeground),
      ),
    );
  }
}

class _PlanErrorMessage extends StatelessWidget {
  const _PlanErrorMessage({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.error,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

bool _initiallyExpanded(BirthJourneyPeriod period, int index) {
  return period.initiallyExpanded || period.isCurrent || index == 0;
}

({Color border, Color background, Color foreground}) _periodColors(
  BirthJourneyPeriod period,
) {
  if (period.isCurrent) {
    return (
      border: const Color(0xffb7d8d2),
      background: const Color(0xffeaf6f4),
      foreground: const Color(0xff3f8178),
    );
  }
  if (period.isTerminal) {
    return (
      border: const Color(0xffd9d3e3),
      background: const Color(0xfffaf8ff),
      foreground: const Color(0xff74628b),
    );
  }
  if (period.displayMode == 'expanded') {
    return (
      border: const Color(0xffefd6bf),
      background: const Color(0xfffff2e6),
      foreground: const Color(0xffb65c28),
    );
  }
  return (
    border: const Color(0xffe2edea),
    background: Colors.white,
    foreground: const Color(0xff5f918b),
  );
}

TextStyle _smallPlanText(BuildContext context) {
  return Theme.of(context).textTheme.bodySmall?.copyWith(
        color: const Color(0xff7b6a61),
        fontSize: 11,
        fontWeight: FontWeight.w500,
        height: 1.45,
      ) ??
      const TextStyle(
        color: Color(0xff7b6a61),
        fontSize: 11,
        fontWeight: FontWeight.w500,
        height: 1.45,
      );
}
