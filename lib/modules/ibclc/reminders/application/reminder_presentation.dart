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
    CareEventKind.appointmentConfirmed => '新增咨询预约',
    CareEventKind.appointmentCancelled => '咨询预约已取消',
    CareEventKind.intakeSubmitted => '咨询前资料已提交',
    CareEventKind.caseConsentRevoked => '用户关闭了病例授权',
    CareEventKind.consultationCompleted => '咨询已结束',
    CareEventKind.consultationUserNoShow => '已记录用户未到场',
    CareEventKind.consultationTechnicalFailure => '已记录视频技术故障',
    CareEventKind.planPublished => '护理方案已发布',
    CareEventKind.reportGenerated => 'AI 报告待复核',
    CareEventKind.reportReviewed => '报告复核已保存',
    CareEventKind.consultationStarted => '咨询已开始',
    CareEventKind.serviceProgressChanged => '服务进度已更新',
  };
  String get body => switch (item.event.kind) {
    CareEventKind.appointmentConfirmed => '请在咨询前核对用户资料，并按预约时间进入咨询室。',
    CareEventKind.appointmentCancelled => '这段预约时间已释放，可在客户资料中查看后续安排。',
    CareEventKind.intakeSubmitted => '用户更新了本次咨询的自述和目标，请在咨询前查看。',
    CareEventKind.caseConsentRevoked => '病例资料的可用范围已更新，请查看客户页确认当前授权。',
    CareEventKind.consultationCompleted =>
      '请查看本次记录，核对 Clinical Note 和给用户的咨询总结。',
    CareEventKind.consultationUserNoShow => '本次咨询未扣减次数，可继续跟进后续安排。',
    CareEventKind.consultationTechnicalFailure => '本次视频未完成，未扣减用户的咨询次数。',
    CareEventKind.planPublished => '用户可以查看本次总结与任务。',
    CareEventKind.reportGenerated => '服务资料已完成整理，请查看来源并进行专业复核。',
    CareEventKind.reportReviewed => '专业意见已保存，可在对应日期的报告中查看。',
    CareEventKind.consultationStarted => '请进入咨询室查看当前咨询。',
    CareEventKind.serviceProgressChanged => '请在服务详情中查看最新进度。',
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
      ? '查看报告'
      : item.event.kind == CareEventKind.intakeSubmitted
      ? '查看咨询资料'
      : item.event.kind == CareEventKind.consultationCompleted
      ? '查看专业记录'
      : '查看客户';
}
