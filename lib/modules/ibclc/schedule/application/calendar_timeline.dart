import '../../../../domain/ibclc/workbench.dart';
import '../../../../domain/shared/local_date.dart';
import '../../../../shared/zoned_time.dart';

final class CalendarSegment {
  const CalendarSegment({
    required this.item,
    required this.day,
    required this.startMinute,
    required this.endMinute,
  });
  final WorkbenchAppointment item;
  final LocalDate day;
  final double startMinute, endMinute;
}

final class CalendarTimeline {
  CalendarTimeline({
    required List<WorkbenchAppointment> appointments,
    required this.weekStart,
    required this.timezone,
  }) {
    for (var index = 0; index < 7; index++) {
      final day = weekStart.addDays(index),
          window = zonedDayWindow(weekStart.addDays(index), timezone);
      if (window.end.difference(window.start) != const Duration(hours: 24)) {
        clockChangeWeek = true;
      }
      for (final item in appointments) {
        final start = item.appointment.startsAt, end = item.appointment.endsAt;
        if (!start.isBefore(window.end) || !end.isAfter(window.start)) continue;
        final from = start.isBefore(window.start) ? window.start : start;
        final to = end.isAfter(window.end) ? window.end : end;
        final localStart = inTimezone(from, timezone),
            localEnd = inTimezone(to, timezone);
        final startMinute = localStart.hour * 60.0 + localStart.minute;
        final endMinute = to == window.end
            ? 1440.0
            : localEnd.hour * 60.0 + localEnd.minute;
        segments.add(
          CalendarSegment(
            item: item,
            day: day,
            startMinute: startMinute,
            endMinute: endMinute,
          ),
        );
      }
    }
    if (segments.isNotEmpty) {
      final earliest = segments
          .map((value) => value.startMinute)
          .reduce((a, b) => a < b ? a : b);
      final latest = segments
          .map((value) => value.endMinute)
          .reduce((a, b) => a > b ? a : b);
      startHour = (earliest / 60).floor().clamp(0, 8);
      endHour = (latest / 60).ceil().clamp(20, 24);
    }
  }
  final LocalDate weekStart;
  final String timezone;
  final List<CalendarSegment> segments = [];
  bool clockChangeWeek = false;
  int startHour = 8, endHour = 20;
  List<CalendarSegment> onDay(LocalDate day) =>
      segments.where((value) => value.day == day).toList();
}
