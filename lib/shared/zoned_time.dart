import 'package:timezone/data/latest.dart' as data;
import 'package:timezone/timezone.dart' as tz;
import '../domain/shared/local_date.dart';

bool _initialized = false;
tz.Location _location(String timezone) {
  if (timezone == 'UTC') return tz.UTC;
  if (!_initialized) {
    data.initializeTimeZones();
    _initialized = true;
  }
  return tz.getLocation(timezone);
}

tz.TZDateTime inTimezone(DateTime instant, String timezone) =>
    tz.TZDateTime.from(instant, _location(timezone));

DayWindow zonedDayWindow(LocalDate date, String timezone) {
  final zone = _location(timezone);
  return DayWindow(
    tz.TZDateTime(zone, date.year, date.month, date.day),
    tz.TZDateTime(zone, date.year, date.month, date.day + 1),
  );
}

LocalDate dateInTimezone(DateTime instant, String timezone) =>
    LocalDate.fromDateTime(inTimezone(instant, timezone));

/// Zero candidates for a skipped clock time, two when the clock repeats at DST.
List<DateTime> zonedWallClockCandidates(
  LocalDate date,
  int hour,
  int minute,
  String timezone,
) {
  final wall = DateTime.utc(date.year, date.month, date.day, hour, minute);
  final offsets = <Duration>{
    for (var hours = -36; hours <= 36; hours += 6)
      inTimezone(wall.add(Duration(hours: hours)), timezone).timeZoneOffset,
  };
  final values = <DateTime>[];
  for (final offset in offsets) {
    final instant = wall.subtract(offset);
    final local = inTimezone(instant, timezone);
    if (LocalDate.fromDateTime(local) == date &&
        local.hour == hour &&
        local.minute == minute) {
      values.add(instant);
    }
  }
  return values..sort();
}

String zonedClock(DateTime instant, String timezone) {
  final value = inTimezone(instant, timezone);
  return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

String zonedRange(DateTime start, DateTime end, String timezone) {
  final first = inTimezone(start, timezone), last = inTimezone(end, timezone);
  final sameZone = first.timeZoneName == last.timeZoneName;
  return '${zonedClock(start, timezone)}${sameZone ? '' : ' ${first.timeZoneName}'} – ${zonedClock(end, timezone)} ${last.timeZoneName}';
}

String appointmentDay(DateTime instant, String timezone) {
  final value = inTimezone(instant, timezone);
  const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  return '${value.month}月${value.day}日 ${weekdays[value.weekday - 1]}';
}
