import '../../../domain/lactation/lactation_record.dart';
import '../../../domain/mother/mother_diary.dart';
import '../../../domain/shared/local_date.dart';
import 'mother_knowledge_content.dart';

MotherKnowledgeTopic selectMotherKnowledge({
  required DateTime now,
  required String ownerUserId,
  required Iterable<MotherDiaryEntry> diaries,
  required Iterable<LactationRecord> lactation,
}) {
  final local = now.toLocal();
  var release = DateTime(local.year, local.month, local.day, 8);
  if (release.isAfter(local)) {
    release = DateTime(local.year, local.month, local.day - 1, 8);
  }
  final start = release.subtract(const Duration(hours: 24));
  bool inWindow(DateTime instant) =>
      instant.isAfter(start) && !instant.isAfter(release);
  final signals =
      <({MotherKnowledgeTopic topic, DateTime at, int relevance})>[];
  for (final entry in diaries) {
    if (entry.ownerUserId != ownerUserId || !inWindow(entry.updatedAt)) {
      continue;
    }
    final value = entry.diary;
    if (!value.body.isEmpty) {
      signals.add((
        topic: MotherKnowledgeTopic.body,
        at: entry.updatedAt,
        relevance:
            value.body.impact == BodyImpact.careLimited ||
                value.body.trend == RecoveryTrend.worse ||
                value.body.severity == DiscomfortSeverity.hardToIgnore
            ? 4
            : 2,
      ));
    }
    if (!value.rest.isEmpty) {
      signals.add((
        topic: MotherKnowledgeTopic.rest,
        at: entry.updatedAt,
        relevance:
            value.rest.recovery == SleepRecovery.exhausted ||
                value.rest.total == SleepTotalBand.underThreeHours ||
                value.rest.resleepDifficulty == ResleepDifficulty.hard
            ? 4
            : 1,
      ));
    }
    if (!value.mood.isEmpty) {
      signals.add((
        topic: MotherKnowledgeTopic.mood,
        at: entry.updatedAt,
        relevance:
            value.mood.impact == MoodImpact.hard ||
                value.mood.tone == MoodTone.low ||
                value.mood.tone == MoodTone.reactive
            ? 4
            : 1,
      ));
    }
  }
  for (final entry in lactation) {
    if (entry.ownerUserId != ownerUserId ||
        !inWindow(entry.observation.occurredAt)) {
      continue;
    }
    signals.add((
      topic: MotherKnowledgeTopic.lactation,
      at: entry.observation.occurredAt,
      relevance: entry.observation.feeling == BreastComfort.painful ? 4 : 1,
    ));
  }
  signals.sort((a, b) {
    final byTime = b.at.compareTo(a.at);
    if (byTime != 0) return byTime;
    final byRelevance = b.relevance.compareTo(a.relevance);
    return byRelevance != 0
        ? byRelevance
        : a.topic.index.compareTo(b.topic.index);
  });
  if (signals.isNotEmpty) return signals.first.topic;
  final seed = '$ownerUserId-${LocalDate.fromDateTime(release)}'.codeUnits
      .fold<int>(0, (sum, value) => sum + value);
  return [
    MotherKnowledgeTopic.body,
    MotherKnowledgeTopic.rest,
    MotherKnowledgeTopic.mood,
  ][seed % 3];
}
