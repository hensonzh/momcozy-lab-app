/// A calendar date. Never store a derived age or turn a date into a UTC instant.
final class LocalDate implements Comparable<LocalDate> {
  factory LocalDate(int year, int month, int day) {
    final normalized = DateTime.utc(year, month, day);
    if (year < 1 ||
        year > 9999 ||
        normalized.year != year ||
        normalized.month != month ||
        normalized.day != day) {
      throw FormatException('Invalid calendar date: $year-$month-$day');
    }
    return LocalDate._(year, month, day);
  }

  const LocalDate._(this.year, this.month, this.day);

  factory LocalDate.parse(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      throw FormatException('Expected YYYY-MM-DD', value);
    }
    return LocalDate(
      int.parse(value.substring(0, 4)),
      int.parse(value.substring(5, 7)),
      int.parse(value.substring(8, 10)),
    );
  }

  /// The caller selects the timezone before passing the wall-clock value.
  factory LocalDate.fromDateTime(DateTime value) =>
      LocalDate(value.year, value.month, value.day);

  final int year;
  final int month;
  final int day;

  DateTime get _calendar => DateTime.utc(year, month, day);
  int get weekday => _calendar.weekday;
  int get daysInMonth => DateTime.utc(year, month + 1, 0).day;
  LocalDate addDays(int days) =>
      LocalDate.fromDateTime(_calendar.add(Duration(days: days)));
  LocalDate addMonths(int months) {
    final first = DateTime.utc(year, month + months);
    final lastDay = DateTime.utc(first.year, first.month + 1, 0).day;
    return LocalDate(first.year, first.month, day > lastDay ? lastDay : day);
  }

  int daysSince(LocalDate other) =>
      _calendar.difference(other._calendar).inDays;
  DayWindow get localWindow =>
      DayWindow(DateTime(year, month, day), DateTime(year, month, day + 1));

  @override
  int compareTo(LocalDate other) => _calendar.compareTo(other._calendar);
  @override
  bool operator ==(Object other) =>
      other is LocalDate &&
      year == other.year &&
      month == other.month &&
      day == other.day;
  @override
  int get hashCode => Object.hash(year, month, day);
  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
}

/// Half-open interval; boundaries may come from the device or an IANA timezone.
final class DayWindow {
  DayWindow(this.start, this.end) {
    if (!end.isAfter(start)) throw ArgumentError('Day end must follow start.');
  }
  final DateTime start;
  final DateTime end;
  bool contains(DateTime instant) =>
      !instant.isBefore(start) && instant.isBefore(end);
}
