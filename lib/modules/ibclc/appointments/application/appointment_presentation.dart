import '../../../../domain/care/appointment.dart';
import '../../../../domain/care/clinical_note.dart';
import '../../../../domain/care/consultation_room.dart';
import '../../../../domain/ibclc/workbench.dart';

enum WorkbenchAppointmentAction { prepare, room, note }

enum WorkbenchStatusTone { neutral, care, attention }

final class WorkbenchAppointmentPresentation {
  const WorkbenchAppointmentPresentation(
    this.status,
    this.tone,
    this.action,
    this.actionLabel,
  );
  final String status;
  final WorkbenchStatusTone tone;
  final WorkbenchAppointmentAction action;
  final String actionLabel;

  factory WorkbenchAppointmentPresentation.forAppointment(
    WorkbenchAppointment item,
    DateTime now,
  ) {
    final appointment = item.appointment;
    final consultation = item.consultation;
    if (appointment.status == AppointmentStatus.cancelled ||
        consultation?.status == ConsultationStatus.cancelled) {
      return const WorkbenchAppointmentPresentation(
        'Canceled',
        WorkbenchStatusTone.neutral,
        WorkbenchAppointmentAction.prepare,
        'View intake',
      );
    }
    if (consultation?.status == ConsultationStatus.noShow) {
      return const WorkbenchAppointmentPresentation(
        'Client did not attend',
        WorkbenchStatusTone.attention,
        WorkbenchAppointmentAction.room,
        'View outcome',
      );
    }
    if (consultation?.status == ConsultationStatus.failed) {
      return WorkbenchAppointmentPresentation(
        consultation?.endReason == ConsultationEndReason.safetyEscalation
            ? 'Escalated'
            : 'Technical issue',
        WorkbenchStatusTone.attention,
        WorkbenchAppointmentAction.room,
        'View outcome',
      );
    }
    if (appointment.status == AppointmentStatus.completed ||
        consultation?.ended == true) {
      if (item.publishedRevision > 0) {
        return const WorkbenchAppointmentPresentation(
          'Plan published',
          WorkbenchStatusTone.care,
          WorkbenchAppointmentAction.note,
          'View notes',
        );
      }
      if (item.noteStatus == ClinicalNoteStatus.signed) {
        return const WorkbenchAppointmentPresentation(
          'Plan not published yet',
          WorkbenchStatusTone.attention,
          WorkbenchAppointmentAction.note,
          'Prepare plan',
        );
      }
      return const WorkbenchAppointmentPresentation(
        'Notes to complete',
        WorkbenchStatusTone.attention,
        WorkbenchAppointmentAction.note,
        'Complete notes',
      );
    }
    if (appointment.status == AppointmentStatus.inProgress ||
        consultation?.status == ConsultationStatus.inProgress) {
      return const WorkbenchAppointmentPresentation(
        'In consultation',
        WorkbenchStatusTone.care,
        WorkbenchAppointmentAction.room,
        'Return to consultation',
      );
    }
    if (!now.isBefore(
      appointment.startsAt.subtract(const Duration(minutes: 10)),
    )) {
      return WorkbenchAppointmentPresentation(
        now.isAfter(appointment.endsAt.add(const Duration(minutes: 15)))
            ? 'Outcome to confirm'
            : 'Not started yet',
        WorkbenchStatusTone.attention,
        WorkbenchAppointmentAction.room,
        'Join consultation',
      );
    }
    return const WorkbenchAppointmentPresentation(
      'Booked',
      WorkbenchStatusTone.neutral,
      WorkbenchAppointmentAction.prepare,
      'View intake',
    );
  }
}
