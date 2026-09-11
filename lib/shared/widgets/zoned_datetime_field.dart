import 'package:flutter/material.dart';
import '../../domain/shared/local_date.dart';
import '../zoned_time.dart';

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
  });
  final String label, timezone;
  final DateTime? value;
  final DateTime Function() now;
  final ValueChanged<DateTime?> onChanged;
  final bool enabled, clearable;

  Future<void> _pick(BuildContext context) async {
    final current = inTimezone(now(), timezone);
    final initial = value != null && !value!.isAfter(now())
        ? inTimezone(value!, timezone)
        : current;
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime(initial.year, initial.month, initial.day),
      firstDate: DateTime(1900),
      lastDate: DateTime(current.year, current.month, current.day),
      helpText: label,
    );
    if (selectedDate == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial.hour, minute: initial.minute),
      helpText: label,
    );
    if (time == null || !context.mounted) return;
    final candidates = zonedWallClockCandidates(
      LocalDate.fromDateTime(selectedDate),
      time.hour,
      time.minute,
      timezone,
    );
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('这一天有时钟调整，所选时间不存在。请重新选择。')));
      return;
    }
    DateTime? selected = candidates.first;
    if (candidates.length > 1) {
      selected = await showDialog<DateTime>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('请选择这次发生的时间'),
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text('这一天时钟回拨，同一时间出现了两次。'),
            ),
            for (final instant in candidates)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, instant),
                child: Text(
                  '${zonedClock(instant, timezone)} ${inTimezone(instant, timezone).timeZoneName} (${instant.toIso8601String()})',
                ),
              ),
          ],
        ),
      );
    }
    if (selected != null && context.mounted) onChanged(selected);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ListTile(
        contentPadding: EdgeInsets.zero,
        enabled: enabled,
        title: Text(label),
        subtitle: Text(
          value == null
              ? '尚未填写'
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
            child: const Text('清除时间'),
          ),
        ),
    ],
  );
}
