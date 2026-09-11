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
        '已取消',
        WorkbenchStatusTone.neutral,
        WorkbenchAppointmentAction.prepare,
        '查看资料',
      );
    }
    if (consultation?.status == ConsultationStatus.noShow) {
      return const WorkbenchAppointmentPresentation(
        '用户未到场',
        WorkbenchStatusTone.attention,
        WorkbenchAppointmentAction.room,
        '查看结果',
      );
    }
    if (consultation?.status == ConsultationStatus.failed) {
      return WorkbenchAppointmentPresentation(
        consultation?.endReason == ConsultationEndReason.safetyEscalation
            ? '已升级处理'
            : '技术故障',
        WorkbenchStatusTone.attention,
        WorkbenchAppointmentAction.room,
        '查看结果',
      );
    }
    if (appointment.status == AppointmentStatus.completed ||
        consultation?.ended == true) {
      if (item.publishedRevision > 0) {
        return const WorkbenchAppointmentPresentation(
          '方案已发布',
          WorkbenchStatusTone.care,
          WorkbenchAppointmentAction.note,
          '查看记录',
        );
      }
      if (item.noteStatus == ClinicalNoteStatus.signed) {
        return const WorkbenchAppointmentPresentation(
          '待发布方案',
          WorkbenchStatusTone.attention,
          WorkbenchAppointmentAction.note,
          '整理方案',
        );
      }
      return const WorkbenchAppointmentPresentation(
        '待完成记录',
        WorkbenchStatusTone.attention,
        WorkbenchAppointmentAction.note,
        '整理记录',
      );
    }
    if (appointment.status == AppointmentStatus.inProgress ||
        consultation?.status == ConsultationStatus.inProgress) {
      return const WorkbenchAppointmentPresentation(
        '咨询中',
        WorkbenchStatusTone.care,
        WorkbenchAppointmentAction.room,
        '返回咨询',
      );
    }
    if (!now.isBefore(
      appointment.startsAt.subtract(const Duration(minutes: 10)),
    )) {
      return WorkbenchAppointmentPresentation(
        now.isAfter(appointment.endsAt.add(const Duration(minutes: 15)))
            ? '待确认结果'
            : '待开始',
        WorkbenchStatusTone.attention,
        WorkbenchAppointmentAction.room,
        '进入咨询室',
      );
    }
    return const WorkbenchAppointmentPresentation(
      '已预约',
      WorkbenchStatusTone.neutral,
      WorkbenchAppointmentAction.prepare,
      '查看资料',
    );
  }
}
