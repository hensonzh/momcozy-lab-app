import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/pregnancy_diary/data/pregnancy_diary_api_repository.dart';
import 'package:momcozy_flutter_app/features/pregnancy_diary/domain/pregnancy_diary_entry.dart';

void main() {
  group('PregnancyDiaryApiRepository', () {
    test('maps the complete diary entry and bounded query', () async {
      final transport = _RecordingTransport();
      final repository = PregnancyDiaryApiRepository(transport: transport);

      final entries = await repository.fetchEntries(
        startDate: DateTime(2026, 7, 5),
        endDate: DateTime(2026, 7, 11),
        limit: 120,
      );

      expect(entries.single.content, '已有日记');
      expect(entries.single.gestationalWeek, '孕 32 周');
      expect(entries.single.symptomTags, ['腰酸', '水肿']);
      expect(entries.single.hasAppointmentQuestion, isTrue);
      expect(entries.single.status, 'active');
      expect(transport.calls, [('GET', '/v1/pregnancy-diary/entries')]);
      expect(transport.firstQuery, {
        'start_date': '2026-07-05',
        'end_date': '2026-07-11',
        'limit': 100,
      });
    });

    test('creates, updates, and deletes using the backend contract', () async {
      final transport = _RecordingTransport();
      final repository = PregnancyDiaryApiRepository(transport: transport);
      const draft = PregnancyDiaryDraft(
        gestationalWeek: ' 孕 32 周 ',
        mood: ' 平稳 ',
        energyLevel: ' 一般 ',
        sleepSummary: ' 易醒 ',
        fetalMovement: ' 胎动正常 ',
        symptomTags: [' 腰酸 ', ' ', '水肿'],
        appointmentNote: ' 想确认水肿是否正常 ',
        nutritionNote: ' 增加蛋白质 ',
        content: ' 今天胎动规律。 ',
      );

      final created = await repository.createEntry(
        entryDate: DateTime(2026, 7, 11),
        draft: draft,
      );
      final updated = await repository.updateEntry(
        entryDate: DateTime(2026, 7, 11),
        draft: draft,
      );
      await repository.deleteEntry(entryDate: DateTime(2026, 7, 11));

      expect(created.content, '今天胎动规律。');
      expect(updated.mood, '平稳');
      expect(transport.calls, [
        ('POST', '/v1/pregnancy-diary/entries'),
        ('PATCH', '/v1/pregnancy-diary/entries/2026-07-11'),
        ('DELETE', '/v1/pregnancy-diary/entries/2026-07-11'),
      ]);
      expect(transport.bodies[0], {
        'entry_date': '2026-07-11',
        'gestational_week': '孕 32 周',
        'mood': '平稳',
        'energy_level': '一般',
        'sleep_summary': '易醒',
        'fetal_movement': '胎动正常',
        'symptom_tags': ['腰酸', '水肿'],
        'appointment_note': '想确认水肿是否正常',
        'nutrition_note': '增加蛋白质',
        'content': '今天胎动规律。',
      });
      expect(transport.bodies[1], {
        'gestational_week': '孕 32 周',
        'mood': '平稳',
        'energy_level': '一般',
        'sleep_summary': '易醒',
        'fetal_movement': '胎动正常',
        'symptom_tags': ['腰酸', '水肿'],
        'appointment_note': '想确认水肿是否正常',
        'nutrition_note': '增加蛋白质',
        'content': '今天胎动规律。',
      });
    });

    test('rejects malformed list responses instead of reporting empty', () {
      final repository = PregnancyDiaryApiRepository(
        transport: _RecordingTransport(listResponse: const {}),
      );

      expect(repository.fetchEntries, throwsFormatException);
    });
  });
}

class _RecordingTransport
    implements ApiJsonTransport, ApiJsonMutationTransport {
  _RecordingTransport({Map<String, Object?>? listResponse})
    : listResponse =
          listResponse ??
          {
            'items': [
              {
                'id': 'entry-1',
                'entry_date': '2026-07-10',
                'content': '已有日记',
                'gestational_week': '孕 32 周',
                'mood': '平静',
                'symptom_tags': <Object?>['腰酸', '水肿'],
                'appointment_note': '想确认水肿是否正常',
                'attachments': <Object?>[],
                'status': 'active',
              },
            ],
          };

  final Map<String, Object?> listResponse;
  final calls = <(String, String)>[];
  final bodies = <Map<String, Object?>>[];
  Map<String, Object?>? firstQuery;

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) async {
    calls.add(('GET', path));
    firstQuery ??= Map<String, Object?>.from(query);
    return listResponse;
  }

  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    calls.add(('POST', path));
    bodies.add(Map<String, Object?>.from(body));
    return _entry(body);
  }

  @override
  Future<Map<String, Object?>> putJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    calls.add(('PUT', path));
    bodies.add(Map<String, Object?>.from(body));
    return _entry(body);
  }

  @override
  Future<Map<String, Object?>> patchJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    calls.add(('PATCH', path));
    bodies.add(Map<String, Object?>.from(body));
    return _entry(body);
  }

  @override
  Future<Map<String, Object?>> deleteJson(
    String path, {
    Map<String, String> headers = const {},
  }) async {
    calls.add(('DELETE', path));
    return const {};
  }

  Map<String, Object?> _entry(Map<String, Object?> body) {
    return {
      'id': 'entry-1',
      'entry_date': '2026-07-11',
      'content': body['content'] ?? '',
      'gestational_week': body['gestational_week'] ?? '',
      'mood': body['mood'] ?? '',
      'energy_level': body['energy_level'] ?? '',
      'sleep_summary': body['sleep_summary'] ?? '',
      'fetal_movement': body['fetal_movement'] ?? '',
      'symptom_tags': body['symptom_tags'] ?? <Object?>[],
      'appointment_note': body['appointment_note'] ?? '',
      'nutrition_note': body['nutrition_note'] ?? '',
      'attachments': <Object?>[],
      'status': 'active',
    };
  }
}
