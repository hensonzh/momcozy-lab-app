import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../design_system/momcozy_motion.dart';

/// Shared picker presentation; callers retain their date bounds and value logic.
Future<DateTime?> showMomCozyDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String? helpText,
  DateTime? currentDate,
  ThemeData? theme,
}) {
  final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
  Widget dialog = DatePickerDialog(
    initialDate: initialDate,
    currentDate: currentDate,
    firstDate: firstDate,
    lastDate: lastDate,
    helpText: helpText,
    // Preserve full-sized text instead of squeezing seven calendar columns.
    initialEntryMode: largeText
        ? DatePickerEntryMode.inputOnly
        : DatePickerEntryMode.calendar,
  );
  final locale = DatePickerTheme.of(context).locale;
  if (locale != null) {
    dialog = Localizations.override(
      context: context,
      locale: locale,
      child: dialog,
    );
  }
  return showDialog<DateTime>(
    context: context,
    animationStyle: MomCozyMotion.animationStyle(context),
    builder: (_) => theme == null ? dialog : Theme(data: theme, child: dialog),
  );
}

Future<TimeOfDay?> showMomCozyTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
  String? helpText,
  TransitionBuilder? builder,
}) {
  final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
  final Widget dialog = largeText
      ? _LargeTimeInput(initialTime: initialTime, helpText: helpText)
      : TimePickerDialog(
          key: const ValueKey('momcozy-time-picker'),
          initialTime: initialTime,
          helpText: helpText,
        );
  return showDialog<TimeOfDay>(
    context: context,
    animationStyle: MomCozyMotion.animationStyle(context),
    builder: (context) => builder == null ? dialog : builder(context, dialog),
  );
}

/// The SDK input dialog has a fixed height that clips validation at large text
/// sizes. Use the same localized fields in a scrollable dialog instead.
class _LargeTimeInput extends StatefulWidget {
  const _LargeTimeInput({required this.initialTime, this.helpText});
  final TimeOfDay initialTime;
  final String? helpText;

  @override
  State<_LargeTimeInput> createState() => _LargeTimeInputState();
}

class _LargeTimeInputState extends State<_LargeTimeInput> {
  final _form = GlobalKey<FormState>();
  final _hour = TextEditingController();
  final _minute = TextEditingController();
  late DayPeriod _period;
  bool? _use24Hours;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final format = MaterialLocalizations.of(context).timeOfDayFormat(
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    final use24Hours =
        format != TimeOfDayFormat.h_colon_mm_space_a &&
        format != TimeOfDayFormat.a_space_h_colon_mm;
    if (_use24Hours == null) {
      _period = widget.initialTime.period;
      _hour.text =
          (use24Hours
                  ? widget.initialTime.hour
                  : widget.initialTime.hourOfPeriod == 0
                  ? 12
                  : widget.initialTime.hourOfPeriod)
              .toString()
              .padLeft(2, '0');
      _minute.text = widget.initialTime.minute.toString().padLeft(2, '0');
      _use24Hours = use24Hours;
    }
  }

  @override
  void dispose() {
    _hour.dispose();
    _minute.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = MaterialLocalizations.of(context);
    Widget field(
      TextEditingController controller,
      String label,
      int min,
      int max,
    ) => TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(2),
      ],
      validator: (value) {
        final number = int.tryParse(value ?? '');
        return number == null || number < min || number > max
            ? strings.invalidTimeLabel
            : null;
      },
    );
    return AlertDialog(
      key: const ValueKey('momcozy-time-picker'),
      scrollable: true,
      title: Text(widget.helpText ?? strings.timePickerInputHelpText),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            field(
              _hour,
              strings.timePickerHourLabel,
              _use24Hours! ? 0 : 1,
              _use24Hours! ? 23 : 12,
            ),
            const SizedBox(height: 16),
            field(_minute, strings.timePickerMinuteLabel, 0, 59),
            if (!_use24Hours!) ...[
              const SizedBox(height: 16),
              SegmentedButton<DayPeriod>(
                segments: [
                  ButtonSegment(
                    value: DayPeriod.am,
                    label: Text(strings.anteMeridiemAbbreviation),
                  ),
                  ButtonSegment(
                    value: DayPeriod.pm,
                    label: Text(strings.postMeridiemAbbreviation),
                  ),
                ],
                selected: {_period},
                onSelectionChanged: (value) =>
                    setState(() => _period = value.single),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(strings.cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () {
            if (!_form.currentState!.validate()) return;
            final hour = int.parse(_hour.text);
            Navigator.pop(
              context,
              TimeOfDay(
                hour: _use24Hours!
                    ? hour
                    : hour % 12 + (_period == DayPeriod.pm ? 12 : 0),
                minute: int.parse(_minute.text),
              ),
            );
          },
          child: Text(strings.okButtonLabel),
        ),
      ],
    );
  }
}
