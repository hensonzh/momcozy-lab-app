import 'package:momcozy_flutter_app/features/status/domain/pregnancy_diary.dart';

class PregnancyDiaryProjection {
  PregnancyDiaryProjection({
    required List<PregnancyDiaryEntry> entries,
    required DateTime now,
  }) : entries = _sortEntries(entries),
       today = _findToday(entries, now),
       recentCount = _recentEntries(entries, now).length,
       recentHealthNotes = _recentEntries(
         entries,
         now,
       ).expand((entry) => entry.healthNotes).toList(growable: false),
       questionCount = entries.fold<int>(
         0,
         (total, entry) => total + _questionCount(entry.appointmentNote),
       );

  final List<PregnancyDiaryEntry> entries;
  final PregnancyDiaryEntry? today;
  final int recentCount;
  final List<PregnancyDiaryHealthNote> recentHealthNotes;
  final int questionCount;

  int get recentHealthNoteCount => recentHealthNotes.length;

  List<String> get todayTextBlocks => textBlocks(today);

  String get primaryAction => questionCount > 0 ? '整理产检问题' : '回顾最近记录';

  String get primarySubtitle =>
      questionCount > 0 ? '从日记里整理 $questionCount 个问题' : '把最近记录整理成一段状态回顾';

  String get primaryPrompt {
    if (questionCount > 0) return '帮我整理孕期日记里的产检问题清单';
    if (recentHealthNotes.isNotEmpty) return '帮我回顾最近的健康咨询记录';
    return '帮我回顾最近7天的孕期日记';
  }

  static String summary(PregnancyDiaryEntry? entry) {
    if (entry == null) return '今天还没有记录哦';
    final parts = <String>[
      if (_compact(entry.mood).isNotEmpty) '心情${_compact(entry.mood)}',
      _compact(entry.fetalMovement),
      _compact(entry.sleepSummary),
    ].where((part) => part.isNotEmpty).take(2).toList(growable: false);
    if (parts.isNotEmpty) return '今日已记录：${parts.join('，')}';
    if (entry.healthNotes.isNotEmpty) {
      final topic = _compact(entry.healthNotes.first.topic);
      return '今日已记录：${topic.isEmpty ? '健康咨询' : topic}';
    }
    final content = _compact(entry.content);
    return content.isNotEmpty ? '今日已记录：$content' : '今天已有孕期记录';
  }

  static List<String> textBlocks(PregnancyDiaryEntry? entry) {
    if (entry == null) return const <String>[];
    final candidates = <String>[
      entry.content,
      entry.appointmentNote,
      entry.nutritionNote,
      ...entry.healthNotes.map((note) => note.userReport),
    ];
    final seen = <String>{};
    return candidates
        .map(_compact)
        .where((text) => text.isNotEmpty && seen.add(text))
        .toList(growable: false);
  }

  static List<String> signalTags(PregnancyDiaryEntry entry) {
    return <String>[
          if (_compact(entry.mood).isNotEmpty) '心情${_compact(entry.mood)}',
          entry.fetalMovement,
          entry.sleepSummary,
          ...entry.healthNotes.map((note) => note.topic),
          ...entry.symptomTags,
        ]
        .map(_compact)
        .where((tag) => tag.isNotEmpty)
        .take(4)
        .toList(growable: false);
  }
}

List<PregnancyDiaryEntry> _sortEntries(List<PregnancyDiaryEntry> entries) {
  final sorted = List<PregnancyDiaryEntry>.of(entries);
  sorted.sort((a, b) => b.entryDate.compareTo(a.entryDate));
  return List<PregnancyDiaryEntry>.unmodifiable(sorted);
}

PregnancyDiaryEntry? _findToday(
  List<PregnancyDiaryEntry> entries,
  DateTime now,
) {
  for (final entry in entries) {
    if (_sameLocalDay(entry.entryDate, now)) return entry;
  }
  return null;
}

List<PregnancyDiaryEntry> _recentEntries(
  List<PregnancyDiaryEntry> entries,
  DateTime now,
) {
  final today = DateTime(now.year, now.month, now.day);
  final firstDay = today.subtract(const Duration(days: 6));
  return entries
      .where((entry) {
        final date = DateTime(
          entry.entryDate.year,
          entry.entryDate.month,
          entry.entryDate.day,
        );
        return !date.isBefore(firstDay) && !date.isAfter(today);
      })
      .toList(growable: false);
}

int _questionCount(String value) {
  final note = _compact(value);
  if (note.isEmpty) return 0;
  final questions = note
      .split(RegExp(r'[？?\n；;]'))
      .map(_compact)
      .where((question) => question.isNotEmpty)
      .length;
  return questions < 1 ? 1 : questions;
}

bool _sameLocalDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String _compact(String value) => value.trim();
