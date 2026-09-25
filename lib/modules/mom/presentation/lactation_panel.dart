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
import '../../../shared/design_system/mom_home_tokens.dart';
import '../../../shared/design_system/mom_settings_theme.dart';
import '../../../shared/widgets/mom_settings_widgets.dart';
import '../../../shared/widgets/confirm_discard.dart';
import '../../../shared/widgets/product_feedback.dart';
import '../../../shared/widgets/momcozy_line_icon.dart';
import '../application/lactation_controller.dart';
import 'lactation_chart.dart';

const breastSideLabels = {
  BreastSide.left: 'Left side',
  BreastSide.right: 'Right side',
};
const breastComfortLabels = {
  BreastComfort.comfortable: 'Comfortable',
  BreastComfort.full: 'Full',
  BreastComfort.painful: 'Painful',
  BreastComfort.uncertain: 'Not sure',
};

String lactationMeasurement(LactationObservation value) => switch (value) {
  PumpObservation(:final volumeMl) =>
    volumeMl == null ? 'Amount not recorded' : '${compactNumber(volumeMl)} ml',
  NursingObservation(:final durationMinutes) =>
    durationMinutes == null ? 'Duration not recorded' : '$durationMinutes min',
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
      backgroundColor: MomHomeTokens.background,
      insetPadding: const EdgeInsets.all(MomCozySpacing.content),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
            theme: momSettingsTheme(Theme.of(context)),
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
          theme: momSettingsTheme(Theme.of(context)),
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
      setState(
        () => _savedMessage = wasEditing ? 'Record updated.' : 'Record saved.',
      );
      widget.onChanged?.call();
      await _reveal(_listFeedback);
    } else if (mounted) {
      await _reveal(_formFeedback);
    }
  }

  Future<void> _delete(LactationRecord record) async {
    final deleted = await widget.controller.delete(record);
    if (!mounted) return;
    if (deleted) {
      setState(() => _savedMessage = null);
      widget.onChanged?.call();
    }
    await _reveal(_listFeedback);
  }

  Future<void> _undo() async {
    await widget.controller.undoDelete();
    if (!mounted) return;
    if (widget.controller.deletion == null &&
        widget.controller.failure == null) {
      setState(() => _savedMessage = 'Record restored.');
      widget.onChanged?.call();
    }
    await _reveal(_listFeedback);
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: momSettingsTheme(Theme.of(context)),
    child: AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        final draft = controller.draft;
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) unawaited(_close());
          },
          child: ColoredBox(
            color: MomHomeTokens.background,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ColoredBox(
                  color: MomHomeTokens.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Feeding & pumping today',
                            style: MomHomeTokens.text(
                              20,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          tooltip: 'Close feeding and pumping records',
                          onPressed: controller.busy ? null : _close,
                          icon: const Icon(Icons.close_rounded, size: 22),
                          style: IconButton.styleFrom(
                            foregroundColor: MomHomeTokens.rose,
                            minimumSize: const Size.square(44),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (controller.loading)
                  const Expanded(child: ProductLoadingView())
                else if (!controller.loaded)
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: ProductErrorView(
                          useMomStyle: true,
                          failure: controller.failure!,
                          onRetry: _load,
                        ),
                      ),
                    ),
                  )
                else if (draft != null) ...[
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  controller.editing == null
                                      ? 'Add a record'
                                      : 'Edit this record',
                                  style: MomHomeTokens.text(
                                    16,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (controller.todayRecords.isNotEmpty)
                                TextButton(
                                  onPressed: controller.busy ? null : _cancel,
                                  child: const Text('Back to records'),
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          AbsorbPointer(
                            absorbing: !controller.canEdit,
                            child: _LactationFields(
                              key: ValueKey(
                                '${controller.editing?.id ?? 'new'}-${draft.method.name}',
                              ),
                              draft: draft,
                              onChanged: controller.edit,
                              now: controller.now,
                            ),
                          ),
                          Column(
                            key: _formFeedback,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (controller.validationErrors.isNotEmpty)
                                const _LactationFeedback(
                                  'Check the time and values: milk amount must be 0–2,000 ml, and nursing duration must be a whole number from 0–240 minutes.',
                                  error: true,
                                ),
                              if (controller.failure case final failure?)
                                ProductErrorView(
                                  useMomStyle: true,
                                  failure: failure,
                                  preserveDraft: true,
                                  onRetry:
                                      failure.kind ==
                                          ProductFailureKind.conflict
                                      ? _cancel
                                      : null,
                                ),
                              if (controller.uncertainSave)
                                Padding(
                                  padding: const EdgeInsets.only(top: 14),
                                  child: Text(
                                    'Your save has not been confirmed. Please try again.',
                                    style: MomHomeTokens.text(
                                      13,
                                      color: MomHomeTokens.secondary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  ColoredBox(
                    color: MomHomeTokens.surface,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: controller.busy ? null : _cancel,
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: FilledButton(
                              onPressed: controller.busy ? null : _save,
                              style: FilledButton.styleFrom(
                                disabledBackgroundColor:
                                    MomHomeTokens.neutralSurface,
                                disabledForegroundColor:
                                    MomHomeTokens.secondary,
                              ),
                              child: Text(
                                controller.busy
                                    ? 'Saving…'
                                    : controller.uncertainSave
                                    ? 'Try saving again'
                                    : controller.editing == null
                                    ? 'Save this record'
                                    : 'Save changes',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        // Lay out the daily content together so feedback remains a
                        // valid scroll target even below a large-text chart.
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              MomSettingsCard(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${controller.date.month}/${controller.date.day}\nOne session at a time',
                                          style: MomHomeTokens.text(
                                            14,
                                            color: MomHomeTokens.secondary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: Image.asset(
                                          'assets/images/mom/milk-hero.png',
                                          width: 80,
                                          height: 80,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              _DaySummary(
                                summary: controller.summary(controller.date),
                              ),
                              const SizedBox(height: 14),
                              LactationTrendChart(controller: controller),
                              const SizedBox(height: 14),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final title = Text(
                                    'Today\'s records',
                                    style: MomHomeTokens.text(
                                      18,
                                      weight: FontWeight.w700,
                                    ),
                                  );
                                  final add = FilledButton.icon(
                                    onPressed: controller.busy
                                        ? null
                                        : () => _begin(),
                                    icon: const Icon(Icons.add, size: 18),
                                    label: const Text('Add a record'),
                                  );
                                  return MediaQuery.textScalerOf(
                                            context,
                                          ).scale(1) >
                                          1.4
                                      ? Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            title,
                                            const SizedBox(height: 12),
                                            add,
                                          ],
                                        )
                                      : Row(
                                          children: [
                                            Expanded(child: title),
                                            const SizedBox(width: 12),
                                            add,
                                          ],
                                        );
                                },
                              ),
                              Column(
                                key: _listFeedback,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (controller.failure case final failure?)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 14),
                                      child: ProductErrorView(
                                        useMomStyle: true,
                                        failure: failure,
                                        onRetry: _load,
                                      ),
                                    ),
                                  if (_savedMessage != null)
                                    _LactationFeedback(_savedMessage!),
                                  if (controller.deletion != null)
                                    _LactationFeedback(
                                      'Record deleted',
                                      warning: true,
                                      action: TextButton(
                                        onPressed: controller.busy
                                            ? null
                                            : _undo,
                                        child: const Text('Undo'),
                                      ),
                                    ),
                                ],
                              ),
                              if (controller.todayRecords.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 14),
                                  child: MomSettingsCard(
                                    children: [
                                      Text(
                                        'No feeding or pumping records today',
                                        style: MomHomeTokens.text(
                                          16,
                                          weight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        'Add a pumping or nursing session to get started.',
                                        style: MomHomeTokens.text(
                                          14,
                                          color: MomHomeTokens.secondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              for (final record in controller.todayRecords)
                                Padding(
                                  padding: const EdgeInsets.only(top: 14),
                                  child: _RecordRow(
                                    record: record,
                                    busy: controller.busy,
                                    onEdit: () => _begin(record),
                                    onDelete: () => _delete(record),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    ),
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
      _label('Method'),
      const SizedBox(height: 8),
      _choiceRow<LactationMethod>(
        options: const {
          LactationMethod.pump: 'Pumping',
          LactationMethod.nurse: 'Nursing',
        },
        selected: draft.method,
        tabs: true,
        onSelect: (value) => onChanged(draft.copyWith(method: value)),
      ),
      const SizedBox(height: 16),
      _label('Time'),
      const SizedBox(height: 7),
      OutlinedButton(
        onPressed: () async {
          final base = momSettingsTheme(Theme.of(context));
          // The SDK input picker needs 280 logical pixels inside its padding.
          // Keep both input and dial modes accessible on a 320-wide screen.
          final horizontal = ((MediaQuery.sizeOf(context).width - 32 - 280) / 2)
              .clamp(4.0, 24.0);
          final pickerTheme = base.copyWith(
            timePickerTheme: base.timePickerTheme.copyWith(
              padding: EdgeInsets.symmetric(
                horizontal: horizontal,
                vertical: 20,
              ),
              backgroundColor: MomHomeTokens.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              helpTextStyle: MomHomeTokens.text(16, weight: FontWeight.w700),
              hourMinuteTextStyle: MomHomeTokens.text(
                36,
                weight: FontWeight.w600,
              ),
              hourMinuteTextColor: MomHomeTokens.ink,
              hourMinuteColor: MomHomeTokens.mint,
              dayPeriodColor: MomHomeTokens.mint,
              dayPeriodTextColor: MomHomeTokens.teal,
              dialBackgroundColor: MomCozyColors.roseSoft,
              dialHandColor: MomHomeTokens.rose,
              entryModeIconColor: MomHomeTokens.rose,
              cancelButtonStyle: base.outlinedButtonTheme.style,
              confirmButtonStyle: base.filledButtonTheme.style,
            ),
          );
          final value = await showMomCozyTimePicker(
            context: context,
            initialTime: TimeOfDay.fromDateTime(draft.occurredAt),
            builder: (context, child) =>
                Theme(data: pickerTheme, child: child!),
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
          backgroundColor: MomHomeTokens.surface,
          foregroundColor: MomHomeTokens.ink,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: 'NotoSansSCHome',
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
      _label('Side'),
      const SizedBox(height: 7),
      _choiceRow<BreastSide>(
        options: breastSideLabels,
        selected: draft.side,
        tabs: false,
        onSelect: (value) => onChanged(draft.copyWith(side: value)),
      ),
      const SizedBox(height: 16),
      _label(
        '${breastSideLabels[draft.side]} ${draft.method == LactationMethod.pump ? 'amount' : 'duration'}',
        optional: true,
      ),
      const SizedBox(height: 7),
      TextFormField(
        key: ValueKey('lactation-measurement-${draft.method.name}'),
        initialValue: draft.measurement,
        keyboardType: TextInputType.numberWithOptions(
          decimal: draft.method == LactationMethod.pump,
        ),
        style: const TextStyle(fontSize: 16),
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
                draft.method == LactationMethod.pump ? 'ml' : 'Minutes',
                style: const TextStyle(
                  fontSize: 13,
                  color: MomHomeTokens.secondary,
                ),
              ),
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          filled: true,
          fillColor: MomHomeTokens.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onChanged: (value) => onChanged(draft.copyWith(measurement: value)),
      ),
      const SizedBox(height: 16),
      ExpansionTile(
        title: Row(
          children: [
            const Expanded(
              child: Text(
                'Feelings and notes',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              draft.feeling != null || draft.note.isNotEmpty
                  ? 'Added'
                  : 'Optional',
              style: const TextStyle(
                fontSize: 12,
                color: MomHomeTokens.secondary,
              ),
            ),
          ],
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: MomHomeTokens.border),
        ),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: MomHomeTokens.border),
        ),
        backgroundColor: MomHomeTokens.surface,
        collapsedBackgroundColor: MomHomeTokens.surface,
        tilePadding: const EdgeInsets.symmetric(horizontal: 11),
        childrenPadding: const EdgeInsets.all(12),
        initiallyExpanded: draft.feeling != null || draft.note.isNotEmpty,
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'How did your breasts feel?',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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
            style: MomHomeTokens.text(16),
            initialValue: draft.note,
            maxLength: 2000,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              hintText: 'For example, my right breast feels full',
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
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: MomHomeTokens.secondary,
          ),
        ),
      ),
      if (optional)
        const Text(
          'Optional',
          style: TextStyle(fontSize: 12, color: MomHomeTokens.secondary),
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
            color: MomHomeTokens.neutralSurface,
            borderRadius: BorderRadius.circular(16),
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
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontFamily: 'NotoSansSCHome',
                    fontFamilyFallback: MomCozyTypography.fontFamilyFallback,
                  ),
                  foregroundColor: entry.key == selected
                      ? MomHomeTokens.teal
                      : MomHomeTokens.secondary,
                  backgroundColor: entry.key == selected
                      ? MomHomeTokens.mint
                      : tabs
                      ? Colors.transparent
                      : MomHomeTokens.surface,
                  side: BorderSide(
                    color: tabs
                        ? Colors.transparent
                        : entry.key == selected
                        ? MomHomeTokens.teal
                        : MomHomeTokens.border,
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
  Widget build(BuildContext context) {
    final pump = _tile(
      'Pumping',
      summary.pumpCount == 0
          ? 'Not recorded'
          : '${summary.measuredVolumeMl == null ? '' : '${compactNumber(summary.measuredVolumeMl!)} ml · '}${summary.pumpCount} sessions',
      detail: summary.unmeasuredPumpCount == 0
          ? null
          : '${summary.unmeasuredPumpCount} sessions without an amount',
    );
    final nursing = _tile(
      'Nursing',
      summary.nursingCount == 0
          ? 'Not recorded'
          : '${summary.nursingCount} sessions${summary.nursingMinutes == null ? '' : ' · ${summary.nursingMinutes} min'}',
    );
    return MediaQuery.textScalerOf(context).scale(1) > 1.4
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [pump, const SizedBox(height: 14), nursing],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: pump),
              const SizedBox(width: 14),
              Expanded(child: nursing),
            ],
          );
  }

  Widget _tile(String title, String value, {String? detail}) => MomSettingsCard(
    children: [
      Text(
        title,
        style: MomHomeTokens.text(13, color: MomHomeTokens.secondary),
      ),
      Text(value, style: MomHomeTokens.text(16, weight: FontWeight.w600)),
      if (detail != null)
        Text(
          detail,
          style: MomHomeTokens.text(13, color: MomHomeTokens.secondary),
        ),
    ],
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
    return MomSettingsCard(
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: MomHomeTokens.mint,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: MomCozyLineIcon(
                value is PumpObservation
                    ? MomCozyLineGlyph.drop
                    : MomCozyLineGlyph.baby,
                size: 22,
                color: MomHomeTokens.teal,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${value is PumpObservation ? 'Pumping' : 'Nursing'} · ${breastSideLabels[value.side]}',
                    style: MomHomeTokens.text(16, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatClockTime(value.occurredAt),
                    style: MomHomeTokens.text(
                      13,
                      color: MomHomeTokens.secondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        Text(
          lactationMeasurement(value),
          style: MomHomeTokens.text(20, weight: FontWeight.w600),
        ),
        if (value.feeling != null)
          Text(
            breastComfortLabels[value.feeling]!,
            style: MomHomeTokens.text(14, color: MomHomeTokens.secondary),
          ),
        if (value.note.isNotEmpty)
          Text(
            value.note,
            style: MomHomeTokens.text(14, color: MomHomeTokens.secondary),
          ),
        Row(
          key: ValueKey('lactation-record-actions-${record.id}'),
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            for (final action in [
              ('edit', 'Edit', onEdit),
              ('delete', 'Delete', onDelete),
            ])
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: OutlinedButton(
                  key: ValueKey('lactation-${action.$1}-${record.id}'),
                  onPressed: busy ? null : action.$3,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(80, 44),
                    foregroundColor: action.$1 == 'delete'
                        ? MomCozyColors.danger
                        : MomHomeTokens.rose,
                  ),
                  child: Text(action.$2),
                ),
              ),
          ],
        ),
      ],
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
  final bool warning, error;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: MomSettingsCard(
        color: error
            ? MomCozyColors.errorSurface
            : warning
            ? MomCozyColors.amberSoft
            : MomHomeTokens.mint,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                warning || error
                    ? Icons.schedule_rounded
                    : Icons.check_circle_outline_rounded,
                size: 18,
                color: error ? MomCozyColors.danger : MomHomeTokens.teal,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: MomHomeTokens.text(
                    13,
                    color: error ? MomCozyColors.danger : MomHomeTokens.teal,
                  ),
                ),
              ),
            ],
          ),
          ?action,
        ],
      ),
    ),
  );
}
