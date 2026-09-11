import 'dart:async';
import '../../../shared/format_time.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../domain/lactation/lactation_record.dart';
import '../../../domain/shared/local_date.dart';
import '../../../domain/shared/product_failure.dart';
import '../../../shared/design_system/momcozy_design_system.dart';
import '../../../shared/widgets/choice_field.dart';
import '../../../shared/widgets/confirm_discard.dart';
import '../../../shared/widgets/product_feedback.dart';
import '../application/lactation_controller.dart';
import 'lactation_chart.dart';

const breastSideLabels = {BreastSide.left: '左侧', BreastSide.right: '右侧'};
const breastComfortLabels = {
  BreastComfort.comfortable: '舒适',
  BreastComfort.full: '有些胀',
  BreastComfort.painful: '不舒服 / 疼痛',
  BreastComfort.uncertain: '说不清',
};

String lactationMeasurement(LactationObservation value) => switch (value) {
  PumpObservation(:final volumeMl) =>
    volumeMl == null ? '奶量未填写' : '${compactNumber(volumeMl)} ml',
  NursingObservation(:final durationMinutes) =>
    durationMinutes == null ? '时长未填写' : '$durationMinutes 分钟',
};
String compactNumber(num value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString();

Future<void> showLactationPanel(
  BuildContext context, {
  required LactationRepository repository,
  required String ownerUserId,
  required LocalDate date,
  required DateTime Function() now,
  bool create = false,
  VoidCallback? onChanged,
}) async {
  final controller = LactationController(
    repository: repository,
    ownerUserId: ownerUserId,
    date: date,
    now: now,
  );
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => Dialog(
      backgroundColor: MomCozyColors.background,
      insetPadding: const EdgeInsets.all(MomCozySpacing.content),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: MomCozyLayout.maxAppWidth,
        height: math.min(MediaQuery.sizeOf(context).height * .9, 780),
        child: LactationPanel(
          controller: controller,
          initialCreate: create,
          onChanged: onChanged,
          onClose: () => Navigator.pop(context),
        ),
      ),
    ),
  );
  controller.dispose();
}

class LactationPanel extends StatefulWidget {
  const LactationPanel({
    super.key,
    required this.controller,
    required this.onClose,
    this.initialCreate = false,
    this.onChanged,
  });
  final LactationController controller;
  final VoidCallback onClose;
  final bool initialCreate;
  final VoidCallback? onChanged;
  @override
  State<LactationPanel> createState() => _LactationPanelState();
}

class _LactationPanelState extends State<LactationPanel> {
  bool _closing = false;
  bool _initialCreatePending = false;
  @override
  void initState() {
    super.initState();
    _initialCreatePending = widget.initialCreate;
    unawaited(_load());
  }

  Future<void> _load() async {
    await widget.controller.load();
    if (!mounted) return;
    if (_initialCreatePending && widget.controller.loaded) {
      _initialCreatePending = false;
      widget.controller.begin();
    }
  }

  Future<void> _close() async {
    final controller = widget.controller;
    if (_closing || controller.busy) return;
    _closing = true;
    try {
      if (controller.draft != null &&
          !await confirmDiscard(
            context,
            uncertainSave: controller.uncertainSave,
          )) {
        return;
      }
      if (mounted) widget.onClose();
    } finally {
      _closing = false;
    }
  }

  Future<void> _cancel() async {
    if (!await confirmDiscard(
          context,
          uncertainSave: widget.controller.uncertainSave,
        ) ||
        !mounted) {
      return;
    }
    widget.controller.cancel();
    await _load();
  }

  Future<void> _save() async {
    if (await widget.controller.save() && mounted) widget.onChanged?.call();
  }

  Future<void> _delete(LactationRecord record) async {
    if (await widget.controller.delete(record) && mounted) {
      widget.onChanged?.call();
    }
  }

  Future<void> _undo() async {
    await widget.controller.undoDelete();
    if (mounted) widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      final draft = controller.draft;
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) unawaited(_close());
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (controller.loading || !controller.loaded || draft != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '今日泌乳',
                            style: TextStyle(
                              fontSize: MomCozyTypography.headingSize,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${controller.date.month} 月 ${controller.date.day} 日 · 一次一次，慢慢记录',
                            style: const TextStyle(
                              color: MomCozyColors.mutedForeground,
                              fontSize: MomCozyTypography.captionSize,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: '关闭泌乳记录',
                      onPressed: controller.busy ? null : _close,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
            if (controller.loading)
              const Expanded(child: ProductLoadingView())
            else if (!controller.loaded)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(MomCozySpacing.card),
                    child: ProductErrorView(
                      failure: controller.failure!,
                      onRetry: _load,
                    ),
                  ),
                ),
              )
            else if (draft != null) ...[
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(MomCozySpacing.card),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        controller.editing == null ? '添加一条记录' : '编辑这次记录',
                        style: const TextStyle(
                          fontSize: MomCozyTypography.bodyLargeSize,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: MomCozySpacing.card),
                      AbsorbPointer(
                        absorbing: !controller.canEdit,
                        child: Opacity(
                          opacity: controller.canEdit ? 1 : .6,
                          child: _LactationFields(
                            key: ValueKey(
                              '${controller.editing?.id ?? 'new'}-${draft.method.name}',
                            ),
                            draft: draft,
                            onChanged: controller.edit,
                            now: controller.now,
                          ),
                        ),
                      ),
                      if (controller.validationErrors.isNotEmpty)
                        const Text(
                          '请检查记录时间和数值：奶量为 0–2000 ml，亲喂时长为 0–240 分钟的整数。',
                          style: TextStyle(color: MomCozyColors.danger),
                        ),
                      if (controller.failure case final failure?)
                        ProductErrorView(
                          failure: failure,
                          preserveDraft: true,
                          onRetry: failure.kind == ProductFailureKind.conflict
                              ? _cancel
                              : null,
                        ),
                      if (controller.uncertainSave)
                        const Text(
                          '保存结果还未确认，请重试这次保存。',
                          style: TextStyle(
                            color: MomCozyColors.mutedForeground,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: controller.busy ? null : _cancel,
                        child: const Text('取消'),
                      ),
                    ),
                    const SizedBox(width: MomCozySpacing.content),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: controller.busy ? null : _save,
                        child: Text(
                          controller.busy
                              ? '正在保存…'
                              : controller.uncertainSave
                              ? '重试保存'
                              : controller.editing == null
                              ? '保存这次记录'
                              : '保存修改',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    children: [
                      SizedBox(
                        height: 218,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.asset(
                              'assets/images/mom/milk-hero.png',
                              fit: BoxFit.cover,
                            ),
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    MomCozyColors.milkChartBackground,
                                    MomCozyColors.milkChartFade,
                                  ],
                                  stops: [0, .45],
                                ),
                              ),
                            ),
                            Positioned(
                              top: 16,
                              left: 22,
                              right: 8,
                              child: Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      '今日泌乳',
                                      style: TextStyle(
                                        fontSize: MomCozyTypography.headingSize,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: '关闭泌乳记录',
                                    onPressed: controller.busy ? null : _close,
                                    icon: const Icon(Icons.close_rounded),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      LactationTrendChart(controller: controller),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _DaySummary(
                              summary: controller.summary(controller.date),
                            ),
                            const SizedBox(height: MomCozySpacing.card),
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    '今日记录',
                                    style: TextStyle(
                                      fontSize: MomCozyTypography.bodyLargeSize,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: controller.busy
                                      ? null
                                      : () => controller.begin(),
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('添加一条'),
                                ),
                              ],
                            ),
                            if (controller.failure case final failure?)
                              ProductErrorView(
                                failure: failure,
                                onRetry: _load,
                              ),
                            if (controller.deletion != null)
                              Row(
                                children: [
                                  const Expanded(child: Text('记录已删除')),
                                  TextButton(
                                    onPressed: controller.busy ? null : _undo,
                                    child: const Text('撤销'),
                                  ),
                                ],
                              ),
                            if (controller.todayRecords.isEmpty)
                              const ProductEmptyView(
                                title: '今天还没有泌乳记录',
                                description: '添加一次泵奶或亲喂即可。',
                              ),
                            for (final record in controller.todayRecords)
                              _RecordRow(
                                record: record,
                                busy: controller.busy,
                                onEdit: () => controller.begin(record),
                                onDelete: () => _delete(record),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class _LactationFields extends StatelessWidget {
  const _LactationFields({
    super.key,
    required this.draft,
    required this.onChanged,
    required this.now,
  });
  final LactationDraft draft;
  final ValueChanged<LactationDraft> onChanged;
  final DateTime Function() now;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text('记录方式', style: TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: MomCozySpacing.statusGap),
      SegmentedButton<LactationMethod>(
        segments: const [
          ButtonSegment(value: LactationMethod.pump, label: Text('泵奶')),
          ButtonSegment(value: LactationMethod.nurse, label: Text('亲喂')),
        ],
        selected: {draft.method},
        onSelectionChanged: (value) =>
            onChanged(draft.copyWith(method: value.first)),
      ),
      const SizedBox(height: MomCozySpacing.section),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('时间', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: MomCozySpacing.statusGap),
                OutlinedButton.icon(
                  onPressed: () async {
                    final value = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(draft.occurredAt),
                    );
                    if (value != null) {
                      onChanged(
                        draft.copyWith(
                          occurredAt: DateTime(
                            draft.occurredAt.year,
                            draft.occurredAt.month,
                            draft.occurredAt.day,
                            value.hour,
                            value.minute,
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.schedule_rounded, size: 18),
                  label: Text(formatClockTime(draft.occurredAt)),
                ),
              ],
            ),
          ),
          const SizedBox(width: MomCozySpacing.content),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('侧别', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: MomCozySpacing.statusGap),
                SegmentedButton<BreastSide>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    padding: WidgetStatePropertyAll(EdgeInsets.zero),
                  ),
                  segments: const [
                    ButtonSegment(value: BreastSide.left, label: Text('左侧')),
                    ButtonSegment(value: BreastSide.right, label: Text('右侧')),
                  ],
                  selected: {draft.side},
                  onSelectionChanged: (value) =>
                      onChanged(draft.copyWith(side: value.first)),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: MomCozySpacing.section),
      TextFormField(
        key: ValueKey('lactation-measurement-${draft.method.name}'),
        initialValue: draft.measurement,
        keyboardType: TextInputType.numberWithOptions(
          decimal: draft.method == LactationMethod.pump,
        ),
        decoration: InputDecoration(
          labelText:
              '${breastSideLabels[draft.side]}${draft.method == LactationMethod.pump ? '奶量' : '时长'}（可选）',
          hintText: '—',
          suffixText: draft.method == LactationMethod.pump ? 'ml' : '分钟',
        ),
        onChanged: (value) => onChanged(draft.copyWith(measurement: value)),
      ),
      const SizedBox(height: MomCozySpacing.page),
      ExpansionTile(
        title: const Text('补充感受与备注'),
        subtitle: Text(
          draft.feeling != null || draft.note.isNotEmpty ? '已填写' : '可选',
        ),
        tilePadding: EdgeInsets.zero,
        initiallyExpanded: draft.feeling != null || draft.note.isNotEmpty,
        children: [
          ChoiceField(
            title: '本次乳房感受',
            options: breastComfortLabels,
            selected: {if (draft.feeling != null) draft.feeling!},
            onChanged: (value) =>
                onChanged(draft.copyWith(feeling: () => value.firstOrNull)),
          ),
          TextFormField(
            initialValue: draft.note,
            maxLength: 2000,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: '备注（可选）',
              hintText: '例如：右侧有些胀',
            ),
            onChanged: (value) => onChanged(draft.copyWith(note: value)),
          ),
        ],
      ),
    ],
  );
}

class _DaySummary extends StatelessWidget {
  const _DaySummary({required this.summary});
  final LactationDaySummary summary;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: _tile(
          '泵奶',
          summary.pumpCount == 0
              ? '未记录'
              : '${summary.measuredVolumeMl == null ? '' : '${compactNumber(summary.measuredVolumeMl!)} ml · '}${summary.pumpCount} 次',
          detail: summary.unmeasuredPumpCount == 0
              ? null
              : '${summary.unmeasuredPumpCount} 次未填写奶量',
        ),
      ),
      const SizedBox(width: MomCozySpacing.compact),
      Expanded(
        child: _tile(
          '亲喂',
          summary.nursingCount == 0
              ? '未记录'
              : '${summary.nursingCount} 次${summary.nursingMinutes == null ? '' : ' · ${summary.nursingMinutes} 分'}',
        ),
      ),
    ],
  );
  Widget _tile(String title, String value, {String? detail}) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(MomCozyRadii.control),
      border: Border.all(color: MomCozyColors.border),
      color: MomCozyColors.raised.withValues(alpha: .3),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: MomCozyColors.mutedForeground,
            fontSize: MomCozyTypography.captionSize,
          ),
        ),
        const SizedBox(height: MomCozySpacing.compact),
        Text(
          value,
          style: const TextStyle(
            fontSize: MomCozyTypography.bodySize,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (detail != null)
          Text(
            detail,
            style: const TextStyle(
              fontSize: MomCozyTypography.microSize,
              color: MomCozyColors.mutedForeground,
            ),
          ),
      ],
    ),
  );
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({
    required this.record,
    required this.busy,
    required this.onEdit,
    required this.onDelete,
  });
  final LactationRecord record;
  final bool busy;
  final VoidCallback onEdit, onDelete;
  @override
  Widget build(BuildContext context) {
    final value = record.observation;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: MomCozyColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3, right: 12),
            child: Text(
              formatClockTime(value.occurredAt),
              style: const TextStyle(
                fontSize: MomCozyTypography.captionSize,
                color: MomCozyColors.mutedForeground,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${value is PumpObservation ? '泵奶' : '亲喂'} · ${breastSideLabels[value.side]}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(lactationMeasurement(value)),
                if (value.feeling != null)
                  Text(
                    breastComfortLabels[value.feeling]!,
                    style: const TextStyle(
                      color: MomCozyColors.mutedForeground,
                      fontSize: MomCozyTypography.captionSize,
                    ),
                  ),
                if (value.note.isNotEmpty)
                  Text(
                    value.note,
                    style: const TextStyle(
                      color: MomCozyColors.mutedForeground,
                      fontSize: MomCozyTypography.captionSize,
                    ),
                  ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            key: ValueKey('lactation-record-actions-${record.id}'),
            tooltip: '编辑或删除记录',
            enabled: !busy,
            onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('编辑')),
              PopupMenuItem(
                value: 'delete',
                child: Text(
                  '删除',
                  style: TextStyle(color: MomCozyColors.danger),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
