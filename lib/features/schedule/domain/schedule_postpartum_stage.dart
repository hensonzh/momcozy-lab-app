String schedulePostpartumStageLabel({
  required DateTime deliveryDate,
  required DateTime selectedDay,
}) {
  final rawDayOffset = _localDay(
    selectedDay,
  ).difference(_localDay(deliveryDate)).inDays;
  final dayOffset = rawDayOffset < 0 ? 0 : rawDayOffset;
  final week = dayOffset ~/ 7 + 1;
  final phase = switch (dayOffset) {
    <= 3 => '初乳期',
    <= 28 => '建立期',
    <= 180 => '稳产期',
    _ => '离乳期',
  };
  return '产后第$week周（$phase）';
}

DateTime _localDay(DateTime value) {
  final local = value.isUtc ? value.toLocal() : value;
  return DateTime(local.year, local.month, local.day);
}
