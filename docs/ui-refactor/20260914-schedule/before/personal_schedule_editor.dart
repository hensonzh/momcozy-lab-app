import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/shared/widgets/date_time_picker.dart';
import '../../../domain/shared/local_date.dart';
import '../../../domain/shared/product_failure.dart';
import '../../../shared/design_system/momcozy_design_system.dart';
import '../../../shared/widgets/confirm_discard.dart';
import '../../../shared/widgets/momcozy_line_icon.dart';
import '../application/schedule_controller.dart';
import '../domain/schedule.dart';

class PersonalScheduleEditor extends StatefulWidget {
  const PersonalScheduleEditor({
    super.key,
    required this.controller,
    this.existing,
    this.now = DateTime.now,
  });
  final ScheduleController controller;
  final PersonalScheduleEntry? existing;
  final DateTime Function() now;
  @override
  State<PersonalScheduleEditor> createState() => _PersonalScheduleEditorState();
}

class _PersonalScheduleEditorState extends State<PersonalScheduleEditor> {
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _note = TextEditingController(text: widget.existing?.note ?? '');
  late final _initialDate =
      widget.existing?.date ?? widget.controller.state.selected;
  late var _date = _initialDate;
  late var _time = widget.existing?.startTime ?? '09:00';
  String _createKey = 'schedule-${DateTime.now().microsecondsSinceEpoch}';
  bool _busy = false, _uncertain = false, _allowPop = false, _closing = false;
  ProductFailure? _failure;
  bool get _editable => !_busy && !_uncertain;
  bool get _dirty =>
      _title.text != (widget.existing?.title ?? '') ||
      _note.text != (widget.existing?.note ?? '') ||
      _date != _initialDate ||
      _time != (widget.existing?.startTime ?? '09:00');

  Future<void> _close([bool saved = false]) async {
    if (_busy || _closing) return;
    _closing = true;
    if (!saved &&
        (_dirty || _uncertain) &&
        !await confirmDiscard(context, uncertainSave: _uncertain)) {
      _closing = false;
      return;
    }
    if (!mounted) return;
    setState(() => _allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.pop(context, saved);
  }

  Future<void> _save() async {
    if (_busy || _title.text.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await widget.controller.savePersonal(
        existing: widget.existing,
        title: _title.text.trim(),
        date: _date,
        startTime: _time,
        note: _note.text.trim(),
        idempotencyKey: _createKey,
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _uncertain = false;
      });
      await _close(true);
    } catch (error) {
      if (!mounted) return;
      final failure = error is ProductFailure
          ? error
          : const ProductFailure(ProductFailureKind.unavailable);
      setState(() {
        _busy = false;
        _failure = failure;
        _uncertain =
            failure.kind == ProductFailureKind.offline ||
            failure.kind == ProductFailureKind.unavailable;
        if (!_uncertain) {
          _createKey = 'schedule-${DateTime.now().microsecondsSinceEpoch}';
        }
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showMomCozyDatePicker(
      context: context,
      initialDate: DateTime(_date.year, _date.month, _date.day),
      currentDate: widget.now(),
      firstDate: DateTime(_date.year - 2),
      lastDate: DateTime(_date.year + 2),
    );
    if (picked != null && mounted) {
      setState(() => _date = LocalDate.fromDateTime(picked));
    }
  }

  Future<void> _pickTime() async {
    final picked = await showMomCozyTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(_time.substring(0, 2)),
        minute: int.parse(_time.substring(3)),
      ),
    );
    if (picked != null && mounted) {
      setState(
        () => _time =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}',
      );
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stacked =
        MediaQuery.sizeOf(context).width <= 390 ||
        MediaQuery.textScalerOf(context).scale(13) > 18;
    final dateField = _ScheduleField(
      label: '日期',
      child: OutlinedButton(
        key: const ValueKey('schedule-date'),
        onPressed: _editable ? _pickDate : null,
        style: _pickerStyle(context),
        child: Row(
          children: [
            Expanded(child: Text(_date.toString())),
            const SizedBox(width: 8),
            const Icon(Icons.calendar_today_outlined, size: 16),
          ],
        ),
      ),
    );
    final timeField = _ScheduleField(
      label: '开始时间',
      child: OutlinedButton(
        key: const ValueKey('schedule-time'),
        onPressed: _editable ? _pickTime : null,
        style: _pickerStyle(context),
        child: Row(
          children: [
            Expanded(child: Text(_time)),
            const SizedBox(width: 8),
            const Icon(Icons.schedule_outlined, size: 16),
          ],
        ),
      ),
    );
    return PopScope<bool>(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: _ScheduleDialogFrame(
        title: widget.existing == null ? '添加日程' : '修改日程',
        onClose: _busy ? null : () => _close(),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ScheduleField(
              label: '日程名称',
              child: TextField(
                key: const ValueKey('schedule-title'),
                controller: _title,
                enabled: _editable,
                autofocus: true,
                maxLength: 40,
                style: const TextStyle(fontSize: 13),
                onChanged: (_) => setState(() => _failure = null),
                decoration: _input('例如：宝宝体检'),
              ),
            ),
            const SizedBox(height: 14),
            if (stacked) ...[
              dateField,
              const SizedBox(height: 14),
              timeField,
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 6, child: dateField),
                  const SizedBox(width: 10),
                  Expanded(flex: 4, child: timeField),
                ],
              ),
            const SizedBox(height: 14),
            _ScheduleField(
              label: '备注',
              optional: true,
              child: TextField(
                key: const ValueKey('schedule-note'),
                controller: _note,
                enabled: _editable,
                maxLength: 120,
                minLines: 3,
                maxLines: 5,
                style: const TextStyle(fontSize: 13, height: 1.45),
                onChanged: (_) => setState(() => _failure = null),
                decoration: _input('需要准备的东西或地点'),
              ),
            ),
          ],
        ),
        footer: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_failure != null)
              Semantics(
                liveRegion: true,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _failureMessage,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: MomCozyColors.danger,
                    ),
                  ),
                ),
              ),
            FilledButton(
              key: const ValueKey('schedule-save'),
              onPressed: _busy || _title.text.trim().isEmpty ? null : _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                textStyle: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontSize: 14),
              ),
              child: Text(
                _busy
                    ? '正在保存…'
                    : _uncertain
                    ? '重试确认保存'
                    : widget.existing == null
                    ? '添加到日程'
                    : '保存修改',
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _failureMessage => switch (_failure?.kind) {
    ProductFailureKind.conflict => '日程已发生变化。请保留需要的内容，关闭后刷新并核对。',
    ProductFailureKind.unauthenticated => '登录已过期。请重新登录后继续。',
    ProductFailureKind.forbidden => '当前账号无法修改这条日程。',
    ProductFailureKind.invalid => '请检查填写内容后重试，草稿仍然保留。',
    _ => '保存结果暂未确认，草稿仍然保留。请重试确认后再修改。',
  };
  InputDecoration _input(String hint) => InputDecoration(
    hintText: hint,
    counterText: '',
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 13),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(11),
      borderSide: const BorderSide(color: MomCozyColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(11),
      borderSide: const BorderSide(color: MomCozyColors.primary),
    ),
  );
  ButtonStyle _pickerStyle(BuildContext context) => OutlinedButton.styleFrom(
    minimumSize: const Size.fromHeight(46),
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
    foregroundColor: MomCozyColors.foreground,
    side: const BorderSide(color: MomCozyColors.border),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
    textStyle: Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(fontSize: 13, fontWeight: FontWeight.w500),
  );
}

class _ScheduleField extends StatelessWidget {
  const _ScheduleField({
    required this.label,
    required this.child,
    this.optional = false,
  });
  final String label;
  final Widget child;
  final bool optional;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: MomCozyColors.mutedForeground,
              ),
            ),
          ),
          if (optional)
            const Text(
              '选填',
              style: TextStyle(
                fontSize: 10,
                color: MomCozyColors.mutedForeground,
              ),
            ),
        ],
      ),
      const SizedBox(height: 7),
      child,
    ],
  );
}

class _ScheduleDialogFrame extends StatelessWidget {
  const _ScheduleDialogFrame({
    required this.title,
    required this.onClose,
    required this.content,
    required this.footer,
    this.maxHeight = 560,
  });
  final String title;
  final VoidCallback? onClose;
  final Widget content, footer;
  final double maxHeight;
  @override
  Widget build(BuildContext context) => Dialog(
    alignment: Alignment.bottomCenter,
    insetPadding: const EdgeInsets.all(18),
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 440, maxHeight: maxHeight),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 320;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: onClose,
                      style: TextButton.styleFrom(
                        foregroundColor: MomCozyColors.mutedForeground,
                        textStyle: Theme.of(
                          context,
                        ).textTheme.labelMedium?.copyWith(fontSize: 12),
                      ),
                      child: const Text('关闭'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        content,
                        if (compact) ...[const SizedBox(height: 14), footer],
                      ],
                    ),
                  ),
                ),
                if (!compact) ...[const SizedBox(height: 14), footer],
              ],
            );
          },
        ),
      ),
    ),
  );
}

class PersonalScheduleDeleteDialog extends StatelessWidget {
  const PersonalScheduleDeleteDialog({super.key, required this.entry});
  final PersonalScheduleEntry entry;
  @override
  Widget build(BuildContext context) => _ScheduleDialogFrame(
    title: '删除日程？',
    maxHeight: 430,
    onClose: () => Navigator.pop(context, false),
    content: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: MomCozyColors.amberSoft,
                borderRadius: BorderRadius.circular(11),
              ),
              child: const MomCozyLineIcon(
                MomCozyLineGlyph.calendar,
                size: 18,
                color: MomCozyColors.amber,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${entry.date} · ${entry.startTime}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: MomCozyColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Divider(height: 1),
        const SizedBox(height: 16),
        const Text(
          '删除后将从日历和当日日程中移除，且无法恢复。',
          style: TextStyle(
            fontSize: 12,
            height: 1.55,
            color: MomCozyColors.mutedForeground,
          ),
        ),
      ],
    ),
    footer: LayoutBuilder(
      builder: (context, constraints) {
        final actions = [
          FilledButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('保留日程'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, true),
            style: OutlinedButton.styleFrom(
              foregroundColor: MomCozyColors.primaryDark,
              side: const BorderSide(color: MomCozyColors.primary),
            ),
            child: const Text('确认删除'),
          ),
        ];
        return MediaQuery.textScalerOf(context).scale(14) > 20
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [actions[0], const SizedBox(height: 9), actions[1]],
              )
            : Row(
                children: [
                  Expanded(child: actions[0]),
                  const SizedBox(width: 9),
                  Expanded(child: actions[1]),
                ],
              );
      },
    ),
  );
}
