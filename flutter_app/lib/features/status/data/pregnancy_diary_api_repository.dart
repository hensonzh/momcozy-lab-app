import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/status/domain/pregnancy_diary.dart';

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
    final values = response['items'] ?? response['diary_list'];
    if (values is! List) return const <PregnancyDiaryEntry>[];
    return values
        .whereType<Map>()
        .map((value) => _entry(Map<String, Object?>.from(value)))
        .whereType<PregnancyDiaryEntry>()
        .toList(growable: false);
  }

  @override
  Future<PregnancyDiaryEntry> upsertEntry({
    required DateTime entryDate,
    required PregnancyDiaryDraft draft,
  }) async {
    final mutations = transport;
    if (mutations is! ApiJsonMutationTransport) {
      throw UnsupportedError('Pregnancy diary requires JSON mutation support.');
    }
    final response = await (mutations as ApiJsonMutationTransport).putJson(
      '$pregnancyDiaryEntriesEndpoint/${_apiDate(entryDate)}',
      body: {
        'gestational_week': draft.gestationalWeek.trim(),
        'mood': draft.mood.trim(),
        'energy_level': draft.energyLevel.trim(),
        'sleep_summary': draft.sleepSummary.trim(),
        'fetal_movement': draft.fetalMovement.trim(),
        'symptom_tags': draft.symptomTags
            .map((tag) => tag.trim())
            .where((tag) => tag.isNotEmpty)
            .toList(growable: false),
        'appointment_note': draft.appointmentNote.trim(),
        'nutrition_note': draft.nutritionNote.trim(),
        'content': draft.content.trim(),
      },
    );
    final entry = _entry(response);
    if (entry == null) {
      throw const FormatException('Pregnancy diary response is invalid.');
    }
    return entry;
  }
}

PregnancyDiaryEntry? _entry(Map<String, Object?> data) {
  final entryDate = _date(data['entry_date'] ?? data['entryDate']);
  if (entryDate == null) return null;
  return PregnancyDiaryEntry(
    id: _id(data['id'] ?? data['entry_id'] ?? data['entryId']),
    entryDate: entryDate,
    gestationalWeek: _string(
      data['gestational_week'] ?? data['gestationalWeek'],
    ),
    mood: _string(data['mood']),
    energyLevel: _string(data['energy_level'] ?? data['energyLevel']),
    sleepSummary: _string(data['sleep_summary'] ?? data['sleepSummary']),
    fetalMovement: _string(data['fetal_movement'] ?? data['fetalMovement']),
    symptomTags: _strings(data['symptom_tags'] ?? data['symptomTags']),
    appointmentNote: _string(
      data['appointment_note'] ?? data['appointmentNote'],
    ),
    nutritionNote: _string(data['nutrition_note'] ?? data['nutritionNote']),
    content: _string(data['content']),
    healthNotes: _healthNotes(data['health_notes'] ?? data['healthNotes']),
    status: _string(data['status']),
  );
}

List<PregnancyDiaryHealthNote> _healthNotes(Object? value) {
  if (value is! List) return const <PregnancyDiaryHealthNote>[];
  return value
      .whereType<Map>()
      .map((raw) {
        final map = Map<String, Object?>.from(raw);
        return PregnancyDiaryHealthNote(
          id: _id(map['id'] ?? map['note_id'] ?? map['noteId']),
          topic: _string(map['topic']),
          userReport: _string(map['user_report'] ?? map['userReport']),
          followUp: _string(map['follow_up'] ?? map['followUp']),
        );
      })
      .toList(growable: false);
}

List<String> _strings(Object? value) {
  if (value is! List) return const <String>[];
  return value.whereType<String>().toList(growable: false);
}

String _apiDate(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

DateTime? _date(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  final parsed = DateTime.tryParse(value.trim());
  if (parsed == null) return null;
  return DateTime(parsed.year, parsed.month, parsed.day);
}

String _id(Object? value) => value?.toString() ?? '';

String _string(Object? value) => value is String ? value : '';
