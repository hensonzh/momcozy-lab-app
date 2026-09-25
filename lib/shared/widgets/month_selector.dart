import 'package:flutter/material.dart';
import '../../domain/shared/local_date.dart';
import '../design_system/momcozy_design_system.dart';

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

class MonthSelector extends StatelessWidget {
  const MonthSelector({
    super.key,
    required this.selected,
    required this.onSelect,
    this.today,
    this.weekStart,
  });
  final LocalDate selected;
  final LocalDate? today, weekStart;
  final ValueChanged<LocalDate> onSelect;

  void _shift(int offset) {
    final month = DateTime(selected.year, selected.month + offset);
    final last = DateTime(month.year, month.month + 1, 0).day;
    onSelect(LocalDate(month.year, month.month, selected.day.clamp(1, last)));
  }

  @override
  Widget build(BuildContext context) {
    final month = LocalDate(selected.year, selected.month, 1);
    final first = month.addDays(1 - month.weekday);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${_monthNames[selected.month - 1]} ${selected.year}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Previous month',
              onPressed: () => _shift(-1),
              icon: const Icon(Icons.chevron_left_rounded, size: 20),
            ),
            IconButton(
              tooltip: 'Next month',
              onPressed: () => _shift(1),
              icon: const Icon(Icons.chevron_right_rounded, size: 20),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final label in [
              'Mon',
              'Tue',
              'Wed',
              'Thu',
              'Fri',
              'Sat',
              'Sun',
            ])
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: MomCozyColors.mutedForeground,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 42,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
          ),
          itemBuilder: (context, index) => _day(first.addDays(index)),
        ),
      ],
    );
  }

  Widget _day(LocalDate day) {
    final inWeek =
        weekStart != null &&
        day.compareTo(weekStart!) >= 0 &&
        day.compareTo(weekStart!.addDays(7)) < 0;
    final active = day == selected;
    final background = active
        ? MomCozyColors.primary
        : inWeek
        ? MomCozyColors.roseSoft
        : Colors.transparent;
    final color = active
        ? Colors.white
        : day.month == selected.month
        ? MomCozyColors.foreground
        : MomCozyColors.mutedForeground.withValues(alpha: .55);
    return Semantics(
      label: '${_monthNames[day.month - 1]} ${day.day}, ${day.year}',
      selected: active,
      button: true,
      onTap: () => onSelect(day),
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.all(1),
          child: Tooltip(
            message: day.toString(),
            child: TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                backgroundColor: background,
                foregroundColor: color,
                side: day == today
                    ? const BorderSide(color: MomCozyColors.primary)
                    : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => onSelect(day),
              child: Text('${day.day}', style: const TextStyle(fontSize: 12)),
            ),
          ),
        ),
      ),
    );
  }
}
