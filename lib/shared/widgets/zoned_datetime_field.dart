import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/shared/widgets/date_time_picker.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_motion.dart';
import '../../domain/shared/local_date.dart';
import '../zoned_time.dart';
import '../design_system/momcozy_design_system.dart';
import '../design_system/mom_home_tokens.dart';
import '../design_system/mom_settings_theme.dart';

class ZonedDateTimeField extends StatelessWidget {
  const ZonedDateTimeField({
    super.key,
    required this.label,
    required this.value,
    required this.timezone,
    required this.now,
    required this.onChanged,
    this.enabled = true,
    this.clearable = false,
    this.warm = false,
    this.useMomStyle = false,
    this.valueStyle,
    this.showLabel = true,
    this.bottomSpacing = 20,
    this.fieldStyle,
    this.trailing,
  });
  final String label, timezone;
  final DateTime? value;
  final DateTime Function() now;
  final ValueChanged<DateTime?> onChanged;
  final bool enabled, clearable;
  final bool warm, useMomStyle;
  final TextStyle? valueStyle;
  final bool showLabel;
  final double bottomSpacing;
  final ButtonStyle? fieldStyle;
  final Widget? trailing;

  Future<void> _pick(BuildContext context) async {
    final current = inTimezone(now(), timezone);
    final initial = value != null && !value!.isAfter(now())
        ? inTimezone(value!, timezone)
        : current;
    final selectedDate = await showMomCozyDatePicker(
      context: context,
      initialDate: DateTime(initial.year, initial.month, initial.day),
      currentDate: DateTime(current.year, current.month, current.day),
      firstDate: DateTime(1900),
      lastDate: DateTime(current.year, current.month, current.day),
      helpText: label,
      theme: useMomStyle ? momSettingsTheme(Theme.of(context)) : null,
    );
    if (selectedDate == null || !context.mounted) return;
    final time = await showMomCozyTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial.hour, minute: initial.minute),
      helpText: label,
      // Match the 24-hour value shown by this field, including in 12-hour locales.
      builder: (pickerContext, child) {
        final content = MediaQuery(
          data: MediaQuery.of(
            pickerContext,
          ).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
        return useMomStyle
            ? Theme(data: momSettingsTheme(Theme.of(context)), child: content)
            : content;
      },
    );
    if (time == null || !context.mounted) return;
    final candidates = zonedWallClockCandidates(
      LocalDate.fromDateTime(selectedDate),
      time.hour,
      time.minute,
      timezone,
    );
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The clocks change on this day, so that time does not exist. Choose another time.',
          ),
        ),
      );
      return;
    }
    DateTime? selected = candidates.first;
    if (candidates.length > 1) {
      selected = await showDialog<DateTime>(
        context: context,
        animationStyle: MomCozyMotion.animationStyle(context),
        builder: (context) {
          final dialog = SimpleDialog(
            title: const Text('When did this happen?'),
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Text(
                  'The clocks turn back on this day, so this time occurs twice.',
                ),
              ),
              for (final instant in candidates)
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, instant),
                  child: Text(
                    '${zonedClock(instant, timezone)} ${inTimezone(instant, timezone).timeZoneName} (${instant.toIso8601String()})',
                  ),
                ),
            ],
          );
          return useMomStyle
              ? Theme(data: momSettingsTheme(Theme.of(context)), child: dialog)
              : dialog;
        },
      );
    }
    if (selected != null && context.mounted) onChanged(selected);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (warm || useMomStyle) ...[
        if (showLabel)
          Text(
            label,
            style: useMomStyle
                ? MomHomeTokens.text(14, weight: FontWeight.w700)
                : const TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    fontWeight: FontWeight.w600,
                    color: MomCozyColors.warmEditorInk,
                  ),
          ),
        if (showLabel) const SizedBox(height: 10),
        OutlinedButton(
          onPressed: enabled ? () => _pick(context) : null,
          style: (fieldStyle ?? const ButtonStyle()).merge(
            OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              backgroundColor: useMomStyle
                  ? MomHomeTokens.surface
                  : MomCozyColors.warmFormField,
              foregroundColor: useMomStyle
                  ? MomHomeTokens.ink
                  : MomCozyColors.warmEditorInk,
              side: BorderSide(
                color: useMomStyle
                    ? MomHomeTokens.border
                    : MomCozyColors.warmFormBorder,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(useMomStyle ? 16 : 12),
              ),
              textStyle:
                  valueStyle ??
                  Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontSize: 14),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value == null
                      ? 'Not set'
                      : '${dateInTimezone(value!, timezone)} ${zonedClock(value!, timezone)} ${inTimezone(value!, timezone).timeZoneName}',
                ),
              ),
              const SizedBox(width: 8),
              trailing ?? const Icon(Icons.schedule_outlined, size: 18),
            ],
          ),
        ),
        SizedBox(height: bottomSpacing),
      ] else
        ListTile(
          contentPadding: EdgeInsets.zero,
          enabled: enabled,
          title: Text(label),
          subtitle: Text(
            value == null
                ? 'Not set'
                : '${dateInTimezone(value!, timezone)} ${zonedClock(value!, timezone)} ${inTimezone(value!, timezone).timeZoneName}',
          ),
          trailing: const Icon(Icons.schedule_outlined),
          onTap: enabled ? () => _pick(context) : null,
        ),
      if (clearable && value != null)
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: enabled ? () => onChanged(null) : null,
            child: const Text('Clear time'),
          ),
        ),
    ],
  );
}
