import 'appointment.dart';

enum ConsultationRole { mom, ibclc }

enum ConsultationStatus {
  waitingRoom,
  inProgress,
  notePending,
  noShow,
  failed,
  cancelled,
  closed,
}

enum VideoRoomStatus { creating, ready, closing, closed, failed }

enum VideoProvider { disabled, sandbox, livekit }

enum ParticipantPresence { notJoined, joining, joined, reconnecting, left }

enum ConsultationEndReason {
  completed,
  technicalFailure,
  userNoShow,
  safetyEscalation,
}

final class CareConsultation {
  const CareConsultation({
    required this.id,
    required this.appointmentId,
    required this.episodeId,
    required this.version,
    required this.status,
    required this.roomStatus,
    required this.videoProvider,
    this.startedAt,
    this.endedAt,
    this.endReason,
  });
  final String id, appointmentId, episodeId;
  final int version;
  final ConsultationStatus status;
  final VideoRoomStatus roomStatus;
  final VideoProvider videoProvider;
  final DateTime? startedAt, endedAt;
  final ConsultationEndReason? endReason;
  bool get ended =>
      status != ConsultationStatus.waitingRoom &&
      status != ConsultationStatus.inProgress;
}

final class ConsultationParticipant {
  const ConsultationParticipant({
    required this.role,
    required this.presence,
    required this.connectionVersion,
    this.joinedAt,
    this.lastSeenAt,
  });
  final ConsultationRole role;
  final ParticipantPresence presence;
  final int connectionVersion;
  final DateTime? joinedAt, lastSeenAt;
}

final class ConsultationLocation {
  const ConsultationLocation({
    required this.id,
    required this.region,
    required this.passed,
    required this.expiresAt,
    required this.createdAt,
  });
  final String id, region;
  final bool passed;
  final DateTime expiresAt, createdAt;
  bool validAt(DateTime now) => passed && expiresAt.isAfter(now);
}

final class ConsultationRoomContext {
  const ConsultationRoomContext({
    required this.appointment,
    required this.viewerRole,
    required this.participants,
    required this.intakeReady,
    required this.caseConsent,
    required this.videoConsent,
    required this.opensAt,
    required this.closesAt,
    required this.serverTime,
    required this.demoEarlyJoin,
    required this.videoProvider,
    required this.consentPolicyVersion,
    this.consultation,
    this.location,
  });
  final CareAppointment appointment;
  final ConsultationRole viewerRole;
  final CareConsultation? consultation;
  final List<ConsultationParticipant> participants;
  final bool intakeReady, caseConsent, videoConsent, demoEarlyJoin;
  final String consentPolicyVersion;
  final DateTime opensAt, closesAt, serverTime;
  final VideoProvider videoProvider;
  final ConsultationLocation? location;
  bool get active => consultation?.status == ConsultationStatus.inProgress;
  bool get ended =>
      (consultation?.ended ?? false) ||
      appointment.status == AppointmentStatus.completed ||
      appointment.status == AppointmentStatus.cancelled;
  bool windowOpen(DateTime now) =>
      !ended &&
      (active ||
          ((!opensAt.isAfter(now) || demoEarlyJoin) && closesAt.isAfter(now)));
  ConsultationParticipant? participant(ConsultationRole role) =>
      participants.where((value) => value.role == role).firstOrNull;
}

final class ConsultationCredentials {
  const ConsultationCredentials({
    required this.serverUrl,
    required this.token,
    required this.expiresAt,
  });
  final String? serverUrl, token;
  final DateTime expiresAt;
}

final class ConsultationJoin {
  const ConsultationJoin({
    required this.context,
    required this.connectionId,
    required this.credentials,
  });
  final ConsultationRoomContext context;
  final String connectionId;
  final ConsultationCredentials? credentials;
}

abstract interface class ConsultationRoomRepository {
  Future<ConsultationRoomContext> load(String appointmentId);
  Future<ConsultationLocation> checkLocation(
    String appointmentId,
    String region,
  );
  Future<ConsultationRoomContext> prepare(String appointmentId);
  Future<ConsultationJoin> join(
    String appointmentId, {
    required String idempotencyKey,
  });
  Future<ConsultationRoomContext> presence(
    String appointmentId, {
    required String connectionId,
    required ParticipantPresence presence,
  });
  Future<ConsultationRoomContext> start(
    String appointmentId, {
    required int expectedVersion,
  });
  Future<ConsultationRoomContext> end(
    String appointmentId, {
    required int expectedVersion,
    required ConsultationEndReason reason,
  });
}
