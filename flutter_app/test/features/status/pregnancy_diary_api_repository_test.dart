import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/status/data/pregnancy_diary_api_repository.dart';
import 'package:momcozy_flutter_app/features/status/domain/pregnancy_diary.dart';

import '../../support/fixture_api_transport.dart';

void main() {
  group('PregnancyDiaryApiRepository', () {
    test('maps current and legacy diary fields from a bounded list', () async {
      final transport = FixtureApiJsonTransport({
        'items': [
          {
            'id': 'diary-001',
            'entry_date': '2026-07-11',
            'gestational_week': '孕 32 周',
            'mood': '平稳',
            'energy_level': '一般',
            'sleep_summary': '易醒',
            'fetal_movement': '胎动正常',
            'symptom_tags': ['腰酸', '水肿'],
            'appointment_note': '想确认水肿是否正常',
            'content': '今天散步二十分钟。',
            'health_notes': [
              {
                'note_id': 'note-001',
                'topic': '水肿',
                'user_report': '下午更明显',
                'follow_up': '持续观察血压',
              },
            ],
            'status': 'active',
          },
        ],
      });
      final repository = PregnancyDiaryApiRepository(transport: transport);

      final entries = await repository.fetchEntries(
        startDate: DateTime(2026, 7, 5),
        endDate: DateTime(2026, 7, 11),
        limit: 12,
      );

      expect(transport.lastPath, pregnancyDiaryEntriesEndpoint);
      expect(transport.lastQuery, {
        'start_date': '2026-07-05',
        'end_date': '2026-07-11',
        'limit': 12,
      });
      expect(entries.single.gestationalWeek, '孕 32 周');
      expect(entries.single.symptomTags, ['腰酸', '水肿']);
      expect(entries.single.hasAppointmentQuestion, isTrue);
      expect(entries.single.healthNotes.single.followUp, '持续观察血压');
    });

    test('upserts the complete diary draft through PUT', () async {
      final transport = FixtureApiJsonTransport({
        'id': 'diary-001',
        'entry_date': '2026-07-11',
        'gestational_week': '孕 32 周',
        'mood': '平稳',
        'energy_level': '一般',
        'sleep_summary': '易醒',
        'fetal_movement': '胎动正常',
        'symptom_tags': ['腰酸'],
        'appointment_note': '想问医生',
        'nutrition_note': '',
        'content': '今天状态稳定。',
        'attachments': [],
        'status': 'active',
      });
      final repository = PregnancyDiaryApiRepository(transport: transport);
      const draft = PregnancyDiaryDraft(
        gestationalWeek: '孕 32 周',
        mood: '平稳',
        energyLevel: '一般',
        sleepSummary: '易醒',
        fetalMovement: '胎动正常',
        symptomTags: ['腰酸', ' '],
        appointmentNote: '想问医生',
        content: '今天状态稳定。',
      );

      final entry = await repository.upsertEntry(
        entryDate: DateTime(2026, 7, 11),
        draft: draft,
      );

      expect(draft.hasContent, isTrue);
      expect(transport.lastMethod, 'PUT');
      expect(transport.lastPath, '$pregnancyDiaryEntriesEndpoint/2026-07-11');
      expect(transport.lastBody, {
        'gestational_week': '孕 32 周',
        'mood': '平稳',
        'energy_level': '一般',
        'sleep_summary': '易醒',
        'fetal_movement': '胎动正常',
        'symptom_tags': ['腰酸'],
        'appointment_note': '想问医生',
        'nutrition_note': '',
        'content': '今天状态稳定。',
      });
      expect(entry.id, 'diary-001');
    });

    test('preserves production HTTP failures', () async {
      final repository = PregnancyDiaryApiRepository(
        transport: FixtureApiJsonTransport({
          'http_status': 503,
          'status_text': 'Service Unavailable',
          'body': {
            'error': {
              'code': 'dependency_failed',
              'message': 'Diary unavailable',
            },
          },
        }),
      );

      await expectLater(
        repository.fetchEntries(),
        throwsA(
          isA<ApiHttpException>().having(
            (error) => error.errorCode,
            'errorCode',
            'dependency_failed',
          ),
        ),
      );
    });
  });
}
