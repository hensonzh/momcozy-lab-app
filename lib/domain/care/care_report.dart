import '../shared/local_date.dart';

enum CareReportPurpose { daily, preparation }

enum CareReportState {
  notGenerated,
  waitingForRecord,
  queued,
  running,
  ready,
  failed,
  cancelled,
  caseConsentRequired,
  aiConsentRequired,
}

enum CareReportSourceKind { dialogue, intake, lactation, carePlan, babyRecord }

enum CareReportReviewDecision { confirmed, feedback }

final class CareReportSource {
  const CareReportSource({
    required this.id,
    required this.kind,
    required this.recordedAt,
    required this.content,
    required this.truncated,
  });
  final String id, content;
  final CareReportSourceKind kind;
  final DateTime recordedAt;
  final bool truncated;
}

final class CareReportCitation {
  const CareReportCitation({required this.sourceId, required this.quote});
  final String sourceId, quote;
}

final class CareReportFinding {
  const CareReportFinding({required this.text, required this.evidence});
  final String text;
  final List<CareReportCitation> evidence;
}

final class CareReportContent {
  const CareReportContent({
    required this.summary,
    required this.emotionalState,
    required this.communicationPreferences,
    required this.checks,
    required this.dataGaps,
  });
  final List<CareReportFinding> summary,
      emotionalState,
      communicationPreferences,
      checks;
  final List<String> dataGaps;
}

final class CareReportDialogue {
  const CareReportDialogue({
    required this.runId,
    required this.threadId,
    required this.question,
    required this.answer,
    required this.questionAt,
    required this.answeredAt,
    required this.truncated,
  });
  final String runId, threadId, question, answer;
  final DateTime questionAt, answeredAt;
  final bool truncated;
}

final class CareReportReview {
  const CareReportReview({
    required this.id,
    required this.version,
    required this.decision,
    required this.feedback,
    required this.createdAt,
  });
  final String id, feedback;
  final int version;
  final CareReportReviewDecision decision;
  final DateTime createdAt;
}

final class CareReport {
  const CareReport({
    required this.id,
    required this.episodeId,
    required this.purpose,
    required this.date,
    required this.timezone,
    required this.version,
    required this.state,
    required this.createdAt,
    required this.reviewable,
    required this.sources,
    required this.dialogues,
    required this.omittedCount,
    this.asOf,
    this.generatedAt,
    this.content,
    this.review,
    this.errorCode,
    this.model,
    this.promptVersion,
  });
  final String id, episodeId, timezone;
  final CareReportPurpose purpose;
  final LocalDate date;
  final int version, omittedCount;
  final CareReportState state;
  final DateTime createdAt;
  final DateTime? asOf, generatedAt;
  final bool reviewable;
  final List<CareReportSource> sources;
  final List<CareReportDialogue> dialogues;
  final CareReportContent? content;
  final CareReportReview? review;
  final String? errorCode, model, promptVersion;
}

final class CareReportSnapshot {
  const CareReportSnapshot({
    required this.date,
    required this.timezone,
    required this.purpose,
    required this.state,
    required this.serverTime,
    this.report,
  });
  final LocalDate date;
  final String timezone;
  final CareReportPurpose purpose;
  final CareReportState state;
  final CareReport? report;
  final DateTime serverTime;
}

final class CareReportDay {
  const CareReportDay({
    required this.id,
    required this.date,
    required this.version,
    required this.state,
    this.reviewDecision,
  });
  final String id;
  final LocalDate date;
  final int version;
  final CareReportState state;
  final CareReportReviewDecision? reviewDecision;
}

abstract interface class CareReportsRepository {
  Future<CareReportSnapshot> read(
    String episodeId, {
    required CareReportPurpose purpose,
    LocalDate? date,
  });
  Future<CareReportSnapshot> generate(
    String episodeId, {
    required CareReportPurpose purpose,
    LocalDate? date,
  });
  Future<List<CareReportDay>> history(
    String episodeId, {
    required CareReportPurpose purpose,
  });
  Future<CareReport> review(
    String reportId, {
    required int expectedVersion,
    required CareReportReviewDecision decision,
    String feedback = '',
  });
}
