enum ClinicalNoteStatus { draft, signed }

final class ClinicalNoteContent {
  const ClinicalNoteContent({
    this.subjective = '',
    this.objective = '',
    this.assessment = '',
    this.plan = '',
  });
  final String subjective, objective, assessment, plan;
  bool get complete => [
    subjective,
    objective,
    assessment,
    plan,
  ].every((value) => value.trim().isNotEmpty);
  bool get withinLimits => [
    subjective,
    objective,
    assessment,
    plan,
  ].every((value) => value.trim().length <= 8000);
  ClinicalNoteContent copyWith({
    String? subjective,
    String? objective,
    String? assessment,
    String? plan,
  }) => ClinicalNoteContent(
    subjective: subjective ?? this.subjective,
    objective: objective ?? this.objective,
    assessment: assessment ?? this.assessment,
    plan: plan ?? this.plan,
  );
}

class ClinicalNoteRevision {
  const ClinicalNoteRevision({
    required this.id,
    required this.consultationId,
    required this.authorId,
    required this.revision,
    required this.version,
    required this.status,
    required this.updatedAt,
    this.revisesId,
    this.amendmentReason = '',
    this.signedAt,
  });
  final String id, consultationId, authorId, amendmentReason;
  final String? revisesId;
  final int revision, version;
  final ClinicalNoteStatus status;
  final DateTime updatedAt;
  final DateTime? signedAt;
}

final class ClinicalNote extends ClinicalNoteRevision {
  const ClinicalNote({
    required super.id,
    required super.consultationId,
    required super.authorId,
    required super.revision,
    required super.version,
    required super.status,
    required super.updatedAt,
    super.revisesId,
    super.amendmentReason,
    super.signedAt,
    required this.content,
  });
  final ClinicalNoteContent content;
}
