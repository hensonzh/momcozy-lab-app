import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/pregnancy_diary/data/pregnancy_diary_api_repository.dart';

void main() {
  test(
    'pregnancy diary repository exposes independent CRUD requests',
    () async {
      final transport = _RecordingTransport();
      final repository = PregnancyDiaryApiRepository(transport: transport);

      final entries = await repository.fetchEntries(
        startDate: DateTime(2026, 7, 5),
        endDate: DateTime(2026, 7, 11),
        limit: 7,
      );
      final created = await repository.createEntry(
        entryDate: DateTime(2026, 7, 11),
        content: '今天胎动规律。',
      );
      final updated = await repository.updateEntry(
        entryDate: DateTime(2026, 7, 11),
        content: '今天胎动规律，心情安心。',
      );
      await repository.deleteEntry(entryDate: DateTime(2026, 7, 11));

      expect(entries.single.content, '已有日记');
      expect(created.content, '今天胎动规律。');
      expect(updated.content, '今天胎动规律，心情安心。');
      expect(transport.calls, [
        ('GET', '/v1/pregnancy-diary/entries'),
        ('POST', '/v1/pregnancy-diary/entries'),
        ('PATCH', '/v1/pregnancy-diary/entries/2026-07-11'),
        ('DELETE', '/v1/pregnancy-diary/entries/2026-07-11'),
      ]);
      expect(transport.firstQuery, {
        'start_date': '2026-07-05',
        'end_date': '2026-07-11',
        'limit': 7,
      });
    },
  );
}

class _RecordingTransport implements ApiJsonTransport {
  final calls = <(String, String)>[];
  Map<String, Object?>? firstQuery;

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) async {
    calls.add(('GET', path));
    firstQuery ??= Map<String, Object?>.from(query);
    return {
      'items': [
        {
          'id': 'entry-1',
          'entry_date': '2026-07-10',
          'content': '已有日记',
          'mood': '平静',
          'symptom_tags': <Object?>[],
          'attachments': <Object?>[],
          'status': 'active',
        },
      ],
    };
  }

  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    calls.add(('POST', path));
    return _entry(body);
  }

  @override
  Future<Map<String, Object?>> patchJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    calls.add(('PATCH', path));
    return _entry(body);
  }

  @override
  Future<void> deleteJson(
    String path, {
    Map<String, String> headers = const {},
  }) async {
    calls.add(('DELETE', path));
  }

  Map<String, Object?> _entry(Map<String, Object?> body) {
    return {
      'id': 'entry-1',
      'entry_date': '2026-07-11',
      'content': body['content'] ?? '',
      'mood': '',
      'symptom_tags': <Object?>[],
      'attachments': <Object?>[],
      'status': 'active',
    };
  }
}
