abstract interface class PregnancyDiaryRepository {
  Future<List<PregnancyDiaryEntry>> fetchEntries({
    DateTime? startDate,
    DateTime? endDate,
    int limit = 30,
  });

  Future<PregnancyDiaryEntry> upsertEntry({
    required DateTime entryDate,
    required PregnancyDiaryDraft draft,
  });
}

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
    this.healthNotes = const <PregnancyDiaryHealthNote>[],
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
  final List<PregnancyDiaryHealthNote> healthNotes;
  final String status;

  bool get hasAppointmentQuestion => appointmentNote.trim().isNotEmpty;
}

class PregnancyDiaryHealthNote {
  const PregnancyDiaryHealthNote({
    required this.id,
    required this.topic,
    this.userReport = '',
    this.followUp = '',
  });

  final String id;
  final String topic;
  final String userReport;
  final String followUp;
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
