import 'package:flutter/material.dart';
import '../../../domain/shared/local_date.dart';
import '../../../shared/design_system/mom_home_tokens.dart';
import '../application/schedule_controller.dart';
import 'schedule_design.dart';

class ScheduleCalendar extends StatelessWidget {
  const ScheduleCalendar({
    super.key,
    required this.state,
    required this.expanded,
    required this.onSelect,
    required this.onShift,
    required this.onToday,
  });
  final ScheduleState state;
  final bool expanded;
  final ValueChanged<LocalDate> onSelect;
  final ValueChanged<int> onShift;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final first = expanded ? state.month : state.selected;
    final start = first.addDays(1 - first.weekday);
    final rows = expanded
        ? (first.weekday - 1 + first.daysInMonth + 6) ~/ 7
        : 1;
    final end = start.addDays(6);
    final label = expanded
        ? '${state.month.month}/${state.month.year}'
        : '${start.month}/${start.day}–${start.month == end.month ? '' : '${end.month}/'}${end.day}';
    final events = state.page!.datesWithEvents().toSet();
    return Container(
      key: ValueKey(
        expanded ? 'schedule-month-calendar' : 'schedule-week-calendar',
      ),
      decoration: BoxDecoration(
        gradient: ScheduleDesign.calendar,
        borderRadius: BorderRadius.circular(26),
        boxShadow: ScheduleDesign.calendarShadow,
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: .8)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              _arrow(
                '‹',
                expanded ? 'Previous month' : 'Previous week',
                () => onShift(-1),
                fontSize: expanded ? 13 : 24,
              ),
              Expanded(
                child: InkWell(
                  onTap: onToday,
                  borderRadius: BorderRadius.circular(12),
                  child: Semantics(
                    button: true,
                    label: 'Go to today',
                    child: Column(
                      children: [
                        Text(
                          label,
                          textAlign: TextAlign.center,
                          style: ScheduleDesign.text(
                            20,
                            bold: true,
                            lineHeight: 28,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'A dot means there is something scheduled that day',
                          textAlign: TextAlign.center,
                          style: ScheduleDesign.text(
                            11,
                            color: MomHomeTokens.secondary,
                            lineHeight: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _arrow(
                '›',
                expanded ? 'Next month' : 'Next week',
                () => onShift(1),
                fontSize: expanded ? 13 : 24,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final day in const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'])
                Expanded(
                  child: Text(
                    day,
                    textAlign: TextAlign.center,
                    style: ScheduleDesign.text(
                      11,
                      bold: true,
                      color: MomHomeTokens.secondary,
                      lineHeight: 15,
                    ),
                  ),
                ),
            ],
          ),
          for (var row = 0; row < rows; row++) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                for (var col = 0; col < 7; col++)
                  _day(context, start.addDays(row * 7 + col), events),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _arrow(
    String glyph,
    String tooltip,
    VoidCallback action, {
    required double fontSize,
  }) => SizedBox.square(
    dimension: 44,
    child: Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: .65),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: action,
          child: Center(
            child: Text(
              glyph,
              style: ScheduleDesign.text(
                fontSize,
                bold: true,
                color: MomHomeTokens.rose,
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _day(BuildContext context, LocalDate date, Set<LocalDate> events) {
    final selected = date == state.selected;
    final marked = events.contains(date);
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        excludeSemantics: true,
        label: '${date.month}/${date.day}/${date.year}${marked ? ' · Has events' : ''}',
        onTap: () => onSelect(date),
        child: InkWell(
          key: ValueKey('schedule-day-$date'),
          onTap: () => onSelect(date),
          borderRadius: BorderRadius.circular(13),
          child: Container(
            constraints: const BoxConstraints(minHeight: 45),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: selected ? MomHomeTokens.rose : null,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${date.day}',
                  style: ScheduleDesign.text(
                    13,
                    bold: selected,
                    color: selected
                        ? MomHomeTokens.surface
                        : date.month == state.month.month
                        ? MomHomeTokens.ink
                        : MomHomeTokens.secondary,
                    lineHeight: 18,
                  ),
                ),
                if (marked) ...[
                  const SizedBox(height: 3),
                  Container(
                    key: ValueKey('schedule-dot-$date'),
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: selected
                          ? MomHomeTokens.surface
                          : MomHomeTokens.rose,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
