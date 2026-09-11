enum CareEpisodeStatus {
  provisioningPending,
  active,
  paused,
  completed,
  cancelled,
}

enum CareStage {
  preparation,
  initialConsultation,
  activeCare,
  followUp,
  conclusion,
}

final class CareEpisode {
  const CareEpisode({
    required this.id,
    required this.orderId,
    required this.packageId,
    required this.status,
    required this.stage,
    required this.totalSessions,
    required this.remainingSessions,
    required this.version,
    this.babyId,
    this.assignedIbclcId,
    this.startsAt,
    this.endsAt,
  });
  final String id, orderId, packageId;
  final String? babyId, assignedIbclcId;
  final CareEpisodeStatus status;
  final CareStage stage;
  final int totalSessions, remainingSessions, version;
  final DateTime? startsAt, endsAt;
  bool get canBook =>
      status == CareEpisodeStatus.active && remainingSessions > 0;
  bool get ongoing => [
    CareEpisodeStatus.active,
    CareEpisodeStatus.paused,
    CareEpisodeStatus.provisioningPending,
  ].contains(status);
}
