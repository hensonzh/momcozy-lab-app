enum CareEventKind {
  appointmentConfirmed,
  appointmentCancelled,
  intakeSubmitted,
  caseConsentRevoked,
  consultationCompleted,
  consultationUserNoShow,
  consultationTechnicalFailure,
  planPublished,
  reportGenerated,
  reportReviewed,
  consultationStarted,
  serviceProgressChanged,
}

final class CareServiceEvent {
  const CareServiceEvent({
    required this.id,
    required this.kind,
    required this.episodeId,
    required this.occurredAt,
    this.appointmentId,
  });
  final String id, episodeId;
  final String? appointmentId;
  final CareEventKind kind;
  final DateTime occurredAt;
}
