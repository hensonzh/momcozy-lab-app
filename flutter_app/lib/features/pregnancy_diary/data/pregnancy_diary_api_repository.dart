import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/pregnancy_diary/domain/pregnancy_diary_entry.dart';

const pregnancyDiaryEntriesEndpoint = '/v1/pregnancy-diary/entries';

class PregnancyDiaryApiRepository implements PregnancyDiaryRepository {
  const PregnancyDiaryApiRepository({required this.transport});

  final ApiJsonTransport transport;

  @override
  Future<List<PregnancyDiaryEntry>> fetchEntries({
    DateTime? startDate,
    DateTime? endDate,
    int limit = 7,
  }) async {
    final response = await transport.getJson(
      pregnancyDiaryEntriesEndpoint,
      query: {
        if (startDate != null) 'start_date': _apiDate(startDate),
        if (endDate != null) 'end_date': _apiDate(endDate),
        'limit': limit,
      },
    );
    final items = response['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((item) => _entry(Map<String, Object?>.from(item)))
        .toList(growable: false);
  }

  @override
  Future<PregnancyDiaryEntry> createEntry({
    required DateTime entryDate,
    required String content,
  }) async {
    final response = await transport.postJson(
      pregnancyDiaryEntriesEndpoint,
      body: {'entry_date': _apiDate(entryDate), 'content': content},
    );
    return _entry(response);
  }

  @override
  Future<PregnancyDiaryEntry> updateEntry({
    required DateTime entryDate,
    required String content,
  }) async {
    final response = await transport.patchJson(
      '$pregnancyDiaryEntriesEndpoint/${_apiDate(entryDate)}',
      body: {'content': content},
    );
    return _entry(response);
  }

  @override
  Future<void> deleteEntry({required DateTime entryDate}) {
    return transport.deleteJson(
      '$pregnancyDiaryEntriesEndpoint/${_apiDate(entryDate)}',
    );
  }
}

PregnancyDiaryEntry _entry(Map<String, Object?> data) {
  final entryDate = DateTime.tryParse(_string(data['entry_date']));
  if (entryDate == null) {
    throw const FormatException('Pregnancy diary entry_date is invalid.');
  }
  return PregnancyDiaryEntry(
    id: _string(data['id']),
    entryDate: entryDate,
    content: _string(data['content']),
    gestationalWeek: _string(data['gestational_week']),
    mood: _string(data['mood']),
    energyLevel: _string(data['energy_level']),
    sleepSummary: _string(data['sleep_summary']),
    fetalMovement: _string(data['fetal_movement']),
    symptomTags: _list(data['symptom_tags']),
    appointmentNote: _string(data['appointment_note']),
    nutritionNote: _string(data['nutrition_note']),
    attachments: _list(data['attachments']),
  );
}

String _apiDate(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

String _string(Object? value) => value is String ? value : '';

List<Object?> _list(Object? value) =>
    value is List ? List<Object?>.from(value) : const [];
