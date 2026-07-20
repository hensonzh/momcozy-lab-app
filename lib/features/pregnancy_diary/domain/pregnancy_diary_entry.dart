class PregnancyDiaryEntry {
  const PregnancyDiaryEntry({
    required this.id,
    required this.entryDate,
    this.gestationalWeek = '',
    this.mood = '',
    this.energyLevel = '',
    this.sleepSummary = '',
    this.fetalMovement = '',
    this.symptomTags = const <String>[],
    this.appointmentNote = '',
    this.nutritionNote = '',
    this.content = '',
    this.attachments = const <Object?>[],
    this.status = '',
  });

  final String id;
  final DateTime entryDate;
  final String gestationalWeek;
  final String mood;
  final String energyLevel;
  final String sleepSummary;
  final String fetalMovement;
  final List<String> symptomTags;
  final String appointmentNote;
  final String nutritionNote;
  final String content;
  final List<Object?> attachments;
  final String status;

  bool get hasAppointmentQuestion => appointmentNote.trim().isNotEmpty;
}

class PregnancyDiaryDraft {
  const PregnancyDiaryDraft({
    this.gestationalWeek = '',
    this.mood = '',
    this.energyLevel = '',
    this.sleepSummary = '',
    this.fetalMovement = '',
    this.symptomTags = const <String>[],
    this.appointmentNote = '',
    this.nutritionNote = '',
    this.content = '',
  });

  factory PregnancyDiaryDraft.fromEntry(PregnancyDiaryEntry? entry) {
    if (entry == null) return const PregnancyDiaryDraft();
    return PregnancyDiaryDraft(
      gestationalWeek: entry.gestationalWeek,
      mood: entry.mood,
      energyLevel: entry.energyLevel,
      sleepSummary: entry.sleepSummary,
      fetalMovement: entry.fetalMovement,
      symptomTags: entry.symptomTags,
      appointmentNote: entry.appointmentNote,
      nutritionNote: entry.nutritionNote,
      content: entry.content,
    );
  }

  final String gestationalWeek;
  final String mood;
  final String energyLevel;
  final String sleepSummary;
  final String fetalMovement;
  final List<String> symptomTags;
  final String appointmentNote;
  final String nutritionNote;
  final String content;

  bool get hasContent {
    return gestationalWeek.trim().isNotEmpty ||
        mood.trim().isNotEmpty ||
        energyLevel.trim().isNotEmpty ||
        sleepSummary.trim().isNotEmpty ||
        fetalMovement.trim().isNotEmpty ||
        symptomTags.any((tag) => tag.trim().isNotEmpty) ||
        appointmentNote.trim().isNotEmpty ||
        nutritionNote.trim().isNotEmpty ||
        content.trim().isNotEmpty;
  }
}

abstract interface class PregnancyDiaryRepository {
  Future<List<PregnancyDiaryEntry>> fetchEntries({
    DateTime? startDate,
    DateTime? endDate,
    int limit = 30,
  });

  Future<PregnancyDiaryEntry> createEntry({
    required DateTime entryDate,
    required PregnancyDiaryDraft draft,
  });

  Future<PregnancyDiaryEntry> updateEntry({
    required DateTime entryDate,
    required PregnancyDiaryDraft draft,
  });

  Future<void> deleteEntry({required DateTime entryDate});
}
