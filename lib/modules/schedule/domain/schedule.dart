import '../../../domain/shared/local_date.dart';

final class PersonalScheduleEntry {
  const PersonalScheduleEntry({
    required this.id,
    required this.title,
    required this.date,
    required this.startTime,
    required this.note,
    required this.updatedAt,
  });
  final String id, title, startTime, note;
  final LocalDate date;
  final DateTime updatedAt;
}

final class SchedulePageData {
  SchedulePageData({
    required List<PersonalScheduleEntry> personal,
    required this.serverTime,
    required this.hasMore,
  }) : personal = List.unmodifiable(personal);

  final List<PersonalScheduleEntry> personal;
  final DateTime serverTime;
  final bool hasMore;

  Iterable<LocalDate> datesWithEvents() => personal.map((item) => item.date);

  SchedulePageData copyWith({List<PersonalScheduleEntry>? personal}) =>
      SchedulePageData(
        personal: personal ?? this.personal,
        serverTime: serverTime,
        hasMore: hasMore,
      );

  List<ScheduleAgendaEntry> agendaOn(LocalDate date) {
    final entries = [
      for (final item in personal.where((item) => item.date == date))
        ScheduleAgendaEntry(personal: item),
    ];
    entries.sort((a, b) => a.startMinute.compareTo(b.startMinute));
    return entries;
  }
}

/// A view of a personal calendar item.
final class ScheduleAgendaEntry {
  const ScheduleAgendaEntry({required this.personal});
  final PersonalScheduleEntry personal;
  String get key => 'personal-${personal.id}';
  String get title => personal.title;
  String get timeLabel => personal.startTime;
  int get startMinute {
    final parts = personal.startTime.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }
}
