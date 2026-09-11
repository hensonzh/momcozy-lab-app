import '../../domain/care/care_plan.dart';
import '../../domain/care/clinical_note.dart';
import '../../domain/care/documentation.dart';
import '../../domain/shared/local_date.dart';
import '../appointments/appointment_codec.dart';
import '../care/care_codec.dart';
import '../consultations/room_codec.dart';
import '../shared/json_value.dart';

const noteStatusWire = EnumWire<ClinicalNoteStatus>({
  ClinicalNoteStatus.draft: 'draft',
  ClinicalNoteStatus.signed: 'signed',
});
const careTaskStatusWire = EnumWire<CareTaskStatus>({
  CareTaskStatus.pending: 'pending',
  CareTaskStatus.inProgress: 'in_progress',
  CareTaskStatus.completed: 'completed',
  CareTaskStatus.skipped: 'skipped',
});

ClinicalNoteContent readNoteContent(Map<String, Object?> json) =>
    ClinicalNoteContent(
      subjective: jsonString(json['subjective']),
      objective: jsonString(json['objective']),
      assessment: jsonString(json['assessment']),
      plan: jsonString(json['plan']),
    );
Map<String, Object?> writeNoteContent(ClinicalNoteContent value) => {
  'subjective': value.subjective.trim(),
  'objective': value.objective.trim(),
  'assessment': value.assessment.trim(),
  'plan': value.plan.trim(),
};
ClinicalNoteRevision readNoteRevision(Map<String, Object?> json) =>
    ClinicalNoteRevision(
      id: jsonString(json['id']),
      consultationId: jsonString(json['consultation_id']),
      authorId: jsonString(json['author_id']),
      revision: jsonInt(json['revision']),
      version: jsonInt(json['version']),
      status: noteStatusWire.read(json['status'])!,
      updatedAt: jsonInstant(json['updated_at']),
      signedAt: json['signed_at'] == null
          ? null
          : jsonInstant(json['signed_at']),
      revisesId: json['revises_id'] as String?,
      amendmentReason: jsonString(json['amendment_reason']),
    );
ClinicalNote readNote(Map<String, Object?> json) {
  final revision = readNoteRevision(json);
  return ClinicalNote(
    id: revision.id,
    consultationId: revision.consultationId,
    authorId: revision.authorId,
    revision: revision.revision,
    version: revision.version,
    status: revision.status,
    updatedAt: revision.updatedAt,
    signedAt: revision.signedAt,
    revisesId: revision.revisesId,
    amendmentReason: revision.amendmentReason,
    content: readNoteContent(jsonObject(json['content'])),
  );
}

CarePlanTaskContent readPlanTask(Map<String, Object?> json) =>
    CarePlanTaskContent(
      sourceKey: jsonString(json['source_key']),
      title: jsonString(json['title']),
      description: jsonString(json['description']),
      category: jsonString(json['category']),
      dueLabel: jsonString(json['due_label']),
      scheduledDate: json['scheduled_date'] == null
          ? null
          : LocalDate.parse(jsonString(json['scheduled_date'])),
    );
Map<String, Object?> writePlanTask(CarePlanTaskContent value) => {
  'source_key': value.sourceKey,
  'title': value.title.trim(),
  'description': value.description.trim(),
  'category': value.category.trim(),
  'due_label': value.dueLabel.trim(),
  'scheduled_date': value.scheduledDate?.toString(),
};
CarePlanContent readPlanContent(Map<String, Object?> json) => CarePlanContent(
  title: jsonString(json['title']),
  summary: jsonString(json['summary']),
  goals: jsonStrings(json['goals']),
  tasks: jsonList(json['tasks'], readPlanTask),
);
Map<String, Object?> writePlanContent(CarePlanContent value) => {
  'title': value.title.trim(),
  'summary': value.summary.trim(),
  'goals': value.goals.map((item) => item.trim()).toList(),
  'tasks': value.tasks.map(writePlanTask).toList(),
};
CarePlanDraft readPlanDraft(Map<String, Object?> json) => CarePlanDraft(
  id: jsonString(json['id']),
  consultationId: jsonString(json['consultation_id']),
  version: jsonInt(json['version']),
  publishedRevision: jsonInt(json['published_revision']),
  content: readPlanContent(jsonObject(json['content'])),
  updatedAt: jsonInstant(json['updated_at']),
);
PublishedCarePlan readPublication(Map<String, Object?> json) =>
    PublishedCarePlan(
      id: jsonString(json['id']),
      planId: jsonString(json['plan_id']),
      consultationId: jsonString(json['consultation_id']),
      revision: jsonInt(json['revision']),
      title: jsonString(json['title']),
      summary: jsonString(json['summary']),
      goals: jsonStrings(json['goals']),
      tasks: jsonList(
        json['tasks'],
        (task) => PublishedCareTask(
          content: readPlanTask(task),
          status: careTaskStatusWire.read(task['status'])!,
          progressVersion: jsonInt(task['progress_version']),
        ),
      ),
      publisherName: jsonString(json['publisher_name']),
      publishedAt: jsonInstant(json['published_at']),
    );
CareDocumentation readDocumentation(Map<String, Object?> json) =>
    CareDocumentation(
      appointment: readAppointment(jsonObject(json['appointment'])),
      consultation: json['consultation'] == null
          ? null
          : readConsultation(jsonObject(json['consultation'])),
      note: json['note'] == null ? null : readNote(jsonObject(json['note'])),
      noteHistory: jsonList(json['note_history'], readNoteRevision),
      plan: json['plan'] == null
          ? null
          : readPlanDraft(jsonObject(json['plan'])),
      publication: json['publication'] == null
          ? null
          : readPublication(jsonObject(json['publication'])),
    );
PatientCareSummary readPatientSummary(Map<String, Object?> json) =>
    PatientCareSummary(
      episode: readCareEpisode(jsonObject(json['episode'])),
      appointment: readAppointment(jsonObject(json['appointment'])),
      consultation: json['consultation'] == null
          ? null
          : readConsultation(jsonObject(json['consultation'])),
      publication: json['publication'] == null
          ? null
          : readPublication(jsonObject(json['publication'])),
    );
