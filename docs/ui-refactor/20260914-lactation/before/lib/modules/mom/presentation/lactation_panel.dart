import 'dart:async';
import '../../../shared/format_time.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/shared/widgets/date_time_picker.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_motion.dart';
import '../../../domain/lactation/lactation_record.dart';
import '../../../domain/shared/local_date.dart';
import '../../../domain/shared/product_failure.dart';
import '../../../shared/design_system/momcozy_design_system.dart';
import '../../../shared/widgets/confirm_discard.dart';
import '../../../shared/widgets/product_feedback.dart';
import '../../../shared/widgets/momcozy_line_icon.dart';
import '../application/lactation_controller.dart';
import 'lactation_chart.dart';

const breastSideLabels = {BreastSide.left: '左侧', BreastSide.right: '右侧'};
const breastComfortLabels = {
  BreastComfort.comfortable: '舒服',
  BreastComfort.full: '胀满',
  BreastComfort.painful: '疼痛',
  BreastComfort.uncertain: '说不清楚',
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
    animationStyle: MomCozyMotion.animationStyle(context),
    barrierDismissible: false,
    barrierColor: const Color(0x55302723),
    builder: (context) => Dialog(
      backgroundColor: MomCozyColors.warmFormSurface,
      insetPadding: const EdgeInsets.all(MomCozySpacing.content),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          MediaQuery.sizeOf(context).width < 359 ? 18 : 24,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) => SizedBox(
          width: 440,
          height: math.min(
            MediaQuery.sizeOf(context).height - 24,
            controller.draft == null ? 900 : 650,
          ),
          child: child,
        ),
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
  String? _savedMessage;
  final _formFeedback = GlobalKey();
  final _listFeedback = GlobalKey();

  Future<void> _reveal(GlobalKey key) async {
    await WidgetsBinding.instance.endOfFrame;
    final target = key.currentContext;
    if (mounted && target != null && target.mounted) {
      await Scrollable.ensureVisible(
        target,
        alignment: 1,
        duration: const Duration(milliseconds: 180),
      );
    }
  }

  void _begin([LactationRecord? record]) {
    _savedMessage = null;
    widget.controller.begin(record);
  }

  @override
  void initState() {
    super.initState();
    _initialCreatePending = widget.initialCreate;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_load());
    });
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
    final wasEditing = widget.controller.editing != null;
    if (await widget.controller.save()) {
      if (!mounted) return;
      setState(() => _savedMessage = wasEditing ? '这次记录已更新。' : '这次记录已保存。');
      widget.onChanged?.call();
      await _reveal(_listFeedback);
    } else if (mounted) {
      await _reveal(_formFeedback);
    }
  }

  Future<void> _delete(LactationRecord record) async {
    if (await widget.controller.delete(record) && mounted) {
      setState(() => _savedMessage = null);
      widget.onChanged?.call();
      await _reveal(_listFeedback);
    }
  }

  Future<void> _undo() async {
    await widget.controller.undoDelete();
    if (!mounted) return;
    if (widget.controller.deletion == null &&
        widget.controller.failure == null) {
      setState(() => _savedMessage = '记录已恢复。');
      widget.onChanged?.call();
    }
    await _reveal(_listFeedback);
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
                          if (draft == null)
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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              controller.editing == null ? '添加一条记录' : '编辑这次记录',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (controller.todayRecords.isNotEmpty)
                            TextButton(
                              onPressed: controller.busy ? null : _cancel,
                              child: const Text(
                                '返回记录',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                      const Divider(height: 1),
                      const SizedBox(height: 16),
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
                      Column(
                        key: _formFeedback,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (controller.validationErrors.isNotEmpty)
                            const _LactationFeedback(
                              '请检查记录时间和数值：奶量为 0–2000 ml，亲喂时长为 0–240 分钟的整数。',
                              error: true,
                            ),
                          if (controller.failure case final failure?)
                            ProductErrorView(
                              failure: failure,
                              preserveDraft: true,
                              onRetry:
                                  failure.kind == ProductFailureKind.conflict
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
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          backgroundColor: MomCozyColors.roseSoft,
                          foregroundColor: MomCozyColors.primaryDark,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('取消'),
                      ),
                    ),
                    const SizedBox(width: MomCozySpacing.content),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: controller.busy ? null : _save,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          backgroundColor: MomCozyColors.foreground,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
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
                        height: MediaQuery.sizeOf(context).width < 359
                            ? 190
                            : 218,
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
                                      : () => _begin(),
                                  icon: const Icon(Icons.add, size: 16),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(0, 44),
                                    foregroundColor:
                                        MomCozyColors.warmFormSelected,
                                    side: const BorderSide(
                                      color: MomCozyColors.diarySelectionBorder,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    textStyle: const TextStyle(
                                      fontSize: 12,
                                      fontFamily: MomCozyTypography.fontFamily,
                                      fontFamilyFallback:
                                          MomCozyTypography.fontFamilyFallback,
                                    ),
                                  ),
                                  label: const Text('添加一条'),
                                ),
                              ],
                            ),
                            Column(
                              key: _listFeedback,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (controller.failure case final failure?)
                                  ProductErrorView(
                                    failure: failure,
                                    onRetry: _load,
                                  ),
                                if (_savedMessage != null)
                                  _LactationFeedback(_savedMessage!),
                                if (controller.deletion != null)
                                  _LactationFeedback(
                                    '记录已删除',
                                    warning: true,
                                    action: TextButton(
                                      onPressed: controller.busy ? null : _undo,
                                      child: const Text('撤销'),
                                    ),
                                  ),
                              ],
                            ),
                            if (controller.todayRecords.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 14),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: MomCozyColors.roseSoft,
                                        borderRadius: BorderRadius.all(
                                          Radius.circular(11),
                                        ),
                                      ),
                                      child: SizedBox.square(
                                        dimension: 34,
                                        child: Center(
                                          child: MomCozyLineIcon(
                                            MomCozyLineGlyph.drop,
                                            size: 20,
                                            color: MomCozyColors.primaryDark,
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '今天还没有泌乳记录',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            '添加一次泵奶或亲喂即可。',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color:
                                                  MomCozyColors.mutedForeground,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            for (final record in controller.todayRecords)
                              _RecordRow(
                                record: record,
                                busy: controller.busy,
                                onEdit: () => _begin(record),
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
      _label('记录方式'),
      const SizedBox(height: 8),
      _choiceRow<LactationMethod>(
        options: const {
          LactationMethod.pump: '泵奶',
          LactationMethod.nurse: '亲喂',
        },
        selected: draft.method,
        tabs: true,
        onSelect: (value) => onChanged(draft.copyWith(method: value)),
      ),
      const SizedBox(height: 16),
      _label('时间'),
      const SizedBox(height: 7),
      OutlinedButton(
        onPressed: () async {
          final value = await showMomCozyTimePicker(
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
        style: OutlinedButton.styleFrom(
          backgroundColor: MomCozyColors.card,
          foregroundColor: MomCozyColors.foreground,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            fontFamily: MomCozyTypography.fontFamily,
            fontFamilyFallback: MomCozyTypography.fontFamilyFallback,
          ),
        ),
        child: Row(
          children: [
            Expanded(child: Text(formatClockTime(draft.occurredAt))),
            const Icon(Icons.schedule_rounded, size: 16),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _label('侧别'),
      const SizedBox(height: 7),
      _choiceRow<BreastSide>(
        options: breastSideLabels,
        selected: draft.side,
        tabs: false,
        onSelect: (value) => onChanged(draft.copyWith(side: value)),
      ),
      const SizedBox(height: 16),
      _label(
        '${breastSideLabels[draft.side]}${draft.method == LactationMethod.pump ? '奶量' : '时长'}',
        optional: true,
      ),
      const SizedBox(height: 7),
      TextFormField(
        key: ValueKey('lactation-measurement-${draft.method.name}'),
        initialValue: draft.measurement,
        keyboardType: TextInputType.numberWithOptions(
          decimal: draft.method == LactationMethod.pump,
        ),
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: '—',
          suffixIconConstraints: const BoxConstraints(
            minWidth: 36,
            minHeight: 44,
          ),
          suffixIcon: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              widthFactor: 1,
              child: Text(
                draft.method == LactationMethod.pump ? 'ml' : '分钟',
                style: const TextStyle(
                  fontSize: 11,
                  color: MomCozyColors.mutedForeground,
                ),
              ),
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          filled: true,
          fillColor: MomCozyColors.card,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onChanged: (value) => onChanged(draft.copyWith(measurement: value)),
      ),
      const SizedBox(height: 16),
      ExpansionTile(
        title: Row(
          children: [
            const Expanded(
              child: Text(
                '补充感受与备注',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              draft.feeling != null || draft.note.isNotEmpty ? '已填写' : '可选',
              style: const TextStyle(
                fontSize: 10,
                color: MomCozyColors.mutedForeground,
              ),
            ),
          ],
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: MomCozyColors.border),
        ),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: MomCozyColors.border),
        ),
        backgroundColor: MomCozyColors.card,
        collapsedBackgroundColor: MomCozyColors.card,
        tilePadding: const EdgeInsets.symmetric(horizontal: 11),
        childrenPadding: const EdgeInsets.all(12),
        initiallyExpanded: draft.feeling != null || draft.note.isNotEmpty,
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '本次乳房感受',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 8),
          for (final entries in [
            breastComfortLabels.entries.take(2),
            breastComfortLabels.entries.skip(2),
          ]) ...[
            _choiceRow<BreastComfort>(
              options: Map.fromEntries(entries),
              selected: draft.feeling,
              tabs: false,
              onSelect: (value) => onChanged(
                draft.copyWith(
                  feeling: () => draft.feeling == value ? null : value,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
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

  Widget _label(String title, {bool optional = false}) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: MomCozyColors.mutedForeground,
          ),
        ),
      ),
      if (optional)
        const Text(
          '可选',
          style: TextStyle(fontSize: 10, color: MomCozyColors.mutedForeground),
        ),
    ],
  );

  Widget _choiceRow<T>({
    required Map<T, String> options,
    required T? selected,
    required bool tabs,
    required ValueChanged<T> onSelect,
  }) => Container(
    padding: tabs ? const EdgeInsets.all(4) : EdgeInsets.zero,
    decoration: tabs
        ? BoxDecoration(
            color: MomCozyColors.secondary,
            borderRadius: BorderRadius.circular(10),
          )
        : null,
    child: Row(
      children: [
        for (final entry in options.entries) ...[
          if (entry.key != options.keys.first) const SizedBox(width: 6),
          Expanded(
            child: Semantics(
              selected: entry.key == selected,
              child: OutlinedButton(
                onPressed: () => onSelect(entry.key),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 9,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontFamily: MomCozyTypography.fontFamily,
                    fontFamilyFallback: MomCozyTypography.fontFamilyFallback,
                  ),
                  foregroundColor: entry.key == selected
                      ? MomCozyColors.primaryDark
                      : MomCozyColors.mutedForeground,
                  backgroundColor: entry.key == selected
                      ? tabs
                            ? MomCozyColors.card
                            : MomCozyColors.roseSoft
                      : tabs
                      ? Colors.transparent
                      : MomCozyColors.card,
                  side: BorderSide(
                    color: tabs
                        ? Colors.transparent
                        : entry.key == selected
                        ? MomCozyColors.primary
                        : MomCozyColors.border,
                  ),
                ),
                child: Text(entry.value),
              ),
            ),
          ),
        ],
      ],
    ),
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
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: MomCozyColors.warmFormBorder),
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
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
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
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: MomCozyColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3, right: 8),
            child: Text(
              formatClockTime(value.occurredAt),
              style: const TextStyle(
                fontSize: 10,
                color: MomCozyColors.mutedForeground,
              ),
            ),
          ),
          Container(
            width: 29,
            height: 32,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: MomCozyColors.warmQuietSurface,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: MomCozyLineIcon(
              value is PumpObservation
                  ? MomCozyLineGlyph.drop
                  : MomCozyLineGlyph.baby,
              size: 18,
              color: MomCozyColors.warmIcon,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${value is PumpObservation ? '泵奶' : '亲喂'} · ${breastSideLabels[value.side]}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  lactationMeasurement(value),
                  style: const TextStyle(
                    fontSize: 10,
                    color: MomCozyColors.diaryMuted,
                  ),
                ),
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
          Row(
            key: ValueKey('lactation-record-actions-${record.id}'),
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final action in [
                ('edit', '编辑', onEdit),
                ('delete', '删除', onDelete),
              ])
                TextButton(
                  key: ValueKey('lactation-${action.$1}-${record.id}'),
                  onPressed: busy ? null : action.$3,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(44, 44),
                    foregroundColor: action.$1 == 'delete'
                        ? MomCozyColors.danger
                        : MomCozyColors.diaryMuted,
                    textStyle: const TextStyle(
                      fontSize: 10,
                      fontFamily: MomCozyTypography.fontFamily,
                      fontFamilyFallback: MomCozyTypography.fontFamilyFallback,
                    ),
                  ),
                  child: Text(action.$2),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LactationFeedback extends StatelessWidget {
  const _LactationFeedback(
    this.message, {
    this.warning = false,
    this.error = false,
    this.action,
  });
  final String message;
  final bool warning;
  final bool error;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: error
            ? MomCozyColors.errorSurface
            : warning
            ? MomCozyColors.amberSoft
            : MomCozyColors.careSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            warning || error
                ? Icons.schedule_rounded
                : Icons.check_circle_outline_rounded,
            size: 18,
            color: error
                ? MomCozyColors.danger
                : warning
                ? MomCozyColors.diaryMuted
                : MomCozyColors.care,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: error ? MomCozyColors.danger : null,
              ),
            ),
          ),
          ?action,
        ],
      ),
    ),
  );
}
