import '../../domain/care/consultation_room.dart';
import '../appointments/appointment_codec.dart';
import '../shared/json_value.dart';

const consultationRoleWire = EnumWire<ConsultationRole>({
  ConsultationRole.mom: 'mom',
  ConsultationRole.ibclc: 'ibclc',
});
const consultationStatusWire = EnumWire<ConsultationStatus>({
  ConsultationStatus.waitingRoom: 'waiting_room',
  ConsultationStatus.inProgress: 'in_progress',
  ConsultationStatus.notePending: 'note_pending',
  ConsultationStatus.noShow: 'no_show',
  ConsultationStatus.failed: 'failed',
  ConsultationStatus.cancelled: 'cancelled',
  ConsultationStatus.closed: 'closed',
});
const videoRoomStatusWire = EnumWire<VideoRoomStatus>({
  VideoRoomStatus.creating: 'creating',
  VideoRoomStatus.ready: 'ready',
  VideoRoomStatus.closing: 'closing',
  VideoRoomStatus.closed: 'closed',
  VideoRoomStatus.failed: 'failed',
});
const videoProviderWire = EnumWire<VideoProvider>({
  VideoProvider.disabled: 'disabled',
  VideoProvider.sandbox: 'sandbox',
  VideoProvider.livekit: 'livekit',
});
const participantPresenceWire = EnumWire<ParticipantPresence>({
  ParticipantPresence.notJoined: 'not_joined',
  ParticipantPresence.joining: 'joining',
  ParticipantPresence.joined: 'joined',
  ParticipantPresence.reconnecting: 'reconnecting',
  ParticipantPresence.left: 'left',
});
const consultationEndReasonWire = EnumWire<ConsultationEndReason>({
  ConsultationEndReason.completed: 'completed',
  ConsultationEndReason.technicalFailure: 'technical_failure',
  ConsultationEndReason.userNoShow: 'user_no_show',
  ConsultationEndReason.safetyEscalation: 'safety_escalation',
});

CareConsultation readConsultation(Map<String, Object?> json) =>
    CareConsultation(
      id: jsonString(json['id']),
      appointmentId: jsonString(json['appointment_id']),
      episodeId: jsonString(json['episode_id']),
      version: jsonInt(json['version']),
      status: consultationStatusWire.read(json['status'])!,
      roomStatus: videoRoomStatusWire.read(json['room_status'])!,
      videoProvider: videoProviderWire.read(json['video_provider'])!,
      startedAt: _nullableInstant(json['started_at']),
      endedAt: _nullableInstant(json['ended_at']),
      endReason: consultationEndReasonWire.read(json['end_reason']),
    );
DateTime? _nullableInstant(Object? json) =>
    json == null ? null : jsonInstant(json);
ConsultationLocation readConsultationLocation(Map<String, Object?> json) {
  final decision = jsonString(json['decision']);
  if (decision != 'passed' && decision != 'blocked') {
    throw const FormatException('Invalid location decision.');
  }
  return ConsultationLocation(
    id: jsonString(json['id']),
    region: jsonString(json['region']),
    passed: decision == 'passed',
    expiresAt: jsonInstant(json['expires_at']),
    createdAt: jsonInstant(json['created_at']),
  );
}

ConsultationRoomContext readRoomContext(Map<String, Object?> json) =>
    ConsultationRoomContext(
      appointment: readAppointment(jsonObject(json['appointment'])),
      viewerRole: consultationRoleWire.read(json['viewer_role'])!,
      consultation: json['consultation'] == null
          ? null
          : readConsultation(jsonObject(json['consultation'])),
      participants: jsonList(
        json['participants'],
        (value) => ConsultationParticipant(
          role: consultationRoleWire.read(value['role'])!,
          presence: participantPresenceWire.read(value['presence'])!,
          connectionVersion: jsonInt(value['connection_version']),
          joinedAt: _nullableInstant(value['joined_at']),
          lastSeenAt: _nullableInstant(value['last_seen_at']),
        ),
      ),
      intakeReady: jsonBool(json['intake_ready']),
      caseConsent: jsonBool(json['case_consent']),
      videoConsent: jsonBool(json['video_consent']),
      location: json['location'] == null
          ? null
          : readConsultationLocation(jsonObject(json['location'])),
      opensAt: jsonInstant(json['opens_at']),
      closesAt: jsonInstant(json['closes_at']),
      serverTime: jsonInstant(json['server_time']),
      demoEarlyJoin: jsonBool(json['demo_early_join']),
      consentPolicyVersion: jsonString(json['consent_policy_version']),
      videoProvider: videoProviderWire.read(json['video_provider'])!,
    );
ConsultationJoin readRoomJoin(Map<String, Object?> json) {
  final credentials = json['credentials'] == null
      ? null
      : jsonObject(json['credentials']);
  return ConsultationJoin(
    context: readRoomContext(jsonObject(json['context'])),
    connectionId: jsonString(json['connection_id']),
    credentials: credentials == null
        ? null
        : ConsultationCredentials(
            serverUrl: credentials['server_url'] as String?,
            token: credentials['token'] as String?,
            expiresAt: jsonInstant(credentials['expires_at']),
          ),
  );
}
