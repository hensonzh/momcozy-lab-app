import '../shared/local_date.dart';

enum CareTaskStatus { pending, inProgress, completed, skipped }

// Patient-facing plans require an expert-reviewed English version before
// publication. Drafts and private clinical notes keep their original text.
final _unreviewedPlanCopy = RegExp(
  r'[\u3400-\u9fff\u{20000}-\u{323af}\u3040-\u30ff\u31f0-\u31ff\uac00-\ud7af\u0400-\u052f\u0600-\u06ff\u0900-\u097f]|cozy[\s-]*mate',
  caseSensitive: false,
  unicode: true,
);

final _retiredPlanBrand = RegExp(r'cozy[\s-]*mate', caseSensitive: false);

String _englishTaskMetadata(String raw, String fallback) {
  final display = raw.replaceAll(_retiredPlanBrand, 'Momcozy AI');
  return display.trim().isEmpty || _unreviewedPlanCopy.hasMatch(display)
      ? fallback
      : display;
}

final class CarePlanTaskContent {
  const CarePlanTaskContent({
    required this.sourceKey,
    this.title = '',
    this.description = '',
    this.category = '',
    this.dueLabel = '',
    this.scheduledDate,
  });
  final String sourceKey, title, description, category, dueLabel;
  final LocalDate? scheduledDate;

  String get displayCategory => category == '\u89c2\u5bdf'
      ? 'Observation'
      : _englishTaskMetadata(category, 'Care task');
  String get displayDueLabel => dueLabel == '\u4eca\u5929'
      ? 'Originally marked “Today”'
      : _englishTaskMetadata(dueLabel, 'Ask your consultant about timing');
  bool get complete => [
    title,
    description,
    category,
    dueLabel,
  ].every((value) => value.trim().isNotEmpty);
  bool get withinLimits =>
      title.trim().length <= 160 &&
      description.trim().length <= 1000 &&
      category.trim().length <= 64 &&
      dueLabel.trim().length <= 80;
  CarePlanTaskContent copyWith({
    String? title,
    String? description,
    String? category,
    String? dueLabel,
    LocalDate? scheduledDate,
    bool clearDate = false,
  }) => CarePlanTaskContent(
    sourceKey: sourceKey,
    title: title ?? this.title,
    description: description ?? this.description,
    category: category ?? this.category,
    dueLabel: dueLabel ?? this.dueLabel,
    scheduledDate: clearDate ? null : scheduledDate ?? this.scheduledDate,
  );
}

final class CarePlanContent {
  CarePlanContent({
    this.title = '',
    this.summary = '',
    List<String> goals = const [],
    List<CarePlanTaskContent> tasks = const [],
  }) : goals = List.unmodifiable(goals),
       tasks = List.unmodifiable(tasks);
  final String title, summary;
  final List<String> goals;
  final List<CarePlanTaskContent> tasks;
  bool get complete =>
      title.trim().isNotEmpty &&
      summary.trim().isNotEmpty &&
      goals.isNotEmpty &&
      goals.every((value) => value.trim().isNotEmpty) &&
      tasks.isNotEmpty &&
      tasks.every((value) => value.complete);
  bool get englishClientCopy => ![
    title,
    summary,
    ...goals,
    for (final task in tasks) ...[
      task.title,
      task.description,
      task.category,
      task.dueLabel,
    ],
  ].any(_unreviewedPlanCopy.hasMatch);
  bool get withinLimits =>
      title.trim().length <= 120 &&
      summary.trim().length <= 3000 &&
      goals.length <= 6 &&
      goals.every((value) => value.trim().length <= 200) &&
      tasks.length <= 12 &&
      tasks.every((value) => value.withinLimits) &&
      tasks.map((value) => value.sourceKey).toSet().length == tasks.length;
  CarePlanContent copyWith({
    String? title,
    String? summary,
    List<String>? goals,
    List<CarePlanTaskContent>? tasks,
  }) => CarePlanContent(
    title: title ?? this.title,
    summary: summary ?? this.summary,
    goals: goals ?? this.goals,
    tasks: tasks ?? this.tasks,
  );
}

final class CarePlanDraft {
  const CarePlanDraft({
    required this.id,
    required this.consultationId,
    required this.version,
    required this.publishedRevision,
    required this.content,
    required this.updatedAt,
  });
  final String id, consultationId;
  final int version, publishedRevision;
  final CarePlanContent content;
  final DateTime updatedAt;
}

final class PublishedCareTask {
  const PublishedCareTask({
    required this.content,
    required this.status,
    required this.progressVersion,
  });
  final CarePlanTaskContent content;
  final CareTaskStatus status;
  final int progressVersion;
}

final class PublishedCarePlan {
  PublishedCarePlan({
    required this.id,
    required this.planId,
    required this.consultationId,
    required this.revision,
    required this.title,
    required this.summary,
    required List<String> goals,
    required List<PublishedCareTask> tasks,
    required this.publisherName,
    required this.publishedAt,
  }) : goals = List.unmodifiable(goals),
       tasks = List.unmodifiable(tasks);
  final String id, planId, consultationId, title, summary, publisherName;
  final int revision;
  final List<String> goals;
  final List<PublishedCareTask> tasks;
  final DateTime publishedAt;
}
