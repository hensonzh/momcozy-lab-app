import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/pregnancy_diary/domain/pregnancy_diary_entry.dart';
import 'package:momcozy_flutter_app/features/status/domain/pregnancy_diary_projection.dart';

void main() {
  group('PregnancyDiaryProjection', () {
    test('matches seven-day counts and question segmentation', () {
      final projection = PregnancyDiaryProjection(
        now: DateTime(2026, 7, 11, 23, 30),
        entries: [
          _entry(
            id: 'today',
            date: DateTime(2026, 7, 11, 8),
            appointmentNote: '胎动少需要检查吗？\n药还能继续吃吗;',
          ),
          _entry(
            id: 'first-day',
            date: DateTime(2026, 7, 5),
            appointmentNote: '需要空腹吗',
          ),
          _entry(id: 'outside', date: DateTime(2026, 7, 4)),
          _entry(id: 'future', date: DateTime(2026, 7, 12)),
        ],
      );

      expect(projection.today?.id, 'today');
      expect(projection.recentCount, 2);
      expect(projection.questionCount, 3);
      expect(projection.entries.map((entry) => entry.id), [
        'future',
        'today',
        'first-day',
        'outside',
      ]);
    });

    test('builds summary, deduplicated text blocks, and four signal tags', () {
      final entry = _entry(
        id: 'today',
        date: DateTime(2026, 7, 11),
        mood: ' 平稳 ',
        fetalMovement: '胎动正常',
        sleepSummary: '易醒',
        content: ' 今天散步了 ',
        appointmentNote: '需要补钙吗',
        nutritionNote: '今天散步了',
        symptomTags: const ['腰酸', '水肿'],
      );

      expect(PregnancyDiaryProjection.summary(entry), '今日已记录：心情平稳，胎动正常');
      expect(PregnancyDiaryProjection.textBlocks(entry), ['今天散步了', '需要补钙吗']);
      expect(PregnancyDiaryProjection.signalTags(entry), [
        '心情平稳',
        '胎动正常',
        '易醒',
        '腰酸',
      ]);
    });

    test('uses the approved primary Agent prompt priority', () {
      final questions = PregnancyDiaryProjection(
        now: DateTime(2026, 7, 11),
        entries: [
          _entry(
            id: 'q',
            date: DateTime(2026, 7, 11),
            appointmentNote: '下次检查什么？',
          ),
        ],
      );
      expect(questions.primaryAction, '整理产检问题');
      expect(questions.primarySubtitle, '从日记里整理 1 个问题');
      expect(questions.primaryPrompt, '帮我整理孕期日记里的产检问题清单');

      final recent = PregnancyDiaryProjection(
        now: DateTime(2026, 7, 11),
        entries: [_entry(id: 'recent', date: DateTime(2026, 7, 10))],
      );
      expect(recent.primaryAction, '回顾最近记录');
      expect(recent.primaryPrompt, '帮我回顾最近7天的孕期日记');

      final empty = PregnancyDiaryProjection(
        now: DateTime(2026, 7, 11),
        entries: const [],
      );
      expect(empty.primaryPrompt, '帮我回顾最近7天的孕期日记');
    });
  });
}

PregnancyDiaryEntry _entry({
  required String id,
  required DateTime date,
  String mood = '',
  String fetalMovement = '',
  String sleepSummary = '',
  String content = '',
  String appointmentNote = '',
  String nutritionNote = '',
  List<String> symptomTags = const [],
}) {
  return PregnancyDiaryEntry(
    id: id,
    entryDate: date,
    mood: mood,
    fetalMovement: fetalMovement,
    sleepSummary: sleepSummary,
    content: content,
    appointmentNote: appointmentNote,
    nutritionNote: nutritionNote,
    symptomTags: symptomTags,
  );
}
