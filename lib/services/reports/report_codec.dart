import '../../domain/care/care_report.dart';
import '../../domain/shared/local_date.dart';
import '../shared/json_value.dart';

const reportPurposeWire = EnumWire<CareReportPurpose>({
  CareReportPurpose.daily: 'daily',
  CareReportPurpose.preparation: 'preparation',
});
const reportStateWire = EnumWire<CareReportState>({
  CareReportState.notGenerated: 'not_generated',
  CareReportState.waitingForRecord: 'waiting_for_record',
  CareReportState.queued: 'queued',
  CareReportState.running: 'running',
  CareReportState.ready: 'ready',
  CareReportState.failed: 'failed',
  CareReportState.cancelled: 'cancelled',
  CareReportState.caseConsentRequired: 'case_consent_required',
  CareReportState.aiConsentRequired: 'ai_consent_required',
});
const reportReviewWire = EnumWire<CareReportReviewDecision>({
  CareReportReviewDecision.confirmed: 'confirmed',
  CareReportReviewDecision.feedback: 'feedback',
});
const reportSourceWire = EnumWire<CareReportSourceKind>({
  CareReportSourceKind.dialogue: 'dialogue',
  CareReportSourceKind.intake: 'intake',
  CareReportSourceKind.lactation: 'lactation',
  CareReportSourceKind.carePlan: 'care_plan',
  CareReportSourceKind.babyRecord: 'baby_record',
});

CareReportSnapshot readReportSnapshot(Map<String, Object?> json) =>
    CareReportSnapshot(
      date: LocalDate.parse(jsonString(json['report_date'])),
      timezone: jsonString(json['timezone']),
      purpose: reportPurposeWire.read(json['purpose'])!,
      state: reportStateWire.read(json['state'])!,
      serverTime: jsonInstant(json['server_time']),
      report: json['report'] == null
          ? null
          : readReport(jsonObject(json['report'])),
    );
CareReportFinding _finding(Map<String, Object?> json) => CareReportFinding(
  text: jsonString(json['text']),
  evidence: jsonList(
    json['evidence'],
    (item) => CareReportCitation(
      sourceId: jsonString(item['source_id']),
      quote: jsonString(item['quote']),
    ),
  ),
);
CareReportContent _content(Map<String, Object?> json) => CareReportContent(
  summary: jsonList(json['summary'], _finding),
  emotionalState: jsonList(json['emotional_state'], _finding),
  communicationPreferences: jsonList(
    json['communication_preferences'],
    _finding,
  ),
  checks: jsonList(json['checks'], _finding),
  dataGaps: jsonStrings(json['data_gaps']),
);
CareReportReview _review(Map<String, Object?> json) => CareReportReview(
  id: jsonString(json['id']),
  version: jsonInt(json['version']),
  decision: reportReviewWire.read(json['decision'])!,
  feedback: jsonString(json['feedback']),
  createdAt: jsonInstant(json['created_at']),
);
CareReport readReport(Map<String, Object?> json) {
  final snapshot = json['snapshot'] == null
      ? null
      : jsonObject(json['snapshot']);
  final input = snapshot == null ? null : jsonObject(snapshot['input']);
  final result = json['result'] == null ? null : jsonObject(json['result']);
  return CareReport(
    id: jsonString(json['id']),
    episodeId: jsonString(json['episode_id']),
    purpose: reportPurposeWire.read(json['purpose'])!,
    date: LocalDate.parse(jsonString(json['report_date'])),
    timezone: jsonString(json['timezone']),
    version: jsonInt(json['version']),
    state: reportStateWire.read(json['status'])!,
    createdAt: jsonInstant(json['created_at']),
    generatedAt: json['generated_at'] == null
        ? null
        : jsonInstant(json['generated_at']),
    reviewable: jsonBool(json['reviewable']),
    asOf: input == null ? null : jsonInstant(input['as_of']),
    omittedCount: input == null ? 0 : jsonInt(input['omitted_count']),
    sources: input == null
        ? const []
        : jsonList(
            input['sources'],
            (item) => CareReportSource(
              id: jsonString(item['id']),
              kind: reportSourceWire.read(item['kind'])!,
              recordedAt: jsonInstant(item['recorded_at']),
              content: jsonString(item['content']),
              truncated: jsonBool(item['truncated']),
            ),
          ),
    dialogues: snapshot == null
        ? const []
        : jsonList(
            snapshot['dialogues'],
            (item) => CareReportDialogue(
              runId: jsonString(item['run_id']),
              threadId: jsonString(item['thread_id']),
              question: jsonString(item['question']),
              answer: jsonString(item['answer']),
              questionAt: jsonInstant(item['question_at']),
              answeredAt: jsonInstant(item['answered_at']),
              truncated:
                  jsonBool(item['question_truncated']) ||
                  jsonBool(item['answer_truncated']),
            ),
          ),
    content: result == null ? null : _content(jsonObject(result['content'])),
    review: json['review'] == null ? null : _review(jsonObject(json['review'])),
    errorCode: json['error_code'] as String?,
    model: result?['model'] as String?,
    promptVersion: result?['prompt_version'] as String?,
  );
}

CareReportDay readReportDay(Map<String, Object?> json) => CareReportDay(
  id: jsonString(json['id']),
  date: LocalDate.parse(jsonString(json['report_date'])),
  version: jsonInt(json['version']),
  state: reportStateWire.read(json['status'])!,
  reviewDecision: reportReviewWire.read(json['review_decision']),
);
