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
    int limit = 30,
  }) async {
    final response = await transport.getJson(
      pregnancyDiaryEntriesEndpoint,
      query: {
        if (startDate != null) 'start_date': _apiDate(startDate),
        if (endDate != null) 'end_date': _apiDate(endDate),
        'limit': limit.clamp(1, 100),
      },
    );
    final items = response['items'];
    if (items is! List) {
      throw const FormatException(
        'Pregnancy diary response has no items list.',
      );
    }
    return List<PregnancyDiaryEntry>.unmodifiable(
      items.map((raw) {
        if (raw is! Map) {
          throw const FormatException('Pregnancy diary entry is invalid.');
        }
        return _entry(Map<String, Object?>.from(raw));
      }),
    );
  }

  @override
  Future<PregnancyDiaryEntry> createEntry({
    required DateTime entryDate,
    required PregnancyDiaryDraft draft,
  }) async {
    final response = await transport.postJson(
      pregnancyDiaryEntriesEndpoint,
      body: <String, Object?>{
        'entry_date': _apiDate(entryDate),
        ..._draftBody(draft),
      },
    );
    return _entry(response);
  }

  @override
  Future<PregnancyDiaryEntry> updateEntry({
    required DateTime entryDate,
    required PregnancyDiaryDraft draft,
  }) async {
    final response = await _mutations().patchJson(
      '$pregnancyDiaryEntriesEndpoint/${_apiDate(entryDate)}',
      body: _draftBody(draft),
    );
    return _entry(response);
  }

  @override
  Future<void> deleteEntry({required DateTime entryDate}) async {
    await _mutations().deleteJson(
      '$pregnancyDiaryEntriesEndpoint/${_apiDate(entryDate)}',
    );
  }

  ApiJsonMutationTransport _mutations() {
    final value = transport;
    if (value is! ApiJsonMutationTransport) {
      throw UnsupportedError('Pregnancy diary requires mutation support.');
    }
    return value as ApiJsonMutationTransport;
  }
}

Map<String, Object?> _draftBody(PregnancyDiaryDraft draft) {
  return <String, Object?>{
    'gestational_week': draft.gestationalWeek.trim(),
    'mood': draft.mood.trim(),
    'energy_level': draft.energyLevel.trim(),
    'sleep_summary': draft.sleepSummary.trim(),
    'fetal_movement': draft.fetalMovement.trim(),
    'symptom_tags': draft.symptomTags
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList(growable: false),
    'appointment_note': draft.appointmentNote.trim(),
    'nutrition_note': draft.nutritionNote.trim(),
    'content': draft.content.trim(),
  };
}

PregnancyDiaryEntry _entry(Map<String, Object?> data) {
  final id = _string(data['id']);
  final parsedDate = DateTime.tryParse(_string(data['entry_date']));
  if (id.isEmpty || parsedDate == null) {
    throw const FormatException('Pregnancy diary entry is invalid.');
  }
  final entryDate = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
  return PregnancyDiaryEntry(
    id: id,
    entryDate: entryDate,
    content: _string(data['content']),
    gestationalWeek: _string(data['gestational_week']),
    mood: _string(data['mood']),
    energyLevel: _string(data['energy_level']),
    sleepSummary: _string(data['sleep_summary']),
    fetalMovement: _string(data['fetal_movement']),
    symptomTags: _strings(data['symptom_tags']),
    appointmentNote: _string(data['appointment_note']),
    nutritionNote: _string(data['nutrition_note']),
    attachments: _list(data['attachments']),
    status: _string(data['status']),
  );
}

String _apiDate(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

String _string(Object? value) => value is String ? value : '';

List<String> _strings(Object? value) {
  if (value is! List) return const <String>[];
  return List<String>.unmodifiable(value.whereType<String>());
}

List<Object?> _list(Object? value) {
  return value is List ? List<Object?>.unmodifiable(value) : const <Object?>[];
}
