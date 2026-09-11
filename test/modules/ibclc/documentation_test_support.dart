import 'dart:convert';
import 'dart:io';
import 'package:momcozy_flutter_app/domain/care/care_plan.dart';
import 'package:momcozy_flutter_app/domain/care/clinical_note.dart';
import 'package:momcozy_flutter_app/domain/care/documentation.dart';
import 'package:momcozy_flutter_app/services/documentation/documentation_codec.dart';

Map<String, Object?> documentationFixture([
  String name = 'documentation_draft',
]) => Map<String, Object?>.from(
  jsonDecode(
        File('test/fixtures/product_baseline/$name.json').readAsStringSync(),
      )
      as Map,
);

class TestDocumentationRepository implements CareDocumentationRepository {
  Map<String, Object?> json = documentationFixture();
  final calls = <({String action, Map<String, Object?> body})>[];
  Future<void> Function(String action, Map<String, Object?> body)? onCall;
  Future<void> Function()? onLoad;
  @override
  Future<CareDocumentation> load(String appointmentId) async {
    await onLoad?.call();
    return readDocumentation(json);
  }

  Future<void> _call(String action, Map<String, Object?> body) async {
    calls.add((action: action, body: body));
    await onCall?.call(action, body);
  }

  ClinicalNote get note => readDocumentation(json).note!;
  @override
  Future<ClinicalNote> noteRevision(
    String appointmentId,
    String noteId,
  ) async => note;
  @override
  Future<ClinicalNote> saveNote(
    String appointmentId, {
    required ClinicalNoteContent content,
    required int expectedRevision,
    required int expectedVersion,
    required String idempotencyKey,
  }) async {
    await _call('save_note', {
      'content': writeNoteContent(content),
      'revision': expectedRevision,
      'version': expectedVersion,
      'key': idempotencyKey,
    });
    return note;
  }

  @override
  Future<ClinicalNote> signNote(
    String appointmentId, {
    required int expectedRevision,
    required int expectedVersion,
    required String idempotencyKey,
  }) async {
    await _call('sign', {
      'revision': expectedRevision,
      'version': expectedVersion,
      'key': idempotencyKey,
    });
    return note;
  }

  @override
  Future<ClinicalNote> amendNote(
    String appointmentId, {
    required String reason,
    required int expectedRevision,
    required int expectedVersion,
    required String idempotencyKey,
  }) async {
    await _call('amend', {
      'revision': expectedRevision,
      'version': expectedVersion,
      'key': idempotencyKey,
      'reason': reason,
    });
    return note;
  }

  @override
  Future<CarePlanDraft> savePlan(
    String appointmentId, {
    required CarePlanContent content,
    required int expectedVersion,
    required String idempotencyKey,
  }) async {
    await _call('save_plan', {
      'version': expectedVersion,
      'key': idempotencyKey,
      'content': writePlanContent(content),
    });
    return readDocumentation(json).plan!;
  }

  @override
  Future<PublishedCarePlan> publish(
    String appointmentId, {
    required int expectedVersion,
    required String idempotencyKey,
  }) async {
    await _call('publish', {'version': expectedVersion, 'key': idempotencyKey});
    return readDocumentation(json).publication!;
  }
}

class TestPatientPlanRepository implements PatientCarePlanRepository {
  Map<String, Object?> json = documentationFixture('patient_care_summary');
  final calls =
      <
        ({String publication, String key, int version, CareTaskStatus status})
      >[];
  Future<void> Function()? onUpdate;
  @override
  Future<PatientCareSummary> summary(String appointmentId) async =>
      readPatientSummary(json);
  @override
  Future<PublishedCarePlan> updateTask(
    String publicationId,
    String sourceKey, {
    required int expectedVersion,
    required CareTaskStatus status,
  }) async {
    calls.add((
      publication: publicationId,
      key: sourceKey,
      version: expectedVersion,
      status: status,
    ));
    await onUpdate?.call();
    return readPatientSummary(json).publication!;
  }
}
