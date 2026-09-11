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
        if (task.content.scheduledDate != null) {
          yield task.content.scheduledDate!;
        }
      }
    }
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
