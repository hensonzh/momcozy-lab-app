enum MotionAssessmentOutcome { completed, cancelled, failed }

class MotionAssessmentFinalization {
  const MotionAssessmentFinalization({
    required this.finalizationId,
    required this.assessmentId,
    required this.outcome,
    required this.resultSummary,
    required this.processSummary,
    required this.safetyEvents,
    required this.clientRevision,
    this.failureCode = '',
  });

  factory MotionAssessmentFinalization.fromJson(Map<String, Object?> json) {
    final outcome = switch (json['outcome']?.toString()) {
      'completed' => MotionAssessmentOutcome.completed,
      'cancelled' => MotionAssessmentOutcome.cancelled,
      'failed' => MotionAssessmentOutcome.failed,
      _ => throw const FormatException('Invalid motion assessment outcome.'),
    };
    final result = json['result_summary'];
    final process = json['process_summary'];
    final rawSafetyEvents = json['safety_events'];
    return MotionAssessmentFinalization(
      finalizationId: _requiredText(json, 'finalization_id', maxLength: 120),
      assessmentId: _requiredText(json, 'assessment_id', maxLength: 80),
      outcome: outcome,
      resultSummary: result is Map
          ? Map<String, Object?>.from(result)
          : const <String, Object?>{},
      processSummary: process is Map
          ? Map<String, Object?>.from(process)
          : const <String, Object?>{},
      safetyEvents: rawSafetyEvents is List
          ? List<Map<String, Object?>>.unmodifiable(
              rawSafetyEvents
                  .take(16)
                  .whereType<Map>()
                  .map(Map<String, Object?>.from),
            )
          : const <Map<String, Object?>>[],
      clientRevision: json['client_revision'] is int
          ? json['client_revision']! as int
          : 1,
      failureCode: _optionalText(json['failure_code'], maxLength: 64),
    );
  }

  final String finalizationId;
  final String assessmentId;
  final MotionAssessmentOutcome outcome;
  final Map<String, Object?> resultSummary;
  final Map<String, Object?> processSummary;
  final List<Map<String, Object?>> safetyEvents;
  final int clientRevision;
  final String failureCode;

  Map<String, Object?> toJson({bool includeAssessmentId = true}) {
    return <String, Object?>{
      'schema_version': 'motion_assessment.finalization.v1',
      if (includeAssessmentId) 'assessment_id': assessmentId,
      'finalization_id': finalizationId,
      'outcome': outcome.name,
      if (resultSummary.isNotEmpty) 'result_summary': resultSummary,
      'process_summary': processSummary,
      'safety_events': safetyEvents,
      'client_revision': clientRevision,
      if (failureCode.isNotEmpty) 'failure_code': failureCode,
    };
  }
}

abstract interface class MotionAssessmentFinalizationStore {
  Future<List<MotionAssessmentFinalization>> readAll();

  Future<void> upsert(MotionAssessmentFinalization finalization);

  Future<void> remove(String finalizationId);
}

String _requiredText(
  Map<String, Object?> json,
  String key, {
  required int maxLength,
}) {
  final value = _optionalText(json[key], maxLength: maxLength);
  if (value.isEmpty) throw FormatException('$key is required.');
  return value;
}

String _optionalText(Object? value, {required int maxLength}) {
  if (value is! String) return '';
  final normalized = value.trim();
  return normalized.length <= maxLength
      ? normalized
      : normalized.substring(0, maxLength);
}
