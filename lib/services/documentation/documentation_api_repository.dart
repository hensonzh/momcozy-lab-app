import '../../core/network/api_json_transport.dart';
import '../../domain/care/care_plan.dart';
import '../../domain/care/clinical_note.dart';
import '../../domain/care/documentation.dart';
import '../shared/product_failure_mapper.dart';
import 'documentation_codec.dart';

class DocumentationApiRepository
    implements CareDocumentationRepository, PatientCarePlanRepository {
  const DocumentationApiRepository({required this.transport});
  final ApiJsonTransport transport;
  String _path(String id) => '/v1/care/appointments/${Uri.encodeComponent(id)}';
  @override
  Future<CareDocumentation> load(String appointmentId) => withProductFailure(
    () async => readDocumentation(
      await transport.getJson('${_path(appointmentId)}/documentation'),
    ),
  );
  @override
  Future<ClinicalNote> noteRevision(String appointmentId, String noteId) =>
      withProductFailure(
        () async => readNote(
          await transport.getJson(
            '${_path(appointmentId)}/notes/${Uri.encodeComponent(noteId)}',
          ),
        ),
      );
  @override
  Future<ClinicalNote> saveNote(
    String appointmentId, {
    required ClinicalNoteContent content,
    required int expectedRevision,
    required int expectedVersion,
    required String idempotencyKey,
  }) => withProductFailure(
    () async => readNote(
      await (transport as ApiJsonMutationTransport).putJson(
        '${_path(appointmentId)}/note',
        headers: {'Idempotency-Key': idempotencyKey},
        body: {
          'expected_revision': expectedRevision,
          'expected_version': expectedVersion,
          'content': writeNoteContent(content),
        },
      ),
    ),
  );
  @override
  Future<ClinicalNote> signNote(
    String appointmentId, {
    required int expectedRevision,
    required int expectedVersion,
    required String idempotencyKey,
  }) => withProductFailure(
    () async => readNote(
      await transport.postJson(
        '${_path(appointmentId)}/note/sign',
        headers: {'Idempotency-Key': idempotencyKey},
        body: {
          'expected_revision': expectedRevision,
          'expected_version': expectedVersion,
        },
      ),
    ),
  );
  @override
  Future<ClinicalNote> amendNote(
    String appointmentId, {
    required String reason,
    required int expectedRevision,
    required int expectedVersion,
    required String idempotencyKey,
  }) => withProductFailure(
    () async => readNote(
      await transport.postJson(
        '${_path(appointmentId)}/note/amend',
        headers: {'Idempotency-Key': idempotencyKey},
        body: {
          'expected_revision': expectedRevision,
          'expected_version': expectedVersion,
          'reason': reason.trim(),
        },
      ),
    ),
  );
  @override
  Future<CarePlanDraft> savePlan(
    String appointmentId, {
    required CarePlanContent content,
    required int expectedVersion,
    required String idempotencyKey,
  }) => withProductFailure(
    () async => readPlanDraft(
      await (transport as ApiJsonMutationTransport).putJson(
        '${_path(appointmentId)}/plan',
        headers: {'Idempotency-Key': idempotencyKey},
        body: {
          'expected_version': expectedVersion,
          'content': writePlanContent(content),
        },
      ),
    ),
  );
  @override
  Future<PublishedCarePlan> publish(
    String appointmentId, {
    required int expectedVersion,
    required String idempotencyKey,
  }) => withProductFailure(
    () async => readPublication(
      await transport.postJson(
        '${_path(appointmentId)}/plan/publish',
        headers: {'Idempotency-Key': idempotencyKey},
        body: {'expected_version': expectedVersion},
      ),
    ),
  );
  @override
  Future<PatientCareSummary> summary(String appointmentId) =>
      withProductFailure(
        () async => readPatientSummary(
          await transport.getJson('${_path(appointmentId)}/summary'),
        ),
      );
  @override
  Future<PublishedCarePlan> updateTask(
    String publicationId,
    String sourceKey, {
    required int expectedVersion,
    required CareTaskStatus status,
  }) => withProductFailure(
    () async => readPublication(
      await (transport as ApiJsonMutationTransport).putJson(
        '/v1/care/plan-publications/${Uri.encodeComponent(publicationId)}/tasks/${Uri.encodeComponent(sourceKey)}',
        body: {
          'expected_version': expectedVersion,
          'status': careTaskStatusWire.write(status),
        },
      ),
    ),
  );
}
