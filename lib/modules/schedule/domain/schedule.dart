import '../../../domain/care/appointment.dart';
import '../../../domain/care/care_episode.dart';
import '../../../domain/care/care_plan.dart';
import '../../../domain/care/service_package.dart';
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

final class ScheduledPlan {
  const ScheduledPlan({
    required this.episodeId,
    required this.appointmentId,
    required this.publication,
  });
  final String episodeId, appointmentId;
  final PublishedCarePlan publication;
}

final class SchedulePageData {
  SchedulePageData({
    required List<PersonalScheduleEntry> personal,
    required List<CareAppointment> appointments,
    required List<ScheduledPlan> plans,
    required List<CareEpisode> episodes,
    required this.serverTime,
    required this.hasMore,
  }) : personal = List.unmodifiable(personal),
       appointments = List.unmodifiable(appointments),
       plans = List.unmodifiable(plans),
       episodes = List.unmodifiable(episodes);
  final List<PersonalScheduleEntry> personal;
  final List<CareAppointment> appointments;
  final List<ScheduledPlan> plans;
  final List<CareEpisode> episodes;
  final DateTime serverTime;
  final bool hasMore;

  Iterable<LocalDate> datesWithEvents() sync* {
    for (final value in personal) {
      yield value.date;
    }
    for (final value in appointments) {
      yield LocalDate.fromDateTime(value.startsAt.toLocal());
    }
    for (final plan in plans) {
      for (final task in plan.publication.tasks) {
        yield task.content.scheduledDate ??
            LocalDate.fromDateTime(plan.publication.publishedAt.toLocal());
      }
    }
  }

  SchedulePageData copyWith({
    List<PersonalScheduleEntry>? personal,
    List<ScheduledPlan>? plans,
  }) => SchedulePageData(
    personal: personal ?? this.personal,
    appointments: appointments,
    plans: plans ?? this.plans,
    episodes: episodes,
    serverTime: serverTime,
    hasMore: hasMore,
  );

  /// All-day entries first, then start time; source order breaks equal-time ties.
  List<ScheduleAgendaEntry> agendaOn(LocalDate date) {
    final result = <ScheduleAgendaEntry>[];
    for (final plan in plans) {
      for (final task in plan.publication.tasks) {
        if ((task.content.scheduledDate ??
                LocalDate.fromDateTime(
                  plan.publication.publishedAt.toLocal(),
                )) ==
            date) {
          result.add(
            ScheduleAgendaEntry(
              task: ScheduleTaskEntry(plan: plan, task: task),
            ),
          );
        }
      }
    }
    for (final item in personal.where((e) => e.date == date)) {
      result.add(ScheduleAgendaEntry(personal: item));
    }
    for (final item in appointments.where(
      (e) => LocalDate.fromDateTime(e.startsAt.toLocal()) == date,
    )) {
      result.add(ScheduleAgendaEntry(appointment: item));
    }
    final positions = {for (var i = 0; i < result.length; i++) result[i]: i};
    result.sort((a, b) {
      final byTime = a.startMinute.compareTo(b.startMinute);
      return byTime != 0 ? byTime : positions[a]!.compareTo(positions[b]!);
    });
    return result;
  }
}

final class ScheduleTaskEntry {
  const ScheduleTaskEntry({required this.plan, required this.task});
  final ScheduledPlan plan;
  final PublishedCareTask task;
}

ServicePackage? packageForEpisode(
  CareEpisode episode,
  ServiceCatalog? catalog,
) {
  for (final item in catalog?.packages ?? const <ServicePackage>[]) {
    if (item.id == episode.packageId) return item;
  }
  return null;
}

/// A view of a real schedule object; does not duplicate its business ownership.
final class ScheduleAgendaEntry {
  const ScheduleAgendaEntry({this.personal, this.appointment, this.task});
  final PersonalScheduleEntry? personal;
  final CareAppointment? appointment;
  final ScheduleTaskEntry? task;
  String get key => personal != null
      ? 'personal-${personal!.id}'
      : appointment != null
      ? 'appointment-${appointment!.id}'
      : 'task-${task!.plan.publication.id}-${task!.task.content.sourceKey}';
  String get title =>
      personal?.title ??
      (appointment != null ? '哺乳咨询' : task!.task.content.title);
  String get timeLabel => task != null
      ? '全天'
      : personal?.startTime ??
            '${_time(appointment!.startsAt)}–${_time(appointment!.endsAt)}';
  int get startMinute {
    if (task != null || personal?.startTime == '全天') return -1;
    if (appointment case final a?) {
      return a.startsAt.toLocal().hour * 60 + a.startsAt.toLocal().minute;
    }
    final parts = personal!.startTime.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  static String _time(DateTime t) =>
      '${t.toLocal().hour.toString().padLeft(2, '0')}:${t.toLocal().minute.toString().padLeft(2, '0')}';
}
