import '../shared/local_date.dart';

String formatBabyAge(LocalDate? birth, LocalDate today) {
  if (birth == null) return '月龄待完善';
  final days = today.daysSince(birth);
  if (days < 0) return '尚未出生';
  if (days == 0) return '出生当天';
  var months = (today.year - birth.year) * 12 + today.month - birth.month;
  if (birth.addMonths(months).compareTo(today) > 0) months--;
  if (months >= 24) {
    final remaining = months % 12;
    return '${months ~/ 12} 岁${remaining == 0 ? '' : ' $remaining 个月'}';
  }
  if (months >= 3) return '$months 个月';
  if (days < 14) return '$days 天';
  final remaining = days % 7;
  return '${days ~/ 7} 周${remaining == 0 ? '' : ' $remaining 天'}';
}
