import '../shared/local_date.dart';

String formatBabyAge(LocalDate? birth, LocalDate today) {
  if (birth == null) return 'Age not set';
  final days = today.daysSince(birth);
  if (days < 0) return 'Not born yet';
  if (days == 0) return 'Newborn';
  var months = (today.year - birth.year) * 12 + today.month - birth.month;
  if (birth.addMonths(months).compareTo(today) > 0) months--;
  if (months >= 24) {
    final remaining = months % 12;
    return '${months ~/ 12} yr${remaining == 0 ? '' : ' $remaining mo'}';
  }
  if (months >= 3) return '$months mo';
  if (days < 14) return '$days day${days == 1 ? '' : 's'}';
  final remaining = days % 7;
  return '${days ~/ 7} wk${remaining == 0 ? '' : ' $remaining day${remaining == 1 ? '' : 's'}'}';
}
