import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'schedule_design.dart';
import '../../../shared/design_system/mom_home_tokens.dart';
import '../../../shared/design_system/mom_settings_theme.dart';
import '../../../shared/widgets/mom_settings_widgets.dart';
import 'package:momcozy_flutter_app/shared/widgets/date_time_picker.dart';
import '../../../domain/shared/local_date.dart';
import '../../../domain/shared/product_failure.dart';
import '../../../shared/design_system/momcozy_design_system.dart';
import '../../../shared/widgets/confirm_discard.dart';
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
  bool _busy = false,
      _allowPop = false,
      _closing = false,
      _titleTouched = false;
  late PersonalScheduleEntry? _workingEntry = widget.existing;
  ({String title, LocalDate date, String time, String note})? _createAttempt;
  ({String title, LocalDate date, String time, String note}) get _draft => (
    title: _title.text.trim(),
    date: _date,
    time: _time,
    note: _note.text.trim(),
  );
  ProductFailure? _failure;
  bool get _editable => !_busy;
  bool get _dirty =>
      _title.text != (widget.existing?.title ?? '') ||
      _note.text != (widget.existing?.note ?? '') ||
      _date != _initialDate ||
      _time != (widget.existing?.startTime ?? '09:00');

  Future<void> _close([bool saved = false]) async {
    if (_busy || _closing) return;
    _closing = true;
    if (!saved &&
        _dirty &&
        !await confirmDiscard(
          context,
          theme: momSettingsTheme(Theme.of(context)),
        )) {
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
      final draft = _draft;
      if (_workingEntry == null) {
        // A retry reuses the original payload and key, even if the user has
        // edited the retained draft. Apply later edits to the recovered entry.
        final attempt = _createAttempt ??= draft;
        _workingEntry = await widget.controller.savePersonal(
          title: attempt.title,
          date: attempt.date,
          startTime: attempt.time,
          note: attempt.note,
          idempotencyKey: _createKey,
        );
        if (attempt != draft) {
          _workingEntry = await widget.controller.savePersonal(
            existing: _workingEntry,
            title: draft.title,
            date: draft.date,
            startTime: draft.time,
            note: draft.note,
          );
        }
      } else {
        _workingEntry = await widget.controller.savePersonal(
          existing: _workingEntry,
          title: draft.title,
          date: draft.date,
          startTime: draft.time,
          note: draft.note,
        );
      }
      if (!mounted) return;
      setState(() => _busy = false);
      await _close(true);
    } catch (error) {
      if (!mounted) return;
      final failure = error is ProductFailure
          ? error
          : const ProductFailure(ProductFailureKind.unavailable);
      setState(() {
        _busy = false;
        _failure = failure;
        if (failure.kind != ProductFailureKind.offline &&
            failure.kind != ProductFailureKind.unavailable) {
          _createAttempt = null;
          _createKey = 'schedule-${DateTime.now().microsecondsSinceEpoch}';
        }
      });
    }
  }

  ThemeData _pickerTheme(BuildContext context) {
    final base = momSettingsTheme(Theme.of(context));
    return base.copyWith(
      timePickerTheme: base.timePickerTheme.copyWith(
        dayPeriodColor: MomHomeTokens.mint,
        dayPeriodTextColor: MomHomeTokens.teal,
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showMomCozyDatePicker(
      context: context,
      initialDate: DateTime(_date.year, _date.month, _date.day),
      currentDate: widget.now(),
      theme: _pickerTheme(context),
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
      builder: (context, child) =>
          Theme(data: _pickerTheme(context), child: child!),
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
    final dateField = _ScheduleField(
      label: 'Date',
      child: OutlinedButton(
        key: const ValueKey('schedule-date'),
        onPressed: _editable ? _pickDate : null,
        style: _pickerStyle(context),
        child: Row(
          children: [
            Expanded(child: Text(_date.toString())),
            const SizedBox(width: 8),
            SvgPicture.asset(
              'assets/images/schedule_date.svg',
              width: 16,
              height: 16,
            ),
          ],
        ),
      ),
    );
    final timeField = _ScheduleField(
      label: 'Start time',
      child: OutlinedButton(
        key: const ValueKey('schedule-time'),
        onPressed: _editable ? _pickTime : null,
        style: _pickerStyle(context),
        child: Row(children: [Expanded(child: Text(_time))]),
      ),
    );
    return PopScope<bool>(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: _ScheduleDialogFrame(
        title: widget.existing == null ? 'Add to schedule' : 'Edit schedule item',
        onClose: _busy ? null : () => _close(),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ScheduleField(
              label: 'Title',
              child: TextField(
                key: const ValueKey('schedule-title'),
                controller: _title,
                enabled: _editable,
                autofocus: false,
                maxLength: 40,
                style: ScheduleDesign.text(13, lineHeight: 18),
                onChanged: (_) => setState(() {
                  _failure = null;
                  _titleTouched = true;
                }),
                decoration: _input('For example: baby checkup').copyWith(
                  errorText: _titleTouched && _title.text.trim().isEmpty
                      ? 'Enter a title'
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 14),
            dateField,
            const SizedBox(height: 14),
            timeField,
            const SizedBox(height: 14),
            _ScheduleField(
              label: 'Notes',
              optional: true,
              child: TextField(
                key: const ValueKey('schedule-note'),
                controller: _note,
                enabled: _editable,
                maxLength: 120,
                minLines: 3,
                maxLines: 5,
                style: ScheduleDesign.text(13, lineHeight: 20),
                onChanged: (_) => setState(() => _failure = null),
                decoration: _input('What to bring or where to go'),
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
                  child: MomSettingsCard(
                    color: MomCozyColors.amberSoft,
                    children: [
                      Text(
                        _failureMessage,
                        style: MomHomeTokens.text(13, height: 1.55),
                      ),
                    ],
                  ),
                ),
              ),
            FilledButton(
              key: const ValueKey('schedule-save'),
              onPressed: _busy || _title.text.trim().isEmpty
                  ? null
                  : widget.existing != null && !_dirty
                  ? () => _close(true)
                  : _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                disabledBackgroundColor: const Color(0xffe4e2e1),
                disabledForegroundColor: MomHomeTokens.secondary,
                textStyle: ScheduleDesign.text(13, bold: true, lineHeight: 18),
              ),
              child: Text(
                _busy
                    ? 'Saving…'
                    : _failure != null
                    ? 'Try saving again'
                    : widget.existing == null
                    ? 'Add to schedule'
                    : 'Save changes',
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _failureMessage => switch (_failure?.kind) {
    ProductFailureKind.conflict => 'This item was updated elsewhere. Refresh and try again. Your entries are still here.',
    ProductFailureKind.unauthenticated => 'Your session has expired. Sign in again to continue.',
    ProductFailureKind.forbidden => 'This account cannot edit this item.',
    ProductFailureKind.invalid => 'Check your entries and try again. Your draft is still here.',
    _ => 'Could not save right now. Your entries are still here. Try again later.',
  };
  InputDecoration _input(String hint) => InputDecoration(
    hintText: hint,
    counterText: '',
    isDense: true,
    hintStyle: ScheduleDesign.text(13, lineHeight: 18),
    contentPadding: const EdgeInsets.all(14),
  );
  ButtonStyle _pickerStyle(BuildContext context) => OutlinedButton.styleFrom(
    minimumSize: const Size.fromHeight(46),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    foregroundColor: MomHomeTokens.ink,
    side: const BorderSide(color: MomHomeTokens.border),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    textStyle: ScheduleDesign.text(13, lineHeight: 18),
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
      Text(
        optional ? '$label · optional' : label,
        style: ScheduleDesign.text(
          12,
          bold: true,
          color: MomHomeTokens.secondary,
          lineHeight: 17,
        ),
      ),
      const SizedBox(height: 6),
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
  });
  final String title;
  final VoidCallback? onClose;
  final Widget content, footer;
  @override
  Widget build(BuildContext context) => Theme(
    data: momSettingsTheme(Theme.of(context)),
    child: MomSettingsFlowDialog(
      title: title,
      closeLabel: 'Close schedule item',
      closeIcon: Text(
        '×',
        style: ScheduleDesign.text(13, bold: true, color: MomHomeTokens.rose),
      ),
      onClose: onClose,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [content, const SizedBox(height: 14), footer],
      ),
    ),
  );
}

class PersonalScheduleDeleteDialog extends StatelessWidget {
  const PersonalScheduleDeleteDialog({super.key, required this.entry});
  final PersonalScheduleEntry entry;
  @override
  Widget build(BuildContext context) => _ScheduleDialogFrame(
    title: 'Delete this item?',
    onClose: () => Navigator.pop(context, false),
    content: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MomSettingsCard(
          borderInside: true,
          color: MomCozyColors.amberSoft,
          children: [
            Text(
              entry.title,
              style: MomHomeTokens.text(16, weight: FontWeight.w700),
            ),
            Text(
              '${entry.date} · ${entry.startTime}',
              style: MomHomeTokens.text(12, color: MomHomeTokens.secondary),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          'This item will be removed from your calendar and daily schedule. This cannot be undone.',
          style: MomHomeTokens.text(
            13,
            height: 1.4,
            color: MomHomeTokens.secondary,
          ),
        ),
      ],
    ),
    footer: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          style: FilledButton.styleFrom(
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Keep item'),
        ),
        const SizedBox(height: 14),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete item'),
        ),
      ],
    ),
  );
}
