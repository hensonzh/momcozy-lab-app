import '../../../../domain/care/service_event.dart';
import '../../../../domain/ibclc/workbench_reminder.dart';

class WorkbenchReminderPresentation {
  WorkbenchReminderPresentation(this.item);
  final WorkbenchReminder item;
  bool get isAppointment => {
    CareEventKind.appointmentConfirmed,
    CareEventKind.appointmentCancelled,
  }.contains(item.event.kind);
  String get title => switch (item.event.kind) {
    CareEventKind.appointmentConfirmed => 'New consultation booking',
    CareEventKind.appointmentCancelled => 'Consultation booking canceled',
    CareEventKind.intakeSubmitted => 'Intake submitted',
    CareEventKind.caseConsentRevoked => 'Client turned off case access',
    CareEventKind.consultationCompleted => 'Consultation ended',
    CareEventKind.consultationUserNoShow => 'Client no-show recorded',
    CareEventKind.consultationTechnicalFailure => 'Video technical issue recorded',
    CareEventKind.planPublished => 'Care plan published',
    CareEventKind.reportGenerated => 'AI report needs review',
    CareEventKind.reportReviewed => 'Report review saved',
    CareEventKind.consultationStarted => 'Consultation started',
    CareEventKind.serviceProgressChanged => 'Service progress updated',
  };
  String get body => switch (item.event.kind) {
    CareEventKind.appointmentConfirmed => 'Review the client\'s information before the consultation and join the room at the scheduled time.',
    CareEventKind.appointmentCancelled => 'The booking time has been released. View next steps in the client profile.',
    CareEventKind.intakeSubmitted => 'The client updated their concerns and goals for this consultation. Review them beforehand.',
    CareEventKind.caseConsentRevoked => 'Case access has changed. Check the client page to confirm current consent.',
    CareEventKind.consultationCompleted =>
      'Review the consultation notes, clinical note, and client summary.',
    CareEventKind.consultationUserNoShow => 'No consultation was used. Follow up on the next steps.',
    CareEventKind.consultationTechnicalFailure => 'The video session was not completed. No consultation was used.',
    CareEventKind.planPublished => 'The client can now view the summary and tasks.',
    CareEventKind.reportGenerated => 'Service information is ready. Review the sources and complete the clinical review.',
    CareEventKind.reportReviewed => 'Your clinical feedback was saved and can be viewed in the report for that date.',
    CareEventKind.consultationStarted => 'Enter the consultation room to view the current session.',
    CareEventKind.serviceProgressChanged => 'See the latest progress in the service details.',
  };
  String get route {
    if (item.event.kind == CareEventKind.reportGenerated ||
        item.event.kind == CareEventKind.reportReviewed) {
      return Uri(
        path: '/ibclc/followups/${item.patientRef}',
        queryParameters: {
          'episode': item.event.episodeId,
          if (item.reportDate != null) 'date': item.reportDate.toString(),
        },
      ).toString();
    }
    final appointment = item.event.appointmentId;
    if (appointment != null &&
        item.event.kind == CareEventKind.intakeSubmitted) {
      return '/ibclc/appointments/$appointment/intake';
    }
    if (appointment != null &&
        item.event.kind == CareEventKind.consultationCompleted) {
      return '/ibclc/appointments/$appointment/note';
    }
    return '/ibclc/clients/${item.patientRef}';
  }

  String get actionLabel =>
      item.event.kind == CareEventKind.reportGenerated ||
          item.event.kind == CareEventKind.reportReviewed
      ? 'View report'
      : item.event.kind == CareEventKind.intakeSubmitted
      ? 'View intake'
      : item.event.kind == CareEventKind.consultationCompleted
      ? 'View clinical note'
      : 'View client';
}
