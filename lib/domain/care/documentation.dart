import 'appointment.dart';
import 'care_plan.dart';
import 'care_episode.dart';
import 'clinical_note.dart';
import 'consultation_room.dart';

final class CareDocumentation {
  CareDocumentation({
    required this.appointment,
    this.consultation,
    this.note,
    List<ClinicalNoteRevision> noteHistory = const [],
    this.plan,
    this.publication,
  }) : noteHistory = List.unmodifiable(noteHistory);
  final CareAppointment appointment;
  final CareConsultation? consultation;
  final ClinicalNote? note;
  final List<ClinicalNoteRevision> noteHistory;
  final CarePlanDraft? plan;
  final PublishedCarePlan? publication;
  bool get editable =>
      consultation?.status == ConsultationStatus.notePending ||
      consultation?.status == ConsultationStatus.closed;
}

final class PatientCareSummary {
  const PatientCareSummary({
    required this.episode,
    required this.appointment,
    this.consultation,
    this.publication,
  });
  final CareEpisode episode;
  final CareAppointment appointment;
  final CareConsultation? consultation;
  final PublishedCarePlan? publication;
}

abstract interface class CareDocumentationRepository {
  Future<CareDocumentation> load(String appointmentId);
  Future<ClinicalNote> noteRevision(String appointmentId, String noteId);
  Future<ClinicalNote> saveNote(
    String appointmentId, {
    required ClinicalNoteContent content,
    required int expectedRevision,
    required int expectedVersion,
    required String idempotencyKey,
  });
  Future<ClinicalNote> signNote(
    String appointmentId, {
    required int expectedRevision,
    required int expectedVersion,
    required String idempotencyKey,
  });
  Future<ClinicalNote> amendNote(
    String appointmentId, {
    required String reason,
    required int expectedRevision,
    required int expectedVersion,
    required String idempotencyKey,
  });
  Future<CarePlanDraft> savePlan(
    String appointmentId, {
    required CarePlanContent content,
    required int expectedVersion,
    required String idempotencyKey,
  });
  Future<PublishedCarePlan> publish(
    String appointmentId, {
    required int expectedVersion,
    required String idempotencyKey,
  });
}

abstract interface class PatientCarePlanRepository {
  Future<PatientCareSummary> summary(String appointmentId);
  Future<PublishedCarePlan> updateTask(
    String publicationId,
    String sourceKey, {
    required int expectedVersion,
    required CareTaskStatus status,
  });
}
