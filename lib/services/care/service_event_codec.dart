import '../../domain/care/service_event.dart';
import '../shared/json_value.dart';

const careEventKindWire = EnumWire({
  CareEventKind.appointmentConfirmed: 'appointment_confirmed',
  CareEventKind.appointmentCancelled: 'appointment_cancelled',
  CareEventKind.intakeSubmitted: 'intake_submitted',
  CareEventKind.caseConsentRevoked: 'case_consent_revoked',
  CareEventKind.consultationCompleted: 'consultation_completed',
  CareEventKind.consultationUserNoShow: 'consultation_user_no_show',
  CareEventKind.consultationTechnicalFailure: 'consultation_technical_failure',
  CareEventKind.planPublished: 'plan_published',
  CareEventKind.reportGenerated: 'report_generated',
  CareEventKind.reportReviewed: 'report_reviewed',
  CareEventKind.consultationStarted: 'consultation_started',
  CareEventKind.serviceProgressChanged: 'service_progress_changed',
});

CareServiceEvent readServiceEvent(Map<String, Object?> json) =>
    CareServiceEvent(
      id: jsonString(json['id']),
      kind: careEventKindWire.read(json['kind'])!,
      episodeId: jsonString(json['episode_id']),
      appointmentId: json['appointment_id'] as String?,
      occurredAt: jsonInstant(json['occurred_at']),
    );
